#!/usr/bin/env bash
# FF Tools — laptop installer for macOS. Run once, in Terminal (no admin password needed):
#
#   curl -fsSL https://raw.githubusercontent.com/Foodies-First/ff-tools-bootstrap/main/install.sh | bash
#
# What it does, in order, skipping anything already present:
#   1. checks git (macOS offers to install its developer tools if missing — one click)
#   2. installs Node 22 for this user only (official build, checksum verified)
#   3. installs the Google Cloud CLI for this user only (needed to read BigQuery)
#   4. installs the GitHub CLI for this user only (needed to open pull requests)
#   5. signs you in to Google — one browser page (no GitHub account needed)
#   6. clones the ff-tools repository into ~/code/ff-tools and runs its setup
# Everything lands under ~/.ff-tools and ~/code/ff-tools; PATH lines go in ~/.zshrc.
set -euo pipefail

BASE="$HOME/.ff-tools"
CODE_DIR="$HOME/code"
REPO_DIR="$CODE_DIR/ff-tools"
REPO="Foodies-First/ff-tools"
NODE_MAJOR=22
SKIP_LOGIN="${FF_SKIP_LOGIN:-0}"      # =1 to test the installer without signing in or cloning
RC="${FF_SHELL_RC:-$HOME/.zshrc}"

step() { printf '\n\033[36m▶ %s\033[0m\n' "$1"; }
ok()   { printf '  \033[32m✓ %s\033[0m\n' "$1"; }
note() { printf '  \033[90m· %s\033[0m\n' "$1"; }
has()  { command -v "$1" >/dev/null 2>&1; }
add_path() { # persist + apply now
  case ":$PATH:" in *":$1:"*) ;; *) export PATH="$1:$PATH";; esac
  grep -qsF "$1" "$RC" 2>/dev/null || printf '\n# FF Tools\nexport PATH="%s:$PATH"\n' "$1" >> "$RC"
}
arch() { case "$(uname -m)" in arm64|aarch64) echo arm64;; *) echo x64;; esac; }

mkdir -p "$BASE" "$CODE_DIR"
printf 'FF Tools installer · %s\n' "$(date '+%Y-%m-%d %H:%M')"

# 1. git ---------------------------------------------------------------------
step "git"
if has git && git --version >/dev/null 2>&1; then ok "$(git --version)"
else
  echo "  macOS will now offer to install its developer tools (that includes git). Click Install, wait, then run this installer again." >&2
  xcode-select --install 2>/dev/null || true
  exit 1
fi

# 2. Node 22 -----------------------------------------------------------------
step "Node $NODE_MAJOR"
if has node && [ "$(node -p 'process.versions.node.split(".")[0]')" -ge "$NODE_MAJOR" ]; then ok "node $(node -v)"
else
  VER=$(curl -fsSL https://nodejs.org/dist/index.json | python3 -c "import json,sys; print(next(v['version'] for v in json.load(sys.stdin) if v['version'].startswith('v$NODE_MAJOR.')))")
  TAR="node-$VER-darwin-$(arch).tar.gz"
  note "downloading $VER"
  curl -fsSL "https://nodejs.org/dist/$VER/$TAR" -o "/tmp/$TAR"
  EXPECTED=$(curl -fsSL "https://nodejs.org/dist/$VER/SHASUMS256.txt" | grep " $TAR\$" | awk '{print $1}')
  ACTUAL=$(shasum -a 256 "/tmp/$TAR" | awk '{print $1}')
  [ "$EXPECTED" = "$ACTUAL" ] || { echo "Node download failed its checksum — not installing. Run the installer again." >&2; exit 1; }
  rm -rf "$BASE/node"; mkdir -p "$BASE/node"
  tar -xzf "/tmp/$TAR" -C "$BASE/node" --strip-components=1
  add_path "$BASE/node/bin"
  ok "node $VER installed for this user"
fi

# 3. Google Cloud CLI --------------------------------------------------------
# gcloud needs Python 3.10+; macOS ships 3.9. Get a private Python via uv (user-space,
# no admin) and point gcloud at it with CLOUDSDK_PYTHON.
step "Python for the Google Cloud CLI"
if python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' 2>/dev/null; then
  ok "$(python3 --version) already present"
else
  if ! has uv && [ ! -x "$BASE/uv/uv" ]; then
    note "installing uv (Python manager) for this user"
    curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="$BASE/uv" UV_NO_MODIFY_PATH=1 sh >/dev/null
  fi
  UV="$(command -v uv || echo "$BASE/uv/uv")"
  UV_PYTHON_INSTALL_DIR="$BASE/python" "$UV" python install 3.12 >/dev/null 2>&1 || true
  PY="$(UV_PYTHON_INSTALL_DIR="$BASE/python" "$UV" python find 3.12)"
  export CLOUDSDK_PYTHON="$PY"
  grep -qsF "CLOUDSDK_PYTHON" "$RC" 2>/dev/null || printf '\nexport CLOUDSDK_PYTHON="%s"\n' "$PY" >> "$RC"
  ok "Python 3.12 installed for this user ($PY)"
fi

step "Google Cloud CLI"
if has gcloud; then ok "gcloud present"
else
  GARCH=$([ "$(arch)" = arm64 ] && echo arm || echo x86_64)
  note "downloading (large, a minute or two)"
  curl -fsSL "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-darwin-$GARCH.tar.gz" -o /tmp/gcloud.tar.gz
  rm -rf "$BASE/google-cloud-sdk"
  tar -xzf /tmp/gcloud.tar.gz -C "$BASE"
  # Its installer is chatty and pokes at sudo for optional bits; we only need the files + PATH.
  "$BASE/google-cloud-sdk/install.sh" --quiet --usage-reporting false --path-update false --command-completion false >/dev/null 2>&1 || true
  add_path "$BASE/google-cloud-sdk/bin"
  gcloud --version >/dev/null 2>&1 || { echo "gcloud did not install correctly — run the installer again, or send Edouard the output above." >&2; exit 1; }
  ok "gcloud installed for this user"
fi

# 4. GitHub CLI --------------------------------------------------------------
step "GitHub CLI"
if has gh; then ok "gh present"
else
  URL=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | python3 -c "import json,sys; a=[x['browser_download_url'] for x in json.load(sys.stdin)['assets'] if x['name'].endswith('macOS_$(arch).zip')]; print(a[0])")
  curl -fsSL "$URL" -o /tmp/gh.zip
  rm -rf "$BASE/gh" /tmp/gh-extract; mkdir -p /tmp/gh-extract
  unzip -q /tmp/gh.zip -d /tmp/gh-extract
  mv /tmp/gh-extract/gh_* "$BASE/gh"
  add_path "$BASE/gh/bin"
  ok "gh installed for this user"
