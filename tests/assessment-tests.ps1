<#
.SYNOPSIS
Runs fictional-fixture assessment consistency tests without diagnostic collection.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$MainScript = Join-Path $ProjectRoot 'PC-Full-Check.ps1'
$FixtureRoot = Join-Path $PSScriptRoot 'fixtures'
$script:Passed = 0
$script:Failed = 0

function Test-Rule {
    param([string]$Name, [scriptblock]$Test)
    try {
        if ((& $Test) -ne $true) { throw 'Assertion returned false.' }
        $script:Passed++
        Write-Host ('ASSESSMENT PASS: ' + $Name) -ForegroundColor Green
    }
    catch {
        $script:Failed++
        Write-Host ('ASSESSMENT FAIL: ' + $Name + ' - ' + $_.Exception.Message) -ForegroundColor Red
    }
}

function New-FictionalResult {
    param([string]$Name, [string]$Status, [bool]$Critical = $false, [string]$Message = '')
    return [pscustomobject]@{ Name = $Name; Status = $Status; Critical = $Critical; Message = $Message }
}

function New-FictionalEssentialResults {
    $names = @('WindowsInfo', 'SystemInfo', 'CPU', 'Memory', 'Display', 'Storage', 'Volumes', 'ProblemDevices', 'Defender')
    return @($names | ForEach-Object { New-FictionalResult -Name $_ -Status 'Passed' })
}

$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($MainScript, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { Write-Host 'ASSESSMENT FAIL: main script did not parse.' -ForegroundColor Red; exit 1 }
$source = Get-Content -Raw -LiteralPath $MainScript

foreach ($functionName in @('New-CheckOutcome', 'Get-StatusCount', 'Get-Assessment', 'Get-BatteryCapacityStatus', 'ConvertTo-OptionalTemperature', 'Get-CompletionExitCode')) {
    $node = $ast.FindAll({ param($item) $item -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $item.Name -eq $functionName }, $true) | Select-Object -First 1
    if ($null -eq $node) { Write-Host ('ASSESSMENT FAIL: missing function ' + $functionName) -ForegroundColor Red; exit 1 }
    . ([scriptblock]::Create($node.Extent.Text))
}

$fixtureSummaries = @{}
foreach ($mode in @('quick', 'standard')) {
    $fixturePath = Join-Path $FixtureRoot ($mode + '-summary.json')
    if (-not (Test-Path -LiteralPath $fixturePath -PathType Leaf)) {
        Write-Host ('ASSESSMENT FAIL: required fictional fixture is missing: ' + ($mode + '-summary.json')) -ForegroundColor Red
        exit 1
    }
    try {
        $fixtureSummaries[$mode] = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Host ('ASSESSMENT FAIL: required fictional fixture is invalid JSON: ' + ($mode + '-summary.json')) -ForegroundColor Red
        exit 1
    }
    if ($fixtureSummaries[$mode].FictionalFixture -ne $true -or $fixtureSummaries[$mode].FixtureNotice -notmatch '^FICTIONAL TEST FIXTURE') {
        Write-Host ('ASSESSMENT FAIL: fixture is not clearly marked fictional: ' + ($mode + '-summary.json')) -ForegroundColor Red
        exit 1
    }
}

Test-Rule 'Null battery health is Unavailable, never Passed' {
    return (Get-BatteryCapacityStatus -EstimatedHealthPercent $null) -eq 'Unavailable'
}
Test-Rule 'Missing reliability telemetry is not treated as healthy telemetry' {
    $fictionalRecords = @([pscustomobject]@{ AvailableTelemetry = @() })
    $usable = @($fictionalRecords | Where-Object { @($_.AvailableTelemetry).Count -gt 0 })
    return $usable.Count -eq 0 -and $source -match 'Status Unavailable -Data \$items -Message ''Windows returned storage reliability records but no usable telemetry fields\.'''
}
Test-Rule 'Zero temperature is normalized to unavailable rather than verified 0 C' {
    return $null -eq (ConvertTo-OptionalTemperature -Value 0) -and (ConvertTo-OptionalTemperature -Value 42) -eq 42
}
Test-Rule 'Unavailable remains distinct from Passed' {
    $unavailable = New-CheckOutcome -Status Unavailable
    $passed = New-CheckOutcome -Status Passed
    return $unavailable.Status -ne $passed.Status
}
Test-Rule 'Omitted remains distinct from Passed' {
    $omitted = New-CheckOutcome -Status Omitted
    $passed = New-CheckOutcome -Status Passed
    return $omitted.Status -ne $passed.Status
}
Test-Rule 'Warning yields Attention required with process exit code 0' {
    $results = @(New-FictionalEssentialResults)
    ($results | Where-Object { $_.Name -eq 'ProblemDevices' }).Status = 'Warning'
    $context = [pscustomobject]@{ Results = $results }
    return (Get-Assessment -Context $context) -eq 'Attention required' -and (Get-CompletionExitCode -Results $results) -eq 0
}
Test-Rule 'Failed check yields process exit code 1' {
    $results = @(New-FictionalEssentialResults)
    $results += New-FictionalResult -Name 'FictionalOptionalCheck' -Status 'Failed'
    return (Get-CompletionExitCode -Results $results) -eq 1
}
Test-Rule 'Fictional Quick and Standard fixtures contain no failed checks' {
    foreach ($mode in @('quick', 'standard')) {
        $summary = $fixtureSummaries[$mode]
        if (@($summary.Checks | Where-Object { $_.Status -eq 'Failed' }).Count -ne 0) { return $false }
    }
    return $true
}
Test-Rule 'Fictional Attention required assessments trace to explicit warnings and expected unavailable evidence' {
    foreach ($mode in @('quick', 'standard')) {
        $summary = $fixtureSummaries[$mode]
        $warnings = @($summary.Checks | Where-Object { $_.Status -eq 'Warning' })
        if ($summary.Assessment -ne 'Attention required' -or $warnings.Count -eq 0) { return $false }
        if (@($warnings | Where-Object { [string]::IsNullOrWhiteSpace($_.Message) }).Count -gt 0) { return $false }
        if ($mode -eq 'standard' -and @($summary.Checks | Where-Object { $_.Status -eq 'Unavailable' }).Count -ne 1) { return $false }
    }
    return $true
}
Test-Rule 'Problem devices prevent an all-clear assessment' {
    $results = @(New-FictionalEssentialResults)
    ($results | Where-Object { $_.Name -eq 'ProblemDevices' }).Status = 'Warning'
    $context = [pscustomobject]@{ Results = $results }
    return (Get-Assessment -Context $context) -eq 'Attention required' -and $source -notmatch '(?i)all hardware is healthy'
}

$total = $script:Passed + $script:Failed
Write-Host ('ASSESSMENT_TOTAL={0}; PASSED={1}; FAILED={2}' -f $total, $script:Passed, $script:Failed)
if ($script:Failed -gt 0) { exit 1 }
exit 0
