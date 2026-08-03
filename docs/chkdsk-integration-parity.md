# CHKDSK integration parity investigation

Investigation date: 2026-08-02
Final synchronization date: 2026-08-03
Scope: safe aggregate metadata only. Raw CHKDSK stdout and stderr were neither documented nor saved.

## Current conclusion

The remediated isolated validator and remediated Full privacy-mode run both exercised the shared production collector successfully on the current Windows computer. The isolated validator started the process, did not time out, ran for 288920 ms, returned native exit code 0, observed stdout and no stderr, saved no raw output, used no repair command, and returned validator exit code 0. The integrated Full check also started, did not time out, returned native exit code 0, saved no raw output, used no repair command, and was Passed.

This validates shared-path behavior on one current computer. It does not certify physical disk health, predict future reliability, or establish universal hardware, Windows-version, localization, or provider compatibility.

## Chronological evidence

| Phase | Path | Duration | Native exit | Result | Interpretation |
|---|---|---:|---:|---|---|
| Historical targeted validation | Separately implemented online scan | 225.39 seconds | 0 | Passed | Validated only the separate process, not production-path parity. |
| Historical integrated Full attempt | Pre-consolidation production path | 240 ms | 3 | Failed | Non-zero result remained unresolved; it did not prove corruption. |
| Historical consolidated isolated validation | Shared collector and helper | 225.082 seconds | 0 | Passed | Established production-path parity for that implementation. |
| Historical consolidated Full validation | Shared collector and helper | included in a 467.645-second Full run | 0 | Passed | Confirmed the integrated path for that implementation. |
| Final remediated isolated validation | Current shared collector and helper | 288920 ms | 0 | Passed | Confirmed the trusted resolver, bounded waits, and safe metadata path on this computer. |
| Final remediated Full validation | Current shared collector and helper | aggregate only | 0 | Passed | Confirmed the same current path inside Full mode. |

The earlier exit-code-3 evidence is intentionally preserved. Argument serialization was a credible historical divergence, but the artifacts did not prove it was the root cause.

## Maintained production call path

1. `PC-Full-Check.ps1` loads `internal/ChkdskProduction.ps1`.
2. `Get-CheckDefinitions` maps `ChkdskOnlineScan` to `Invoke-ChkdskOnlineScan` for Full mode.
3. `Invoke-DiagnosticCheck` executes the manifest action and writes structured check JSON through the safe output-path helper.
4. `Invoke-ChkdskOnlineScan` verifies the system volume, constructs the online-scan arguments, calls the shared native helper, classifies the outcome, and returns safe metadata.
5. `Get-WindowsSystemVolume` requires two independent Windows sources to agree before execution.
6. `Invoke-PCFCNativeProcess` owns trusted executable resolution, process configuration, asynchronous stream reads, bounded waits, and exit-code capture.
7. `ConvertTo-PCFCNativeArgument` produces a Windows PowerShell 5.1-compatible argument string without the historical unconditional quoting behavior.
8. The summary and completion logic expose the check status and return a non-zero process exit only when a check is Failed.

There is one maintained `Invoke-ChkdskOnlineScan` definition. Full mode and the isolated integration validator load that definition and the same native-process helper; the validator contains no separate CHKDSK execution implementation.

## Safe contract

The current result records only safe execution metadata: a trusted executable identity, placeholder arguments, start and timeout states, native exit code, stream-presence and length metadata, duration, process-configuration facts, classification, and repair-command state. It does not persist localized stream contents or the actual system-volume value.

The current trusted-executable resolution and subsequent process start are separate operating-system operations. A narrow time-of-check/time-of-use substitution window therefore remains a documented residual risk; repository-controlled resolution, strict allowlisting, and immediate execution reduce but do not mathematically eliminate it.

## Final parity judgment

Production-path parity is validated for the remediated build on the current Windows computer. Broader representative testing remains required before stable-release or universal-support claims.
