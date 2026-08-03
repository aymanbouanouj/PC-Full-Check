# PC Full Check for Windows v0.1.0-beta

Creator and maintainer: Ayman Bounaouj
Copyright 2026 Ayman Bounaouj
License: MIT

## Final public structure

The v0.1.0-beta public manifest contains 42 files. It adds the complete user guide, `AUTHORS.md`, `CITATION.cff`, and four reviewed public audit summaries. Eight optional/internal audit artifacts and all private runtime evidence remain outside public scope. `PC-Full-Check.ps1` remains the only supported diagnostic entry point.

## Beta scope

This public beta is a privacy-only, read-only Windows diagnostic aid. Windows 10 and Windows 11 are intended targets, using Windows PowerShell 5.1 or later with Administrator privileges. It is not professional certification and is not guaranteed to detect every hardware or software problem.

## Diagnostic modes

- **Quick:** core Windows, hardware, storage, volume, device, and Defender checks.
- **Standard:** Quick plus security, update, reliability, driver, safe battery, power, program, network, and event checks.
- **Full:** Standard plus read-only DISM CheckHealth, SFC verify-only, and CHKDSK online scan.

Full retains eight transparent Omitted entries for unsafe raw-report categories.

## Privacy-only behavior

The maintained entry point exposes only `Mode` and `OutputPath`. Sensitive-report collection is unavailable in v0.1.0-beta. Raw device-registration, licensing, MSINFO32, DXDIAG, battery, sleep, energy, event-message, and integrity-command output cannot be enabled.

The original internal executable source predates this privacy-only design and is deliberately unpublished. `PC-Full-Check.ps1` is the only supported public entry point; `legacy/README.md` retains only the historical baseline hash and safety context.

Reports are processed locally and are not uploaded. Privacy mode avoids specified direct identifiers, but reports may still reveal useful hardware, software, driver, update, and event information. Review every report before sharing.

SleepStates retains only controlled process/capability metadata and never persists raw localized stdout, stderr, or reason strings. The four maintained native executables resolve only as direct, canonical files in the trusted Windows system directory; PATH fallback is not used.

## Validation performed

The remediated Quick, Standard, and Full privacy-mode paths passed elevated validation on the current Windows computer.

| Mode | Exit | Assessment | Passed | Warning | Failed | Unavailable | Omitted |
|---|---:|---|---:|---:|---:|---:|---:|
| Quick | 0 | Attention required | 8 | 1 | 0 | 0 | 0 |
| Standard | 0 | Attention required | 17 | 3 | 0 | 1 | 0 |
| Full | 0 | Attention required | 20 | 3 | 0 | 1 | 8 |

Required report files were present and JSON summaries parsed. Privacy validation passed with 0 confirmed and 0 potential-review findings: 13 files for Quick, 25 for Standard, and 28 for Full. Harmless/ambiguous ignored counts were 14, 534, and 536 respectively; matched values are not reproduced.

The remediated isolated shared CHKDSK production path started, did not time out, completed in 288,920 milliseconds with native exit code 0, produced stdout but no stderr, saved no raw output, and used no repair command. The Full integrated CHKDSK result also Passed with native exit code 0.

The final dependency-free repository suite passed `77/76/0/1`; assessment fixtures passed 10/10; CHKDSK/privacy-progress/trusted-resolver fixtures passed 26/26; and all 8 maintained PowerShell files parsed with 0 errors.

## Known limitations

- Functional validation represents one current Windows computer.
- Representative Windows 10/11 hardware and localization coverage is incomplete.
- Hardware, firmware, drivers, edition, permissions, and providers affect evidence availability.
- Privacy validation is not an anonymity guarantee.
- Path-based output checks cannot atomically eliminate every hostile local TOCTOU race.
- Sensitive-report collection is unsupported and unavailable.
- A verified private security contact is not yet published; GitHub private vulnerability reporting should be enabled before publication.

## No repair behavior

The project contains no repair workflow. Full uses only DISM `/CheckHealth`, SFC `/verifyonly`, and CHKDSK `/scan`; it does not use repair, dismount, fix, or restore-health operations.
