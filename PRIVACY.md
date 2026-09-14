# Privacy policy and report handling

PC Full Check for Windows processes diagnostic data locally. The core diagnostic engine (`PC-Full-Check.ps1`) contains no upload, download, analytics, telemetry, or network-request feature. A diagnostic report leaves the computer only if the user shares it through another tool.

## Optional Easy Runner network boundary

`PCFC-Easy-Runner.ps1` is a convenience launcher, not a diagnostic collector. It uses HTTPS to contact the official GitHub repository and GitHub API only to resolve the repository's current default branch, resolve that branch to an exact commit SHA, and download that exact source snapshot before local validation and execution.

The Easy Runner does not upload diagnostic reports, report contents, local hardware inventory, usernames, computer names, serials, network identifiers, or other diagnostic evidence to GitHub. It stores its downloaded source, test log, and generated reports in a per-user local workspace under `LOCALAPPDATA`. If that workspace is under a reparse point or cannot be validated as writable, the launcher fails instead of selecting a broader shared fallback directory.

Users who require a strictly offline launch path should download and extract the repository separately and invoke `PC-Full-Check.ps1` directly.

## Privacy-only beta scope

Version 0.1.0-beta operates only in privacy mode. Sensitive-report collection is unavailable and cannot be enabled by a public or hidden parameter.

The original internal executable source predates this boundary and is deliberately unpublished. Unofficial legacy copies are not supported and should not be requested or executed.

The maintained script uses allowlisted fields and excludes:

- computer, account, and user names;
- user-profile and user-specific startup paths;
- email, organization, domain, tenant, registration, and enrollment identifiers;
- hardware serial numbers, UUIDs, asset tags, product keys, and license identifiers;
- MAC addresses, IP addresses, Wi-Fi profiles, and unfiltered network configuration;
- unfiltered device-registration and detailed license output;
- raw MSINFO32, DXDIAG, battery, sleep-study, sleep-diagnostics, and energy reports;
- raw native integrity-command output and raw event messages.

The eight unsafe raw Full entries remain visible as `Omitted` so the report accurately shows what was not collected. No collector or command capable of producing those outputs is present in the maintained public execution path.

When safe evidence is unavailable, a check is `Unavailable` or `Omitted`. Missing evidence is never described as healthy.

## Information retained

Privacy mode can retain diagnostically useful information including:

- hardware manufacturer, model, and component names;
- signed-driver names, providers, versions, dates, signing state, and classes;
- installed-program names, versions, publishers, and install dates;
- Windows update identifiers;
- event provider names, IDs, levels, timestamps, and controlled descriptions;
- safe status, timing, exit-code, and capability metadata.

`SleepStates` saves only controlled process/capability metadata: completion, start, timeout, exit code, stream presence/length, and explicit `LocalizedOutputParsed=false` and `RawOutputSaved=false` flags. Raw or localized `powercfg /a` text and reason strings are never saved.

`ActivePowerPlan` continues to retain only an extracted `SchemeGuid` and an indication that the localized name was omitted. That GUID can remain linkable across reports. The beta does not invent a name mapping or treat the GUID as a direct machine identifier.

These are not the excluded direct identifiers, but their combination can still reveal details about a computer.

## Privacy validation

The repository includes a local validator that checks defined identifier patterns and exact local values without printing matched values. A result with zero confirmed and zero potential-review findings does not prove anonymity or make a report automatically suitable for publication.

The remediated implementation passed privacy validation on one current computer for Quick, Standard, and Full: 13, 25, and 28 files scanned respectively, with zero confirmed and zero potential-review findings in every mode. The harmless/ignored counts were 14, 534, and 536. Those ignored counts represent classified ambiguous or harmless metadata matches, not confirmed leaks; matched values are intentionally not reproduced. Standard verification also confirmed `RawOutputSaved=false`, `LocalizedOutputParsed=false`, and zero forbidden SleepStates raw-text fields.

## Sharing responsibility

Users are responsible for securing report directories, deleting them when no longer needed, and reviewing every file before sharing. Do not attach a diagnostic report to a public issue or repository without careful review.

Privacy-first does not mean anonymous under every hardware, driver, or software naming convention.
