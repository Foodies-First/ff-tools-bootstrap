# FF Tools — put a Windows laptop back the way it was, so the installer can be
# tried again from scratch. Run in PowerShell (no admin needed):
#
#   irm https://raw.githubusercontent.com/Foodies-First/ff-tools-bootstrap/main/uninstall.ps1 | iex
#
# Removes, after asking: the tools installed for this user (Node, Google Cloud CLI,
# GitHub CLI under %LOCALAPPDATA%\ff-tools), the PATH entries they added, the cached
# GitHub token, and the ff-tools folder. Leaves alone: Git, Claude Code, and anything
# you installed yourself.
#
# It refuses to delete the repo folder if it holds work that was never pushed.

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$Base = Join-Path $env:LOCALAPPDATA "ff-tools"
$RepoDir = Join-Path (Join-Path $HOME "code") "ff-tools"
$TokenCache = Join-Path (Join-Path $HOME ".ff-tools") "github-token.json"
$Force = $env:FF_FORCE -eq "1"

function Step($m) { Write-Host ""; Write-Host "▶ $m" -ForegroundColor Cyan }
function Ok($m) { Write-Host "  ✓ $m" -ForegroundColor Green }
function Note($m) { Write-Host "  · $m" -ForegroundColor Gray }

Write-Host "FF Tools — clean slate" -ForegroundColor White

# 1. Unpushed work is the only thing here that cannot be recovered.
Step "Checking for work that was never sent"
$unpushed = $false
if (Test-Path (Join-Path $RepoDir ".git")) {
  Push-Location $RepoDir
  try {
    $ErrorActionPreference = "Continue"
    $dirty = (git status --porcelain 2> $null | Measure-Object -Line).Lines
    $ahead = (git log --branches --not --remotes --oneline 2> $null | Measure-Object -Line).Lines
    $ErrorActionPreference = "Stop"
    if ($dirty -gt 0 -or $ahead -gt 0) {
      $unpushed = $true
      Write-Host "  ! $dirty unsaved file(s) and $ahead commit(s) that were never sent to Edouard." -ForegroundColor Yellow
    } else { Ok "nothing unsent" }
  } finally { Pop-Location }
} else { Ok "no ff-tools folder" }

if ($unpushed -and -not $Force) {
  Write-Host ""
  Write-Host "Stopping here so nothing is lost. Say 'send it to Edouard' in Claude first," -ForegroundColor Yellow
  Write-Host "or run again with FF_FORCE=1 to throw that work away:" -ForegroundColor Yellow
  Write-Host '   $env:FF_FORCE=1; irm https://raw.githubusercontent.com/Foodies-First/ff-tools-bootstrap/main/uninstall.ps1 | iex' -ForegroundColor Gray
  exit 1
}

# 2. The tools this installer put there, for this user only.
Step "Removing what the installer added"
foreach ($p in @($Base, $TokenCache, $RepoDir)) {
  if (Test-Path $p) { Remove-Item $p -Recurse -Force; Ok "removed $p" } else { Note "already gone: $p" }
}

# 3. PATH entries pointing at those folders.
Step "Cleaning PATH"
$user = [Environment]::GetEnvironmentVariable("Path", "User")
if ($user) {
  $kept = ($user -split ";" | Where-Object { $_ -and ($_ -notlike "$Base*") }) -join ";"
  if ($kept -ne $user) { [Environment]::SetEnvironmentVariable("Path", $kept, "User"); Ok "removed the FF Tools entries" } else { Note "nothing to remove" }
}

Write-Host ""
Write-Host "Done. Close this window, open a new PowerShell, and start again from the portal:" -ForegroundColor White
Write-Host "  https://tools.foodies-first.com/t/build" -ForegroundColor Gray
Write-Host "Your Google sign-in was left in place. To sign out of that too: gcloud auth revoke --all" -ForegroundColor Gray
