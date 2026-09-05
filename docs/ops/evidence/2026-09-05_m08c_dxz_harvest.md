# M08-C native DXZ history download and matched-minute spreads

RESULT: REVIEW. Router task `b74e58e7-da8c-42c1-87ec-ade75db377dc`. All six native DXZ series cover the requested 2026-05-20 through 2026-09-04 server-date window. Each has nonzero matched FTMO minutes. Two bounded runs used only **T2**, for **126.031 seconds / 2.10 minutes** total including compile, extraction, freezing and reservation handling. Both owned processes were closed by the canonical identity-bound helper and both owned reservations released. No active backtest was interrupted.

## What changed in the measurement

M08-B queried local `.DWX` custom archives. This run requests their native broker counterparts GBPUSD, EURUSD, USDCAD, NZDUSD, XTIUSD and XAGUSD on the registered DXZ factory connection. It neither rewrites nor extends a custom symbol. Native versus custom identity is recorded (`is_custom=0` for all six). XTIUSD pairs with FTMO USOIL.cash; other native names match their FTMO names.

The source performs a bounded native `CopyRates` date request before extracting, recording each attempt, return count/error, connection state, first/last labels, broker history start and point size. [MetaQuotes documents that script requests initiate a server download when local data are absent](https://www.mql5.com/en/docs/series/copyrates). Source and compiler bindings, compiled binary, download receipts, raw rows and coverage are frozen with raw and compressed SHA-256 hashes under [the evidence directory](2026-09-05_m08c_dxz_harvest/).

The first run exposed the terminal's 100,000-bar series limit: recent data were available, but the early requested dates were truncated. A second run rechecked that **the same T2** was idle and reserved it again, using `MaxBars=250000` in that run's startup INI. It refused any replacement slot. The second request reaches the start day for all six. The Experts/live-trading settings in the canonical startup recipe remain disabled. The canonical harvester and bootstrap helper were not edited; both compile receipts report zero errors and warnings. This is native broker measurement evidence, not adoption of a new governed archive comparator.

## Matched results

Delta is **FTMO spread minus DXZ spread**, in quote-price units, after multiplying each venue's integer spread by its own point size. This excludes commissions and swaps. FTMO point sizes come from the frozen dated provider digits; DXZ point sizes come from the native observation.

| Native symbol | First server bar | Last server bar | Matched minutes | Delta p50 | Delta p90 |
|---|---|---|---:|---:|---:|
| GBPUSD | May 20 00:04 | Sep 4 23:54 | 99,907 | -0.00002 | 0.00002 |
| EURUSD | May 20 00:04 | Sep 4 23:54 | 99,944 | -0.00001 | 0 |
| USDCAD | May 20 00:04 | Sep 4 23:54 | 99,840 | -0.00002 | 0.00002 |
| NZDUSD | May 20 00:05 | Sep 4 23:54 | 99,863 | -0.00001 | 0.00002 |
| XTIUSD | May 20 01:00 | Sep 4 23:54 | 99,682 | 0.038 | 0.062 |
| XAGUSD | May 20 01:00 | Sep 4 23:54 | 99,990 | 0.035 | 0.053 |

The [matched-minute artifact](2026-09-05_m08c_dxz_harvest/matched_minutes.json) contains four six-hour session bands per symbol, each with its actual intersection count and p50/p90. [CSV table](2026-09-05_m08c_dxz_harvest/session_deltas.csv). Quantiles use linear interpolation over matched observations only; no missing minute is imputed.

Clock qualification remains explicit: old FTMO exports appended a literal Z to raw server labels. The join preserves those labels and applies the same declared summer offset (+180 minutes) to both venues; the new DXZ rows retain both server and converted UTC labels. The four bands use that declared UTC conversion. This is a provisional clock alignment, not empirical historical clock/DST validation. No transition week lies in the requested window. No economic inputs, live configuration, risk freeze or Q-pipeline verdict were changed.

## Verification

`python C:/QM/repo/docs/ops/evidence/2026-09-05_m08c_dxz_harvest/join.py` verifies all frozen raw/compressed hashes, six earlier FTMO input hashes, strict row ordering, nonnegative integer spreads, native UTC conversions, counts and coverage bounds, one-terminal use and the one-hour total budget. [Verification: PASS](2026-09-05_m08c_dxz_harvest/verification.json). Canonical bootstrap tests: **23 passed**. Both run receipts preserve the measured cost and exact release result. Outputs remain REVIEW for comparator and clock review; no spread-cost adoption is implied.
