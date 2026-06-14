# QM5_10775_tv-liq-ims - Strategy Spec

**EA ID:** QM5_10775
**Slug:** tv-liq-ims
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades local liquidity sweeps followed by an internal market shift on M15 bars. A long entry requires the last closed bar to touch or sweep the most recent confirmed local swing-low liquidity zone, then close above the most recent confirmed internal pivot high. A short entry requires the last closed bar to touch or sweep the most recent confirmed local swing-high liquidity zone, then close below the most recent confirmed internal pivot low. Stops are placed beyond the touched liquidity zone with an ATR buffer, and take profit is set at a fixed reward-to-risk multiple.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_liquidity_lookback | 5 | 1-20 | Left/right bars used to confirm local high/low liquidity pivots. |
| strategy_internal_lookback | 2 | 1-10 | Left/right bars used to confirm internal shift pivots. |
| strategy_structure_scan_bars | 80 | 10-300 | Maximum closed-bar history scanned for recent liquidity and internal pivots. |
| strategy_atr_period | 14 | 1-100 | ATR period used for the stop buffer. |
| strategy_atr_stop_buffer | 0.50 | 0.01-5.00 | ATR multiple added beyond the swept liquidity zone for stop placement. |
| strategy_rr_target | 2.00 | 0.25-10.00 | Fixed reward-to-risk take-profit multiple. |
| strategy_mode | 0 | 0-2 | Direction mode: 0 both, 1 bullish only, 2 bearish only. |
| strategy_session_start_hour | 7 | 0-23 | Broker-hour start of the London/New York trading window. |
| strategy_session_end_hour | 21 | 0-23 | Broker-hour end of the London/New York trading window. |
| strategy_max_spread_points | 500 | 0-10000 | Maximum allowed spread in points; 0 disables this strategy spread gate. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card R3 forex target with DWX OHLC coverage.
- GBPUSD.DWX - Card R3 forex target with DWX OHLC coverage.
- USDJPY.DWX - Card R3 forex target with DWX OHLC coverage.
- XAUUSD.DWX - Card R3 gold target normalized from XAUUSD to the canonical DWX symbol.
- GDAXI.DWX - Canonical DAX DWX symbol used for the card's GER40 exposure.
- NDX.DWX - Card R3 index target with DWX OHLC coverage.

**Explicitly NOT for:**
- GER40.DWX - Not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is the registered DAX equivalent.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 90 |
| Typical hold time | Intraday; card does not state a numeric hold time, exits are SL/TP driven. |
| Expected drawdown profile | Structure-breakout drawdown profile; losses cluster during false liquidity sweeps. |
| Regime preference | Liquidity sweep plus market-structure shift on active intraday sessions. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source script
**Pointer:** TradingView script `Liquidity + Internal Market Shift Strategy`, author handle `The_Forex_Steward`, published 2025-03-22, https://www.tradingview.com/script/vfcGHwNP-Liquidity-Internal-Market-Shift-Strategy/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10775_tv-liq-ims.md`

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
| v1 | 2026-06-14 | Initial build from card | 1d46be30-db1c-4977-ab73-75f0536204d9 |
