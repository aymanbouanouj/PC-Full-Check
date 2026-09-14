<#
.SYNOPSIS
Runs a privacy-first, read-only Windows diagnostic collection.

.DESCRIPTION
PC Full Check for Windows collects selected hardware, Windows, storage,
battery, security, and reliability information and creates local HTML and
JSON summaries. Privacy mode is the only mode in v0.2.0-beta. The script never repairs or
changes the computer and never uploads a report.

.PARAMETER Mode
Selects Quick, Standard, or Full diagnostics. The default is Standard.

.PARAMETER OutputPath
Specifies a new or empty report directory. When omitted, a timestamped report
directory is created on the current user's Desktop.

.EXAMPLE
.\PC-Full-Check.ps1

.EXAMPLE
.\PC-Full-Check.ps1 -Mode Quick

.EXAMPLE
.\PC-Full-Check.ps1 -Mode Full -OutputPath '.\PCFC-Report'

.INPUTS
None.

.OUTPUTS
Local HTML, JSON, text, and log files in the selected report directory.

.NOTES
Version: 0.2.0-beta
Author: Ayman Bounaouj
Copyright 2026 Ayman Bounaouj
Requires Windows 10 or Windows 11, PowerShell 5.1 or later, and Administrator
privileges. This is a diagnostic aid, not a professional certification.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Quick', 'Standard', 'Full')]
    [string]$Mode = 'Standard',

    [Parameter()]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$ToolName = 'PC Full Check for Windows'
$ToolVersion = '0.2.0-beta'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$SupportedStatuses = @('Passed', 'Warning', 'Failed', 'Unavailable', 'Omitted')
$ChkdskProductionPath = Join-Path $PSScriptRoot 'internal\ChkdskProduction.ps1'
if (-not (Test-Path -LiteralPath $ChkdskProductionPath -PathType Leaf)) {
    Write-Error 'The internal CHKDSK production implementation is missing.'
    exit 2
}
. $ChkdskProductionPath

function Get-PCFCCanonicalPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { throw 'A non-empty filesystem path is required.' }
    if ($Path -match '^[^\\/:]+::' -or ($Path -match '^[A-Za-z][A-Za-z0-9_-]+:' -and $Path -notmatch '^[A-Za-z]:')) {
        throw 'Only local filesystem paths are supported.'
    }
    $providerPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $fullPath = [System.IO.Path]::GetFullPath($providerPath)
    $root = [System.IO.Path]::GetPathRoot($fullPath)
    if ($fullPath.Equals($root, [System.StringComparison]::OrdinalIgnoreCase)) { return $fullPath }
    return $fullPath.TrimEnd([char[]]@([char]92, [char]47))
}

