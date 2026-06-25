# QM5_11564_connors-double7s-sma200-d1 - Strategy Spec

**EA ID:** QM5_11564
**Slug:** connors-double7s-sma200-d1
**Source:** 278c6e13-0726-5779-83fe-a38f5a2e480f (see `strategy-seeds/sources/278c6e13-0726-5779-83fe-a38f5a2e480f/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

This EA trades the Connors Double 7's pullback rule on D1 bars. A long entry is opened when the last closed daily close is above SMA(200) and is the lowest close of the last 7 closed daily bars. A symmetric short entry is opened when the last closed daily close is below SMA(200) and is the highest close of the last 7 closed daily bars. Long positions exit when the last closed daily close becomes the highest close of the last 7 bars; shorts exit when it becomes the lowest close of the last 7 bars. A 2 x ATR(14) safety stop is placed at entry, capped by a 150 pip maximum stop distance.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_period` | 200 | 50-300 | Daily SMA trend filter period. |
| `strategy_extreme_lookback` | 7 | 5-10 | Number of closed D1 bars used for the closing high/low entry and exit rule. |
| `strategy_atr_period` | 14 | 5-50 | ATR period for the P2 safety stop. |
| `strategy_sl_atr_mult` | 2.0 | 1.0-5.0 | ATR multiple used to place the safety stop. |
| `strategy_max_sl_pips` | 150 | 10-300 | Maximum allowed ATR stop distance in pips; wider signals are skipped. |
| `strategy_allow_short` | true | true/false | Enables the card's symmetric short side for the Forex adaptation. |
| `strategy_block_friday` | true | true/false | Blocks new entries on Friday while leaving exits and framework Friday close active. |
| `strategy_spread_cap_pips` | 15.0 | 0-50 | Blocks only genuinely wide positive spreads above this pip cap. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-approved D1 Forex port of the original liquid-market Double 7's concept.
- `GBPUSD.DWX` - card-approved D1 Forex port with deep DWX history and daily liquidity.
- `USDJPY.DWX` - card-approved D1 Forex port with deep DWX history and daily liquidity.

**Explicitly NOT for:**
- `SPY.DWX` - not an available DWX symbol; the card explicitly ports the strategy to Forex.
- `SPX500.DWX` - not an available canonical custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Typical hold time | days |
| Expected drawdown profile | Mean-reversion pullbacks can cluster during trend breaks; ATR stop bounds failed reversions. |
| Regime preference | Mean-revert inside a trend filter |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 278c6e13-0726-5779-83fe-a38f5a2e480f
**Source type:** book
**Pointer:** Larry Connors & Cesar Alvarez, "Short-Term Trading Strategies That Work" (TradingMarkets Publishing, 2009), Strategy 11; `artifacts/cards_approved/QM5_11564_connors-double7s-sma200-d1.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11564_connors-double7s-sma200-d1.md`

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
| v1 | 2026-06-25 | Initial build from card | 4f6310f7-4c9f-4017-8048-a0336f3e9317 |
