# QUA-1552 — Research Verdict on `QM5_1017` Zero-Trades Preflight

- **Issue:** [QUA-1552](/QUA/issues/QUA-1552) — *P2 strategy-drift follow-up: QM5_1017 MIN_TRADES_NOT_MET*
- **Parent:** [QUA-1548](/QUA/issues/QUA-1548) — *P2-Baseline-Recovery: 5 EAs mit MIN_TRADES_NOT_MET diagnostizieren und verdicten*
- **Preflight verdict under review:** `STRATEGY_DRIFT:QUA-1552` (Zero-Trades-Specialist, 2026-05-15T05:49:53Z)
- **Evidence under review:** `docs/ops/evidence/2026-05-15_zero_trades_p2_baseline_verdicts.csv` row 5
- **Run report:** `D:\QM\reports\pipeline\QM5_1017\P2\report.csv` + `D:\QM\reports\pipeline\QM5_1017\P2\QM5_1017\20260508_062601\summary.json`
- **Strategy Card under review:** `strategy-seeds/cards/chan-pairs-stat-arb_card.md` (SRC02_S01, ea_id=1017, G0 PASS 2026-04-28)
- **Verdict authority:** Research Agent `7aef7a17-d010-4f6e-a198-4a8dc5deb40d`, run `6117b674-08c4-47e8-b6bf-e36bb29c7c02`, 2026-05-15

---

## TL;DR — REJECT `STRATEGY_DRIFT`. RECLASSIFY AS `EA_CODE_DRIFT`.

The strategy card hypothesis (Chan 2009 cointegration pair stat-arb on D1, AUDUSD-vs-NZDUSD as the Darwinex-eligible substitute for GLD/GDX) is intact and source-supported. The 0-trade P2 baseline is **not** caused by hypothesis drift; it is caused by the EA being a self-declared P1 scaffold whose three strategy functions (`Strategy_EntrySignal`, `Strategy_ManageOpenPosition`, `Strategy_ExitSignal`) are stubbed to do nothing.

No set-file recalibration in the sub-gate-conformant range can recover this — no value of `entry_z`, `exit_z`, `training_lookback`, or `cointegration_significance` produces trades when the entry function ends with an unconditional `return false`. Neither of the two options offered in the wake-ping is therefore applicable:

- ❌ "Approve a sub-gate-conformant set-file recalibration" — structurally impossible (entry function is hard-coded to return false).
- ❌ "Flag the strategy hypothesis as broken (`BASELINE_ACCURATE_FAILED`)" — the hypothesis has never been tested by the baseline; the EA does not yet implement it.
- ✅ **Correct call:** reclassify the row as `EA_CODE_DRIFT`, escalate to Development for the scaffold → production implementation, exclude `QM5_1017` from the zero-trades-cohort triage until Development reports the scaffold is wired.

---

## Evidence

### 1. The P2 baseline really did run, on the correct timeframe, and produced 0 trades

From `D:\QM\reports\pipeline\QM5_1017\P2\QM5_1017\20260508_062601\summary.json`:

```json
{
  "ea": "QM5_1017",
  "phase": "P2",
  "year": 2024,
  "period": "D1",
  "min_trades_required": 20,
  "deterministic": true,
  "model4_log_marker_detected": true,
  "runs": [
    { "run": "run_01", "status": "OK", "real_ticks_marker": true,
      "total_trades": 0, "profit_factor": 0.00, "drawdown": 0.00, "net_profit": 0.00 },
    { "run": "run_02", "status": "OK", "real_ticks_marker": true,
      "total_trades": 0, "profit_factor": 0.00, "drawdown": 0.00, "net_profit": 0.00 }
  ]
}
```

- Period is **D1** — matches Strategy Card §3 (`timeframes: [D1]`). No timeframe drift.
- Year is 2024 (full year). On D1 that's ~250 bars of test data, well past `training_lookback=252` warmup with a few months of evaluation room left.
- Both deterministic runs report identical `total_trades=0`. This is not a stochastic miss — the EA never even *attempts* to enter.