function Test-PCFCPathInside {
    param(
        [Parameter(Mandatory = $true)][string]$ParentPath,
        [Parameter(Mandatory = $true)][string]$CandidatePath
    )

    $parent = (Get-PCFCCanonicalPath -Path $ParentPath).TrimEnd([char[]]@([char]92, [char]47))
    $candidate = Get-PCFCCanonicalPath -Path $CandidatePath
    $prefix = $parent + [System.IO.Path]::DirectorySeparatorChar
    return $candidate.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-PCFCPathHasReparsePoint {
    param([Parameter(Mandatory = $true)][string]$Path)

    try {
        $current = Get-PCFCCanonicalPath -Path $Path
        while (-not [string]::IsNullOrWhiteSpace($current)) {
            if (Test-Path -LiteralPath $current) {
                $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
                if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { return $true }
            }
            $parent = [System.IO.Directory]::GetParent($current)
            if ($null -eq $parent) { break }
            $current = $parent.FullName
        }
        return $false
    }
    catch { return $true }
}

function Get-PCFCSafeReportPath {
    param(
        [Parameter(Mandatory = $true)][string]$OutputDirectory,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    if ([string]::IsNullOrWhiteSpace($RelativePath) -or [System.IO.Path]::IsPathRooted($RelativePath)) { throw 'A fixed relative report path is required.' }
    $outputRoot = Get-PCFCCanonicalPath -Path $OutputDirectory
    if (-not [System.IO.Directory]::Exists($outputRoot) -or (Test-PCFCPathHasReparsePoint -Path $outputRoot)) { throw 'The report directory is unavailable or unsafe.' }
    $candidate = Get-PCFCCanonicalPath -Path (Join-Path $outputRoot $RelativePath)
    if (-not (Test-PCFCPathInside -ParentPath $outputRoot -CandidatePath $candidate)) { throw 'The report path is outside the selected output directory.' }
    $parent = [System.IO.Path]::GetDirectoryName($candidate)
    if (-not [System.IO.Directory]::Exists($parent) -or (Test-PCFCPathHasReparsePoint -Path $parent)) { throw 'The report parent directory is unavailable or unsafe.' }
    if ([System.IO.Directory]::Exists($candidate)) { throw 'A report-file path points to a directory.' }
    if ([System.IO.File]::Exists($candidate) -and (Test-PCFCPathHasReparsePoint -Path $candidate)) { throw 'A report-file path is a reparse point.' }
    return $candidate
}

function Initialize-PCFCOutputDirectory {
    param([Parameter(Mandatory = $true)][string]$RequestedPath)

    $reportDirectory = Get-PCFCCanonicalPath -Path $RequestedPath
    if ([System.IO.File]::Exists($reportDirectory)) { throw 'OutputPath points to a file.' }
    if (Test-PCFCPathHasReparsePoint -Path $reportDirectory) { throw 'OutputPath or an inspected parent is a reparse point.' }
    if ([System.IO.Directory]::Exists($reportDirectory)) {
        if (@(Get-ChildItem -LiteralPath $reportDirectory -Force -ErrorAction Stop).Count -gt 0) { throw 'OutputPath must be a new or empty directory to prevent overwriting existing data.' }
    }
    else {
        [void](New-Item -ItemType Directory -Path $reportDirectory -ErrorAction Stop)
    }
    if (-not [System.IO.Directory]::Exists($reportDirectory) -or (Test-PCFCPathHasReparsePoint -Path $reportDirectory)) { throw 'The output directory could not be established safely.' }
    if (@(Get-ChildItem -LiteralPath $reportDirectory -Force -ErrorAction Stop).Count -gt 0) { throw 'The output directory changed during initialization.' }

    $checksDirectory = Get-PCFCCanonicalPath -Path (Join-Path $reportDirectory 'checks')
    if (-not (Test-PCFCPathInside -ParentPath $reportDirectory -CandidatePath $checksDirectory)) { throw 'The checks directory is outside the selected output directory.' }
    if (Test-PCFCPathHasReparsePoint -Path $checksDirectory) { throw 'The checks directory path is unsafe.' }
    [void](New-Item -ItemType Directory -Path $checksDirectory -ErrorAction Stop)
    if (-not [System.IO.Directory]::Exists($checksDirectory) -or (Test-PCFCPathHasReparsePoint -Path $checksDirectory)) { throw 'The checks directory could not be established safely.' }
    return $reportDirectory
}

function Write-Utf8File {
    param(
        [Parameter(Mandatory = $true)][string]$OutputDirectory,
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content
    )

    $Path = Get-PCFCSafeReportPath -OutputDirectory $OutputDirectory -RelativePath $RelativePath
    [System.IO.File]::WriteAllText($Path, $Content, $script:Utf8NoBom)
}

function Get-SafeExceptionMessage {
    param([Parameter(Mandatory = $true)][System.Exception]$Exception)
    return 'The check could not complete; detailed exception text was suppressed by privacy mode.'
}

function Test-CommandAvailable {
    param([Parameter(Mandatory = $true)][string]$Name)

    return $null -ne (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function New-CheckOutcome {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('Passed', 'Warning', 'Failed', 'Unavailable', 'Omitted')][string]$Status,
        [Parameter()][AllowNull()]$Data = $null,
        [Parameter()][string]$Message = '',
        [Parameter()][string]$OutputFile = '',
        [Parameter()][AllowNull()]$ExitCode = $null,
        [Parameter()][bool]$Critical = $false
    )

    return [pscustomobject][ordered]@{
        Status     = $Status
        Data       = $Data
        Message    = $Message
        OutputFile = $OutputFile
        ExitCode   = $ExitCode
        Critical   = $Critical
    }
}

function Write-RunLog {
    param(
        [Parameter(Mandatory = $true)]$Context,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $line = '[{0}] {1}' -f ([DateTime]::Now.ToString('o')), $Message
    $logPath = Get-PCFCSafeReportPath -OutputDirectory $Context.OutputDirectory -RelativePath 'run.log'
    [System.IO.File]::AppendAllText($logPath, $line + [Environment]::NewLine, $script:Utf8NoBom)
}

function Invoke-DiagnosticCheck {
    param(
        [Parameter(Mandatory = $true)]$Context,
        [Parameter(Mandatory = $true)]$Definition,
        [Parameter(Mandatory = $true)][int]$Index,
        [Parameter(Mandatory = $true)][int]$Total
    )

    $progressText = Get-CheckProgressText -Context $Context -Definition $Definition
    Write-Host ('[{0:D2}/{1:D2}] {2}...' -f $Index, $Total, $progressText)
    $started = [DateTime]::Now
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $outcome = $null

    try {
        $outcome = & $Definition.Action $Context
        if ($null -eq $outcome -or $script:SupportedStatuses -notcontains $outcome.Status) {
            throw 'The check returned an invalid result object.'
        }
    }
    catch {
        $outcome = New-CheckOutcome -Status Failed -Message (Get-SafeExceptionMessage -Exception $_.Exception)
    }
    finally {
        $timer.Stop()
    }

    $relativeOutput = $outcome.OutputFile
    if ([string]::IsNullOrWhiteSpace($relativeOutput) -and $null -ne $outcome.Data) {
        $relativeOutput = Join-Path 'checks' ($Definition.Name + '.json')
        try {
            Write-Utf8File -OutputDirectory $Context.OutputDirectory -RelativePath $relativeOutput -Content ($outcome.Data | ConvertTo-Json -Depth 12)
        }
        catch {
            $outcome = New-CheckOutcome -Status Failed -Message 'The check completed, but its structured output could not be written.'
            $relativeOutput = ''
        }
    }

    $result = [pscustomobject][ordered]@{
        Name          = $Definition.Name
        DisplayName   = $Definition.DisplayName
        Status        = $outcome.Status
        StartTime     = $started.ToString('o')
        DurationMs    = [math]::Round($timer.Elapsed.TotalMilliseconds, 0)
        OutputFile    = $relativeOutput
        Error         = if ($outcome.Status -eq 'Failed') { $outcome.Message } else { '' }
        Message       = $outcome.Message
        ExitCode      = $outcome.ExitCode
        Critical      = [bool]$outcome.Critical
        Data          = $outcome.Data
    }

    [void]$Context.Results.Add($result)
    $Context.Data[$Definition.Name] = $outcome.Data
    $logMessage = 'Check={0}; Status={1}; DurationMs={2}' -f $result.Name, $result.Status, $result.DurationMs
    if ($result.ExitCode -ne $null) { $logMessage += '; ExitCode=' + $result.ExitCode }
    if (-not [string]::IsNullOrWhiteSpace($result.Message)) { $logMessage += '; Message=' + $result.Message }
    Write-RunLog -Context $Context -Message $logMessage
}

function New-Definition {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$DisplayName,
        [Parameter(Mandatory = $true)][string]$ProgressText,
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [Parameter()][string]$PrivacyProgressText = ''
    )

    return [pscustomobject]@{ Name = $Name; DisplayName = $DisplayName; ProgressText = $ProgressText; PrivacyProgressText = $PrivacyProgressText; Action = $Action }
}

function New-PrivacyOnlyOmittedDefinition {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$DisplayName,
        [Parameter(Mandatory = $true)][string]$ProgressText
    )

    return New-Definition -Name $Name -DisplayName $DisplayName -ProgressText $ProgressText -PrivacyProgressText $ProgressText -Action {
        param($Context)
        New-CheckOutcome -Status Omitted -Message 'Omitted in privacy mode; sensitive-report collection is unavailable in v0.2.0-beta.'
    }
}

function Get-CheckProgressText {
    param($Context, $Definition)

    if (-not [string]::IsNullOrWhiteSpace($Definition.PrivacyProgressText)) {
        return $Definition.PrivacyProgressText
    }
    return $Definition.ProgressText
}

function Get-WindowsInformation {
    param($Context)

    if (-not (Test-CommandAvailable 'Get-CimInstance')) { return New-CheckOutcome -Status Unavailable -Message 'Get-CimInstance is unavailable.' }
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $data = [pscustomobject][ordered]@{
        Caption        = $os.Caption
        Version        = $os.Version
        BuildNumber    = $os.BuildNumber
        OSArchitecture = $os.OSArchitecture
    }
    return New-CheckOutcome -Status Passed -Data $data
}

function Get-SystemInformation {
    param($Context)

    $system = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    $data = [pscustomobject][ordered]@{
        Manufacturer = $system.Manufacturer
        Model        = $system.Model
        SystemType   = $system.SystemType
    }
    return New-CheckOutcome -Status Passed -Data $data
}

function Get-CpuInformation {
    param($Context)

    $items = @(Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | ForEach-Object {
        [pscustomobject][ordered]@{
            Name                      = $_.Name
            Manufacturer              = $_.Manufacturer
            NumberOfCores             = $_.NumberOfCores
            NumberOfLogicalProcessors = $_.NumberOfLogicalProcessors
            MaxClockMHz               = $_.MaxClockSpeed
            VirtualizationEnabled     = $_.VirtualizationFirmwareEnabled
            Status                    = $_.Status
        }
    })
    if ($items.Count -eq 0) { return New-CheckOutcome -Status Unavailable -Message 'No processor data was returned.' }
    return New-CheckOutcome -Status Passed -Data $items
}

function Get-MemoryInformation {
    param($Context)

    $system = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    $modules = @(Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop | ForEach-Object {
        [pscustomobject][ordered]@{
            BankLabel          = $_.BankLabel
            DeviceLocator      = $_.DeviceLocator
            Manufacturer       = $_.Manufacturer
            PartNumber         = $_.PartNumber
            CapacityBytes      = [uint64]$_.Capacity
            SpeedMHz           = $_.Speed
            ConfiguredClockMHz = $_.ConfiguredClockSpeed
            MemoryTypeCode     = $_.SMBIOSMemoryType
            FormFactorCode     = $_.FormFactor
        }
    })
    $data = [pscustomobject][ordered]@{ TotalPhysicalMemoryBytes = [uint64]$system.TotalPhysicalMemory; Modules = $modules }
    return New-CheckOutcome -Status Passed -Data $data
}

function Get-DisplayInformation {
    param($Context)

    $gpus = @(Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop | ForEach-Object {
        [pscustomobject][ordered]@{
            Name                 = $_.Name
            AdapterCompatibility = $_.AdapterCompatibility
            AdapterRAMBytes      = $_.AdapterRAM
            DriverVersion        = $_.DriverVersion
            DriverDate           = if ($_.DriverDate) { ([DateTime]$_.DriverDate).ToString('o') } else { $null }
            HorizontalResolution = $_.CurrentHorizontalResolution
            VerticalResolution   = $_.CurrentVerticalResolution
            RefreshRateHz        = $_.CurrentRefreshRate
            Status               = $_.Status
        }
    })
    $monitors = @()
    try {
        $monitors = @(Get-CimInstance -Namespace 'root\wmi' -ClassName WmiMonitorID -ErrorAction Stop | ForEach-Object {
            [pscustomobject][ordered]@{
                Manufacturer = -join ($_.ManufacturerName | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ })
                MonitorName  = -join ($_.UserFriendlyName | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ })
            }
        })
    }
    catch { $monitors = @() }
    return New-CheckOutcome -Status Passed -Data ([pscustomobject][ordered]@{ GPUs = $gpus; Monitors = $monitors })
}

