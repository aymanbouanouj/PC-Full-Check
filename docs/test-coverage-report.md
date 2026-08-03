# Test coverage report

Creator and maintainer: Ayman Bounaouj

## Final static results

| Suite | Result |
|---|---|
| Repository runner | `TOTAL=77; PASSED=76; FAILED=0; NOT_EXECUTED=1` |
| Assessment fixture suite | `ASSESSMENT_TOTAL=10; PASSED=10; FAILED=0` |
| CHKDSK/privacy-progress/trusted-resolver suite | `CHKDSK_TOTAL=26; PASSED=26; FAILED=0` |
| Maintained PowerShell parser | 8 files, 0 errors |

The single Not Executed item is Windows functional diagnostics. The runner was inspected before execution: its only PowerShell child launches are assessment-tests and chkdsk-tests, it contains zero diagnostic-mode launch nodes, and it contains zero direct CHKDSK/powercfg/DISM/SFC command nodes.

The first final-documentation run returned `TOTAL=72; PASSED=70; FAILED=1; NOT_EXECUTED=1` because one documentation assertion still required the obsolete pending-runtime wording. That assertion was synchronized to require the remediated mode aggregates and reject the stale statement. The following run passed at 72/71/0/1. No diagnostic ran in either attempt.

The first clean-public-structure run returned `TOTAL=77; PASSED=70; FAILED=6; NOT_EXECUTED=1`. The six failures were wording assertions left behind by the README redesign plus one guide wording probe; all source, parser, manifest, authorship, citation, link, privacy, fixture, and native-safety checks passed. The assertions were synchronized without weakening their behavior requirements, and the following run passed at 77/76/0/1. Neither attempt executed a diagnostic.

## TEST-001 status

Original defect: `tests/assessment-tests.ps1` required ignored Quick/Standard files beneath `local-validation`, so a clean clone could not run the advertised dependency-free suite.

Remediation: `tests/fixtures/quick-summary.json` and `tests/fixtures/standard-summary.json` are fictional, public-manifest fixtures. Assessment tests load only those files, fail clearly for absence/corrupt JSON/missing marker, verify Warning/no-Failed scenarios, and require one Standard Unavailable result. The source contains no `local-validation` or real summary filename reference.

Current status: Resolved in a clean-clone-equivalent fixture environment.

## New behavior coverage

| Area | Coverage |
|---|---|
| Trusted resolver | Direct read-only resolution of all four allowlisted SystemDirectory files; unsupported/path-like rejection; PATH-precedence fixture; source checks for no fallback. No executable started. |
| Output paths | Extracted production helpers exercised against file, non-empty directory, contained report, traversal, and junction fixtures. Cleanup is limited to the exact project-local temporary fixture after containment/reparse checks. |
| Timeout handling | Static proof of initial and second bounded waits, no parameterless WaitForExit, completed-task guards, and required FailureKind values; fictional timeout results cannot pass. |
| SleepStates | Static schema allowlist; raw/output-line/localized/reason persistence rejected. Fictional Standard fixture carries only safe metadata. |
| Sample schema | JSON parse plus all unconditional summary fields, normalized Checks count, Battery, WHEA range, exact privacy state, and four Limitations. |
| Documentation | Assertions cover all DOC-001 through DOC-009 outcomes. |
| Manifest/audits | Both fixtures required exactly once; four approved audit summaries required public, and eight local audit artifacts forbidden from the manifest. |
| Privacy/safety | Identifier patterns, network/repair/sensitive paths, legacy tracking/public execution, parser validity, and output artifacts. |

## Production coverage classification

- Direct fictional/pure coverage: outcome/status/assessment/exit rules, temperature/battery helpers, manifest/omitted actions, CHKDSK classification, resolver behavior, and output-path helpers.
- Static structural coverage: process startup/timeout/streams, collectors, rendering, privacy allowlists, startup gates, manual validator safety, and documentation consistency.
- Historical runtime evidence: earlier Quick, Standard, Full, and CHKDSK runs, including preserved failed integrated attempts and later pre-remediation success.
- Current runtime evidence: remediated Quick, Standard, Full, and isolated shared CHKDSK passed on one current computer. Counts were 8/1/0/0/0, 17/3/0/1/0, and 20/3/0/1/8 for Passed/Warning/Failed/Unavailable/Omitted; the isolated shared scan completed in 288920 ms with native exit code 0, no timeout, no raw output, and no repair.

No line/branch percentage is claimed. Most hardware/provider collectors still lack mocked provider success/absence/error matrices, and representative Windows/hardware/localization coverage remains incomplete.