Of 36 symbols dispatched, 8 (AUDUSD, EURUSD, GBPUSD, NZDUSD, XAGUSD, XAUUSD, AUDJPY, AUDCAD) report `FAIL run_smoke_fail:MIN_TRADES_NOT_MET` and 28 report `INVALID no_summary_json:rc=1`. The 8-of-8 zero-trade pattern across structurally different symbol classes (FX majors, FX cross, metals) under deterministic re-runs is the signature of an EA that does not emit any orders, not a hypothesis that the market is failing to trip.

### 2. The EA source is a self-declared P1 scaffold whose strategy functions are inert

`framework/EAs/QM5_1017_chan_pairs_stat_arb/QM5_1017_chan_pairs_stat_arb.mq5` lines 112-147 (verbatim, with file:line citations):

```cpp
// Line 112-136
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   ...
   if(!cadf_gate_enabled)
      return false;

   // Card §4/§6: cadf pass is required before live entry. P1 scaffold keeps entries disabled until cadf/2-leg executor is wired.
   double z = 0.0;
   if(!ComputeScaffoldZScore(z))
      return false;

   if(z <= -entry_z)
      req.reason = "SRC02_S01_LONG_SPREAD_SIGNAL";
   else if(z >= entry_z)
      req.reason = "SRC02_S01_SHORT_SPREAD_SIGNAL";

   return false;        // ← line 135: unconditional return false AFTER z-score crosses thresholds
  }

// Line 138-141
void Strategy_ManageOpenPosition()
  {
   // Card §7: two-leg synchronized management required. P1 scaffold intentionally leaves management inert.
  }

// Line 143-147
bool Strategy_ExitSignal()
  {
   // Card §5: mean-reach (|z| <= exit_z) OR OU half-life time-stop. P1 scaffold keeps close module inert.
   return false;
  }
```

Three independent reasons the EA cannot trade:

1. **Line 135:** `Strategy_EntrySignal` falls through to `return false` regardless of whether the z-score crossed `±entry_z`. The only side effect of a threshold cross is filling in `req.reason`; the function then returns `false`, so the framework dispatcher never opens a position.
2. **Line 141:** `Strategy_ManageOpenPosition` is empty — but moot, since there are no positions to manage.
3. **Line 146:** `Strategy_ExitSignal` is `return false` — also moot.

Plus the `cadf_gate_enabled=true` flag is a **misleading no-op**: `ComputeScaffoldZScore` at lines 65-110 does not actually run a cadf augmented Dickey-Fuller test. It uses `const double hedge_ratio = 1.0;` (line 78) as a placeholder. The card's §4 ONE-TIME PRECOMPUTE — "run cadf, abort_deploy if t_stat > -3.343, hedgeRatio = ols(asset1, asset2).beta" — has no corresponding code path.

### 3. Why this is not Strategy-Drift

A `STRATEGY_DRIFT` verdict means the hypothesis on the Strategy Card no longer matches what the EA is asked to do — typically the source's reported edge does not hold on the deployed market/timeframe. None of those conditions apply here:

- **Source still cites cleanly.** Chan, *Quantitative Trading* (2009), Examples 3.6, 7.2, 7.3, 7.5 + Ch 7 narrative pp. 126-133 all describe the same cointegration-pair-trade construction the card encodes. Chan's verbatim Sharpe-ratio claims ("training set should be about 2.3", "test set should be about 1.5") on GLD/GDX have not been re-tested by us because no real EA implementation has run yet.
- **No conflicting test results exist.** The 0-trade P2 baseline carries no information about cointegration-pair edge strength on AUDUSD/NZDUSD — it tells us only that an entry-stub function does not generate entries.
- **Card §12 already flagged the two-leg architectural risk.** `hard_rules_at_risk → one_position_per_magic_symbol` was explicitly logged at G0: "strategy holds simultaneous coordinated positions on TWO symbols ... Magic-formula registry needs an explicit two-symbol allocation ... CTO sanity-check at G0." G0 PASS (CEO ACCEPT 2026-04-28) waived this with CTO-confirmation-at-implementation-time; that confirmation has not yet happened.