function Get-StorageInformation {
    param($Context)

    if (-not (Test-CommandAvailable 'Get-PhysicalDisk')) { return New-CheckOutcome -Status Unavailable -Message 'Get-PhysicalDisk is unavailable.' }
    $disks = @(Get-PhysicalDisk -ErrorAction Stop | ForEach-Object {
        [pscustomobject][ordered]@{
            FriendlyName      = $_.FriendlyName
            MediaType         = [string]$_.MediaType
            BusType           = [string]$_.BusType
            HealthStatus      = [string]$_.HealthStatus
            OperationalStatus = @($_.OperationalStatus | ForEach-Object { [string]$_ })
            SizeBytes         = [uint64]$_.Size
        }
    })
    if ($disks.Count -eq 0) { return New-CheckOutcome -Status Unavailable -Message 'No physical-disk data was returned.' }
    $unhealthy = @($disks | Where-Object { $_.HealthStatus -eq 'Unhealthy' })
    $notHealthy = @($disks | Where-Object { $_.HealthStatus -ne 'Healthy' })
    if ($unhealthy.Count -gt 0) { return New-CheckOutcome -Status Failed -Data $disks -Message 'Windows reports one or more physical disks as unhealthy.' -Critical $true }
    if ($notHealthy.Count -gt 0) { return New-CheckOutcome -Status Warning -Data $disks -Message 'Windows does not report every physical disk as healthy.' }
    return New-CheckOutcome -Status Passed -Data $disks
}

function Get-VolumeInformation {
    param($Context)

    if (-not (Test-CommandAvailable 'Get-Volume')) { return New-CheckOutcome -Status Unavailable -Message 'Get-Volume is unavailable.' }
    $volumes = @(Get-Volume -ErrorAction Stop | Where-Object { $_.DriveLetter } | ForEach-Object {
        [pscustomobject][ordered]@{
            DriveLetter       = [string]$_.DriveLetter
            FileSystem        = $_.FileSystem
            HealthStatus      = [string]$_.HealthStatus
            OperationalStatus = @($_.OperationalStatus | ForEach-Object { [string]$_ })
            SizeBytes         = [uint64]$_.Size
            FreeBytes         = [uint64]$_.SizeRemaining
        }
    })
    if ($volumes.Count -eq 0) { return New-CheckOutcome -Status Unavailable -Message 'No mounted drive-letter volume data was returned.' }
    $lowSpace = @($volumes | Where-Object { $_.SizeBytes -gt 0 -and (($_.FreeBytes / $_.SizeBytes) * 100) -lt 10 })
    $badHealth = @($volumes | Where-Object { $_.HealthStatus -ne 'Healthy' })
    if ($badHealth.Count -gt 0 -or $lowSpace.Count -gt 0) { return New-CheckOutcome -Status Warning -Data $volumes -Message 'One or more volumes report non-healthy status or less than 10% free space.' }
    return New-CheckOutcome -Status Passed -Data $volumes
}

function Get-ProblemDevices {
    param($Context)

    if (-not (Test-CommandAvailable 'Get-PnpDevice')) { return New-CheckOutcome -Status Unavailable -Message 'Get-PnpDevice is unavailable.' }
    $all = @(Get-PnpDevice -PresentOnly -ErrorAction Stop)
    $problems = @($all | Where-Object { $_.Status -ne 'OK' } | ForEach-Object {
        [pscustomobject][ordered]@{ Status = [string]$_.Status; Class = $_.Class; FriendlyName = $_.FriendlyName; Problem = $_.Problem }
    })
    $data = [pscustomobject][ordered]@{ ProblemDeviceCount = $problems.Count; Devices = $problems }
    if ($problems.Count -gt 0) { return New-CheckOutcome -Status Warning -Data $data -Message 'Windows reports one or more present devices with a non-OK status.' }
    return New-CheckOutcome -Status Passed -Data $data
}

function Get-DefenderInformation {
    param($Context)

    if (-not (Test-CommandAvailable 'Get-MpComputerStatus')) { return New-CheckOutcome -Status Unavailable -Message 'Microsoft Defender status cmdlet is unavailable.' }
    $item = Get-MpComputerStatus -ErrorAction Stop
    $data = [pscustomobject][ordered]@{
        AntivirusEnabled             = [bool]$item.AntivirusEnabled
        AntispywareEnabled           = [bool]$item.AntispywareEnabled
        RealTimeProtectionEnabled    = [bool]$item.RealTimeProtectionEnabled
        BehaviorMonitorEnabled       = [bool]$item.BehaviorMonitorEnabled
        AntivirusSignatureVersion    = $item.AntivirusSignatureVersion
        AntivirusSignatureLastUpdate = if ($item.AntivirusSignatureLastUpdated) { ([DateTime]$item.AntivirusSignatureLastUpdated).ToString('o') } else { $null }
    }
    if (-not $data.AntivirusEnabled -or -not $data.RealTimeProtectionEnabled) { return New-CheckOutcome -Status Warning -Data $data -Message 'Microsoft Defender antivirus or real-time protection is not reported as enabled.' }
    return New-CheckOutcome -Status Passed -Data $data
}

function Get-TpmInformation {
    param($Context)

    if (-not (Test-CommandAvailable 'Get-Tpm')) { return New-CheckOutcome -Status Unavailable -Message 'Get-Tpm is unavailable.' }
    try { $item = Get-Tpm -ErrorAction Stop } catch { return New-CheckOutcome -Status Unavailable -Message 'TPM status is unavailable on this system.' }
    $data = [pscustomobject][ordered]@{ TpmPresent = [bool]$item.TpmPresent; TpmReady = [bool]$item.TpmReady; TpmEnabled = [bool]$item.TpmEnabled; TpmActivated = [bool]$item.TpmActivated }
    if (-not $data.TpmPresent) { return New-CheckOutcome -Status Unavailable -Data $data -Message 'No TPM was reported.' }
    if (-not $data.TpmReady) { return New-CheckOutcome -Status Warning -Data $data -Message 'A TPM is present but is not reported as ready.' }
    return New-CheckOutcome -Status Passed -Data $data
}

