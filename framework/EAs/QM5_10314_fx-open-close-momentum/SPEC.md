<!--
QuantMechanica V5 — EA Spec Document
Required by Q01 Build & Spec gate (Vault: `03 Pipeline/Q01 Build & Spec.md`)
Validator: `framework/scripts/validate_spec_doc.py`
-->

# QM5_10314_fx-open-close-momentum — Strategy Spec

**EA ID:** QM5_10314
**Slug:** `fx-open-close-momentum`
**Source:** `fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9` (see `strategy-seeds/sources/fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-22

---

## 1. Strategy Logic

At the opening of the first M30 bar of the configured session the EA records the bar's open price. When the last 30-minute window of that same session begins, it computes the return of the first half-hour bar (close/open − 1). If the return is positive and its absolute value exceeds 10% of the rolling 20-day median first-half-hour absolute return, a long position is opened; if negative (with same magnitude filter), a short is opened. The stop is placed at 0.75× the rolling 20-day median first-half-hour absolute range from entry. The position is closed by time stop at session end (the close of the final 30-minute bar). EURUSD and GBPUSD use the London session (broker 10:00–18:30); all other DWX FX majors use the NY overlap session (broker 15:30–20:00).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_london_open_hhmm` | 1000 | 0–2359 | London session open in DXZ broker time (HHMM); EURUSD/GBPUSD only |
| `strategy_london_close_hhmm` | 1830 | 0–2359 | London session close in DXZ broker time (HHMM); defines last-bar entry + exit |
| `strategy_ny_overlap_open_hhmm` | 1530 | 0–2359 | NY overlap session open in DXZ broker time (HHMM); all other FX majors |
| `strategy_ny_overlap_close_hhmm` | 2000 | 0–2359 | NY overlap session close in DXZ broker time (HHMM) |
| `strategy_median_days` | 20 | 5–60 | Rolling lookback in trading days for first-bar return and range medians |
| `strategy_min_return_median_mult` | 0.10 | 0.0–1.0 | Minimum first-bar return as a fraction of the rolling median; skips weak days |
| `strategy_stop_range_mult` | 0.75 | 0.1–3.0 | Stop distance = this × rolling median first-bar range |
| `strategy_spread_median_mult` | 1.50 | 0.0–5.0 | Max spread = this × rolling median spread at entry bar (0 = disable; DWX tester silently skips when median unavailable) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — most liquid FX pair; London session momentum well-documented in source paper
- `GBPUSD.DWX` — high-liquidity GBP/USD; London session analogous to EURUSD
- `USDJPY.DWX` — USD major with strong NY overlap momentum characteristics
- `USDCAD.DWX` — USD/CAD trades the NY overlap period; Canadian data releases coincide
- `AUDUSD.DWX` — antipodean pair with NY overlap activity suitable for this strategy
- `USDCHF.DWX` — safe-haven USD/CHF with NY overlap session participation

**Explicitly NOT for:**
- Index or commodity DWX symbols — strategy is FX-native; session definitions differ materially

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | None — all reads are on `PERIOD_M30` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` for entry evaluation; `iTime(M30, 0)` to identify entry bar |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~30 (corrected from initial 220 overclaim; rework v2 2026-06-16) |
| Typical hold time | 30 minutes (one M30 bar — final session window) |
| Expected drawdown profile | Low absolute DD per trade; stop = 0.75× median first-bar range |
| Regime preference | Intraday momentum / liquidity-provision |
| Win rate target (qualitative) | Medium (momentum edge is moderate; confirmed by SSRN source paper) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9`
**Source type:** paper
**Pointer:** Elaut, Frommel, Lampaert, "Intraday Momentum in FX Markets: Disentangling Informed Trading from Liquidity Provision," SSRN abstract 2694985, 2015-11-24. URL: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2694985
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10314_fx-open-close-momentum.md`

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
| v1 | 2026-05-25 | Initial build from card | Prior attempt; spread-filter DWX bug caused zero trades |
| v2 | 2026-06-22 | Fix DWX spread-filter invariant; correct session defaults to broker time | Build task c7368e6f |
