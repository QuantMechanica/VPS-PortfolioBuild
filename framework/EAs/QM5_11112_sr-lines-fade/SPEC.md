# QM5_11112_sr-lines-fade — Strategy Spec

**EA ID:** QM5_11112
**Slug:** `sr-lines-fade`
**Source:** `0693c604-4f96-56ef-be79-15efe9f48b86` (see `strategy-seeds/sources/0693c604-4f96-56ef-be79-15efe9f48b86/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

The EA fades price rejections at fractal-derived horizontal support/resistance
levels on closed H1 bars. Once per closed bar it scans the last `strategy_max_bars_ext`
bars for confirmed Williams fractals (highs and lows), groups near-coincident
fractal prices into ATR-scaled bins, and exposes the nearest level strictly above
the last close (resistance, `LevelAbove`) and strictly below it (support,
`LevelBelow`). A long fires when the just-closed bar dipped into the `SafeDistance`
danger zone just above support, closed bullish, and did not close below support;
a short is the mirror at resistance. Entries that would have BOTH danger zones
active on the same bar are skipped. Entry is at the next bar open (market). A long
exits when price reaches `LevelAbove`, when a bar closes below `LevelBelow`, or
after `strategy_hold_bars` H1 bars; shorts mirror. The stop is the further of a
level-anchored offset and an entry-anchored ATR offset:
`min(LevelBelow − 0.5·ATR, entry − 1.5·ATR)` for longs, mirrored for shorts.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_max_bars_ext` | 100 | 20-300 | Closed-bar window scanned for confirmed fractals (EarnForex MaxBarsExt) |
| `strategy_atr_bin_period` | 100 | 20-200 | ATR period used for the SRAccuracy bin width |
| `strategy_atr_bin_mult` | 0.5 | 0.1-2.0 | Bin width = mult × ATR(atr_bin_period); collapses near-coincident fractals |
| `strategy_safe_distance_pts` | 50 | 10-300 | Danger-zone width in points (pip-scaled; EarnForex SafeDistance) |
| `strategy_atr_period` | 14 | 5-50 | ATR period for the stop distances |
| `strategy_sl_level_atr_mult` | 0.5 | 0.1-2.0 | Stop = level −/+ this × ATR (level-anchored term) |
| `strategy_sl_entry_atr_mult` | 1.5 | 0.5-4.0 | Stop bounded by entry −/+ this × ATR (entry-anchored term, min/max) |
| `strategy_hold_bars` | 20 | 5-100 | Time stop: close the position after this many H1 bars |
| `strategy_spread_pct_of_stop` | 15.0 | 1-100 | Skip entry if spread exceeds this % of the stop distance (fail-open on 0 spread) |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_*, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep liquid major; clean fractal structure and well-behaved ATR on H1.
- `GBPUSD.DWX` — liquid major with frequent intraday level rejections.
- `USDJPY.DWX` — liquid major; pip-scaling handled via the points→price conversion.
- `XAUUSD.DWX` — high-volatility metal; ATR-scaled bins and stops adapt to its larger range.

**Explicitly NOT for:**
- Index CFDs (NDX/WS30/SP500/GDAXI/UK100) — card targets FX/metal fractal levels;
  index session structure differs and was not validated by the card's R3.

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
| Trades / year / symbol | `~48` |
| Typical hold time | `hours to a few days (≤ 20 H1 bars)` |
| Expected drawdown profile | `moderate; fade entries against structure with bounded ATR stops` |
| Regime preference | `mean-revert / range (level rejection)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Source type:** `forum` (open-source indicator repository — EarnForex GitHub)
**Pointer:** `https://github.com/EarnForex/Support-and-Resistance-Lines`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11112_sr-lines-fade.md`

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
| v1 | 2026-06-17 | Initial build from card | board-advisor build |
