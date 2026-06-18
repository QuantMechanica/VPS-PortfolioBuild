# QM5_11448_crue-ichimoku-5line-rank-d1 — Strategy Spec

**EA ID:** QM5_11448
**Slug:** `crue-ichimoku-5line-rank-d1`
**Source:** `26f4bdb0-0e74-5f92-9da1-dbdd8702cab2` (see `strategy-seeds/sources/26f4bdb0-0e74-5f92-9da1-dbdd8702cab2/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The five Ichimoku lines are ranked in strict order on the close of each D1 bar.
When all five are perfectly stacked bullish — Chikou > Tenkan, Tenkan > Kijun,
Kijun > Senkou Span A, Senkou Span A > Senkou Span B — the EA goes (or stays)
long. When the four inequalities are reversed (fully bearish rank) it goes short.
This is an always-in system: it exits the moment any link in the chain breaks
(rank invalidation → flat) and reverses when the opposite full rank appears. The
Chikou displacement is the non-standard **-22** that Crue found optimal in both
in-sample and out-of-sample tests (vs the standard -26). All lines are read on
closed bars at non-repainting shifts. A protective ATR(14) × 2.0 stop is added
for V5 risk control (Crue uses rank-invalidation as the only exit).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_tenkan_period` | 9 | 7-12 | Tenkan-sen (conversion line) period |
| `strategy_kijun_period` | 26 | 20-30 | Kijun-sen (base line) period; MT5 span displacement |
| `strategy_senkou_period` | 52 | 40-60 | Senkou Span B period |
| `strategy_chikou_displacement` | 22 | 18-26 | Non-standard -22 Chikou back-displacement |
| `strategy_atr_period` | 14 | 10-20 | ATR period for the protective stop |
| `strategy_atr_sl_mult` | 2.0 | 1.5-3.0 | Protective stop = mult × ATR (card P2) |
| `strategy_spread_pct_of_stop` | 15.0 | 5-30 | Skip entry only if spread > this % of stop distance |

---

## 3. Symbol Universe

Single-symbol Ichimoku line-ranking (each symbol ranks its own five lines; this
is NOT a cross-sectional basket). Registered for the card's portable FX D1 basket.

**Designed for:**
- `EURUSD.DWX` — deepest, most liquid FX pair; clean D1 trend regimes.
- `GBPUSD.DWX` — liquid major with sustained D1 trends suited to Ichimoku.
- `USDJPY.DWX` — strong directional D1 trends; JPY pip-scaling handled by framework.
- `AUDUSD.DWX` — commodity-linked trender; D1 Ichimoku applicability.
- `USDCAD.DWX` — oil-correlated USD pair with persistent D1 trends.

**Explicitly NOT for:**
- Indices / metals — card specifies FX D1; Crue's optimal -22 shift was tuned on
  daily equity/FX behaviour, not intraday or index CFDs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~15` |
| Typical hold time | `days to weeks (always-in trend rank)` |
| Expected drawdown profile | `trend-follower: many small losses, fewer large trend wins` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `low/medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `26f4bdb0-0e74-5f92-9da1-dbdd8702cab2`
**Source type:** `paper`
**Pointer:** `409877311-BackTesting-Ichimoku-Trading-Strategy.pdf` (Emeric Crue, 2019)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11448_crue-ichimoku-5line-rank-d1.md`

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
| v1 | 2026-06-18 | Initial build from card | Claude board-advisor build |
