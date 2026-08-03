<#
.SYNOPSIS
Runs isolated fictional-fixture tests for the production CHKDSK collector.

.NOTES
No native executable or diagnostic command is started by this test file.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$MainScript = Join-Path $ProjectRoot 'PC-Full-Check.ps1'
$ProductionScript = Join-Path $ProjectRoot 'internal\ChkdskProduction.ps1'
$IntegratedValidator = Join-Path $PSScriptRoot 'run-integrated-chkdsk-validation.ps1'
$ManifestPath = Join-Path $ProjectRoot 'docs\public-file-manifest.txt'
$script:Passed = 0
$script:Failed = 0
$script:NativeCallCount = 0
$script:CapturedExecutable = $null
$script:CapturedArguments = @()
$script:CapturedTimeout = $null

function Test-ChkdskRule {
    param([string]$Name, [scriptblock]$Test)
    try {
        if ((& $Test) -ne $true) { throw 'Assertion returned false.' }
        $script:Passed++
        Write-Host ('CHKDSK PASS: ' + $Name) -ForegroundColor Green
    }
    catch {
        $script:Failed++
        Write-Host ('CHKDSK FAIL: ' + $Name + ' - ' + $_.Exception.Message) -ForegroundColor Red
    }
}

function New-NativeFixture {
    param(
        [bool]$Available = $true,
        [bool]$ProcessStarted = $true,
        [bool]$TimedOut = $false,
        [AllowNull()]$NativeExitCode = 0,
        [string]$StandardOutput = '',
        [string]$StandardError = '',
        [string]$FailureKind = 'Completed'
    )
    return [pscustomobject]@{
        Available = $Available
        ProcessStarted = $ProcessStarted
        Started = $ProcessStarted
        TimedOut = $TimedOut
        NativeExitCode = $NativeExitCode
        ExitCode = $NativeExitCode
        StandardOutput = $StandardOutput
        StdOut = $StandardOutput
        StandardOutputPresent = -not [string]::IsNullOrWhiteSpace($StandardOutput)
        StandardOutputLength = $StandardOutput.Length
        StandardError = $StandardError
        StdErr = $StandardError
        StandardErrorPresent = -not [string]::IsNullOrWhiteSpace($StandardError)
        StandardErrorLength = $StandardError.Length
        FailureKind = $FailureKind
        Error = ''
        DurationMilliseconds = 1234
        WorkingDirectory = '<project-root>'
        ResolvedExecutableName = 'chkdsk.exe'
        UseShellExecute = $false
        CreateNoWindow = $true
        RedirectStandardOutput = $true
        RedirectStandardError = $true
        AsynchronousStreamReading = $true
        WaitForExitAfterAsyncRead = $true
        ExitCodeCapturedBeforeDispose = $true
        LastExitCodeUsed = $false
    }
}

foreach ($path in @($MainScript, $ProductionScript, $IntegratedValidator)) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) { Write-Host ('CHKDSK FAIL: parser errors in ' + $path) -ForegroundColor Red; exit 1 }
}

$source = Get-Content -Raw -LiteralPath $MainScript
$productionSource = Get-Content -Raw -LiteralPath $ProductionScript
$validatorSource = Get-Content -Raw -LiteralPath $IntegratedValidator
. $ProductionScript

$mainTokens = $null
$mainErrors = $null
$mainAst = [System.Management.Automation.Language.Parser]::ParseFile($MainScript, [ref]$mainTokens, [ref]$mainErrors)
foreach ($functionName in @(
    'New-CheckOutcome', 'New-Definition', 'New-PrivacyOnlyOmittedDefinition', 'Get-CheckDefinitions', 'Get-CheckProgressText',
    'Get-StatusCount',
    'Get-CompletionExitCode', 'Get-Assessment'
)) {
    $node = $mainAst.FindAll({ param($item) $item -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $item.Name -eq $functionName }, $true) | Select-Object -First 1
    if ($null -eq $node) { Write-Host ('CHKDSK FAIL: missing function ' + $functionName) -ForegroundColor Red; exit 1 }
    . ([scriptblock]::Create($node.Extent.Text))
}

