# QM5_9262_mql5-vidya-dual - Strategy Spec

**EA ID:** QM5_9262
**Slug:** `mql5-vidya-dual`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

The EA trades a dual VIDYA crossover on closed H1 bars. It calculates a fast VIDYA with CMO period 9 and EMA period 12, and a slow VIDYA with CMO period 20 and EMA period 50. A fast cross above slow opens a long; a fast cross below slow opens a short. Open positions close on the opposite crossover or after 96 H1 bars, with a 3-bar cooldown after exits.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | H1 expected | Timeframe used for VIDYA and ATR signals. |
| `strategy_fast_cmo_period` | `9` | 1-100 | CMO period for the fast VIDYA line. |
| `strategy_fast_ema_period` | `12` | 2-200 | EMA smoothing period for the fast VIDYA line. |
| `strategy_slow_cmo_period` | `20` | 1-200 | CMO period for the slow VIDYA line. |
| `strategy_slow_ema_period` | `50` | 2-300 | EMA smoothing period for the slow VIDYA line. |
| `strategy_atr_period` | `14` | 1-100 | ATR period used for the initial stop. |
| `strategy_atr_sl_mult` | `2.2` | 0.1-10.0 | ATR multiple for initial stop distance. |
| `strategy_take_profit_rr` | `2.4` | 0.1-20.0 | Initial take profit in R multiples. |
| `strategy_max_hold_bars` | `96` | 1-1000 | Failsafe time exit in H1 bars. |
| `strategy_cooldown_bars` | `3` | 0-100 | Closed-bar cooldown after an exit before re-entry. |
| `strategy_vidya_warmup_bars` | `180` | 80-1000 | Warmup history used to seed deterministic VIDYA calculation. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX pair with DWX OHLC and ATR data.
- `GBPJPY.DWX` - card-listed JPY cross with DWX OHLC and ATR data.
- `XAUUSD.DWX` - card-listed gold symbol with DWX OHLC and ATR data.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no DWX tester data guarantee.
- Non-H1 deployments - the card specifies closed H1 bars.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | `hours to 96 H1 bars` |
| Expected drawdown profile | Crossover whipsaws in sideways regimes; bounded by ATR stop and fixed 2.4R take profit. |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** MQL5 article
**Pointer:** `https://www.mql5.com/en/articles/11341`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9262_mql5-vidya-dual.md`

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
| v1 | 2026-06-26 | Initial build from card | cc643f82-6c1c-476a-8ec3-a4856e037272 |
