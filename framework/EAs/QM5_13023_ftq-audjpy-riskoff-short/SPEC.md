# QM5_13023_ftq-audjpy-riskoff-short — Strategy Spec

**EA ID:** QM5_13023
**Slug:** `ftq-audjpy-riskoff-short`
**Source:** `RS-SAFEHAVEN-FX-2010` (see `strategy-seeds/sources/RS-SAFEHAVEN-FX-2010/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-08

---

## 1. Strategy Logic

Short-only D1 momentum system on AUDJPY, active only in its own bear regime.
AUD/JPY is the canonical FX risk barometer (high-beta carry currency vs. the
classic funding safe-haven), so a stacked bearish trend on the pair itself is
used as a self-contained flight-to-quality proxy. Entry: on a new D1 close,
short when close < SMA(200) (bear regime) AND close < SMA(50) AND SMA(50) <
SMA(200) (stacked bearish alignment) AND either close breaks below the
Donchian(20) low of the prior bars or AUDJPY fails a shallow SMA(50) reclaim
by crossing back below SMA(50) inside the bear stack. Exit: ATR(14) x 2.5 hard
stop from entry, cover on a D1 close above the Donchian(15) high (channel
trail), cover on a D1 close back above SMA(50) (reclaim exit), or a 40-bar time
stop. Short-only; the long branch does not exist.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_regime` | 200 | 150-250 | Bear-regime gate: close must be below this SMA |
| `strategy_sma_mom` | 50 | 30-100 | Momentum-stack SMA: close below it, and it below sma_regime; also the reclaim-exit level |
| `strategy_donchian_entry` | 20 | 15-30 | Donchian low lookback for the breakdown entry trigger |
| `strategy_atr_period` | 14 | 10-20 | ATR period feeding the hard stop |
| `strategy_atr_sl_mult` | 2.5 | 2.0-3.0 | ATR multiple for the hard stop distance |
| `strategy_donchian_trail` | 15 | 10-20 | Donchian high lookback for the channel-trail cover |
| `strategy_max_hold_bars` | 40 | 25-55 | Max D1 bars held before the time-stop close |
| `strategy_max_spread_points` | 60 | 30-60 | Entry spread cap in broker points, measured from bid/ask when available; 0 disables the cap |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `AUDJPY.DWX` — the canonical carry-vs-safe-haven FX cross; fully
  self-contained (every input reads AUDJPY.DWX bars only, no cross-symbol
  data), verified in the DWX symbol matrix with D1 history 2017-2026.

**Explicitly NOT for:**
- Any other symbol — card frontmatter sets `single_symbol_only: true`; this
  is a defensive-sleeve single-pair realization, not a portable basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~8 (approximately 5-12, episodic) |
| Typical hold time | up to 40 D1 bars (time-stop bound) |
| Expected drawdown profile | expected_dd_pct 14.0 |
| Regime preference | risk-off / carry-unwind trend (bear regime + stacked bearish SMA alignment) |
| Win rate target (qualitative) | medium — expected_pf 1.12 |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `RS-SAFEHAVEN-FX-2010`
**Source type:** paper
**Pointer:** Ranaldo, Angelo and Paul Söderlind. "Safe Haven Currencies."
Review of Finance, 14(3), 2010 (https://academic.oup.com/rof/article/14/3/385/1592184);
supplement Moskowitz/Ooi/Pedersen (2012) "Time Series Momentum", JFE 104(2)
(https://docs.lhpedersen.com/TimeSeriesMomentum.pdf).
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_13023_ftq-audjpy-riskoff-short.md`

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
| v1 | 2026-07-07 | Initial build from card | 20604212-5ad3-4cc2-88c3-b01a58700040 |
| v1r1 | 2026-07-08 | Q02 under-frequency repair | Added failed-SMA-reclaim re-entry trigger inside the existing bear-regime stack; no new indicators or runtime data. |
