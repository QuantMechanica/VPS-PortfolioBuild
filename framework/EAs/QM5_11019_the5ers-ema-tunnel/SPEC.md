# QM5_11019_the5ers-ema-tunnel — Strategy Spec

**EA ID:** QM5_11019
**Slug:** the5ers-ema-tunnel
**Source:** 1d445184-7c47-57da-9856-a123682a932d (see `sources/the5ers-blog`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA trades a The5ers EMA tunnel swing setup. On each H1 close outside the Tokyo Asian-session proxy, it requires price to be aligned beyond EMA(144) and EMA(169) on H1, D1, W1, and a D1 monthly proxy, then requires the latest D1 candle to have pierced the EMA(144/169) tunnel and closed back outside it. It also requires H1 EMA(12) to be compressed near the tunnel, enters in the aligned direction, places the stop beyond the D1 pierce extreme by 0.5 ATR(D1,14), partial-closes at 1R, trails the remainder by EMA(12) with a 0.5 ATR(H1,14) buffer, and applies the 7-day near-entry and 20-day hard time exits.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_tunnel_fast_period` | 144 | 20-400 | Fast EMA in the tunnel. |
| `strategy_tunnel_slow_period` | 169 | 20-500 | Slow EMA in the tunnel. |
| `strategy_fast_ema_period` | 12 | 2-100 | Fast EMA used for compression and trailing. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for stop, compression, and trailing buffers. |
| `strategy_mn_proxy_fast_d1_period` | 252 | 100-1000 | D1 EMA proxy for the unavailable MN1 fast alignment leg. |
| `strategy_mn_proxy_slow_d1_period` | 300 | 100-1200 | D1 EMA proxy for the unavailable MN1 slow alignment leg. |
| `strategy_compression_pips` | 5.0 | 1-50 | Minimum pip distance allowed between EMA(12) and the nearest tunnel EMA. |
| `strategy_compression_atr_fraction` | 0.15 | 0.01-1.00 | ATR-scaled compression threshold. |
| `strategy_stop_atr_mult` | 0.5 | 0.1-5.0 | ATR(D1,14) buffer beyond the D1 pierce extreme for initial SL. |
| `strategy_partial_rr` | 1.0 | 0.25-5.0 | R multiple that triggers the partial close. |
| `strategy_partial_fraction` | 0.5 | 0.1-0.9 | Fraction of open volume to close at the partial target. |
| `strategy_trail_atr_mult` | 0.5 | 0.1-5.0 | ATR(H1,14) buffer around EMA(12) for runner trailing stop. |
| `strategy_entry_start_hour_tokyo` | 6 | 0-23 | First Tokyo-local hour when entries are allowed. |
| `strategy_entry_end_hour_tokyo` | 22 | 0-23 | First Tokyo-local hour when entries are blocked. |
| `strategy_near_entry_days` | 7 | 1-30 | Close if price remains near entry after this many calendar days. |
| `strategy_hard_stop_days` | 20 | 1-60 | Hard maximum calendar-day hold. |
| `strategy_near_entry_r_fraction` | 0.25 | 0.01-2.00 | Near-entry band in R multiples for the 7-day exit. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX pair with DWX H1/D1/W1 OHLC and EMA/ATR coverage.
- `GBPUSD.DWX` — liquid major FX pair matching the source's generic FX swing scope.
- `USDJPY.DWX` — liquid major FX pair with a JPY quote leg supported by DWX.
- `AUDUSD.DWX` — liquid major FX pair adding USD and commodity-FX exposure.
- `EURJPY.DWX` — liquid EUR/JPY cross with DWX multi-timeframe OHLC coverage.
- `GBPJPY.DWX` — liquid GBP/JPY cross matching the multi-timeframe FX tunnel setup.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols — the card's base/quote exposure filter and pip compression rule are FX-pair specific.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | H1 execution, D1 pierce signal, W1 alignment, D1 proxy for unavailable MN1 alignment |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 20 |
| Typical hold time | 7 to 20 calendar days |
| Expected drawdown profile | Swing-trend losses should be bounded by initial ATR stop and framework fixed-risk sizing. |
| Regime preference | Trend-aligned pullback / continuation after EMA tunnel pierce |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1d445184-7c47-57da-9856-a123682a932d
**Source type:** blog interview
**Pointer:** https://the5ers.com/take-the-time-and-effort-to-learn-yourself/
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11019_the5ers-ema-tunnel.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-18 | Initial build from card | f08bdf55-abf5-4b11-94ed-ab4f6f0430f2 |
