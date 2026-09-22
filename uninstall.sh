#!/usr/bin/env bash
# FF Tools — put a Mac back the way it was, so the installer can be tried again:
#
#   curl -fsSL https://raw.githubusercontent.com/Foodies-First/ff-tools-bootstrap/main/uninstall.sh | bash
#
# Removes the tools installed for this user (~/.ff-tools), their PATH lines, the
# cached GitHub token and the ff-tools folder. Leaves git, Claude Code and your
# Google sign-in alone. Refuses if the folder holds work that was never sent.
set -euo pipefail

BASE="$HOME/.ff-tools"
REPO_DIR="$HOME/code/ff-tools"
TOKEN_CACHE="$HOME/.ff-tools/github-token.json"
RC="${FF_SHELL_RC:-$HOME/.zshrc}"
FORCE="${FF_FORCE:-0}"

step() { printf '\n\033[36m▶ %s\033[0m\n' "$1"; }
ok()   { printf '  \033[32m✓ %s\033[0m\n' "$1"; }
note() { printf '  \033[90m· %s\033[0m\n' "$1"; }

printf 'FF Tools — clean slate\n'

step "Checking for work that was never sent"
if [ -d "$REPO_DIR/.git" ]; then
  dirty=$(git -C "$REPO_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  ahead=$(git -C "$REPO_DIR" log --branches --not --remotes --oneline 2>/dev/null | wc -l | tr -d ' ')
  if [ "$dirty" != "0" ] || [ "$ahead" != "0" ]; then
    if [ "$FORCE" != "1" ]; then
      printf '\n  %s unsaved file(s) and %s commit(s) never sent to Edouard.\n' "$dirty" "$ahead" >&2
      printf '  Stopping so nothing is lost. Say "send it to Edouard" in Claude first,\n' >&2
      printf '  or run again with FF_FORCE=1 to throw that work away.\n' >&2
      exit 1
    fi
    note "throwing away $dirty unsaved file(s) and $ahead unsent commit(s) (FF_FORCE=1)"
  else ok "nothing unsent"; fi
else ok "no ff-tools folder"; fi

step "Removing what the installer added"
for p in "$TOKEN_CACHE" "$BASE" "$REPO_DIR"; do
  if [ -e "$p" ]; then rm -rf "$p"; ok "removed $p"; else note "already gone: $p"; fi
done

step "Cleaning the shell profile"
if [ -f "$RC" ] && grep -qsF ".ff-tools" "$RC"; then
  tmp=$(mktemp)
  grep -vF ".ff-tools" "$RC" | grep -v "^# FF Tools$" > "$tmp" && mv "$tmp" "$RC"
  ok "removed the FF Tools lines from $RC"
else note "nothing to remove from $RC"; fi

printf '\nDone. Open a new Terminal and start again from the portal:\n'
printf '  https://tools.foodies-first.com/t/build\n'
printf 'Your Google sign-in was left in place. To sign out of that too: gcloud auth revoke --all\n'
