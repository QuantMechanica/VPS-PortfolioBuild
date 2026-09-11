# QM5_41400_wti-mrecency-sign-tr — Strategy Spec

**EA ID:** QM5_41400
**Slug:** `wti-mrecency-sign-tr`
**Source:** `AI-CODEX-WTI-MRECENCY-SIGN-TREND-20260909`
**Author of this spec:** Codex
**Last revised:** 2026-09-11

---

## 1. Strategy Logic

On the first executable D1 tick after a broker-month transition, the EA
reconstructs thirteen consecutive completed month-end closes for WTI. It turns
the twelve adjacent log returns into signs and computes
`S = sum((i + 1) * sign(return[i]))`, so newer months receive larger fixed
weights. It buys when `S >= 18`, sells when `S <= -18`, and otherwise stays
flat; each month is consumed after one evaluation so failed execution gates do
not create retries.

An open position is protected by a frozen `3.5 * ATR(20, D1)` broker stop and
has no profit target. It closes at the next broker-month transition or after
40 elapsed days as stale-state repair. The strategy does not flip intramonth,
trail, scale in, partially close, or alter risk from the score magnitude.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_endpoint_count` | 13 | locked at 13 | Completed month-end closes in the formation window. |
| `strategy_return_count` | 12 | locked at 12 | Adjacent monthly log returns derived from the endpoints. |
| `strategy_weight_start` | 1 | locked at 1 | Oldest return's chronological sign weight. |
| `strategy_weight_step` | 1 | locked at 1 | Increment applied to each newer sign weight. |
| `strategy_weight_total` | 78 | locked at 78 | Required checksum of weights 1 through 12. |
| `strategy_score_abs_min` | 18 | locked at 18 | Inclusive absolute score required for entry. |
| `strategy_zero_epsilon` | `1e-12` | locked at `1e-12` | Returns at or inside this band invalidate the month's signal. |
| `strategy_history_bars_d1` | 1200 | locked at 1200 | Maximum D1 history copied to reconstruct month ends. |
| `strategy_entry_window_minutes` | 180 | locked at 180 | Maximum delay after the new month bar opens for the one attempt. |
| `strategy_max_endpoint_gap_days` | 10 | locked at 10 | Maximum age allowed for the newest completed month endpoint. |
| `strategy_atr_period_d1` | 20 | locked at 20 | Closed-D1 ATR period used for the initial stop. |
| `strategy_atr_sl_mult` | 3.5 | locked at 3.5 | ATR multiplier for the frozen hard stop. |
| `strategy_max_hold_days` | 40 | locked at 40 | Stale-position repair horizon. |
| `strategy_max_spread_points` | 1500 | locked at 1500 | Entry spread ceiling; zero modeled spread remains valid. |
| `strategy_deviation_points` | 20 | locked at 20 | Maximum order deviation passed to execution. |

Framework-level risk, news, RNG, stress, and Friday-close inputs are documented
in `framework/V5_FRAMEWORK_DESIGN.md` and are intentionally not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` — the approved WTI continuous-CFD carrier with registered D1
  history and magic slot 0.

**Explicitly NOT for:**

- `XNGUSD.DWX` — natural gas has different weather and storage economics and
  is outside this WTI-only card.
- FX, index, and metal `.DWX` symbols — the source lineage and locked identity
  are specific to WTI; portability was not approved.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none; completed broker months are reconstructed from D1 bars |
| Bar gating | one framework `QM_IsNewBar()` consume; normalized D1 labels provide the broker-month identity |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 6; retire below 5 in any full post-warm-up year |
| Typical hold time | one broker month, with a 40-day stale-repair ceiling |
| Expected drawdown profile | high-variance single-energy sleeve; card prior is up to 30% before downstream rejection |
| Regime preference | persistent crude-oil directional regimes with concentrated recent monthly signs |
| Win rate target (qualitative) | unspecified; downstream gates judge economics rather than a source-derived target |

The exact sign-path support is 2,124 of 4,096 possible paths, or about 6.223
eligible states per twelve monthly attempts before history and execution gates.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `AI-CODEX-WTI-MRECENCY-SIGN-TREND-20260909`

**Source type:** governed mechanization supported by a peer-reviewed paper

**Pointer:** `strategy-seeds/sources/AI-CODEX-WTI-MRECENCY-SIGN-TREND-20260909/source.md`

**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_41400_wti-mrecency-sign-tr_card.md`.

The trading lineage is Moskowitz, Ooi, and Pedersen (2012), “Time Series
Momentum,” *Journal of Financial Economics* 104(2), 228–250,
DOI `10.1016/j.jfineco.2011.11.003`. The fixed chronological sign weights and
absolute-18 threshold are disclosed QuantMechanica translations, not findings
claimed by that paper.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). This build and its canonical setfile use
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1` for non-live
backtests. Nothing in this specification authorizes deployment or live use.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-09 | Initial build from approved card | build task `fb67a381-dcd6-4296-bf48-3d0d875c5cf0`; source commit `d4b6f363eb` |
| v1.1 | 2026-09-11 | Bring the existing build spec onto the mandatory seven-section Q01 schema | no strategy or binary change |
