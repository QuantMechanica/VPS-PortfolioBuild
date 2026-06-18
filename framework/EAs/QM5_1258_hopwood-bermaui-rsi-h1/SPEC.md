# QM5_1258_hopwood-bermaui-rsi-h1 - Strategy Spec

**EA ID:** QM5_1258
**Slug:** hopwood-bermaui-rsi-h1
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA trades H1 closed-bar crosses of a smoothed RSI oscillator. It first reads RSI(14) on H1 close, computes a second RSI(14) over that RSI series, then enters long when the smoothed oscillator crosses up through 50 and price is above EMA(200). It enters short when the smoothed oscillator crosses down through 50 and price is below EMA(200). Open trades exit on an opposite smoothed-RSI midline cross, by the framework SL/TP, or when the smoothed oscillator has stayed inside 45-55 for four closed bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_rsi_period | 14 | >=2 | Period for the raw RSI and second RSI pass. |
| strategy_ema_period | 200 | >=1 | EMA period used as the directional trend filter. |
| strategy_atr_period | 14 | >=1 | ATR period used for initial stop placement. |
| strategy_atr_sl_mult | 2.0 | >0 | ATR multiple for the initial stop loss. |
| strategy_rr_target | 2.0 | >0 | Reward-to-risk multiple for take profit. |
| strategy_midline | 50.0 | 0-100 | Smoothed RSI midline crossing threshold. |
| strategy_mid_zone_bars | 4 | >=1 | Consecutive closed bars required inside the mid-zone exit band. |
| strategy_mid_zone_low | 45.0 | 0-100 | Lower bound of the trend-fade mid-zone. |
| strategy_mid_zone_high | 55.0 | 0-100 | Upper bound of the trend-fade mid-zone. |
| strategy_max_spread_points | 25 | >=0 | Maximum modeled spread in points; zero spread is allowed. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Major FX pair listed in the card's R3 portable DWX basket.
- GBPUSD.DWX - Major FX pair listed in the card's R3 portable DWX basket.
- USDJPY.DWX - Major FX pair listed in the card's R3 portable DWX basket.
- AUDUSD.DWX - Major FX pair listed in the card's R3 portable DWX basket.
- EURJPY.DWX - Major FX cross listed in the card's R3 portable DWX basket.
- GBPJPY.DWX - Major FX cross listed in the card's R3 portable DWX basket.

**Explicitly NOT for:**
- SP500.DWX - The card is an FX H1 Hopwood oscillator strategy, not an index strategy.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Not specified in frontmatter; card describes similar frequency to Hopwood stochastic-cross siblings. |
| Typical hold time | Not specified in frontmatter; H1 trend-follower holds until opposite cross, mid-zone fade, SL, or 2R TP. |
| Expected drawdown profile | Not specified in frontmatter; fixed ATR stop and one position per magic bound per-trade loss. |
| Regime preference | Trend-following FX regimes aligned with EMA(200). |
| Win rate target (qualitative) | Medium; fixed 2R target allows lower win rate than one-to-one exits. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** https://www.forexfactory.com/thread/282290 and `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1258_hopwood-bermaui-rsi-h1.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1258_hopwood-bermaui-rsi-h1.md`

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
| v1 | 2026-06-18 | Initial build from card | a9b157e6-7545-4f28-9083-f72e6ddefbd2 |
