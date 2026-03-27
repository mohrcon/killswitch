; ============================================================
; ⚡ Killswitch for Windows (AutoHotkey v2)
; Version: 1.0.0
; Author: Michael Mohr
; License: MIT
;
; Compile to .exe: Ahk2Exe → select this script → done
; ============================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ============================================================
; CONFIG
; ============================================================
global CONFIG_DIR := A_AppData . "\Killswitch"
global CONFIG_FILE := CONFIG_DIR . "\profiles.ini"
global LOG_FILE := CONFIG_DIR . "\killswitch.log"
global Profiles := Map()
global Settings := Map()

; Ensure config dir exists
if !DirExist(CONFIG_DIR)
    DirCreate(CONFIG_DIR)

; Create default config if not exists
if !FileExist(CONFIG_FILE)
    CreateDefaultConfig()

; Parse config
LoadConfig()

; ============================================================
; TRAY MENU
; ============================================================
BuildTrayMenu()

; Set up a timer to refresh the tray every 5 seconds
SetTimer(RefreshTray, 5000)
RefreshTray()

; ============================================================
; GLOBAL HOTKEYS (from config)
; ============================================================
RegisterHotkeys()

; ============================================================
; FUNCTIONS
; ============================================================

CreateDefaultConfig() {
    defaultCfg := "
    (
; ============================================================
; ⚡ KILLSWITCH PROFILE CONFIG (Windows)
; ============================================================
;
; Prozessnamen = wie im Task Manager (ohne .exe)
; Nutze "killswitch --diagnose" oder den Diagnose-Menüpunkt
; um die richtigen Prozessnamen zu sehen.
;
; kill_mode: force = sofort beenden
;            quit  = sanft beenden (WM_CLOSE, dann force)
; ============================================================

[Settings]
editor=notepad
kill_mode=force

; Bevor du deinen Bildschirm teilst: alles Persönliche weg.
[ScreenSharing]
hotkey=^!#s
apps=WhatsApp,Telegram,Discord,Spotify,Claude,ChatGPT

; Deep Work: alle Ablenkungen schliessen.
[Focus]
hotkey=^!#f
apps=Slack,ms-teams,Outlook,WhatsApp,Telegram,Discord

; Meeting ist vorbei? Alles auf einmal beenden.
[MeetingEnde]
hotkey=^!#m
apps=Zoom,ms-teams,Webex

; Panik-Button: ALLES dicht.
[AllesAus]
hotkey=^!#k
apps=Slack,ms-teams,Zoom,Outlook,WhatsApp,Telegram,Discord,Spotify,Claude,ChatGPT,Chrome
    )"
    FileAppend(defaultCfg, CONFIG_FILE)
}

LoadConfig() {
    global Profiles, Settings
    Profiles := Map()
    Settings := Map()
    Settings["editor"] := "notepad"
    Settings["kill_mode"] := "force"

    currentSection := ""
    Loop Read, CONFIG_FILE {
        line := Trim(A_LoopReadLine)
        if (line = "" || SubStr(line, 1, 1) = ";")
            continue

        ; Section header
        if RegExMatch(line, "^\[(.+)\]$", &m) {
            currentSection := m[1]
            if (currentSection != "Settings" && !Profiles.Has(currentSection))
                Profiles[currentSection] := Map("apps", "", "hotkey", "")
            continue
        }

        ; Key=Value
        if RegExMatch(line, "^(\w+)\s*=\s*(.*)$", &m) {
            key := m[1]
            val := Trim(m[2])
            if (currentSection = "Settings") {
                Settings[key] := val
            } else if Profiles.Has(currentSection) {
                Profiles[currentSection][key] := val
            }
        }
    }
}

GetRunningCount() {
    allApps := Map()
    for name, profile in Profiles {
        for app in StrSplit(profile["apps"], ",") {
            app := Trim(app)
            if (app != "")
                allApps[app] := 1
        }
    }

    count := 0
    for app, _ in allApps {
        if ProcessExist(app ".exe")
            count++
    }
    return count
}

BuildTrayMenu() {
    ; Custom tray icon tooltip
    A_IconTip := "⚡ Killswitch"

    ; Build menu
    tray := A_TrayMenu
    tray.Delete()

    ; Mode display
    mode := Settings.Has("kill_mode") ? Settings["kill_mode"] : "force"
    tray.Add("⚡ Modus: " . (mode = "force" ? "Force Kill" : "Sanft Beenden"), (*) => "")
    tray.Disable("⚡ Modus: " . (mode = "force" ? "Force Kill" : "Sanft Beenden"))
    tray.Add()

    ; Profiles
    for name, profile in Profiles {
        apps := StrSplit(profile["apps"], ",")
        active := 0
        total := apps.Length
        for app in apps {
            app := Trim(app)
            if (app != "" && ProcessExist(app ".exe"))
                active++
        }

        hotkeyLabel := ""
        if (profile["hotkey"] != "")
            hotkeyLabel := "  [" . FormatHotkeyLabel(profile["hotkey"]) . "]"

        menuLabel := "🔴 " . name . " (" . active . "/" . total . " aktiv)" . hotkeyLabel
        tray.Add(menuLabel, KillProfileHandler.Bind(name))
    }

    tray.Add()
    tray.Add("🔍 Diagnose", (*) => RunDiagnose())
    tray.Add("📋 Log anzeigen", (*) => Run(Settings.Has("editor") ? Settings["editor"] . " " . LOG_FILE : "notepad " . LOG_FILE))
    tray.Add("⚙️ Profile bearbeiten", (*) => Run(Settings.Has("editor") ? Settings["editor"] . " " . CONFIG_FILE : "notepad " . CONFIG_FILE))
    tray.Add("🔄 Config neu laden", (*) => ReloadConfig())
    tray.Add()
    tray.Add("❌ Beenden", (*) => ExitApp())
}

