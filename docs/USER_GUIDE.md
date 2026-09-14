# PC Full Check for Windows — Complete User Guide

## 1. About the project

PC Full Check for Windows is a local Windows diagnostic aid written for Windows PowerShell. It collects selected evidence and presents it in readable and structured reports. The only supported diagnostic entry point is `PC-Full-Check.ps1`.

## 2. Author

PC Full Check for Windows was created and is maintained by **Ayman Bounaouj**. No personal email address is published with the beta.

## 3. Current beta status

The current version is **0.1.0-beta**. It has passing static tests and controlled runtime evidence on one current Windows computer, but it is not universally validated or professionally certified. Representative hardware, firmware, Windows edition, and localization coverage remains incomplete.

## 4. What the tool does

The tool checks selected Windows, manufacturer/model, processor, memory, display, physical storage, volume, device, Defender, update, driver, battery, power, event, and reliability information. Full mode also runs three read-only Windows integrity commands. Results are normalized into five check statuses and an overall assessment.

## 5. What the tool does not do

The diagnostic engine does not repair Windows, change settings, install software, upload reports, use telemetry, provide remote support, guarantee that every problem will be found, or replace a qualified technician. Version 0.1.0-beta has no sensitive-data mode and no second supported diagnostic entry point. The optional Easy Runner is a launcher only; it invokes the same diagnostic entry point.

## 6. Supported operating systems

The public beta supports Windows 10 and Windows 11. Linux, macOS, Windows versions outside that stated scope, and non-Windows PowerShell environments are unsupported.

## 7. Requirements

You need Windows PowerShell 5.1 or later, Administrator privileges, working Windows CIM/WMI providers, and permission to create a new report directory. Some checks also depend on optional hardware, firmware, drivers, Windows components, event logs, and storage providers.

## 8. Files included in the download

The public download contains the main script, the optional `PCFC-Easy-Runner.ps1` convenience launcher, the maintained internal native-process helper, public documentation, release and policy files, fictional examples, static tests, attribution files, and public audit summaries. It does not contain private runtime evidence, local-only audit evidence, or either unpublished legacy executable.

## 9. Security and privacy notice

Core diagnostic processing is local and `PC-Full-Check.ps1` makes no network request. The optional Easy Runner uses HTTPS only to resolve and download an exact source snapshot from the official GitHub repository before local validation and execution; it does not upload diagnostic reports. Privacy mode excludes documented direct identifiers and raw native output, but it is not anonymity. A report can still disclose hardware, software, driver, update, device, event, security, and storage details. Protect the output directory and review every file before sharing it.

## 10. Downloading from GitHub

For the direct offline-capable diagnostic path, select **Code**, then **Download ZIP** on the official project page, extract it, and invoke `PC-Full-Check.ps1` directly. For the easier network-assisted path, save `PCFC-Easy-Runner.ps1` from the official repository and run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PCFC-Easy-Runner.ps1"`. The Easy Runner defaults to Standard mode, requests UAC if needed, resolves the official default branch to an exact commit SHA, downloads that exact source snapshot, validates it, runs repository tests, and then invokes `PC-Full-Check.ps1`.

## 11. Extracting the ZIP safely

Use File Explorer to open the downloaded ZIP, select **Extract all**, and choose a directory you control. Work from the extracted directory rather than running the script inside the compressed ZIP. Confirm that `PC-Full-Check.ps1`, `README.md`, `LICENSE`, and the `docs` directory are present.

## 12. Opening Windows PowerShell as Administrator

For direct execution, open the Start menu, search for **Windows PowerShell**, right-click it, select **Run as administrator**, and accept the Windows confirmation prompt. `PC-Full-Check.ps1` checks Administrator membership and stops before creating a report if elevation is missing; it does not auto-elevate itself. The optional Easy Runner is different: when saved as a `.ps1` file, it can request UAC and restart itself in native Windows PowerShell before invoking the same diagnostic engine.

## 13. Navigating to the project directory

If PowerShell is already open in the parent directory of the extracted folder, use:

```powershell
Set-Location -LiteralPath ".\PC-Full-Check"
```

