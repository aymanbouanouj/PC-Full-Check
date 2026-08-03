# Blocked decisions

## Private security contact

- **Issue:** No verified private security-reporting address or hosted advisory channel was supplied.
- **Why unresolved:** Inventing an email address or repository security URL would be misleading.
- **Missing evidence:** A maintainer-approved private contact or future repository security-advisory configuration.
- **Safest current behavior:** `SECURITY.md` directs users to GitHub private vulnerability reporting when enabled and forbids publishing reports, identifiers, or exploit details in public issues until then.
- **Manual follow-up:** Enable and test GitHub private vulnerability reporting before making the repository public, or publish another verified private contact.

## Raw-report privacy sanitization

- **Issue:** Native MSINFO32, DXDIAG, battery, sleep-study, sleep-diagnostics, and energy reports can include identifiers or user-related values, and reliable sanitization across supported Windows versions and localizations has not been verified.
- **Why unresolved:** The project has no safe structured parser that guarantees removal of all prohibited fields.
- **Missing evidence:** Representative reports across Windows 10/11 editions, languages, hardware types, and drivers, plus a reviewed allowlist parser.
- **Safest current behavior:** Version 0.1.0-beta is privacy-only. Unsafe raw entries are fixed `Omitted` definitions, the public sensitive parameter was removed, and the maintained source contains no executable raw collector.
- **Manual follow-up:** Test representative raw reports privately before considering any sanitized derivative feature.

## Representative Windows hardware coverage

- **Issue:** One local environment cannot verify every check on both Windows 10 and Windows 11 across desktops, laptops, editions, firmware modes, battery implementations, storage controllers, and localization settings.
- **Why unresolved:** The required representative systems and hardware telemetry are not available in this project workspace.
- **Missing evidence:** Remediated Quick, Standard, Full, and isolated CHKDSK paths passed on one current computer, but representative elevated Windows 10 and Windows 11 desktops and laptops, including unavailable-capability and timeout paths, are still missing.
- **Safest current behavior:** Capability checks return `Unavailable`, Full mode is never run automatically, localized native output is not parsed for extra claims, and documentation avoids universal compatibility claims.
- **Manual follow-up:** Execute and review the validation matrix described in `docs/supported-systems.md` before declaring a stable release.

## Windows 10 and Windows 11 localization coverage

- **Issue:** The maintained script has not been functionally exercised across representative Windows 10/11 display languages.
- **Why unresolved:** The current project has reports from only one local environment and does not include a localization test matrix.
- **Missing evidence:** Privacy-mode Quick, Standard, and supervised Full results from representative non-English Windows installations, including native-command failure and no-event paths.
- **Safest current behavior:** Structured CIM, cmdlet, event, and exit-code sources are preferred; localized native text is not parsed for extra health conclusions.
- **Manual follow-up:** Run the documented matrix privately and record only sanitized outcomes.

## Future sensitive-report feature

- **Issue:** Sensitive-report collection has not been safely designed, sanitized, or validated.
- **Why unresolved:** Raw files can expose direct identifiers, and representative privacy behavior is unverified.
- **Missing evidence:** A reviewed design, robust allowlist sanitization, protected validation, and explicit release decision.
- **Safest current behavior:** Sensitive-report collection is unavailable in v0.1.0-beta. The parameter and maintained collector implementations were removed, so this is not a public beta execution path.
- **Manual follow-up:** Treat any future sensitive feature as a separately reviewed release; do not re-enable the historical implementation.

## Git author-email privacy

- **Issue:** The existing commit author address may be exposed if the repository is published.
- **Why unresolved:** This task does not decide whether that recorded address is intended for public use, and the address must not be printed by automated review.
- **Safest current behavior:** Keep publication pending and do not modify Git identity or rewrite the existing commit.
- **Manual follow-up:** The maintainer must explicitly accept the existing author metadata or choose a separately reviewed history/privacy action before publication.

## Resolved for v0.1.0-beta: comprehensive audit-report publication set

- **Historical issue:** Twelve detailed audit artifacts required an explicit public/internal decision.
- **Decision:** The public manifest selects the four approved public audit summaries.
- **Preservation:** Five optional technical reports and three maintainer/internal reports remain preserved as ignored local evidence and are not part of the public beta.
- **Manual follow-up:** Review any future publication-scope change and the exact staged diff before approval.

## Resolved for public scope: unpublished legacy executable

- **Issue:** The original internal executable predates the privacy-only public design and may contain raw or sensitive collection behavior.
- **Decision:** Its source is deliberately unpublished and excluded from the public manifest. `PC-Full-Check.ps1` is the only supported public entry point.
- **Historical record:** `legacy/README.md` retains only the baseline SHA-256 and safety context; it contains no legacy source and no execution instructions.
- **Public boundary:** Sensitive-mode functionality remains unavailable in v0.1.0-beta. Users should not search for, request, or execute unofficial legacy copies.

## Resolved on the current computer: remediated integrated CHKDSK production-path parity

- **Issue:** The first hardened Full run returned CHKDSK exit code 3, a separate targeted process returned exit code 0, and the later final Full integrated path returned exit code 3 again after 240 ms.
- **Historical uncertainty:** The separate targeted success did not execute the production collector, and the exact causes of the two earlier integrated exit-code-3 results remain unproven.
- **Implemented containment:** Full mode and the isolated validator now load one production collector and native helper from `internal/ChkdskProduction.ps1`. Arguments are serialized with a Windows PowerShell 5.1-compatible routine, raw output and the actual volume are not persisted, and all required safe execution metadata is produced.
- **Resolution evidence:** Earlier consolidated-path validation passed in 225.082 seconds. After the final resolver/timeout/output remediation, the Administrator isolated validator again executed the exact shared collector and helper in 288.920 seconds with process started, no timeout, native exit code 0, stdout present, stderr absent, no raw output, and no repair command. The remediated Full privacy run used the same path and returned exit code 0 with CHKDSK Passed and zero Failed checks.
- **Decision:** Production-path parity is validated on the current Windows computer. Preserve the historical failures without assigning a cause or inferring physical disk damage.
- **Remaining limit:** This resolution is not universal Windows compatibility or physical disk-health certification.
