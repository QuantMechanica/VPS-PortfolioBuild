# QM5_1358_as-gpm-corrhedge — Strategy Spec

**EA ID:** QM5_1358
**Slug:** `as-gpm-corrhedge`
**Source:** `2df06de7-6a3a-5b06-9e6d-446d1a01fab9` (see `strategy-seeds/sources/2df06de7-6a3a-5b06-9e6d-446d1a01fab9/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

AllocateSmartly Generalized Protective Momentum (Keuning & Keller) with a
correlation hedge, realized as a monthly cross-sectional rotation. Once per
broker-time calendar-month roll (the first closed D1 bar of a new month), the EA
ranks a 9-symbol basket on closed D1 bars. For each asset it computes momentum
`ri` = the average of the 1-, 3-, 6-, and 12-month price returns (one month = 21
D1 bars), and a correlation hedge `ci` = the 12-month Pearson correlation of that
asset's monthly-step returns against the equal-weight basket's monthly returns.
The hedged score is `zi = ri * (1 - ci)` — momentum is rewarded but discounted
when the asset is highly correlated to the crowd. Breadth `n` counts the risk
assets with `zi > 0`. If `n <= 4` (half of the 8 risk assets) the book goes fully
defensive (100% crash-protection proxy). If `n > 4`, the EA holds the three risk
sleeves with the highest `zi` and also holds the defensive proxy for the residual
crash-protection weight `((8 - n) / 4)`. Each EA instance trades only its own
chart symbol long when that symbol is in the selected sleeve set, and exits at the
next month roll when it falls out. Protective initial stop = 4× D1 ATR(14).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_month_bars` | 21 | 18-23 | D1 bars per month proxy (252/12) for momentum & correlation steps |
| `strategy_corr_months` | 12 | 6-12 | Correlation lookback in months (12 → 252 D1 bars) |
| `strategy_top_n` | 3 | 1-4 | Number of risk sleeves held when offensive |
| `strategy_atr_sl_mult` | 4.0 | 2.0-8.0 | Protective initial stop = mult × D1 ATR(period) |
| `strategy_atr_period` | 14 | 10-21 | D1 ATR period for the protective stop |
| `strategy_spread_atr_cap` | 0.50 | 0.0-2.0 | Skip entry if quoted spread / D1 ATR exceeds this (fail-open on 0 spread) |

---

## 3. Symbol Universe

**Designed for (RISK universe — 8 sleeves):**
- `SP500.DWX` — S&P 500, SPY proxy (US large-cap equity). Backtest-only; not broker-routable.
- `NDX.DWX` — Nasdaq 100, QQQ proxy (US growth equity).
- `WS30.DWX` — Dow 30, large-cap proxy (IWM/Russell not routable on DWX → Dow fallback).
- `GDAXI.DWX` — DAX 40, VGK / Europe-equity proxy.
- `UK100.DWX` — FTSE 100, international-equity proxy.
- `XTIUSD.DWX` — WTI crude, DBC commodity proxy.
- `XNGUSD.DWX` — Natural gas, DBC commodity proxy.
- `XAGUSD.DWX` — Silver, precious-metal / commodity proxy.

**Designed for (DEFENSIVE / crash-protection proxy — 1):**
- `XAUUSD.DWX` — Gold, safe-haven proxy standing in for IEF/TLT. Treasuries are
  not routable on DWX, so the source's bond/cash crash-protection leg is realized
  as a gold price-momentum proxy. FLAGGED: any bond carry/yield edge is unmodeled
  ($0 swap in tester).

**Explicitly NOT for:**
- Forex pairs — GPM is a cross-asset-class TAA rotation; FX legs are not in the source universe.
- Bond / credit / REIT / EM / Japan ETFs (TLT, IEF, HYG, LQD, VNQ, EEM, EWJ, VGK) — no DWX CFD exists; substituted by the proxies above and flagged.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` (monthly cadence derived from D1 calendar-month roll) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~6-12` (monthly rebalance; only when host is selected/deselected) |
| Typical hold time | `weeks to months` (held to month end; multi-month while still selected) |
| Expected drawdown profile | `breadth-driven crash protection caps equity drawdowns; rotates to gold defensive proxy when breadth deteriorates` |
| Regime preference | `trend` (cross-sectional momentum with correlation hedge) |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `2df06de7-6a3a-5b06-9e6d-446d1a01fab9`
**Source type:** `forum` (AllocateSmartly strategy catalogue; Keuning & Keller, TrendXplorer / SSRN references)
**Pointer:** https://allocatesmartly.com/keuning-kellers-generalized-protective-momentum/
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1358_as-gpm-corrhedge.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor build worker |