function Get-SecureBootInformation {
    param($Context)

    if (-not (Test-CommandAvailable 'Confirm-SecureBootUEFI')) { return New-CheckOutcome -Status Unavailable -Message 'Confirm-SecureBootUEFI is unavailable.' }
    try { $enabled = Confirm-SecureBootUEFI -ErrorAction Stop } catch { return New-CheckOutcome -Status Unavailable -Message 'Secure Boot state is unavailable on this firmware or platform.' }
    $data = [pscustomobject][ordered]@{ SecureBootEnabled = [bool]$enabled }
    if (-not $enabled) { return New-CheckOutcome -Status Warning -Data $data -Message 'Secure Boot is supported but not enabled.' }
    return New-CheckOutcome -Status Passed -Data $data
}

function Get-UpdateInformation {
    param($Context)

    if (-not (Test-CommandAvailable 'Get-HotFix')) { return New-CheckOutcome -Status Unavailable -Message 'Get-HotFix is unavailable.' }
    $updates = @(Get-HotFix -ErrorAction Stop | Sort-Object InstalledOn -Descending | Select-Object -First 40 | ForEach-Object {
        [pscustomobject][ordered]@{ HotFixID = $_.HotFixID; Description = $_.Description; InstalledOn = if ($_.InstalledOn) { ([DateTime]$_.InstalledOn).ToString('yyyy-MM-dd') } else { $null } }
    })
    return New-CheckOutcome -Status Passed -Data $updates
}

function Get-StorageReliabilityInformation {
    param($Context)

    if (-not (Test-CommandAvailable 'Get-StorageReliabilityCounter')) { return New-CheckOutcome -Status Unavailable -Message 'Storage reliability counters are unavailable.' }
    $items = @()
    foreach ($disk in @(Get-PhysicalDisk -ErrorAction Stop)) {
        try {
            $counter = $disk | Get-StorageReliabilityCounter -ErrorAction Stop
            # Some storage providers return zero for unsupported temperature
            # fields. Without a separate validity flag, zero is not saved as a
            # verified physical temperature.
            $temperature = ConvertTo-OptionalTemperature -Value $counter.Temperature
            $temperatureMax = ConvertTo-OptionalTemperature -Value $counter.TemperatureMax
            $availableFields = @()
            if ($null -ne $temperature) { $availableFields += 'TemperatureC' }
            if ($null -ne $temperatureMax) { $availableFields += 'TemperatureMaxC' }
            foreach ($field in @('Wear', 'PowerOnHours', 'StartStopCycleCount', 'ReadErrorsTotal', 'WriteErrorsTotal')) {
                if ($null -ne $counter.$field) { $availableFields += $field }
            }
            $items += [pscustomobject][ordered]@{
                FriendlyName        = $disk.FriendlyName
                HealthStatus        = [string]$disk.HealthStatus
                OperationalStatus   = @($disk.OperationalStatus | ForEach-Object { [string]$_ })
                TemperatureC        = $temperature
                TemperatureMaxC     = $temperatureMax
                WearPercent         = $counter.Wear
                PowerOnHours        = $counter.PowerOnHours
                StartStopCycleCount = $counter.StartStopCycleCount
                ReadErrorsTotal     = $counter.ReadErrorsTotal
                WriteErrorsTotal    = $counter.WriteErrorsTotal
                AvailableTelemetry  = $availableFields
            }
        }
        catch { }
    }
    if ($items.Count -eq 0) { return New-CheckOutcome -Status Unavailable -Message 'Windows returned no supported storage reliability counters.' }
    if (@($items | Where-Object { @($_.AvailableTelemetry).Count -gt 0 }).Count -eq 0) {
        return New-CheckOutcome -Status Unavailable -Data $items -Message 'Windows returned storage reliability records but no usable telemetry fields.'
    }
    return New-CheckOutcome -Status Passed -Data $items
}

function ConvertTo-OptionalTemperature {
    param([AllowNull()]$Value)

    if ($null -eq $Value) { return $null }
    $numericValue = 0.0
    if (-not [double]::TryParse([string]$Value, [ref]$numericValue)) { return $null }
    if ($numericValue -le 0) { return $null }
    return $Value
}

function Get-DriverInformation {
    param($Context)

    $items = @(Get-CimInstance -ClassName Win32_PnPSignedDriver -ErrorAction Stop | ForEach-Object {
        [pscustomobject][ordered]@{
            DeviceName       = $_.DeviceName
            Manufacturer     = $_.Manufacturer
            DriverProvider   = $_.DriverProviderName
            DriverVersion    = $_.DriverVersion
            DriverDate       = if ($_.DriverDate) { ([DateTime]$_.DriverDate).ToString('o') } else { $null }
            IsSigned         = $_.IsSigned
            DeviceClass      = $_.DeviceClass
        }
    })
    return New-CheckOutcome -Status Passed -Data $items
}

function Get-BatteryInformation {
    param($Context)

    $batteries = @(Get-CimInstance -ClassName Win32_Battery -ErrorAction Stop)
    if ($batteries.Count -eq 0) { return New-CheckOutcome -Status Unavailable -Message 'No battery was reported; this is expected on many desktop computers.' }
    $designed = @()
    $full = @()
    try { $designed = @(Get-CimInstance -Namespace 'root\wmi' -ClassName BatteryStaticData -ErrorAction Stop) } catch { }
    try { $full = @(Get-CimInstance -Namespace 'root\wmi' -ClassName BatteryFullChargedCapacity -ErrorAction Stop) } catch { }
    $designedTotal = [double](($designed | Measure-Object -Property DesignedCapacity -Sum).Sum)
    $fullTotal = [double](($full | Measure-Object -Property FullChargedCapacity -Sum).Sum)
    $health = $null
    if ($designedTotal -gt 0 -and $fullTotal -ge 0) { $health = [math]::Round(($fullTotal / $designedTotal) * 100, 1) }
    $data = [pscustomobject][ordered]@{
        BatteryCount              = $batteries.Count
        EstimatedChargeRemaining = @($batteries | ForEach-Object { $_.EstimatedChargeRemaining })
        StatusCodes               = @($batteries | ForEach-Object { $_.BatteryStatus })
        DesignedCapacityMWh       = if ($designedTotal -gt 0) { $designedTotal } else { $null }
        FullChargeCapacityMWh     = if ($fullTotal -gt 0) { $fullTotal } else { $null }
        EstimatedHealthPercent    = $health
    }
    $batteryStatus = Get-BatteryCapacityStatus -EstimatedHealthPercent $health
    if ($batteryStatus -eq 'Unavailable') { return New-CheckOutcome -Status Unavailable -Data $data -Message 'A battery is present, but safe design/full-charge capacity telemetry is unavailable.' }
    if ($batteryStatus -eq 'Warning') { return New-CheckOutcome -Status Warning -Data $data -Message 'Estimated battery capacity is below the project heuristic of 80% of design capacity.' }
    return New-CheckOutcome -Status Passed -Data $data
}

