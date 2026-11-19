# Install Private DNS

Private DNS encrypts your Mac's DNS lookups (the step that turns a website's name into an address) with a provider you choose, from the menu bar.

You need a Mac with **macOS 13 (Ventura) or later**. It takes about two minutes.

## 1. Download it

Download **[Private-DNS.dmg](https://github.com/neteinstein/MacOS-MenuBar-DNS-Changer/releases/latest/download/Private-DNS.dmg)**. It's in your Downloads folder when it's done.

## 2. Drag it into Applications

Open **Private-DNS.dmg**. A window opens: drag **Private DNS** onto the **Applications** folder.

## 3. Open it, and allow it

Open **Applications** in Finder and double-click **Private DNS**.

The first time, macOS stops it. Private DNS is free and isn't signed by Apple, so macOS can't check it and says it's not opened. Click **Done**. Don't click Move to Trash.

Now allow it:

1. Open the Apple menu › **System Settings**.
2. Click **Privacy & Security** in the sidebar.
3. Scroll down to **Security**. Next to “Private DNS” was blocked to protect your Mac, click **Open Anyway**.
4. Click **Open Anyway** again and enter your Mac's password (or use Touch ID).

You only do this once. From then on it opens like any other app.

## 4. Turn it on

A lock icon appears in the menu bar, at the top right of your screen.

1. Click it, open **Providers** and pick one (Cloudflare, Quad9, Mullvad…).
2. macOS opens System Settings with a new profile, **Private DNS: <provider>**. Open **Privacy & Security › Profiles** (on some versions, **General › Device Management**), double-click the profile and click **Install**, then enter your password.

That's it: the lock in the menu bar is closed while encrypted DNS is on. Every time you switch provider or turn it off, macOS asks you to install the new profile the same way. To have it start whenever you log in, turn on **Open at login** in Settings › General.

## Updating

Download the new **Private-DNS.dmg**, quit Private DNS from its menu, drag the new one into Applications and choose **Replace**. Open it, and allow it once more with **Open Anyway** (step 3). Your settings are kept.

## Removing it

Turn Private DNS off from its menu (or remove the **Private DNS** profile in System Settings), quit it, then drag it from Applications to the Bin.
