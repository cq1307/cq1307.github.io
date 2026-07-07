param(
  [string]$Domain,
  [string]$GitHubUser
)

$ErrorActionPreference = "Stop"

function Normalize-Domain([string]$Value) {
  $d = ($Value -replace '^https?://', '').Trim().TrimEnd('/')
  $d = $d -replace '\s+', ''
  if (-not $d) { throw "Domain is required." }
  if ($d -match '[/:]') { throw "Use only the domain, for example blog.example.com." }
  return $d.ToLowerInvariant()
}

if (-not $Domain) {
  $Domain = Read-Host "Domain, for example blog.example.com or example.com"
}

if (-not $GitHubUser) {
  $GitHubUser = Read-Host "GitHub username, for example octocat"
}

$Domain = Normalize-Domain $Domain
$GitHubUser = $GitHubUser.Trim()
if (-not $GitHubUser) { throw "GitHub username is required." }

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$cnamePath = Join-Path $root "CNAME"
Set-Content -LiteralPath $cnamePath -Value $Domain -Encoding ASCII

Write-Host ""
Write-Host "CNAME written:"
Write-Host "  $cnamePath"
Write-Host "  $Domain"
Write-Host ""
Write-Host "GitHub Pages:"
Write-Host "  Repository Settings -> Pages -> Custom domain -> $Domain"
Write-Host ""

$labels = $Domain.Split(".")
$isApex = $labels.Count -eq 2

if ($isApex) {
  Write-Host "DNS records for apex domain:"
  Write-Host "  A  @  185.199.108.153"
  Write-Host "  A  @  185.199.109.153"
  Write-Host "  A  @  185.199.110.153"
  Write-Host "  A  @  185.199.111.153"
  Write-Host ""
  Write-Host "Optional www redirect:"
  Write-Host "  CNAME  www  $GitHubUser.github.io"
} else {
  $sub = $labels[0]
  Write-Host "DNS records for subdomain:"
  Write-Host "  CNAME  $sub  $GitHubUser.github.io"
}

Write-Host ""
Write-Host "After DNS works, enable Enforce HTTPS in GitHub Pages."
