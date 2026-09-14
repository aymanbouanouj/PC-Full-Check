# Contributing

Thank you for helping improve PC Full Check for Windows.

## Before proposing a change

1. Read `PRIVACY.md`, `SECURITY.md`, `docs/architecture.md`, and `docs/report-guide.md`.
2. Use fictional, sanitized data in issues, tests, screenshots, and examples.
3. Do not attach a real report publicly.
4. Keep the maintained script compatible with Windows PowerShell 5.1.

## Design requirements

- Keep all diagnostics read-only.
- Preserve privacy mode as the default.
- Select safe properties during collection instead of collecting everything for later redaction.
- Keep sensitive commands and raw-report collection unavailable in v0.2.0-beta. Any such capability requires a separately designed, reviewed, and validated future release.
- Resolve supported native executables from the trusted Windows system directory, add sensible timeouts, and capture safe process, exit, and stream-presence metadata.
- Record missing capability as `Unavailable` and intentional privacy exclusions as `Omitted`.
- Do not use missing telemetry as proof of health.
- Keep assessment rules transparent and documented; do not add a hidden score.
- Add no package or runtime dependency to the required test path.

## Validation

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\run-tests.ps1"
```

If an elevated Windows functional test is appropriate, run only Quick mode into a new temporary directory inside a working copy, record the real result, and remove the temporary report after review. Do not run Full mode automatically.

Update `CHANGELOG.md`, documentation, fictional examples, tests, and `docs/validation-report.md` when behavior changes.
