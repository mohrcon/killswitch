<p align="center">
  <h1 align="center">⚡ Killswitch</h1>
  <p align="center"><strong>Dein Screen. Deine Kontrolle.</strong></p>
  <p align="center">Ein Klick oder Hotkey – und alle Apps verschwinden, die beim Screen Sharing nichts zu suchen haben.</p>
</p>

<p align="center">
  <a href="https://github.com/mohrcon/killswitch/releases/latest"><img src="https://img.shields.io/github/v/release/mohrcon/killswitch?style=flat-square&color=ff3b30" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/mohrcon/killswitch?style=flat-square" alt="License"></a>
  <a href="https://github.com/mohrcon/killswitch/stargazers"><img src="https://img.shields.io/github/stars/mohrcon/killswitch?style=flat-square" alt="Stars"></a>
</p>

<p align="center">
  <img src="assets/demo.gif" alt="Killswitch Demo" width="600">
</p>

---

## Das Problem

> "Kannst du deinen Bildschirm teilen?"

Und plötzlich sieht das ganze Meeting deine WhatsApp-Nachrichten, den offenen Job-Portal-Tab und die Tinder-Notification.

**Killswitch löst das.** Definiere Profile, drück einen Hotkey, fertig. Alle Apps die niemand sehen soll sind in unter einer Sekunde geschlossen.

## Features

- ⚡ **Ein Klick, alles weg** – Profile mit beliebig vielen Apps
- ⌨️ **Globale Hotkeys** – funktionieren aus jeder App heraus
- 📊 **Live Status** – sieh welche Apps laufen (CPU/RAM)
- 🔒 **100% lokal** – keine Cloud, kein Tracking, kein Account
- ⚙️ **Simple Config** – eine Textdatei, das war's
- 🛠️ **Open Source** – MIT License, forever free

## Installation

### One-Liner (empfohlen)

```bash
curl -fsSL https://raw.githubusercontent.com/mohrcon/killswitch/main/install.sh | zsh
```

brew tap mohrcon/tap
brew install killswitch
```

### Manuell

```bash
git clone https://github.com/mohrcon/killswitch.git
cd killswitch
chmod +x install.sh
./install.sh
```

## Voraussetzungen

- **macOS** (getestet auf Ventura, Sonoma, Sequoia)
- **[SwiftBar](https://swiftbar.app)** – für das Menüleisten-Icon (`brew install --cask swiftbar`)
- **[Hammerspoon](https://www.hammerspoon.org)** – optional, für globale Hotkeys (`brew install --cask hammerspoon`)

## Quick Start

Nach der Installation erscheint ein ⚡ in deiner Menüleiste. Klick drauf und du siehst deine Profile.

### Profile anpassen

Öffne `~/.killswitch/profiles.ini`:

```ini
[Settings]
editor = TextEdit
kill_mode = force        # force = sofort | quit = sanft beenden

[ScreenSharing]
hotkey = ctrl+alt+cmd+s
apps = WhatsApp, Messages, Tinder, Discord, ChatGPT, Spotify

[Focus]
hotkey = ctrl+alt+cmd+f
apps = Slack, MSTeams, Mail, Messages, WhatsApp

[MeetingEnde]
hotkey = ctrl+alt+cmd+m
apps = zoom.us, MSTeams, krisp, Webex
```

### Den richtigen App-Namen finden

App-Namen müssen exakt so heißen wie macOS sie kennt. Nutze die Diagnose:

```bash
killswitch --diagnose
```

Das zeigt dir alle laufenden Apps mit ihren korrekten Namen.

### Hotkeys (mit Hammerspoon)

| Hotkey | Aktion |
|--------|--------|
| `⌃⌥⌘S` | Screen Sharing Profil |
| `⌃⌥⌘F` | Focus Profil |
| `⌃⌥⌘M` | Meeting Ende |
| `⌃⌥⌘K` | Alles Aus (Notfall) |

Hotkeys sind frei konfigurierbar in `~/.hammerspoon/init.lua`.

## CLI

```bash
killswitch                  # Interaktive Profilauswahl
killswitch ScreenSharing    # Profil direkt ausführen
killswitch --list           # Alle Profile anzeigen
killswitch --diagnose       # Prozessnamen anzeigen
```

## FAQ

**Werden Apps wirklich geschlossen oder nur versteckt?**
Geschlossen. Kill heißt Kill. (Ein "Soft Kill"/Verstecken-Modus ist für v2 geplant.)

**Funktioniert das auch mit Chrome-Tabs?**
Aktuell werden ganze Apps geschlossen, nicht einzelne Tabs. Für Browser empfehlen wir separate Profile oder Browser.

**Muss ich Hammerspoon installieren?**
Nein. Die Menüleiste funktioniert auch ohne. Hammerspoon brauchst du nur für die globalen Hotkeys.

**Ich sehe das ⚡ nicht in der Menüleiste.**
Stelle sicher, dass SwiftBar läuft und auf `~/SwiftBarPlugins/` zeigt (SwiftBar → Preferences → Plugin Folder).

## Contributing

PRs willkommen! Besonders gesucht:

- [ ] Native Swift Menu-Bar-App (eliminiert SwiftBar-Dependency)
- [ ] Apple Shortcuts Integration
- [ ] Kalender-Integration (Auto-Kill bei Meeting-Start)
- [ ] Windows/Linux Port

## License

MIT – siehe [LICENSE](LICENSE).

---

<p align="center">
  Made with ⚡ by <a href="https://www.linkedin.com/in/michaelmohr-sap/">Michael Mohr</a>
</p>