# Replace only the shared native helper and volume selector with fictional fixtures.
function Invoke-PCFCNativeProcess {
    param([string]$FilePath, [string[]]$Arguments, [int]$TimeoutSeconds, [string]$WorkingDirectory)
    $script:NativeCallCount++
    $script:CapturedExecutable = $FilePath
    $script:CapturedArguments = @($Arguments)
    $script:CapturedTimeout = $TimeoutSeconds
    return $script:NativeFixture
}

function Get-WindowsSystemVolume {
    return [pscustomobject]@{ Volume = 'Z:'; SelectionMethod = 'Fictional structured system-volume fixture' }
}

$privacyContext = [pscustomobject]@{ SensitiveMode = $false; OutputDirectory = $ProjectRoot }
$script:NativeFixture = New-NativeFixture -NativeExitCode 0
$baseline = Invoke-ChkdskOnlineScan -Context $privacyContext

Test-ChkdskRule 'Only one maintained CHKDSK collector exists' {
    $collectorCount = @(Get-Content -LiteralPath $ManifestPath | Where-Object { $_ -match '\.ps1$' } | ForEach-Object {
        $text = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot $_)
        ([regex]::Matches($text, '(?im)^function\s+Invoke-ChkdskOnlineScan\s*\{')).Count
    } | Measure-Object -Sum).Sum
    return $collectorCount -eq 1
}
Test-ChkdskRule 'Full manifest calls the shared production collector' {
    return $source -match "New-Definition 'ChkdskOnlineScan'.+Invoke-ChkdskOnlineScan" -and $source -match 'internal\\ChkdskProduction\.ps1'
}
Test-ChkdskRule 'Integrated validator calls the production collector without duplicating native logic' {
    return $validatorSource -match '\. \$ProductionScript' -and $validatorSource -match 'Invoke-ChkdskOnlineScan -Context' -and
        $validatorSource -notmatch 'ProcessStartInfo|ReadToEndAsync|\.Start\(\)'
}
Test-ChkdskRule 'Main and integrated validator share the production native helper' {
    return $productionSource -match 'function Invoke-PCFCNativeProcess' -and
        $productionSource -match 'Invoke-PCFCNativeProcess.+chkdsk\.exe' -and
        $validatorSource -match "ProductionNativeHelper = 'Invoke-PCFCNativeProcess'"
}
Test-ChkdskRule 'All approved native names resolve directly inside the trusted Windows system directory' {
    $systemDirectory = [System.IO.Path]::GetFullPath([Environment]::SystemDirectory).TrimEnd([char[]]@([char]92, [char]47))
    foreach ($name in @('powercfg.exe', 'dism.exe', 'sfc.exe', 'chkdsk.exe')) {
        $resolved = Resolve-PCFCTrustedWindowsExecutable -FileName $name
        if ([string]::IsNullOrWhiteSpace($resolved)) { return $false }
        if (-not ([System.IO.Path]::GetDirectoryName($resolved).TrimEnd([char[]]@([char]92, [char]47))).Equals($systemDirectory, [System.StringComparison]::OrdinalIgnoreCase)) { return $false }
        if (-not ([System.IO.Path]::GetFileName($resolved)).Equals($name, [System.StringComparison]::OrdinalIgnoreCase)) { return $false }
    }
    return $true
}
Test-ChkdskRule 'Unsupported and path-like executable values are rejected' {
    foreach ($value in @('cmd.exe', '.\chkdsk.exe', '..\chkdsk.exe', 'folder/chkdsk.exe', 'chkdsk', ' chkdsk.exe')) {
        if ($null -ne (Resolve-PCFCTrustedWindowsExecutable -FileName $value)) { return $false }
    }
    return $true
}
Test-ChkdskRule 'An earlier same-named PATH fixture is never selected' {
    $fixtureRoot = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot 'temp\pcfc-trusted-resolver-fixture'))
    $expectedRoot = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot 'temp\pcfc-trusted-resolver-fixture'))
    $projectPrefix = [System.IO.Path]::GetFullPath($ProjectRoot).TrimEnd([char[]]@([char]92, [char]47)) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $fixtureRoot.Equals($expectedRoot, [System.StringComparison]::OrdinalIgnoreCase) -or -not $fixtureRoot.StartsWith($projectPrefix, [System.StringComparison]::OrdinalIgnoreCase)) { return $false }
    if (Test-Path -LiteralPath $fixtureRoot) { return $false }
    [void](New-Item -ItemType Directory -Path $fixtureRoot -ErrorAction Stop)
    $fakeExecutable = Join-Path $fixtureRoot 'powercfg.exe'
    try {
        [System.IO.File]::WriteAllText($fakeExecutable, 'fictional non-executable fixture')
        $originalPath = $env:PATH
        try {
            $env:PATH = $fixtureRoot + [System.IO.Path]::PathSeparator + $originalPath
            $resolved = Resolve-PCFCTrustedWindowsExecutable -FileName 'powercfg.exe'
        }
        finally { $env:PATH = $originalPath }
        return -not [string]::IsNullOrWhiteSpace($resolved) -and -not $resolved.Equals($fakeExecutable, [System.StringComparison]::OrdinalIgnoreCase)
    }
    finally {
        $fixtureItem = Get-Item -LiteralPath $fixtureRoot -Force -ErrorAction Stop
        if ($fixtureItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { throw 'Refusing to clean an unexpected reparse-point fixture.' }
        if (Test-Path -LiteralPath $fakeExecutable -PathType Leaf) { Remove-Item -LiteralPath $fakeExecutable -Force }
        if (@(Get-ChildItem -LiteralPath $fixtureRoot -Force).Count -eq 0) { Remove-Item -LiteralPath $fixtureRoot -Force }
    }
}
Test-ChkdskRule 'Native selection source has no PATH or Get-Command fallback' {
    $selectionBlock = [regex]::Match($productionSource, '(?s)function Resolve-PCFCTrustedWindowsExecutable.*?function New-PCFCNativeResult').Value
    $nativeBlock = [regex]::Match($productionSource, '(?s)function Invoke-PCFCNativeProcess.*?function Get-WindowsSystemVolume').Value
    return $selectionBlock -match '\[Environment\]::SystemDirectory' -and $selectionBlock -match '\[System\.IO\.Path\]::GetFullPath' -and
        $selectionBlock -notmatch 'Get-Command|\$env:PATH' -and $nativeBlock -match 'Resolve-PCFCTrustedWindowsExecutable' -and
        $nativeBlock -notmatch 'CommandType Application|\$env:PATH'
}
Test-ChkdskRule 'CHKDSK uses only verified volume and scan arguments' {
    return $script:CapturedExecutable -eq 'chkdsk.exe' -and $script:CapturedArguments.Count -eq 2 -and
        $script:CapturedArguments[0] -eq 'Z:' -and $script:CapturedArguments[1] -eq '/scan' -and $script:CapturedTimeout -eq 900
}
Test-ChkdskRule 'No CHKDSK repair option exists' {
    return $productionSource -notmatch '(?i)[''"]/(?:f|r|x|b|spotfix)[''"]' -and -not $baseline.Data.RepairCommandUsed
}
Test-ChkdskRule 'PowerShell 5.1 argument serialization leaves simple CHKDSK arguments unquoted' {
    return (ConvertTo-PCFCNativeArgument -Argument 'C:') -eq 'C:' -and (ConvertTo-PCFCNativeArgument -Argument '/scan') -eq '/scan'
}
Test-ChkdskRule 'Safe argument metadata uses a volume placeholder' {
    return @($baseline.Data.SafeArguments).Count -eq 2 -and $baseline.Data.SafeArguments[0] -eq '<verified-system-volume>' -and
        $baseline.Data.SafeArguments[1] -eq '/scan' -and $baseline.Data.PSObject.Properties.Name -notcontains 'SystemVolume'
}
Test-ChkdskRule 'Process-start and timeout metadata are recorded' {
    return $baseline.Data.ProcessStarted -and -not $baseline.Data.TimedOut -and $baseline.Data.DurationMilliseconds -eq 1234
}
Test-ChkdskRule 'stdout and stderr presence and lengths are recorded without raw data' {
    $script:NativeFixture = New-NativeFixture -NativeExitCode 0 -StandardOutput 'fictional output' -StandardError ''
    $result = Invoke-ChkdskOnlineScan -Context $privacyContext
    return $result.Data.StandardOutputPresent -and $result.Data.StandardOutputLength -eq 16 -and
        -not $result.Data.StandardErrorPresent -and $result.Data.StandardErrorLength -eq 0 -and
        $result.Data.PSObject.Properties.Name -notcontains 'StandardOutput' -and
        $result.Data.PSObject.Properties.Name -notcontains 'StandardError' -and -not $result.Data.RawOutputSaved
}
Test-ChkdskRule 'Native process parity flags are retained' {
    return -not $baseline.Data.ProcessStartInfo.UseShellExecute -and $baseline.Data.ProcessStartInfo.CreateNoWindow -and
        $baseline.Data.ProcessStartInfo.RedirectStandardOutput -and $baseline.Data.ProcessStartInfo.RedirectStandardError -and
        $baseline.Data.ProcessStartInfo.AsynchronousStreamReading -and $baseline.Data.ProcessStartInfo.WaitForExitAfterAsyncRead -and
        -not $baseline.Data.ProcessStartInfo.LastExitCodeUsed
}
Test-ChkdskRule 'Missing executable yields Unavailable' {
    $script:NativeFixture = New-NativeFixture -Available $false -ProcessStarted $false -NativeExitCode $null -FailureKind 'MissingExecutable'
    $result = Invoke-ChkdskOnlineScan -Context $privacyContext
    return $result.Status -eq 'Unavailable' -and -not $result.Data.ProcessStarted -and $null -eq $result.Data.NativeExitCode
}
Test-ChkdskRule 'Exit code zero cannot pass when timeout is true' {
    $script:NativeFixture = New-NativeFixture -ProcessStarted $true -TimedOut $true -NativeExitCode 0 -FailureKind 'Timeout'
    $result = Invoke-ChkdskOnlineScan -Context $privacyContext
    return $result.Status -eq 'Failed' -and $result.Message -match 'timeout'
}
Test-ChkdskRule 'Exit code zero cannot pass when process did not start' {
    $script:NativeFixture = New-NativeFixture -ProcessStarted $false -NativeExitCode 0 -FailureKind 'ProcessStartFailure'
    $result = Invoke-ChkdskOnlineScan -Context $privacyContext
    return $result.Status -eq 'Failed' -and $result.Message -match 'could not start'
}
Test-ChkdskRule 'Process-start failure does not imply filesystem damage' {
    $script:NativeFixture = New-NativeFixture -ProcessStarted $false -NativeExitCode $null -FailureKind 'ProcessStartFailure'
    $result = Invoke-ChkdskOnlineScan -Context $privacyContext
    return $result.Status -eq 'Failed' -and $result.Message -match 'could not start' -and $result.Message -notmatch '(?i)corrupt|damage'
}
Test-ChkdskRule 'Incomplete timeout termination cannot produce Passed' {
    $script:NativeFixture = New-NativeFixture -ProcessStarted $true -TimedOut $true -NativeExitCode $null -FailureKind 'TimeoutTerminationIncomplete'
    $result = Invoke-ChkdskOnlineScan -Context $privacyContext
    return $result.Status -eq 'Failed' -and $result.Data.FailureKind -eq 'TimeoutTerminationIncomplete' -and $result.Message -match 'timeout'
}
Test-ChkdskRule 'Non-zero native exit remains Failed with metadata' {
    $script:NativeFixture = New-NativeFixture -NativeExitCode 7 -StandardOutput 'fictional output'
    $result = Invoke-ChkdskOnlineScan -Context $privacyContext
    return $result.Status -eq 'Failed' -and $result.ExitCode -eq 7 -and $result.Data.NativeExitCode -eq 7 -and
        $result.Data.FailureKind -eq 'Completed' -and $result.Message -match 'non-zero' -and -not $result.Critical
}
Test-ChkdskRule 'Successful result requires started, no timeout, and native exit zero' {
    $script:NativeFixture = New-NativeFixture -ProcessStarted $true -TimedOut $false -NativeExitCode 0
    $result = Invoke-ChkdskOnlineScan -Context $privacyContext
    return $result.Status -eq 'Passed' -and $result.Data.Status -eq 'Passed' -and $result.Data.Message -eq $result.Message
}
Test-ChkdskRule 'Privacy-mode progress accurately identifies all eight omissions' {
    $names = @('EnergyReport', 'BatteryReport', 'SleepStudy', 'SleepDiagnostics', 'MSInfo32', 'DxDiag', 'DeviceRegistration', 'LicenseDetails')
    $allDefinitions = @(Get-CheckDefinitions -SelectedMode Full)
    $definitions = @($allDefinitions | Where-Object { $names -contains $_.Name })
    if ($allDefinitions.Count -ne 32 -or $definitions.Count -ne 8) { return $false }
    foreach ($definition in $definitions) {
        if ((Get-CheckProgressText -Context $privacyContext -Definition $definition) -notmatch '^Omitt') { return $false }
    }
    return $true
}
Test-ChkdskRule 'Omitted raw entries have no executable collector in privacy-only mode' {
    $names = @('EnergyReport', 'BatteryReport', 'SleepStudy', 'SleepDiagnostics', 'MSInfo32', 'DxDiag', 'DeviceRegistration', 'LicenseDetails')
    $definitions = @(Get-CheckDefinitions -SelectedMode Full | Where-Object { $names -contains $_.Name })
    $before = $script:NativeCallCount
    foreach ($definition in $definitions) {
        $result = & $definition.Action $privacyContext
        if ($result.Status -ne 'Omitted' -or $result.Message -notmatch 'unavailable in v0\.1\.0-beta') { return $false }
    }
    return $script:NativeCallCount -eq $before
}
Test-ChkdskRule 'A Failed Full check preserves process exit code 1' {
    $results = @(
        [pscustomobject]@{ Name = 'FictionalPassed'; Status = 'Passed'; Critical = $false },
        [pscustomobject]@{ Name = 'ChkdskOnlineScan'; Status = 'Failed'; Critical = $false }
    )
    return (Get-CompletionExitCode -Results $results) -eq 1
}
Test-ChkdskRule 'Full summary status categories remain distinct' {
    $results = @(
        [pscustomobject]@{ Name = 'One'; Status = 'Passed'; Critical = $false },
        [pscustomobject]@{ Name = 'Two'; Status = 'Warning'; Critical = $false },
        [pscustomobject]@{ Name = 'Three'; Status = 'Failed'; Critical = $false },
        [pscustomobject]@{ Name = 'Four'; Status = 'Unavailable'; Critical = $false },
        [pscustomobject]@{ Name = 'Five'; Status = 'Omitted'; Critical = $false }
    )
    $context = [pscustomobject]@{ Results = $results }
    return (Get-StatusCount $results 'Passed') -eq 1 -and (Get-StatusCount $results 'Warning') -eq 1 -and
        (Get-StatusCount $results 'Failed') -eq 1 -and (Get-StatusCount $results 'Unavailable') -eq 1 -and
        (Get-StatusCount $results 'Omitted') -eq 1 -and (Get-Assessment -Context $context) -eq 'Unknown'
}

$total = $script:Passed + $script:Failed
Write-Host ('CHKDSK_TOTAL={0}; PASSED={1}; FAILED={2}' -f $total, $script:Passed, $script:Failed)
if ($script:Failed -gt 0) { exit 1 }
exit 0
