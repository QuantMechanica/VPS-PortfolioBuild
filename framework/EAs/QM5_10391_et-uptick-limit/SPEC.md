# QM5_10391_et-uptick-limit - Strategy Spec

**EA ID:** QM5_10391
**Slug:** et-uptick-limit
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades mean reversion from a closed H3 bar using a child-bar tick-direction proxy. It counts M1 closes inside the last closed H3 bar: closes above the prior M1 close are UpTicksProxy, and closes below the prior M1 close are DownTicksProxy. If UpTicksProxy is greater, it places a buy limit for the next bar at the H3 close minus Rate; if DownTicksProxy is greater, it places a sell limit at the H3 close plus Rate. Targets sit at EntryPrice +/- Rate / K, protective stops sit 1.5 x Rate away with a minimum distance of four current spreads, and positions are closed after 8 parent bars if the target has not filled.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_rate_pct | 0.14 | >0 | Entry offset as percent of the last closed parent-bar close. |
| strategy_k | 1.0 | >0 | Target divisor; target distance is Rate / K. |
| strategy_stop_rate_mult | 1.5 | >0 | Stop distance multiplier applied to Rate. |
| strategy_min_spread_mult | 4.0 | >0 | Minimum stop distance in current-spread units. |
| strategy_max_hold_bars | 8 | >=1 | Failsafe close after this many parent bars. |
| strategy_min_child_bars | 30 | >=1 | Minimum valid M1/M5 child bars inside the parent bar. |
| strategy_proxy_tf_minutes | 1 | 1 or 5 | Child timeframe used for the close-direction proxy. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 custom symbol is the card's primary broad US index proxy for the MSFT/QQQ source concept.
- NDX.DWX - Nasdaq 100 is a liquid US growth-index proxy close to the source's QQQ reference.
- WS30.DWX - Dow 30 completes the card's portable US large-cap basket.

**Explicitly NOT for:**
- SPX500.DWX - not in the DWX symbol matrix; SP500.DWX is the canonical S&P 500 custom symbol.
- SPY.DWX - not in the DWX symbol matrix; ETF symbols are not valid DWX registration targets.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H3 |
| Multi-timeframe refs | M1 child bars for the default close-direction proxy; M5 is a declared parameter variant. |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 90 |
| Typical hold time | Up to 8 H3 bars, roughly one trading day. |
| Expected drawdown profile | High porting risk because the source uptick/downtick field is approximated from CFD child closes. |
| Regime preference | Mean-revert |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/strategy-that-works-well-for-msft.28280/
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10391_et-uptick-limit.md`

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
| v1 | 2026-06-13 | Initial build from card | c9c84418-83c2-4ef0-a2a7-33d7d60b444d |
