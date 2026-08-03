<#
.SYNOPSIS
Internal production implementation for native execution and CHKDSK online scan.

.DESCRIPTION
This file is loaded by the maintained diagnostic and the isolated integrated
validator. It is not a public entry point. CHKDSK is read-only, uses only the
dynamically verified Windows system volume plus /scan, and never persists raw
stdout or stderr.
#>

$internalScriptPath = $MyInvocation.MyCommand.Path
$script:PCFCNativeProjectRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent (Split-Path -Parent $internalScriptPath))
).TrimEnd('\')

function ConvertTo-PCFCNativeArgument {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Argument)

    if ($Argument.Length -eq 0) { return '""' }
    if ($Argument -notmatch '[\s"]') { return $Argument }

    # Windows CommandLineToArgvW-compatible quoting for PowerShell 5.1/.NET Framework.
    $builder = New-Object System.Text.StringBuilder
    $backslash = [char]92
    $quote = [char]34
    [void]$builder.Append($quote)
    $backslashCount = 0
    foreach ($character in $Argument.ToCharArray()) {
        if ($character -eq $backslash) {
            $backslashCount++
            continue
        }
        if ($character -eq $quote) {
            [void]$builder.Append($backslash, (($backslashCount * 2) + 1))
            [void]$builder.Append($quote)
            $backslashCount = 0
            continue
        }
        if ($backslashCount -gt 0) {
            [void]$builder.Append($backslash, $backslashCount)
            $backslashCount = 0
        }
        [void]$builder.Append($character)
    }
    if ($backslashCount -gt 0) {
        [void]$builder.Append($backslash, ($backslashCount * 2))
    }
    [void]$builder.Append($quote)
    return $builder.ToString()
}

