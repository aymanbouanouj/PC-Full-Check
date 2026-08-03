# CHKDSK Full-mode investigation

Investigation date: 2026-08-02
Evidence directory: `local-validation/hardened-full`
Check: `ChkdskOnlineScan`

No CHKDSK repair operation was run. Raw localized CHKDSK text was not printed or added to this document.

## Existing report evidence

| Item | Verified result |
|---|---|
| Executable | `chkdsk.exe` |
| Argument array | `C:`, `/scan` |
| Selected volume | `C:` |
| Report-time selection method | None; the maintained source at report time hard-coded `C:` |
| Check start time | `2026-08-02T19:03:43.9535006+01:00` |
| Duration | 86 ms |
| Timeout | No |
| Process start | Successful |
| Native exit code | 3 |
| Status | Failed |
| Critical flag | false |
| Expected native output file | None |
| Raw output saved | No |
| Localized output parsed | No |

The old native runner assigned an exit code only after `Process.Start()` returned true and the process completed within the timeout. A start exception returned a null exit code, and a timeout also returned a null exit code. The stored exit code 3 therefore proves that the CHKDSK process started and completed without the 900-second timeout.

Standard output and standard error were both redirected and read asynchronously into memory by the old runner. The privacy-mode integrity wrapper discarded their content and stored no non-empty flags, so the existing report cannot prove whether either stream contained text. No CHKDSK stdout, stderr, native-command, or temporary-result file exists under the evidence directory. The only related file is `checks/ChkdskOnlineScan.json`, containing exit code 3, `LocalizedOutputParsed: false`, and `RawOutputSaved: false`.

No PowerShell exception escaped the native runner. Under the old implementation, an exception would have produced a null exit code rather than 3. The check's Failed status came only from the completed native process returning a non-zero exit code.

## Volume verification

At investigation time, two structured/local sources agreed that the Windows system volume is `C:`:

- `Win32_OperatingSystem.SystemDrive` returned `C:`;
- the root of the Windows directory was `C:`.

Therefore the report happened to target the current system volume. This does not excuse the implementation defect: the report-time source blindly supplied `C:` rather than determining and verifying the system volume.

The maintained implementation now obtains `Win32_OperatingSystem.SystemDrive`, validates the drive-letter form, and verifies it against the Windows-root volume. If those sources are missing or disagree, the CHKDSK check is Unavailable and does not start. No drive letter is used as a fallback.

## Command safety

The report-time command was exactly the read-only form:

```text
chkdsk.exe C: /scan
```

The arguments were supplied as two separate array elements to the timeout-controlled native runner. The source did not contain `/f`, `/r`, `/x`, `/b`, `/spotfix`, or another CHKDSK repair option in this check.

## Exit-code evidence and classification

Local `chkdsk.exe /?` inspection was permitted and performed without saving or printing its localized text. The help process started, produced standard output, produced no standard error, and itself returned exit code 3. The captured help contained no detected exit-code section and no explicit mapping for code 3.

No structured evidence in the Full report or local built-in help defines what exit code 3 means for the completed `/scan`. The raw `/scan` output was not saved, so it cannot be safely interpreted after the fact. The result therefore remains:

- **Failed — unresolved non-zero native exit code 3**;
- not Passed;
- not Critical;
- not evidence by itself of filesystem corruption or permanent disk damage.

## Implementation changes

The narrow changes made after the report are:

- dynamic and cross-verified Windows system-volume selection;
- structured `ProcessStarted`, `TimedOut`, `FailureKind`, stdout/stderr-presence, exit-code, executable, argument, and expected-output-file metadata;
- distinct Missing executable (Unavailable), start failure (Failed), access-denied start (Failed without a filesystem conclusion), timeout (Failed), zero exit (Passed), and unresolved non-zero exit (Failed) paths;
- no localized phrase parsing;
- no raw integrity output saved in privacy mode.

## Later targeted Administrator validation

