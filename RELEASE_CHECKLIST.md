# v0.2.1-beta security maintenance checklist

Version: 0.2.1-beta
Target release date: 2026-10-31

- [x] Prior tag/release history preserved before preparing the release
- [x] Security hardening merged in PR #7
- [x] Elevated Quick mode tested on one Windows computer (reported exit 0; reports existed and JSON parsed)
- [ ] New locked source snapshot accepted, and tested on Windows
- [ ] Fresh release-candidate static CI passes with zero failures
- [ ] Main merge commit passes post-merge GitHub Actions CI
- [ ] Version v0.2.1-beta tag created for immutable merge commit
- [ ] GitHub Release marked as prerelease and published
- [ ] New Zenodo version deposited and new DOI recorded (do not reuse v0.2.0-beta DOI)

No new automatic Full-mode diagnostics are requested. The bootstrap launcher still requires independent trust.

---

# Historical v0.2.0-beta checklist (unchanged)

# Public beta release checklist

Version: 0.2.0-beta

- [x] Repository tests pass
- [x] Parser validation passes
- [x] Quick validation passed
- [x] Standard validation passed
- [x] Full validation passed
- [x] Privacy validation passed
- [x] Fresh v0.2.0-beta repository suite: 78 total, 77 passed, 0 failed, 1 intentionally not executed
- [x] Fresh v0.2.0-beta Quick runtime: exit 0, 8 Passed, 1 Warning, 0 Failed
- [x] Fresh v0.2.0-beta Standard runtime: exit 0, 17 Passed, 3 Warning, 0 Failed, 1 Unavailable
- [x] Fresh v0.2.0-beta elevated Full validator: exit 0
- [x] Fresh Quick/Standard/Full privacy scans: 0 confirmed findings and 0 potential-review findings
- [x] Documentation exposes only Quick, Standard, and Full as supported modes
- [x] Integrated CHKDSK validation passed
- [x] Remediated Quick, Standard, Full, and isolated shared CHKDSK paths passed on the current computer
- [x] SleepStates report schema contains no raw localized output fields
- [x] Native executable resolution is pinned to trusted Windows system paths
- [x] No Failed checks in final Full run
- [x] Sensitive mode disabled
- [x] No local reports tracked or listed for publication
- [x] Unpublished legacy executables excluded and exactly ignored
- [x] Safe legacy history document included
- [x] No absolute local paths in public files
- [x] No private identifiers found by the release-candidate scan
- [x] MIT license present
- [x] README reviewed
- [x] SECURITY.md reviewed
- [ ] GitHub private vulnerability reporting enabled
- [ ] Existing commit author-email privacy decision confirmed
- [x] Comprehensive audit-report publication set selected: four public summaries; eight preserved outside public scope
- [ ] Repository visibility confirmed
- [x] Explicit final staged diff reviewed
- [ ] Remote creation manually approved
- [ ] GitHub push manually approved

Unchecked publication actions require explicit manual completion. This checklist does not authorize staging, committing, creating a repository or remote, or pushing. Representative hardware and localization coverage remains incomplete, so broader compatibility claims are also pending.
