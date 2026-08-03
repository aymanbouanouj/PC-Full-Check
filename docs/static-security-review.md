# Static security review

Creator and maintainer: Ayman Bounaouj

## Current posture

The maintained production path has no network/upload behavior, third-party dependency, `Invoke-Expression`, shell execution, repair command, production recursive deletion, hidden sensitive parameter, or raw integrity persistence. The review is static and does not claim hostile-host isolation.

## Historical findings and current status

### PCFC-SEC-001 — Medium — Elevated native executable PATH trust

Original finding: the shared runner selected an application with `Get-Command`, allowing search-order/PATH influence.

Remediation: `Resolve-PCFCTrustedWindowsExecutable` (`internal/ChkdskProduction.ps1:L53-L76`) accepts only `powercfg.exe`, `dism.exe`, `sfc.exe`, and `chkdsk.exe`; rejects paths/alternate names; obtains `[Environment]::SystemDirectory`; canonicalizes directory/candidate; requires direct containment, an existing file, and no selected reparse point; and returns no PATH fallback. `Invoke-PCFCNativeProcess` uses only this resolver (`L124-L197`). Tests prove all four names resolve under SystemDirectory, unsupported/path-like inputs fail, and an earlier same-named PATH fixture is ignored without execution.

Current status: Resolved. Residual trust remains in Windows, `[Environment]::SystemDirectory`, filesystem metadata, and repository source.

### PCFC-SEC-002 — Low — Output reparse/TOCTOU exposure

Original finding: empty-directory checks and later elevated fixed-name writes lacked reparse validation.

Remediation: five shared helpers canonicalize paths, inspect reparse points, reject files/non-empty directories, require checks/report containment, and revalidate immediately before writes (`PC-Full-Check.ps1:L62-L157`). Filesystem fixtures cover files, non-empty directories, traversal, safe containment, and a junction destination. Production has no recursive delete and does not alter ACLs.

Current status: Partially mitigated. A path-based implementation cannot atomically pin every directory/file handle, so a hostile local actor with concurrent destination control retains a narrow TOCTOU opportunity. Open Low.

### PCFC-SEC-003 — Low — Unbounded post-timeout wait

Original finding: timeout cleanup used parameterless `WaitForExit()` and unguarded task Result reads.

Remediation: after the initial caller timeout, only the direct child receives `Kill()`, followed by `WaitForExit(5000)`. No parameterless wait remains. Results are read only for completed tasks. `TimeoutTerminationIncomplete` is distinct from `Timeout`; either remains Failed and cannot become Passed.

Current status: Resolved. Descendant-process behavior remains outside the direct-child contract but no indefinite post-timeout wait remains.

### PCFC-SEC-004 — Informational — Destination ACL/retention confidentiality

No ACL is silently modified. Users must select/protect/review the local report directory. Open Informational.

### PCFC-SEC-005 — Informational — Private security channel pending

No verified private reporting address/channel exists yet. Open Informational and release-process blocking until the maintainer enables/tests one.

## Current finding totals

| Severity | Open | Resolved historical |
|---|---:|---:|
| Critical | 0 | 0 |
| High | 0 | 0 |
| Medium | 0 | 1 |
| Low | 1 | 1 |
| Informational | 2 | 0 |

## Static verification

Repository tests: `TOTAL=77; PASSED=76; FAILED=0; NOT_EXECUTED=1`. Nested assessment: 10/10. Nested CHKDSK/privacy-progress/trusted-resolver: 26/26. Parser: 8 files, 0 errors. No native executable was started by these tests.

## Runtime corroboration

Controlled elevated validation of the remediated build passed Quick, Standard, Full, and the isolated shared-CHKDSK path on one current Windows computer. The isolated trusted-resolver/native-runner path started successfully, did not time out, returned native exit code 0 after 288920 ms, saved no raw output, and used no repair command. Full's integrated CHKDSK check also Passed. These results corroborate the remediated paths but do not eliminate the documented local TOCTOU residual or establish hostile-host isolation.
