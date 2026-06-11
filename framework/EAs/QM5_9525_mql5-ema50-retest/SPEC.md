# QM5_9525_mql5-ema50-retest — Strategy Spec

**EA ID:** QM5_9525
**Slug:** `mql5-ema50-retest`
**Source:** `a120af9a-fb72-526c-bb80-d1d098a617b5` (see `strategy-seeds/sources/a120af9a-fb72-526c-bb80-d1d098a617b5/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades EMA-50 bounce setups on M15 bars. On each closed bar, the 50-period EMA is read. A bullish signal fires when the bar's low dips below the EMA but the bar closes back above it, AND the close is higher than the open, AND the candle body covers at least 25% of the bar's range — this confirms a genuine EMA pierce-and-close retest with directional momentum. The mirror condition (high pierces EMA, closes below, bearish body) fires a short signal. Entry is at the next market price (ask for buys, bid for sells) with a fixed 300-point stop and 600-point take profit bracketing each trade. An optional repeated-defense filter (disabled by default) requires that the EMA was also defended in at least one of the prior four bars before allowing an entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 50 | 10–200 | Period for the EMA used as the retest level |
| `strategy_sl_points` | 300 | 50–2000 | Fixed stop-loss distance in points |
| `strategy_tp_points` | 600 | 100–5000 | Fixed take-profit distance in points |
| `strategy_min_body_ratio` | 0.25 | 0.0–1.0 | Minimum body/range ratio for candle confirmation |
| `strategy_use_defense` | false | true/false | Require prior EMA defense before entry |
| `strategy_defense_lookback` | 4 | 1–20 | Bars back (from shift 2) to check for prior defense |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — Major forex pair with high M15 liquidity; EMA-50 bounce well-studied
- `GBPUSD.DWX` — Major forex pair with similar EMA-retest characteristics
- `GDAXI.DWX` — DAX 40 index; strong intraday EMA behaviour during European session (card stated GER40.DWX, ported to available GDAXI.DWX)
- `XAUUSD.DWX` — Gold; trending/mean-reverting dynamics fit EMA-bounce logic

**Explicitly NOT for:**
- `GER40.DWX` — Not available in DWX matrix; GDAXI.DWX is the canonical DAX symbol

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~95 (card frontmatter) |
| Typical hold time | 1–8 hours (M15 with fixed 300-pt SL / 600-pt TP) |
| Expected drawdown profile | Moderate; fixed SL per trade, 1:2 R:R ratio |
| Regime preference | Trend-following (pullback/retest) |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `a120af9a-fb72-526c-bb80-d1d098a617b5`
**Source type:** article
**Pointer:** Clemence Benjamin, "From Novice to Expert: Automating Intraday Strategies", MQL5 Articles, 2026-02-20
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9525_mql5-ema50-retest.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-11 | Initial build from card | c93ac7b6-3f49-446c-8489-3f2af96f5585 |
