# M08 FTMO cost evidence pack — 2026-09-05

Task `0cb1153d-e55d-4912-b2f1-4092a37eed93`. Status: REVIEW, research only. Cost version SHA-256: `e45ebdcce4a68e81456c78228cd042770c59bb1ce84cf1527e8dba50bc7bad79`.

The shared `qm.ftmo-cost-version/v1` reader is wired into read-only inspection commands in the timebox evaluator, FTMO builder and lane runner. All three return identical pinned values. This is preparatory consumer wiring; economic calculations and governed admission have not adopted this version. The builder and lane runner retain different existing cost pins, recorded in `verification.json`. Consolidating those governed pins remains a separate review action.

Six FTMO exports contain 100,000 M1 bars each. Ten complete native harvests (six FTMO, two DXZ replicated on T1/T7) are frozen as deterministic gzip copies with raw and stored hashes. An incomplete NZDUSD attempt is explicitly excluded. The six FTMO series share **94,843 minute labels**, from **2026-05-29 14:57** through **2026-09-04 23:49**, using the recorded clock.

DXZ EURUSD ends 2026-04-06 and GBPUSD ends 2026-04-24, before FTMO begins. No DXZ harvest was located for USDCAD, NZDUSD, XAGUSD or XTIUSD in the inspected T1–T10 harvest roots. Matched FTMO/DXZ minutes are **zero for every symbol**; every spread delta stays null.

The harvester source (`framework/scripts/mt5_diagnostics/QM_M1_SpreadHarvest.mq5:61`) formats CopyRates timestamps with a literal Z without a visible offset conversion. Source-to-executed-binary attestation is absent. Quantiles below use descriptive recorded-clock bands; no UTC, London/New York session or DST certification is claimed. Spread values are native symbol points, not fills or slippage.

| Symbol | FTMO first label | DXZ last label | 00–06 p90 | 06–12 p90 | 12–18 p90 | 18–24 p90 |
|---|---|---|---:|---:|---:|---:|
| EURUSD | 2026-05-29T11:52:00Z | 2026-04-06T02:59:00Z | 1.0 | 0.0 | 0.0 | 1.0 |
| GBPUSD | 2026-05-29T14:57:00Z | 2026-04-24T23:54:00Z | 5.0 | 4.0 | 2.0 | 5.0 |
| USDCAD | 2026-05-29T10:01:00Z | unavailable | 7.0 | 6.0 | 5.0 | 6.0 |
| NZDUSD | 2026-05-29T10:31:00Z | unavailable | 7.0 | 6.0 | 6.0 | 6.0 |
| XAGUSD | 2026-05-26T10:12:00Z | unavailable | 71.0 | 66.0 | 63.0 | 65.0 |
| XTIUSD | 2026-05-26T03:16:00Z | unavailable | 82.0 | 88.0 | 88.0 | 88.0 |

Commission, swap, tick/contract units and Swing margin retain the dated 2026-09-05 provider snapshot with **provider-provisional** provenance. Session spread distributions are **measured**, with the clock limitation attached. Triple rollover weekday, lot minimum, lot step and fill slippage are **unknown/null**. The older Wednesday convention is not presented as a verified provider fact. All fields carry units and source bindings.

Before governed adoption: obtain overlapping same-symbol DXZ evidence; attest timestamp/DST and point conversion; bind exact native FTMO contracts, rollover, lot and margin terms; collect fill slippage separately; refresh variable provider terms and complete review. The OWNER-scheduled September 14 backfill can improve historical coverage but cannot prove FTMO fills or current native contract settings.

Verification: 67 focused tests pass, one existing environment-dependent test is skipped. Tests cover all three consumers, content-hash drift, unsupported adoption, duplicate symbols, missing provenance, unknown-value fabrication and numeric type checks. All ten frozen raw hashes were reproduced by decompression; direct CLI inspection parity passed. The first run also exposed the pre-existing difference between builder and lane cost pins, which remains visible instead of being overwritten.

Example read-only command:

```powershell
python C:/QM/repo/tools/strategy_farm/portfolio/ftmo_timebox_eval.py inspect-cost-version --cost-version "C:/QM/repo/docs/ops/evidence/2026-09-05_m08_ftmo_cost_pack/cost_version.json" --expected-sha256 e45ebdcce4a68e81456c78228cd042770c59bb1ce84cf1527e8dba50bc7bad79
```

No terminal, data export, backfill, purge, purchase, live setting, pipeline verdict or governed cost adoption was initiated. Artifacts and code remain on agents/board-advisor for REVIEW.
