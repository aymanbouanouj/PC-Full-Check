<#
.SYNOPSIS
Runs dependency-free static and structural tests for PC Full Check for Windows.

.NOTES
Uses built-in Windows PowerShell capabilities only. It does not run a diagnostic.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$MainScript = Join-Path $ProjectRoot 'PC-Full-Check.ps1'
$EasyRunnerPath = Join-Path $ProjectRoot 'PCFC-Easy-Runner.ps1'
$ProductionScript = Join-Path $ProjectRoot 'internal\ChkdskProduction.ps1'
$IntegratedValidatorPath = Join-Path $PSScriptRoot 'run-integrated-chkdsk-validation.ps1'
$ManifestPath = Join-Path $ProjectRoot 'docs\public-file-manifest.txt'
$LegacyReadmePath = Join-Path $ProjectRoot 'legacy\README.md'
$RootLegacyPath = Join-Path $ProjectRoot 'PC_FULL_CHECK_FIXED.ps1'
$NestedLegacyPath = Join-Path $ProjectRoot 'legacy\PC_FULL_CHECK_FIXED.ps1'
$FixturePaths = @('tests/fixtures/quick-summary.json', 'tests/fixtures/standard-summary.json')
$PublicAuditPaths = @(
    'docs/complete-project-report.md', 'docs/privacy-security-audit.md',
    'docs/static-security-review.md', 'docs/test-coverage-report.md'
)
$LocalAuditPaths = @(
    'local-audit/check-catalog.md', 'local-audit/documentation-consistency-audit.md',
    'local-audit/execution-data-flow.md', 'local-audit/function-call-graph.md',
    'local-audit/function-reference.md', 'local-audit/project-inventory.json',
    'local-audit/report-schema-reference.md', 'local-audit/repository-state-audit.md'
)
$HistoricalLegacyHash = 'C3B0E03C48FE797AF9C2A74778E222C3C4F6AAA1B423012B16E19165918E00D8'
$script:Passed = 0
$script:Failed = 0
$script:NotExecuted = 0

function Test-Case {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Test
    )
    try {
        $result = & $Test
        if ($result -ne $true) { throw 'Assertion returned false.' }
        $script:Passed++
        Write-Host ('PASS: ' + $Name) -ForegroundColor Green
    }
    catch {
        $script:Failed++
        Write-Host ('FAIL: ' + $Name + ' - ' + $_.Exception.Message) -ForegroundColor Red
    }
}

function Add-NotExecuted {
    param([Parameter(Mandatory = $true)][string]$Name, [Parameter(Mandatory = $true)][string]$Reason)
    $script:NotExecuted++
    Write-Host ('NOT EXECUTED: ' + $Name + ' - ' + $Reason) -ForegroundColor Yellow
}

if (-not (Test-Path -LiteralPath $MainScript -PathType Leaf)) {
    Write-Host 'FAIL: Main script is missing; remaining source tests cannot run.' -ForegroundColor Red
    exit 1
}

$source = Get-Content -Raw -LiteralPath $MainScript
$easyRunnerSource = if (Test-Path -LiteralPath $EasyRunnerPath -PathType Leaf) { Get-Content -Raw -LiteralPath $EasyRunnerPath } else { '' }
$productionSource = if (Test-Path -LiteralPath $ProductionScript -PathType Leaf) { Get-Content -Raw -LiteralPath $ProductionScript } else { '' }
$integratedValidatorSource = if (Test-Path -LiteralPath $IntegratedValidatorPath -PathType Leaf) { Get-Content -Raw -LiteralPath $IntegratedValidatorPath } else { '' }
$localUsersBackslash = 'C:' + [char]92 + 'Users' + [char]92
$localUsersSlash = 'C:' + '/' + 'Users' + '/'
$desktopProjectFragment = 'Desktop' + [char]92 + 'PC-Full-Check'
$fileUriPrefix = 'file:' + '//'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($MainScript, [ref]$tokens, [ref]$parseErrors)
$commandNames = @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() } | Where-Object { $_ })

Test-Case 'Main script parses without syntax errors' { return $parseErrors.Count -eq 0 }

$requiredFiles = @(
    'PC-Full-Check.ps1', 'PCFC-Easy-Runner.ps1', 'README.md', 'LICENSE', 'CHANGELOG.md', 'AUTHORS.md', 'CITATION.cff',
    'RELEASE_NOTES.md', 'RELEASE_CHECKLIST.md',
    'SECURITY.md', 'PRIVACY.md', 'CONTRIBUTING.md', 'CODE_OF_CONDUCT.md',
    'BLOCKED_DECISIONS.md', '.gitignore', 'legacy\README.md',
    'docs\audit-before.md', 'docs\architecture.md', 'docs\supported-systems.md',
    'docs\report-guide.md', 'docs\validation-report.md', 'docs\functional-validation.md', 'docs\chkdsk-investigation.md',
    'docs\chkdsk-integration-parity.md', 'docs\public-file-manifest.txt',
    'docs\git-publication-commands.md', 'docs\release-candidate-audit.md', 'docs\USER_GUIDE.md',
    'docs\complete-project-report.md', 'docs\privacy-security-audit.md', 'docs\static-security-review.md',
    'docs\test-coverage-report.md', 'internal\ChkdskProduction.ps1',
    'examples\sanitized-sample-summary.json', 'examples\sanitized-sample-report.txt',
    'tests\run-tests.ps1', 'tests\assessment-tests.ps1', 'tests\chkdsk-tests.ps1',
    'tests\privacy-validation.ps1', 'tests\run-final-full-validation.ps1', 'tests\run-integrated-chkdsk-validation.ps1',
    'tests\fixtures\quick-summary.json', 'tests\fixtures\standard-summary.json'
)
Test-Case 'All required repository files exist' {
    $missing = @($requiredFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $ProjectRoot $_) -PathType Leaf) })
    if ($missing.Count -gt 0) { throw ('Missing: ' + ($missing -join ', ')) }
    return $true
}