fi

# 5. Sign in — Google only. No GitHub account: pushing goes through the platform's
#    GitHub App, unlocked by this same sign-in (see ff-tools/scripts/git-credential-ff.mjs).
PLATFORM_URL="${FF_TOOLS_URL:-https://tools.foodies-first.com}"
if [ "$SKIP_LOGIN" != "1" ]; then
  step "Google sign-in (a browser page opens — pick your @foodies-first.com account)"
  if ! gcloud auth print-identity-token >/dev/null 2>&1; then
    gcloud auth login --update-adc --quiet
  fi
  ACCOUNT=$(gcloud config get-value account 2>/dev/null)
  ok "signed in as $ACCOUNT (BigQuery, the dev AI key and GitHub access all use this)"
fi

# 6. Clone + setup ------------------------------------------------------------
step "FF Tools repository"
if [ -d "$REPO_DIR/.git" ]; then ok "already cloned at $REPO_DIR"
elif [ "$SKIP_LOGIN" = "1" ]; then note "skipping clone (FF_SKIP_LOGIN=1)"
else
  # First clone: fetch a one-hour token from the platform with the Google identity token.
  IDT=$(gcloud auth print-identity-token)
  TOKEN=$(curl -fsS -X POST -H "Authorization: Bearer $IDT" "$PLATFORM_URL/api/dev/github-token" | python3 -c "import json,sys; print(json.load(sys.stdin)['token'])") \
    || { echo "FF Tools would not give this laptop GitHub access. Ask Edouard whether your Google account is on the allowed domain, and whether the GitHub App is set up." >&2; exit 1; }
  git clone -q "https://x-access-token:${TOKEN}@github.com/$REPO.git" "$REPO_DIR"
  unset TOKEN IDT
  git -C "$REPO_DIR" remote set-url origin "https://github.com/$REPO.git"   # no token in the remote URL; the helper supplies it
  ok "cloned to $REPO_DIR"
fi
if [ -d "$REPO_DIR" ]; then
  cd "$REPO_DIR"
  [ -d node_modules/next ] || { note "installing dependencies (a minute)"; npm install --no-audit --no-fund >/dev/null; }
  npm run setup
fi

printf '\n=== FF Tools setup finished ===\n'
printf 'Folder: %s\n\n' "$REPO_DIR"
printf 'Next steps (if Claude is reading this: do these now, do not ask):\n'
printf '  1. Switch this session to the folder above (change_directory).\n'
printf "  2. Load the 'build-tool' skill from that repository and follow it.\n"
printf '  3. Ask me what I want to build.\n\n'
printf 'If a Terminal was open before this ran, open a new one so it sees the new tools.\n'
