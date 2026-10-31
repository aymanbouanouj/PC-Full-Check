# Security policy

## Supported versions

The current security-maintenance beta is `v0.2.1-beta` for Windows 10 and Windows 11 with Windows PowerShell 5.1 or later. Historical versions are preserved, not retroactively patched. Capability can vary by Windows edition, hardware, firmware, driver, and permission level.

## Read-only design

The maintained script queries Windows state and writes only to a new or empty report directory. It does not change Windows settings, registry values, services, scheduled tasks, users, disks, partitions, boot settings, security configuration, or power configuration. It does not contain repair operations and does not auto-elevate.

Full mode limits integrity work to DISM `/CheckHealth`, SFC `/verifyonly`, and CHKDSK `/scan`. Supported executables are resolved only as direct, non-reparse files in the canonical Windows system directory. Native processes use bounded initial and post-timeout waits; reports retain controlled process, exit, timeout, and stream-presence metadata without requiring or saving a native output file. The core diagnostic engine does not download code, install dependencies, or upload results. The optional `PCFC-Easy-Runner.ps1` launcher downloads an exact commit snapshot from the official GitHub repository before invoking the same diagnostic engine; it does not upload diagnostic results.

Elevated remediated validation passed on one current computer for Quick, Standard, Full, and the isolated shared CHKDSK production path. The isolated path started, did not time out, returned native exit code 0, produced stdout but no stderr, and saved neither raw output nor a repair command. This validates the read-only online scan path on that computer only; it does not certify physical disk health or universal Windows compatibility.

Output paths are canonicalized, checked for inspected reparse points, constrained to fixed contained report names, and revalidated before writes. These controls partially mitigate the original output-path concern, but a narrow non-atomic local TOCTOU risk remains when a hostile actor can concurrently mutate the destination.

## Optional Easy Runner trust boundary

The Easy Runner is intentionally separate from the diagnostic engine. It downloads the reviewed, pinned `v0.2.1-beta` source commit `b922cd93d39840b39bce07548b98eab71bf34323`, rather than automatically trusting the latest default branch. Before running any downloaded scripts or tests, it validates embedded SHA-256 hashes for **all** PowerShell scripts and the public-file manifest from that approved commit, rejects missing or unexpected public files and untrusted scripts, and rejects reparse points. Only then does it parse maintained scripts and execute the downloaded repository tests.

The runner's ZIP SHA-256 display remains a trace hash, not a signature. The **fixed SHA-256 reference hashes embedded in a previously trusted launcher** form the integrity trust anchor for executable downloaded files. A compromised initial launcher download remains outside that trust boundary; this is not a signed-release mechanism or blanket assurance against all supply-chain attacks. Other non-executable public documents are inventory-checked against the SHA-256-verified manifest but not individually hashed. Releases must be deliberately reviewed and re-pinned to update the trusted source. HTTPS transport remains required. No Git installation, network uploads, or diagnostic repairs are introduced.

## Reporting a security issue

Use GitHub private vulnerability reporting when it is enabled for the repository. Until it is enabled, do not publish exploits, diagnostic reports, private machine details, or identifiers in public issues. A future private report should include the affected project version, a minimal sanitized description, reproduction steps using fictional values, and the expected security impact.

Never attach a diagnostic report publicly without reviewing every file. Prefer a minimal hand-written reproduction. Remove computer and user names, serial numbers, UUIDs, paths, addresses, organization identifiers, registration and license data, and any unrelated event text.

Privacy-only mode reduces direct-identifier exposure but does not make a report automatically safe to publish. Hardware and component names, driver and installed-program inventory, update identifiers, and System-event metadata can disclose details about a computer even when they are not direct personal identifiers. Review those fields in context before sharing.

No private security-reporting address has been verified for this beta; this limitation is recorded in `BLOCKED_DECISIONS.md`.

The unpublished legacy executable is outside the supported public beta. Do not request, redistribute, or execute unofficial copies when reporting an issue.