Alternatively, open the extracted directory in File Explorer, use its address bar to identify the directory, and change location without publishing or pasting that personal path into an issue or report.

## 14. Temporary execution-policy command

The supplied launch commands use `-ExecutionPolicy Bypass` only for the new `powershell.exe` process. They do not change the machine-wide policy. If you are already in an Administrator Windows PowerShell session and prefer to set the current process explicitly, use:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

The Process scope ends when that PowerShell process closes. Do not weaken LocalMachine policy for this project.

## 15. Quick mode

Quick runs 9 core checks and is the smallest diagnostic set:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PC-Full-Check.ps1" -Mode Quick
```

## 16. Standard mode

Standard runs 21 checks. It includes Quick plus additional update, reliability, driver, battery, power, installed-program, network-adapter, and event evidence. Standard is the default mode.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PC-Full-Check.ps1" -Mode Standard
```

Running the script without `-Mode` also selects Standard.

## 17. Full mode

Full contains 32 entries: the 21 Standard checks, 3 executing read-only integrity checks, and 8 fixed privacy Omitted entries.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PC-Full-Check.ps1" -Mode Full
```

Full can take substantially longer than the other modes. Keep the elevated PowerShell window open until completion.

## 18. Selecting a custom output directory

Use `-OutputPath` with a new or empty local directory:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PC-Full-Check.ps1" -Mode Standard -OutputPath ".\PCFC-Report"
```

The destination must not be a file, a non-empty directory, an unsafe escape from the report root, or an inspected reparse-point destination. Existing files are not overwritten.

## 19. Complete copy-paste examples

Optional Easy Runner, Standard mode by default:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PCFC-Easy-Runner.ps1"
```

Optional Easy Runner, explicit Quick or Full mode:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PCFC-Easy-Runner.ps1" -Mode Quick
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PCFC-Easy-Runner.ps1" -Mode Full
```

