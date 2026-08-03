# Architecture

## Goals and boundaries

PC Full Check for Windows is a dependency-free diagnostic entry point with one internal CHKDSK implementation, documentation, tests, and fictional examples. Its operational boundary is read-only Windows inspection plus writes to a new or empty local report directory. It has no network path, repair path, sensitive-collection path, auto-elevation path, or plug-in execution system.

`PC-Full-Check.ps1` is the only supported public executable. The original internal source predates this architecture and is deliberately absent from the public file set; `legacy/README.md` contains only its historical integrity record.

## Execution flow

1. Parse the advanced-script parameters.
2. Validate Windows, PowerShell version, Windows 10/11 identification, CIM availability, and Administrator privileges before creating output.
3. Canonicalize and create a new or empty non-reparse output directory and its contained `checks` subdirectory.
4. Build the deterministic privacy-only check manifest for Quick, Standard, or Full mode.
5. Execute each manifest item through the shared check runner, recording timing and a normalized status.
6. Keep structured collection objects separate from rendering.
7. Apply documented assessment rules and write JSON, encoded offline HTML, text orientation, and the run log.
8. Return the documented process exit code.

## Check model

Each selected check records:

- stable internal name and display name;
- Passed, Warning, Failed, Unavailable, or Omitted status;
- ISO 8601 start time and duration in milliseconds;
- relative output filename where applicable;
- native exit code where applicable;
- controlled message and error fields;
- structured data rather than preformatted PowerShell display text;
- an explicit `Critical` flag used only for verified serious conditions.

An unsupported command or capability is `Unavailable`; an intentional privacy exclusion is `Omitted`. Unexpected collection or output-write errors are `Failed`. The check runner continues after non-critical failures.

## Privacy boundary

Collectors use property allowlists. Identifying CIM properties are not placed in maintained report objects, and event objects omit raw message text. The eight unsafe Full entries use fixed Omitted-only definitions with no native command or sensitive collector behind them.

Stored output references are relative paths so a default Desktop location does not leak a user-profile path into the report. Exception details are replaced with controlled messages in the report and log. There is no sensitive-report execution path in v0.1.0-beta.

## Native process boundary

The shared native runner:

- accepts only `powercfg.exe`, `dism.exe`, `sfc.exe`, or `chkdsk.exe` and resolves the executable as a direct, non-reparse file beneath the canonical `[Environment]::SystemDirectory`;
- starts without shell execution or a visible window;
- captures standard output and standard error;
- waits for a bounded period, attempts to terminate only the timed-out direct child, and uses a second short bounded wait;
- records the exit code;
- exposes controlled process, timeout, exit, and stream-presence metadata to callers without requiring a native output file.

Native localized text is not parsed when no stable structured contract is available. Integrity checks use exit codes and explicitly state that localized text was not used for additional health claims. Privacy-only mode never saves their raw text.

Every report write reconstructs a fixed relative path beneath the canonical selected output directory and rechecks inspected path components for reparse points. Production never recursively deletes an output path and does not silently change ACLs. Path-based checks reduce, but cannot eliminate, local time-of-check/time-of-use risk.

## Rendering

The JSON summary preserves values and collections. The HTML renderer converts every dynamic value with `System.Net.WebUtility.HtmlEncode` before insertion. CSS is embedded; no script, remote image, CDN, font, or other external resource is used.

## Compatibility choices

The implementation uses functions and built-in .NET/PowerShell APIs available to Windows PowerShell 5.1. It avoids classes, third-party modules, Pester as a required dependency, PowerShell 7-only syntax, and background job infrastructure.
