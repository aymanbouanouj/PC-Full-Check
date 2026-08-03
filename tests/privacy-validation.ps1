<#
.SYNOPSIS
Scans one or more generated privacy-mode report directories for identifiers.

.DESCRIPTION
Uses exact local identifiers in memory plus conservative contextual patterns.
Matched secret values are never printed or written to disk.

.PARAMETER ReportPath
One or more generated report directories inside the current project.

.OUTPUTS
Counts and finding locations without matched values.

.NOTES
Exit 0: no confirmed direct identifier.
Exit 1: one or more confirmed direct identifiers.
Exit 2: invalid input or startup failure.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string[]]$ReportPath
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\')
$AllowedExtensions = @('.json', '.html', '.txt', '.log', '.csv', '.xml')
$Confirmed = New-Object System.Collections.ArrayList
$Potential = New-Object System.Collections.ArrayList
$Ignored = New-Object System.Collections.ArrayList
$FindingKeys = @{}

function Stop-PrivacyValidation {
    param([string]$SafeMessage)
    Write-Host ('ERROR: ' + $SafeMessage) -ForegroundColor Red
    exit 2
}

function Get-ProjectRelativePath {
    param([string]$FullPath)
    return $FullPath.Substring($script:ProjectRoot.Length).TrimStart('\')
}

function Test-PathInsideProject {
    param([string]$FullPath)
    $prefix = $script:ProjectRoot + [System.IO.Path]::DirectorySeparatorChar
    return $FullPath.Equals($script:ProjectRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        $FullPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-ReparsePointInProjectPath {
    param([string]$FullPath)
    $item = Get-Item -LiteralPath $FullPath -Force -ErrorAction Stop
    while ($null -ne $item -and (Test-PathInsideProject -FullPath $item.FullName)) {
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { return $true }
        if ($item.FullName.Equals($script:ProjectRoot, [System.StringComparison]::OrdinalIgnoreCase)) { break }
        $item = $item.Parent
    }
    return $false
}

function Add-Finding {
    param(
        [ValidateSet('Confirmed', 'Potential', 'Ignored')][string]$Kind,
        [string]$Category,
        [string]$File,
        [int]$Line
    )
    $key = $Kind + '|' + $Category + '|' + $File + '|' + $Line
    if ($script:FindingKeys.ContainsKey($key)) { return }
    $script:FindingKeys[$key] = $true
    $finding = [pscustomobject]@{ Category = $Category; File = $File; Line = $Line }
    if ($Kind -eq 'Confirmed') { [void]$script:Confirmed.Add($finding) }
    elseif ($Kind -eq 'Potential') { [void]$script:Potential.Add($finding) }
    else { [void]$script:Ignored.Add($finding) }
}

function Test-UsableIdentifier {
    param([AllowNull()][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    $trimmed = $Value.Trim()
    if ($trimmed -match '^(?i:unknown|none|not applicable|n/a|default string|to be filled by o\.e\.m\.|system serial number|0+|f+)$') { return $false }
    return $true
}

function Add-ExactIdentifier {
    param([System.Collections.ArrayList]$List, [string]$Category, [AllowNull()]$Value, [bool]$ContextOnly = $false)
    if ($null -eq $Value) { return }
    $text = ([string]$Value).Trim()
    if (-not (Test-UsableIdentifier -Value $text)) { return }
    [void]$List.Add([pscustomobject]@{ Category = $Category; Value = $text; ContextOnly = $ContextOnly })
}

function Get-NormalizedMac {
    param([string]$Value)
    return ($Value -replace '[:-]', '').ToUpperInvariant()
}

function Test-ExactText {
    param([string]$Text, [string]$Value)
    return $Text.IndexOf($Value, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
}

try {
    $resolvedDirectories = New-Object System.Collections.ArrayList
    foreach ($candidate in $ReportPath) {
        $resolved = (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).ProviderPath
        $full = [System.IO.Path]::GetFullPath($resolved).TrimEnd('\')
        if (-not (Test-PathInsideProject -FullPath $full)) { Stop-PrivacyValidation 'A report path is outside the current project.' }
        if (-not (Test-Path -LiteralPath $full -PathType Container)) { Stop-PrivacyValidation 'Every report path must be a directory.' }
        if (Test-ReparsePointInProjectPath -FullPath $full) { Stop-PrivacyValidation 'Reparse-point report paths are not accepted.' }
        if (-not (Test-Path -LiteralPath (Join-Path $full '00_HEALTH_SUMMARY.json') -PathType Leaf)) { Stop-PrivacyValidation 'A report directory is missing its health summary.' }
        if (-not (@($resolvedDirectories | Where-Object { $_.Equals($full, [System.StringComparison]::OrdinalIgnoreCase) }).Count)) {
            [void]$resolvedDirectories.Add($full)
        }
    }
    if ($resolvedDirectories.Count -eq 0) { Stop-PrivacyValidation 'No report directory was supplied.' }

    $files = @($resolvedDirectories | ForEach-Object {
        Get-ChildItem -LiteralPath $_ -Recurse -File -Force -ErrorAction Stop | Where-Object { $script:AllowedExtensions -contains $_.Extension.ToLowerInvariant() }
    } | Sort-Object FullName -Unique)
    if ($files.Count -eq 0) { Stop-PrivacyValidation 'No supported text report file was found.' }
    foreach ($file in $files) {
        if (-not (Test-PathInsideProject -FullPath $file.FullName)) { Stop-PrivacyValidation 'A discovered file is outside the current project.' }
        if (($file.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { Stop-PrivacyValidation 'Reparse-point report files are not accepted.' }
    }
}
catch {
    Stop-PrivacyValidation 'Report-path validation failed.'
}

# Identifiers remain only in process memory. Collection failures are intentionally
# silent because a missing local source is not itself a privacy leak.
$exactIdentifiers = New-Object System.Collections.ArrayList
$currentUser = [Environment]::UserName
$computerName = [Environment]::MachineName
$userProfile = [Environment]::GetFolderPath('UserProfile')
Add-ExactIdentifier -List $exactIdentifiers -Category 'CurrentUserName' -Value $currentUser -ContextOnly $true
Add-ExactIdentifier -List $exactIdentifiers -Category 'ComputerName' -Value $computerName -ContextOnly $true
Add-ExactIdentifier -List $exactIdentifiers -Category 'UserProfilePath' -Value $userProfile

try { Add-ExactIdentifier -List $exactIdentifiers -Category 'BiosSerial' -Value ((Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop | Select-Object -First 1).SerialNumber) } catch { }
try { Add-ExactIdentifier -List $exactIdentifiers -Category 'ComputerSystemUuid' -Value ((Get-CimInstance -ClassName Win32_ComputerSystemProduct -ErrorAction Stop | Select-Object -First 1).UUID) } catch { }
try { Add-ExactIdentifier -List $exactIdentifiers -Category 'BaseboardSerial' -Value ((Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction Stop | Select-Object -First 1).SerialNumber) } catch { }
try {
    if (Get-Command -Name Get-PhysicalDisk -ErrorAction SilentlyContinue) {
        foreach ($value in @(Get-PhysicalDisk -ErrorAction Stop | ForEach-Object { $_.SerialNumber })) { Add-ExactIdentifier -List $exactIdentifiers -Category 'DiskSerial' -Value $value }
    }
} catch { }
try {
    foreach ($value in @(Get-CimInstance -ClassName Win32_DiskDrive -ErrorAction Stop | ForEach-Object { $_.SerialNumber })) { Add-ExactIdentifier -List $exactIdentifiers -Category 'DiskSerial' -Value $value }
} catch { }

$localMacs = @{}
try {
    if (Get-Command -Name Get-NetAdapter -ErrorAction SilentlyContinue) {
        foreach ($value in @(Get-NetAdapter -ErrorAction Stop | ForEach-Object { $_.MacAddress })) {
            if (Test-UsableIdentifier -Value $value) { $localMacs[(Get-NormalizedMac -Value $value)] = $true }
        }
    }
} catch { }
try {
    foreach ($value in @(Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -ErrorAction Stop | ForEach-Object { $_.MACAddress })) {
        if (Test-UsableIdentifier -Value $value) { $localMacs[(Get-NormalizedMac -Value $value)] = $true }
    }
} catch { }

$emailRegex = New-Object System.Text.RegularExpressions.Regex('(?i)(?<![A-Z0-9._%+\-])[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}(?![A-Z0-9._%+\-])')
$ipv4LikeRegex = New-Object System.Text.RegularExpressions.Regex('(?<![0-9.])(?:[0-9]{1,5}\.){3}[0-9]{1,5}(?![0-9.])')
$macRegex = New-Object System.Text.RegularExpressions.Regex('(?i)(?<![0-9A-F])(?:[0-9A-F]{2}[:-]){5}[0-9A-F]{2}(?![0-9A-F])')
$guidRegex = New-Object System.Text.RegularExpressions.Regex('(?i)(?<![0-9A-F])[0-9A-F]{8}(?:-[0-9A-F]{4}){3}-[0-9A-F]{12}(?![0-9A-F])')
$profilePatternRegex = New-Object System.Text.RegularExpressions.Regex('(?i)(?:[A-Z]:)?\\Users\\[^\\\s"'']+\\')

try {
    foreach ($file in $files) {
        $relativeFile = Get-ProjectRelativePath -FullPath $file.FullName
        $lineNumber = 0
        foreach ($line in @(Get-Content -LiteralPath $file.FullName -ErrorAction Stop)) {
            $lineNumber++
            $normalizedLine = $line.Replace('\\', '\')

            $userContextFound = $false
            if (Test-UsableIdentifier -Value $currentUser) {
                $escapedUser = [regex]::Escape($currentUser)
                $userPatterns = @(
                    '(?i)(?:[A-Z]:)?\\Users\\' + $escapedUser + '(?:\\|["''\s]|$)',
                    '(?i)\bUSERNAME\s*=\s*["'']?' + $escapedUser + '(?:["'']|\s|$)',
                    '(?i)["'']?(?:UserName|User)["'']?\s*[:=]\s*["'']?' + $escapedUser + '["'']?(?:\s*[,}]|\s*$)'
                )
                foreach ($pattern in $userPatterns) {
                    if ($normalizedLine -match $pattern) { Add-Finding -Kind Confirmed -Category 'CurrentUserName' -File $relativeFile -Line $lineNumber; $userContextFound = $true; break }
                }
                if ($currentUser.Length -le 3 -and -not $userContextFound -and $normalizedLine -match ('(?i)(?<![A-Z0-9_])' + $escapedUser + '(?![A-Z0-9_])')) {
                    Add-Finding -Kind Ignored -Category 'AmbiguousShortUserValueOutsideIdentityContext' -File $relativeFile -Line $lineNumber
                }
            }

            if (Test-UsableIdentifier -Value $computerName) {
                $escapedComputer = [regex]::Escape($computerName)
                if ($normalizedLine -match ('(?i)["'']?(?:ComputerName|HostName|MachineName)["'']?\s*[:=]\s*["'']?' + $escapedComputer + '["'']?(?:\s*[,}]|\s*$)') -or
                    $normalizedLine -match ('(?i)\bCOMPUTERNAME\s*=\s*["'']?' + $escapedComputer + '(?:["'']|\s|$)')) {
                    Add-Finding -Kind Confirmed -Category 'ComputerName' -File $relativeFile -Line $lineNumber
                }
            }

            if (Test-UsableIdentifier -Value $userProfile) {
                $normalizedProfile = $userProfile.Replace('\\', '\')
                if (Test-ExactText -Text $normalizedLine -Value $normalizedProfile) { Add-Finding -Kind Confirmed -Category 'UserProfilePath' -File $relativeFile -Line $lineNumber }
            }

            foreach ($identifier in $exactIdentifiers) {
                if ($identifier.Category -in @('CurrentUserName', 'ComputerName', 'UserProfilePath')) { continue }
                $matched = $false
                if (-not $identifier.ContextOnly -and $identifier.Value.Length -ge 4) {
                    $matched = Test-ExactText -Text $normalizedLine -Value $identifier.Value
                }
                else {
                    $escapedValue = [regex]::Escape($identifier.Value)
                    $matched = $normalizedLine -match ('(?i)["'']?(?:SerialNumber|BiosSerial|BaseboardSerial|DiskSerial|UUID|SystemUUID)["'']?\s*[:=]\s*["'']?' + $escapedValue + '["'']?(?:\s*[,}]|\s*$)')
                }
                if ($matched) { Add-Finding -Kind Confirmed -Category $identifier.Category -File $relativeFile -Line $lineNumber }
            }

            foreach ($match in $profilePatternRegex.Matches($normalizedLine)) {
                if (-not (Test-UsableIdentifier -Value $userProfile) -or -not (Test-ExactText -Text $match.Value -Value $userProfile)) {
                    Add-Finding -Kind Potential -Category 'UserProfilePathPattern' -File $relativeFile -Line $lineNumber
                }
            }
            foreach ($match in $emailRegex.Matches($line)) { Add-Finding -Kind Potential -Category 'EmailAddressPattern' -File $relativeFile -Line $lineNumber }

            foreach ($match in $ipv4LikeRegex.Matches($line)) {
                $parts = @($match.Value -split '\.')
                $validOctets = $parts.Count -eq 4 -and @($parts | Where-Object { [int]$_ -lt 0 -or [int]$_ -gt 255 }).Count -eq 0
                $parsedAddress = $null
                $parsed = $validOctets -and [System.Net.IPAddress]::TryParse($match.Value, [ref]$parsedAddress) -and $parsedAddress.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork
                if (-not $parsed) { Add-Finding -Kind Ignored -Category 'InvalidIPv4LikeValue' -File $relativeFile -Line $lineNumber; continue }
                if ($line -match '(?i)["'']?(?:DisplayVersion|DriverVersion|Version|BuildNumber|AntivirusSignatureVersion)["'']?\s*[:=]') {
                    Add-Finding -Kind Ignored -Category 'VersionShapedLikeIPv4' -File $relativeFile -Line $lineNumber
                }
                elseif ($line -match '(?i)["'']?(?:DisplayName|DeviceName|FriendlyName|Manufacturer|Model|PartNumber)["'']?\s*[:=]') {
                    Add-Finding -Kind Ignored -Category 'InventoryMetadataShapedLikeIPv4' -File $relativeFile -Line $lineNumber
                }
                elseif ($parsedAddress.Equals([System.Net.IPAddress]::Loopback) -or $parsedAddress.Equals([System.Net.IPAddress]::Any)) {
                    Add-Finding -Kind Ignored -Category 'NonIdentifyingIPv4Metadata' -File $relativeFile -Line $lineNumber
                }
                else { Add-Finding -Kind Potential -Category 'ValidIPv4Address' -File $relativeFile -Line $lineNumber }
            }

            foreach ($match in $macRegex.Matches($line)) {
                $normalizedMac = Get-NormalizedMac -Value $match.Value
                if ($localMacs.ContainsKey($normalizedMac)) { Add-Finding -Kind Confirmed -Category 'LocalMacAddress' -File $relativeFile -Line $lineNumber }
                else { Add-Finding -Kind Potential -Category 'MacAddressPattern' -File $relativeFile -Line $lineNumber }
            }

            foreach ($match in $guidRegex.Matches($line)) {
                $localUuid = @($exactIdentifiers | Where-Object { $_.Category -eq 'ComputerSystemUuid' -and $_.Value.Equals($match.Value, [System.StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
                if ($localUuid) { Add-Finding -Kind Confirmed -Category 'ComputerSystemUuid' -File $relativeFile -Line $lineNumber; continue }
                if ($line -match '(?i)["'']?(?:TenantId|DeviceId|ObjectId|UserId|AccountId|SubscriptionId|MachineId|RegistrationId|UUID|SystemUUID)["'']?\s*[:=]') {
                    Add-Finding -Kind Potential -Category 'GuidInIdentityContext' -File $relativeFile -Line $lineNumber
                }
                elseif ($line -match '(?i)["'']?(?:SchemeGuid|DisplayName|DeviceName|DriverVersion|ProviderName|HotFixID)["'']?\s*[:=]') {
                    Add-Finding -Kind Ignored -Category 'GuidShapedHarmlessMetadata' -File $relativeFile -Line $lineNumber
                }
                else { Add-Finding -Kind Potential -Category 'GuidShapedValueForReview' -File $relativeFile -Line $lineNumber }
            }
        }
    }
}
catch {
    Stop-PrivacyValidation 'A report file could not be scanned.'
}

Write-Host ('FILES_SCANNED={0}' -f $files.Count)
Write-Host ('CONFIRMED_FINDINGS={0}' -f $Confirmed.Count)
Write-Host ('POTENTIAL_REVIEW={0}' -f $Potential.Count)
Write-Host ('HARMLESS_OR_IGNORED={0}' -f $Ignored.Count)
foreach ($finding in @($Confirmed | Sort-Object File, Line, Category)) {
    Write-Host ('CONFIRMED; Category={0}; File={1}; Line={2}' -f $finding.Category, $finding.File, $finding.Line)
}
foreach ($finding in @($Potential | Sort-Object File, Line, Category)) {
    Write-Host ('POTENTIAL; Category={0}; File={1}; Line={2}' -f $finding.Category, $finding.File, $finding.Line)
}
foreach ($group in @($Ignored | Group-Object Category, File | Sort-Object Name)) {
    $first = $group.Group | Select-Object -First 1
    Write-Host ('IGNORED; Category={0}; File={1}; Count={2}' -f $first.Category, $first.File, $group.Count)
}

if ($Confirmed.Count -gt 0) { exit 1 }
exit 0
