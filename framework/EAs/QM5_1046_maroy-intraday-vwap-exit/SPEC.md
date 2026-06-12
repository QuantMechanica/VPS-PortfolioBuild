# QM5_1046_maroy-intraday-vwap-exit — Strategy Spec

**EA ID:** QM5_1046
**Slug:** `maroy-intraday-vwap-exit`
**Source:** `afab7a6f-c3c8-51ae-a609-f376744beb8e` (see `strategy-seeds/sources/afab7a6f-c3c8-51ae-a609-f376744beb8e/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

Long entry when the last closed M30 bar's close exceeds the upper noise boundary (`ref_close * exp(k * sigma)`); short entry when close is below the lower boundary (`ref_close * exp(-k * sigma)`). The boundary reference is yesterday's D1 close; sigma is the rolling N-day standard deviation of daily log-returns. VWAP exit (variant A): close long when bid drops below session VWAP, close short when ask rises above session VWAP. Ladder exit (variant B): close 75% of position at 1% MFE (longs) or 2% MFE (shorts), hold remainder to session end. Hybrid exit (variant C): 75% ladder scale-out, VWAP exit for remainder. All variants flatten at cash session end and use ATR(M30, 14) × 3 as a hard stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_vwap_tf` | M5 | M1–M30 | Timeframe for intraday VWAP accumulation |
| `strategy_boundary_tf` | M30 | M5–H1 | Timeframe for noise-boundary entry check |
| `strategy_lookback_days` | 14 | 2–60 | N: rolling window for daily HV (sigma) |
| `strategy_vol_k` | 1.0 | 0.5–3.0 | k: volatility band multiplier |
| `strategy_atr_period` | 14 | 5–30 | ATR lookback for hard stop |
| `strategy_atr_sl_mult` | 3.0 | 1.0–5.0 | ATR stop distance multiplier |
| `strategy_exit_variant` | EXIT_VWAP | 0/1/2 | 0=VWAP, 1=Ladder, 2=Hybrid |
| `strategy_ladder_long_mfe_pct` | 1.0 | 0.5–5.0 | % MFE for 75% scale-out (long side) |
| `strategy_ladder_short_mfe_pct` | 2.0 | 0.5–5.0 | % MFE for 75% scale-out (short side, asymmetric) |
| `strategy_ladder_close_pct` | 75.0 | 25–90 | Fraction (%) closed on ladder trigger |
| `strategy_session_dd_cap_pct` | 20.0 | 5–50 | Skip new entries if intraday equity DD exceeds this % |
| `strategy_session_start_hour` | 16 | 0–23 | Session open hour (broker time) |
| `strategy_session_start_minute` | 30 | 0–59 | Session open minute |
| `strategy_session_end_hour` | 23 | 0–23 | Session close hour (broker time) |
| `strategy_session_end_minute` | 0 | 0–59 | Session close minute |
| `strategy_max_spread_points` | 80 | 0–500 | Max spread in points to allow new entry |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` — Nasdaq 100 CFD; liquid US large-cap index with strong intraday momentum documented in the paper; live-tradable (slot 0)
- `WS30.DWX` — Dow Jones 30 CFD; correlated US large-cap index, suitable for P3 cross-check (slot 1)
- `SP500.DWX` — S&P 500 custom symbol (backtest-only, available since 2026-05-16T19:15Z); paper's primary symbol; excluded from live promotion until parallel NDX/WS30 validation at T6 (slot 2)

**Explicitly NOT for:**
- `SPX500.DWX` — not a valid DWX symbol; the canonical name is SP500.DWX
- Forex pairs — intraday momentum edge is index-specific

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` (boundary check and entry) |
| Multi-timeframe refs | `M5` (VWAP accumulation via strategy_vwap_tf), `D1` (daily HV sigma, reference close) |
| Bar gating | `QM_IsNewBar(_Symbol, strategy_boundary_tf)` for entry; `QM_IsNewBar(_Symbol, strategy_vwap_tf)` for VWAP advance |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~2 |
| Typical hold time | Hours (intraday, flattened at session end) |
| Expected drawdown profile | Low absolute DD; session-level 20% cap prevents runaway intraday loss |
| Regime preference | Intraday momentum / breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `afab7a6f-c3c8-51ae-a609-f376744beb8e`
**Source type:** paper
**Pointer:** SSRN 5095349 (Maróy 2025), "Improvements to Intraday Momentum Strategies Using Parameter Optimization and Different Exit Strategies"
**R1–R4 verdict (Q00):** R1 UNKNOWN / R2 PASS / R3 PASS (ported) / R4 PASS — see `artifacts/cards_approved/QM5_1046_maroy-intraday-vwap-exit.md`

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
| v1 | 2026-06-12 | Initial build from card | 43519522-632d-4a53-bccf-0a7ed6df24b6 |
