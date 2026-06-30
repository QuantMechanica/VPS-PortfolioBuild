# Prop Challenge Simulator - FTMO 2-Step - 2026-06-28

Scope: implement a read-only simulator for prop-firm challenge survival using
existing Q08 portfolio trade streams. This does not touch `T_Live`.

> 2026-06-29 correction: prop challenge timing now uses full calendar daily
> series with missing days filled as zero PnL. Earlier active-trade-day-only
> sprint readings were too optimistic for low-frequency D1 sleeves.

## Preset

Implemented preset: `FTMO_2STEP`

- Phase 1 `challenge`: profit target `10%`, max daily loss `5%`, max loss
  `10%`, minimum trading days `4`.
- Phase 2 `verification`: profit target `5%`, max daily loss `5%`, max loss
  `10%`, minimum trading days `4`.
- Time zone recorded as `CE(S)T`.

Rule sources recorded in the JSON artifact:

- `https://ftmo.com/en/trading-objectives/`
- `https://ftmo.com/en/how-it-works/`

## Module

New module:

`tools/strategy_farm/portfolio/prop_challenge_sim.py`

It reads the same durable streams used by Q09:

`<common-dir>/QM/q08_trades/*.jsonl`

The simulator uses `Trade.net_of_cost`, so the existing worst-case
DXZ/FTMO-style commission model is applied through `portfolio_common.load_streams`.

## What It Measures

For a selected EA/book stream set, the artifact reports:

- observed chronological challenge result;
- daily PnL stats, including worst closed daily loss and best-day dependency;
- block-bootstrap Monte Carlo result;
- day-order-shuffle Monte Carlo result;
- FTMO 2-step pass probability;
- daily-loss breach probability;
- max-loss breach probability;
- target-not-reached probability;
- days-to-pass distribution for successful paths.

Important limitation: Q08 streams contain closed trade PnL, not intraday
floating drawdown. Daily-loss breach risk is therefore a lower-bound estimate.
Any deployment-quality FTMO workflow still needs an MT5/live-like intraday
equity guard.

## CLI

Example for the durable portfolio streams:

```powershell
python tools\strategy_farm\portfolio\prop_challenge_sim.py `
  --preset FTMO_2STEP `
  --common-dir D:\QM\reports\portfolio\sleeve_streams `
  --all-streams `
  --runs 1000 `
  --block-days 5 `
  --phase-horizon-days 60 `
  --risk-scale 0.75 `
  --out D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_2step_075.json
```

For a specific candidate/book:

```powershell
python tools\strategy_farm\portfolio\prop_challenge_sim.py `
  --preset FTMO_2STEP `
  --common-dir D:\QM\reports\portfolio\sleeve_streams `
  --keys 10430:NDX.DWX,10692:NDX.DWX `
  --weights 0.5,0.5 `
  --runs 1000 `
  --risk-scale 0.75
```

## Interpretation

Use this as a new `Q_PROP` style report, not as direct deployment approval.

Minimum useful read:

- high `pass_probability_pct`;
- low `daily_loss_breach_probability_pct`;
- low `max_loss_breach_probability_pct`;
- low best-day dependency;
- no single phase that only passes by extreme tail luck.

For FTMO 2-step specifically, a portfolio should be treated as not ready if it
only improves pass probability by taking daily-loss breach probability into a
material range. The first production use should be a risk-scale sweep, e.g.
`0.25 / 0.50 / 0.75 / 1.00`, before selecting any challenge configuration.

## Verification

Regression:

```powershell
python -m pytest tools\strategy_farm\tests\test_prop_challenge_sim.py `
  tools\strategy_farm\tests\test_portfolio_montecarlo.py `
  tools\strategy_farm\tests\test_portfolio_q08_contribution.py `
  tools\strategy_farm\tests\test_portfolio_admission.py -q
```

Result: `28 passed`.

## Smoke Run

Command executed against the current durable sleeve store:

```powershell
python tools\strategy_farm\portfolio\prop_challenge_sim.py `
  --preset FTMO_2STEP `
  --common-dir D:\QM\reports\portfolio\sleeve_streams `
  --all-streams `
  --runs 200 `
  --block-days 5 `
  --phase-horizon-days 60 `
  --risk-scale 0.75 `
  --out D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_2step_075_smoke.json
```

Result:

- loaded `29` streams over `2060` daily buckets;
- observed first phase did not reach the `10%` target within `60` days;
- block bootstrap pass probability `0.0%`;
- day-order-shuffle pass probability `0.0%`;
- daily-loss breach probability `0.0%`;
- max-loss breach probability `0.0%`.

Interpretation: the uncurated equal-weight all-stream book is too slow for a
60-day FTMO-style sprint at `risk_scale=0.75`, but it is not loss-limit fragile
in closed-PnL terms. The next useful run is a curated key set and risk-scale
sweep, not adding more random streams.
