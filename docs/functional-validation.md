# Functional validation findings

This record contains aggregate validation evidence only. It intentionally excludes machine identity, paths, hardware inventory, device names, installed-program values, driver values, network values, event details, and raw native output.

## Interpretation rules

- `Attention required` means at least one Warning exists; it is not equivalent to a Failed diagnostic.
- Process exit code 0 is correct when Failed is zero.
- Unavailable and Omitted remain distinct from Passed.
- Privacy-validator harmless/ignored counts are classified ambiguous or harmless metadata matches, not confirmed leaks. Matched values are never reproduced here.
- CHKDSK native exit code 0 validates the implemented read-only online filesystem scan path on the tested computer only. It does not certify physical disk health, predict future reliability, or establish universal Windows compatibility.

## Chronological historical evidence

### Initial Quick and Standard evidence

Earlier privacy-mode runs completed with exit code 0 and `Attention required`:

| Mode | Checks | Passed | Warning | Failed | Unavailable | Omitted |
|---|---:|---:|---:|---:|---:|---:|
| Quick | 9 | 8 | 1 | 0 | 0 | 0 |
| Standard | 21 | 17 | 3 | 0 | 1 | 0 |

Required files were present and referenced JSON parsed. These results predate later native/output remediation.

### Historical failed Full attempts

One hardened Full run returned exit 1 with 19 Passed, 3 Warning, 1 Failed, 1 Unavailable, and 8 Omitted. Its CHKDSK path returned native exit code 3. Privacy validation passed; that privacy result did not override the diagnostic failure.

A later integrated Full attempt again returned exit 1 with the same aggregate status counts and a non-zero CHKDSK result. The exact cause was not proven and was never described as filesystem corruption or physical disk failure.

### Historical separate and consolidated successes

A separate targeted read-only CHKDSK scan later returned native exit code 0 after 225.39 seconds, but it did not initially validate the integrated production collector.

After collector consolidation, the exact shared isolated production path passed in 225.082 seconds. A subsequent Full run completed in 467.645 seconds with exit 0, 20 Passed, 3 Warning, 0 Failed, 1 Unavailable, and 8 Omitted. These successes remain historical evidence for the implementation before the final trusted-resolver, timeout, output-path, and SleepStates remediation.

## Final remediated runtime validation

The modified implementation completed elevated validation successfully on one current Windows computer.

### Quick

| Property | Result |
|---|---|
| Process exit | 0 |
| Assessment | Attention required |
| Checks | 9 |
| Counts | 8 Passed, 1 Warning, 0 Failed, 0 Unavailable, 0 Omitted |
| Required files / JSON | Present / parsed |
| Privacy validation | 13 files; 0 confirmed; 0 potential review; 14 harmless/ignored; exit 0 |

### Standard

| Property | Result |
|---|---|
| Process exit | 0 |
| Assessment | Attention required |
| Checks | 21 |
| Counts | 17 Passed, 3 Warning, 0 Failed, 1 Unavailable, 0 Omitted |
| Required files / JSON | Present / parsed |
| SleepStates | Passed; `RawOutputSaved=false`; `LocalizedOutputParsed=false`; forbidden raw-text fields 0 |
| Privacy validation | 25 files; 0 confirmed; 0 potential review; 534 harmless/ignored; exit 0 |

### Isolated shared CHKDSK production path

| Property | Result |
|---|---|
| Process started | true |
| Timed out | false |
| Duration | 288,920 milliseconds |
| Native exit | 0 |
| stdout / stderr present | true / false |
| Status / validator exit | Passed / 0 |
| Raw output saved | false |
| Repair command used | false |

The standalone validator object is not a normal PC Full Check report directory, so the report privacy validator is not applicable to it. That is not a privacy failure.

### Full

| Property | Result |
|---|---|
| Process exit | 0 |
| Assessment | Attention required |
| Checks | 32 |
| Counts | 20 Passed, 3 Warning, 0 Failed, 1 Unavailable, 8 Omitted |
| Required files / JSON | All four present / parsed |
| Omitted entries | Data absent, OutputFile absent, no executing collector |
| Integrated CHKDSK | Passed; started; no timeout; native exit 0; no raw output; no repair command |
| Privacy validation | 28 files; 0 confirmed; 0 potential review; 536 harmless/ignored; exit 0 |

All three remediated modes had Failed=0, so process exit code 0 is correct. The Warning results explain `Attention required` without creating a Failed result.

## Static evidence accompanying the runtime validation

- Repository: `TOTAL=77; PASSED=76; FAILED=0; NOT_EXECUTED=1`.
- Assessment fixtures: 10 passed, 0 failed.
- CHKDSK/privacy-progress/trusted-resolver fixtures: 26 passed, 0 failed.
- Maintained PowerShell parsing: 8 files, 0 errors.

## Current scope conclusion

The remediated implementation passed its documented modes and shared CHKDSK path on the current computer, and the corresponding privacy validators passed. Representative Windows 10/11 hardware, firmware, edition, provider, and localization coverage remains incomplete. This is one-computer beta evidence, not professional certification or universal validation.
