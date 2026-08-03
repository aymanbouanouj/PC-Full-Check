# Pre-change source audit

Audit date: 2026-08-02
Audited source: unpublished original internal baseline
Source size: 11,010 characters, 273 lines
SHA-256: `C3B0E03C48FE797AF9C2A74778E222C3C4F6AAA1B423012B16E19165918E00D8`

## Baseline inventory and repository state

Before this audit was created, the project contained one internal executable source file (11,010 bytes). No `.git` directory was present, so the directory was not already a Git repository. The PowerShell parser reported no syntax errors in the original source. That source is deliberately unpublished in v0.1.0-beta.

This document records source inspection only. No diagnostic command from the original script was executed during the audit.

## Observed design

The script creates a timestamped `PC_FULL_CHECK_*` directory on the current user's Desktop and writes a series of text and HTML reports. Its `Save-Report` helper executes a script block, combines success and error streams, converts display output to text, and catches terminating PowerShell exceptions. It finishes by writing a short read-me and opening the output directory in Explorer.

The source has no parameters, `CmdletBinding`, comment-based help, mode selection, privacy mode, explicit platform validation, Administrator-role validation, reusable check-result model, structured JSON summary, health assessment, progress total, run log, or process exit-code policy.

## Commands and external executables

The parsed command inventory is:

`chkdsk.exe`, `Confirm-SecureBootUEFI`, `cscript.exe`, `dism.exe`, `dsregcmd.exe`, `ForEach-Object`, `Format-List`, `Format-Table`, `Get-BitLockerVolume`, `Get-CimInstance`, `Get-Date`, `Get-Disk`, `Get-HotFix`, `Get-ItemProperty`, `Get-MpComputerStatus`, `Get-NetAdapter`, `Get-Partition`, `Get-PhysicalDisk`, `Get-PnpDevice`, `Get-StorageReliabilityCounter`, `Get-Tpm`, `Get-Volume`, `Get-WinEvent`, `Join-Path`, `manage-bde.exe`, `New-Item`, `Out-File`, `Out-Null`, `Out-String`, `powercfg.exe`, `Save-Report`, `Select-Object`, `sfc.exe`, `Sort-Object`, `Start-Process`, `Where-Object`, and `Write-Host`.

The source also directly references these executable or script names: `chkdsk.exe`, `cscript.exe`, `dism.exe`, `dsregcmd.exe`, `dxdiag.exe`, `explorer.exe`, `manage-bde.exe`, `msinfo32.exe`, `powercfg.exe`, `sfc.exe`, and `slmgr.vbs`.

The integrity operations in the source are the read-only variants DISM `/CheckHealth`, SFC `/verifyonly`, and CHKDSK `C: /scan`. No repair or destructive storage command was found in the original source.

## Privacy-sensitive collection

The original source deliberately writes reports containing direct or linkable identifiers, including:

- computer-product identifying number and UUID;
- baseboard, chassis, BIOS, Windows, memory-module, physical-disk, and disk serial numbers;
- chassis SMBIOS asset tag and monitor EDID serial number;
- domain and workgroup membership values;
- PnP instance IDs;
- device-registration output from unfiltered `dsregcmd.exe /status`;
- detailed license output from `slmgr.vbs /dlv`;
- startup command, location, and user values;
- raw battery, sleep-study, sleep-diagnostics, energy, MSINFO32, and DXDIAG reports;
- unrestricted BitLocker properties through `Format-List *`.

The output directory path is based on the current user's Desktop and is written into `00_READ_ME.txt`. Error text is also written verbatim. The script has no sanitization layer and no field allowlist for a privacy-preserving mode. Its final read-me acknowledges that the folder contains serial numbers, UUIDs, and device information.

## Long-running and blocking operations

Potentially long-running or blocking source operations include `powercfg` battery, sleep-study, sleep-diagnostics, and 60-second energy reports; DISM CheckHealth; SFC verify-only; CHKDSK online scan; and `Start-Process -Wait` for MSINFO32 and DXDIAG. None has timeout protection. All are run on every invocation because there are no diagnostic modes.

## Unavailable-command and platform risks

The script calls Windows-only CIM/WMI classes, registry drives, Storage, PnP, Defender, BitLocker, Secure Boot, TPM, networking, event-log, and hotfix commands without a general command-availability check. Some individual calls have local `try`/`catch` blocks, but many do not. Availability can depend on Windows version or edition, device firmware, hardware, drivers, installed Windows components, and permissions. The source does not detect unsupported operating systems or verify Windows PowerShell 5.1 or later.

The script comment says to run as Administrator, but the code does not test the current token and does not stop when elevation is missing. Several checks may consequently return access or capability errors while the rest of the script continues.

## False-success and reliability risks

The following are verified from the source:

- `$ErrorActionPreference` is set to `Continue`, so non-terminating errors generally do not enter `catch` blocks.
- `Save-Report` writes merged error text to the normal report file and has no check status, so a report file can exist even when collection failed.
- Native command exit codes are not captured or evaluated.
- Expected output files from `powercfg`, MSINFO32, and DXDIAG are not verified after execution.
- The three raw `powercfg` report commands before the power text report have no surrounding `try`/`catch`.
- The final completion message is unconditional and does not reflect prior command failures.
- `Start-Process` success is treated as report success without examining a process exit code or checking the output file.
- No serious initialization guard follows output-directory creation; `New-Item` uses the global `Continue` error preference.
- Several data streams are converted with `Format-List` or `Format-Table` before storage, preventing later structured assessment.
- The problem-device report prints `NO PROBLEM DEVICES FOUND` when `$Problems` is falsey, but the surrounding collection does not separately prove that `Get-PnpDevice` completed successfully.
- The WHEA report prints `NO WHEA HARDWARE ERRORS FOUND` when `$Whea` is falsey, while `Get-WinEvent` uses `-ErrorAction SilentlyContinue`; an unavailable or failed query can therefore be presented like a negative finding.

## Administrator requirements observed

The file header requests Administrator execution. The code itself does not map privileges to individual checks. DISM online servicing inspection, SFC verification, CHKDSK online scan, some `powercfg` diagnostics, storage reliability, BitLocker status, Secure Boot, TPM, and certain event or device queries can be permission- or capability-dependent, but the exact behavior was not executed during this baseline audit.

## Baseline conclusion

The original was a Windows-specific collection script with broad hardware and system coverage, but it always performed the full collection, saved sensitive identifiers and raw reports, and could print unconditional completion after unavailable or failed operations. These observations justified keeping only a historical hash record and implementing a separate maintained public entry point with explicit privacy, availability, status, timeout, and validation controls. The audited source is not part of the public repository.