function Get-BatteryCapacityStatus {
    param([Parameter()][AllowNull()]$EstimatedHealthPercent)

    if ($null -eq $EstimatedHealthPercent) { return 'Unavailable' }
    if ([double]$EstimatedHealthPercent -lt 80) { return 'Warning' }
    return 'Passed'
}

function Get-SleepStateInformation {
    param($Context)

    $result = Invoke-PCFCNativeProcess -FilePath 'powercfg.exe' -Arguments @('/a') -TimeoutSeconds 20
    if (-not $result.Available) { return New-CheckOutcome -Status Unavailable -Message 'powercfg.exe is unavailable.' }
    if (-not $result.Started) { return New-CheckOutcome -Status Failed -Message 'The sleep-state query could not start.' }
    if ($result.TimedOut -or $result.ExitCode -ne 0) { return New-CheckOutcome -Status Failed -Message 'The sleep-state query did not complete successfully.' -ExitCode $result.ExitCode }
    $data = [pscustomobject][ordered]@{
        QueryCompleted        = $true
        ProcessStarted        = [bool]$result.Started
        TimedOut              = [bool]$result.TimedOut
        ExitCode              = $result.ExitCode
        StandardOutputPresent = [bool]$result.StandardOutputPresent
        StandardOutputLength  = $result.StandardOutputLength
        StandardErrorPresent  = [bool]$result.StandardErrorPresent
        StandardErrorLength   = $result.StandardErrorLength
        LocalizedOutputParsed = $false
        RawOutputSaved        = $false
    }
    return New-CheckOutcome -Status Passed -Data $data -ExitCode $result.ExitCode
}

function Get-ActivePowerPlanInformation {
    param($Context)

    $result = Invoke-PCFCNativeProcess -FilePath 'powercfg.exe' -Arguments @('/getactivescheme') -TimeoutSeconds 20
    if (-not $result.Available) { return New-CheckOutcome -Status Unavailable -Message 'powercfg.exe is unavailable.' }
    if ($result.TimedOut -or $result.ExitCode -ne 0) { return New-CheckOutcome -Status Failed -Message 'The active power-plan query did not complete successfully.' -ExitCode $result.ExitCode }
    $match = [regex]::Match($result.StdOut, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
    $data = [pscustomobject][ordered]@{ SchemeGuid = if ($match.Success) { $match.Value } else { $null }; LocalizedNameOmitted = $true }
    return New-CheckOutcome -Status Passed -Data $data -ExitCode $result.ExitCode
}

function Get-InstalledProgramInformation {
    param($Context)

    $paths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $items = @(Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName } | Sort-Object DisplayName, DisplayVersion -Unique | ForEach-Object {
        [pscustomobject][ordered]@{ DisplayName = $_.DisplayName; DisplayVersion = $_.DisplayVersion; Publisher = $_.Publisher; InstallDate = $_.InstallDate }
    })
    return New-CheckOutcome -Status Passed -Data $items
}

function Get-NetworkAdapterInformation {
    param($Context)

    if (-not (Test-CommandAvailable 'Get-NetAdapter')) { return New-CheckOutcome -Status Unavailable -Message 'Get-NetAdapter is unavailable.' }
    $items = @(Get-NetAdapter -ErrorAction Stop | ForEach-Object {
        [pscustomobject][ordered]@{ Name = $_.Name; InterfaceDescription = $_.InterfaceDescription; Status = [string]$_.Status; LinkSpeed = $_.LinkSpeed }
    })
    return New-CheckOutcome -Status Passed -Data $items
}

function Get-EventInformation {
    param($Context, [bool]$WheaOnly)

    if (-not (Test-CommandAvailable 'Get-WinEvent')) { return New-CheckOutcome -Status Unavailable -Message 'Get-WinEvent is unavailable.' }
    $days = if ($WheaOnly) { 90 } else { 30 }
    $start = (Get-Date).AddDays(-$days)
    $filter = if ($WheaOnly) {
        @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WHEA-Logger'; StartTime = $start }
    }
    else {
        @{ LogName = 'System'; Level = 1, 2; StartTime = $start }
    }
    try { $events = @(Get-WinEvent -FilterHashtable $filter -MaxEvents 300 -ErrorAction Stop) } catch {
        if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*') { $events = @() } else { return New-CheckOutcome -Status Unavailable -Message 'The requested System event-log view is unavailable.' }
    }
    $safe = @($events | ForEach-Object {
        $entry = [ordered]@{ TimeCreated = if ($_.TimeCreated) { $_.TimeCreated.ToString('o') } else { $null }; Id = $_.Id; ProviderName = $_.ProviderName; Level = $_.LevelDisplayName }
        [pscustomobject]$entry
    })
    $times = @($events | Where-Object { $_.TimeCreated } | ForEach-Object { $_.TimeCreated } | Sort-Object)
    $data = [pscustomobject][ordered]@{
        EventCount    = $safe.Count
        RequestedFrom = $start.ToString('o')
        ObservedFirst = if ($times.Count -gt 0) { $times[0].ToString('o') } else { $null }
        ObservedLast  = if ($times.Count -gt 0) { $times[$times.Count - 1].ToString('o') } else { $null }
        Events        = $safe
    }
    if ($safe.Count -gt 0) {
        $message = if ($WheaOnly) { 'WHEA events were observed in the requested time range; this is not proof of permanent hardware failure.' } else { 'Critical or error System events were observed in the requested time range.' }
        return New-CheckOutcome -Status Warning -Data $data -Message $message
    }
    return New-CheckOutcome -Status Passed -Data $data
}

function Invoke-IntegrityCommand {
    param($Context, [string]$FilePath, [string[]]$Arguments, [int]$TimeoutSeconds)

    $result = Invoke-PCFCNativeProcess -FilePath $FilePath -Arguments $Arguments -TimeoutSeconds $TimeoutSeconds
    $data = [pscustomobject][ordered]@{
        Executable                 = $FilePath
        Arguments                  = @($Arguments)
        ProcessStarted             = [bool]$result.Started
        TimedOut                   = [bool]$result.TimedOut
        ExitCode                   = $result.ExitCode
        StdOutCaptured             = -not [string]::IsNullOrWhiteSpace($result.StdOut)
        StdErrCaptured             = -not [string]::IsNullOrWhiteSpace($result.StdErr)
        ExpectedOutputFileRequired = $false
        FailureKind                = $result.FailureKind
        LocalizedOutputParsed      = $false
        RawOutputSaved             = $false
    }
    if (-not $result.Available) { return New-CheckOutcome -Status Unavailable -Data $data -Message "$FilePath is unavailable." }
    if (-not $result.Started) {
        return New-CheckOutcome -Status Failed -Data $data -Message 'The command could not start; no filesystem-health conclusion was made.'
    }
    if ($result.TimedOut) { return New-CheckOutcome -Status Failed -Data $data -Message "The command exceeded the $TimeoutSeconds-second timeout." }
    if ($result.ExitCode -ne 0) { return New-CheckOutcome -Status Failed -Data $data -Message 'The command returned a non-zero exit code; localized output was not interpreted.' -ExitCode $result.ExitCode }
    return New-CheckOutcome -Status Passed -Data $data -Message 'The command completed with exit code 0; localized text was not used to infer additional health claims.' -ExitCode $result.ExitCode
}

