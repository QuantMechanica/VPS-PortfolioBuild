# QM5_9123_aa-tes01325-cross — Strategy Spec

**EA ID:** QM5_9123
**Slug:** `aa-tes01325-cross`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7` (see `strategy-seeds/sources/ede348b4-0fa7-5be1-baa8-09e9089b67b7/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA computes a triple exponential smoothing (TES) signal from D1 closes using a fixed smoothing constant alpha=0.1325. The three nested smoothers are: ES1_t = alpha*Close_t + (1-alpha)*ES1_{t-1}; ES2_t = alpha*ES1_t + (1-alpha)*ES2_{t-1}; TES_t = alpha*ES2_t + (1-alpha)*TES_{t-1}. A long position is entered when the D1 close crosses above TES (prior close was at or below TES), and a short position is entered when the D1 close crosses below TES (prior close was at or above TES). The existing position is closed when the D1 close crosses back to the opposite side of TES, which also triggers an entry in the new direction if the cross condition is met. An initial stop-loss of 2.5×ATR(20,D1) is placed on entry. Trades are suppressed during the first 120 D1 bars (warmup) and when the current spread exceeds 2.5× the 20-day median spread.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_alpha` | 0.1325 | 0.01–0.50 | Fixed smoothing constant for all three TES stages |
| `strategy_warmup_bars` | 120 | 60–300 | Minimum D1 bars before trading is allowed |
| `strategy_atr_period` | 20 | 10–50 | ATR lookback period for initial SL |
| `strategy_atr_sl_mult` | 2.5 | 1.0–5.0 | ATR multiplier for initial stop-loss distance |
| `strategy_spread_window` | 20 | 5–50 | Rolling bar count for median spread computation |
| `strategy_spread_mult` | 2.5 | 1.0–5.0 | Current spread must be below this multiple of the median |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — US large-cap index (S&P 500); backtest-only; original paper illustration symbol
- `NDX.DWX` — US tech-heavy index (Nasdaq 100); live-tradable; high daily trend persistence
- `WS30.DWX` — US blue-chip index (Dow 30); live-tradable; diversifies from NDX
- `GDAXI.DWX` — European index (DAX 40); live-tradable; extends to EU session trend
- `XAUUSD.DWX` — Gold; live-tradable; low correlation to equity indices
- `XTIUSD.DWX` — WTI crude oil; live-tradable; ported from card's USOIL.DWX (see open_questions)
- `EURUSD.DWX` — Major FX pair; live-tradable; liquid daily trend vehicle
- `GBPUSD.DWX` — Major FX pair; live-tradable; partially correlated to EURUSD for diversification
- `USDJPY.DWX` — Major FX pair; live-tradable; risk-on/off divergence from EUR/GBP pairs

**Explicitly NOT for:**
- `SP500.DWX` live trading — broker does not route orders; requires NDX/WS30 parallel validation for T6

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` — all reads are PERIOD_D1 |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` with EA period set to D1 |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~100 (card frontmatter) |
| Typical hold time | Days to weeks (D1 trend-following) |
| Expected drawdown profile | Moderate; ATR-based SL limits per-trade loss; trend-following inherits extended drawdowns in ranging markets |
| Regime preference | trend-following |
| Win rate target (qualitative) | low (trend-followers typically win <50% but with large winners) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Source type:** `paper / blog`
**Pointer:** Henry Stern, "Trend-Following Filters - Part 2/2", Alpha Architect blog, 2021-01-21
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9123_aa-tes01325-cross.md`

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
| v1 | 2026-06-10 | Initial build from card | 7f02a3e6-3129-4e9e-bfce-71e5cd2e2861 |
