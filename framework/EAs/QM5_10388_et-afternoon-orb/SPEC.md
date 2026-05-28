# QM5_10388_et-afternoon-orb - Strategy Spec

**EA ID:** QM5_10388
**Slug:** et-afternoon-orb
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA builds an opening range from the first 210 minutes of the regular broker-session window. After that range is complete, it places a buy stop one tick above the range high and a sell stop one tick below the range low, provided no trade has already occurred for the symbol that day. The stop for a long is the range low minus 0.6 times the opening range; the stop for a short is the range high plus 0.6 times the opening range, with the V5 minimum distance of at least four spreads. Any open position is closed at the mapped 22:00 broker close, and the opposite pending order is cancelled after one side fills.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_session_start_hhmm` | 1530 | 0000-2359 | Broker-time start of the regular session used to build the opening range. |
| `strategy_range_minutes` | 210 | 1-1440 | Number of minutes included in the opening range. |
| `strategy_stop_factor` | 0.60 | 0.10-2.00 | Fraction of the opening range added beyond the opposite side for stop placement. |
| `strategy_trigger_ticks` | 1 | 1-10 | Tick offset beyond the range high or low for stop entries. |
| `strategy_min_range_spreads` | 6.0 | 0.0-50.0 | Minimum opening range width expressed as a multiple of current spread. |
| `strategy_close_hhmm` | 2200 | 0000-2359 | Broker-time close used for pending-order cancellation and position exit. |
| `strategy_allow_monday` | true | true/false | Allows Monday entries. |
| `strategy_allow_tuesday` | true | true/false | Allows Tuesday entries. |
| `strategy_allow_wednesday` | true | true/false | Allows Wednesday entries. |
| `strategy_allow_thursday` | true | true/false | Allows Thursday entries. |
| `strategy_allow_friday` | true | true/false | Allows Friday entries. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 index exposure, matching the source index-futures ORB concept; backtest-only per DWX symbol discipline.
- `NDX.DWX` - Nasdaq 100 index CFD analog for US large-cap index breakout behaviour.
- `WS30.DWX` - Dow 30 index CFD analog for US large-cap index breakout behaviour.
- `GDAXI.DWX` - DAX 40 index analog, used as the available DWX DAX equivalent for card-stated `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; ported to `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable or non-canonical S&P 500 variants.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 110 |
| Typical hold time | Intraday, from afternoon breakout fill to 22:00 broker close or stop. |
| Expected drawdown profile | Volatility-sensitive one-trade-per-day index breakout drawdown. |
| Regime preference | breakout / volatility-expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** mechtrader41, Example Trading System page 43, Elite Trader, 2006-03-22, https://www.elitetrader.com/et/threads/example-trading-system.44092/page-43
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10388_et-afternoon-orb.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-25 | Initial build from card | c2c55981-e716-4898-bac5-b89db3da6501 |
