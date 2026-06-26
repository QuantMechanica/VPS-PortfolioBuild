# QM5_11909_singh-good-morning-asia-usdjpy-d1 - Strategy Spec

**EA ID:** QM5_11909
**Slug:** `singh-good-morning-asia-usdjpy-d1`
**Source:** `b4d7e6c1-2f59-5a83-9d68-c5b4e2a8d7f3`
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

This EA trades Mario Singh's Good Morning Asia rule on USDJPY daily bars. At the first tick of a new D1 bar, it reads the just-closed D1 candle: a bullish candle triggers a long market entry and a bearish candle triggers a short market entry. The stop is the prior candle low for longs or high for shorts, widened to at least 30 pips when needed, and the take profit is 0.5 times the stop distance. Any position still open after one full D1 bar is closed by the time-stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_min_stop_pips` | 30.0 | 10.0-150.0 | Minimum stop distance in pips when the prior candle extreme is too close to entry. |
| `strategy_target_ratio` | 0.5 | 0.25-1.5 | Take-profit distance as a multiple of the stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `USDJPY.DWX` - the card is explicitly single-pair and maps directly to Darwinex USDJPY data.

**Explicitly NOT for:**
- Other `.DWX` symbols - the source rationale is specific to USDJPY and the Tokyo/Asian open context.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 100 |
| Typical hold time | one daily bar or less |
| Expected drawdown profile | high win-rate, negative reward-to-risk profile with frequent small wins and occasional larger losses |
| Regime preference | previous-day momentum continuation in liquid USDJPY conditions |
| Win rate target (qualitative) | high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b4d7e6c1-2f59-5a83-9d68-c5b4e2a8d7f3`
**Source type:** book
**Pointer:** Mario Singh, "17 Proven Currency Trading Strategies: How to Profit in the Forex Market" (John Wiley & Sons, 2013), Strategy 17 "Good Morning Asia", chapter 10 pp. 228-233.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11909_singh-good-morning-asia-usdjpy-d1.md`

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
| v1 | 2026-06-26 | Complete stale build metadata for Q02 re-enqueue | paced-fleet repair |
