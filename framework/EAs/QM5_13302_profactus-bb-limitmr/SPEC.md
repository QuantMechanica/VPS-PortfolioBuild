# QM5_13302_profactus-bb-limitmr — Strategy Spec

**EA ID:** QM5_13302
**Slug:** profactus-bb-limitmr
**Source:** YT-PROFACTUS-PROP-2026-08
**Author of this spec:** Codex
**Last revised:** 2026-08-04

---

## 1. Strategy Logic

On each newly closed M15 bar, the EA places a passive sell limit when the close is above the M15 upper Bollinger Band, RSI is above 70, and the last closed H1 high is above its upper band; the long rule is the exact inverse below the lower bands with RSI below 30. The limit sits two pips beyond the signal close and expires after one M15 bar if unfilled. A filled trade has a static take-profit at the signal-time M15 middle band, a hard three-ATR stop, and is flattened when the broker-time trading session ends.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bb_period` | 20 | 14, 20, 26 | Bollinger Band period on M15 and H1. |
| `strategy_bb_deviation` | 2.0 | 1.8, 2.0, 2.4 | Bollinger Band standard-deviation multiplier. |
| `strategy_rsi_period` | 14 | fixed | M15 RSI period. |
| `strategy_rsi_filter` | 20.0 | 15.0, 20.0, 25.0 | Distance from RSI 50 used to form the 30/70 exhaustion thresholds. |
| `strategy_atr_period` | 14 | fixed | M15 ATR period used for the protective stop. |
| `strategy_sl_atr_mult` | 3.0 | 2.0, 3.0, 4.0 | ATR multiple between the pending entry and hard stop. |
| `strategy_entry_offset_pips` | 2.0 | 1.0, 2.0, 3.0 | Passive limit offset beyond the signal close. |
| `strategy_order_expiry_bars` | 1 | fixed | M15 bars allowed before an unfilled limit is removed. |
| `strategy_session_start_hour` | 2 | fixed | Inclusive broker-time session start hour. |
| `strategy_session_end_hour` | 20 | fixed | Exclusive broker-time session end hour. |
| `strategy_max_spread_points` | 0 | per symbol | Positive spread ceiling in points; zero leaves the gate disabled until a measured DWX cap is available. |

Framework-level risk, news, stress, and Friday-close inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `AUDCAD.DWX` — the card's primary liquid FX-cross implementation and host-symbol baseline.
- `NZDCHF.DWX` — the card's explicitly supported secondary FX-cross implementation, subject to its Q02 history-completeness kill criterion.

**Explicitly NOT for:**

- All other `.DWX` symbols — the approved card authorizes only the two named FX crosses and requires per-symbol EA instances rather than a basket or substitutions.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | Last closed `H1` bar for Bollinger-band confluence. |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` on an M15 chart. |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 100 signals; realized fills are lower because limits expire after one bar. |
| Typical hold time | Intraday, ending at the static middle-band target, ATR stop, or 20:00 broker-time session close. |
| Expected drawdown profile | High; the card estimates about 15% and expects clustered losses during sustained trends. |
| Regime preference | Intraday mean reversion after a Bollinger/RSI overshoot; sustained H1 breakouts are adverse. |
| Win rate target (qualitative) | Not claimed by the source; downstream pipeline evidence decides. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** YT-PROFACTUS-PROP-2026-08
**Source type:** video with an internal transcript-extraction dossier
**Pointer:** Profactus AI videos `KGJvM2w1ylA` and `0fDEufdbmfw`; evidence dossier at `D:/QM/strategy_farm/artifacts/research/profactus_prop_bb_martingale_extraction_2026-08-03.md`
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_13302_profactus-bb-limitmr.md`.

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
| v1 | 2026-08-04 | Initial build from card | 1c167932-6f43-4969-bb65-395d865ea6c4 |
