# FF Tools — laptop installer for Windows. Run once, in PowerShell (no admin needed):
#
#   irm https://raw.githubusercontent.com/Foodies-First/ff-tools-bootstrap/main/install.ps1 | iex
#
# What it does, in order, skipping anything already present:
#   1. checks Git for Windows (Claude Code needs it too — install it if missing)
#   2. installs Node 22 for this user only (official build, checksum verified)
#   3. installs the Google Cloud CLI for this user only (needed to read BigQuery)
#   4. installs the GitHub CLI for this user only (needed to open pull requests)
#   5. signs you in to Google — one browser page (no GitHub account needed)
#   6. clones the ff-tools repository into ~\code\ff-tools and runs its setup
# Nothing here needs administrator rights and nothing is installed system-wide.
# Everything lands under %LOCALAPPDATA%\ff-tools and ~\code\ff-tools.

$ErrorActionPreference = "Stop"
$Base = Join-Path $env:LOCALAPPDATA "ff-tools"
$CodeDir = Join-Path $HOME "code"
$RepoDir = Join-Path $CodeDir "ff-tools"
$Repo = "Foodies-First/ff-tools"
$NodeMajor = 22
$SkipLogin = $env:FF_SKIP_LOGIN -eq "1"   # for testing the installer itself

function Step($m) { Write-Host ""; Write-Host "▶ $m" -ForegroundColor Cyan }
function Ok($m) { Write-Host "  ✓ $m" -ForegroundColor Green }
function Note($m) { Write-Host "  · $m" -ForegroundColor Gray }
function Has($cmd) { return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function AddToUserPath($dir) {
  $user = [Environment]::GetEnvironmentVariable("Path", "User")
  if (-not (($user -split ";") -contains $dir)) { [Environment]::SetEnvironmentVariable("Path", "$dir;$user", "User") }
  if (-not (($env:Path -split ";") -contains $dir)) { $env:Path = "$dir;$env:Path" }
}

New-Item -ItemType Directory -Force -Path $Base, $CodeDir | Out-Null
Write-Host "FF Tools installer · $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor White

# 1. Git ------------------------------------------------------------------
Step "Git"
if (Has git) { Ok (git --version) }
else {
  Write-Host "  Git for Windows is missing. Claude Code needs it as well." -ForegroundColor Yellow
  Write-Host "  Install it from https://git-scm.com/download/win (defaults are fine), then run this installer again." -ForegroundColor Yellow
  exit 1
}

# 2. Node 22 ----------------------------------------------------------------
Step "Node $NodeMajor"
$nodeOk = $false
if (Has node) { try { $nodeOk = [int](node -p "process.versions.node.split('.')[0]") -ge $NodeMajor } catch { $nodeOk = $false } }
if ($nodeOk) { Ok "node $(node -v)" }
else {
  $index = Invoke-RestMethod "https://nodejs.org/dist/index.json"
  $ver = ($index | Where-Object { $_.version -like "v$NodeMajor.*" } | Select-Object -First 1).version
  $zip = "node-$ver-win-x64.zip"
  $tmp = Join-Path $env:TEMP $zip
  Note "downloading $ver"
  Invoke-WebRequest "https://nodejs.org/dist/$ver/$zip" -OutFile $tmp
  $sums = Invoke-RestMethod "https://nodejs.org/dist/$ver/SHASUMS256.txt"
  $expected = (($sums -split "`n" | Where-Object { $_ -like "*$zip*" }) -split "\s+")[0]
  $actual = (Get-FileHash $tmp -Algorithm SHA256).Hash.ToLower()
  if ($actual -ne $expected) { throw "Node download failed its checksum — not installing. Run the installer again." }
  $dest = Join-Path $Base "node"
  if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
  Expand-Archive $tmp -DestinationPath $Base -Force
  Rename-Item (Join-Path $Base "node-$ver-win-x64") $dest
  AddToUserPath $dest
  Ok "node $ver installed for this user"
}

# 3. Google Cloud CLI -------------------------------------------------------
Step "Google Cloud CLI"
if (Has gcloud) { Ok "gcloud present" }
else {
  $zip = Join-Path $env:TEMP "google-cloud-cli.zip"
  Note "downloading (this one is large, a minute or two)"
  Invoke-WebRequest "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-windows-x86_64-bundled-python.zip" -OutFile $zip
  $sdk = Join-Path $Base "google-cloud-sdk"
  if (Test-Path $sdk) { Remove-Item $sdk -Recurse -Force }
  Expand-Archive $zip -DestinationPath $Base -Force
  & (Join-Path $sdk "install.bat") --quiet --usage-reporting false --path-update false --command-completion false | Out-Null
  AddToUserPath (Join-Path $sdk "bin")
  Ok "gcloud installed for this user"
}

# 4. GitHub CLI -------------------------------------------------------------
Step "GitHub CLI"
if (Has gh) { Ok "gh present" }
else {
  $rel = Invoke-RestMethod "https://api.github.com/repos/cli/cli/releases/latest"
  $asset = $rel.assets | Where-Object { $_.name -like "gh_*_windows_amd64.zip" } | Select-Object -First 1
  $zip = Join-Path $env:TEMP $asset.name
  Invoke-WebRequest $asset.browser_download_url -OutFile $zip
  $dest = Join-Path $Base "gh"
  if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
  Expand-Archive $zip -DestinationPath $dest -Force
  AddToUserPath (Join-Path $dest "bin")
  Ok "gh $($rel.tag_name) installed for this user"
}

# 5. Sign in — Google only. No GitHub account: pushing goes through the platform's
#    GitHub App, unlocked by this same sign-in (see ff-tools\scripts\git-credential-ff.mjs).
$PlatformUrl = if ($env:FF_TOOLS_URL) { $env:FF_TOOLS_URL.TrimEnd("/") } else { "https://tools.foodies-first.com" }
if (-not $SkipLogin) {
  Step "Google sign-in (a browser page opens — pick your @foodies-first.com account)"
  gcloud auth print-identity-token 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) { gcloud auth login --update-adc --quiet }
  $Account = (gcloud config get-value account 2>$null)
  Ok "signed in as $Account (BigQuery, the dev AI key and GitHub access all use this)"
}

