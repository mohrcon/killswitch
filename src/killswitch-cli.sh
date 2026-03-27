#!/bin/zsh

# ============================================================
# killswitch-cli.sh v3.1 (zsh)
#
# Usage:
#   killswitch                → Interaktiv
#   killswitch Focus          → Profil sofort ausführen
#   killswitch --list         → Alle Profile anzeigen
#   killswitch --diagnose     → Echte Prozessnamen anzeigen
# ============================================================

CONFIG_DIR="$HOME/.killswitch"
CONFIG_FILE="$CONFIG_DIR/profiles.ini"
LOG_FILE="$CONFIG_DIR/killswitch.log"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ Keine Config gefunden: $CONFIG_FILE"
  exit 1
fi

# ============================================================
# HELPERS
# ============================================================
app_is_running() {
  osascript -e "tell application \"System Events\" to (name of processes) contains \"$1\"" 2>/dev/null | grep -q "true"
}

kill_app_fn() {
  local app="$1"
  local mode="$2"
  if [[ "$mode" == "quit" ]]; then
    osascript -e "tell application \"$app\" to quit" 2>/dev/null
    sleep 0.5
  fi
  osascript -e "
    tell application \"System Events\"
      set targetProcs to every process whose name is \"$app\"
      repeat with p in targetProcs
        do shell script \"kill -9 \" & unix id of p
      end repeat
    end tell" 2>/dev/null
  pkill -9 -fi "$app" 2>/dev/null
}

# ============================================================
# PARSE CONFIG
# ============================================================
typeset -a PROFILE_NAMES
typeset -A PROFILE_APPS
KILL_MODE="force"
CURRENT_SECTION=""

while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line##[[:space:]]}"
  line="${line%%[[:space:]]}"
  [[ -z "$line" || "$line" == \#* ]] && continue

  if [[ "$line" =~ '^\[(.+)\]$' ]]; then
    CURRENT_SECTION="${match[1]}"
    [[ "$CURRENT_SECTION" != "Settings" ]] && PROFILE_NAMES+=("$CURRENT_SECTION")
  elif [[ "$CURRENT_SECTION" == "Settings" && "$line" =~ '^kill_mode[[:space:]]*=[[:space:]]*(.+)$' ]]; then
    KILL_MODE="${match[1]}"
  elif [[ "$line" =~ '^apps[[:space:]]*=[[:space:]]*(.+)$' ]]; then
    PROFILE_APPS[$CURRENT_SECTION]="${match[1]}"
  fi
done < "$CONFIG_FILE"

# ============================================================
# FUNCTIONS
# ============================================================
kill_profile() {
  local profile="$1"
  local apps_str="${PROFILE_APPS[$profile]}"

  if [[ -z "$apps_str" ]]; then
    echo "❌ Profil '$profile' nicht gefunden."
    echo "   Verfügbar: ${PROFILE_NAMES[*]}"
    return 1
  fi

  echo "⚡ Profil: $profile (Modus: $KILL_MODE)"
  echo ""

  IFS=',' read -rA apps_arr <<< "$apps_str"
  local killed=0

  for app in "${apps_arr[@]}"; do
    app="${app##[[:space:]]}"
    app="${app%%[[:space:]]}"
    if app_is_running "$app"; then
      kill_app_fn "$app" "$KILL_MODE"
      echo "  ✓ $app beendet"
      ((killed++))
    else
      echo "  - $app (nicht aktiv)"
    fi
  done

  echo ""
  echo "⚡ $killed Apps beendet."
  echo "$(date): CLI – Profil '$profile' ($KILL_MODE, $killed gekillt)" >> "$LOG_FILE"
  osascript -e "display notification \"$killed Apps beendet\" with title \"⚡ $profile\"" 2>/dev/null
}

run_diagnose() {
  echo "⚡ Killswitch Diagnose"
  echo "========================"
  echo ""
  echo "Alle sichtbaren Apps (diese Namen in profiles.ini verwenden):"
  echo ""
  osascript -e 'tell application "System Events" to get name of every process whose background only is false' 2>/dev/null | tr ',' '\n' | sed 's/^ //' | sort
  echo ""
  echo "========================"
  echo "Status deiner konfigurierten Apps:"
  echo ""

  typeset -A seen
  for profile in "${PROFILE_NAMES[@]}"; do
    IFS=',' read -rA apps_arr <<< "${PROFILE_APPS[$profile]}"
    for app in "${apps_arr[@]}"; do
      app="${app##[[:space:]]}"
      app="${app%%[[:space:]]}"
      [[ -n "${seen[$app]}" ]] && continue
      seen[$app]=1
      if app_is_running "$app"; then
        echo "  ✅ $app"
      else
        echo "  ❌ $app  ← NICHT GEFUNDEN, Name prüfen!"
      fi
    done
  done
  echo ""
}

# ============================================================
# MAIN
# ============================================================
case "$1" in
  --list|-l)
    echo "⚡ Killswitch Profile (Modus: $KILL_MODE):"
    echo ""
    for profile in "${PROFILE_NAMES[@]}"; do
      IFS=',' read -rA apps_arr <<< "${PROFILE_APPS[$profile]}"
      echo "  [$profile] (${#apps_arr[@]} Apps)"
      for app in "${apps_arr[@]}"; do
        app="${app##[[:space:]]}"
        app="${app%%[[:space:]]}"
        if app_is_running "$app"; then
          echo "    🟢 $app"
        else
          echo "    ⚪ $app"
        fi
      done
    done
    ;;
  --diagnose|-d)
    run_diagnose
    ;;
  "")
    echo "⚡ Killswitch – Profil wählen (Modus: $KILL_MODE):"
    echo ""
    for i in {1..${#PROFILE_NAMES[@]}}; do
      echo "  $i) ${PROFILE_NAMES[$i]}"
    done
    echo ""
    read "choice?Nummer eingeben (oder 'q' zum Abbrechen): "
    [[ "$choice" == "q" ]] && exit 0
    if [[ "$choice" -ge 1 && "$choice" -le ${#PROFILE_NAMES[@]} ]]; then
      echo ""
      kill_profile "${PROFILE_NAMES[$choice]}"
    else
      echo "❌ Ungültige Auswahl."
      exit 1
    fi
    ;;
  *)
    kill_profile "$1"
    ;;
esac
