param(
    [string]$Binary = "$PSScriptRoot\..\..\build\profiles-tests\release\ProfilesTest.exe",
    [string]$QtDir = 'C:\Qt\6.11.3\msvc2022_64'
)
$ErrorActionPreference = 'Stop'
$env:PATH = "$QtDir\bin;$PSScriptRoot\..\..\libs\windows\lib\x64;$env:PATH"
$env:QT_QPA_PLATFORM = 'offscreen'
# Each scenario gets a fresh process, matching the app's process-local profile selection.
$scenarios = @('migrationPreservesSettings', 'automaticMigrationAndLegacyBase',
    'profileIsolationAndLaunchSelection', 'launchArgumentsHaveOneSettingsSource', 'matchingUsesChosenMonitor', 'pickerLoadsUnifiedProfiles')
foreach ($scenario in $scenarios) {
    $report = Join-Path (Split-Path (Split-Path $Binary -Parent) -Parent) "$scenario.txt"
    & $Binary $scenario -o "$report,txt"
    if ($LASTEXITCODE -ne 0) { throw "Profile scenario failed: $scenario" }
    Get-Content -LiteralPath $report
}
