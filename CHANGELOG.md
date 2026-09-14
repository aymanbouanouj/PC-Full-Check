# Changelog

Creator and maintainer: Ayman Bounaouj

All notable project changes are documented here.

## Unreleased

### Added

- added `PCFC-Easy-Runner.ps1` as an optional convenience launcher while preserving `PC-Full-Check.ps1` as the only supported diagnostic entry point;
- added exact-commit source acquisition from the official GitHub repository, native Windows PowerShell/UAC relaunch, per-user non-reparse workspace validation, public-manifest validation, repository-test execution, and local report opening;
- documented the Easy Runner network boundary separately from the offline core diagnostic path.

### Changed

- updated privacy, security, README, user-guide, public-manifest, and static-test coverage for the optional launcher without altering the published `v0.1.0-beta` tag.

## 0.1.0-beta — 2026-08-02

First public-beta source layout.

### Added

- added a complete non-expert user guide, author-credit file, and CFF 1.2 citation metadata;
- selected four reviewed public audit summaries while preserving eight optional/internal reports outside public scope;
- privacy-first maintained entry point with Quick, Standard, and Full modes;
- privacy-only public parameters with no sensitive-data execution path;
- structured check results, offline HTML and JSON summaries, and local logging;
- trusted Windows-system native executable resolution, bounded timeouts, native exit-code capture, and safe stream-presence metadata;
- transparent health-assessment rules and dependency-free repository tests;
- public documentation, privacy and security policies, contribution guidance, and fictional examples.

### Legacy

- recorded the unpublished original baseline hash and source audit before implementing the public beta;
- excluded both local copies of the original executable source from the public manifest and Git index;
- added `legacy/README.md` as the source-free public historical record;
- identified `PC-Full-Check.ps1` as the only supported public entry point.

### Validation and privacy hardening

- inspected completed local Quick and Standard privacy-mode reports and traced every warning behind their `Attention required` assessments;
- added an exact-value, context-aware privacy report validator that never prints matched secrets;
- added fictional-fixture assessment consistency tests and real-report status consistency checks;
- normalized ambiguous non-positive storage temperature telemetry to unavailable for future reports;
- made null battery status and completion exit-code rules independently testable;
- clarified that privacy-first reports retain useful system inventory and are not automatically anonymous or safe to publish unchanged.
- investigated the hardened Full privacy-mode CHKDSK exit-code 3 result without claiming filesystem corruption;
- replaced the hard-coded CHKDSK volume with structured system-volume selection verified against the Windows root;
- added safe process-start, timeout, stream-presence, failure-kind, argument, and exit-code metadata for integrity checks;
- made Failed evidence take assessment precedence over warnings without inventing a Critical diagnosis;
- made all eight Full privacy omissions display accurate `Omitting ... in privacy mode` progress text;
- added isolated dependency-free CHKDSK and privacy-progress fixtures that never invoke a native diagnostic.
- recorded a targeted Administrator CHKDSK `/scan` success on the dynamically verified system volume: exit code 0, no timeout, no errors found, no raw output saved, and no repair command used;
- preserved the earlier Full-run exit code 3 as historical evidence while removing it as a current-system CHKDSK blocker because the targeted result did not reproduce it;
- added an Administrator-only `tests/run-final-full-validation.ps1` handoff that safely runs one Full privacy-mode validation, verifies required outputs, invokes privacy validation, and saves a structured validation result;
- expanded the repository suite to 44 tests, with 43 passed, 0 failed, and 1 intentionally not executed functional item.
- recorded the final Full privacy-mode run accurately as exit code 1 with one Failed integrated CHKDSK check, while its required files, JSON parsing, and privacy validation passed;
- documented parity between the separate targeted exit-0 process and the integrated Full exit-3 process without assigning an unproven root cause;
- consolidated CHKDSK into one internal production collector and one Windows PowerShell 5.1-compatible native-process helper used by both Full mode and isolated integration validation;
- replaced raw volume metadata with `<verified-system-volume>`, added duration, stream lengths, process configuration, failure, status, and message metadata, and kept raw output unsaved;
- added an Administrator-only production-path validator that runs one shared read-only CHKDSK scan without invoking Quick, Standard, Full, sensitive, or repair paths;
- expanded the repository suite to 48 tests, with 47 passed, 0 failed, and 1 intentionally not executed functional item; the isolated CHKDSK fixture suite passes 21 of 21 cases.

### Public release-candidate hardening

- verified Quick, Standard, and Full privacy-mode functional validation on the current Windows computer;
- recorded the final Full exit code 0 result: 20 Passed, 3 Warning, 0 Failed, 1 Unavailable, and 8 Omitted;
- recorded privacy validation exit code 0 with no confirmed or potential-review findings;
- recorded successful isolated and Full integrated production-path CHKDSK execution with native exit code 0, no raw output, and no repair command;
- removed the public sensitive-data parameter and all maintained raw/sensitive collector implementations;
- retained unsafe Full categories as transparent Omitted-only definitions with no executable command path;
- finalized public-beta README, privacy and security language, release notes, checklist, explicit public-file manifest, and manual Git publication instructions.
- expanded release-candidate static coverage to 57 tests: 56 passed, 0 failed, and 1 intentionally not executed diagnostic item.

### Final remediation and validation synchronization

- added committed-intended fictional Quick and Standard fixtures so repository tests no longer depend on ignored local validation reports;
- pinned `powercfg.exe`, `dism.exe`, `sfc.exe`, and `chkdsk.exe` to canonical direct files beneath the trusted Windows system directory with no PATH fallback;
- added bounded post-timeout termination handling and guarded asynchronous stream-result access;
- added canonical output containment, reparse checks, and immediate pre-write revalidation while documenting the residual non-atomic TOCTOU limitation;
- removed raw localized SleepStates persistence and retained only controlled process/capability metadata;
- removed the unused integrity-command output-name parameter and kept native output-file generation unavailable;
- expanded static coverage to `TOTAL=72; PASSED=71; FAILED=0; NOT_EXECUTED=1`, with assessment fixtures 10/10, CHKDSK/resolver fixtures 26/26, and 8 maintained PowerShell files parsing with 0 errors;
- expanded final public-structure, authorship, citation, user-guide, manifest, ignored-path, and link coverage to `TOTAL=77; PASSED=76; FAILED=0; NOT_EXECUTED=1`;
- recorded successful elevated remediated Quick, Standard, Full, and isolated shared CHKDSK production-path validation on one current Windows computer;
- recorded remediated Quick counts 8 Passed/1 Warning/0 Failed, Standard counts 17 Passed/3 Warning/0 Failed/1 Unavailable, and Full counts 20 Passed/3 Warning/0 Failed/1 Unavailable/8 Omitted;
- recorded privacy-validator success for all three remediated modes with zero confirmed and zero potential-review findings, without reproducing matched values;
- preserved earlier non-zero CHKDSK and failed Full attempts as chronological historical evidence.
