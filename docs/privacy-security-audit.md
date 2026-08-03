# Privacy and security audit

Creator and maintainer: Ayman Bounaouj

## Scope

Post-remediation static review covered the final 42-file public manifest and the preserved audit evidence without copying private report content into public files. Eight maintained PowerShell files parsed with zero errors. The final documentation task performed no diagnostic, native diagnostic, repair command, manual runtime validator, network operation, upload, staging, or publication action. Controlled elevated runtime results from the preceding validation phase are recorded below as aggregate evidence.

## Privacy controls

- Direct computer/user names, profile paths, hardware serials/UUIDs, MAC/IP addresses, raw event messages, raw integrity output, registration/license details, and eight unsafe raw-report categories remain excluded.
- SleepStates now persists only controlled process/capability metadata; raw/localized `powercfg /a` stdout/stderr and reason strings are never saved (`PC-Full-Check.ps1:L598-L618`).
- ActivePowerPlan behavior is unchanged: localized text is omitted and SchemeGuid can remain linkable (`L620-L629`).
- Fictional fixtures/examples contain explicit markers and no detected real identifier patterns.
- Reports remain local and user-retained; no ACL is silently changed.

## Historical findings and remediation

### PRIV-001 — Medium — System fingerprinting remains by design

Original finding: combined hardware, software, driver, update, device, event, security, and storage inventory can identify a system context indirectly.

Remediation/current residual: direct-identifier allowlists and sharing warnings remain; this diagnostic inventory is still intentionally useful and potentially linkable. Open Medium; privacy mode is not anonymity.

### PRIV-002 — Low — Sleep-state raw localized lines were persisted

Original finding: `OutputLines` stored raw nonblank `powercfg /a` stdout.

Remediation: `Get-SleepStateInformation` now saves only completion/start/timeout/exit, stream presence/length, and false parsing/raw-save flags. Tests reject `OutputLines`, `.StdOut`, `.StdErr`, split-line persistence, localized text, and reason fields.

Current residual: native output exists transiently in the shared in-memory result until the collector returns, as with other native calls. No raw SleepStates text is serialized. Resolved.

### PRIV-003 — Low — Active power-plan GUID is retained

Original finding/current residual: SchemeGuid can correlate configuration across reports. Localized name/full stdout remain omitted; no GUID mapping is invented. Open Low.

### PRIV-004 — Informational — User-managed report retention

Reports inherit destination ACLs and remain until the user secures or deletes them. Open Informational.

### PRIV-005 — Informational — Privacy validator uses exact identifiers in memory

The separate manual validator can query exact identifiers for comparison without printing/writing their values. It was not executed. Open Informational.

## Current privacy finding totals

| Severity | Open | Resolved historical |
|---|---:|---:|
| Critical | 0 | 0 |
| High | 0 | 0 |
| Medium | 1 | 0 |
| Low | 1 | 1 |
| Informational | 2 | 0 |

## Public-safety conclusion

The manifest/audit scan found no verified direct local identity, absolute user path, email address, serial value, UUID value, MAC value, private IP value, token, API key, password, private key, connection string, raw event message, raw native output, raw powercfg output, local-validation report content, sensitive execution parameter, legacy execution command, or production repair command. Category counts are recorded in the final verification and repository-state audit without printing private values.

## Remediated runtime privacy evidence

Quick, Standard, and Full validators scanned respectively 13, 25, and 28 files. Each returned exit code 0 with 0 confirmed and 0 potential-review findings; ignored counts were respectively 14, 534, and 536. Ignored matches are context-classified harmless schema or metadata matches, not leaks, and no matched value is reproduced. Standard's Passed SleepStates result persisted no raw output or localized text fields. Full's eight privacy-only entries remained non-executing Omitted results without Data or OutputFile.

This runtime evidence applies to one current computer and does not make privacy mode an anonymity guarantee.
