# PC Full Check for Windows v0.2.1-beta

Creator and maintainer: Ayman Bounaouj
Release date: 2026-10-31
Copyright 2026 Ayman Bounaouj
License: MIT

## Security maintenance since v0.2.0-beta

- Hardened the optional Easy Runner privileged source-acquisition boundary (PR #7; Issue #6).
- Require a reviewed, pinned commit and embedded SHA-256 hashes for the downloaded PowerShell scripts and manifest BEFORE executing downloaded tests and diagnostics.
- Reject mismatched or missing trusted files, unexpected files, and reparse points.
- Keep local privacy-first, read-only Quick/Standard/Full diagnostics with no report uploads, repairs, or new dependencies.
- Update the diagnostic tool/report version and fictional fixture metadata to `0.2.1-beta`.
- Trust in the *initial launcher* is required; the hash checks do not authenticate an untrusted first copy.
- This release pins the validated v0.2.1-beta source snapshot at commit `b8b02fdf667712062be482cd52ccb0068d5393aa` instead of using the latest `main`; future source updates need explicit review.

## Validation and limitations

- The original security change on PR #7 passed Windows GitHub Actions static validation: `TOTAL=79; PASSED=78; FAILED=0; NOT_EXECUTED=1`.
- The maintainer's reported elevated Quick test returned `RUNNER_EXIT=0`, generated all four expected reports, and produced valid JSON on one Windows computer.
- Final release-candidate static CI is required on the new version commit; this is not a claim of broad Windows or hardware certification.
- Historical `v0.1.0-beta` and `v0.2.0-beta` Git tags/releases/archives are unchanged.
- The old Zenodo version DOI `10.5281/zenodo.23273477` applies only to `v0.2.0-beta`. An independent DOI for `v0.2.1-beta` requires a new Zenodo version deposit.

---

# Historical v0.2.0-beta release notes

# PC Full Check for Windows v0.2.0-beta

Creator and maintainer: Ayman Bounaouj
Copyright 2026 Ayman Bounaouj
License: MIT

## What changed since v0.1.0-beta

This beta advances the public project while preserving the privacy-first, read-only diagnostic design.

- Added the optional `PCFC-Easy-Runner.ps1` launcher for a simpler supported startup path.
- Added `START_HERE.md`, a beginner-oriented guide covering setup, launch methods, diagnostic modes, reports, privacy, exit codes, and common mistakes.
- Added GitHub Actions static validation for pull requests and repository changes.
- Extended repository validation for the Easy Runner and current public documentation.
- Preserved `PC-Full-Check.ps1` as the supported diagnostic engine.
- Preserved Quick, Standard, and Full diagnostic modes.
- Corrected the beginner documentation so `All` is not presented as a supported mode; users who need all three reports must run Quick, Standard, and Full separately.
- Preserved the privacy-only design: the eight sensitive Full categories remain intentionally `Omitted`.
- Preserved the read-only integrity operations: DISM `/CheckHealth`, SFC `/verifyonly`, and CHKDSK `/scan`.
- The diagnostic engine still performs no report upload, telemetry, analytics, repair, or destructive action.
- The optional Easy Runner uses HTTPS only to obtain the official repository source needed for launch and does not upload diagnostic reports.
- The published `v0.1.0-beta` tag and its historical evidence remain unchanged.

## Validation status

Fresh local validation for `v0.2.0-beta` completed successfully on one current Windows computer.

| Validation | Result |
|---|---|
| Repository suite | `TOTAL=78; PASSED=77; FAILED=0; NOT_EXECUTED=1` |
| Quick runtime | Exit 0; 8 Passed, 1 Warning, 0 Failed |
| Standard runtime | Exit 0; 17 Passed, 3 Warning, 0 Failed, 1 Unavailable |
| Full release validator | Exit 0; elevated validation passed |
| Quick privacy | 13 files; 0 confirmed; 0 potential review; 14 harmless/ignored |
| Standard privacy | 25 files; 0 confirmed; 0 potential review; 540 harmless/ignored |
| Full privacy | 28 files; 0 confirmed; 0 potential review; 540 harmless/ignored |

Warnings and Unavailable results remain visible and are not converted to Passed. These results do not certify the computer or establish universal Windows compatibility.

Local `v0.2.0-beta` validation is complete. Publication still requires final diff review, pull-request CI, merge into `main`, creation of the `v0.2.0-beta` tag, and GitHub Release publication.
---

# Historical release notes

The complete original `v0.1.0-beta` release notes are preserved below without deletion or replacement.

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