function Get-CheckDefinitions {
    param([string]$SelectedMode)

    $definitions = @(
        (New-Definition 'WindowsInfo' 'Windows information' 'Checking Windows information' { param($c) Get-WindowsInformation $c }),
        (New-Definition 'SystemInfo' 'Computer manufacturer and model' 'Checking computer model' { param($c) Get-SystemInformation $c }),
        (New-Definition 'CPU' 'Processor' 'Checking CPU' { param($c) Get-CpuInformation $c }),
        (New-Definition 'Memory' 'Memory' 'Checking memory' { param($c) Get-MemoryInformation $c }),
        (New-Definition 'Display' 'Graphics and displays' 'Checking graphics and displays' { param($c) Get-DisplayInformation $c }),
        (New-Definition 'Storage' 'Physical storage' 'Checking storage health' { param($c) Get-StorageInformation $c }),
        (New-Definition 'Volumes' 'Volumes and free space' 'Checking volumes and free space' { param($c) Get-VolumeInformation $c }),
        (New-Definition 'ProblemDevices' 'Problem devices' 'Checking problem devices' { param($c) Get-ProblemDevices $c }),
        (New-Definition 'Defender' 'Microsoft Defender' 'Checking Microsoft Defender' { param($c) Get-DefenderInformation $c })
    )

    if ($SelectedMode -in @('Standard', 'Full')) {
        $definitions += @(
            (New-Definition 'TPM' 'Trusted Platform Module' 'Checking TPM' { param($c) Get-TpmInformation $c }),
            (New-Definition 'SecureBoot' 'Secure Boot' 'Checking Secure Boot' { param($c) Get-SecureBootInformation $c }),
            (New-Definition 'WindowsUpdates' 'Recent Windows updates' 'Checking recent Windows updates' { param($c) Get-UpdateInformation $c }),
            (New-Definition 'StorageReliability' 'Storage reliability counters' 'Checking storage reliability counters' { param($c) Get-StorageReliabilityInformation $c }),
            (New-Definition 'SignedDrivers' 'Signed drivers' 'Checking signed drivers' { param($c) Get-DriverInformation $c }),
            (New-Definition 'Battery' 'Battery health' 'Checking battery metrics' { param($c) Get-BatteryInformation $c }),
            (New-Definition 'SleepStates' 'Sleep-state availability' 'Checking sleep-state availability' { param($c) Get-SleepStateInformation $c }),
            (New-Definition 'ActivePowerPlan' 'Active power plan' 'Checking active power plan' { param($c) Get-ActivePowerPlanInformation $c }),
            (New-Definition 'InstalledPrograms' 'Installed programs' 'Checking installed programs' { param($c) Get-InstalledProgramInformation $c }),
            (New-Definition 'NetworkAdapters' 'Network adapters' 'Checking network adapters' { param($c) Get-NetworkAdapterInformation $c }),
            (New-Definition 'CriticalSystemEvents' 'Recent critical System events' 'Checking recent critical System events' { param($c) Get-EventInformation $c $false }),
            (New-Definition 'WHEAEvents' 'WHEA event summary' 'Checking WHEA events' { param($c) Get-EventInformation $c $true })
        )
    }

    if ($SelectedMode -eq 'Full') {
        $definitions += @(
            (New-Definition 'DismCheckHealth' 'DISM CheckHealth' 'Running DISM CheckHealth' { param($c) Invoke-IntegrityCommand $c 'dism.exe' @('/Online', '/Cleanup-Image', '/CheckHealth') 300 }),
            (New-Definition 'SfcVerifyOnly' 'SFC verify-only' 'Running SFC verify-only' { param($c) Invoke-IntegrityCommand $c 'sfc.exe' @('/verifyonly') 900 }),
            (New-Definition 'ChkdskOnlineScan' 'CHKDSK online scan' 'Running CHKDSK online scan' { param($c) Invoke-ChkdskOnlineScan $c }),
            (New-PrivacyOnlyOmittedDefinition 'EnergyReport' 'Power energy report' 'Omitting power energy report in privacy mode'),
            (New-PrivacyOnlyOmittedDefinition 'BatteryReport' 'Raw battery report' 'Omitting raw battery report in privacy mode'),
            (New-PrivacyOnlyOmittedDefinition 'SleepStudy' 'Raw sleep study' 'Omitting sleep study in privacy mode'),
            (New-PrivacyOnlyOmittedDefinition 'SleepDiagnostics' 'Raw sleep diagnostics' 'Omitting raw sleep diagnostics in privacy mode'),
            (New-PrivacyOnlyOmittedDefinition 'MSInfo32' 'MSINFO32 report' 'Omitting MSINFO32 report in privacy mode'),
            (New-PrivacyOnlyOmittedDefinition 'DxDiag' 'DXDIAG report' 'Omitting DXDIAG report in privacy mode'),
            (New-PrivacyOnlyOmittedDefinition 'DeviceRegistration' 'Device registration details' 'Omitting device registration details in privacy mode'),
            (New-PrivacyOnlyOmittedDefinition 'LicenseDetails' 'Windows license details' 'Omitting Windows license details in privacy mode')
        )
    }

    return $definitions
}

