#!/bin/zsh

# ============================================================
# ⚡ Killswitch Installer
# curl -fsSL https://raw.githubusercontent.com/mohr-consulting/killswitch/main/install.sh | zsh
# ============================================================

set -e

REPO="mohr-consulting/killswitch"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/$REPO/$BRANCH"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo "${BOLD}⚡ Killswitch Installer${NC}"
echo "========================"
echo ""

# ============================================================
# 1. Check macOS
# ============================================================
if [[ "$(uname)" != "Darwin" ]]; then
  echo "${RED}❌ Killswitch ist nur für macOS.${NC}"
  exit 1
fi

# ============================================================
# 2. Check/Install Homebrew
# ============================================================
if ! command -v brew &>/dev/null; then
  echo "${YELLOW}⚠️  Homebrew nicht gefunden.${NC}"
  echo "   Installiere Homebrew zuerst: https://brew.sh"
  echo ""
  read "install_brew?Homebrew jetzt installieren? (y/n): "
  if [[ "$install_brew" == "y" ]]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    echo "Ohne Homebrew kann SwiftBar nicht automatisch installiert werden."
    echo "Du kannst SwiftBar manuell von https://swiftbar.app laden."
  fi
fi

# ============================================================
# 3. Install SwiftBar
# ============================================================
if ! brew list --cask swiftbar &>/dev/null 2>&1; then
  echo "📦 Installiere SwiftBar..."
  brew install --cask swiftbar
  echo "${GREEN}✓ SwiftBar installiert${NC}"
else
  echo "${GREEN}✓ SwiftBar bereits installiert${NC}"
fi

# ============================================================
# 4. Create directories
# ============================================================
mkdir -p "$HOME/.killswitch"
mkdir -p "$HOME/SwiftBarPlugins"
echo "${GREEN}✓ Verzeichnisse erstellt${NC}"

# ============================================================
# 5. Download files
# ============================================================
echo "📥 Lade Killswitch herunter..."

curl -fsSL "$BASE_URL/src/killswitch-cli.sh" -o "$HOME/.killswitch/killswitch-cli.sh"
chmod +x "$HOME/.killswitch/killswitch-cli.sh"
echo "  ${GREEN}✓${NC} CLI"

curl -fsSL "$BASE_URL/src/killswitch.5s.sh" -o "$HOME/SwiftBarPlugins/killswitch.5s.sh"
chmod +x "$HOME/SwiftBarPlugins/killswitch.5s.sh"
echo "  ${GREEN}✓${NC} SwiftBar Plugin"

# Config nur wenn noch keine existiert
if [[ ! -f "$HOME/.killswitch/profiles.ini" ]]; then
  curl -fsSL "$BASE_URL/src/profiles.ini" -o "$HOME/.killswitch/profiles.ini"
  echo "  ${GREEN}✓${NC} Default Profile"
else
  echo "  ${YELLOW}ℹ️${NC}  profiles.ini existiert bereits, wird nicht überschrieben"
fi

# ============================================================
# 6. Symlink CLI
# ============================================================
if [[ -d "/usr/local/bin" ]]; then
  sudo ln -sf "$HOME/.killswitch/killswitch-cli.sh" /usr/local/bin/killswitch 2>/dev/null || true
  echo "${GREEN}✓ CLI verfügbar als 'killswitch'${NC}"
fi

# ============================================================
# 7. Optional: Hammerspoon Hotkeys
# ============================================================
echo ""
read "setup_hs?Globale Hotkeys einrichten? (braucht Hammerspoon) (y/n): "
if [[ "$setup_hs" == "y" ]]; then
  if ! brew list --cask hammerspoon &>/dev/null 2>&1; then
    echo "📦 Installiere Hammerspoon..."
    brew install --cask hammerspoon
  fi

  mkdir -p "$HOME/.hammerspoon"

  # Prüfen ob schon drin
  if ! grep -q "killswitch" "$HOME/.hammerspoon/init.lua" 2>/dev/null; then
    cat >> "$HOME/.hammerspoon/init.lua" << 'HSEOF'

-- ⚡ Killswitch Hotkeys
local ks = os.getenv("HOME") .. "/.killswitch/killswitch-cli.sh"
hs.hotkey.bind({"ctrl", "alt", "cmd"}, "S", function() hs.execute(ks .. " ScreenSharing", true) end)
hs.hotkey.bind({"ctrl", "alt", "cmd"}, "F", function() hs.execute(ks .. " Focus", true) end)
hs.hotkey.bind({"ctrl", "alt", "cmd"}, "M", function() hs.execute(ks .. " MeetingEnde", true) end)
hs.hotkey.bind({"ctrl", "alt", "cmd"}, "K", function() hs.execute(ks .. " AllesAus", true) end)
HSEOF
    echo "${GREEN}✓ Hammerspoon Hotkeys eingerichtet${NC}"
    echo "  ${YELLOW}→ Starte Hammerspoon und klick 'Reload Config'${NC}"
  else
    echo "${YELLOW}ℹ️  Hotkeys bereits vorhanden${NC}"
  fi
fi

# ============================================================
# 8. Start SwiftBar
# ============================================================
echo ""
echo "🚀 Starte SwiftBar..."
open -a SwiftBar 2>/dev/null || true

# ============================================================
# Done
# ============================================================
echo ""
echo "${BOLD}============================================================${NC}"
echo "${GREEN}${BOLD}⚡ Killswitch erfolgreich installiert!${NC}"
echo ""
echo "   ${BOLD}Menüleiste:${NC}  ⚡ Icon in der Menüleiste"
echo "   ${BOLD}Terminal:${NC}    killswitch --list"
echo "   ${BOLD}Profile:${NC}     ~/.killswitch/profiles.ini"
echo "   ${BOLD}Diagnose:${NC}    killswitch --diagnose"
echo ""
echo "   Beim ersten Start: SwiftBar nach Plugin-Ordner"
echo "   gefragt? Wähle: ~/SwiftBarPlugins/"
echo "${BOLD}============================================================${NC}"
echo ""
echo "Nächster Schritt: ${BOLD}killswitch --diagnose${NC}"
echo "um die richtigen App-Namen für deine Profile zu finden."
echo ""