function Resolve-PCFCTrustedWindowsExecutable {
    param([Parameter(Mandatory = $true)][string]$FileName)

    $allowedNames = @('powercfg.exe', 'dism.exe', 'sfc.exe', 'chkdsk.exe')
    if ([string]::IsNullOrWhiteSpace($FileName) -or $allowedNames -notcontains $FileName) { return $null }
    if ([System.IO.Path]::GetFileName($FileName) -ne $FileName -or $FileName.IndexOfAny([char[]]@([char]47, [char]92)) -ge 0) { return $null }

    try {
        $systemDirectory = [Environment]::SystemDirectory
        if ([string]::IsNullOrWhiteSpace($systemDirectory)) { return $null }
        $canonicalSystemDirectory = [System.IO.Path]::GetFullPath($systemDirectory).TrimEnd([char[]]@([char]92, [char]47))
        $systemDirectoryItem = Get-Item -LiteralPath $canonicalSystemDirectory -Force -ErrorAction Stop
        if (-not $systemDirectoryItem.PSIsContainer -or ($systemDirectoryItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) { return $null }

        $candidate = [System.IO.Path]::GetFullPath((Join-Path $canonicalSystemDirectory $FileName))
        $candidateParent = [System.IO.Path]::GetDirectoryName($candidate).TrimEnd([char[]]@([char]92, [char]47))
        if (-not $candidateParent.Equals($canonicalSystemDirectory, [System.StringComparison]::OrdinalIgnoreCase)) { return $null }
        if (-not [System.IO.File]::Exists($candidate)) { return $null }
        $candidateItem = Get-Item -LiteralPath $candidate -Force -ErrorAction Stop
        if ($candidateItem.PSIsContainer -or ($candidateItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) { return $null }
        return [System.IO.Path]::GetFullPath($candidateItem.FullName)
    }
    catch { return $null }
}

function New-PCFCNativeResult {
    param(
        [bool]$Available,
        [bool]$ProcessStarted,
        [bool]$TimedOut,
        [AllowNull()]$NativeExitCode,
        [string]$StandardOutput = '',
        [string]$StandardError = '',
        [string]$FailureKind,
        [string]$ErrorMessage = '',
        [double]$DurationMilliseconds,
        [string]$WorkingDirectory,
        [string]$ResolvedExecutableName
    )

    return [pscustomobject][ordered]@{
        Available                  = $Available
        ProcessStarted             = $ProcessStarted
        Started                    = $ProcessStarted
        TimedOut                   = $TimedOut
        NativeExitCode             = $NativeExitCode
        ExitCode                   = $NativeExitCode
        StandardOutput             = $StandardOutput
        StdOut                     = $StandardOutput
        StandardOutputPresent      = -not [string]::IsNullOrWhiteSpace($StandardOutput)
        StandardOutputLength       = $StandardOutput.Length
        StandardError              = $StandardError
        StdErr                     = $StandardError
        StandardErrorPresent       = -not [string]::IsNullOrWhiteSpace($StandardError)
        StandardErrorLength        = $StandardError.Length
        FailureKind                = $FailureKind
        Error                      = $ErrorMessage
        DurationMilliseconds       = [math]::Round($DurationMilliseconds, 0)
        WorkingDirectory           = $WorkingDirectory
        ResolvedExecutableName     = $ResolvedExecutableName
        UseShellExecute            = $false
        CreateNoWindow             = $true
        RedirectStandardOutput     = $true
        RedirectStandardError      = $true
        AsynchronousStreamReading  = $true
        WaitForExitAfterAsyncRead  = $true
        ExitCodeCapturedBeforeDispose = $true
        LastExitCodeUsed           = $false
    }
}

function Invoke-PCFCNativeProcess {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter()][string[]]$Arguments = @(),
        [Parameter()][ValidateRange(1, 1800)][int]$TimeoutSeconds = 60,
        [Parameter()][string]$WorkingDirectory = $script:PCFCNativeProjectRoot
    )

    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $resolvedPath = Resolve-PCFCTrustedWindowsExecutable -FileName $FilePath
    if ([string]::IsNullOrWhiteSpace($resolvedPath)) {
        $timer.Stop()
        return New-PCFCNativeResult -Available $false -ProcessStarted $false -TimedOut $false -NativeExitCode $null -FailureKind 'MissingExecutable' -ErrorMessage 'The requested executable is unavailable.' -DurationMilliseconds $timer.Elapsed.TotalMilliseconds -WorkingDirectory '<project-root>' -ResolvedExecutableName $FilePath
    }

    $resolvedName = [System.IO.Path]::GetFileName($resolvedPath)
    $process = $null
    $processStarted = $false
    $standardOutput = ''
    $standardError = ''
    try {
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $resolvedPath
        $startInfo.Arguments = (($Arguments | ForEach-Object { ConvertTo-PCFCNativeArgument -Argument $_ }) -join ' ')
        $startInfo.WorkingDirectory = $WorkingDirectory
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo
        $processStarted = [bool]$process.Start()
        if (-not $processStarted) {
            $timer.Stop()
            return New-PCFCNativeResult -Available $true -ProcessStarted $false -TimedOut $false -NativeExitCode $null -FailureKind 'ProcessStartFailure' -ErrorMessage 'The process did not start.' -DurationMilliseconds $timer.Elapsed.TotalMilliseconds -WorkingDirectory '<project-root>' -ResolvedExecutableName $resolvedName
        }

        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $completed = $process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $completed) {
            try { $process.Kill() } catch { }
            $terminationCompleted = $false
            try { $terminationCompleted = [bool]$process.WaitForExit(5000) } catch { $terminationCompleted = $false }
            if ($stdoutTask.IsCompleted) { try { $standardOutput = [string]$stdoutTask.Result } catch { $standardOutput = '' } }
            if ($stderrTask.IsCompleted) { try { $standardError = [string]$stderrTask.Result } catch { $standardError = '' } }
            $timer.Stop()
            $timeoutFailureKind = if ($terminationCompleted) { 'Timeout' } else { 'TimeoutTerminationIncomplete' }
            return New-PCFCNativeResult -Available $true -ProcessStarted $true -TimedOut $true -NativeExitCode $null -StandardOutput $standardOutput -StandardError $standardError -FailureKind $timeoutFailureKind -ErrorMessage "Process exceeded the $TimeoutSeconds-second timeout." -DurationMilliseconds $timer.Elapsed.TotalMilliseconds -WorkingDirectory '<project-root>' -ResolvedExecutableName $resolvedName
        }

        # Bound stream completion independently before reading task results.
        $stdoutCompleted = $stdoutTask.IsCompleted -or $stdoutTask.Wait(5000)
        $stderrCompleted = $stderrTask.IsCompleted -or $stderrTask.Wait(5000)
        if (-not $stdoutCompleted -or -not $stderrCompleted) {
            $timer.Stop()
            return New-PCFCNativeResult -Available $true -ProcessStarted $true -TimedOut $false -NativeExitCode $null -FailureKind 'ExecutionFailure' -ErrorMessage 'Native output streams did not complete within the bounded wait.' -DurationMilliseconds $timer.Elapsed.TotalMilliseconds -WorkingDirectory '<project-root>' -ResolvedExecutableName $resolvedName
        }
        if ($stdoutTask.IsCompleted) { $standardOutput = [string]$stdoutTask.Result }
        if ($stderrTask.IsCompleted) { $standardError = [string]$stderrTask.Result }
        $nativeExitCode = $process.ExitCode
        $timer.Stop()
        return New-PCFCNativeResult -Available $true -ProcessStarted $true -TimedOut $false -NativeExitCode $nativeExitCode -StandardOutput $standardOutput -StandardError $standardError -FailureKind 'Completed' -DurationMilliseconds $timer.Elapsed.TotalMilliseconds -WorkingDirectory '<project-root>' -ResolvedExecutableName $resolvedName
    }
    catch {
        $timer.Stop()
        $failureKind = if ($processStarted) { 'ExecutionFailure' } else { 'ProcessStartFailure' }
        return New-PCFCNativeResult -Available $true -ProcessStarted $processStarted -TimedOut $false -NativeExitCode $null -StandardOutput $standardOutput -StandardError $standardError -FailureKind $failureKind -ErrorMessage $_.Exception.Message -DurationMilliseconds $timer.Elapsed.TotalMilliseconds -WorkingDirectory '<project-root>' -ResolvedExecutableName $resolvedName
    }
    finally {
        if ($null -ne $process) { $process.Dispose() }
    }
}