RefreshTray() {
    count := GetRunningCount()
    A_IconTip := "⚡ Killswitch – " . count . " Apps aktiv"
    BuildTrayMenu()
}

FormatHotkeyLabel(hk) {
    result := hk
    result := StrReplace(result, "^", "Ctrl+")
    result := StrReplace(result, "!", "Alt+")
    result := StrReplace(result, "#", "Win+")
    result := StrReplace(result, "+", "Shift+")
    return result
}

KillProfileHandler(profileName, *) {
    KillProfile(profileName)
}

KillProfile(profileName) {
    if !Profiles.Has(profileName) {
        MsgBox("Profil '" . profileName . "' nicht gefunden.", "Killswitch", "Icon!")
        return
    }

    profile := Profiles[profileName]
    apps := StrSplit(profile["apps"], ",")
    mode := Settings.Has("kill_mode") ? Settings["kill_mode"] : "force"
    killedCount := 0
    killedApps := ""

    for app in apps {
        app := Trim(app)
        if (app = "")
            continue

        pid := ProcessExist(app ".exe")
        if pid {
            if (mode = "quit") {
                ; Try graceful close first
                try {
                    ProcessClose(pid)
                    if ProcessWaitClose(pid,, 1)
                        pid := 0
                }
            }
            ; Force kill if still running
            if pid {
                try {
                    Run('taskkill /F /IM "' . app . '.exe"',, "Hide")
                }
            }
            killedCount++
            killedApps .= (killedApps ? ", " : "") . app
        }
    }

    ; Log
    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    FileAppend(timestamp . " | Profil '" . profileName . "' (" . mode . ") | Gekillt: " . killedApps . "`n", LOG_FILE)

    ; Windows Toast Notification
    TrayTip("⚡ " . profileName, killedCount . " Apps beendet", "Info")

    ; Refresh tray
    RefreshTray()
}

RegisterHotkeys() {
    for name, profile in Profiles {
        hk := profile["hotkey"]
        if (hk != "") {
            try {
                HotKey(hk, KillProfileHotkeyHandler.Bind(name))
            } catch as e {
                ; Invalid hotkey, skip silently
            }
        }
    }
}

KillProfileHotkeyHandler(profileName, *) {
    KillProfile(profileName)
}

RunDiagnose() {
    ; Get all visible windows
    output := "⚡ Killswitch Diagnose`n"
    output .= "========================`n`n"
    output .= "Alle laufenden Prozesse mit sichtbaren Fenstern:`n"
    output .= "(Diese Namen in profiles.ini verwenden, OHNE .exe)`n`n"

    processes := Map()
    for proc in ComObjGet("winmgmts:").ExecQuery("SELECT Name FROM Win32_Process") {
        pName := StrReplace(proc.Name, ".exe", "")
        if !processes.Has(pName)
            processes[pName] := 1
    }

    ; Sort-ish: just list them
    for pName, _ in processes {
        ; Check if it has a visible window
        if WinExist("ahk_exe " . pName . ".exe")
            output .= "  🟢 " . pName . "`n"
    }

    output .= "`n========================`n"
    output .= "Status deiner konfigurierten Apps:`n`n"

    allApps := Map()
    for name, profile in Profiles {
        for app in StrSplit(profile["apps"], ",") {
            app := Trim(app)
            if (app != "" && !allApps.Has(app))
                allApps[app] := 1
        }
    }

    for app, _ in allApps {
        if ProcessExist(app ".exe")
            output .= "  ✅ " . app . " → LÄUFT`n"
        else
            output .= "  ❌ " . app . " → NICHT GEFUNDEN`n"
    }

    ; Show in a temporary file
    diagFile := CONFIG_DIR . "\diagnose.txt"
    if FileExist(diagFile)
        FileDelete(diagFile)
    FileAppend(output, diagFile)
    Run("notepad " . diagFile)
}

ReloadConfig() {
    ; Unregister old hotkeys
    for name, profile in Profiles {
        hk := profile["hotkey"]
        if (hk != "") {
            try HotKey(hk, "Off")
        }
    }

    LoadConfig()
    RegisterHotkeys()
    BuildTrayMenu()
    RefreshTray()
    TrayTip("⚡ Killswitch", "Config neu geladen", "Info")
}
