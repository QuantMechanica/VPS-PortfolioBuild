# QM5_41225_xng-medcal — Strategy Spec

Status: `G0 APPROVED; IMPLEMENTED; Q01 VALIDATION PENDING`

**EA ID:** QM5_41225
**Slug:** `xng-medcal`
**Source:** `KELOHARJU-RETSEAS-2016`
**Author of this spec:** Codex
**Last revised:** 2026-08-30

## 1. Strategy Logic

At the first normalized `XNGUSD.DWX` D1 broker-month transition into month
`(Y,M)`, the EA reconstructs the completed log return for calendar month `M`
in each exact year `Y-1..Y-10`. Missing years are skipped, five valid returns
are required, and no current-month price enters the signal.

The finite sample is sorted. An odd sample uses its center observation; an
even sample uses the arithmetic mean of its two center observations. A median
above `1e-12` buys XNG, one below `-1e-12` sells XNG, and the inclusive band is
flat. The month is durably consumed before history or entry gates. An accepted
position closes at the next normalized broker month, with a 35-day stale
repair and one frozen `3.5 * ATR(20,D1)` hard stop.

## 2. Parameters

| Parameter | Default | Locked range | Meaning |
|---|---:|---:|---|
| `strategy_lookback_years` | 10 | 10 | exact prior-year cap |
| `strategy_min_observations` | 5 | 5 | valid return floor |
| `strategy_history_bars_d1` | 3000 | 3000 | bounded completed-D1 scan |
| `strategy_signal_epsilon` | `1e-12` | `1e-12` | inclusive flat band |
| `strategy_atr_period_d1` | 20 | 20 | completed-bar stop range |
| `strategy_atr_sl_mult` | 3.5 | 3.5 | frozen stop multiple |
| `strategy_max_hold_days` | 35 | 35 | stale repair |
| `strategy_max_spread_points` | 3000 | 3000 | entry quote guard |

## 3. Symbol Universe

**Designed for:**

- `XNGUSD.DWX` only — registered continuous natural-gas CFD carrier used by
  the approved card and source translation.

**Explicitly not for:**

- `XTIUSD.DWX` — the WTI median carrier is already `QM5_41055_wti-medcal`.
- metals, indices, FX, or unregistered symbols — no parameter portability is
  authorized by this build.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe references | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` |
| Decision clock | first genuine normalized broker-month transition |

Native same-date D1 labels and one uniform `+1` calendar-day energy-label
offset are accepted. The same offset is applied to every historical endpoint.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Decisions / year / symbol | 12 maximum |
| Trades / year / symbol | approximately 5–12; Q02 must establish |
| Typical hold time | until next broker month, generally 28–31 days |
| Expected drawdown profile | episodic commodity gaps behind fixed-risk stops |
| Regime preference | persistent same-calendar natural-gas seasonality |
| Win rate target | not claimed before evidence |

The ordinary sample median is intentionally distinct from the existing XNG
arithmetic mean, Huber-location, Bernoulli sign-score, and daily cumulative
RSI2 candidates. Structural distinction is not a correlation claim; Q09 owns
that test.

## 6. Source Citation

**Source ID:** `KELOHARJU-RETSEAS-2016`
**Source type:** peer-reviewed paper / complete NBER working-paper packet
**Pointer:** `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`
**Source approval:** `decisions/2026-08-30_xng_median_same_calendar_source_approval.md`
**G0 decision:** `decisions/2026-08-30_qm5_41225_xng_median_same_calendar_g0.md`

Keloharju, Linnainmaa, and Nyberg (2016), *Return Seasonalities*, documents
same-calendar return effects and explicitly includes natural gas in its
commodity panel. The sample median, single-XNG CFD carrier, exact risk rules,
and operational lifecycle are disclosed QM translations; source performance
does not transfer.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02–Q10) | `RISK_FIXED` | `$1,000` per trade |
| Live burn-in | not authorized | none |
| Full live | not authorized | none |

The sole preset locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Friday close and both news axes are disabled. There is
no target, scale-in, retry, grid, martingale, pyramid, or live preset.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-30 | initial G0-approved build | compile pending |
