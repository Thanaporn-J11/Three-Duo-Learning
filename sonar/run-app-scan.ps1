# Scan the Flutter app with SonarQube.
# Usage (PowerShell, in the app folder):
#   $env:SONAR_TOKEN = "<analysis token of project threeduo-app>"
#   .\sonar\run-app-scan.ps1                      # SonarQube on http://localhost:9000
#   .\sonar\run-app-scan.ps1 -HostUrl http://localhost:9001   # the 10.x fallback server
param([string]$HostUrl = "http://localhost:9000")

if (-not $env:SONAR_TOKEN) { Write-Error "Set `$env:SONAR_TOKEN first"; exit 1 }

flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Tests and coverage for the plugin (a failing test does not stop the scan)
flutter test --machine --coverage | Out-File -Encoding utf8 tests.output

sonar-scanner "-Dsonar.host.url=$HostUrl" "-Dsonar.token=$env:SONAR_TOKEN"

Write-Host "Done. Check 'git status': analysis_options.yaml must be unchanged."
