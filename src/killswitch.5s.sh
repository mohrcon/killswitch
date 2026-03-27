#!/bin/zsh

# <xbar.title>App Killswitch Pro</xbar.title>
# <xbar.version>v3.1</xbar.version>
# <xbar.author>Michael Mohr</xbar.author>
# <xbar.desc>Profile-based killswitch (zsh/macOS native)</xbar.desc>

CONFIG_DIR="$HOME/.killswitch"
CONFIG_FILE="$CONFIG_DIR/profiles.ini"
LOG_FILE="$CONFIG_DIR/killswitch.log"

# ============================================================
# ENSURE CONFIG EXISTS
# ============================================================
if [[ ! -f "$CONFIG_FILE" ]]; then
  mkdir -p "$CONFIG_DIR"
  cat > "$CONFIG_FILE" << 'DEFAULTCONF'
[Settings]
editor = sublime_text
kill_mode = force

[Focus]
hotkey = ctrl+alt+cmd+f
apps = krisp, Slack, MSTeams, zoom.us

[AllesAus]
hotkey = ctrl+alt+cmd+k
apps = krisp, Claude, zoom.us, MSTeams, Slack, Safari
DEFAULTCONF
  echo "$(date): Config erstellt unter $CONFIG_FILE" >> "$LOG_FILE"
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
  # Force kill via System Events
  osascript -e "
    tell application \"System Events\"
      set targetProcs to every process whose name is \"$app\"
      repeat with p in targetProcs
        do shell script \"kill -9 \" & unix id of p
      end repeat
    end tell" 2>/dev/null
  # Fallback
  pkill -9 -fi "$app" 2>/dev/null
}

get_app_stats() {
  local app="$1"
  local cpu=$(ps aux | grep -i "$app" | grep -v grep | awk '{sum += $3} END {printf "%.1f", sum}')
  local mem=$(ps aux | grep -i "$app" | grep -v grep | awk '{sum += $4} END {printf "%.1f", sum}')
  echo "${cpu:-0.0}% / ${mem:-0.0}%"
}

# ============================================================
# PARSE CONFIG
# ============================================================
typeset -a PROFILE_NAMES
typeset -A PROFILE_APPS
typeset -A PROFILE_HOTKEYS
EDITOR_APP=""
KILL_MODE="force"
CURRENT_SECTION=""

