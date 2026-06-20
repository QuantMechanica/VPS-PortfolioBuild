# QM5_11838_robo-two-pairs-ema-macd-h4 - Strategy Spec

**EA ID:** QM5_11838
**Slug:** `robo-two-pairs-ema-macd-h4`
**Source:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d` (see `sources/362359657-robo-forex-strategy`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades the H4 close when four EMAs are fully stacked in one direction and MACD confirms the same direction. A long signal requires EMA(5) > EMA(15) > EMA(50) > EMA(100), plus MACD main above zero or crossing above its signal line. A short signal requires the inverse EMA stack, plus MACD main below zero or crossing below its signal line. New trades use a 2 x ATR(14) stop and 4 x ATR(14) take profit; open positions close early when EMA(5) crosses back through EMA(15) against the trade.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_fast` | 5 | integer > 0 | Fast EMA used for entry stack and reversal exit. |
| `strategy_ema_mid` | 15 | integer > 0 | Mid EMA used for entry stack and reversal exit. |
| `strategy_ema_anchor_fast` | 50 | integer > 0 | Faster anchor EMA in the trend cascade. |
| `strategy_ema_anchor_slow` | 100 | integer > 0 | Slower anchor EMA in the trend cascade. |
| `strategy_macd_fast` | 12 | integer > 0 | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | integer greater than fast | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | integer > 0 | MACD signal line period. |
| `strategy_atr_period` | 14 | integer > 0 | ATR period for initial stop and take profit distances. |
| `strategy_atr_sl_mult` | 2.0 | double > 0 | Stop loss distance as ATR multiple. |
| `strategy_atr_tp_mult` | 4.0 | double > 0 | Take profit distance as ATR multiple. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Primary RoboForex source pair and present in the DWX symbol matrix.
- `GBPUSD.DWX` - Primary RoboForex source pair and present in the DWX symbol matrix.

**Explicitly NOT for:**
- Non-FX-index or commodity `.DWX` symbols - The source strategy is stated for two forex pairs, not a broad cross-asset basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Expected trade frequency | Not specified in card frontmatter; inferred as moderate H4 trend-following cadence. |
| Typical hold time | Not specified in card frontmatter; expected to be hours to several days from H4 ATR exits. |
| Expected drawdown profile | Not specified in card frontmatter; trend-following systems can cluster losses in sideways regimes. |
| Regime preference | Trend-following, aligned EMA cascade. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d`
**Source type:** educational PDF strategy collection
**Pointer:** RoboForex Educational Team, `Forex Strategy Collection`, strategy `Two Pairs EMA + MACD`, page 92.
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11838_robo-two-pairs-ema-macd-h4.md`

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
| v1 | 2026-06-20 | Initial build from card | 1229a432-084b-4dfc-82de-7b7236a8e6ad |
