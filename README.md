# ff-tools-bootstrap

One-line laptop installer for colleagues who build tools on **FF Tools**, Foodies First's internal
tooling platform (private repository `Foodies-First/ff-tools`). This repository is public only so
the installer can be fetched before that private repository is cloned. It contains no secrets and
no company data.

**Windows** (PowerShell, no admin rights):

```powershell
irm https://raw.githubusercontent.com/Foodies-First/ff-tools-bootstrap/main/install.ps1 | iex
```

**macOS** (Terminal, no admin password):

```bash
curl -fsSL https://raw.githubusercontent.com/Foodies-First/ff-tools-bootstrap/main/install.sh | bash
```

What it does, skipping anything already present: checks git · installs Node 22, the Google Cloud
CLI and the GitHub CLI **for the current user only** (no system-wide changes) · signs you in to
Google (one browser approval; no GitHub account — pushing goes through the platform's GitHub App) · clones `ff-tools` into `~/code/ff-tools` and runs its
setup. Safe to run again.

Node downloads are verified against the official SHA-256 list. Google Cloud CLI and GitHub CLI
come from their vendors' release channels. Review the scripts before running them; they are short.

Testing the installer itself without signing in or cloning: set `FF_SKIP_LOGIN=1`.

**Starting over.** `uninstall.ps1` puts a Windows laptop back as it was — it removes the per-user
tools, the PATH entries, the cached token and the `ff-tools` folder, and leaves Git, Claude Code and
your Google sign-in alone. It stops if the folder holds work that was never sent to Edouard, unless
you set `FF_FORCE=1`.

```powershell
irm https://raw.githubusercontent.com/Foodies-First/ff-tools-bootstrap/main/uninstall.ps1 | iex
```

Maintainer: Edouard Schneiders. Colleagues: see `ONBOARDING.md` in `ff-tools`.
