# Prop Challenge Sprint Optimizer - FTMO 2-Step - 2026-06-29

Scope: rank FTMO 2-step sprint candidates from existing Q08 durable streams.
This is read-only and does not touch `T_Live`.

> 2026-06-29 correction: the first optimizer version counted active trade days,
> not calendar days. That overstated low-frequency D1 sprint viability. The
> simulator and optimizer now fill missing calendar days with zero PnL. Treat
> the original rankings below as superseded by
> `docs/ops/PROP_CHALLENGE_MT5_VALIDATION_FTMO_2STEP_2026-06-29.md`.

## Module

New module:

`tools/strategy_farm/portfolio/prop_challenge_optimizer.py`

The optimizer reuses `prop_challenge_sim.py` and ranks:

- single streams;
- equal-weight combinations from a top-single pool;
- multiple risk scales.

Ranking uses:

- `robust_pass_probability_pct = min(block_bootstrap, day_order_shuffle)`;
- worst daily-loss breach probability across both simulation methods;
- worst max-loss breach probability across both simulation methods;
- phase-1 pass probability as a secondary speed signal;
- best-day dependency as a concentration warning.

The artifact also marks `sample_status`:

- `PASS`: candidate trade count >= `min_trade_count`;
- `LOW_SAMPLE`: candidate trade count below threshold.

## Q12-Ready Search

Command:

```powershell
python tools\strategy_farm\portfolio\prop_challenge_optimizer.py `
  --preset FTMO_2STEP `
  --common-dir D:\QM\reports\portfolio\sleeve_streams `
  --risk-scales 1,2,3,5,8,10,15,20 `
  --runs 300 `
  --block-days 5 `
  --phase-horizon-days 60 `
  --max-combo-size 3 `
  --top-single-pool 12 `
  --top-results 25 `
  --min-trade-count 50 `
  --out D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_2step_sprint_optimizer_q12ready_20260629.json
```

Result:

- basis `candidates` (`Q12_REVIEW_READY` only);
- streams `13`;
- combinations tested `286`;
- best raw result: `12567:XNGUSD + 12567:XAUUSD`, scale `10`,
  robust pass `100%`, but `sample_status=LOW_SAMPLE` with `48` trades.

## Best Candidates

| rank | candidate | trades | sample | scale | robust pass | daily breach | max-loss breach | worst closed day | note |
|---:|---|---:|---|---:|---:|---:|---:|---:|---|
| 1 | `12567:XNGUSD + 12567:XAUUSD` | 48 | `LOW_SAMPLE` | 10 | `100.0%` | `0.0%` | `0.0%` | `4.8000%` | strongest sprint, but just below 50-trade floor and close to daily-loss limit |
| 2 | `12567:XNGUSD` | 20 | `LOW_SAMPLE` | 15 | `100.0%` | `0.0%` | `0.0%` | `4.1874%` | very fast, too sample-thin as a standalone challenge plan |
| 3 | `12567:XAUUSD` | 28 | `LOW_SAMPLE` | 3 | `99.6667%` | `0.0%` | `0.0%` | `2.8800%` | good but sample-thin |
| 4 | `12567:XNGUSD + 12567:XAUUSD + 11132:SP500` | 91 | `PASS` | 8 | `98.6667%` | `0.0%` | `0.6667%` | `2.7142%` | best sample-ok Q12-ready sprint profile |
| 5 | `12567:XNGUSD + 12567:XAUUSD + 10513:XAUUSD` | 70 | `PASS` | 8 | `95.3333%` | `0.0%` | `3.6667%` | `2.6721%` | viable but more XAU concentration |
| 6 | `12567:XNGUSD + 11132:SP500` | 63 | `PASS` | 5 | `93.0%` | `0.0%` | `4.0%` | `2.5446%` | simpler sample-ok alternative |

## 2000-Run Confirmation

Confirmed top candidates with `runs=2000`:

| candidate | scale | block pass | shuffle pass | daily breach | max-loss breach | p50 days |
|---|---:|---:|---:|---:|---:|---:|
| `12567:XNGUSD + 12567:XAUUSD` | 10 | `100.0%` | `100.0%` | `0.0% / 0.0%` | `0.0% / 0.0%` | `14 / 14` |
| `12567:XNGUSD` | 15 | `100.0%` | `100.0%` | `0.0% / 0.0%` | `0.0% / 0.0%` | `8 / 8` |
| `12567:XNGUSD + 12567:XAUUSD + 11132:SP500` | 8 | `98.7%` | `99.75%` | `0.0% / 0.0%` | `0.25% / 0.25%` | `31 / 31` |
| `12567:XNGUSD + 12567:XAUUSD + 10513:XAUUSD` | 8 | `95.05%` | `96.45%` | `0.0% / 0.0%` | `3.65% / 3.55%` | `26 / 27` |
| `12567:XNGUSD + 11132:SP500` | 5 | `93.65%` | `99.3%` | `0.0% / 0.0%` | `2.4% / 0.7%` | `35 / 37` |

## Interpretation

There are successful FTMO-style sprint profiles in the current Q12-ready stream
set. The previous all-stream equal-weight book failed because it was too slow,
not because every EA was unusable.

Best practical read:

- For pure sprint speed, `12567:XNGUSD + 12567:XAUUSD` at scale `10` is the best
  closed-PnL profile, but it is `LOW_SAMPLE` and its worst closed day is close to
  FTMO's `5%` daily-loss boundary.
- For a more defensible starting candidate, prefer
  `12567:XNGUSD + 12567:XAUUSD + 11132:SP500` at scale `8`: it has `91` trades,
  lower worst-day pressure, and still confirms near `99%` pass probability in
  the current closed-PnL simulation.

## Caveats Before Any Challenge Use

- Q08 streams only contain closed trade PnL. Intraday floating drawdown is not
  measured here, so daily-loss breach probability is a lower-bound estimate.
- `risk_scale` is a PnL multiplier over the Q08 stream, not an already-approved
  live setfile risk value.
- FTMO deployment would need a hard intraday equity guard, no-new-trade daily
  cutoff, and a per-symbol exposure cap before any live challenge attempt.
- The optimizer is a research screen. It is not a deploy manifest.

## Verification

Regression:

```powershell
python -m pytest tools\strategy_farm\tests\test_prop_challenge_optimizer.py `
  tools\strategy_farm\tests\test_prop_challenge_sim.py `
  tools\strategy_farm\tests\test_portfolio_montecarlo.py `
  tools\strategy_farm\tests\test_portfolio_q08_contribution.py `
  tools\strategy_farm\tests\test_portfolio_admission.py -q
```

Current result: `33 passed`.
