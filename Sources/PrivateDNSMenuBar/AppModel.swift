import AppKit
import DNSChangerCore
import Foundation
import ServiceManagement
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var settings: AppSettings {
        didSet { if settings != oldValue { save() } }
    }

    @Published private(set) var state: DNSState = .off
    /// False while the Network Extension configuration is waiting to be enabled in System Settings.
    @Published private(set) var enabledInSystem = true
    @Published private(set) var health: HealthStatus = .unknown
    @Published private(set) var network = NetworkSnapshot(kind: nil)
    @Published private(set) var online = true
    @Published private(set) var busy = false
    @Published var lastError: String?
    @Published private(set) var now = Date()

    let backend: DNSBackend
    private let monitor = NetworkMonitor()
    private var tick: Timer?
    private var safetyCheck: Task<Void, Never>?
    private var lastHealthCheck = Date.distantPast

    private static let settingsKey = "settings"
    private static let addressCacheKey = "addressCache"

    init(backend: DNSBackend = Backends.make()) {
        self.backend = backend
        if let data = UserDefaults.standard.data(forKey: Self.settingsKey),
           let saved = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = saved
        } else {
            settings = AppSettings()
        }
    }

    // MARK: - Lifecycle

    func start() {
        monitor.onChange = { [weak self] network, online in
            guard let self else { return }
            let changed = network != self.network || online != self.online
            self.network = network
            self.online = online
            if changed { Task { await self.checkHealth() } }
        }
        monitor.start()

        // Once every 15 s: count the pause down, end it when due, and re-check the provider now and then.
        tick = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.onTick() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.onTick() }
        }

        Task {
            await refresh()
            await onTick()
        }
    }

    func refresh() async {
        do {
            let status = try await backend.load()
            state = status.state
            enabledInSystem = status.enabledInSystem
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func onTick() async {
        now = Date()
        if let pause = settings.pause, pause.isExpired(at: now) {
            await resume()
            notify(title: "Private DNS is back on", body: "\(settings.name(of: pause.restoreHost)) is in use again.")
        }
        if now.timeIntervalSince(lastHealthCheck) > 120 { await checkHealth() }
    }

    // MARK: - Derived state

    var currentName: String? { state.host.map(settings.name(of:)) }

    var suspendedByRule: Bool { isSuspendedByRule(network, state: state, rules: settings.rules) }

    var pauseRemaining: String? {
        guard let pause = settings.pause else { return nil }
        let minutes = max(1, Int((pause.until.timeIntervalSince(now) / 60).rounded(.up)))
        return minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
    }

    /// What "Toggle" would switch to.
    var toggleTarget: DNSState {
        nextToggleTarget(state: state, toggleHost: settings.toggleHost, cycle: settings.cycle)
    }

    // MARK: - Actions

    func toggle() async {
        if settings.pause != nil {
            await resume()
        } else {
            await apply(toggleTarget)
        }
    }

    /// Switches to [host] and makes it the provider "Turn on" uses from now on.
    func select(_ host: String) async {
        settings.toggleHost = host
        await apply(.on(host: host))
    }

    func turnOn(host: String? = nil) async { await apply(.on(host: host ?? settings.toggleHost)) }

    func turnOff() async { await apply(.off) }

    func pause(minutes: Int) async {
        let pause = Pause.start(minutes: minutes, now: Date(), current: state, existing: settings.pause, toggleHost: settings.toggleHost)
        guard await apply(.off, endsPause: false) else { return }
        settings.pause = pause
        now = Date()
    }

    func resume() async {
        guard let pause = settings.pause else { return }
        settings.pause = nil
        await apply(.on(host: pause.restoreHost))
    }

    /// Re-applies the current state, e.g. after the network rules changed.
    func reapply() async {
        await apply(state, endsPause: false, safe: false)
    }

    func updateRules(_ change: (inout NetworkRules) -> Void) {
        change(&settings.rules)
        Task { await reapply() }
    }

    /// Applies [target]. A manual change ends any pause. Returns whether it worked.
    @discardableResult
    func apply(_ target: DNSState, endsPause: Bool = true, safe: Bool = true) async -> Bool {
        let previous = state
        busy = true
        defer { busy = false }
        safetyCheck?.cancel()
        lastError = nil

        var addresses: [String] = []
        if let host = target.host {
            addresses = await Resolver.addresses(of: host)
            if addresses.isEmpty {
                addresses = cachedAddresses(for: host)
            } else {
                cacheAddresses(addresses, for: host)
            }
        }

        do {
            let rules = onDemandRules(for: target, rules: settings.rules)
            try await backend.apply(target, rules: rules, addresses: addresses, displayName: target.host.map(settings.name(of:)) ?? "Off")
        } catch {
            lastError = error.localizedDescription
            return false
        }
        if endsPause { settings.pause = nil }
        state = target
        health = .unknown
        await refresh()

        if safe, settings.safeSwitching, backend.kind == .networkExtension, enabledInSystem, target.isOn, target != previous {
            startSafetyCheck(target: target, previous: previous)
        } else {
            Task { await checkHealth() }
        }
        return true
    }

    // MARK: - Health and safe switching

    func checkHealth() async {
        lastHealthCheck = Date()
        guard state.isOn, enabledInSystem, !suspendedByRule, settings.pause == nil else {
            health = .unknown
            return
        }
        health = .checking
        let result = await Resolver.probe(online: online)
        health = Health.status(of: result)
    }

    /// Probes the new provider every few seconds. If it never answers while the Mac is online, goes
    /// back to [previous], like the Android app does after Android fails to validate the network.
    private func startSafetyCheck(target: DNSState, previous: DNSState) {
        health = .checking
        safetyCheck = Task { [weak self] in
            let started = Date()
            var results: [ProbeResult] = []
            // Give macOS a moment to pick up the new configuration.
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            while !Task.isCancelled {
                guard let self else { return }
                let result = await Resolver.probe(online: self.online, timeout: 4)
                results.append(result)
                switch Health.verdict(results: results, elapsed: Date().timeIntervalSince(started)) {
                case .keep:
                    self.health = results.contains { Health.status(of: $0) == .answering } ? .answering : .unknown
                    return
                case .revert:
                    guard !Task.isCancelled, self.state == target else { return }
                    let name = target.host.map(self.settings.name(of:)) ?? "The provider"
                    await self.apply(previous, endsPause: false, safe: false)
                    self.lastError = "\(name) didn't answer, so the previous setting was restored."
                    self.notify(title: "Switched back", body: "\(name) didn't answer DNS queries, so the previous setting was restored.")
                    return
                case .wait:
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                }
            }
        }
    }

    // MARK: - Automation

    func handle(url: URL) {
        guard let command = DNSCommand.parse(url) else { return }
        guard DNSCommand.isAuthorized(url, settings: settings) else {
            lastError = settings.automationEnabled
                ? "Ignored an automation request with a missing or wrong token."
                : "Ignored an automation request: turn on automation in Settings first."
            return
        }
        Task {
            switch command {
            case let .turnOn(host): await turnOn(host: host)
            case .turnOff: await turnOff()
            case .toggle: await toggle()
            case let .pause(minutes): await pause(minutes: minutes)
            case .resume: await resume()
            }
        }
    }

    // MARK: - Providers

    func addNextDNS(id: String) -> Bool {
        guard NextDNS.isValidID(id) else { return false }
        let host = NextDNS.host(forID: id)
        settings.addCustom(host: host, name: "NextDNS (\(id.trimmingCharacters(in: .whitespaces)))")
        return true
    }

    // MARK: - Launch at login

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                lastError = "Couldn't change Open at Login: \(error.localizedDescription)"
            }
            objectWillChange.send()
        }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.settingsKey)
        }
    }

    private func cachedAddresses(for host: String) -> [String] {
        (UserDefaults.standard.dictionary(forKey: Self.addressCacheKey) as? [String: [String]])?[host] ?? []
    }

    private func cacheAddresses(_ addresses: [String], for host: String) {
        var cache = (UserDefaults.standard.dictionary(forKey: Self.addressCacheKey) as? [String: [String]]) ?? [:]
        cache[host] = addresses
        UserDefaults.standard.set(cache, forKey: Self.addressCacheKey)
    }

    // MARK: - Notifications

    private func notify(title: String, body: String) {
        // UNUserNotificationCenter traps outside an app bundle (e.g. `swift run`).
        guard Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
}
