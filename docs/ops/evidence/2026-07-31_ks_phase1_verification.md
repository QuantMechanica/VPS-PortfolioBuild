# KS baseline Phase 1 — independent Codex verification

Router task: `d6fea536-edb3-488e-8fcb-23d4912c27c7`  
Scope: Topic B, Phase-1 file-side execution only  
Verification mode: strictly read-only except this deliverable

## Verdict

**PASS — all five execution conditions independently verified.** This is a
file-side operations verdict, not a pipeline verdict and not an authorization
for Phase 2. No baseline, terminal-local file, Common file, task, chart,
terminal, position, T_Live setting or AutoTrading setting was changed during
this verification.

Observed evidence identities:

| Evidence | SHA-256 at verification |
|---|---|
| `D:\QM\reports\state\ks_common_backup_20260731\_manifest.json` | `73787118127694d9f0da3e9fe24cc6ba70f84f77c84d1c801cc8115157a27c59` |
| `D:\QM\reports\state\ks_phase1_execution_20260731.json` | `5a9200b23dcb86b34636a98d7070d927baaf02fc7345c7ceda2da2a87ae947ab` |
| `D:\QM\reports\state\live_book_pulse.json` observed at `2026-07-31T12:30:01Z` | `2a00b2cfabb8ee5889a5bc9069136c5669e5ca33513af2f1b0e3c4866ccb5f63` |

The live pulse is a mutable state artifact; the timestamp and hash above bind
the exact snapshot read for this verification.

## Condition 1 — backup manifest and content

**PASS.** The backup directory contains `_manifest.json` plus exactly 54 data
files. Independently enumerating and hashing all 54 data files produced:

- file count: manifest 54, actual 54;
- total bytes: manifest 185,470, actual 185,470;
- missing manifest paths: 0;
- extra data paths: 0;
- SHA-256 or byte-size mismatches: 0.

Five independently selected hash samples (the full 54-file set was checked):

| Backup file | Bytes | Independently computed SHA-256 |
|---|---:|---|
| `QM5_10123_XAUUSD.json` | 1,618 | `d8340c010805f0892a112ea497e05331402e9d3c7cadd289944d7850ddf3979e` |
| `QM5_10403_XAUUSD_DWX.json` | 3,019 | `7e030c9daaa9dd9fe3b460e56d863974ffc855b0f961326677d624cff0ac7ad4` |
| `QM5_11422_USDCAD.json` | 2,852 | `0a489a2fdd5ec2b7c042e9df1319cb306110f64dd02a2c4f68e76b8469959fbc` |
| `QM5_13213_USDJPY_DWX.json` | 21,222 | `30027f92fef810fbb8a887f4e26e32184e739e5772aeb4b9df004730e6adbeca` |
| `QM5_20048_XTIUSD.json` | 1,035 | `aac18d99d047ba04489cba7227fe7b561764601bc9a7390a8e1290961cb5ccfb` |

Every sample and all remaining manifest rows matched both recorded size and
SHA-256.

## Condition 2 — 40 alignment paths and terminal-local immutability

**PASS.** Sources were read from
`C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\baselines`; Common targets were read
from
`C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM\baselines`.

The machine JSON names exactly 40 rows representing 20 distinct sleeve names
with both broker-symbol and `_DWX` aliases. Independent SHA-256 comparison of
every row found:

- terminal-local vs Common mismatches: 0/40;
- terminal-local vs recorded `source_sha` mismatches: 0/40;
- Common vs recorded `common_post_sha` mismatches: 0/40.

All 40 terminal-local `LastWriteTimeUtc` values remain in the narrow WP-11
window `2026-07-25T09:41:51.1581827Z` through
`2026-07-25T09:41:51.7236531Z`. The corresponding Common mtimes are in the
Phase-1 copy window `2026-07-31T12:10:56.0889987Z` through
`2026-07-31T12:10:56.4434768Z`. Thus the source hashes match the execution
record and the terminal-local mtimes predate Phase 1 by six days; no Phase-1
write is visible in the terminal-local tree.

## Condition 3 — four allowed deploys and two explicit holds

**PASS.** Both staged aliases and both Common aliases exist for each allowed
sleeve and are byte-identical:

| Paths | Staging SHA-256 = Common SHA-256 |
|---|---|
| `QM5_1567_EURUSD.json`, `QM5_1567_EURUSD_DWX.json` | `ddc677e66569c260dd8e9472130e6ad43f9c1b7be47b288387d7da91ede176ae` |
| `QM5_13117_EURGBP.json`, `QM5_13117_EURGBP_DWX.json` | `8338275651702ee5bf0bdabfc09be3897acf05072b1ed1f50903ba1fab85bf41` |

The four Common mtimes are `2026-07-31T12:10:56.4565101Z` through
`2026-07-31T12:10:56.4845830Z`, immediately following the alignment window.
No `QM5_10513_*` or `QM5_10440_*` file exists in Common. The provenance hold
and Q10-FAIL hold were therefore respected.

## Condition 4 — exact Common end state

**PASS.** Expected names were independently reconstructed as the 54 backup
manifest names plus the four allowed created names. The Common directory has:

- exactly 58 files, all `.json`;
- zero subdirectories;
- missing expected paths: 0;
- unexpected extra paths: 0.

Subtracting the 40 aligned names from the 54 backup names leaves exactly 14
untouched paths. Independent Common SHA-256 comparison against their backup
manifest rows found 0/14 mismatches. The untouched set is the seven alias
pairs for EAs 10123, 10128, 10145, 10183, 11422, 13013 and 20048.

## Condition 5 — post-copy pulse and residual dormancy

**PASS.** The observed pulse was generated at `2026-07-31T12:30:01Z`, about 19
minutes after the Common copy window, so it is a post-copy pulse. Its
kill-switch section reports:

- `mirror_divergences=0`;
- `hash_mismatches=0`;
- `missing_files={10440|NDX, 10513|XAUUSD}` exactly;
- baseline sources: terminal-local 20, Common 2, none 2;
- `loaded_ok=10/24`, dormant 12.

The dormant set is plausible and contains both newly deployed Common-only
sleeves, `1567|EURUSD` and `13117|EURGBP`, as required before Phase-2 re-init.
The remaining ten are the nine full-log dormant sleeves identified in the R1
review plus the known pulse-tail false positive `10706|GBPUSD`. Overall pulse
verdict `ALARM` / kill-switch status `WARN` is therefore the expected Phase-2
residual, not a failed Phase-1 copy.

## Boundary

Phase 2 remains OWNER+Claude maintenance-session work. This verification does
not authorize a T_Live restart, chart operation, position operation, 10513
deployment, 10440 promotion, or any live-trading change.
