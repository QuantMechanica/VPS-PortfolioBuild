# QM5_20011_xng-thu-tue - Strategy Spec

**EA ID:** QM5_20011
**Slug:** `xng-thu-tue`
**Source:** `MEEK-HOELSCHER-XNG-DOW-2023` (see `strategy-seeds/sources/MEEK-HOELSCHER-XNG-DOW-2023/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-19

## 1. Strategy Logic

The EA buys Natural Gas once per broker week at Friday D1 open, the executable
Darwinex proxy for the source's Thursday-close entry. It carries the position
through Friday, the weekend, Monday and Tuesday, then closes at Wednesday D1
open, the proxy for Tuesday close. Every entry has a frozen D1 ATR hard stop;
a seven-day stale guard handles missing-session or execution anomalies.

The rule is one source-explicit, persistent multi-day package. It is not the
certified `QM5_12567` conditional SMA200/cumulative-RSI2 pullback. Its Monday
and Tuesday return-window overlap with pending weekday prototypes is disclosed
and must be measured rather than assumed away.

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---|---|
| `strategy_entry_dow` | 5 | 5 | Friday D1-open proxy for Thursday close; Sunday is 0 |
| `strategy_exit_dow` | 3 | 3 | Wednesday D1-open proxy for Tuesday close |
| `strategy_atr_period` | 20 | 14, 20, 30 | Closed-D1 ATR period for the frozen hard stop |
| `strategy_atr_sl_mult` | 3.5 | 2.5, 3.5, 4.5 | ATR multiple for the initial stop |
| `strategy_max_hold_days` | 7 | 7 | Calendar-day stale guard |
| `strategy_max_spread_points` | 2500 | 1500, 2500, 3500 | Entry spread cap; zero modeled spread is valid |

Entry/exit weekdays, long direction, weekly cadence and weekend hold are
locked. Changing them creates another strategy rather than a parameter sweep.

## 3. Symbol Universe

**Designed for:**

- `XNGUSD.DWX` (slot 0) - registered Darwinex Natural Gas CFD proxy with D1
  history; the approved card is explicitly single-symbol.

**Explicitly not portable to:**

- `XTIUSD.DWX` - crude oil has different physical storage, seasonality and
  weekday evidence.
- indices, metals and FX - outside the source's Natural Gas result.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Entry cadence | new Friday D1 bar, at most once per framework weekly key |
| Exit cadence | Wednesday D1 open or the next tradable D1 bar |

The EA uses the framework D1 bar reader and weekly calendar-period key; it has
no W1 tester-bar dependency.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 48; one eligible package per broker week minus holidays/filters |
| Typical hold time | about five calendar days, capped at seven |
| Expected drawdown profile | high Natural Gas and weekend-gap risk, bounded per entry by fixed dollar risk and broker stop |
| Regime preference | persistence of the source's Monday/Tuesday Natural Gas weekday premia |

`expected_pf=1.01` and `expected_dd_pct=35` are conservative queue-ordering
priors, not source statistics or performance evidence.

## 6. Source Citation

**Source ID:** `MEEK-HOELSCHER-XNG-DOW-2023`
**Source type:** peer-reviewed open-access paper
**Pointer:** `strategy-seeds/sources/MEEK-HOELSCHER-XNG-DOW-2023/source.md`
**R1-R4 verdict (G0):** all PASS; see
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_20011_xng-thu-tue.md`.

Meek, A. C. and Hoelscher, S. A. (2023), "Day-of-the-week effect:
Petroleum and petroleum products", *Cogent Economics & Finance*, 11(1),
article 2213876, DOI `10.1080/23322039.2023.2213876`, Section 4 and Table 6.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02-Q10) | `RISK_FIXED` | $1,000 per trade (HR4) |
| Live burn-in (Q13) | `RISK_PERCENT` | Min-lot equivalent under an OWNER manifest |
| Full live (post-Q13 PASS) | `RISK_PERCENT` | Allocated by the later portfolio process |

ENV-to-mode validation is enforced by `QM_FrameworkInit`. This build creates
one RISK_FIXED backtest setfile and no live setfile. Friday close is explicitly
disabled by a fail-closed execution contract because the weekend hold is part
of the source rule. No T_Live, AutoTrading, deploy/T_Live manifest, portfolio
gate or portfolio-admission artifact is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-19 | Initial build from approved card | task `dfa80ef0-0aa0-4ab5-bb46-a95b59b32157` |
