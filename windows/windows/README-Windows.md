# ⚡ Killswitch für Windows

## Installation

### Option A: Einfach (empfohlen)

1. Lade `Killswitch.exe` aus den [GitHub Releases](https://github.com/mohrcon/killswitch/releases/latest) herunter
2. Doppelklick → ⚡ erscheint im System Tray (unten rechts)
3. Fertig

### Option B: Mit Setup

1. Lade das Windows-Paket herunter und entpacke es
2. Führe `setup.bat` aus
3. Das Setup installiert Killswitch, erstellt eine Startmenü-Verknüpfung und optional einen Autostart-Eintrag

## Benutzung

- **Rechtsklick** auf ⚡ im Tray → Profile mit Live-Status
- **Klick auf ein Profil** → alle Apps im Profil werden geschlossen
- **Hotkeys** funktionieren global:

| Hotkey | Aktion |
|--------|--------|
| `Ctrl+Alt+Win+S` | Screen Sharing |
| `Ctrl+Alt+Win+F` | Focus |
| `Ctrl+Alt+Win+M` | Meeting Ende |
| `Ctrl+Alt+Win+K` | Alles Aus |

## Profile anpassen

Die Config liegt unter:
```
%APPDATA%\Killswitch\profiles.ini
```

Öffnen: Rechtsklick auf ⚡ → "Profile bearbeiten"

### Prozessnamen finden

Rechtsklick auf ⚡ → **Diagnose**. Das zeigt dir alle laufenden Prozesse mit ihren korrekten Namen.

Alternativ: Task Manager öffnen → Tab "Details" → Spalte "Name" (ohne `.exe`).

### Hotkey-Format

```
^ = Ctrl
! = Alt
# = Win
+ = Shift
```

Beispiel: `^!#s` = Ctrl+Alt+Win+S

## Selbst kompilieren

Falls du das AHK-Script selbst kompilieren willst:

1. Installiere [AutoHotkey v2](https://www.autohotkey.com/)
2. Rechtsklick auf `killswitch.ahk` → "Compile Script"
3. Fertig → `Killswitch.exe` ist erstellt

## Deinstallation

1. Rechtsklick auf ⚡ → "Beenden"
2. Lösche `%LOCALAPPDATA%\Killswitch\`
3. Lösche `%APPDATA%\Killswitch\`
4. Lösche die Startmenü-Verknüpfung falls vorhanden
