# SP-E4 diagnosis of five formerly never-signaling DXZ EAs

Date: 2026-08-22 15:12 Europe/Berlin

Router task: `961deb63-f5ea-4f1f-a877-a5f9685846e3`

Scope: read-only diagnosis. No T_Live chart, set file, AutoTrading state, or binary was changed.

## Outcome

The 2026-08-19 inventory premise is now stale for one EA: QM5_10939 traded on 2026-08-21. Three EAs remain evidence-consistent with genuine sparse signals. QM5_13128 missed a deterministic scheduled event while initialized and is classified as a bug/venue-window incompatibility candidate.

| EA / live sleeve | Live evidence through 2026-08-21 | Historical Q10 cadence (2017-01-01..2025-12-31) | Classification |
|---|---|---:|---|
| QM5_10919 / XTIUSD H4 | 27 snapshots, 0 entries since 2026-07-05; healthy `INIT_OK`; no order reject/error event | 30 trades / 9 years | `GENUINE_SPARSE_NO_SIGNAL` |
| QM5_12567 / XAUUSD + XNGUSD D1 | 38/35 snapshots, 0 entries since 2026-06-28; both symbols repeatedly `INIT_OK`; no order reject/error event | 73 XAU + 58 XNG / 9 years | `GENUINE_SPARSE_NO_SIGNAL` |
| QM5_12989 / XAUUSD H4 | 33 snapshots, 0 entries since 2026-07-05; healthy `INIT_OK`; no order reject/error event | 51 trades / 9 years | `GENUINE_SPARSE_NO_SIGNAL` |
| QM5_13128 / NDX H1 | 28 snapshots, 0 entries since 2026-07-13; initialized before the 2026-07-29 event; no entry/order attempt | 57 trades / 9 years | `BUG_SUSPECTED_EXACT_HOUR_VENUE_WINDOW` |
| QM5_10939 / GBPUSD H4 | `ENTRY_ACCEPTED` ticket 3174097046 at 2026-08-21 12:00 broker, then governed Friday close at 21:00 | 92 trades / 9 years | `STALE_PREMISE_GENUINE_SPARSE_SIGNAL_CONFIRMED` |

## Evidence paths and bindings

Live logs:

| EA | Path | SHA-256 at observation |
|---|---|---|
| 10919 | `C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/QM5_10919_ea-10919.log` | `AF5BD7E4B751612E621BB31CD09005FC779BAA801E41C60F83F3795E54B90FE9` |
| 12567 | `C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/QM5_12567_ea-12567.log` | `A4B90B9201B2DEABC281E984F0BECB58A935A1470C3D47096983FF0BBE53B85F` |
| 12989 | `C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/QM5_12989_ea-12989.log` | `9E7E345B5280FFEAB6B9C55FD0D29587C3578DA2D9FE9690B95C67B7421F2335` |
| 13128 | `C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/QM5_13128_ea-13128.log` | `6CA3F2EF2F1008928865D2E2C10E30D426C77C6B6E49621BC8C6325A36C4165D` |
| 10939 | `C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/QM5_10939_ea-10939.log` | `62E503B6BD8319758E72EE5092D27DE94ADE8A1AE327F73813D92A49A304F453` |

Q10 aggregates:

- `D:/QM/reports/pipeline/QM5_10919/Q10/XTIUSD_DWX/aggregate.json`
- `D:/QM/reports/pipeline/QM5_12567/Q10/{XAUUSD_DWX,XNGUSD_DWX}/aggregate.json`
- `D:/QM/reports/pipeline/QM5_12989/Q10/XAUUSD_DWX/aggregate.json`
- `D:/QM/reports/pipeline/QM5_13128/Q10/NDX_DWX/aggregate.json`
- `D:/QM/reports/pipeline/QM5_10939/Q10/GBPUSD_DWX/aggregate.json`

The T_Live log and baseline trade counts agree exactly with the Q10 trade counts for all six sleeves. That is positive identity evidence: the telemetry is loading the expected per-EA/per-symbol baseline rather than a foreign sleeve.

## Per-EA reasoning

### QM5_10919

The strategy requires a mature 30-bar EMA50 slope, a 20-bar extreme, at least 2 ATR acceleration/channel overshoot, a 1.5 ATR exhaustion range, weak close, and a subsequent trigger inside three H4 bars. Thirty trades over nine years is about 3.3/year. A roughly seven-week wait without a qualifying overshoot is compatible with the backtest cadence. The log has no entry rejection or failed initialization. No set correction is supported.

### QM5_12567

This is a D1 cumulative RSI(2) mean-reversion entry above SMA200 with two-day cumulative RSI below 35. The two live sleeves produced 73 and 58 trades over nine years (about 8.1 and 6.4/year). Both symbols load their exact baseline hashes and remain initialized. There is no order attempt or rejection. The current wait is unusual enough to monitor, but not evidence of an unreachable path. No set correction is supported.

### QM5_12989

The nested-pullback construction combines D1 EMA trend, a 24-bar impulse, a 12-bar retracement constrained to 25–55%, a 3–8 H4 pause, ATR-percentile floor, stop cap, and spread/stop cap. Fifty-one trades over nine years is about 5.7/year. The attached interval without an entry is compatible with this intentionally extreme filter stack and has no runtime error/reject evidence. No set correction is supported.

### QM5_13128

The strategy calendar explicitly contains `20260729`. Its entry rule is exact: on a new H1 bar whose broker hour equals `strategy_entry_hour=21`, enter when tomorrow is the event date. The EA was initialized on 2026-07-27 and remained live across 2026-07-28/29, but its log contains no entry or order attempt. This is not an unscheduled quiet period: a deterministic opportunity passed.

The leading explanation is a transport mismatch between the custom `NDX.DWX` backtest bar schedule and live `NDX`: an exact-hour predicate silently misses if no new bar/tick is delivered at broker hour 21. The log proves the missed event and excludes init failure; it does not independently prove which live H1 hours exist. Therefore the defect is real at the strategy/venue boundary, while the precise correction hour must be measured before use.

The probe-only set delta is stored in `docs/ops/evidence/2026-08-22_sp_e4_qm5_13128_set_correction_probe.template.set`. It is deliberately non-deployable and contains no risk setting. A DEV/T1–T5 governed replay must determine the last tradable pre-event H1 hour and preserve the intended flat-before-statement exit before any OWNER-signed live change.

The next listed FOMC date is 2026-09-16, so leaving the exact-hour defect unresolved would create another deterministic miss.

### QM5_10939

This EA is no longer a no-signal case. At broker time 2026-08-21 12:00 it emitted `ENTRY_ACCEPTED` for GBPUSD, magic 109390001, 0.36 lots, and `TM_OPEN`; it closed through the framework Friday close at 21:00. The prior zero count was a stale snapshot of a sparse strategy, not an implementation defect. No correction is supported.

## Verification

Each live log was parsed line-by-line as JSON (zero parse failures), grouped by symbol/event, and compared with its bound Q10 aggregate and baseline `n`. Source predicates were inspected in the five canonical `.mq5` files. No pipeline verdict was created or inferred; existing Q10 rows are cited only as historical cadence evidence.

## Operator disposition

- Keep 10919, 12567, and 12989 classified as sparse/monitoring candidates; do not loosen filters from this evidence.
- Remove 10939 from the never-signaling list.
- Treat 13128 as a separate development/requalification item. Do not apply the probe template to T_Live; live correction requires validated schedule evidence and a separate OWNER/RED action.

