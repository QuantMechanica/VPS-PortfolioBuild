# QM5_11482_singh-m-good-morning-asia-d1 - Strategy Spec

**EA ID:** QM5_11482
**Slug:** singh-m-good-morning-asia-d1
**Source:** a655746e-8011-56d9-8d9b-0020a8a2ae89 (see `strategy-seeds/sources/a655746e-8011-56d9-8d9b-0020a8a2ae89/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-23

---

## 1. Strategy Logic

The EA trades USDJPY.DWX on D1 at the open of each new daily bar. If the prior completed D1 candle closed above its open, it opens a long; if the prior candle closed below its open, it opens a short; flat prior candles are skipped. The stop is based on the prior day's low for longs or high for shorts, with a 30-pip minimum and 80-pip cap, and the take profit is 0.5 times the stop distance. If neither stop nor target is hit within one D1 bar, the EA closes the position at the next D1 bar.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_tp_ratio` | 0.5 | > 0 | Take-profit distance as a multiple of stop distance. |
| `strategy_min_sl_pips` | 30.0 | > 0 | Minimum stop distance in pips. |
| `strategy_max_sl_pips` | 80.0 | >= minimum SL | Maximum stop distance in pips after clamping. |
| `strategy_skip_above_pips` | 160.0 | >= maximum SL | Skip setups whose raw prior-extreme stop distance exceeds this value. |
| `strategy_skip_doji` | true | true / false | Skip prior candles with no directional body. |
| `strategy_spread_cap_pips` | 25.0 | > 0 | Maximum live spread; zero modeled DWX spread is allowed. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `USDJPY.DWX` - Singh specifies USD/JPY exclusively because Japan is the first major Asian market and the strategy targets the Asian session continuation effect.

**Explicitly NOT for:**
- Other FX pairs - the card explicitly names USDJPY only and does not authorize basket expansion.
- Index and commodity symbols - the card's mechanism is tied to Asian FX session continuation, not index or commodity market opens.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 200 |
| Typical hold time | Up to one D1 bar |
| Expected drawdown profile | Frequent small fixed-risk losses from asymmetric 2:1 risk-to-reward; requires high win rate. |
| Regime preference | Session continuation / prior-candle momentum |
| Win rate target (qualitative) | high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** a655746e-8011-56d9-8d9b-0020a8a2ae89
**Source type:** book
**Pointer:** Mario Singh, 17 Proven Currency Trading Strategies, Strategy 17: Good Morning Asia, pp. 228-233.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11482_singh-m-good-morning-asia-d1.md`

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
| v1 | 2026-06-20 | Initial build from card | 4161751f-bca4-4150-b81b-2798277a0b0c |
| v2 | 2026-07-23 | OnTick framework-wiring fix: added `QM_FrameworkTrackOpenPositionMae()` as first statement (Q08 evidence), moved central news gate below `Strategy_ManageOpenPosition`/time-stop exit so it blocks new entries only (2026-07-02 audit rule). Strategy_ hook bodies unchanged. | 4161751f-bca4-4150-b81b-2798277a0b0c |
