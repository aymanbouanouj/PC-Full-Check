<#
.SYNOPSIS
Runs one isolated Administrator-only validation of the production CHKDSK path.

.DESCRIPTION
Loads the same internal collector and native-process helper used by Full mode,
runs exactly one read-only system-volume /scan, and writes safe metadata only to
local-validation/integrated-chkdsk. It never invokes a diagnostic mode.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ProjectRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\')
$LocalValidationRoot = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot 'local-validation')).TrimEnd('\')
$TargetDirectory = [System.IO.Path]::GetFullPath((Join-Path $LocalValidationRoot 'integrated-chkdsk')).TrimEnd('\')
$ProductionScript = Join-Path $ProjectRoot 'internal\ChkdskProduction.ps1'
$PrivacyScript = Join-Path $PSScriptRoot 'privacy-validation.ps1'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Stop-IntegratedValidation {
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

if ($env:OS -ne 'Windows_NT') { Stop-IntegratedValidation 'Windows is required.' }
if ($PSVersionTable.PSVersion -lt [Version]'5.1') { Stop-IntegratedValidation 'Windows PowerShell 5.1 or later is required.' }
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Stop-IntegratedValidation 'Run this validation script from Windows PowerShell as Administrator.'
}

if (-not (Test-PathInsideProject -FullPath $LocalValidationRoot) -or -not (Test-PathInsideProject -FullPath $TargetDirectory)) {
    Stop-IntegratedValidation 'The validation paths are outside the project.'
}
if (-not (Test-ExactPath -Actual (Split-Path -Parent $TargetDirectory) -Expected $LocalValidationRoot)) {
    Stop-IntegratedValidation 'The integrated CHKDSK target has an unexpected parent path.'
}
if (-not (Test-ExactPath -Actual (Split-Path -Leaf $TargetDirectory) -Expected 'integrated-chkdsk')) {
    Stop-IntegratedValidation 'The integrated CHKDSK target name is invalid.'
}
if (-not (Test-Path -LiteralPath $ProductionScript -PathType Leaf)) {
    Stop-IntegratedValidation 'The production CHKDSK implementation is missing.'
}

try {
    if (-not (Test-Path -LiteralPath $LocalValidationRoot -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $LocalValidationRoot -ErrorAction Stop)
    }
    $localItem = Get-Item -LiteralPath $LocalValidationRoot -Force -ErrorAction Stop
    if (($localItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        Stop-IntegratedValidation 'The local-validation directory cannot be a reparse point.'
    }
    if (Test-Path -LiteralPath $TargetDirectory) {
        $targetItem = Get-Item -LiteralPath $TargetDirectory -Force -ErrorAction Stop
        if (-not $targetItem.PSIsContainer) { Stop-IntegratedValidation 'The target is not a directory.' }
        if (-not (Test-ExactPath -Actual $targetItem.FullName.TrimEnd('\') -Expected $TargetDirectory)) {
            Stop-IntegratedValidation 'The existing target did not resolve to the exact expected path.'
        }
        if (($targetItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            Stop-IntegratedValidation 'The target cannot be a reparse point.'
        }
        Remove-Item -LiteralPath $TargetDirectory -Recurse -Force -ErrorAction Stop
    }
    [void](New-Item -ItemType Directory -Path $TargetDirectory -ErrorAction Stop)
}
catch {
    Stop-IntegratedValidation 'Safe preparation of the integrated validation directory failed.'
}

# Load, then invoke, the exact collector and helper used by the maintained Full manifest.
. $ProductionScript
$context = [pscustomobject]@{
    OutputDirectory = $TargetDirectory
    SensitiveMode = $false
}
$outcome = Invoke-ChkdskOnlineScan -Context $context

$requiredMetadata = @(
    'Executable', 'SafeArguments', 'VerifiedSystemVolume', 'VolumeSelectionMethod',
    'ProcessStarted', 'TimedOut', 'DurationMilliseconds', 'NativeExitCode',
    'FailureKind', 'StandardOutputPresent', 'StandardOutputLength',
    'StandardErrorPresent', 'StandardErrorLength', 'RawOutputSaved',
    'RepairCommandUsed', 'Status', 'Message'
)
$metadataValid = $null -ne $outcome -and $null -ne $outcome.Data
if ($metadataValid) {
    foreach ($name in $requiredMetadata) {
        if ($outcome.Data.PSObject.Properties.Name -notcontains $name) { $metadataValid = $false }
    }
}
if ($metadataValid) {
    $metadataValid = @($outcome.Data.SafeArguments).Count -eq 2 -and
        $outcome.Data.SafeArguments[0] -eq '<verified-system-volume>' -and
        $outcome.Data.SafeArguments[1] -eq '/scan' -and
        $outcome.Data.RawOutputSaved -eq $false -and
        $outcome.Data.RepairCommandUsed -eq $false -and
        $outcome.Data.Status -eq $outcome.Status -and
        $outcome.Data.Message -eq $outcome.Message
}
if (-not $metadataValid) { Stop-IntegratedValidation 'The production collector returned invalid safe metadata.' }

$record = [pscustomobject][ordered]@{
    Timestamp = [DateTime]::Now.ToString('o')
    ValidationType = 'IntegratedProductionChkdsk'
    ProductionScript = 'internal\ChkdskProduction.ps1'
    ProductionCollector = 'Invoke-ChkdskOnlineScan'
    ProductionNativeHelper = 'Invoke-PCFCNativeProcess'
    SensitiveModeUsed = $false
    RepairCommandUsed = $false
    Result = $outcome.Data
}
try {
    $json = $record | ConvertTo-Json -Depth 12
    [System.IO.File]::WriteAllText((Join-Path $TargetDirectory 'result.json'), $json, $Utf8NoBom)
}
catch { Stop-IntegratedValidation 'The safe validation result could not be written.' }

$privacyStatus = 'NotSupportedForStandaloneResult'
$privacyExitCode = $null
if (Test-Path -LiteralPath (Join-Path $TargetDirectory '00_HEALTH_SUMMARY.json') -PathType Leaf) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PrivacyScript -ReportPath $TargetDirectory | Out-Null
    $privacyExitCode = $LASTEXITCODE
    $privacyStatus = if ($privacyExitCode -eq 0) { 'Passed' } else { 'Failed' }
}

Write-Host ('PROCESS_STARTED={0}' -f $outcome.Data.ProcessStarted)
Write-Host ('TIMED_OUT={0}' -f $outcome.Data.TimedOut)
Write-Host ('DURATION_MILLISECONDS={0}' -f $outcome.Data.DurationMilliseconds)
Write-Host ('NATIVE_EXIT_CODE={0}' -f $outcome.Data.NativeExitCode)
Write-Host ('STANDARD_OUTPUT_PRESENT={0}' -f $outcome.Data.StandardOutputPresent)
Write-Host ('STANDARD_ERROR_PRESENT={0}' -f $outcome.Data.StandardErrorPresent)
Write-Host ('STATUS={0}' -f $outcome.Status)
Write-Host ('MESSAGE={0}' -f $outcome.Message)
Write-Host ('PRIVACY_VALIDATION={0}' -f $privacyStatus)

if ($privacyStatus -eq 'Failed') { exit 2 }
if ($outcome.Status -eq 'Passed') { exit 0 }
if ($outcome.Status -eq 'Failed' -and $outcome.Data.FailureKind -notin @('ProcessStartFailure', 'ExecutionFailure')) { exit 1 }
exit 2
