#!/usr/bin/env bash
#
# install.sh — Install the recover skill, scripts, and hooks.

set -euo pipefail

readonly PROG="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

die() { printf '%s: error: %s\n' "$PROG" "$*" >&2; exit 1; }
log() { printf '%s\n' "$*"; }

# --- preflight -------------------------------------------------------------

command -v jq >/dev/null 2>&1 || die "jq is required but not found on PATH"
command -v tmutil >/dev/null 2>&1 || die "tmutil not found (are you on macOS?)"

readonly BIN_DIR="$HOME/.local/bin"
readonly SKILL_DIR="$HOME/.claude/skills/recover"
readonly SETTINGS="$HOME/.claude/settings.json"

# --- scripts ----------------------------------------------------------------

log "Installing scripts to $BIN_DIR..."
mkdir -p "$BIN_DIR"

for script in tm-bisect tm-guard-arm tm-guard-snap tm-guard-cleanup; do
    cp "$SCRIPT_DIR/scripts/$script" "$BIN_DIR/$script"
    chmod +x "$BIN_DIR/$script"
done

# Check PATH
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) log "WARNING: $BIN_DIR is not on your PATH. Add it to your shell config." ;;
esac

# --- skill ------------------------------------------------------------------

log "Installing skill to $SKILL_DIR..."
mkdir -p "$SKILL_DIR"
cp "$SCRIPT_DIR/SKILL.md" "$SKILL_DIR/SKILL.md"

# --- hooks ------------------------------------------------------------------

log "Configuring hooks in $SETTINGS..."

if [ ! -f "$SETTINGS" ]; then
    die "$SETTINGS does not exist. Run Claude Code at least once first."
fi

# Back up settings before modifying.
cp "$SETTINGS" "$SETTINGS.bak"

# Each hook entry we want to add. We check whether tm-guard is already
# present (by grepping the command string) to make the installer
# idempotent.

add_hook() {
    local event="$1"
    local entry="$2"
    local marker="$3"

    if jq -e ".hooks.\"$event\"" "$SETTINGS" >/dev/null 2>&1; then
        # Event exists. Check if our hook is already there.
        if jq -r ".hooks.\"$event\"[]?.hooks[]?.command // empty" "$SETTINGS" \
                | grep -qF "$marker"; then
            log "  $event: already configured"
            return
        fi
        # Append our entry to the existing array.
        jq ".hooks.\"$event\" += [$entry]" "$SETTINGS" > "$SETTINGS.tmp" \
            && mv "$SETTINGS.tmp" "$SETTINGS"
    else
        # Event doesn't exist yet. Create it.
        jq ".hooks.\"$event\" = [$entry]" "$SETTINGS" > "$SETTINGS.tmp" \
            && mv "$SETTINGS.tmp" "$SETTINGS"
    fi
    log "  $event: added"
}

add_hook "UserPromptSubmit" \
    '{"hooks":[{"type":"command","command":"tm-guard-arm","timeout":2}]}' \
    "tm-guard-arm"

add_hook "PreToolUse" \
    '{"matcher":"Bash","hooks":[{"type":"command","command":"tm-guard-snap","timeout":10}]}' \
    "tm-guard-snap"

add_hook "SessionEnd" \
    '{"hooks":[{"type":"command","command":"tm-guard-cleanup","timeout":2}]}' \
    "tm-guard-cleanup"

log ""
log "Done. The /recover skill is now available in Claude Code."
log "Backup of previous settings saved to $SETTINGS.bak"
