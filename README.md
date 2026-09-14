# PC Full Check for Windows

**Version 0.2.0-beta — public beta**

PC Full Check for Windows is a privacy-first, read-only Windows PowerShell diagnostic aid. It collects selected hardware, Windows, storage, battery, security, update, driver, and reliability evidence, then writes local HTML, JSON, text, and log reports with transparent statuses. The core diagnostic engine does not upload data, install dependencies, or repair the computer.

## Requirements

- Windows 10 or Windows 11;
- Windows PowerShell 5.1 or later;
- Administrator privileges;
- a new or empty output directory.

The core diagnostic script does not auto-elevate. The optional `PCFC-Easy-Runner.ps1` convenience launcher can request Administrator privileges through UAC before invoking the same diagnostic engine. Other operating systems and earlier PowerShell versions are unsupported.

## Privacy and safety

Version 0.2.0-beta is privacy-mode only. There is no public or hidden sensitive mode. Core diagnostic processing is local, with no network request, telemetry, analytics, or upload behavior in `PC-Full-Check.ps1`. The optional Easy Runner uses HTTPS only to resolve and download an exact source snapshot from the official GitHub repository; it does not upload diagnostic reports.

Privacy mode excludes documented direct identifiers and never saves raw localized integrity output. It reduces exposure but does not provide anonymity: reports can still reveal hardware, software, driver, update, device, event, security, and storage information. Review every report before sharing it.

The tool is read-only. Full mode uses DISM `/CheckHealth`, SFC `/verifyonly`, and CHKDSK `/scan`; no repair, restore, fix, dismount, or automatic configuration change is performed.

## Quick start

**New to the project?** Start with the beginner-friendly [START_HERE.md](START_HERE.md) guide. It explains the one-paste launch path, Easy Runner commands, Quick/Standard/Full modes, report locations, privacy, exit codes, and common mistakes.

### Optional Easy Runner

For the easiest supported launch path, save `PCFC-Easy-Runner.ps1` as a `.ps1` file and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PCFC-Easy-Runner.ps1"
```

The Easy Runner defaults to Standard mode, requests UAC when needed, resolves the official repository's current default-branch commit, downloads that exact source snapshot over HTTPS, validates the public repository, runs the static repository tests, then invokes `PC-Full-Check.ps1`. Its network activity is limited to source acquisition from the official GitHub repository; diagnostic reports remain local. Use `-Mode Quick` or `-Mode Full` only when those modes are specifically wanted; `Standard` remains the default.

### Direct diagnostic engine

Open **Windows PowerShell as Administrator**, change to the extracted project directory, and run one command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PC-Full-Check.ps1" -Mode Quick
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PC-Full-Check.ps1" -Mode Standard
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PC-Full-Check.ps1" -Mode Full
```

Standard is the default mode. A custom new output directory can be selected with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PC-Full-Check.ps1" -Mode Standard -OutputPath ".\PCFC-Report"
```

For download, extraction, PowerShell, report-review, troubleshooting, and safety instructions, read the [complete user guide](docs/USER_GUIDE.md).

## Mode comparison

| Capability | Quick | Standard | Full |
|---|---:|---:|---:|
| Total entries | 9 | 21 | 32 |
| Core Windows and hardware checks | Yes | Yes | Yes |
| Battery, update, driver, power, and event checks | Not included | Yes | Yes |
| Read-only DISM, SFC, and CHKDSK checks | Not included | Not included | Yes |
| Privacy-only raw categories | Not included | Not included | 8 Omitted |

The eight Full omissions are EnergyReport, BatteryReport, SleepStudy, SleepDiagnostics, MSInfo32, DxDiag, DeviceRegistration, and LicenseDetails. They have no executing collector, Data, or OutputFile in this release.

## Output files

A successful run creates:

- `00_HEALTH_SUMMARY.html` — offline visual summary;
- `00_HEALTH_SUMMARY.json` — structured complete summary;
- `00_READ_ME.txt` — short orientation and safety notice;
- `run.log` — controlled progress and status log;
- `checks/<Name>.json` — conditional structured data for checks that return Data.

Reports remain local unless the user shares them.

## Status meanings

- **Passed:** the implemented check completed successfully under its documented contract.
- **Warning:** verified evidence matched an attention rule; this is not a software failure.
- **Failed:** a collection or output operation failed, timed out, or returned a non-zero native result.
- **Unavailable:** the required capability or usable evidence was not available.
- **Omitted:** the check was intentionally not executed for privacy.

Overall assessments are `Good`, `Attention required`, `Unknown`, or `Critical`. Warning results produce `Attention required` when no Critical condition exists. Unavailable and Omitted are never treated as Passed. See [the report guide](docs/report-guide.md) for the exact rules.

## Testing

The dependency-free repository suite performs static, structural, parser, fictional-fixture, manifest, privacy, and documentation checks. It does not run Quick, Standard, Full, or a native diagnostic:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\run-tests.ps1"
```

The runner reports its actual totals at completion; its single Not Executed item is the intentionally separate Windows functional diagnostic.

The published `v0.1.0-beta` clean-structure baseline was `TOTAL=77; PASSED=76; FAILED=0; NOT_EXECUTED=1`. The nested assessment suite passed 10/10, the CHKDSK/privacy-progress/trusted-resolver suite passed 26/26, and the 8 maintained PowerShell files in that release parsed with 0 errors. The current repository test runner prints the authoritative totals for the checked revision.

## Validation scope

The remediated implementation was functionally tested on one current Windows computer:

- Quick: exit 0; 8 Passed, 1 Warning, 0 Failed;
- Standard: exit 0; 17 Passed, 3 Warning, 0 Failed, 1 Unavailable;
- Full: exit 0; 20 Passed, 3 Warning, 0 Failed, 1 Unavailable, 8 Omitted;
- the isolated shared CHKDSK production path passed with native exit code 0, without raw-output persistence or a repair command.

These results support the current beta on the validated computer. They do not certify physical disk health, predict future reliability, establish universal Windows compatibility, or replace professional diagnosis. Representative Windows version, hardware, firmware, provider, and localization coverage remains incomplete.

## Documentation

- [Beginner start guide](START_HERE.md)
- [Complete user guide](docs/USER_GUIDE.md)
- [Privacy policy](PRIVACY.md)
- [Security policy](SECURITY.md)
- [Contributing guide](CONTRIBUTING.md)
- [Release notes](RELEASE_NOTES.md)
- [Supported systems](docs/supported-systems.md)
- [Report and assessment guide](docs/report-guide.md)

The original unpublished executable is not part of this repository and is not a supported entry point. `PC-Full-Check.ps1` is the only supported diagnostic entry point. `PCFC-Easy-Runner.ps1` is an optional convenience launcher that acquires and validates the official source before invoking that diagnostic entry point; it is not a second diagnostic engine. See [the source-free legacy integrity record](legacy/README.md).

## Author

Created and maintained by **Ayman Bounaouj**.

See [AUTHORS.md](AUTHORS.md) and [CITATION.cff](CITATION.cff) for attribution and citation metadata. No personal contact address is published.

## License

Released under the MIT License. See [LICENSE](LICENSE).

Copyright (c) 2026 Ayman Bounaouj.
