# QM5_10808_tv-tqqq-ema - Strategy Spec

**EA ID:** QM5_10808
**Slug:** `tv-tqqq-ema`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see TradingView source citation in approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

This EA trades long only when the fast EMA(20) crosses above the slow EMA(50) on the last closed bar and ADX(14) is at least 20. It opens one market buy position per symbol and magic slot, with an initial stop one ATR(14) below entry and a target three ATR(14) above entry. Once the open profit reaches 1R, the stop moves to breakeven; once open profit reaches 2R, the stop moves to +1R. There is no separate discretionary close signal beyond SL, TP, stepped stop management, and the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_ema` | 20 | 10-30 | Fast EMA period for the bullish crossover trigger. |
| `strategy_slow_ema` | 50 | 50-100 | Slow EMA period for the bullish crossover trigger. |
| `strategy_adx_period` | 14 | 14 | ADX/DMI period from the card. |
| `strategy_adx_threshold` | 20.0 | 15.0-25.0 | Minimum ADX value required for entry. |
| `strategy_atr_period` | 14 | 14 | ATR period used for CFD stop and target normalization. |
| `strategy_atr_sl_mult` | 1.0 | 1.0-1.5 | Initial stop distance in ATR units. |
| `strategy_atr_tp_mult` | 3.0 | 2.0-4.0 | Initial target distance in ATR units. |
| `strategy_be_trigger_r` | 1.0 | 1.0 | Profit in R at which the stop moves to breakeven. |
| `strategy_step_trigger_r` | 2.0 | 2.0 | Profit in R at which the stop moves to a locked-profit level. |
| `strategy_step_lock_r` | 1.0 | 1.0 | Profit in R locked by the second stepped stop move. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - closest DWX large-cap Nasdaq proxy for the original TQQQ trend concept.
- `WS30.DWX` - liquid US index CFD included in the card's portable P2 basket.
- `GDAXI.DWX` - DWX matrix DAX equivalent used because the card's `GER40.DWX` is not present.
- `EURUSD.DWX` - FX trend symbol explicitly listed in the card's R3 basket.
- `GBPUSD.DWX` - FX trend symbol explicitly listed in the card's R3 basket.
- `XAUUSD.DWX` - metals trend symbol listed by the card as `XAUUSD`, normalized to the DWX suffix.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - they are unavailable for DWX backtest registration.
- `GER40.DWX` - not present in the DWX matrix; `GDAXI.DWX` is the registered DAX equivalent.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` for this build; card also lists `D1` for parameter testing |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 30 |
| Typical hold time | hours to days |
| Expected drawdown profile | trend-strategy drawdowns during non-trending or whipsaw periods |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** `https://www.tradingview.com/script/yhKXgYZE-TQQQ-EMA-Strategy/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10808_tv-tqqq-ema.md`

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
| v1 | 2026-06-05 | Initial build from card | 9d8674a9-788a-409e-95fb-e6f5bf44151f |
