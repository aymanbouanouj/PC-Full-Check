# Privacy policy and report handling

PC Full Check for Windows processes data locally. It contains no upload, download, analytics, telemetry, or network-request feature. A report leaves the computer only if the user shares it through another tool.

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
