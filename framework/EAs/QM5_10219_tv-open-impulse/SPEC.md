# QM5_10219_tv-open-impulse - Strategy Spec

**EA ID:** QM5_10219
**Slug:** `tv-open-impulse`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This EA trades one M5 candle at the configured market-open timestamp. The closed impulse candle qualifies when its high-low range is greater than `strategy_impulse_atr_mult` times ATR, using the configured ATR period. It enters long when that candle closes above both its midpoint and its open, enters short when it closes below both, places the stop at the opposite candle extreme, and sets the target at `strategy_rr_target` times the stop distance. There is no discretionary exit or baseline breakeven; exits are by the initial SL/TP and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_open_hhmm` | 1630 | 0000-2359 | Broker-time HHMM for the single market-open impulse candle. |
| `strategy_atr_period` | 14 | >= 1 | ATR period used to judge whether the open candle is impulsive. |
| `strategy_impulse_atr_mult` | 1.5 | > 0 | Minimum candle range as a multiple of ATR. |
| `strategy_rr_target` | 3.0 | > 0 | Reward-to-risk multiple for the fixed target. |
| `strategy_max_spread_points` | 120 | >= 0 | Maximum spread allowed for new entries; 0 disables this guard. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 market-open volatility target from the card.
- `WS30.DWX` - Dow 30 market-open volatility target from the card.
- `GDAXI.DWX` - available DWX DAX symbol used in place of card-stated `GER40.DWX`.
- `SP500.DWX` - S&P 500 market-open analog; valid for backtest, not T6 live routing.
- `XAUUSD.DWX` - volatility cross-check target from the card.

**Explicitly NOT for:**
- Any symbol not registered above in `magic_numbers.csv`.
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework `OnTick` gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | Intraday bracket trade; exits when 3R target or candle-extreme stop is hit. |
| Expected drawdown profile | Fixed $1,000 risk per baseline trade; one position per magic number. |
| Regime preference | Volatility-expansion / momentum-breakout at the market open. |
| Win rate target (qualitative) | Medium, with payoff driven by the 3R target. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script
**Pointer:** TradingView script `Market Open Impulse [LuciTech]`, author `TradesLuci`, https://www.tradingview.com/script/5VVg9PqU-Market-Open-Impulse-LuciTech/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10219_tv-open-impulse.md`

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
| v1 | 2026-06-09 | Initial build from card | 64acdbcb-c371-4d33-80b7-c46daecc0f51 |
