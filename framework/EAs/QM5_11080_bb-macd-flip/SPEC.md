# QM5_11080_bb-macd-flip — Strategy Spec

**EA ID:** QM5_11080
**Slug:** `bb-macd-flip`
**Source:** `0693c604-4f96-56ef-be79-15efe9f48b86` (EarnForex BB-MACD)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA trades the EarnForex "BB-MACD" colour flip — a trend-change detector built
on a Bollinger envelope drawn around the MACD line itself. Each closed bar it
computes `bbMACD = EMA(close, 12) - EMA(close, 26)` (the MACD main line), then a
Bollinger band over the last 10 bbMACD values: `SMA(bbMACD, 10) ± 2.5 ×
stddev(bbMACD, 10)`. The indicator's colour turns UP when bbMACD crosses above
the upper band and DOWN when it crosses below the lower band; a colour flip is
exactly that band-cross event.

Long when bbMACD crosses above the upper band (down→up flip); short when it
crosses below the lower band (up→down flip). The system is stop-and-reverse: a
flip closes any opposite position and opens a new one in the flip direction, so
the exit for a long is the next short flip and vice-versa. A catastrophic ATR(14)
× 2.5 stop sits broker-side as the only standalone protective exit. An optional
stricter variant (`strategy_stricter_zero`) additionally requires bbMACD > 0 for
longs / < 0 for shorts. Signals evaluate on completed bars only.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_len` | 12 | 5-50 | bbMACD fast EMA length (FastLen) |
| `strategy_slow_len` | 26 | 10-100 | bbMACD slow EMA length (SlowLen) |
| `strategy_bb_length` | 10 | 5-50 | Bollinger length over the bbMACD series (Length) |
| `strategy_bb_stdv` | 2.5 | 1.0-4.0 | Bollinger deviations over bbMACD (StDv) |
| `strategy_stricter_zero` | false | true/false | Require bbMACD>0 long / <0 short (lower-freq variant) |
| `strategy_atr_period` | 14 | 5-50 | Catastrophic stop ATR period |
| `strategy_atr_sl_mult` | 2.5 | 1.0-5.0 | Catastrophic stop distance in ATR (card P2 baseline) |
| `strategy_atr_tp_mult` | 0.0 | 0.0-6.0 | Optional take-profit in ATR (0 = disabled; flip exit only) |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_*, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid major; clean trending/momentum cycles suit MACD-band flips.
- `GBPUSD.DWX` — volatile major with sustained momentum legs that produce band crosses.
- `USDJPY.DWX` — trend-persistent major; momentum-cycle flips are well-defined.
- `XAUUSD.DWX` — strong directional regimes on gold give pronounced bbMACD band breaks.

**Explicitly NOT for:**
- Index CFDs (NDX/WS30/SP500.DWX) — card universe is FX + gold; not in scope for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | `hours to a few days (momentum-cycle holds on H1)` |
| Expected drawdown profile | `moderate; reversal whipsaws in ranges, capped by 2.5-ATR stop` |
| Regime preference | `trend / momentum` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Source type:** `forum` (EarnForex GitHub repository + indicator article)
**Pointer:** `https://github.com/EarnForex/BB-MACD` (article: https://www.earnforex.com/metatrader-indicators/BB-MACD/)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11080_bb-macd-flip.md`

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
| v1 | 2026-06-07 | Initial build from card | 68577f3e-71d6-4a67-8993-979197583bfa |
