# Start Here — PC Full Check for Windows

This page is the beginner-friendly way to run **PC Full Check for Windows**.

If you only want the shortest answer: use the **Easy Runner**. It can request Administrator privileges, download an exact snapshot from the official GitHub repository, validate the repository, run the repository tests, start the diagnostic, create the reports, and open the HTML report.

> **Supported scope:** Windows 10 or Windows 11, Windows PowerShell 5.1 or later, and Administrator privileges for diagnostic execution. The Easy Runner also needs an Internet connection to acquire the official source snapshot. Other operating systems are not supported.

## Choose what you want to do

| Goal | Mode | Diagnostic entries | Recommended for |
|---|---|---:|---|
| Fast basic check | `Quick` | 9 | A quick overview |
| Normal complete check | `Standard` | 21 | Most users |
| Maximum available diagnostic scope | `Full` | 32 | Deeper troubleshooting |
| Need separate reports from every supported mode | No single combined mode | Run Quick, Standard, and Full separately | Validation or comparison only |

`Standard` is the default mode.

`Full` includes the read-only Windows integrity checks **DISM `/CheckHealth`**, **SFC `/verifyonly`**, and **CHKDSK `/scan`**. Full mode also contains eight privacy-sensitive categories that are intentionally reported as `Omitted`; they are not executed in this release.

There is no supported `All` mode. If you need separate Quick, Standard, and Full reports, run the three supported modes separately. Most users should use `Standard` or `Full` instead.

---

# Option A — One-paste start from Windows PowerShell

Use this when you have **not downloaded the repository** and want the launcher to obtain the official source automatically.

## Step 1 — Open Windows PowerShell

Open **Windows PowerShell** from the Start menu.

You do not need to start it as Administrator manually. The Easy Runner can request elevation through Windows UAC when required.

## Step 2 — Paste the complete block once

Do **not** paste the `PS C:\...>` prompt or any `>>` characters shown by PowerShell. Paste only the code block below.

The example below runs **Standard** mode. To run another mode, change only the final `-Mode Standard` value to `Quick` or `Full`.

