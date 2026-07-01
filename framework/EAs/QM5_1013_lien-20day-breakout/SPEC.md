# QM5_1013_lien-20day-breakout - Strategy Spec

**EA ID:** QM5_1013
**Slug:** lien-20day-breakout
**Source:** SRC04_S07
**Author of this spec:** Codex
**Last revised:** 2026-07-01

---

## 1. Strategy Logic

The EA mechanises Kathy Lien's 20-day breakout continuation setup for FX. On each closed D1 bar it looks for a fresh 20-day high or fresh 20-day low. A fresh high arms a long continuation setup; a fresh low arms a short continuation setup. The breakout must be followed on the same closed bar or the next closed bar by an opposite two-day extreme: a two-day low after a fresh high, or a two-day high after a fresh low. After that failed pullback, the EA places a stop entry beyond the original breakout level for up to three D1 bars.

For a long setup, the buy stop is placed `breakout_offset_pips` above the original 20-day high, with the initial stop `stop_anchor_offset_pips` below the pullback two-day low. For a short setup, the sell stop is placed `breakout_offset_pips` below the original 20-day low, with the initial stop `stop_anchor_offset_pips` above the pullback two-day high. If price gaps through the rebreak level before the EA can place a stop order, the EA permits a market entry with the same structural stop.

Open positions are managed structurally. At `tp1_rr` times initial risk, the EA closes half the position when broker volume constraints allow it, moves the remainder to breakeven, then trails using the configured method. The default trailing method is the two-bar extreme from the signal timeframe.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `breakout_lookback` | 20 | 10-60 | Prior closed bars used to define a fresh breakout high or low. |
| `pullback_lookback` | 2 | 2-3 | Closed bars used to confirm the failed pullback extreme. |
| `pullback_timing` | 1 | 0-2 | Number of bars after breakout allowed for the pullback; zero allows only same-bar reversal. |
| `rebreak_window` | 3 | 1-5 | Number of bars after pullback during which the breakout re-entry remains valid. |
| `breakout_offset_pips` | 5 | 2-15 | Entry offset beyond the original breakout high or low. |
| `stop_anchor_offset_pips` | 7 | 3-20 | Stop offset beyond the pullback two-day extreme. |
| `tp1_rr` | 1.0 | 0.75-2.0 | Risk multiple for half exit and breakeven stop shift. |
| `trail_method` | two_bar_extreme | two_bar_extreme, three_bar_extreme, atr14x2, atr14x3, donchian5, donchian10 | Remainder trailing method after TP1. |
| `multi_window_extreme_confluence` | off | off, 40, 60 | Optional requirement that the breakout is also a fresh 40- or 60-bar extreme. |
| `signal_tf` | D1 | D1/H4/W1 | Signal timeframe. Q02 setfiles use D1. The approved card's raw parameter name is `tf`; this EA uses `signal_tf` to avoid shadowing framework helpers. |

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` - Lien primary example and active registry slot 20.
- `EURUSD.DWX` - Lien primary example and active registry slot 14.
- `AUDUSD.DWX` - Lien primary example and active registry slot 4.
- `EURGBP.DWX` - FX cross generalisation and active registry slot 11.
- `USDJPY.DWX` - major-FX generalisation and active registry slot 30.
- `USDCHF.DWX` - major-FX generalisation and active registry slot 29.
- `USDCAD.DWX` - major-FX generalisation and active registry slot 28.
- `NZDUSD.DWX` - major-FX generalisation and active registry slot 26.
- `EURJPY.DWX` - card P3.5 cross-axis candidate and active registry slot 12.
- `GBPJPY.DWX` - card P3.5 cross-axis candidate and active registry slot 18.
- `AUDNZD.DWX` - card P3.5 cross-axis candidate and active registry slot 3.

**Explicitly NOT for:**
- Non-FX symbols in the registry. The source thesis is a currency breakout continuation after a failed pullback.
- Symbols without active magic rows for EA 1013. The V5 resolver rejects unregistered symbol slots.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none by default |
| Bar gating | `QM_IsNewBar(_Symbol, StrategyTf())` through the V5 entry gate |
| Raw bar reads | One bounded `CopyRates` call from the closed-bar entry hook for 20-day and optional 40/60-day extremes |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 3-8 |
| Typical hold time | days to several weeks |
| Expected drawdown profile | Whipsaw losses when breakout failures become deeper reversals or when rebreaks fail after entry. |
| Regime preference | directional FX continuation after temporary failed pullback |
| Win rate target (qualitative) | medium |

## 6. Source Citation

This card was mechanised from:

**Source ID:** SRC04_S07
**Source type:** book
**Pointer:** `strategy-seeds/cards/lien-20day-breakout_card.md`, sourced from Kathy Lien, *Day Trading and Swing Trading the Currency Market*, Chapter 13.
**R1-R4 verdict (Q00):** all PASS per the approved strategy card.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio, typically 0.3% - 0.5% |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-01 | Initial build from approved card | Built for Q02 enqueue on branch agents/board-advisor. |
