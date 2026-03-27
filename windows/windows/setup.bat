@echo off
echo ============================================================
echo  ⚡ Killswitch Setup (Windows)
echo ============================================================
echo.

:: Create config directory
set "CONFIGDIR=%APPDATA%\Killswitch"
if not exist "%CONFIGDIR%" mkdir "%CONFIGDIR%"
echo ✓ Config-Ordner erstellt: %CONFIGDIR%

:: Copy default config if not exists
if not exist "%CONFIGDIR%\profiles.ini" (
    copy /Y "%~dp0profiles.ini" "%CONFIGDIR%\profiles.ini" >nul
    echo ✓ Default Profile installiert
) else (
    echo ℹ️  profiles.ini existiert bereits, wird nicht überschrieben
)

:: Copy exe to program files or local
set "APPDIR=%LOCALAPPDATA%\Killswitch"
if not exist "%APPDIR%" mkdir "%APPDIR%"
if exist "%~dp0Killswitch.exe" (
    copy /Y "%~dp0Killswitch.exe" "%APPDIR%\Killswitch.exe" >nul
    echo ✓ Killswitch.exe installiert: %APPDIR%
) else (
    echo ⚠️  Killswitch.exe nicht gefunden im aktuellen Ordner
    echo    Bitte manuell nach %APPDIR% kopieren
)

:: Create Start Menu shortcut
set "STARTMENU=%APPDATA%\Microsoft\Windows\Start Menu\Programs"
if exist "%APPDIR%\Killswitch.exe" (
    powershell -Command "$s=(New-Object -COM WScript.Shell).CreateShortcut('%STARTMENU%\Killswitch.lnk');$s.TargetPath='%APPDIR%\Killswitch.exe';$s.Description='Killswitch - Screen Sharing Privacy';$s.Save()"
    echo ✓ Startmenü-Verknüpfung erstellt
)

:: Optional: Autostart
echo.
set /p AUTOSTART="Killswitch beim Windows-Start automatisch starten? (j/n): "
if /i "%AUTOSTART%"=="j" (
    set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
    if exist "%APPDIR%\Killswitch.exe" (
        powershell -Command "$s=(New-Object -COM WScript.Shell).CreateShortcut('%STARTUP%\Killswitch.lnk');$s.TargetPath='%APPDIR%\Killswitch.exe';$s.Description='Killswitch';$s.Save()"
        echo ✓ Autostart aktiviert
    )
)

echo.
echo ============================================================
echo ⚡ Killswitch erfolgreich installiert!
echo.
echo    Tray-Icon:    ⚡ im System Tray (unten rechts)
echo    Profile:      %CONFIGDIR%\profiles.ini
echo    Hotkeys:      Ctrl+Alt+Win+S = Screen Sharing
echo                  Ctrl+Alt+Win+F = Focus
echo                  Ctrl+Alt+Win+M = Meeting Ende
echo                  Ctrl+Alt+Win+K = Alles Aus
echo.
echo    Tipp: Rechtsklick auf ⚡ → Diagnose
echo    um die richtigen Prozessnamen zu finden.
echo ============================================================
echo.

:: Start Killswitch
if exist "%APPDIR%\Killswitch.exe" (
    start "" "%APPDIR%\Killswitch.exe"
    echo ⚡ Killswitch gestartet!
)

pause
