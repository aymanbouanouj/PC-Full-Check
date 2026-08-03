# Supported systems and capability matrix

## Public support statement

The 0.1.0-beta public support scope is:

- Windows 10;
- Windows 11;
- Windows PowerShell 5.1 or later on Windows;
- desktop and laptop computers.

The startup guard stops on other operating systems, unsupported Windows captions, PowerShell versions earlier than 5.1, missing CIM support, missing Administrator privileges, or output-initialization failure. It does not create a partial diagnostic report in those cases.

## Capability-dependent checks

| Area | Primary source | Common dependency |
|---|---|---|
| Base hardware and Windows | CIM classes | WMI/CIM service and provider |
| Storage health | Storage cmdlets | Storage module, provider, controller support |
| Storage reliability | `Get-StorageReliabilityCounter` | Drive/controller telemetry support |
| Problem devices | PnP cmdlets | PnP module and device data |
| Defender | Defender cmdlets | Microsoft Defender components and policy |
| TPM | `Get-Tpm` | TPM hardware, firmware, and cmdlet |
| Secure Boot | `Confirm-SecureBootUEFI` | UEFI firmware and supported platform |
| Safe battery health | CIM plus `root\wmi` battery classes | Battery firmware and driver telemetry |
| Sleep and power | `powercfg.exe` | Supported power capabilities |
| Events and WHEA | System event log | Log access, providers, retained events |
| Integrity checks | DISM, SFC, CHKDSK | Built-in executables and Administrator access |
| Raw Full reports | Not collected in v0.1.0-beta | Always Omitted in privacy-only scope |

Capability absence is reported as `Unavailable`; privacy exclusions are `Omitted`. The tool does not imply that every check works on every supported computer.

## Current validation boundary

Final remediated Quick, Standard, Full privacy mode, and isolated shared-CHKDSK validation passed on one current Windows computer. The mode counts were respectively 8/1/0/0/0, 17/3/0/1/0, and 20/3/0/1/8 for Passed/Warning/Failed/Unavailable/Omitted. The isolated online scan started, did not time out, returned native exit code 0 after 288920 ms, saved no raw output, and used no repair command.

This is useful beta evidence for the tested computer, not representative coverage of the complete support statement. It does not establish every Windows version, desktop/laptop shape, hardware and firmware combination, provider behavior, language, or localization path.

## Manual pre-release matrix

Before a stable release, maintainers should record real results for at least:

- an elevated Windows 10 desktop Quick and Standard run;
- an elevated Windows 10 laptop with a battery Quick and Standard run;
- an elevated Windows 11 desktop Quick and Standard run;
- an elevated Windows 11 laptop with a battery Quick and Standard run;
- UEFI Secure Boot enabled and unsupported/legacy paths;
- TPM present/ready and absent/unavailable paths;
- storage with and without reliability-counter support;
- localized Windows installations where native output is not English;
- a manually supervised Full privacy-mode run;
- confirmation that unsafe raw entries remain Omitted and cannot execute.

These tests must use private output, never public real-machine examples. Full mode must not be run automatically during ordinary development validation.
