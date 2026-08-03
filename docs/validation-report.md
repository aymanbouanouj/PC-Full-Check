# Validation report

Initial validation date: 2026-08-02
Final synchronization date: 2026-08-03
Project version: 0.1.0-beta

## Scope and evidence boundary

This report preserves the chronological static and functional evidence for the public privacy-only implementation. It contains aggregate results only. No username, hostname, user path, configured email, volume or device identity, installed-product or driver value, event entry, raw native output, or local report content is reproduced.

The final documentation-synchronization task did not execute Quick, Standard, Full, CHKDSK, DISM, SFC, `powercfg`, either unpublished legacy executable, or any repair action. The remediated runtime results below were supplied from controlled elevated validation. This task was limited to documentation, static inspection, and the dependency-free repository suite.

## Final remediated evidence

| Validation | Exit | Aggregate result |
|---|---:|---|
| Repository suite | 0 | `TOTAL=77; PASSED=76; FAILED=0; NOT_EXECUTED=1` |
| Nested fictional assessment suite | 0 | `ASSESSMENT_TOTAL=10; PASSED=10; FAILED=0` |
| Nested CHKDSK/progress/trusted-resolver suite | 0 | `CHKDSK_TOTAL=26; PASSED=26; FAILED=0`; no native diagnostic executed by these fixtures |
| Maintained-file parser inspection | 0 | 8 files; 0 parser errors |
| Remediated Quick privacy mode | 0 | 9 checks: 8 Passed, 1 Warning, 0 Failed, 0 Unavailable, 0 Omitted; `Attention required` |
| Remediated Standard privacy mode | 0 | 21 checks: 17 Passed, 3 Warning, 0 Failed, 1 Unavailable, 0 Omitted; `Attention required` |
| Remediated isolated shared CHKDSK validator | 0 | 288920 ms; started; no timeout; native exit 0; stdout present; stderr absent; Passed; no raw output; no repair |
| Remediated Full privacy mode | 0 | 32 checks: 20 Passed, 3 Warning, 0 Failed, 1 Unavailable, 8 Omitted; `Attention required` |

All four required top-level report files existed for each remediated mode and the JSON parsed. In Full, every Omitted check had no `Data`, no `OutputFile`, and no executing collector. The standalone CHKDSK artifact is a validator record rather than a complete diagnostic report, so a report assessment and report-directory privacy result are not applicable to that artifact.

Throughout the controlled Quick, Standard, isolated CHKDSK, and Full validations, no file was staged, no commit was created or amended, no remote was created, no push or upload occurred, and no repair command was executed.

### Privacy-validation aggregates

| Mode | Files scanned | Confirmed | Potential review | Ignored | Exit |
|---|---:|---:|---:|---:|---:|
| Quick | 13 | 0 | 0 | 14 | 0 |
| Standard | 25 | 0 | 0 | 534 | 0 |
| Full | 28 | 0 | 0 | 536 | 0 |

Ignored matches are context-classified harmless schema or metadata matches, not confirmed leaks, and no matched values are reproduced here. Standard `SleepStates` was Passed while `RawOutputSaved=false`, `LocalizedOutputParsed=false`, and `ForbiddenRawTextFields=0`.

## Chronological functional record

The following earlier evidence is retained to show the remediation path. Later success does not rewrite or erase earlier failures.

1. The initial Quick run returned exit code 0 with 9 checks: 8 Passed and 1 Warning. The initial Standard run returned exit code 0 with 21 checks: 17 Passed, 3 Warning, and 1 Unavailable. Both assessments were `Attention required` because warnings were present.
2. The first hardened Full privacy run returned exit code 1 with 32 checks: 19 Passed, 3 Warning, 1 Failed, 1 Unavailable, and 8 Omitted. Integrated CHKDSK returned native exit code 3. Privacy validation passed, but privacy success did not override the failed diagnostic check.
3. A separately implemented targeted online scan later returned native exit code 0 after 225.39 seconds. It validated only that separate process and did not establish integrated parity.
4. A subsequent integrated Full attempt again returned exit code 1 with the same 19/3/1/1/8 distribution and native CHKDSK exit code 3. The non-zero result remained unresolved and was not characterized as proof of corruption.
5. After collector consolidation, the exact shared isolated path passed in 225.082 seconds with native exit code 0. A following Full privacy run completed in 467.645 seconds with exit code 0 and counts of 20 Passed, 3 Warning, 0 Failed, 1 Unavailable, and 8 Omitted.
6. Final remediation added the trusted native resolver, bounded post-timeout handling, strengthened output-path checks, fictional regression fixtures, and safe `SleepStates` metadata. Because those were production changes, the earlier successful runtime evidence was not treated as current.
7. The final elevated remediated validations then produced the Quick, Standard, isolated CHKDSK, and Full aggregates in the table above. All remediated modes had zero Failed checks and returned exit code 0.

## Static-test chronology

Earlier repository-suite totals grew as coverage was added. Intermediate harness failures were test-runner defects, not diagnostic execution. The final clean-structure suite is authoritative for the current tree: 77 total, 76 passed, 0 failed, and 1 intentionally not executed. Its nested suites passed 10 assessment cases and 26 CHKDSK/progress/resolver cases. All 8 maintained PowerShell files parsed with zero errors.

The first run during final documentation synchronization returned 72 total, 70 passed, 1 failed, and 1 not executed. Its sole failure was a stale README assertion that still required the now-obsolete “modified-code validation pending” wording. The assertion was updated to require the supplied remediated Quick, Standard, and Full aggregates and to reject the stale pending claim. The next run passed at 72/71/0/1. Neither run invoked a production diagnostic.

During final public-structure work, the first expanded run returned 77 total, 70 passed, 6 failed, and 1 not executed. Those failures were stale README wording assertions plus one user-guide wording probe; behavior, parser, manifest, authorship, citation, links, fixtures, privacy, and native-safety checks passed. After synchronizing the assertions, the next run passed at 77/76/0/1. No diagnostic ran in either attempt.

The one not-executed item represents Windows functional diagnostics, which the dependency-free runner deliberately does not invoke. Runtime evidence is recorded separately above.

## Interpretation

- A Warning produces `Attention required` but does not produce process exit code 1.
- A Failed check produces process exit code 1. The final remediated Quick, Standard, and Full reports contain zero Failed checks.
- Unavailable and Omitted remain visible and are never converted to Passed.
- Full's eight Omitted entries are the fixed privacy-only raw categories and have no executable collectors.
- Native exit code 0 establishes completion under the implemented online-scan contract; it is not a physical-health certification or future-reliability prediction.
- The evidence covers one current Windows computer. It does not establish representative Windows 10/11, desktop/laptop, hardware, firmware, provider, or localization coverage.

## Release-evidence conclusion

The current implementation has passing static, parser, privacy, Quick, Standard, isolated shared-CHKDSK, and Full evidence on the validated computer. That is sufficient to describe the implementation as beta-ready on the evidenced system. Publication authorization, Git author-email privacy, audit-file publication selection, final staged-diff review, remote/push approval, private vulnerability-reporting setup, and representative-system coverage remain separate release decisions.
