# QM5_11416_ichimoku-tenkan-kijun-cross-cloud-h4 — Strategy Spec

**EA ID:** QM5_11416
**Slug:** `ichimoku-tenkan-kijun-cross-cloud-h4`
**Source:** `d45db07a-2928-5ff6-9251-d54170212549`
**Author of this spec:** Codex
**Last revised:** 2026-08-04

---

## 1. Strategy Logic

On each newly closed H4 bar, the EA buys when Tenkan crosses above Kijun, the close is above the cloud plotted for that bar, and that close is also above the high from 26 bars earlier. It sells on the exact inverse conditions. A position closes when the current price, treated as Chikou 26 bars back, enters that historical bar's high-low range; the protective stop uses Kijun but is capped at 60 pips, and the framework also enforces Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_tenkan_period` | 9 | 7, 9, or 14 | Tenkan-sen midpoint lookback. |
| `strategy_kijun_period` | 26 | 22, 26, or 30 | Kijun-sen midpoint lookback and cloud/Chikou displacement. |
| `strategy_senkou_period` | 52 | fixed | Senkou Span B midpoint lookback. |
| `strategy_sl_cap_pips` | 60 | fixed | Maximum Kijun-stop distance from entry. |
| `strategy_spread_cap_pips` | 20 | fixed | Blocks entry only when the positive modeled spread exceeds 20 pips. |

Framework-level risk, news, seed, stress, and Friday-close inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are intentionally not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — liquid H4 major-FX series explicitly listed by the approved card.
- `GBPUSD.DWX` — liquid H4 major-FX series explicitly listed by the approved card.
- `USDJPY.DWX` — liquid H4 major-FX series explicitly listed by the approved card.
- `AUDUSD.DWX` — liquid H4 major-FX series explicitly listed by the approved card.

**Explicitly NOT for:**

- Symbols outside the four-card basket — they have no approved P2 baseline registration for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 30 |
| Typical hold time | not specified in card; signal-dependent across multiple H4 bars |
| Expected drawdown profile | not specified in card; losses are expected when crosses fail in non-trending markets |
| Regime preference | trend-following with clear cloud and Chikou separation |
| Win rate target (qualitative) | not specified in card |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d45db07a-2928-5ff6-9251-d54170212549`
**Source type:** anonymous local PDF
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\470596299-Ichimoku-Cloud-Forex-Trading-Strategy.pdf`
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_11416_ichimoku-tenkan-kijun-cross-cloud-h4.md`.

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
| v1 | 2026-08-04 | Initial build from card | 7d48aa22-3170-468a-a198-0a37a336321a |
