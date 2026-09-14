#requires -Version 5.1

<#
.SYNOPSIS
    Optional easy launcher for PC Full Check for Windows.

.DESCRIPTION
    PCFC-Easy-Runner.ps1 is a convenience launcher, not a second diagnostic engine.
    It contacts the official GitHub repository to resolve the current default-branch
    commit, downloads that exact source snapshot, validates the public repository,
    runs the repository test suite, then invokes PC-Full-Check.ps1.

    Diagnostic reports stay local. The launcher does not upload diagnostic output.

.PARAMETER Mode
    Diagnostic mode to run. Standard is the default. All runs Quick, Standard,
    and Full sequentially.

.PARAMETER NoOpenReport
    Do not open the generated HTML report automatically.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('All', 'Quick', 'Standard', 'Full')]
    [string]$Mode = 'Standard',

    [Parameter()]
    [switch]$NoOpenReport
)

$ErrorActionPreference = 'Stop'

$RepositoryOwner = 'aymanbouanouj'
$RepositoryName = 'PC-Full-Check'
$RepositoryUrl = 'https://github.com/aymanbouanouj/PC-Full-Check'
$RepositoryApi = 'https://api.github.com/repos/aymanbouanouj/PC-Full-Check'
$RunnerDirectoryName = 'PC-Full-Check-Runner'

function Write-PCFCSection {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host (' ' + $Title) -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
}

function Write-PCFCOk {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host ('[OK] ' + $Message) -ForegroundColor Green
}

function Write-PCFCInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host ('[INFO] ' + $Message) -ForegroundColor Yellow
}

