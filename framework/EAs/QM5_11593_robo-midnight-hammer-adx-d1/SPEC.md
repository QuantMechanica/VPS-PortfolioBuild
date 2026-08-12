# QM5_11593_robo-midnight-hammer-adx-d1 — Strategy Spec

**EA ID:** QM5_11593
**Slug:** `robo-midnight-hammer-adx-d1`
**Source:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d`
**Author of this spec:** Codex
**Last revised:** 2026-08-06

---

## 1. Strategy Logic

At each D1 close, the EA looks for a hammer or shooting-star rejection candle whose long tail is at least three times its body and whose opposite tail is at most half the long tail. A long requires ADX(14), +DI, and -DI to confirm bullish direction; a short uses the mirrored DI conditions. The EA enters at the next D1 open with the signal-bar extreme as its stop, a 2R take-profit, and closes any remaining position at the end of its entry day.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_adx_period` | 14 | 2–100 | ADX and directional-indicator lookback; Q00 baseline is 14. |
| `strategy_adx_threshold` | 20.0 | >0–<100 | Required ADX and dominant DI level; Q00 baseline is 20. |
| `strategy_tail_body_ratio` | 3.0 | >0–20 | Minimum long-tail size as a multiple of the real body. |
| `strategy_opposite_tail_max_ratio` | 0.5 | 0–1 | Maximum opposite-tail size relative to the long tail. |
| `strategy_rr_target` | 2.0 | >0–10 | Factory take-profit as a multiple of signal-bar stop risk. |
| `strategy_max_hold_bars` | 1 | 1–10 | Completed D1 bars before the same-day time exit; Q00 baseline is one. |

Framework inputs, including risk, news, Friday-close, seed, and stress controls, are defined in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — liquid major FX host for the D1 rejection pattern.
- `GBPUSD.DWX` — liquid major with distinct sterling volatility.
- `AUDUSD.DWX` — commodity-linked major that broadens the FX driver set.
- `USDJPY.DWX` — yen-rate sensitivity adds a different major-pair regime.
- `NZDUSD.DWX` — smaller commodity-linked major broadens the Pacific sleeve.
- `USDCAD.DWX` — oil-sensitive North American major diversifies the basket.

**Explicitly NOT for:**

- Indices, metals, energy, and crypto — the approved card authorizes only the six named FX pairs.
- FX symbols outside the list — no deterministic magic slot is allocated by this card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` on the attached D1 chart |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 30 |
| Typical hold time | one D1 session or less when the 2R target/stop is reached |
| Expected drawdown profile | isolated fixed-risk losses bounded by the signal-bar extreme; no stacking |
| Regime preference | directional rejection after a strong ADX/DI move |
| Win rate target (qualitative) | medium; payoff is capped at 2R and time-flat after one day |

---

## 6. Source Citation

**Source ID:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d`
**Source type:** institutional educational strategy collection
**Pointer:** RoboForex Educational Team, *Forex Strategy Collection* (~2015), “Midnight,” pages 109–110; approved card copy at `docs/strategy_card.md`
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_11593_robo-midnight-hammer-adx-d1.md`

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
| v1 | 2026-08-06 | Initial build from approved card | Build task `7a5b3aa7-7537-4f55-ad41-a2751ece76b4` |
