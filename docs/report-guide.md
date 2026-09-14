# Report and assessment guide

## Check statuses

- **Passed:** the selected collection or command completed according to its structured source or exit-code contract, with no implemented warning condition. For localized native commands, Passed does not claim more than a zero exit code.
- **Warning:** a verified condition matched a documented attention rule.
- **Failed:** a collection/output operation failed, timed out, returned a non-zero native exit code, or a verified serious condition was observed.
- **Unavailable:** Windows, hardware, firmware, a driver, an edition, permissions, or a provider did not expose usable evidence.
- **Omitted:** the check was intentionally not run, normally because privacy mode forbids the raw output.

Unavailable and Omitted are distinct from “no issue found.” A check with no evidence is never converted to Passed.

Passed describes the implemented check contract, not a professional certification and not a claim that every optional telemetry field exists. For example, storage reliability can be Passed when usable fields are returned while an unsupported maximum-temperature field remains null.

## Final assessment

There is no hidden score.

1. **Critical** is used only when a result has an explicit critical flag for a verified serious condition. In 0.2.0-beta, this is limited to a physical disk whose Windows `HealthStatus` is explicitly `Unhealthy`.
2. **Attention required** is used when one or more checks have Warning status and no Critical condition exists.
3. **Unknown** is used when a check failed without a verified critical condition, or when an essential check did not complete with Passed or Warning status.
4. **Good** is used only when all essential checks completed with Passed or Warning, no Warning exists, no check Failed, and no Critical condition exists.

The essential set is Windows information, manufacturer/model, CPU, memory, display, physical storage, volumes, problem devices, and Microsoft Defender.

Unavailable non-essential optional telemetry remains visible in the counts and check table. It is not described as healthy.

## Implemented warning rules

- A physical disk with a status other than `Healthy` is a Warning, except explicit `Unhealthy`, which is Failed and Critical.
- A mounted drive-letter volume with non-`Healthy` status or less than 10% free space is a Warning. The 10% level is a project heuristic, not a Windows or manufacturer guarantee.
- A present PnP device whose Windows status is not `OK` is a Warning.
- Defender antivirus or real-time protection not reported as enabled is a Warning. An unavailable Defender cmdlet is Unavailable, not Warning or Passed.
- A present TPM not reported ready is a Warning. No reported TPM is Unavailable because absence can be expected on some hardware.
- Supported but disabled Secure Boot is a Warning. An unsupported or unreadable state is Unavailable.
- Any observed critical/error System event in the requested 30-day window is a Warning.
- Any observed WHEA event in the requested 90-day window is a Warning, but is never described as proof of permanent hardware failure.

## Battery heuristic

When Windows exposes both aggregate design capacity and aggregate full-charge capacity through safe CIM/WMI battery classes, estimated health is:

`full-charge capacity / design capacity x 100`

- 80% or higher: no battery-capacity warning from this heuristic;
- below 80%: Warning;
- missing capacity telemetry: Unavailable.

This is a project heuristic, not a manufacturer guarantee, warranty test, cell-level measurement, or prediction of remaining lifetime. Multiple-battery systems use aggregate capacity, which can hide differences between individual packs.

## Storage and integrity interpretation

Storage health comes from actual Windows `HealthStatus` and `OperationalStatus` data, not model-age assumptions or invented SMART scoring. Reliability counters are shown only when Windows exposes them.

Storage providers can return zero in unsupported temperature fields without a separate validity flag. The maintained collector treats non-positive temperature telemetry as unavailable and stores null rather than describing it as a verified 0 degrees Celsius reading. If no usable reliability field is returned, the check is Unavailable rather than Passed.

DISM CheckHealth, SFC verify-only, and CHKDSK online scan use native exit codes. Because their text is localized, the beta does not parse it for additional claims. A zero exit code means the process completed normally under the implemented contract; it does not certify the computer. A timeout or start failure is Failed with a specific execution message. A missing executable is Unavailable. An unresolved non-zero exit code remains Failed and is not converted into a filesystem-corruption claim.

CHKDSK targets only a dynamically verified Windows system volume. `Win32_OperatingSystem.SystemDrive` must contain a valid drive letter and must agree with the Windows-root volume. If the sources are unavailable or disagree, CHKDSK is Unavailable and does not start. The only permitted arguments are the verified volume and `/scan`; no repair or dismount option is used.

The check records a trusted executable identity, placeholder argument array, process-start state, timeout state, native exit code, stdout/stderr-presence and length metadata, expected-output-file requirement, and volume-selection method. Raw localized integrity output and the actual system-volume value remain unsaved in privacy mode.

Historically, a separately implemented targeted scan returned exit code 0 after 225.39 seconds while an integrated Full attempt returned code 3. The separate success did not validate the integrated collector, and the non-zero integrated result did not prove corruption. Both results remain in the chronological record.

The maintained Full manifest and isolated integration validator load one internal production collector and native helper. Their result stores only `<verified-system-volume>` and `/scan`, stream presence and lengths, timing, process configuration, status, and other safe execution metadata. It never persists raw CHKDSK output or the actual volume value.

The exact remediated shared path passed isolated Administrator validation in 288920 ms with native exit code 0, no timeout, no saved raw output, and no repair command. The integrated Full privacy-mode check also Passed with native exit code 0. This validates the implemented path on the current computer only; the interpretation limits above still apply.

Trusted resolution and native process creation are separate operating-system operations, leaving a narrow time-of-check/time-of-use substitution window as a residual risk. Strict executable allowlisting and immediate execution reduce that window but do not eliminate it completely.

## Event time ranges

The report records the requested start time plus the earliest and latest observed timestamps in the returned set. Retention, filtering, the maximum event limit, and log availability can affect the range. Old WHEA records indicate an observed historical event, not necessarily a current or permanent fault.

## Privacy and sharing

Version 0.2.0-beta is privacy-mode only. Sensitive-report collection is unavailable, and the eight unsafe raw Full categories are fixed Omitted entries with no executable collector.

Privacy mode avoids the documented direct identifiers but is not an anonymity guarantee or automatic publication sanitizer. Hardware manufacturer/model, component names, driver inventory, installed-program inventory, update identifiers, and System-event metadata or diagnostic descriptions remain useful report content. They are not direct personal identifiers by themselves, but they can reveal computer details and should be reviewed before sharing. Report processing is local, and the script does not upload reports.