function Get-NativeWindowsPowerShellPath {
    if ([string]::IsNullOrWhiteSpace($env:SystemRoot)) {
        throw 'SystemRoot environment variable is unavailable.'
    }

    if (
        [Environment]::Is64BitOperatingSystem -and
        -not [Environment]::Is64BitProcess
    ) {
        $sysnativePowerShell = Join-Path `
            $env:SystemRoot `
            'Sysnative\WindowsPowerShell\v1.0\powershell.exe'

        if (Test-Path -LiteralPath $sysnativePowerShell -PathType Leaf) {
            return $sysnativePowerShell
        }
    }

    $system32PowerShell = Join-Path `
        $env:SystemRoot `
        'System32\WindowsPowerShell\v1.0\powershell.exe'

    if (Test-Path -LiteralPath $system32PowerShell -PathType Leaf) {
        return $system32PowerShell
    }

    throw 'Native Windows PowerShell could not be located.'
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object `
        -TypeName Security.Principal.WindowsPrincipal `
        -ArgumentList $identity

    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Test-PathHasReparseAncestor {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $current = [System.IO.Path]::GetFullPath($Path)

        while (-not (Test-Path -LiteralPath $current)) {
            $parent = Split-Path -Path $current -Parent

            if (
                [string]::IsNullOrWhiteSpace($parent) -or
                $parent -eq $current
            ) {
                break
            }

            $current = $parent
        }

        while (-not [string]::IsNullOrWhiteSpace($current)) {
            if (Test-Path -LiteralPath $current) {
                $item = Get-Item `
                    -LiteralPath $current `
                    -Force `
                    -ErrorAction Stop

                if (
                    ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
                ) {
                    return $true
                }
            }

            $parent = Split-Path -Path $current -Parent

            if (
                [string]::IsNullOrWhiteSpace($parent) -or
                $parent -eq $current
            ) {
                break
            }

            $current = $parent
        }

        return $false
    }
    catch {
        return $true
    }
}

function Get-SafeLocalBase {
    if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        throw 'LOCALAPPDATA is unavailable; a private per-user workspace cannot be selected safely.'
    }

    $candidate = Join-Path $env:LOCALAPPDATA $RunnerDirectoryName

    if (Test-PathHasReparseAncestor -Path $candidate) {
        throw (
            'The per-user workspace is under a reparse point and was rejected: ' +
            $candidate
        )
    }

    if (-not (Test-Path -LiteralPath $candidate)) {
        [void](New-Item `
            -ItemType Directory `
            -Path $candidate `
            -Force `
            -ErrorAction Stop)
    }

    if (Test-PathHasReparseAncestor -Path $candidate) {
        throw 'The per-user workspace became unsafe after creation.'
    }

    $probe = Join-Path `
        $candidate `
        ('.pcfc-write-test-' + [Guid]::NewGuid().ToString('N') + '.tmp')

    try {
        [System.IO.File]::WriteAllText($probe, 'PCFC write test')

        if (-not (Test-Path -LiteralPath $probe -PathType Leaf)) {
            throw 'Workspace write test failed.'
        }
    }
    finally {
        if (Test-Path -LiteralPath $probe -PathType Leaf) {
            Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
        }
    }

    return $candidate
}

function Test-PowerShellFileParses {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $tokens = $null
    $parseErrors = $null

    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $Path,
        [ref]$tokens,
        [ref]$parseErrors
    )

    if (@($parseErrors).Count -gt 0) {
        $messages = @(
            $parseErrors |
                ForEach-Object { $_.Message }
        )

        throw (
            'PowerShell syntax validation failed for "' +
            $Path +
            '": ' +
            ($messages -join ' | ')
        )
    }
}

function Invoke-PCFCGitHubRestGet {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri
    )

    $headers = @{
        'User-Agent' = 'PC-Full-Check-Easy-Runner'
        'Accept' = 'application/vnd.github+json'
    }

    return Invoke-RestMethod `
        -Uri $Uri `
        -Headers $headers `
        -Method Get `
        -ErrorAction Stop
}

function Invoke-PCFCDownload {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [string]$OutFile
    )

    $parameters = @{
        Uri = $Uri
        OutFile = $OutFile
        ErrorAction = 'Stop'
        Headers = @{
            'User-Agent' = 'PC-Full-Check-Easy-Runner'
        }
    }

    if ($PSVersionTable.PSVersion.Major -le 5) {
        $parameters['UseBasicParsing'] = $true
    }

    Invoke-WebRequest @parameters
}

function Get-PCFCRepositorySnapshot {
    Write-PCFCInfo 'Resolving the official repository default branch...'

    $repositoryInfo = Invoke-PCFCGitHubRestGet -Uri $RepositoryApi

    $defaultBranch = [string]$repositoryInfo.default_branch

    if ([string]::IsNullOrWhiteSpace($defaultBranch)) {
        throw 'GitHub did not return a default branch.'
    }

    $escapedBranch = [Uri]::EscapeDataString($defaultBranch)

    Write-PCFCInfo (
        'Resolving the exact commit for default branch: ' +
        $defaultBranch
    )

    $commitInfo = Invoke-PCFCGitHubRestGet `
        -Uri ($RepositoryApi + '/commits/' + $escapedBranch)

    $commitSha = [string]$commitInfo.sha

    if ($commitSha -notmatch '^[0-9a-fA-F]{40}$') {
        throw 'GitHub did not return a valid 40-character commit SHA.'
    }

    return [pscustomobject]@{
        DefaultBranch = $defaultBranch
        CommitSha = $commitSha.ToLowerInvariant()
        ArchiveUrl = (
            $RepositoryUrl +
            '/archive/' +
            $commitSha.ToLowerInvariant() +
            '.zip'
        )
    }
}

function Expand-PCFCRepository {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ZipPath,

        [Parameter(Mandatory = $true)]
        [string]$ExtractRoot,

        [Parameter(Mandatory = $true)]
        [string]$RepositoryDestination
    )

    if (Test-Path -LiteralPath $ExtractRoot) {
        Remove-Item `
            -LiteralPath $ExtractRoot `
            -Recurse `
            -Force `
            -ErrorAction Stop
    }

    [void](New-Item `
        -ItemType Directory `
        -Path $ExtractRoot `
        -Force `
        -ErrorAction Stop)

    Expand-Archive `
        -LiteralPath $ZipPath `
        -DestinationPath $ExtractRoot `
        -Force `
        -ErrorAction Stop

    $candidates = @(
        Get-ChildItem `
            -LiteralPath $ExtractRoot `
            -Directory `
            -Force `
            -ErrorAction Stop |
            Where-Object {
                Test-Path `
                    -LiteralPath (Join-Path $_.FullName 'PC-Full-Check.ps1') `
                    -PathType Leaf
            }
    )

    if ($candidates.Count -ne 1) {
        throw 'The downloaded archive did not contain exactly one recognizable repository root.'
    }

    if (Test-Path -LiteralPath $RepositoryDestination) {
        throw ('Repository destination already exists: ' + $RepositoryDestination)
    }

    Move-Item `
        -LiteralPath $candidates[0].FullName `
        -Destination $RepositoryDestination `
        -ErrorAction Stop
}

function Test-PCFCPublicManifest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryDirectory
    )

    $manifestPath = Join-Path `
        $RepositoryDirectory `
        'docs\public-file-manifest.txt'

    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw 'Public file manifest is missing.'
    }

    $entries = @(
        Get-Content -LiteralPath $manifestPath |
            ForEach-Object { $_.Trim().Replace('\', '/') } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )

    if ($entries.Count -eq 0) {
        throw 'Public file manifest is empty.'
    }

    foreach ($entry in $entries) {
        if (
            $entry -match '^(?:[A-Za-z]:|/|\\)' -or
            $entry -match '(^|/)\.\.(/|$)'
        ) {
            throw ('Unsafe manifest path: ' + $entry)
        }

        $candidate = Join-Path `
            $RepositoryDirectory `
            ($entry -replace '/', '\')

        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            throw ('Manifest entry is missing: ' + $entry)
        }
    }

    return $entries
}

try {
    Write-PCFCSection 'PC Full Check - Easy Runner'

    if ($env:OS -ne 'Windows_NT') {
        throw 'Unsupported platform. PC Full Check supports Windows 10 and Windows 11 only.'
    }

    $windowsPowerShell = Get-NativeWindowsPowerShellPath
    $isAdministrator = Test-IsAdministrator

    $needsNativeWindowsPowerShell = (
        $PSVersionTable.PSEdition -ne 'Desktop' -or
        $PSVersionTable.PSVersion -lt [Version]'5.1' -or
        (
            [Environment]::Is64BitOperatingSystem -and
            -not [Environment]::Is64BitProcess
        )
    )

    if ($needsNativeWindowsPowerShell -or -not $isAdministrator) {
        if ([string]::IsNullOrWhiteSpace($PSCommandPath)) {
            throw (
                'Automatic relaunch requires this launcher to be saved as a .ps1 file.'
            )
        }

        $arguments = @(
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            ('"' + $PSCommandPath + '"'),
            '-Mode',
            $Mode
        )

        if ($NoOpenReport) {
            $arguments += '-NoOpenReport'
        }

        $startParameters = @{
            FilePath = $windowsPowerShell
            ArgumentList = $arguments
            Wait = $true
            PassThru = $true
            ErrorAction = 'Stop'
        }

        if (-not $isAdministrator) {
            $startParameters['Verb'] = 'RunAs'
            Write-PCFCInfo 'Requesting Administrator privileges...'
        }
        else {
            Write-PCFCInfo 'Restarting in native Windows PowerShell 5.1...'
        }

        $restartedProcess = Start-Process @startParameters
        exit $restartedProcess.ExitCode
    }

    Write-PCFCOk (
        'Native Windows PowerShell ' +
        $PSVersionTable.PSVersion.ToString() +
        ' is active.'
    )
    Write-PCFCOk 'Administrator privileges confirmed.'

    Write-PCFCSection 'Windows Validation'

    if ($null -eq (Get-Command Get-CimInstance -ErrorAction SilentlyContinue)) {
        throw 'Required Windows CIM support is unavailable.'
    }

    $operatingSystem = Get-CimInstance `
        -ClassName Win32_OperatingSystem `
        -ErrorAction Stop

    if ([string]$operatingSystem.Caption -notmatch 'Windows 10|Windows 11') {
        throw (
            'Unsupported Windows version: ' +
            [string]$operatingSystem.Caption
        )
    }

    Write-PCFCOk (
        'Supported operating system: ' +
        [string]$operatingSystem.Caption
    )

    try {
        [Net.ServicePointManager]::SecurityProtocol = `
            [Net.ServicePointManager]::SecurityProtocol -bor `
            [Net.SecurityProtocolType]::Tls12
    }
    catch {
        Write-Warning 'TLS 1.2 compatibility setting could not be applied.'
    }

    Write-PCFCSection 'Private Local Workspace'

    $safeBase = Get-SafeLocalBase
    $runsRoot = Join-Path $safeBase 'Runs'

    if (-not (Test-Path -LiteralPath $runsRoot)) {
        [void](New-Item `
            -ItemType Directory `
            -Path $runsRoot `
            -Force `
            -ErrorAction Stop)
    }

    if (Test-PathHasReparseAncestor -Path $runsRoot) {
        throw 'The selected runs directory is unsafe.'
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $runId = [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $runRoot = Join-Path $runsRoot ($timestamp + '-' + $runId)

    [void](New-Item `
        -ItemType Directory `
        -Path $runRoot `
        -ErrorAction Stop)

    $repositoryDirectory = Join-Path $runRoot 'Repository'
    $extractRoot = Join-Path $runRoot '_Extract'
    $downloadedZip = Join-Path $runRoot 'PC-Full-Check.zip'
    $reportRoot = Join-Path $runRoot 'Reports'

    [void](New-Item `
        -ItemType Directory `
        -Path $reportRoot `
        -ErrorAction Stop)

    Write-PCFCOk ('Run workspace: ' + $runRoot)

    Write-PCFCSection 'Official Source Acquisition'

    $snapshot = Get-PCFCRepositorySnapshot

    Write-Host ('Default branch: ' + $snapshot.DefaultBranch)
    Write-Host ('Resolved commit: ' + $snapshot.CommitSha)
    Write-PCFCInfo 'Downloading that exact commit snapshot from the official GitHub repository...'

    Invoke-PCFCDownload `
        -Uri $snapshot.ArchiveUrl `
        -OutFile $downloadedZip

    if (-not (Test-Path -LiteralPath $downloadedZip -PathType Leaf)) {
        throw 'The repository ZIP was not created.'
    }

    if ((Get-Item -LiteralPath $downloadedZip).Length -lt 1024) {
        throw 'The repository ZIP is unexpectedly small.'
    }

    $zipHash = Get-FileHash `
        -LiteralPath $downloadedZip `
        -Algorithm SHA256 `
        -ErrorAction Stop

    Write-PCFCOk 'Official source snapshot downloaded.'
    Write-Host ('ZIP trace SHA-256 (not a signature): ' + $zipHash.Hash)

    Expand-PCFCRepository `
        -ZipPath $downloadedZip `
        -ExtractRoot $extractRoot `
        -RepositoryDestination $repositoryDirectory

    if (Test-Path -LiteralPath $extractRoot) {
        Remove-Item `
            -LiteralPath $extractRoot `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }

    if (Test-PathHasReparseAncestor -Path $repositoryDirectory) {
        throw 'The extracted repository path is unsafe.'
    }

    Write-PCFCSection 'Repository Verification'

    foreach ($requiredFile in @(
        'PC-Full-Check.ps1',
        'README.md',
        'LICENSE',
        'docs\public-file-manifest.txt',
        'internal\ChkdskProduction.ps1',
        'tests\run-tests.ps1'
    )) {
        $requiredPath = Join-Path $repositoryDirectory $requiredFile

        if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
            throw ('Required repository file is missing: ' + $requiredFile)
        }
    }

    $manifestEntries = @(
        Test-PCFCPublicManifest -RepositoryDirectory $repositoryDirectory
    )

    $publicPowerShellFiles = @(
        $manifestEntries |
            Where-Object { $_ -match '\.ps1$' } |
            ForEach-Object {
                Join-Path $repositoryDirectory ($_ -replace '/', '\')
            }
    )

    foreach ($powerShellFile in $publicPowerShellFiles) {
        Test-PowerShellFileParses -Path $powerShellFile
    }

    Write-PCFCOk (
        'Public manifest verified; PowerShell syntax valid for ' +
        $publicPowerShellFiles.Count +
        ' maintained script file(s).'
    )

    $mainScript = Join-Path $repositoryDirectory 'PC-Full-Check.ps1'
    $testsScript = Join-Path $repositoryDirectory 'tests\run-tests.ps1'
    $testLog = Join-Path $runRoot 'repository-tests.log'

    Write-PCFCSection 'Repository Tests'

    Push-Location $repositoryDirectory

    try {
        $testOutput = @(
            & $windowsPowerShell `
                -NoProfile `
                -ExecutionPolicy Bypass `
                -File $testsScript 2>&1
        )

        $testExitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }

    $testOutput |
        Out-File `
            -LiteralPath $testLog `
            -Encoding UTF8 `
            -Force

    foreach ($line in $testOutput) {
        $text = [string]$line

        if ($text -match '^PASS:') {
            Write-Host $text -ForegroundColor Green
        }
        elseif ($text -match '^FAIL:') {
            Write-Host $text -ForegroundColor Red
        }
        elseif ($text -match '^NOT EXECUTED:') {
            Write-Host $text -ForegroundColor Yellow
        }
        elseif ($text -match 'TOTAL=') {
            Write-Host $text -ForegroundColor Cyan
        }
        else {
            Write-Host $text
        }
    }

    if ($testExitCode -ne 0) {
        throw ('Repository validation tests failed. See: ' + $testLog)
    }

    Write-PCFCOk 'Repository tests passed.'

    if ($Mode -eq 'All') {
        $modesToRun = @('Quick', 'Standard', 'Full')
    }
    else {
        $modesToRun = @($Mode)
    }

    $results = New-Object System.Collections.ArrayList
    $anyDiagnosticFailure = $false

    foreach ($currentMode in $modesToRun) {
        Write-PCFCSection ('Running ' + $currentMode + ' Diagnostic')

        $modeOutput = Join-Path $reportRoot $currentMode

        if (Test-Path -LiteralPath $modeOutput) {
            throw ('Unexpected pre-existing report directory: ' + $modeOutput)
        }

        if (Test-PathHasReparseAncestor -Path $modeOutput) {
            throw ('Unsafe report destination: ' + $modeOutput)
        }

        Push-Location $repositoryDirectory

        try {
            & $windowsPowerShell `
                -NoProfile `
                -ExecutionPolicy Bypass `
                -File $mainScript `
                -Mode $currentMode `
                -OutputPath $modeOutput

            $diagnosticExitCode = $LASTEXITCODE
        }
        finally {
            Pop-Location
        }

        switch ($diagnosticExitCode) {
            0 {
                Write-PCFCOk (
                    $currentMode +
                    ' completed without a Failed check.'
                )
            }
            1 {
                $anyDiagnosticFailure = $true
                Write-Warning (
                    $currentMode +
                    ' completed, but one or more diagnostic checks reported Failed.'
                )
            }
            2 {
                throw (
                    $currentMode +
                    ' could not complete because of a startup, platform, privilege, output, or report-generation error.'
                )
            }
            default {
                throw (
                    $currentMode +
                    ' returned unexpected exit code: ' +
                    $diagnosticExitCode
                )
            }
        }

        $htmlReport = Join-Path $modeOutput '00_HEALTH_SUMMARY.html'
        $jsonReport = Join-Path $modeOutput '00_HEALTH_SUMMARY.json'
        $readMeReport = Join-Path $modeOutput '00_READ_ME.txt'
        $runLog = Join-Path $modeOutput 'run.log'

        foreach ($requiredReport in @(
            $htmlReport,
            $jsonReport,
            $readMeReport,
            $runLog
        )) {
            if (-not (Test-Path -LiteralPath $requiredReport -PathType Leaf)) {
                throw ('Expected report file was not generated: ' + $requiredReport)
            }
        }

        [void]$results.Add(
            [pscustomobject]@{
                Mode = $currentMode
                ExitCode = $diagnosticExitCode
                Directory = $modeOutput
                Html = $htmlReport
                Json = $jsonReport
                Log = $runLog
            }
        )

        Write-PCFCOk ($currentMode + ' report structure verified.')
    }

    Write-PCFCSection 'Final Summary'

    Write-Host ('Official repository: ' + $RepositoryUrl)
    Write-Host ('Resolved commit: ' + $snapshot.CommitSha)
    Write-Host ('Private run workspace: ' + $runRoot)
    Write-Host ('Repository test log: ' + $testLog)
    Write-Host ''

    foreach ($result in $results) {
        if ($result.ExitCode -eq 0) {
            Write-Host (
                '[OK] ' +
                $result.Mode +
                ': ' +
                $result.Directory
            ) -ForegroundColor Green
        }
        else {
            Write-Host (
                '[ATTENTION] ' +
                $result.Mode +
                ': ' +
                $result.Directory
            ) -ForegroundColor Yellow
        }
    }

    if (-not $NoOpenReport) {
        $preferred = $null

        if ($Mode -eq 'All') {
            $preferred = @(
                $results |
                    Where-Object { $_.Mode -eq 'Full' }
            ) | Select-Object -First 1
        }
        else {
            $preferred = @($results) | Select-Object -First 1
        }

        if (
            $null -ne $preferred -and
            (Test-Path -LiteralPath $preferred.Html -PathType Leaf)
        ) {
            try {
                Invoke-Item -LiteralPath $preferred.Html -ErrorAction Stop
            }
            catch {
                Write-Warning 'The report was generated but could not be opened automatically.'
            }
        }
    }

    Write-Host ''

    if ($anyDiagnosticFailure) {
        Write-Host (
            'PC Full Check completed, but at least one diagnostic check reported Failed.'
        ) -ForegroundColor Yellow
        exit 1
    }

    Write-Host 'PC Full Check completed successfully.' -ForegroundColor Green
    exit 0
}
catch {
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Red
    Write-Host ' PC Full Check Easy Runner - ERROR' -ForegroundColor Red
    Write-Host '============================================================' -ForegroundColor Red
    Write-Host ''
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ''
    Write-Host (
        'This is a launcher/environment failure, not a PC health conclusion.'
    ) -ForegroundColor Yellow
    Write-Host ''
    exit 2
}