function ConvertTo-HtmlText {
    param([AllowNull()]$Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return 'Unavailable' }
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Convert-BytesToGiB {
    param([AllowNull()]$Bytes)
    if ($null -eq $Bytes) { return 'Unavailable' }
    return ('{0:N1} GiB' -f ([double]$Bytes / 1GB))
}

function Get-Assessment {
    param($Context)

    $essential = @('WindowsInfo', 'SystemInfo', 'CPU', 'Memory', 'Display', 'Storage', 'Volumes', 'ProblemDevices', 'Defender')
    $critical = @($Context.Results | Where-Object { $_.Critical })
    $warnings = @($Context.Results | Where-Object { $_.Status -eq 'Warning' })
    $failed = @($Context.Results | Where-Object { $_.Status -eq 'Failed' })
    $essentialIncomplete = @($Context.Results | Where-Object { $essential -contains $_.Name -and $_.Status -notin @('Passed', 'Warning') })
    if ($critical.Count -gt 0) { return 'Critical' }
    if ($failed.Count -gt 0 -or $essentialIncomplete.Count -gt 0) { return 'Unknown' }
    if ($warnings.Count -gt 0) { return 'Attention required' }
    return 'Good'
}

function Get-StatusCount {
    param($Results, [string]$Status)
    return @($Results | Where-Object { $_.Status -eq $Status }).Count
}

function Get-CompletionExitCode {
    param($Results)

    if ((Get-StatusCount -Results $Results -Status 'Failed') -gt 0) { return 1 }
    return 0
}

function New-SummaryObject {
    param($Context)

    $windows = $Context.Data['WindowsInfo']
    $system = $Context.Data['SystemInfo']
    $cpu = @($Context.Data['CPU'])
    $memory = $Context.Data['Memory']
    $display = $Context.Data['Display']
    $storage = @($Context.Data['Storage'])
    $battery = $Context.Data['Battery']
    $problems = $Context.Data['ProblemDevices']
    $whea = $Context.Data['WHEAEvents']
    $integrityNames = @('DismCheckHealth', 'SfcVerifyOnly', 'ChkdskOnlineScan')
    $integrity = @($Context.Results | Where-Object { $integrityNames -contains $_.Name } | ForEach-Object { [pscustomobject][ordered]@{ Name = $_.Name; Status = $_.Status; ExitCode = $_.ExitCode; Message = $_.Message } })
    $defenderResult = $Context.Results | Where-Object { $_.Name -eq 'Defender' } | Select-Object -First 1
    $storageReliabilityResult = $Context.Results | Where-Object { $_.Name -eq 'StorageReliability' } | Select-Object -First 1

    return [pscustomobject][ordered]@{
        Tool = [pscustomobject][ordered]@{ Name = $script:ToolName; Version = $script:ToolVersion; Author = 'Ayman Bounaouj' }
        GeneratedAt = [DateTime]::Now.ToString('o')
        Mode = $Context.Mode
        Privacy = [pscustomobject][ordered]@{ SensitiveDataIncluded = $false; State = 'Privacy mode only (v0.2.0-beta)' }
        Assessment = Get-Assessment -Context $Context
        System = [pscustomobject][ordered]@{
            Windows = $windows
            Manufacturer = if ($system) { $system.Manufacturer } else { $null }
            Model = if ($system) { $system.Model } else { $null }
            CPU = if ($cpu.Count -gt 0) { $cpu[0] } else { $null }
            TotalRAMBytes = if ($memory) { $memory.TotalPhysicalMemoryBytes } else { $null }
            GPUs = if ($display) { $display.GPUs } else { @() }
            Storage = $storage
            Battery = $battery
        }
        Findings = [pscustomobject][ordered]@{
            ProblemDeviceCount = if ($problems) { $problems.ProblemDeviceCount } else { $null }
            WHEAEventCount = if ($whea) { $whea.EventCount } else { $null }
            WHEAObservedFirst = if ($whea) { $whea.ObservedFirst } else { $null }
            WHEAObservedLast = if ($whea) { $whea.ObservedLast } else { $null }
            StorageReliabilityStatus = if ($storageReliabilityResult) { $storageReliabilityResult.Status } else { 'Unavailable' }
            WindowsIntegrity = $integrity
            DefenderStatus = if ($defenderResult) { $defenderResult.Status } else { 'Unavailable' }
        }
        Counts = [pscustomobject][ordered]@{
            Completed = $Context.Results.Count
            Passed = Get-StatusCount $Context.Results 'Passed'
            Warning = Get-StatusCount $Context.Results 'Warning'
            Failed = Get-StatusCount $Context.Results 'Failed'
            Unavailable = Get-StatusCount $Context.Results 'Unavailable'
            Omitted = Get-StatusCount $Context.Results 'Omitted'
        }
        Checks = @($Context.Results)
        Limitations = @(
            'Results depend on hardware, Windows edition, permissions, drivers, and supported system capabilities.',
            'Unavailable and omitted checks are not treated as healthy.',
            'Localized native-command text is not parsed to make additional health claims.',
            'This report is a diagnostic aid and not a professional certification.'
        )
    }
}

function Write-SummaryFiles {
    param($Context, $Summary)

    Write-Utf8File -OutputDirectory $Context.OutputDirectory -RelativePath '00_HEALTH_SUMMARY.json' -Content ($Summary | ConvertTo-Json -Depth 15)

    $windowsText = if ($Summary.System.Windows) { '{0} {1} (build {2}, {3})' -f $Summary.System.Windows.Caption, $Summary.System.Windows.Version, $Summary.System.Windows.BuildNumber, $Summary.System.Windows.OSArchitecture } else { 'Unavailable' }
    $cpuText = if ($Summary.System.CPU) { $Summary.System.CPU.Name } else { 'Unavailable' }
    $gpuText = if (@($Summary.System.GPUs).Count -gt 0) { (@($Summary.System.GPUs) | ForEach-Object { $_.Name }) -join ', ' } else { 'Unavailable' }
    $storageText = if (@($Summary.System.Storage).Count -gt 0) { (@($Summary.System.Storage) | ForEach-Object { '{0} ({1}, {2})' -f $_.FriendlyName, (Convert-BytesToGiB $_.SizeBytes), $_.MediaType }) -join '; ' } else { 'Unavailable' }
    $storageHealth = if (@($Summary.System.Storage).Count -gt 0) { (@($Summary.System.Storage) | ForEach-Object { $_.HealthStatus }) -join ', ' } else { 'Unavailable' }
    $batteryText = if ($Summary.System.Battery -and $null -ne $Summary.System.Battery.EstimatedHealthPercent) { $Summary.System.Battery.EstimatedHealthPercent.ToString() + '% estimated capacity' } else { 'Unavailable' }
    $integrityText = if (@($Summary.Findings.WindowsIntegrity).Count -gt 0) { (@($Summary.Findings.WindowsIntegrity) | ForEach-Object { $_.Name + ': ' + $_.Status }) -join '; ' } else { 'Not executed in this mode' }

    $rows = @(
        @('Final assessment', $Summary.Assessment),
        @('Windows version', $windowsText),
        @('Manufacturer and model', (($Summary.System.Manufacturer, $Summary.System.Model | Where-Object { $_ }) -join ' ')),
        @('CPU', $cpuText),
        @('Total RAM', (Convert-BytesToGiB $Summary.System.TotalRAMBytes)),
        @('GPU', $gpuText),
        @('Storage overview', $storageText),
        @('Storage health', $storageHealth),
        @('Storage reliability', $Summary.Findings.StorageReliabilityStatus),
        @('Battery health', $batteryText),
        @('Problem-device count', $(if ($null -eq $Summary.Findings.ProblemDeviceCount) { 'Unavailable' } else { $Summary.Findings.ProblemDeviceCount })),
        @('WHEA event count', $(if ($null -eq $Summary.Findings.WHEAEventCount) { 'Unavailable' } else { $Summary.Findings.WHEAEventCount })),
        @('WHEA observed range', (($Summary.Findings.WHEAObservedFirst, $Summary.Findings.WHEAObservedLast | Where-Object { $_ }) -join ' to ')),
        @('Windows integrity checks', $integrityText),
        @('Microsoft Defender', $Summary.Findings.DefenderStatus)
    )
    $tableRows = ($rows | ForEach-Object { '<tr><th>' + (ConvertTo-HtmlText $_[0]) + '</th><td>' + (ConvertTo-HtmlText $_[1]) + '</td></tr>' }) -join [Environment]::NewLine
    $checkRows = ($Summary.Checks | ForEach-Object { '<tr><td>' + (ConvertTo-HtmlText $_.DisplayName) + '</td><td><span class="status ' + (ConvertTo-HtmlText $_.Status.ToLowerInvariant()) + '">' + (ConvertTo-HtmlText $_.Status) + '</span></td><td>' + (ConvertTo-HtmlText $_.DurationMs) + '</td><td>' + (ConvertTo-HtmlText $_.Message) + '</td></tr>' }) -join [Environment]::NewLine

    $html = @"
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>PC Full Check health summary</title>
<style>body{font-family:Segoe UI,Arial,sans-serif;margin:0;background:#f4f6f8;color:#1f2933}main{max-width:1050px;margin:2rem auto;padding:0 1rem}.card{background:#fff;border:1px solid #d9e2ec;border-radius:10px;padding:1.25rem;margin-bottom:1rem}h1,h2{margin-top:0}table{border-collapse:collapse;width:100%}th,td{text-align:left;vertical-align:top;border-bottom:1px solid #e5e7eb;padding:.65rem}th{width:28%}.status{font-weight:700}.passed{color:#16794b}.warning{color:#9a6700}.failed{color:#b42318}.unavailable,.omitted{color:#52606d}.notice{border-left:5px solid #52606d;padding-left:1rem}.sensitive{border-left-color:#b42318}.counts{display:flex;flex-wrap:wrap;gap:.75rem}.counts span{background:#eef2f6;padding:.5rem .75rem;border-radius:6px}</style></head>
<body><main><section class="card"><h1>$(ConvertTo-HtmlText $Summary.Tool.Name)</h1><p>Version $(ConvertTo-HtmlText $Summary.Tool.Version) - $(ConvertTo-HtmlText $Summary.GeneratedAt) - Mode: $(ConvertTo-HtmlText $Summary.Mode)</p><p class="notice$(if ($Summary.Privacy.SensitiveDataIncluded) { ' sensitive' } else { '' })"><strong>Privacy:</strong> $(ConvertTo-HtmlText $Summary.Privacy.State)</p></section>
<section class="card"><h2>Health summary</h2><table>$tableRows</table></section>
<section class="card"><h2>Check counts</h2><div class="counts"><span>Completed: $(ConvertTo-HtmlText $Summary.Counts.Completed)</span><span>Passed: $(ConvertTo-HtmlText $Summary.Counts.Passed)</span><span>Warnings: $(ConvertTo-HtmlText $Summary.Counts.Warning)</span><span>Failed: $(ConvertTo-HtmlText $Summary.Counts.Failed)</span><span>Unavailable: $(ConvertTo-HtmlText $Summary.Counts.Unavailable)</span><span>Omitted: $(ConvertTo-HtmlText $Summary.Counts.Omitted)</span></div></section>
<section class="card"><h2>Checks</h2><table><thead><tr><th>Check</th><th>Status</th><th>Duration (ms)</th><th>Note</th></tr></thead><tbody>$checkRows</tbody></table></section>
<section class="card"><h2>Limitations</h2><ul><li>$((@($Summary.Limitations) | ForEach-Object { ConvertTo-HtmlText $_ }) -join '</li><li>')</li></ul><p><strong>This is a diagnostic aid and not a professional certification.</strong></p></section></main></body></html>
"@
    Write-Utf8File -OutputDirectory $Context.OutputDirectory -RelativePath '00_HEALTH_SUMMARY.html' -Content $html

    $readMe = @"
PC Full Check for Windows $($Summary.Tool.Version)

Mode: $($Summary.Mode)
Privacy: $($Summary.Privacy.State)
Assessment: $($Summary.Assessment)

Start with 00_HEALTH_SUMMARY.html or 00_HEALTH_SUMMARY.json.
Unavailable and omitted checks are not positive health findings.
This report stays local unless you choose to share it.
This tool is a diagnostic aid and not a professional certification.
"@
    Write-Utf8File -OutputDirectory $Context.OutputDirectory -RelativePath '00_READ_ME.txt' -Content $readMe
}

# Startup validation occurs before output creation so an unsupported or unelevated
# run cannot leave a misleading partial report.
if ($env:OS -ne 'Windows_NT') {
    Write-Error 'Unsupported platform. PC Full Check supports Windows 10 and Windows 11 only.'
    exit 2
}
if ($PSVersionTable.PSVersion -lt [Version]'5.1') {
    Write-Error 'Unsupported PowerShell version. PowerShell 5.1 or later is required.'
    exit 2
}
if (-not (Test-CommandAvailable 'Get-CimInstance')) {
    Write-Error 'Required Windows CIM support is unavailable.'
    exit 2
}
try {
    $startupOs = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    if ($startupOs.Caption -notmatch 'Windows 10|Windows 11') {
        Write-Error ('Unsupported Windows version: ' + $startupOs.Caption + '. Windows 10 or Windows 11 is required.')
        exit 2
    }
}
catch {
    Write-Error 'Windows version detection failed. No report was created.'
    exit 2
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdministrator) {
    $rerun = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" -Mode ' + $Mode
    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) { $rerun += ' -OutputPath "' + $OutputPath.Replace('"', '""') + '"' }
    Write-Host 'Administrator privileges are required for consistent access to read-only storage, security, firmware, and integrity checks.' -ForegroundColor Yellow
    Write-Host 'Open Start, search for Windows PowerShell, right-click it, and choose Run as administrator.'
    Write-Host 'Then run this exact command:'
    Write-Host $rerun
    exit 2
}

try {
    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $desktop = [Environment]::GetFolderPath('Desktop')
        if ([string]::IsNullOrWhiteSpace($desktop)) { throw 'The current user Desktop path is unavailable.' }
        $reportDirectory = Join-Path $desktop ('PC_FULL_CHECK_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
    }
    else {
        $reportDirectory = $OutputPath
    }
    $reportDirectory = Initialize-PCFCOutputDirectory -RequestedPath $reportDirectory
}
catch {
    Write-Error ('Output initialization failed. No diagnostic checks were run. ' + $_.Exception.Message)
    exit 2
}

$context = [pscustomobject]@{
    OutputDirectory = $reportDirectory
    Mode = $Mode
    SensitiveMode = $false
    Results = New-Object System.Collections.ArrayList
    Data = @{}
}

try {
    Write-Utf8File -OutputDirectory $context.OutputDirectory -RelativePath 'run.log' -Content ''
    Write-RunLog -Context $context -Message ("Run started; ToolVersion=$ToolVersion; Mode=$Mode; Privacy=Only")
}
catch {
    Write-Error 'Output initialization failed. No diagnostic checks were run. The report destination became unavailable or unsafe.'
    exit 2
}

$definitions = @(Get-CheckDefinitions -SelectedMode $Mode)
for ($index = 0; $index -lt $definitions.Count; $index++) {
    Invoke-DiagnosticCheck -Context $context -Definition $definitions[$index] -Index ($index + 1) -Total $definitions.Count
}

try {
    $summary = New-SummaryObject -Context $context
    Write-SummaryFiles -Context $context -Summary $summary
}
catch {
    try { Write-RunLog -Context $context -Message 'Summary generation failed; ExitStatus=2' } catch { }
    Write-Error ('Summary generation failed. ' + (Get-SafeExceptionMessage -Exception $_.Exception))
    exit 2
}

$failedCount = Get-StatusCount $context.Results 'Failed'
$exitCode = Get-CompletionExitCode -Results $context.Results
try {
    Write-RunLog -Context $context -Message ("Run completed; Assessment=$($summary.Assessment); FailedChecks=$failedCount; ExitStatus=$exitCode")
}
catch {
    Write-Error 'Final report logging failed because the report destination became unavailable or unsafe.'
    exit 2
}
Write-Host ''
Write-Host ("Completed with assessment: " + $summary.Assessment)
Write-Host ("Report directory: " + $reportDirectory)
exit $exitCode