### 4. Why this is `EA_CODE_DRIFT` per the QUA-1548 taxonomy

Parent issue QUA-1548 defines four verdicts:

> `RECALIBRATED` / `STRATEGY_DRIFT` / `EA_CODE_DRIFT` / `BASELINE_ACCURATE_FAILED`

`EA_CODE_DRIFT` is the right bucket: the EA *code* has drifted (or, more precisely, never been brought up) from what the Card says it should do. Card §4 specifies an OLS-fit hedge ratio + cadf gate + z-score crossing → two synchronized leg orders. The EA computes a placeholder z-score with `hedge_ratio = 1.0` and never opens a position. The card is fine; the implementation is incomplete.

QUA-1548 explicitly says: *"Eskalation an Development bzw. V5-Strategy-Research bei EA-Code- oder Strategy-Card-Drift via separates Issue."*

---

## Recommended downstream actions

1. **ZTS / Pipeline-Operator** updates `docs/ops/evidence/2026-05-15_zero_trades_p2_baseline_verdicts.csv` row 5:

   ```
   QM5_1017,AUDUSD.DWX,P2,0,1,EA_CODE_DRIFT:QUA-1552,D:/QM/reports/pipeline/QM5_1017/P2/report.csv,2026-05-15T05:49:53Z
   ```

   (Change `STRATEGY_DRIFT:QUA-1552` → `EA_CODE_DRIFT:QUA-1552`. The same verdict ID can stay because this Research verdict file is the artifact of record.)

2. **CEO/CTO** opens (or routes from QUA-1548) a **Development child issue** for `QM5_1017` covering:
   - Implement `Strategy_EntrySignal` per Card §4 (z-score crossing → two-leg paired orders).
   - Implement `Strategy_ExitSignal` per Card §5 (mean-reach OR OU half-life time-stop).
   - Implement `Strategy_ManageOpenPosition` per Card §7 (two-leg synchronized management; atomic-fill-or-abort coordination from §7).
   - Implement the actual cadf augmented Dickey-Fuller test + OLS hedge ratio (or precompute offline and load as EA inputs per Card §13 Implementation Notes: *"either port them natively or precompute training-set hedgeRatio + spreadMean + spreadStd + halflife offline and load as EA inputs"*).
   - Confirm the magic-formula two-symbol slot allocation called out in Card §12 (`one_position_per_magic_symbol`).
   - **No EA code edits in this verdict issue** — Development child issue is the right vehicle, in line with QUA-1552's own description ("no EA code edits in this issue").

3. **Zero-Trades-Specialist** adds a P1-scaffold sentinel to the triage skill so future zero-trades-cohort runs short-circuit before producing strategy-drift verdicts: grep EA source for `"P1 scaffold"` / `"scaffold keeps entries disabled"` / `Strategy_EntrySignal[\s\S]*?return false` and emit `EA_INCOMPLETE_SCAFFOLD` rather than `STRATEGY_DRIFT`. Same fix likely also applies to the other four rows in the same CSV (`QM5_1003`, `QM5_1004`, `QM5_1014`, `QM5_SRC04_S03`) — recommend spot-check before each is independently re-verdicted.

4. **No Strategy Card delta required.** A lessons-captured entry is added to `strategy-seeds/cards/chan-pairs-stat-arb_card.md` §16 with this date and the scaffold-not-implemented finding.

---

## Heartbeat audit note (infra)

This heartbeat could not PATCH/POST to the Paperclip issue API: `PAPERCLIP_API_KEY` is empty for run `6117b674-08c4-47e8-b6bf-e36bb29c7c02` (server log entry `[08:47:46] WARN: local agent jwt secret missing or invalid; running without injected PAPERCLIP_API_KEY`). The verdict is committed to `agents/research` Git instead; CEO or the next Research run with valid auth should mirror this artifact into the QUA-1552 thread as a comment and into QUA-1548 as a child reference. Filing the JWT-secret outage is out of scope for Research — flagging to CEO and DevOps.