Test-Case 'Safe legacy history document records the unpublished baseline' {
    if (-not (Test-Path -LiteralPath $LegacyReadmePath -PathType Leaf)) { return $false }
    $legacyReadme = Get-Content -Raw -LiteralPath $LegacyReadmePath
    return $legacyReadme -match [regex]::Escape($HistoricalLegacyHash) -and
        $legacyReadme -match 'original source is deliberately unpublished' -and
        $legacyReadme -match '\.\./PC-Full-Check\.ps1' -and
        $legacyReadme -match 'No sensitive-mode functionality is available'
}
Test-Case 'Ignored local legacy copies match the baseline when present' {
    foreach ($legacyPath in @($RootLegacyPath, $NestedLegacyPath)) {
        if ((Test-Path -LiteralPath $legacyPath -PathType Leaf) -and
            (Get-FileHash -Algorithm SHA256 -LiteralPath $legacyPath).Hash -ne $HistoricalLegacyHash) { return $false }
    }
    return $true
}
Test-Case 'Legacy ignore rules are exact and do not hide the public history document' {
    $ignoreLines = @(Get-Content -LiteralPath (Join-Path $ProjectRoot '.gitignore'))
    return @($ignoreLines | Where-Object { $_ -ceq '/PC_FULL_CHECK_FIXED.ps1' }).Count -eq 1 -and
        @($ignoreLines | Where-Object { $_ -ceq '/legacy/PC_FULL_CHECK_FIXED.ps1' }).Count -eq 1 -and
        @($ignoreLines | Where-Object { $_ -match '^/legacy/$' }).Count -eq 0
}
Test-Case 'Public legacy history document is not ignored when Git metadata is available' {
    if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot '.git') -PathType Container) -or
        $null -eq (Get-Command git -ErrorAction SilentlyContinue)) { return $true }
    & git -C $ProjectRoot check-ignore -q -- 'legacy/README.md'
    return $LASTEXITCODE -ne 0
}
Test-Case 'Public manifest includes only the source-free legacy history file' {
    $manifestEntries = @(Get-Content -LiteralPath $ManifestPath | ForEach-Object { $_.Trim().Replace('\', '/') } | Where-Object { $_ })
    return @($manifestEntries | Where-Object { $_ -ceq 'legacy/README.md' }).Count -eq 1 -and
        $manifestEntries -notcontains 'PC_FULL_CHECK_FIXED.ps1' -and
        $manifestEntries -notcontains 'legacy/PC_FULL_CHECK_FIXED.ps1'
}

$parameters = @($ast.ParamBlock.Parameters)
$modeParameter = $parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'Mode' } | Select-Object -First 1
$outputParameter = $parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'OutputPath' } | Select-Object -First 1

Test-Case 'Script uses CmdletBinding' { return $source -match '(?m)^\[CmdletBinding\(\)\]' }
Test-Case 'Default mode is Standard' { return $null -ne $modeParameter -and $modeParameter.DefaultValue.Value -eq 'Standard' }
Test-Case 'Public parameters are only Mode and OutputPath' {
    $names = @($parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
    return $names.Count -eq 2 -and $names -contains 'Mode' -and $names -contains 'OutputPath' -and $source -notmatch 'IncludeSensitiveData'
}
Test-Case 'Mode accepts only Quick, Standard, and Full' {
    $attribute = $modeParameter.Attributes | Where-Object { $_.TypeName.Name -eq 'ValidateSet' } | Select-Object -First 1
    $values = @($attribute.PositionalArguments | ForEach-Object { $_.Value })
    return $values.Count -eq 3 -and @($values | Where-Object { $_ -notin @('Quick', 'Standard', 'Full') }).Count -eq 0
}
Test-Case 'OutputPath is an optional string parameter' {
    return $null -ne $outputParameter -and $outputParameter.StaticType -eq [string] -and $null -eq $outputParameter.DefaultValue
}

Test-Case 'Maintained script contains no prohibited destructive command' {
    $prohibitedCommands = @('Remove-Item', 'Clear-Disk', 'Initialize-Disk', 'Format-Volume', 'Repair-Volume', 'Set-ItemProperty', 'New-ItemProperty', 'Remove-ItemProperty', 'Set-Service', 'Stop-Service', 'Disable-ScheduledTask', 'Set-LocalUser', 'Remove-LocalUser')
    if (@($commandNames | Where-Object { $prohibitedCommands -contains $_ }).Count -gt 0) { return $false }
    if ($source -match '(?im)\bsfc(?:\.exe)?\b[^\r\n]*/scannow|\bDISM(?:\.exe)?\b[^\r\n]*/RestoreHealth|\bchkdsk(?:\.exe)?\b[^\r\n]*/[fr](?:\s|$)') { return $false }
    return $true
}
Test-Case 'Maintained script contains no network download or upload command' {
    $networkCommands = @('Invoke-WebRequest', 'Invoke-RestMethod', 'Start-BitsTransfer', 'curl', 'curl.exe', 'wget', 'wget.exe', 'git')
    if (@($commandNames | Where-Object { $networkCommands -contains $_ }).Count -gt 0) { return $false }
    return $source -notmatch '(?i)System\.Net\.WebClient|Download(File|String)|Upload(File|String)|HttpClient'
}
Test-Case 'No hard-coded real username appears in the maintained script' {
    return $source -notmatch '(?i)[A-Z]:\\Users\\(?!Public\\|Default\\|Example\\|Sample\\)[^\\\s''"]+'
}
Test-Case 'No hard-coded real serial or UUID value appears in the maintained script' {
    if ($source -match '(?i)(SerialNumber|SMBIOSAssetTag|UUID)\s*=\s*[''"][^''"]+[''"]') { return $false }
    return $source -notmatch '(?i)[''"][0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}[''"]'
}
Test-Case 'Fictional examples contain no obvious live identifiers' {
    $examples = (Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot 'examples\sanitized-sample-summary.json')) + (Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot 'examples\sanitized-sample-report.txt'))
    $forbidden = '(?i)[A-Z]:\\Users\\|\b[0-9A-F]{2}(?::[0-9A-F]{2}){5}\b|\b(?:\d{1,3}\.){3}\d{1,3}\b|\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b|[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}'
    return $examples -notmatch $forbidden -and $examples -match 'FICTIONAL SANITIZED EXAMPLE'
}
Test-Case 'Assessment suite is independent of local validation artifacts' {
    $assessmentSource = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot 'tests\assessment-tests.ps1')
    return $assessmentSource -notmatch 'local-validation|00_HEALTH_SUMMARY' -and
        $assessmentSource -match 'tests\\fixtures|Join-Path \$PSScriptRoot ''fixtures'''
}
Test-Case 'Both assessment fixtures parse and are clearly fictional' {
    foreach ($relativePath in $FixturePaths) {
        $path = Join-Path $ProjectRoot $relativePath
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
        try { $fixture = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json -ErrorAction Stop } catch { return $false }
        if ($fixture.FictionalFixture -ne $true -or $fixture.FixtureNotice -notmatch '^FICTIONAL TEST FIXTURE - NOT A REAL COMPUTER REPORT$') { return $false }
        if (@($fixture.Checks).Count -eq 0 -or $fixture.Privacy.State -ne 'Privacy mode only (v0.2.0-beta)') { return $false }
    }
    return $true
}
Test-Case 'Assessment fixtures contain required warning and unavailable conditions without real identifiers' {
    $forbidden = '(?i)[A-Z]:\\Users\\|\b[0-9A-F]{2}(?::[0-9A-F]{2}){5}\b|\b(?:\d{1,3}\.){3}\d{1,3}\b|\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b|[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}'
    $quick = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot $FixturePaths[0]) | ConvertFrom-Json
    $standard = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot $FixturePaths[1]) | ConvertFrom-Json
    $fixtureText = ($FixturePaths | ForEach-Object { Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot $_) }) -join "`n"
    return @($quick.Checks | Where-Object { $_.Status -eq 'Warning' }).Count -gt 0 -and
        @($quick.Checks | Where-Object { $_.Status -eq 'Failed' }).Count -eq 0 -and
        @($standard.Checks | Where-Object { $_.Status -eq 'Warning' }).Count -gt 0 -and
        @($standard.Checks | Where-Object { $_.Status -eq 'Unavailable' }).Count -eq 1 -and
        @($standard.Checks | Where-Object { $_.Status -eq 'Failed' }).Count -eq 0 -and $fixtureText -notmatch $forbidden
}
Test-Case 'Public manifest includes each fictional fixture exactly once' {
    $manifestEntries = @(Get-Content -LiteralPath $ManifestPath | ForEach-Object { $_.Trim().Replace('\', '/') } | Where-Object { $_ })
    foreach ($fixturePath in $FixturePaths) {
        if (@($manifestEntries | Where-Object { $_ -ceq $fixturePath }).Count -ne 1) { return $false }
    }
    return $true
}
Test-Case 'HTML generation encodes dynamic values' {
    return $source -match 'System\.Net\.WebUtility\]::HtmlEncode' -and $source -match 'ConvertTo-HtmlText' -and $source -match 'Write-SummaryFiles'
}
Test-Case 'Administrator check is present and does not auto-elevate' {
    return $source -match 'WindowsBuiltInRole\]::Administrator' -and $source -match 'exit 2' -and $commandNames -notcontains 'Start-Process'
}
Test-Case 'Platform and supported-Windows checks are present' {
    return $source -match '\$env:OS -ne ''Windows_NT''' -and $source -match 'Windows 10\|Windows 11' -and $source -match '\[Version\]''5\.1'''
}
Test-Case 'README documents privacy limitations and report review' {
    $readme = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot 'README.md')
    return $readme -match '(?m)^## Privacy and safety\s*$' -and $readme -match 'review every report before sharing' -and $readme -match 'privacy-mode only'
}
Test-Case 'README documents Quick, Standard, and Full modes' {
    $readme = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot 'README.md')
    return $readme -match '\bQuick\b' -and $readme -match '\bStandard\b' -and $readme -match '\bFull\b' -and $readme -match '(?m)^## Mode comparison\s*$'
}
Test-Case 'README does not claim Linux or macOS support' {
    $readme = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot 'README.md')
    return $readme -notmatch '(?i)supports?\s+(Linux|macOS)|(?:Linux|macOS)\s+support'
}
Test-Case 'Maintained script does not use Format-List star on sensitive data' {
    return $source -notmatch '(?i)Format-List\s+\*' -and $commandNames -notcontains 'Format-List' -and $commandNames -notcontains 'Format-Table'
}
Test-Case 'Output-path creation rejects non-empty directories and uses terminating errors' {
    return $source -match 'GetUnresolvedProviderPathFromPSPath' -and $source -match 'new or empty directory' -and $source -match 'New-Item -ItemType Directory.+-ErrorAction Stop'
}
Test-Case 'Sensitive collection cannot execute in v0.2.0-beta' {
    return $source -notmatch 'IncludeSensitiveData|Read-Host|Invoke-RawReportCommand|Invoke-SensitiveTextCommand|SENSITIVE_' -and
        $source -notmatch '(?i)dsregcmd\.exe|slmgr\.vbs|msinfo32\.exe|dxdiag\.exe|[''"]/(?:batteryreport|sleepstudy|systemsleepdiagnostics|energy)[''"]' -and
        $source -match 'SensitiveMode = \$false'
}
Test-Case 'Unsafe Full entries are fixed Omitted-only definitions' {
    $names = @('EnergyReport', 'BatteryReport', 'SleepStudy', 'SleepDiagnostics', 'MSInfo32', 'DxDiag', 'DeviceRegistration', 'LicenseDetails')
    foreach ($name in $names) {
        if ($source -notmatch ("New-PrivacyOnlyOmittedDefinition '" + [regex]::Escape($name) + "'")) { return $false }
    }
    return ([regex]::Matches($source, "New-PrivacyOnlyOmittedDefinition '")).Count -eq 8 -and
        $source -match 'sensitive-report collection is unavailable in v0\.2\.0-beta'
}
Test-Case 'README does not expose sensitive collection as available' {
    $readme = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot 'README.md')
    return $readme -notmatch 'IncludeSensitiveData' -and $readme -match 'Version 0\.2\.0-beta is privacy-mode only' -and
        $readme -match 'There is no public or hidden sensitive mode'
}
Test-Case 'Native commands use availability checks, timeouts, and exit codes' {
    return $source -match 'Invoke-PCFCNativeProcess' -and $productionSource -match 'WaitForExit\(\$TimeoutSeconds \* 1000\)' -and
        $productionSource -match '\$nativeExitCode\s*=\s*\$process\.ExitCode' -and $productionSource -match 'ExitCodeCapturedBeforeDispose'
}
Test-Case 'Native executable selection is pinned to an exact Windows-system allowlist' {
    $resolverBlock = [regex]::Match($productionSource, '(?s)function Resolve-PCFCTrustedWindowsExecutable.*?function New-PCFCNativeResult').Value
    $runnerBlock = [regex]::Match($productionSource, '(?s)function Invoke-PCFCNativeProcess.*?function Get-WindowsSystemVolume').Value
    foreach ($name in @('powercfg.exe', 'dism.exe', 'sfc.exe', 'chkdsk.exe')) {
        if ($resolverBlock -notmatch [regex]::Escape("'$name'")) { return $false }
    }
    return $resolverBlock -match '\[Environment\]::SystemDirectory' -and
        ([regex]::Matches($resolverBlock, '\[System\.IO\.Path\]::GetFullPath')).Count -ge 2 -and
        $resolverBlock -match 'ReparsePoint' -and $resolverBlock -notmatch 'Get-Command|\$env:PATH' -and
        $runnerBlock -match 'Resolve-PCFCTrustedWindowsExecutable -FileName \$FilePath' -and
        $runnerBlock -notmatch 'CommandType Application|\$env:PATH'
}
Test-Case 'Post-timeout handling has a second bound and guarded stream reads' {
    $runnerBlock = [regex]::Match($productionSource, '(?s)function Invoke-PCFCNativeProcess.*?function Get-WindowsSystemVolume').Value
    return $runnerBlock -match 'WaitForExit\(\$TimeoutSeconds \* 1000\)' -and
        $runnerBlock -match 'WaitForExit\(5000\)' -and $runnerBlock -notmatch 'WaitForExit\(\s*\)' -and
        $runnerBlock -match '\$stdoutTask\.IsCompleted' -and $runnerBlock -match '\$stderrTask\.IsCompleted' -and
        $runnerBlock -match "'TimeoutTerminationIncomplete'" -and $runnerBlock -match "'ProcessStartFailure'" -and
        $runnerBlock -match "'Completed'"
}
Test-Case 'SleepStates persists only controlled capability and stream metadata' {
    $sleepBlock = [regex]::Match($source, '(?s)function Get-SleepStateInformation.*?function Get-ActivePowerPlanInformation').Value
    foreach ($field in @('QueryCompleted', 'ProcessStarted', 'TimedOut', 'ExitCode', 'StandardOutputPresent', 'StandardOutputLength', 'StandardErrorPresent', 'StandardErrorLength', 'LocalizedOutputParsed', 'RawOutputSaved')) {
        if ($sleepBlock -notmatch [regex]::Escape($field)) { return $false }
    }
    return $sleepBlock -notmatch 'OutputLines|\.StdOut|\.StdErr|-split|LocalizedOutputNotParsed|Reason' -and
        $sleepBlock -match 'LocalizedOutputParsed\s*=\s*\$false' -and $sleepBlock -match 'RawOutputSaved\s*=\s*\$false'
}
Test-Case 'Production report paths are canonical, contained, and reparse-aware' {
    foreach ($functionName in @('Get-PCFCCanonicalPath', 'Test-PCFCPathInside', 'Test-PCFCPathHasReparsePoint', 'Initialize-PCFCOutputDirectory', 'Get-PCFCSafeReportPath')) {
        if ($source -notmatch ('(?m)^function\s+' + [regex]::Escape($functionName) + '\s*\{')) { return $false }
    }
    return $source -match '\[System\.IO\.Path\]::GetFullPath' -and $source -match 'FileAttributes\]::ReparsePoint' -and
        $source -match 'OutputPath must be a new or empty directory' -and $source -match 'Test-PCFCPathInside' -and
        $source -match 'Get-PCFCSafeReportPath' -and $source -notmatch '(?im)^\s*Remove-Item\b'
}
Test-Case 'Production path helpers reject files, non-empty directories, escapes, and reparse destinations' {
    foreach ($functionName in @('Get-PCFCCanonicalPath', 'Test-PCFCPathInside', 'Test-PCFCPathHasReparsePoint', 'Get-PCFCSafeReportPath', 'Initialize-PCFCOutputDirectory')) {
        $node = $ast.FindAll({ param($item) $item -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $item.Name -eq $functionName }, $true) | Select-Object -First 1
        if ($null -eq $node) { return $false }
        . ([scriptblock]::Create($node.Extent.Text))
    }

    $fixtureRoot = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot 'temp\pcfc-output-path-fixture'))
    $expectedRoot = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot 'temp\pcfc-output-path-fixture'))
    $projectPrefix = [System.IO.Path]::GetFullPath($ProjectRoot).TrimEnd([char[]]@([char]92, [char]47)) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $fixtureRoot.Equals($expectedRoot, [System.StringComparison]::OrdinalIgnoreCase) -or -not $fixtureRoot.StartsWith($projectPrefix, [System.StringComparison]::OrdinalIgnoreCase)) { return $false }
    if (Test-Path -LiteralPath $fixtureRoot) { return $false }
    [void](New-Item -ItemType Directory -Path $fixtureRoot -ErrorAction Stop)
    $junction = Join-Path $fixtureRoot 'reparse-output'
    try {
        $filePath = Join-Path $fixtureRoot 'file-output'
        [System.IO.File]::WriteAllText($filePath, 'fictional fixture')
        $fileRejected = $false
        try { [void](Initialize-PCFCOutputDirectory -RequestedPath $filePath) } catch { $fileRejected = $true }

        $nonEmpty = Join-Path $fixtureRoot 'non-empty-output'
        [void](New-Item -ItemType Directory -Path $nonEmpty -ErrorAction Stop)
        [System.IO.File]::WriteAllText((Join-Path $nonEmpty 'marker.txt'), 'fictional fixture')
        $nonEmptyRejected = $false
        try { [void](Initialize-PCFCOutputDirectory -RequestedPath $nonEmpty) } catch { $nonEmptyRejected = $true }

        $safeOutput = Initialize-PCFCOutputDirectory -RequestedPath (Join-Path $fixtureRoot 'safe-output')
        $safeReport = Get-PCFCSafeReportPath -OutputDirectory $safeOutput -RelativePath 'checks\Fictional.json'
        $escapeRejected = $false
        try { [void](Get-PCFCSafeReportPath -OutputDirectory $safeOutput -RelativePath '..\escape.json') } catch { $escapeRejected = $true }

        $junctionTarget = Join-Path $fixtureRoot 'junction-target'
        [void](New-Item -ItemType Directory -Path $junctionTarget -ErrorAction Stop)
        [void](New-Item -ItemType Junction -Path $junction -Target $junctionTarget -ErrorAction Stop)
        $reparseRejected = $false
        try { [void](Initialize-PCFCOutputDirectory -RequestedPath $junction) } catch { $reparseRejected = $true }

        return $fileRejected -and $nonEmptyRejected -and $escapeRejected -and $reparseRejected -and
            (Test-PCFCPathInside -ParentPath $safeOutput -CandidatePath $safeReport)
    }
    finally {
        $fixtureItem = Get-Item -LiteralPath $fixtureRoot -Force -ErrorAction Stop
        if ($fixtureItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { throw 'Refusing to clean an unexpected reparse-point fixture root.' }
        if (Test-Path -LiteralPath $junction) { Remove-Item -LiteralPath $junction -Force }
        if (@(Get-ChildItem -LiteralPath $fixtureRoot -Recurse -Force | Where-Object { $_.Attributes -band [System.IO.FileAttributes]::ReparsePoint }).Count -gt 0) { throw 'Refusing recursive cleanup because an unexpected reparse point remains.' }
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}
Test-Case 'Full and isolated validation share one production CHKDSK collector' {
    $maintainedScripts = @(Get-Content -LiteralPath $ManifestPath | Where-Object { $_ -match '\.ps1$' } | ForEach-Object { Get-Item -LiteralPath (Join-Path $ProjectRoot $_) })
    $collectorCount = 0
    foreach ($scriptFile in $maintainedScripts) {
        $text = Get-Content -Raw -LiteralPath $scriptFile.FullName
        $collectorCount += ([regex]::Matches($text, '(?im)^function\s+Invoke-ChkdskOnlineScan\s*\{')).Count
    }
    return $collectorCount -eq 1 -and $source -match 'internal\\ChkdskProduction\.ps1' -and
        $source -match "New-Definition 'ChkdskOnlineScan'.+Invoke-ChkdskOnlineScan" -and
        $integratedValidatorSource -match '\. \$ProductionScript' -and $integratedValidatorSource -match 'Invoke-ChkdskOnlineScan -Context'
}
Test-Case 'Integrated CHKDSK validator does not duplicate native-process logic or diagnostic modes' {
    return $integratedValidatorSource -notmatch 'ProcessStartInfo|ReadToEndAsync' -and
        $integratedValidatorSource -notmatch '(?i)-Mode\s+(?:Quick|Standard|Full)' -and
        $integratedValidatorSource -match "'integrated-chkdsk'" -and
        $integratedValidatorSource -notmatch '(?i)[''"]/(?:f|r|x|b|spotfix)[''"]'
}
Test-Case 'CHKDSK result records complete safe metadata without raw output' {
    foreach ($field in @('Executable', 'SafeArguments', 'VerifiedSystemVolume', 'VolumeSelectionMethod', 'ProcessStarted',
        'TimedOut', 'DurationMilliseconds', 'NativeExitCode', 'FailureKind', 'StandardOutputPresent',
        'StandardOutputLength', 'StandardErrorPresent', 'StandardErrorLength', 'RawOutputSaved',
        'RepairCommandUsed', 'Status', 'Message')) {
        if ($productionSource -notmatch [regex]::Escape($field)) { return $false }
    }
    return $productionSource -match "'<verified-system-volume>', '/scan'" -and
        $productionSource -match 'RawOutputSaved = \$false' -and $productionSource -notmatch 'Write-Utf8File'
}
Test-Case 'CHKDSK native helper uses safe PowerShell 5.1 process configuration' {
    return $productionSource -match 'UseShellExecute = \$false' -and $productionSource -match 'CreateNoWindow = \$true' -and
        $productionSource -match 'RedirectStandardOutput = \$true' -and $productionSource -match 'RedirectStandardError = \$true' -and
        $productionSource -match 'ReadToEndAsync\(\)' -and $productionSource -match 'ConvertTo-PCFCNativeArgument' -and
        $productionSource -notmatch '\$LASTEXITCODE'
}
Test-Case 'No executable native raw-report output path remains' {
    return $source -notmatch 'Invoke-RawReportCommand|\{OUTPUT\}|SENSITIVE_' -and
        $source -notmatch '(?i)msinfo32\.exe|dxdiag\.exe|[''"]/(?:batteryreport|sleepstudy|systemsleepdiagnostics|energy)[''"]'
}
Test-Case 'Quick, Standard, and Full manifests are deterministic' {
    return $source -match 'if \(\$SelectedMode -in @\(''Standard'', ''Full''\)\)' -and $source -match 'if \(\$SelectedMode -eq ''Full''\)' -and $source -match 'Get-CheckDefinitions'
}
Test-Case 'Required summary and log output names are implemented' {
    return $source -match '00_HEALTH_SUMMARY\.html' -and $source -match '00_HEALTH_SUMMARY\.json' -and $source -match '00_READ_ME\.txt' -and $source -match 'run\.log'
}
Test-Case 'Documented process exit codes are implemented' {
    return $source -match 'exit 2' -and $source -notmatch 'exit 3' -and $source -match 'Get-CompletionExitCode' -and
        $source -match "Status 'Failed'\) -gt 0\) \{ return 1 \}" -and $source -match 'exit \$exitCode'
}
Test-Case 'PC-Full-Check.ps1 remains the only supported public diagnostic entry point' {
    $readme = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot 'README.md')
    $manifestScripts = @(Get-Content -LiteralPath $ManifestPath | Where-Object { $_ -match '\.ps1$' })
    $topLevelScripts = @($manifestScripts | Where-Object { $_ -notmatch '^(?:tests|internal)/' })
    $diagnosticEntrypoints = @($topLevelScripts | Where-Object { $_ -ne 'PCFC-Easy-Runner.ps1' })
    return $diagnosticEntrypoints.Count -eq 1 -and $diagnosticEntrypoints[0] -ceq 'PC-Full-Check.ps1' -and
        @($topLevelScripts | Where-Object { $_ -ceq 'PCFC-Easy-Runner.ps1' }).Count -eq 1 -and
        $readme -match [regex]::Escape('PC-Full-Check.ps1` is the only supported diagnostic entry point.') -and
        $readme -match 'PCFC-Easy-Runner\.ps1.*optional convenience launcher' -and
        $source -match "Version: 0\.2\.0-beta"
}
Test-Case 'Optional Easy Runner preserves the documented network and diagnostic trust boundary' {
    return (Test-Path -LiteralPath $EasyRunnerPath -PathType Leaf) -and
        $easyRunnerSource -match '\[string\]\$Mode = ''Standard''' -and
        $easyRunnerSource -match 'https://api\.github\.com/repos/aymanbouanouj/PC-Full-Check' -and
        $easyRunnerSource -match "'/archive/'" -and
        $easyRunnerSource -match 'tests\\run-tests\.ps1' -and
        $easyRunnerSource -match 'PC-Full-Check\.ps1' -and
        $easyRunnerSource -match 'ZIP trace SHA-256 \(not a signature\)' -and
        $easyRunnerSource -notmatch '(?i)Upload(File|String)|Start-BitsTransfer|HttpClient|WebClient' -and
        $easyRunnerSource -notmatch '(?i)-Method\s+(?:Post|Put|Patch|Delete)'
}

