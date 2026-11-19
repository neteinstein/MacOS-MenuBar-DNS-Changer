import Foundation

/// Who runs a DNS service and how it treats your data. Same facts as the Android app (taken from
/// each provider's own documentation and privacy policy, checked November 2026). Keep [website] and
/// [privacyPolicy] pointing at those pages so people can read the source.
public struct DNSProvider: Hashable, Sendable {
    public let operatorName: String
    public let basedIn: String
    public let about: String
    public let privacy: String
    public let website: URL
    public let privacyPolicy: URL

    public static let cloudflare = DNSProvider(
        operatorName: "Cloudflare, Inc.",
        basedIn: "United States",
        about: "1.1.1.1 is Cloudflare's public resolver, run with APNIC, the internet registry for the Asia-Pacific region.",
        privacy: "Your IP address is never written to disk. Truncated addresses and debug logs are deleted within 25 hours.",
        website: URL(string: "https://one.one.one.one/")!,
        privacyPolicy: URL(string: "https://developers.cloudflare.com/1.1.1.1/privacy/public-dns-resolver/")!
    )
    public static let google = DNSProvider(
        operatorName: "Google LLC",
        basedIn: "United States",
        about: "Google's public resolver, served from Google's global network.",
        privacy: "Temporary logs with your IP address are deleted within 24–48 hours. Permanent logs keep only a sample, with the IP address replaced by a city or region.",
        website: URL(string: "https://developers.google.com/speed/public-dns")!,
        privacyPolicy: URL(string: "https://developers.google.com/speed/public-dns/privacy")!
    )
    public static let quad9 = DNSProvider(
        operatorName: "Quad9 Foundation",
        basedIn: "Switzerland",
        about: "A non-profit foundation focused on security. It blocks threats using data from more than 25 threat-intelligence providers.",
        privacy: "No data containing your IP address is logged. The foundation is bound by Swiss privacy law.",
        website: URL(string: "https://quad9.net/")!,
        privacyPolicy: URL(string: "https://quad9.net/privacy/policy/")!
    )
    public static let mullvad = DNSProvider(
        operatorName: "Mullvad VPN AB",
        basedIn: "Sweden",
        about: "The free, public DNS service of the Mullvad VPN provider. It works without the VPN or an account.",
        privacy: "Uses QNAME minimisation, so other DNS servers learn as little as possible about your queries.",
        website: URL(string: "https://mullvad.net/en/help/dns-over-https-and-dns-over-tls")!,
        privacyPolicy: URL(string: "https://mullvad.net/en/help/privacy-policy")!
    )
    public static let controlD = DNSProvider(
        operatorName: "Control D, Inc.",
        basedIn: "Canada",
        about: "A DNS filtering company in Toronto and the sister company of the Windscribe VPN.",
        privacy: "The free resolvers keep no logs: no browsing history, timestamps or query logs.",
        website: URL(string: "https://controld.com/free-dns")!,
        privacyPolicy: URL(string: "https://controld.com/privacy")!
    )
    public static let adGuard = DNSProvider(
        operatorName: "AdGuard Software Limited",
        basedIn: "Cyprus",
        about: "The maker of the AdGuard ad blocker. Its DNS blocks ads for every app on the Mac, not just the browser.",
        privacy: "Collects only what is needed to run the service and nothing for tracking.",
        website: URL(string: "https://adguard-dns.io/en/public-dns.html")!,
        privacyPolicy: URL(string: "https://adguard-dns.io/en/privacy.html")!
    )
    public static let cleanBrowsing = DNSProvider(
        operatorName: "CleanBrowsing, Inc.",
        basedIn: "United States",
        about: "A fully remote company that builds DNS content filters, mostly to keep children safer online.",
        privacy: "The free filters do not log or store anything that could tie DNS requests back to you, such as your IP address.",
        website: URL(string: "https://cleanbrowsing.org/filters/")!,
        privacyPolicy: URL(string: "https://cleanbrowsing.org/privacy")!
    )
    public static let dns4eu = DNSProvider(
        operatorName: "Whalebone, s.r.o. (DNS4EU)",
        basedIn: "Czech Republic",
        about: "A European Union public resolver on European infrastructure, independent of non-EU providers. Run by a consortium led by Whalebone.",
        privacy: "Runs under EU data protection rules (GDPR), with anonymised resolution.",
        website: URL(string: "https://www.joindns4.eu/for-public")!,
        privacyPolicy: URL(string: "https://www.joindns4.eu/privacy-policy")!
    )
    public static let dnsSB = DNSProvider(
        operatorName: "xTom GmbH",
        basedIn: "Germany",
        about: "A public resolver built on xTom's anycast network, in 30 locations on 6 continents.",
        privacy: "Logs no DNS queries, IP addresses or timestamps.",
        website: URL(string: "https://dns.sb/")!,
        privacyPolicy: URL(string: "https://dns.sb/privacy/")!
    )
}