A later targeted scan was performed manually from an elevated session. Before execution, two independent local sources resolved the Windows system volume to `C:`:

- `Win32_OperatingSystem.SystemDrive`;
- the drive root of `$env:WINDIR`.

The executed command was the read-only form `chkdsk.exe C: /scan`. The structured result is stored at `local-validation/chkdsk-targeted/result.json`; raw stdout was intentionally not saved.

| Item | Verified targeted result |
|---|---|
| System volume | `C:` |
| System volume verified | true |
| Process started | true |
| Timeout | false |
| Duration | 225.39 seconds |
| Native exit code | 0 |
| Classification | Passed |
| Standard output present | true |
| Standard error present | false |
| Raw output saved | false |
| Repair command used | false |
| Recorded interpretation | No errors were found |

The result file stores the actual volume argument as the privacy-safe placeholder `<verified-system-volume>` plus `/scan`; the two-source manual verification records that the placeholder represented `C:`. It stores only output-presence/length metadata, not raw output text.

## Historical and current interpretation

The earlier Full-mode exit code 3 remains part of the validation history. The successful targeted exit-0 scan did not reproduce it. No evidence proves that the earlier result was caused by corruption, the old hard-coded drive, Windows, timeout, permissions, or a specific runner defect.

For the separate targeted process, the later elevated scan supersedes the first unresolved exit-3 result: that verified online scan completed normally and found no filesystem errors. It did not prove that the integrated Full-mode execution path was correct. This does not prove physical disk health, predict future reliability, certify the computer, or explain the earlier result with certainty.

Full mode was not rerun during the targeted scan. Sensitive mode was not used, and no repair option was executed.

## Subsequent final Full integrated result

The later Administrator-run `local-validation/final-full` privacy report completed in 221.625 seconds and returned process exit code 1. Required files were present, summary JSON parsed, and privacy validation returned exit code 0 with 0 confirmed and 0 potential-review findings.

Its integrated `ChkdskOnlineScan` was the only Failed check. Safe evidence records `chkdsk.exe`, verified system volume `C:`, arguments `C:` and `/scan`, process started true, timeout false, duration 240 ms, native exit code 3, stdout present, stderr absent, `FailureKind=Completed`, and raw output not saved. The source used `ProcessStartInfo` with shell execution disabled, no window, both streams redirected and read asynchronously, a timed wait followed by the completion wait, and `Process.ExitCode` captured before disposal. The artifact did not record stdout/stderr lengths, working directory, ProcessStartInfo flags, or the safe volume placeholder.

The final report is consistent with the maintained integrated collector that existed at execution time; the generic failure message is produced by that source and does not prove that an older duplicate ran. The pre-change helper quoted every native argument, including `C:` and `/scan`. This is a verified execution-path difference from the new parity design but is not a proven explanation for exit code 3.

The native helper and CHKDSK collector are now consolidated in `internal/ChkdskProduction.ps1`. Full mode and `tests/run-integrated-chkdsk-validation.ps1` load the same functions. The isolated production-path validator has not been executed because the current Codex session is not Administrator. The issue is not considered fixed unless that exact shared path executes successfully. See `docs/chkdsk-integration-parity.md`.

## Successful shared production-path validation

The later elevated isolated validator executed the exact shared `Invoke-ChkdskOnlineScan` collector and `Invoke-PCFCNativeProcess` helper. It started successfully, did not time out, ran for 225.082 seconds, returned native exit code 0, and classified the result Passed. stdout was present, stderr was absent, raw output was not saved, and no repair command was used. Safe arguments were `<verified-system-volume>` and `/scan`.

The subsequent final Full privacy-mode run also executed the shared production path successfully. Its CHKDSK check was Passed with native exit code 0 and no Failed checks remained in the Full report. The complete Full run returned exit code 0 after 467.645 seconds.

This demonstrates production-path parity on the current Windows computer. It does not establish the exact cause of either historical exit-code-3 result, prove physical disk health, or establish universal Windows compatibility.