Direct diagnostic engine examples from the extracted project directory in Windows PowerShell as Administrator:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PC-Full-Check.ps1" -Mode Quick
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PC-Full-Check.ps1" -Mode Standard
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PC-Full-Check.ps1" -Mode Full
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PC-Full-Check.ps1" -Mode Standard -OutputPath ".\PCFC-Report"
```

## 20. Expected execution time

There is no guaranteed duration because Windows providers, event logs, storage devices, and hardware vary. Quick is normally the shortest set, Standard queries more providers, and Full may run for many minutes. Full's DISM check has a 300-second bound, SFC and CHKDSK each have a 900-second bound, and power queries use shorter bounds. A timeout becomes a visible Failed result rather than an indefinite wait.

## 21. Reading progress output

PowerShell prints a fixed progress line for every selected entry in the form `[current/total] description...`. At the end it prints the overall assessment and report directory. Progress text identifies intentionally Omitted entries rather than implying that they executed.

## 22. Report directory structure

Without `-OutputPath`, the script creates a timestamped `PC_FULL_CHECK_...` directory on the current user's Desktop. A successful report contains:

```text
00_HEALTH_SUMMARY.html
00_HEALTH_SUMMARY.json
00_READ_ME.txt
run.log
checks/
```

The `checks` directory contains JSON only for checks that return structured Data.

## 23. Opening 00_HEALTH_SUMMARY.html

Double-click `00_HEALTH_SUMMARY.html` to open the offline summary in the default browser. It uses no remote fonts, scripts, images, CDNs, or external libraries. Treat it as a convenient view of the same diagnostic evidence, not as a certificate.

## 24. Understanding 00_HEALTH_SUMMARY.json

The JSON summary is the structured record. It contains Tool, GeneratedAt, Mode, Privacy, Assessment, System, Findings, Counts, Checks, and Limitations. Each check envelope records its name, display name, status, timing, optional output reference, controlled error/message, optional native exit code, critical flag, and conditional Data.

## 25. Understanding 00_READ_ME.txt

`00_READ_ME.txt` identifies the tool version, selected mode, privacy state, assessment, preferred starting files, and the key warning that Unavailable and Omitted are not positive health findings.

## 26. Understanding run.log

`run.log` contains controlled start, check, duration, status, optional native exit-code, and completion records. Detailed exception text and raw native command output are suppressed. The file is useful when a check is slow or fails.

## 27. Understanding checks/*.json

Files under `checks/` contain the allowlisted structured Data returned by individual checks. An entry can legitimately have no per-check JSON when it has no Data, is Omitted, or could not create structured output. Follow `OutputFile` from the summary rather than assuming every entry has a file.

## 28. Status meanings

- **Passed:** completed under the implemented contract without an implemented warning condition.
- **Warning:** completed and matched a documented attention rule.
- **Failed:** failed, timed out, could not save required output, or returned an unresolved non-zero native result.
- **Unavailable:** the required capability or usable evidence was not available.
- **Omitted:** intentionally not run, normally because the privacy-only release forbids that raw category.

Unavailable and Omitted are not Passed.

## 29. Overall assessment meanings

- **Good:** essential checks completed, with no Warning, Failed, or Critical condition.
- **Attention required:** at least one Warning exists and no Critical condition exists. A Warning is not a software failure.
- **Unknown:** a check Failed or an essential check did not produce usable Passed/Warning evidence, without a verified Critical condition.
- **Critical:** a narrowly implemented verified critical condition exists. In this beta, that is limited to Windows explicitly reporting a physical disk as Unhealthy.

## 30. Process exit codes

- **0:** the run completed without a Failed check. Warning, Unavailable, or Omitted results can still be present.
- **1:** one or more checks have Failed status.
- **2:** startup, platform, privilege, output initialization, summary generation, or final logging failed.

Always read the report and assessment; an exit code alone is not a health conclusion.

## 31. Quick versus Standard versus Full

| Mode | Entries | Best suited to | Important difference |
|---|---:|---|---|
| Quick | 9 | A smaller core snapshot | No extended power, inventory, event, or integrity entries. |
| Standard | 21 | The normal default review | Adds twelve capability-dependent checks. |
| Full | 32 | A supervised deeper review | Adds three read-only integrity checks and eight privacy omissions. |

More entries do not guarantee more usable evidence. Hardware or provider absence may produce Unavailable.

## 32. Full-mode integrity commands

Full uses trusted copies of Windows system executables, not PATH-selected alternatives:

- DISM with `/Online /Cleanup-Image /CheckHealth`;
- SFC with `/verifyonly`;
- CHKDSK with the dynamically verified Windows system volume and `/scan`.

The tool classifies their process start, timeout, and exit metadata. Localized stdout and stderr are not saved or parsed for extra health claims.

## 33. Explanation of the eight privacy Omitted checks

The following entries are always Omitted in Full mode: EnergyReport, BatteryReport, SleepStudy, SleepDiagnostics, MSInfo32, DxDiag, DeviceRegistration, and LicenseDetails. Their potential raw outputs are outside the privacy-only allowlist. Each has no executing collector, Data, or OutputFile.

## 34. No-repair guarantee and limits

The maintained production script contains no repair workflow. It uses verify/check/online-scan operations only. It does not promise that Windows providers themselves are error-free, that every failure is harmless, or that a Passed result guarantees future health. Stop and seek qualified help if you are unsure about any result.

## 35. Report privacy and sharing risks

Reports remain local unless you share them. Even without direct usernames, computer names, network addresses, serials, or raw event messages, combined inventory can fingerprint a system or expose organizational and security context. The active power-scheme GUID can also be linkable across reports.

## 36. How to review a report before sharing

Open every top-level file and every referenced `checks/*.json` file. Look for hardware and model names, installed-program and driver inventory, update identifiers, device descriptions, event metadata, storage details, paths, organization-specific text, and anything unrelated to the support request. Share the smallest sanitized excerpt that answers the question; do not publish the entire report by default.

## 37. How to delete a report

Close the HTML file and any editor using the report, then delete the exact report directory through File Explorer. Confirm its name and location before deleting it. The project does not automatically delete reports, and it does not change their access-control settings.

## 38. Troubleshooting

Start with the PowerShell error, `00_READ_ME.txt`, `run.log`, the summary status, and the relevant check JSON if it exists. Confirm the supported Windows version, Windows PowerShell version, Administrator state, destination safety, and availability of the required Windows component. Do not respond to a failure by running an unreviewed repair command.

## 39. Administrator error

If the script says Administrator privileges are required, close the current window, open **Windows PowerShell** with **Run as administrator**, return to the project directory, and rerun the same repository-relative command. The script stops before report creation when this check fails.

## 40. Execution-policy error

Use the supplied `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ...` command or the Process-scope command in section 14. Do not change organization-managed policy without authorization. If policy remains enforced, ask the responsible administrator rather than bypassing security controls.

## 41. Existing or non-empty output directory

Choose a new directory name or empty the intended directory manually only after reviewing its contents. The script rejects files and non-empty destinations to prevent accidental overwrite. It also rejects unsafe path and reparse-point conditions.

## 42. Unavailable checks

Unavailable means the required Windows component, provider, hardware, firmware, driver telemetry, or usable evidence was not available. This is common for capability-dependent checks and is not equivalent to either Passed or Failed.

## 43. Warning results

A Warning means the check completed and found a documented attention condition, such as a Windows-reported non-OK state or a project heuristic threshold. It can produce `Attention required` while the process exit code remains 0. Review the evidence; do not describe Warning as a software failure.

## 44. Failed results

A Failed result means the collector, process, timeout, or required output contract failed, or a narrowly verified critical condition was recorded. The process exits 1 when any check is Failed. Read the controlled message and log, and seek qualified help before taking corrective action.

## 45. Long-running Full mode

Full may spend many minutes in Windows integrity operations. Leave the PowerShell window open, keep the computer connected to reliable power, and wait for the tool's bounded timeout or completion message. Do not start a second overlapping Full run into the same destination.

## 46. Battery unavailable on desktops or unsupported firmware

Desktop computers commonly have no battery. Laptops can expose charge state without reliable design/full-charge capacity. In either case Battery may be Unavailable. Missing capacity is never converted into a Passed health claim.

## 47. TPM and Secure Boot differences

TPM and Secure Boot depend on hardware, firmware, boot mode, Windows support, and policy. A missing or unreadable capability can be Unavailable. A supported but disabled Secure Boot state, or a present TPM that is not ready, can be Warning. These checks do not change firmware settings.

## 48. Windows language and provider limitations

Native command text is localized, so the beta uses process metadata and exit codes instead of parsing localized integrity or sleep-state prose for additional claims. CIM/WMI, event, storage, driver, firmware, and cmdlet providers can vary by Windows edition, language, hardware, and vendor.

## 49. Testing the repository

Developers and reviewers can run the dependency-free static suite:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\run-tests.ps1"
```

The runner uses fictional fixtures and static inspection. It does not invoke Quick, Standard, Full, CHKDSK, DISM, SFC, or powercfg.

## 50. Reporting a security issue

Read `SECURITY.md` first. A verified private reporting channel is not yet recorded for this beta. Do not post exploits, personal identifiers, or diagnostic reports in a public issue. When private vulnerability reporting is officially enabled, submit the version, a minimal sanitized description, fictional reproduction steps, and expected impact through that channel.

## 51. Known limitations

The beta has runtime evidence from one current Windows computer, not a representative compatibility matrix. Provider availability varies; CIM and cmdlet calls do not all have explicit timeouts; report inventory remains potentially linkable; event retention constrains interpretation; localized native text is not used for additional claims; and narrow local time-of-check/time-of-use path risks cannot be eliminated completely.

## 52. Author and license

Created and maintained by **Ayman Bounaouj**. PC Full Check for Windows is released under the MIT License in `LICENSE`. Attribution details are in `AUTHORS.md`, and citation metadata is in `CITATION.cff`.

## 53. Version information

This guide describes PC Full Check for Windows **0.1.0-beta**. Check `RELEASE_NOTES.md` and `CHANGELOG.md` before using another version because modes, fields, checks, and limitations may change.

## 54. Final safety reminder

Run only the maintained `PC-Full-Check.ps1` entry point from a source copy you trust. Use Windows PowerShell as Administrator, choose a new or empty destination, keep reports private until reviewed, interpret Warning/Unavailable/Omitted accurately, and never treat this diagnostic evidence as permission to run an unreviewed repair command.