```powershell
& {
    $ErrorActionPreference = 'Stop'

    [Net.ServicePointManager]::SecurityProtocol = `
        [Net.ServicePointManager]::SecurityProtocol -bor `
        [Net.SecurityProtocolType]::Tls12

    $Repo = 'aymanbouanouj/PC-Full-Check'

    $Headers = @{
        'User-Agent' = 'PC-Full-Check-Bootstrap'
        'Accept'     = 'application/vnd.github+json'
    }

    Write-Host "`n[1/4] Finding official PC Full Check version..." -ForegroundColor Cyan

    $Commit = Invoke-RestMethod `
        -Uri "https://api.github.com/repos/$Repo/commits/main" `
        -Headers $Headers `
        -ErrorAction Stop

    $Sha = [string]$Commit.sha

    if ([string]::IsNullOrWhiteSpace($Sha) -or $Sha.Length -lt 40) {
        throw 'Unable to resolve the official GitHub commit.'
    }

    Write-Host "[OK] Official commit: $($Sha.Substring(0,12))" -ForegroundColor Green

    $RunnerUrl = "https://raw.githubusercontent.com/$Repo/$Sha/PCFC-Easy-Runner.ps1"

    $TempRunner = Join-Path `
        $env:TEMP `
        ("PCFC-Easy-Runner-" + [Guid]::NewGuid().ToString('N') + ".ps1")

    try {
        Write-Host "[2/4] Downloading official Easy Runner..." -ForegroundColor Cyan

        Invoke-WebRequest `
            -Uri $RunnerUrl `
            -Headers @{ 'User-Agent' = 'PC-Full-Check-Bootstrap' } `
            -OutFile $TempRunner `
            -UseBasicParsing `
            -ErrorAction Stop

        if (-not (Test-Path -LiteralPath $TempRunner -PathType Leaf)) {
            throw 'Easy Runner download failed.'
        }

        $ParserTokens = $null
        $ParserErrors = $null

        [void][System.Management.Automation.Language.Parser]::ParseFile(
            $TempRunner,
            [ref]$ParserTokens,
            [ref]$ParserErrors
        )

        if (@($ParserErrors).Count -gt 0) {
            throw 'Downloaded Easy Runner failed PowerShell syntax validation.'
        }

        Write-Host "[OK] Easy Runner downloaded and parsed successfully." -ForegroundColor Green

        $WindowsPowerShell = Join-Path `
            $env:SystemRoot `
            'System32\WindowsPowerShell\v1.0\powershell.exe'

        if (-not (Test-Path -LiteralPath $WindowsPowerShell -PathType Leaf)) {
            throw 'Windows PowerShell could not be found.'
        }

        Write-Host "[3/4] Starting PC Full Check..." -ForegroundColor Cyan
        Write-Host "A Windows UAC Administrator prompt may appear.`n" -ForegroundColor Yellow

        & $WindowsPowerShell `
            -NoProfile `
            -ExecutionPolicy Bypass `
            -File $TempRunner `
            -Mode Standard

        $ExitCode = $LASTEXITCODE

        Write-Host "`n[4/4] PC Full Check finished." -ForegroundColor Cyan

        switch ($ExitCode) {
            0 {
                Write-Host "[OK] Diagnostic completed successfully." -ForegroundColor Green
            }

            1 {
                Write-Warning 'Diagnostic completed, but at least one health check reported Failed. Review the generated report.'
            }

            2 {
                throw 'The Easy Runner reported an environment, startup, privilege, download, or report-generation failure.'
            }

            default {
                throw "Unexpected PC Full Check exit code: $ExitCode"
            }
        }
    }
    finally {
        if (
            $TempRunner -and
            (Test-Path -LiteralPath $TempRunner -PathType Leaf)
        ) {
            Remove-Item `
                -LiteralPath $TempRunner `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
}
```

## To run Quick instead

Change only:

```text
-Mode Standard
```

to:

```text
-Mode Quick
```

## To run Full instead

Change only:

```text
-Mode Standard
```

to:

```text
-Mode Full
```

For a normal user, **Standard** is recommended. For the widest available diagnostic scope, use **Full**.

---

# Option B — You already downloaded the repository

If the repository is already extracted and the current PowerShell directory contains `PCFC-Easy-Runner.ps1`, use one of these commands.

## Standard — recommended for most users

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PCFC-Easy-Runner.ps1"
```

Equivalent explicit command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PCFC-Easy-Runner.ps1" -Mode Standard
```

## Quick — fastest diagnostic

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PCFC-Easy-Runner.ps1" -Mode Quick
```

## Full — widest available diagnostic scope

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PCFC-Easy-Runner.ps1" -Mode Full
```

## Run Quick, Standard, and Full separately

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PCFC-Easy-Runner.ps1" -Mode Quick
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PCFC-Easy-Runner.ps1" -Mode Standard
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PCFC-Easy-Runner.ps1" -Mode Full
```

There is no supported `All` mode. Run Quick, Standard, and Full separately only when you specifically need separate reports from every supported mode.

## Do not open the HTML report automatically

Add `-NoOpenReport`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PCFC-Easy-Runner.ps1" -Mode Full -NoOpenReport
```

---

# What the Easy Runner does automatically

The optional Easy Runner is a launcher, not a second diagnostic engine. It performs this sequence:

```text
Validate Windows and Windows PowerShell
        ↓
Request Administrator privileges through UAC when needed
        ↓
Create a private local run workspace
        ↓
Contact the official GitHub repository over HTTPS
        ↓
Resolve the repository default branch and its exact current commit
        ↓
Download that exact source snapshot
        ↓
Verify the public manifest and PowerShell syntax
        ↓
Run the repository static test suite
        ↓
Run PC-Full-Check.ps1 in the selected mode
        ↓
Verify the expected report files
        ↓
Open the selected HTML report unless -NoOpenReport was used
```

No Git installation, GitHub CLI, Python, Node.js, Composer, `winget`, or third-party dependency is required for the Easy Runner workflow.

---

# Where the Easy Runner stores its run

The Easy Runner uses a private local workspace under the current Windows user's local application-data area, beneath:

```text
%LOCALAPPDATA%\PC-Full-Check-Runner\Runs\...
```

Inside the selected mode report directory, a successful diagnostic produces files including:

```text
00_HEALTH_SUMMARY.html
00_HEALTH_SUMMARY.json
00_READ_ME.txt
run.log
checks\...
```

The HTML file is the easiest report for a person to read.

---

# How to understand the result

The diagnostic uses these states:

- **Passed** — the implemented check completed successfully under its documented rule.
- **Warning** — verified evidence needs attention, but the diagnostic itself did not fail.
- **Failed** — the check failed, timed out, or returned a failure result.
- **Unavailable** — usable evidence or a required capability was not available.
- **Omitted** — the check was intentionally not executed for privacy.

`Unavailable` and `Omitted` do **not** mean that the component is healthy.

Possible overall assessments include:

```text
Good
Attention required
Unknown
Critical
```

---

# Exit codes

The Easy Runner preserves the diagnostic exit-code meaning:

```text
0 = Completed without a check in Failed state
1 = Completed, but one or more diagnostic checks are Failed
2 = Launcher, startup, platform, privilege, output, or report-generation failure
```

A `Warning` by itself does not produce exit code `1`.

---

# Privacy and network behavior

The project has two separate trust boundaries:

1. **Core diagnostic engine — `PC-Full-Check.ps1`**
   - diagnostic processing is local;
   - it does not upload diagnostic reports;
   - the maintained diagnostic engine does not perform network download/upload behavior.

2. **Optional Easy Runner — `PCFC-Easy-Runner.ps1`**
   - uses HTTPS to obtain an exact source snapshot from the official GitHub repository;
   - validates that source before starting the diagnostic;
   - does not upload the generated diagnostic reports.

Reports can still contain hardware, software, driver, update, event, security, and storage information that may help fingerprint a computer. **Review every report before sharing it.**

---

# Full mode safety

Full mode is the deepest mode currently provided, but it remains diagnostic/read-only by design.

It uses:

```text
DISM /CheckHealth
SFC /verifyonly
CHKDSK /scan
```

The project does not use repair, restore, fix, dismount, or automatic configuration-changing commands in this diagnostic path.

The eight privacy-sensitive Full categories are intentionally `Omitted` in this release:

```text
EnergyReport
BatteryReport
SleepStudy
SleepDiagnostics
MSInfo32
DxDiag
DeviceRegistration
LicenseDetails
```

---

# Direct diagnostic engine — advanced/manual path

You can skip the Easy Runner and execute the core diagnostic engine directly after downloading and extracting the repository.

Open **Windows PowerShell as Administrator**, enter the project directory, and run one of these commands:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PC-Full-Check.ps1" -Mode Quick
```

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PC-Full-Check.ps1" -Mode Standard
```

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PC-Full-Check.ps1" -Mode Full
```

A custom new output directory can be supplied to the direct engine with `-OutputPath`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PC-Full-Check.ps1" -Mode Standard -OutputPath ".\PCFC-Report"
```

The direct engine requires a new or empty output directory and performs stricter output-path safety checks.

---

# Common mistakes

## PowerShell shows errors for `PS C:\...>` or `>>`

Do not copy the PowerShell prompt or previously printed output back into PowerShell.

Copy only the commands inside the code blocks.

## UAC appears

This is expected when the Easy Runner needs Administrator privileges. Approve the prompt only when you intentionally started PC Full Check.

## The Full diagnostic takes longer

This is expected. Full mode performs more checks and invokes read-only Windows integrity tools. Some of those operations can take several minutes.

## The report says `Attention required`

Read the individual checks. `Attention required` can be caused by one or more `Warning` states and does not automatically mean the computer is damaged.

## A check is `Unavailable`

This means the project could not obtain sufficient supported evidence for that check. It is not interpreted as healthy and is not automatically interpreted as broken.

---

# Which mode should I choose?

Use this simple rule:

```text
I only want a fast overview
→ Quick

I am a normal user and want a useful general check
→ Standard

I am troubleshooting, evaluating a used PC, or want the widest available diagnostic scope
→ Full

I specifically need three separate reports for Quick, Standard, and Full
→ Run Quick, Standard, and Full separately
```

For most people, start with **Standard**. Use **Full** when you need the deepest supported diagnostic run.

---

# Important limitation

PC Full Check is a diagnostic aid, not a professional certification and not a guarantee that a computer has no hidden or future hardware problem. Results depend on Windows, hardware, firmware, drivers, permissions, providers, and supported system capabilities.

For additional detail, read:

- [README](README.md)
- [Complete user guide](docs/USER_GUIDE.md)
- [Privacy policy](PRIVACY.md)
- [Security policy](SECURITY.md)
- [Report and assessment guide](docs/report-guide.md)