# 6. Clone + setup ----------------------------------------------------------
Step "FF Tools repository"
if (Test-Path (Join-Path $RepoDir ".git")) { Ok "already cloned at $RepoDir" }
elseif ($SkipLogin) { Note "skipping clone (FF_SKIP_LOGIN=1)" }
else {
  # First clone: fetch a one-hour token from the platform with the Google identity token.
  $Idt = (gcloud auth print-identity-token)
  try {
    $Resp = Invoke-RestMethod -Method Post -Uri "$PlatformUrl/api/dev/github-token" -Headers @{ Authorization = "Bearer $Idt" }
  } catch {
    Write-Host "  FF Tools would not give this laptop GitHub access. Ask Edouard whether your Google account is on the allowed domain, and whether the GitHub App is set up." -ForegroundColor Yellow
    exit 1
  }
  git clone -q "https://x-access-token:$($Resp.token)@github.com/$Repo.git" $RepoDir
  Remove-Variable Resp, Idt
  git -C $RepoDir remote set-url origin "https://github.com/$Repo.git"   # no token in the remote URL; the helper supplies it
  Ok "cloned to $RepoDir"
}
if (Test-Path $RepoDir) {
  Push-Location $RepoDir
  try {
    if (-not (Test-Path "node_modules\next")) { Note "installing dependencies (a minute)"; npm install --no-audit --no-fund | Out-Null }
    npm run setup
  } finally { Pop-Location }
}

Write-Host ""
Write-Host "Done. Open Claude, choose the folder $RepoDir, and say what you want to build." -ForegroundColor White
Write-Host "If a terminal was open before this ran, open a new one so it sees the new tools." -ForegroundColor Gray
