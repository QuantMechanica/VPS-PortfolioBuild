# QM5_10502_mql5-breakout15 - Strategy Spec

**EA ID:** QM5_10502
**Slug:** mql5-breakout15
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA runs on M1 and reads a fast and slow SMA on the working timeframe, default M15. When fast SMA is above slow SMA during broker hours 07:00 through 15:59, it stores a buy trigger at Ask plus the breakout distance; if the setup remains valid and price reaches that trigger on a later M1 closed-bar evaluation, it opens long. When fast SMA is below slow SMA it mirrors the process with a sell trigger at Bid minus the breakout distance. Open long positions close on a bearish fast/slow SMA state, open short positions close on a bullish fast/slow SMA state, or via their fixed SL/TP and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_working_tf` | `PERIOD_M15` | MT5 timeframe enum | Timeframe used for the fast/slow SMA signal state. |
| `strategy_fast_ma_period` | `10` | `1+` | Fast SMA period on the working timeframe. |
| `strategy_slow_ma_period` | `80` | `1+` | Slow SMA period on the working timeframe. |
| `strategy_breakout_pips` | `10` | `1+` | Distance from current Ask/Bid used to arm the breakout trigger. |
| `strategy_start_hour` | `7` | `0-23` | First broker hour allowed for new entries. |
| `strategy_stop_hour` | `16` | `1-24` | Broker hour at and after which new entries are blocked. |
| `strategy_fixed_sl_pips` | `50` | `1+` | Fixed stop distance for FX symbols. |
| `strategy_fixed_tp_pips` | `50` | `1+` | Fixed take-profit distance for FX symbols. |
| `strategy_atr_period` | `14` | `1+` | ATR period used for non-FX fallback stop sizing. |
| `strategy_atr_mult` | `1.5` | `>0` | ATR multiplier for non-FX fallback stop sizing. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 primary FX basket member; direct DWX match.
- `GBPUSD.DWX` - Card R3 primary FX basket member; direct DWX match.
- `USDJPY.DWX` - Card R3 primary FX basket member; direct DWX match.
- `XAUUSD.DWX` - Card R3 metals member; direct DWX match with ATR fallback stop normalization.

**Explicitly NOT for:**
- Non-DWX or unavailable broker aliases - they are outside `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | `PERIOD_M15` fast/slow SMA state |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | Intraday to multi-hour; exit on opposite M15 SMA state or fixed SL/TP. |
| Expected drawdown profile | Fixed-risk breakout sleeve with one active position per symbol/magic. |
| Regime preference | Breakout / MA-state continuation during active session hours. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase strategy
**Pointer:** https://www.mql5.com/en/code/17057
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10502_mql5-breakout15.md`

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
| v1 | 2026-05-28 | Initial build from card | 8c2c85ab-4674-46fc-9fe6-784be37d5414 |