function Get-WindowsSystemVolume {
    if ($null -eq (Get-Command -Name 'Get-CimInstance' -ErrorAction SilentlyContinue)) { return $null }
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $systemVolume = ([string]$os.SystemDrive).Trim().TrimEnd('\')
        if ($systemVolume -notmatch '^[A-Za-z]:$') { return $null }
        $windowsRootVolume = [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
        if ([string]::IsNullOrWhiteSpace($windowsRootVolume)) { return $null }
        if (-not $systemVolume.Equals($windowsRootVolume, [System.StringComparison]::OrdinalIgnoreCase)) { return $null }
        return [pscustomobject][ordered]@{
            Volume = $systemVolume.ToUpperInvariant()
            SelectionMethod = 'Win32_OperatingSystem.SystemDrive verified against the Windows root volume'
        }
    }
    catch { return $null }
}

function New-PCFCChkdskOutcome {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('Passed', 'Failed', 'Unavailable')][string]$Status,
        [Parameter(Mandatory = $true)]$Data,
        [Parameter(Mandatory = $true)][string]$Message,
        [AllowNull()]$ExitCode = $null
    )

    $Data.Status = $Status
    $Data.Message = $Message
    return [pscustomobject][ordered]@{
        Status = $Status
        Data = $Data
        Message = $Message
        OutputFile = ''
        ExitCode = $ExitCode
        Critical = $false
    }
}