while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line##[[:space:]]}"
  line="${line%%[[:space:]]}"
  [[ -z "$line" || "$line" == \#* ]] && continue

  if [[ "$line" =~ '^\[(.+)\]$' ]]; then
    CURRENT_SECTION="${match[1]}"
    [[ "$CURRENT_SECTION" != "Settings" ]] && PROFILE_NAMES+=("$CURRENT_SECTION")
  elif [[ "$CURRENT_SECTION" == "Settings" ]]; then
    if [[ "$line" =~ '^editor[[:space:]]*=[[:space:]]*(.+)$' ]]; then
      EDITOR_APP="${match[1]}"
    elif [[ "$line" =~ '^kill_mode[[:space:]]*=[[:space:]]*(.+)$' ]]; then
      KILL_MODE="${match[1]}"
    fi
  elif [[ "$line" =~ '^apps[[:space:]]*=[[:space:]]*(.+)$' ]]; then
    PROFILE_APPS[$CURRENT_SECTION]="${match[1]}"
  elif [[ "$line" =~ '^hotkey[[:space:]]*=[[:space:]]*(.+)$' ]]; then
    PROFILE_HOTKEYS[$CURRENT_SECTION]="${match[1]}"
  fi
done < "$CONFIG_FILE"

# ============================================================
# COLLECT ALL UNIQUE APPS + COUNT RUNNING
# ============================================================
typeset -A ALL_APPS
for profile in "${PROFILE_NAMES[@]}"; do
  IFS=',' read -rA apps_arr <<< "${PROFILE_APPS[$profile]}"
  for app in "${apps_arr[@]}"; do
    app="${app##[[:space:]]}"
    app="${app%%[[:space:]]}"
    [[ -n "$app" ]] && ALL_APPS[$app]=1
  done
done

RUNNING_COUNT=0
for app in "${(k)ALL_APPS[@]}"; do
  app_is_running "$app" && ((RUNNING_COUNT++))
done

# ============================================================
# HANDLE --kill-profile <profilename>
# ============================================================
if [[ "$1" == "--kill-profile" ]]; then
  shift
  TARGET_PROFILE="$*"
  IFS=',' read -rA apps_arr <<< "${PROFILE_APPS[$TARGET_PROFILE]}"
  KILL_COUNT=0
  KILLED=""
  for app in "${apps_arr[@]}"; do
    app="${app##[[:space:]]}"
    app="${app%%[[:space:]]}"
    if app_is_running "$app"; then
      kill_app_fn "$app" "$KILL_MODE"
      KILLED="$KILLED $app"
      ((KILL_COUNT++))
    fi
  done
  echo "$(date): Profil '$TARGET_PROFILE' ($KILL_MODE). Gekillt:$KILLED" >> "$LOG_FILE"
  osascript -e "display notification \"$KILL_COUNT Apps beendet\" with title \"⚡ $TARGET_PROFILE\" sound name \"Purr\""
  exit 0
fi

# ============================================================
# HANDLE --kill-app <appname>
# ============================================================
if [[ "$1" == "--kill-app" ]]; then
  shift
  APP_TO_KILL="$*"
  kill_app_fn "$APP_TO_KILL" "$KILL_MODE"
  echo "$(date): App '$APP_TO_KILL' gekillt ($KILL_MODE)" >> "$LOG_FILE"
  osascript -e "display notification \"$APP_TO_KILL beendet\" with title \"⚡ Killswitch\" sound name \"Purr\""
  exit 0
fi

# ============================================================
# MENU BAR ICON
# ============================================================
if [[ "$RUNNING_COUNT" -gt 0 ]]; then
  echo "⚡ $RUNNING_COUNT"
else
  echo "⚡"
fi

echo "---"

if [[ "$KILL_MODE" == "force" ]]; then
  echo "Modus: ⚡ Force Kill | color=orange"
else
  echo "Modus: 🕊️ Sanft Beenden | color=blue"
fi
echo "---"

# ============================================================
# PROFILE SECTION
# ============================================================
for profile in "${PROFILE_NAMES[@]}"; do
  IFS=',' read -rA apps_arr <<< "${PROFILE_APPS[$profile]}"
  ACTIVE=0
  TOTAL=${#apps_arr[@]}
  for app in "${apps_arr[@]}"; do
    app="${app##[[:space:]]}"
    app="${app%%[[:space:]]}"
    app_is_running "$app" && ((ACTIVE++))
  done

  HOTKEY_LABEL=""
  [[ -n "${PROFILE_HOTKEYS[$profile]}" ]] && HOTKEY_LABEL="  [${PROFILE_HOTKEYS[$profile]}]"

  echo "🔴 $profile ($ACTIVE/$TOTAL aktiv)$HOTKEY_LABEL | color=red bash='$0' param1=--kill-profile param2=$profile terminal=false refresh=true"

  for app in "${apps_arr[@]}"; do
    app="${app##[[:space:]]}"
    app="${app%%[[:space:]]}"
    if app_is_running "$app"; then
      STATS=$(get_app_stats "$app")
      echo "-- 🟢 $app ($STATS) | bash='$0' param1=--kill-app param2=$app terminal=false refresh=true"
    else
      echo "-- ⚪ $app | color=gray"
    fi
  done
done

echo "---"
echo "🔍 Diagnose | bash='$0' param1=--diagnose terminal=true"
if [[ -n "$EDITOR_APP" ]]; then
  echo "📋 Log | bash=open param1=-a param2=$EDITOR_APP param3=$LOG_FILE terminal=false"
  echo "⚙️  Profile bearbeiten ($EDITOR_APP) | bash=open param1=-a param2=$EDITOR_APP param3=$CONFIG_FILE terminal=false"
else
  echo "📋 Log | bash=open param1=$LOG_FILE terminal=false"
  echo "⚙️  Profile bearbeiten | bash=open param1=$CONFIG_FILE terminal=false"
fi
echo "🔄 Refresh | refresh=true"