$assessmentTestPath = Join-Path $ProjectRoot 'tests\assessment-tests.ps1'
$chkdskTestPath = Join-Path $ProjectRoot 'tests\chkdsk-tests.ps1'
$privacyTestPath = Join-Path $ProjectRoot 'tests\privacy-validation.ps1'
$finalFullTestPath = Join-Path $ProjectRoot 'tests\run-final-full-validation.ps1'
Test-Case 'Every maintained public PowerShell file parses without errors' {
    $publicPowerShellPaths = @(Get-Content -LiteralPath $ManifestPath | Where-Object { $_ -match '\.ps1$' } | ForEach-Object { Join-Path $ProjectRoot $_ })
    foreach ($path in $publicPowerShellPaths) {
        $extraTokens = $null
        $extraErrors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$extraTokens, [ref]$extraErrors)
        if ($extraErrors.Count -gt 0) { return $false }
    }
    return $true
}
Test-Case 'Privacy validator enforces project paths and text-only report extensions' {
    $privacySource = Get-Content -Raw -LiteralPath $privacyTestPath
    return $privacySource -match 'Test-PathInsideProject' -and $privacySource -match 'ReparsePoint' -and
        $privacySource -match "'\.json', '\.html', '\.txt', '\.log', '\.csv', '\.xml'"
}
Test-Case 'Privacy validator uses exact in-memory local identifiers without printing values' {
    $privacySource = Get-Content -Raw -LiteralPath $privacyTestPath
    return $privacySource -match 'Win32_BIOS' -and $privacySource -match 'Win32_ComputerSystemProduct' -and
        $privacySource -match 'Win32_BaseBoard' -and $privacySource -match 'Win32_DiskDrive' -and
        $privacySource -match 'Get-NetAdapter' -and $privacySource -match 'Category=\{0\}; File=\{1\}; Line=\{2\}' -and
        $privacySource -notmatch 'Write-(Host|Output).+\.Value'
}
Test-Case 'Privacy validator distinguishes parsed IPv4, strict MAC, email, and contextual GUID findings' {
    $privacySource = Get-Content -Raw -LiteralPath $privacyTestPath
    return $privacySource -match 'IPAddress\]::TryParse' -and
        $privacySource -match '\{2\}\[:-\].+\{5\}' -and
        $privacySource -match 'EmailAddressPattern' -and $privacySource -match 'GuidInIdentityContext' -and
        $privacySource -match 'VersionShapedLikeIPv4'
}
Test-Case 'Privacy validator implements required exit-code meanings' {
    $privacySource = Get-Content -Raw -LiteralPath $privacyTestPath
    return $privacySource -match 'Confirmed\.Count -gt 0\) \{ exit 1 \}' -and
        $privacySource -match 'exit 2' -and $privacySource -match 'exit 0'
}
Test-Case 'Battery and reliability ambiguity rules are explicit in maintained code' {
    return $source -match 'Get-BatteryCapacityStatus' -and $source -match "return 'Unavailable'" -and
        $source -match 'ConvertTo-OptionalTemperature' -and $source -match 'numericValue -le 0' -and
        $source -match 'no usable telemetry fields'
}
Test-Case 'Installed-program and signed-driver collectors use explicit privacy allowlists' {
    $forbiddenInventoryFields = 'InstallLocation|UninstallString|QuietUninstallString|PackageFullName|UserProfile|RegistryPath|ProductKey'
    $programBlock = [regex]::Match($source, '(?s)function Get-InstalledProgramInformation.*?function Get-NetworkAdapterInformation').Value
    $driverBlock = [regex]::Match($source, '(?s)function Get-DriverInformation.*?function Get-BatteryInformation').Value
    return $programBlock -match 'DisplayName' -and $programBlock -match 'DisplayVersion' -and $programBlock -match 'Publisher' -and $programBlock -match 'InstallDate' -and
        $driverBlock -match 'DeviceName' -and $driverBlock -match 'DriverVersion' -and
        $programBlock -notmatch $forbiddenInventoryFields -and $driverBlock -notmatch $forbiddenInventoryFields
}
Test-Case 'Public documentation contains no absolute local path' {
    $documentation = @(Get-ChildItem -LiteralPath $ProjectRoot -Recurse -File | Where-Object {
        $_.FullName -notlike '*\local-validation\*' -and $_.FullName -notlike '*\local-audit\*' -and
        $_.Extension -in @('.md', '.txt')
    })
    foreach ($file in $documentation) {
        $text = Get-Content -Raw -LiteralPath $file.FullName
        if ($text.IndexOf($localUsersBackslash, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
            $text.IndexOf($localUsersSlash, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
            $text.IndexOf($desktopProjectFragment, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
            $text.IndexOf($fileUriPrefix, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { return $false }
    }
    return $true
}
Test-Case 'Git ignore excludes local and generated report locations without hiding documentation' {
    $ignore = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot '.gitignore')
    foreach ($requiredPattern in @('local-validation/', '/local-audit/', 'reports/', 'report-output/', 'PC_FULL_CHECK_*/', '*.zip', '*.log', 'tmp/', 'temp/', '*.tmp', '*.bak', '.vscode/', '.idea/', 'Thumbs.db', 'Desktop.ini', '.DS_Store')) {
        if ($ignore -notmatch [regex]::Escape($requiredPattern)) { return $false }
    }
    return @($ignore -split '\r?\n' | Where-Object { $_ -ceq '/local-audit/' }).Count -eq 1 -and
        $ignore -notmatch '(?m)^/legacy/$|^\*\.(?:md|json|html|txt|csv|xml)$' -and $ignore -match '!examples/'
}
Test-Case 'Public documentation never presents an unpublished legacy executable as runnable' {
    $documentationEntries = @(Get-Content -LiteralPath $ManifestPath | Where-Object { $_ -match '\.(?:md|txt)$' })
    foreach ($entry in $documentationEntries) {
        $text = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot $entry)
        if ($text -match '(?im)^\s*(?:powershell(?:\.exe)?[^\r\n]*-File\s+|\.\\)[^\r\n]*PC_FULL_CHECK_FIXED\.ps1(?:\s|$)') { return $false }
    }
    return $true
}
Test-Case 'README records one-computer remediated evidence without universal claims' {
    $readme = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot 'README.md')
    return $readme -match 'functionally tested on one current Windows computer' -and
        $readme -match 'Quick: exit 0; 8 Passed, 1 Warning, 0 Failed' -and
        $readme -match 'Standard: exit 0; 17 Passed, 3 Warning, 0 Failed, 1 Unavailable' -and
        $readme -match 'Full: exit 0; 20 Passed, 3 Warning, 0 Failed, 1 Unavailable, 8 Omitted' -and
        $readme -notmatch 'New elevated Quick, Standard, Full, and integrated CHKDSK production-path validation is required' -and
        $readme -notmatch '(?i)\bis universally validated\b|\bfully certified\b|\bproduction certified\b|\bguaranteed safe on every computer\b|\bdetects every hardware issue\b'
}
Test-Case 'Required release metadata files and version exist' {
    $notesPath = Join-Path $ProjectRoot 'RELEASE_NOTES.md'
    $checklistPath = Join-Path $ProjectRoot 'RELEASE_CHECKLIST.md'
    return (Test-Path -LiteralPath $notesPath -PathType Leaf) -and (Test-Path -LiteralPath $checklistPath -PathType Leaf) -and
        (Get-Content -Raw -LiteralPath $notesPath) -match 'v0\.2\.0-beta' -and
        (Get-Content -Raw -LiteralPath $checklistPath) -match 'Version: 0\.2\.0-beta'
}
Test-Case 'Public authorship metadata consistently names Ayman Bounaouj' {
    $author = 'Ayman Bounaouj'
    $readme = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot 'README.md')
    $authors = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot 'AUTHORS.md')
    $license = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot 'LICENSE')
    $sample = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot 'examples\sanitized-sample-summary.json')
    if ($source -notmatch 'Author: Ayman Bounaouj' -or $source -notmatch "Author = 'Ayman Bounaouj'") { return $false }
    if ($readme -notmatch '(?m)^## Author\s*$' -or $readme -notmatch 'Created and maintained by \*\*Ayman Bounaouj\*\*\.') { return $false }
    if ($authors -notmatch '(?m)^# Authors\s*$' -or $authors -notmatch '\*\*Ayman Bounaouj\*\*') { return $false }
    if ($license -notmatch 'Copyright 2026 Ayman Bounaouj') { return $false }
    if ($sample -notmatch '"Author"\s*:\s*"Ayman Bounaouj"') { return $false }
    foreach ($path in @('RELEASE_NOTES.md', 'CHANGELOG.md', 'docs/complete-project-report.md', 'docs/privacy-security-audit.md', 'docs/static-security-review.md', 'docs/test-coverage-report.md')) {
        if ((Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot $path)) -notmatch [regex]::Escape($author)) { return $false }
    }
    return $true
}
Test-Case 'CITATION.cff has safe CFF 1.2 author structure and Zenodo metadata' {
    $citation = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot 'CITATION.cff')
    return $citation -notmatch "`t" -and
        $citation -match '(?m)^cff-version: 1\.2\.0\s*$' -and
        $citation -match '(?m)^message: "If you use this software, please cite it as below\."\s*$' -and
        $citation -match '(?m)^title: "PC Full Check for Windows"\s*$' -and
        $citation -match '(?m)^version: "0\.2\.0-beta"\s*$' -and
        $citation -match '(?m)^type: software\s*$' -and
        $citation -match '(?m)^authors:\r?\n  - family-names: "Bounaouj"\r?\n    given-names: "Ayman"\r?\n    orcid: "https://orcid\.org/0009-0001-6071-9418"\s*$' -and
        $citation -match '(?m)^doi: "10\.5281/zenodo\.23273477"\s*$' -and
        $citation -match '(?m)^repository-code: "https://github\.com/aymanbouanouj/PC-Full-Check"\s*$' -and
        $citation -match '(?m)^license: MIT\s*$' -and
        $citation -match '(?m)^date-released: 2026-09-14\s*$' -and
        $citation -notmatch '(?im)^\s*(?:email|url):'
}
Test-Case 'Configured Git email does not appear in any public file' {
    if ($null -eq (Get-Command git -ErrorAction SilentlyContinue)) { return $true }
    $configuredEmail = @(& git -C $ProjectRoot config --get user.email 2>$null | Select-Object -First 1)
    if ($configuredEmail.Count -eq 0 -or [string]::IsNullOrWhiteSpace([string]$configuredEmail[0])) { return $true }
    $email = [string]$configuredEmail[0]
    foreach ($entry in @(Get-Content -LiteralPath $ManifestPath | Where-Object { $_ })) {
        $text = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot $entry)
        if ($text.IndexOf($email, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { return $false }
    }
    return $true
}
Test-Case 'Complete user guide matches current public behavior' {
    $guide = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot 'docs\USER_GUIDE.md')
    $sections = @([regex]::Matches($guide, '(?m)^## (\d+)\. '))
    if ($sections.Count -ne 54) { return $false }
    for ($index = 1; $index -le 54; $index++) {
        if ([int]$sections[$index - 1].Groups[1].Value -ne $index) { return $false }
    }
    foreach ($commandMode in @('Quick', 'Standard', 'Full')) {
        if ($guide -notmatch ('powershell\.exe -NoProfile -ExecutionPolicy Bypass -File "\.\\PC-Full-Check\.ps1" -Mode ' + $commandMode)) { return $false }
    }
    $requiredText = @(
        'Windows 10', 'Windows 11', 'Windows PowerShell 5.1 or later', 'Administrator privileges',
        'Standard is the default mode', 'Quick runs 9', 'Standard runs 21', 'Full contains 32',
        'EnergyReport', 'BatteryReport', 'SleepStudy', 'SleepDiagnostics', 'MSInfo32', 'DxDiag',
        'DeviceRegistration', 'LicenseDetails', '00_HEALTH_SUMMARY.html', '00_HEALTH_SUMMARY.json',
        '00_READ_ME.txt', 'run.log', 'Passed', 'Warning', 'Failed', 'Unavailable', 'Omitted',
        'Good', 'Attention required', 'Unknown', 'Critical', 'Ayman Bounaouj'
    )
    foreach ($required in $requiredText) { if ($guide -notmatch [regex]::Escape($required)) { return $false } }
    return $guide -match '-OutputPath "\.\\PCFC-Report"' -and
        $guide -notmatch '(?i)-IncludeSensitiveData|PC_FULL_CHECK_FIXED\.ps1.*(?:-File|runnable)' -and
        $guide -match 'does not auto-elevate|never auto-elevates' -and $guide -match 'no network request' -and
        $guide -match 'no repair workflow' -and $guide -match 'does not provide anonymity|not anonymity'
}
Test-Case 'Public Markdown relative links resolve inside the project' {
    $markdownEntries = @(Get-Content -LiteralPath $ManifestPath | Where-Object { $_ -match '\.md$' })
    foreach ($entry in $markdownEntries) {
        $filePath = Join-Path $ProjectRoot $entry
        $text = Get-Content -Raw -LiteralPath $filePath
        foreach ($match in [regex]::Matches($text, '!?(?:\[[^\]]*\])\((?<target>[^)]+)\)')) {
            $target = $match.Groups['target'].Value.Trim()
            if ($target -match '^(?:https?://|mailto:|#)') { continue }
            $target = ($target -split '#', 2)[0]
            if ([string]::IsNullOrWhiteSpace($target)) { continue }
            if ($target -match '^(?:[A-Za-z]:|/|\\)') { return $false }
            $candidate = [System.IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $filePath) ($target -replace '/', '\')))
            if (-not $candidate.StartsWith($ProjectRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) -or
                -not (Test-Path -LiteralPath $candidate)) { return $false }
        }
    }
    return $true
}
Test-Case 'Public manifest is complete and excludes generated local evidence' {
    $rawListed = @(Get-Content -LiteralPath $ManifestPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if (@($rawListed | Where-Object { $_ -ne $_.Trim() -or $_ -match '\\|^(?:[A-Za-z]:|/)' }).Count -ne 0) { return $false }
    $listed = @($rawListed | ForEach-Object { $_.Trim() } | Sort-Object -Unique)
    if ($listed.Count -ne $rawListed.Count) { return $false }
    $actual = @(Get-ChildItem -LiteralPath $ProjectRoot -Recurse -File | Where-Object {
        $_.FullName -notlike '*\local-validation\*' -and $_.FullName -notlike '*\local-audit\*' -and
        $_.FullName -notlike '*\.git\*' -and
        $_.FullName -ne $RootLegacyPath -and $_.FullName -ne $NestedLegacyPath
    } | ForEach-Object { $_.FullName.Substring($ProjectRoot.Length + 1).Replace('\', '/') } |
        Where-Object { $_ -notmatch '^(?:temp|tmp)/' } | Sort-Object -Unique)
    if (@(Compare-Object -ReferenceObject $listed -DifferenceObject $actual).Count -ne 0) { return $false }
    return @($listed | Where-Object { $_ -match '^(?:local-validation|local-audit|reports|report-output|tmp|temp)/|\.(?:zip|log|tmp|bak)$' }).Count -eq 0
}
Test-Case 'Only approved audit reports are selected for the public manifest' {
    $listed = @(Get-Content -LiteralPath $ManifestPath | ForEach-Object { $_.Trim().Replace('\', '/') } | Where-Object { $_ })
    foreach ($auditPath in $PublicAuditPaths) {
        if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot $auditPath) -PathType Leaf) -or $listed -notcontains $auditPath) { return $false }
    }
    if (@($listed | Where-Object { $_ -match '^local-audit/' }).Count -ne 0) { return $false }
    if (Test-Path -LiteralPath (Join-Path $ProjectRoot 'local-audit') -PathType Container) {
        foreach ($auditPath in $LocalAuditPaths) {
            if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot $auditPath) -PathType Leaf) -or $listed -contains $auditPath) { return $false }
        }
    }
    return $true
}
Test-Case 'Every public manifest entry exists and none matches ignored report patterns' {
    $listed = @(Get-Content -LiteralPath $ManifestPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    foreach ($entry in $listed) {
        if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot $entry) -PathType Leaf)) { return $false }
        $normalized = $entry.Replace('\', '/')
        if ($normalized -match '^(?:local-validation|local-audit|reports|report-output|tmp|temp|\.vscode|\.idea)/|(?:^|/)PC_FULL_CHECK_[^/]+/|\.(?:zip|log|tmp|bak)$|(?:^|/)(?:Thumbs\.db|Desktop\.ini|\.DS_Store)$') { return $false }
        if ((Test-Path -LiteralPath (Join-Path $ProjectRoot '.git') -PathType Container) -and $null -ne (Get-Command git -ErrorAction SilentlyContinue)) {
            & git -C $ProjectRoot check-ignore -q -- $normalized
            if ($LASTEXITCODE -eq 0) { return $false }
        }
    }
    return $true
}
Test-Case 'No generated real report exists outside ignored local directories' {
    $forbiddenNames = @('00_HEALTH_SUMMARY.html', '00_HEALTH_SUMMARY.json', '00_READ_ME.txt', 'run.log', 'final-full-validation.json', 'result.json')
    $unexpected = @(Get-ChildItem -LiteralPath $ProjectRoot -Recurse -File | Where-Object {
        $_.FullName -notlike '*\local-validation\*' -and $forbiddenNames -contains $_.Name
    })
    return $unexpected.Count -eq 0
}
Test-Case 'Public files contain no local identity or direct identifier literal' {
    $listed = @(Get-Content -LiteralPath $ManifestPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $text = ($listed | ForEach-Object { Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot $_) }) -join "`n"
    foreach ($privateValue in @([Environment]::UserName, [Environment]::MachineName)) {
        if (-not [string]::IsNullOrWhiteSpace($privateValue)) {
            $identityContext = '(?i)(?:UserName|ComputerName|MachineName|HostName|DeviceName|UserProfile|Users[\\/])\s*[:=\\/]*\s*' + [regex]::Escape($privateValue) + '(?![A-Za-z0-9])'
            if ($text -match $identityContext) { return $false }
        }
    }
    if ($text.IndexOf($localUsersBackslash, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or $text.IndexOf($localUsersSlash, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { return $false }
    return $text -notmatch '(?i)\b[0-9A-F]{2}(?::[0-9A-F]{2}){5}\b|\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b|\b(?:\d{1,3}\.){3}\d{1,3}\b|[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}'
}
Test-Case 'Public command examples use repository-relative paths' {
    $readme = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot 'README.md')
    $gitGuide = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot 'docs\git-publication-commands.md')
    foreach ($mode in @('Quick', 'Standard', 'Full')) {
        if ($readme -notmatch ('powershell\.exe -NoProfile -ExecutionPolicy Bypass -File "\.\\PC-Full-Check\.ps1" -Mode ' + $mode)) { return $false }
    }
    return $readme.IndexOf($localUsersBackslash, [System.StringComparison]::OrdinalIgnoreCase) -lt 0 -and
        $readme.IndexOf($localUsersSlash, [System.StringComparison]::OrdinalIgnoreCase) -lt 0 -and
        $gitGuide -notmatch '(?m)^\s*git add \.\s*$' -and $gitGuide -match 'public-file-manifest\.txt'
}
Test-Case 'Current fictional sample contains the complete unconditional summary shape' {
    $samplePath = Join-Path $ProjectRoot 'examples\sanitized-sample-summary.json'
    try { $sample = Get-Content -Raw -LiteralPath $samplePath | ConvertFrom-Json -ErrorAction Stop } catch { return $false }
    foreach ($field in @('Tool', 'GeneratedAt', 'Mode', 'Privacy', 'Assessment', 'System', 'Findings', 'Counts', 'Checks', 'Limitations')) {
        if ($sample.PSObject.Properties.Name -notcontains $field) { return $false }
    }
    return $sample.SampleNotice -match '^FICTIONAL SANITIZED EXAMPLE' -and
        $sample.Privacy.State -eq 'Privacy mode only (v0.2.0-beta)' -and
        $sample.System.PSObject.Properties.Name -contains 'Battery' -and
        $sample.Findings.PSObject.Properties.Name -contains 'WHEAObservedFirst' -and
        $sample.Findings.PSObject.Properties.Name -contains 'WHEAObservedLast' -and
        @($sample.Checks).Count -eq $sample.Counts.Completed -and @($sample.Limitations).Count -eq 4
}
Test-Case 'All nine documentation remediation records are current' {
    $readme = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot 'README.md')
    $contributing = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot 'CONTRIBUTING.md')
    $architecture = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot 'docs\architecture.md')
    $security = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot 'SECURITY.md')
    $releaseAudit = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot 'docs\release-candidate-audit.md')
    $gitGuide = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot 'docs\git-publication-commands.md')
    return $releaseAudit -match '265d323' -and $releaseAudit -match 'no staged files' -and
        $contributing -match 'separately designed, reviewed, and validated future release' -and
        $architecture -notmatch 'lets callers verify a requested output file exists' -and
        $security -notmatch 'expected report files are verified' -and
        $readme -match 'Not included\s*\|\s*Not included\s*\|\s*(?:8 )?Omitted' -and
        $gitGuide -notmatch '(?m)^\s*git init\s*$|(?m)^\s*git commit\b' -and
        (Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot 'examples\sanitized-sample-summary.json')) -match 'SampleNotice'
}
Test-Case 'Fictional-fixture assessment consistency suite passes' {
    $assessmentOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $assessmentTestPath 2>&1)
    $assessmentExitCode = $LASTEXITCODE
    foreach ($line in $assessmentOutput) { Write-Host $line }
    return $assessmentExitCode -eq 0
}
Test-Case 'Isolated CHKDSK and Full privacy-progress suite passes' {
    $chkdskOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $chkdskTestPath 2>&1)
    $chkdskExitCode = $LASTEXITCODE
    foreach ($line in $chkdskOutput) { Write-Host $line }
    return $chkdskExitCode -eq 0
}
Test-Case 'Manual final Full validator is Administrator-only and deletes only the exact guarded target' {
    $validatorSource = Get-Content -Raw -LiteralPath $finalFullTestPath
    $validatorTokens = $null
    $validatorErrors = $null
    $validatorAst = [System.Management.Automation.Language.Parser]::ParseFile($finalFullTestPath, [ref]$validatorTokens, [ref]$validatorErrors)
    $removeCommands = @($validatorAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Remove-Item' }, $true))
    return $validatorErrors.Count -eq 0 -and $validatorSource -match 'WindowsBuiltInRole\]::Administrator' -and
        $validatorSource -match "'final-full'" -and $validatorSource -match 'Test-ExactPath' -and
        $removeCommands.Count -eq 1 -and $removeCommands[0].Extent.Text -match '-LiteralPath \$TargetDirectory -Recurse'
}
Test-Case 'Manual final Full validator runs one privacy-mode Full command and verifies outputs safely' {
    $validatorSource = Get-Content -Raw -LiteralPath $finalFullTestPath
    $validatorTokens = $null
    $validatorErrors = $null
    $validatorAst = [System.Management.Automation.Language.Parser]::ParseFile($finalFullTestPath, [ref]$validatorTokens, [ref]$validatorErrors)
    $fullCommands = @($validatorAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'powershell.exe' -and $node.Extent.Text -match 'PC-Full-Check\.ps1' -and $node.Extent.Text -match '-Mode Full' }, $true))
    return $validatorErrors.Count -eq 0 -and $fullCommands.Count -eq 1 -and
        $validatorSource -notmatch '(?i)-IncludeSensitiveData' -and
        $validatorSource -notmatch '(?i)[''"]/(?:f|r|x|b|spotfix|scannow|RestoreHealth)[''"]' -and
        $validatorSource -match '00_HEALTH_SUMMARY\.html' -and $validatorSource -match '00_HEALTH_SUMMARY\.json' -and
        $validatorSource -match '00_READ_ME\.txt' -and $validatorSource -match 'run\.log' -and
        $validatorSource -match 'privacy-validation\.ps1' -and $validatorSource -match 'final-full-validation\.json'
}

Add-NotExecuted 'Windows functional diagnostic checks' 'This dependency-free runner performs static validation only. Functional Quick mode is recorded separately when the current elevated Windows environment permits it.'

$total = $script:Passed + $script:Failed + $script:NotExecuted
Write-Host ''
Write-Host ('TOTAL={0}; PASSED={1}; FAILED={2}; NOT_EXECUTED={3}' -f $total, $script:Passed, $script:Failed, $script:NotExecuted)
if ($script:Failed -gt 0) { exit 1 }
exit 0