function Invoke-ChkdskOnlineScan {
    param([Parameter(Mandatory = $true)]$Context)

    $safeArguments = @('<verified-system-volume>', '/scan')
    $selection = Get-WindowsSystemVolume
    if ($null -eq $selection) {
        $message = 'The Windows system volume could not be verified safely; CHKDSK was not started.'
        $data = [pscustomobject][ordered]@{
            Executable = 'chkdsk.exe'
            SafeArguments = $safeArguments
            VerifiedSystemVolume = $false
            VolumeSelectionMethod = 'System volume verification did not complete'
            ProcessStarted = $false
            TimedOut = $false
            DurationMilliseconds = 0
            NativeExitCode = $null
            FailureKind = 'VolumeVerificationFailure'
            StandardOutputPresent = $false
            StandardOutputLength = 0
            StandardErrorPresent = $false
            StandardErrorLength = 0
            RawOutputSaved = $false
            RepairCommandUsed = $false
            WorkingDirectory = '<project-root>'
            ProcessStartInfo = [pscustomobject][ordered]@{
                UseShellExecute = $false; CreateNoWindow = $true
                RedirectStandardOutput = $true; RedirectStandardError = $true
                AsynchronousStreamReading = $true; ExplicitTimeoutSeconds = 900
                ExitCodeSource = 'Process.ExitCode captured before disposal'
            }
            Status = 'Unavailable'
            Message = $message
        }
        return New-PCFCChkdskOutcome -Status Unavailable -Data $data -Message $message
    }

    $native = Invoke-PCFCNativeProcess -FilePath 'chkdsk.exe' -Arguments @($selection.Volume, '/scan') -TimeoutSeconds 900 -WorkingDirectory $script:PCFCNativeProjectRoot
    $message = ''
    $status = 'Failed'
    if (-not $native.Available) {
        $status = 'Unavailable'
        $message = 'chkdsk.exe is unavailable.'
    }
    elseif (-not $native.ProcessStarted) {
        $message = 'CHKDSK could not start; no filesystem-health conclusion was made.'
    }
    elseif ($native.TimedOut) {
        $message = 'CHKDSK exceeded the 900-second timeout.'
    }
    elseif ($native.NativeExitCode -eq 0) {
        $status = 'Passed'
        $message = 'CHKDSK completed with exit code 0; localized text was not used to infer additional health claims.'
    }
    else {
        $message = 'The command returned a non-zero exit code; localized output was not interpreted.'
    }

    $data = [pscustomobject][ordered]@{
        Executable = 'chkdsk.exe'
        SafeArguments = $safeArguments
        VerifiedSystemVolume = $true
        VolumeSelectionMethod = $selection.SelectionMethod
        ProcessStarted = [bool]$native.ProcessStarted
        TimedOut = [bool]$native.TimedOut
        DurationMilliseconds = $native.DurationMilliseconds
        NativeExitCode = $native.NativeExitCode
        FailureKind = $native.FailureKind
        StandardOutputPresent = [bool]$native.StandardOutputPresent
        StandardOutputLength = $native.StandardOutputLength
        StandardErrorPresent = [bool]$native.StandardErrorPresent
        StandardErrorLength = $native.StandardErrorLength
        RawOutputSaved = $false
        RepairCommandUsed = $false
        WorkingDirectory = '<project-root>'
        ProcessStartInfo = [pscustomobject][ordered]@{
            UseShellExecute = [bool]$native.UseShellExecute
            CreateNoWindow = [bool]$native.CreateNoWindow
            RedirectStandardOutput = [bool]$native.RedirectStandardOutput
            RedirectStandardError = [bool]$native.RedirectStandardError
            AsynchronousStreamReading = [bool]$native.AsynchronousStreamReading
            ExplicitTimeoutSeconds = 900
            WaitForExitAfterAsyncRead = [bool]$native.WaitForExitAfterAsyncRead
            ExitCodeSource = 'Process.ExitCode captured before disposal'
            LastExitCodeUsed = [bool]$native.LastExitCodeUsed
        }
        Status = $status
        Message = $message
    }
    return New-PCFCChkdskOutcome -Status $status -Data $data -Message $message -ExitCode $native.NativeExitCode
}
