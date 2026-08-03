<#
.SYNOPSIS
Runs one Administrator-only final Full privacy-mode validation.

.DESCRIPTION
Safely replaces only local-validation/final-full inside this project, runs the
current maintained Full mode once without sensitive data, verifies required
outputs, runs privacy validation, prints only safe status information, and
writes local-validation/final-full-validation.json.

.NOTES
Windows PowerShell 5.1 compatible. No repair or sensitive-mode command is used.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ProjectRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\')
$LocalValidationRoot = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot 'local-validation')).TrimEnd('\')
$TargetDirectory = [System.IO.Path]::GetFullPath((Join-Path $LocalValidationRoot 'final-full')).TrimEnd('\')
$ValidationResultPath = Join-Path $LocalValidationRoot 'final-full-validation.json'
$MainScript = Join-Path $ProjectRoot 'PC-Full-Check.ps1'
$PrivacyScript = Join-Path $PSScriptRoot 'privacy-validation.ps1'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Stop-FinalValidation {
    param([string]$SafeMessage)
    Write-Host ('ERROR: ' + $SafeMessage) -ForegroundColor Red
    exit 2
}

function Test-ExactPath {
    param([string]$Actual, [string]$Expected)
    return $Actual.Equals($Expected, [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-PathInsideProject {
    param([string]$FullPath)
    $prefix = $script:ProjectRoot + [System.IO.Path]::DirectorySeparatorChar
    return $FullPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function ConvertTo-SafeMessage {
    param([AllowNull()]$Value)
    if ($null -eq $Value) { return '' }
    $message = [string]$Value
    foreach ($privateValue in @([Environment]::UserName, [Environment]::MachineName, [Environment]::GetFolderPath('UserProfile'))) {
        if (-not [string]::IsNullOrWhiteSpace($privateValue)) {
            $message = $message.Replace($privateValue, '[REDACTED]')
        }
    }
    return ($message -replace '[\r\n]+', ' ').Trim()
}

function Write-ValidationJson {
    param($Value)
    $json = $Value | ConvertTo-Json -Depth 12
    [System.IO.File]::WriteAllText($script:ValidationResultPath, $json, $script:Utf8NoBom)
}

if ($env:OS -ne 'Windows_NT') { Stop-FinalValidation 'Windows is required.' }
if ($PSVersionTable.PSVersion -lt [Version]'5.1') { Stop-FinalValidation 'PowerShell 5.1 or later is required.' }
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Stop-FinalValidation 'Run this validation script from Windows PowerShell as Administrator.'
}

if (-not (Test-PathInsideProject -FullPath $LocalValidationRoot) -or -not (Test-PathInsideProject -FullPath $TargetDirectory)) {
    Stop-FinalValidation 'The validation paths are outside the project.'
}
if (-not (Test-ExactPath -Actual (Split-Path -Parent $TargetDirectory) -Expected $LocalValidationRoot)) {
    Stop-FinalValidation 'The final Full target has an unexpected parent path.'
}
if (-not (Test-ExactPath -Actual (Split-Path -Leaf $TargetDirectory) -Expected 'final-full')) {
    Stop-FinalValidation 'The final Full target name is invalid.'
}
if (-not (Test-Path -LiteralPath $MainScript -PathType Leaf) -or -not (Test-Path -LiteralPath $PrivacyScript -PathType Leaf)) {
    Stop-FinalValidation 'A required project script is missing.'
}

try {
    if (-not (Test-Path -LiteralPath $LocalValidationRoot -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $LocalValidationRoot -ErrorAction Stop)
    }
    $localItem = Get-Item -LiteralPath $LocalValidationRoot -Force -ErrorAction Stop
    if (($localItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        Stop-FinalValidation 'The local-validation directory cannot be a reparse point.'
    }

    if (Test-Path -LiteralPath $TargetDirectory) {
        $targetItem = Get-Item -LiteralPath $TargetDirectory -Force -ErrorAction Stop
        if (-not $targetItem.PSIsContainer) { Stop-FinalValidation 'The final Full target is not a directory.' }
        if (-not (Test-ExactPath -Actual $targetItem.FullName.TrimEnd('\') -Expected $TargetDirectory)) {
            Stop-FinalValidation 'The existing final Full directory did not resolve to the exact target.'
        }
        if (($targetItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            Stop-FinalValidation 'The final Full target cannot be a reparse point.'
        }
        # This is the only recursive deletion authorized by this validator.
        Remove-Item -LiteralPath $TargetDirectory -Recurse -Force -ErrorAction Stop
    }
}
catch {
    Stop-FinalValidation 'Safe preparation of the final Full directory failed.'
}

Set-Location -LiteralPath $ProjectRoot
$timer = [System.Diagnostics.Stopwatch]::StartNew()
$diagnosticOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File '.\PC-Full-Check.ps1' -Mode Full -OutputPath '.\local-validation\final-full' 2>&1)
$diagnosticExitCode = $LASTEXITCODE
$timer.Stop()

$requiredNames = @('00_HEALTH_SUMMARY.html', '00_HEALTH_SUMMARY.json', '00_READ_ME.txt', 'run.log')
$requiredFiles = [ordered]@{}
foreach ($name in $requiredNames) {
    $requiredFiles[$name] = [bool](Test-Path -LiteralPath (Join-Path $TargetDirectory $name) -PathType Leaf)
}
$allRequiredFilesPresent = @($requiredFiles.Values | Where-Object { -not $_ }).Count -eq 0

$summaryParsed = $false
$summary = $null
if ($requiredFiles['00_HEALTH_SUMMARY.json']) {
    try {
        $summary = Get-Content -Raw -LiteralPath (Join-Path $TargetDirectory '00_HEALTH_SUMMARY.json') | ConvertFrom-Json
        $summaryParsed = $true
    }
    catch { $summaryParsed = $false }
}

$privacyExitCode = $null
$privacyFilesScanned = $null
$confirmedFindings = $null
$potentialFindings = $null
$ignoredFindings = $null
if ($summaryParsed) {
    $privacyOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File '.\tests\privacy-validation.ps1' -ReportPath '.\local-validation\final-full' 2>&1)
    $privacyExitCode = $LASTEXITCODE
    foreach ($line in $privacyOutput) {
        if ($line -match '^FILES_SCANNED=(\d+)$') { $privacyFilesScanned = [int]$Matches[1] }
        elseif ($line -match '^CONFIRMED_FINDINGS=(\d+)$') { $confirmedFindings = [int]$Matches[1] }
        elseif ($line -match '^POTENTIAL_REVIEW=(\d+)$') { $potentialFindings = [int]$Matches[1] }
        elseif ($line -match '^HARMLESS_OR_IGNORED=(\d+)$') { $ignoredFindings = [int]$Matches[1] }
    }
}

$statusCounts = [ordered]@{ Passed = 0; Warning = 0; Failed = 0; Unavailable = 0; Omitted = 0 }
$safeChecks = @()
$chkdsk = $null
if ($summaryParsed) {
    foreach ($check in @($summary.Checks)) {
        if ($statusCounts.Contains($check.Status)) { $statusCounts[$check.Status]++ }
        $safeMessage = ConvertTo-SafeMessage -Value $check.Message
        $safeChecks += [pscustomobject][ordered]@{
            Name = $check.Name
            Status = $check.Status
            Message = $safeMessage
            ExitCode = $check.ExitCode
        }
        if ($check.Name -eq 'ChkdskOnlineScan') {
            $chkdsk = [pscustomobject][ordered]@{
                Status = $check.Status
                NativeExitCode = if ($check.Data -and $null -ne $check.Data.NativeExitCode) { $check.Data.NativeExitCode } else { $check.ExitCode }
                ProcessStarted = if ($check.Data) { $check.Data.ProcessStarted } else { $null }
                TimedOut = if ($check.Data) { $check.Data.TimedOut } else { $null }
                DurationMilliseconds = if ($check.Data) { $check.Data.DurationMilliseconds } else { $null }
                StandardOutputPresent = if ($check.Data) { $check.Data.StandardOutputPresent } else { $null }
                StandardOutputLength = if ($check.Data) { $check.Data.StandardOutputLength } else { $null }
                StandardErrorPresent = if ($check.Data) { $check.Data.StandardErrorPresent } else { $null }
                StandardErrorLength = if ($check.Data) { $check.Data.StandardErrorLength } else { $null }
                VerifiedSystemVolume = if ($check.Data) { $check.Data.VerifiedSystemVolume } else { $null }
                RawOutputSaved = if ($check.Data) { $check.Data.RawOutputSaved } else { $null }
                RepairCommandUsed = if ($check.Data) { $check.Data.RepairCommandUsed } else { $null }
            }
        }
    }
}

$expectedDiagnosticExitCode = if ($statusCounts.Failed -gt 0) { 1 } else { 0 }
$exitCodeConsistent = $summaryParsed -and $diagnosticExitCode -eq $expectedDiagnosticExitCode
$privacyPassed = $privacyExitCode -eq 0 -and $confirmedFindings -eq 0 -and $potentialFindings -eq 0
$validationPassed = $allRequiredFilesPresent -and $summaryParsed -and $privacyPassed -and $exitCodeConsistent

$validationRecord = [pscustomobject][ordered]@{
    Timestamp = [DateTime]::Now.ToString('o')
    ToolVersion = '0.1.0-beta'
    Mode = 'Full'
    SensitiveDataIncluded = $false
    Command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\PC-Full-Check.ps1 -Mode Full -OutputPath .\local-validation\final-full'
    DurationSeconds = [math]::Round($timer.Elapsed.TotalSeconds, 3)
    DiagnosticExitCode = $diagnosticExitCode
    ExpectedDiagnosticExitCode = $expectedDiagnosticExitCode
    ExitCodeConsistent = $exitCodeConsistent
    RequiredFiles = [pscustomobject]$requiredFiles
    AllRequiredFilesPresent = $allRequiredFilesPresent
    SummaryJsonParsed = $summaryParsed
    Assessment = if ($summaryParsed) { $summary.Assessment } else { $null }
    Counts = [pscustomobject]$statusCounts
    ChkdskOnlineScan = $chkdsk
    PrivacyValidation = [pscustomobject][ordered]@{
        ExitCode = $privacyExitCode
        FilesScanned = $privacyFilesScanned
        ConfirmedFindings = $confirmedFindings
        PotentialReview = $potentialFindings
        HarmlessOrIgnored = $ignoredFindings
        Passed = $privacyPassed
    }
    SafeChecks = $safeChecks
    ValidationPassed = $validationPassed
    RepairCommandUsed = $false
    SensitiveModeUsed = $false
}

try { Write-ValidationJson -Value $validationRecord } catch { Stop-FinalValidation 'The final validation record could not be written.' }

Write-Host ('FULL_DURATION_SECONDS={0}' -f $validationRecord.DurationSeconds)
Write-Host ('FULL_EXIT_CODE={0}' -f $diagnosticExitCode)
Write-Host ('REQUIRED_FILES_PRESENT={0}' -f $allRequiredFilesPresent)
Write-Host ('SUMMARY_JSON_PARSED={0}' -f $summaryParsed)
Write-Host ('PRIVACY_EXIT_CODE={0}' -f $privacyExitCode)
Write-Host ('CONFIRMED_FINDINGS={0}' -f $confirmedFindings)
Write-Host ('POTENTIAL_REVIEW={0}' -f $potentialFindings)
foreach ($status in @('Passed', 'Warning', 'Failed', 'Unavailable', 'Omitted')) {
    Write-Host ('{0}={1}' -f $status.ToUpperInvariant(), $statusCounts[$status])
}
foreach ($check in @($safeChecks | Where-Object { $_.Status -ne 'Passed' })) {
    Write-Host ('CHECK; Name={0}; Status={1}; Message={2}' -f $check.Name, $check.Status, $check.Message)
}

if (-not $validationPassed) { exit 2 }
if ($statusCounts.Failed -gt 0) { exit 1 }
exit 0
