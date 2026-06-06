# QM5_10907_carter-ema60-pb - Strategy Spec

**EA ID:** QM5_10907
**Slug:** carter-ema60-pb
**Source:** 6facee24-8a58-5bbf-88e9-38d44291db50
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA trades an H1 trend pullback to EMA(60). A long setup requires EMA(60) and EMA(15) to slope upward over the last 5 closed bars, with EMA(5) above EMA(15) above EMA(60), and the prior closed bar must touch EMA(60). A short setup mirrors the same rules downward, with EMA(5) below EMA(15) below EMA(60). Entries are market orders on the next bar, with a fixed 30-pip stop, fixed 50-pip take profit, and an early close when EMA(5) crosses EMA(15) against the open trade.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_ema_fast | 5 | 1+ | Fast EMA used for stack and cross exit |
| strategy_ema_mid | 15 | 1+ | Middle EMA used for stack, slope, and cross exit |
| strategy_ema_slow | 60 | 1+ | Slow EMA used as trend anchor and pullback touch level |
| strategy_slope_bars | 5 | 1+ | Closed-bar distance used to confirm EMA(15) and EMA(60) slope |
| strategy_stop_pips | 30 | 1+ | Fixed stop-loss distance in pips |
| strategy_take_pips | 50 | 1+ | Fixed take-profit distance in pips |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card source names EURUSD and the DWX matrix confirms EURUSD.DWX availability.
- GBPUSD.DWX - Card source names GBPUSD and the DWX matrix confirms GBPUSD.DWX availability.

**Explicitly NOT for:**
- Non-registered DWX symbols - The card R3 row only approves EURUSD.DWX and GBPUSD.DWX for this build.

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
| Trades / year / symbol | 20 |
| Typical hold time | Not specified in card frontmatter; bounded by 30-pip SL, 50-pip TP, EMA(5/15) adverse cross, or Friday close |
| Expected drawdown profile | Fixed 30-pip stop per trade, one position per magic |
| Regime preference | Trend pullback / moving-average-stack continuation |
| Win rate target (qualitative) | Not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6facee24-8a58-5bbf-88e9-38d44291db50
**Source type:** book
**Pointer:** `G:/My Drive/QuantMechanica/Ebook/PDF resources/20 Forex Trading Strategies - Thomas Carter.pdf`, Strategy #6, pages 14-15
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10907_carter-ema60-pb.md`

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
| v1 | 2026-06-06 | Initial build from card | 505d9d9a-e483-45c3-8e88-d1d50da8e763 |
