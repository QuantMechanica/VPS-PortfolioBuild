# QM5_10440_mql5-ohlc-mtf - Strategy Spec

**EA ID:** QM5_10440
**Slug:** `mql5-ohlc-mtf`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-27

---

## 1. Strategy Logic

This EA trades H1 multi-timeframe structure breakouts. A long setup requires the previous H1 high and low to sit above the previous H4 structure, an M5 or M30 closed bar to break above the H4 high, and a retest of that high as support within the last three H1 bars. A short setup mirrors the rule below the H4 low, with the retest holding as resistance. Entries are stop orders offset by 0.1 x ATR(14,H1), expire after 240 minutes, and use a 2R take profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 1-200 | H1 ATR period used for entry offset and stop caps. |
| `strategy_entry_atr_offset_mult` | 0.10 | 0.01-1.00 | ATR multiple added above structure for buy stops or below structure for sell stops. |
| `strategy_stop_min_atr_mult` | 0.50 | 0.10-5.00 | Minimum allowed structural stop distance. |
| `strategy_stop_max_atr_mult` | 2.50 | 0.50-10.00 | Maximum allowed structural stop distance before capping. |
| `strategy_take_profit_r` | 2.00 | 0.50-10.00 | Take-profit multiple of initial stop distance. |
| `strategy_role_reversal_bars` | 3 | 1-20 | Number of recent H1 bars checked for role-reversal retest. |
| `strategy_pending_expiry_minutes` | 240 | 1-1440 | Pending stop order expiration time in minutes. |
| `strategy_day_blackout_minutes` | 30 | 0-720 | Minutes skipped after broker-day open and before broker-day close. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - card-listed metal; OHLC structure logic is portable to liquid gold CFD data.
- `EURUSD.DWX` - card-listed major FX pair with sufficient H1/M30/M5 history.
- `GBPUSD.DWX` - card-listed major FX pair with sufficient H1/M30/M5 history.
- `NDX.DWX` - card-listed liquid index CFD for the index portion of the P2 basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no broker or custom-symbol data is available for P2.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `M5`, `M30`, `H1`, `H4` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | Pending order expiry 240 minutes; filled trades typically intraday to multi-day via SL/TP. |
| Expected drawdown profile | Breakout losses cluster during false structure breaks and range-bound sessions. |
| Regime preference | Breakout / volatility expansion after multi-timeframe structural alignment. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/70796`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10440_mql5-ohlc-mtf.md`

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
| v1 | 2026-05-27 | Initial build from card | 2586ffdd-ee72-426c-87cc-9dd44340cf9c |
