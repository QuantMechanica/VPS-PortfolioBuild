# QM5_11385_mario-singh-good-morning-asia-usdjpy-d1 - Strategy Spec

**EA ID:** QM5_11385
**Slug:** `mario-singh-good-morning-asia-usdjpy-d1`
**Source:** `3c141158-8aca-5961-8e09-afd081ef32ee` (see approved card citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA trades USDJPY.DWX on D1 only. At the first tick of a new D1 candle, it reads the previous D1 candle: if the prior candle closed above its open, it opens a long; if the prior candle closed below its open, it opens a short. It skips doji candles where the previous candle body is less than 3 pips. The stop is the previous candle low for longs or high for shorts, bounded to a 30-pip minimum and 80-pip P2 cap, and the take-profit is 0.5 times the stop distance.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_min_sl_pips` | 30.0 | > 0 | Minimum stop distance in pips when previous D1 structure is too close. |
| `strategy_max_sl_pips` | 80.0 | >= `strategy_min_sl_pips` | P2 stop-distance cap for large D1 candles. |
| `strategy_tp_sl_ratio` | 0.50 | > 0 | Take-profit distance as a multiple of stop distance. |
| `strategy_doji_threshold_pips` | 3.0 | >= 0 | Skip prior candles with body smaller than this pip threshold. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `USDJPY.DWX` - the source strategy explicitly targets USD/JPY because of the US and Japan liquidity rationale, and the approved card R3 row names USDJPY.DWX only.

**Explicitly NOT for:**
- Other `.DWX` forex pairs - the approved card states USDJPY only; EURUSD and GBPUSD are mentioned only as possible later P3 sweeps, not as the P2 portable basket.
- Index, metal, and energy `.DWX` symbols - the source edge is a USD/JPY daily momentum rule, not a cross-asset rule.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `250` |
| Typical hold time | Until D1 SL or TP is reached; inferred as intraday to multi-day from the SL/TP-only card body |
| Expected drawdown profile | Fixed-risk daily momentum profile with small 0.5R winners and larger 1R losses; requires high win rate |
| Regime preference | Momentum-continuation / session-momentum |
| Win rate target (qualitative) | high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3c141158-8aca-5961-8e09-afd081ef32ee`
**Source type:** book
**Pointer:** Mario Singh, 17 Proven Currency Trading Strategies (Wiley, 2013), Strategy 17: Good Morning Asia, pp. 228-233; local card `D:\QM\strategy_farm\artifacts\cards_approved\QM5_11385_mario-singh-good-morning-asia-usdjpy-d1.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11385_mario-singh-good-morning-asia-usdjpy-d1.md`

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
| v1 | 2026-06-08 | Initial build from card | 7b241a9d-84db-4298-9e20-5e99b73b7fad |