/// What a built-in hostname blocks, and who runs it.
public struct PresetInfo: Hashable, Sendable {
    public let provider: DNSProvider
    public let blocks: String
}

public enum ProviderInfo {
    private static let none = "Nothing. Every domain resolves normally."
    private static let adsTrackers = "Ads and trackers."
    private static let quad9 = "Malicious domains: malware, phishing, spyware and botnets."

    private static let byHost: [String: PresetInfo] = [
        "one.one.one.one": PresetInfo(provider: .cloudflare, blocks: none),
        "security.cloudflare-dns.com": PresetInfo(provider: .cloudflare, blocks: "Known malware domains."),
        "family.cloudflare-dns.com": PresetInfo(provider: .cloudflare, blocks: "Malware and adult content."),
        "dns.google": PresetInfo(provider: .google, blocks: none),
        "dns.quad9.net": PresetInfo(provider: .quad9, blocks: quad9),
        "dns11.quad9.net": PresetInfo(
            provider: .quad9,
            blocks: quad9 + " It also passes part of your network address (EDNS Client Subnet) to websites' DNS servers, which can pick a closer server but is slightly less private."
        ),
        "dns.mullvad.net": PresetInfo(provider: .mullvad, blocks: none),
        "adblock.dns.mullvad.net": PresetInfo(provider: .mullvad, blocks: adsTrackers),
        "family.dns.mullvad.net": PresetInfo(provider: .mullvad, blocks: "Ads, trackers, malware, adult content and gambling."),
        "p0.freedns.controld.com": PresetInfo(provider: .controlD, blocks: none),
        "p2.freedns.controld.com": PresetInfo(provider: .controlD, blocks: "Malware, ads and trackers."),
        "family.freedns.controld.com": PresetInfo(provider: .controlD, blocks: "Malware, ads, trackers, adult content and drug sites."),
        "unfiltered.adguard-dns.com": PresetInfo(provider: .adGuard, blocks: none),
        "dns.adguard-dns.com": PresetInfo(provider: .adGuard, blocks: adsTrackers),
        "family.adguard-dns.com": PresetInfo(provider: .adGuard, blocks: "Ads, trackers and adult content. Turns on Safe Search where possible."),
        "security-filter-dns.cleanbrowsing.org": PresetInfo(
            provider: .cleanBrowsing,
            blocks: "Phishing, spam, malware and malicious domains. Adult content is not blocked."
        ),
        "adult-filter-dns.cleanbrowsing.org": PresetInfo(
            provider: .cleanBrowsing,
            blocks: "Adult and explicit sites, plus malicious and phishing domains. Google and Bing use SafeSearch."
        ),
        "family-filter-dns.cleanbrowsing.org": PresetInfo(
            provider: .cleanBrowsing,
            blocks: "Adult and explicit sites, proxies and VPNs used to get around the filter, and mixed-content sites like Reddit, plus malicious domains. Google, Bing and YouTube use SafeSearch."
        ),
        "unfiltered.joindns4.eu": PresetInfo(provider: .dns4eu, blocks: none),
        "protective.joindns4.eu": PresetInfo(provider: .dns4eu, blocks: "Malware, phishing and command-and-control domains."),
        "noads.joindns4.eu": PresetInfo(
            provider: .dns4eu,
            blocks: "Malware, phishing and command-and-control domains, plus ads and trackers."
        ),
        "child.joindns4.eu": PresetInfo(
            provider: .dns4eu,
            blocks: "Malware, phishing and command-and-control domains, plus content not suitable for children, such as explicit content, violence or drugs."
        ),
        "child-noads.joindns4.eu": PresetInfo(
            provider: .dns4eu,
            blocks: "Malware, phishing and command-and-control domains, content not suitable for children, and ads and trackers."
        ),
        "dot.sb": PresetInfo(provider: .dnsSB, blocks: none),
    ]

    /// Details for a built-in hostname, or nil for one the user added.
    public static func forHost(_ host: String) -> PresetInfo? { byHost[host] }
}
