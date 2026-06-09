# QM5_10227_tv-triple-st-adx — Strategy Spec

**EA ID:** QM5_10227
**Slug:** `tv-triple-st-adx`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

This EA trades the closed-bar direction of three Supertrend calculations. A long signal is valid when all three Supertrend states are bullish; a short signal is valid when all three are bearish. When the optional ADX/EMA filter is enabled, the closed-bar ADX must exceed the threshold and price must close on the correct side of the EMA. A long exits when any Supertrend flips bearish, and a short exits when any Supertrend flips bullish.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_CURRENT` | MT5 timeframe enum | Timeframe used for Supertrend, EMA, ADX, and ATR stop reads. |
| `strategy_supertrend_1_period` | `10` | `5-25` source range | ATR period for Supertrend 1. |
| `strategy_supertrend_1_mult` | `1.0` | `1.0-6.0` source range | ATR multiplier for Supertrend 1. |
| `strategy_supertrend_2_period` | `15` | `5-25` source range | ATR period for Supertrend 2. |
| `strategy_supertrend_2_mult` | `2.0` | `1.0-6.0` source range | ATR multiplier for Supertrend 2. |
| `strategy_supertrend_3_period` | `20` | `5-25` source range | ATR period for Supertrend 3. |
| `strategy_supertrend_3_mult` | `3.0` | `1.0-6.0` source range | ATR multiplier for Supertrend 3. |
| `strategy_use_adx_ema_filter` | `false` | `true/false` | Enables the source ADX plus EMA confirmation filter. |
| `strategy_ema_period` | `200` | `5-250` source range | EMA trend filter length. |
| `strategy_adx_period` | `14` | `1-25` source range | ADX trend-strength period. |
| `strategy_adx_threshold` | `25.0` | `1.0-50.0` source range | Minimum ADX when the filter is enabled. |
| `strategy_allow_same_side_reentry` | `false` | `true/false` | P1 default disables same-side re-entry until an opposite signal occurs. |
| `strategy_supertrend_warmup_bars` | `220` | `30-1000` | Closed-bar history used to rebuild Supertrend state. |
| `strategy_stop_atr_period` | `14` | `1-100` | ATR period for the emergency protective stop. |
| `strategy_stop_atr_mult` | `2.0` | `0.1-20.0` | Emergency stop distance in ATR multiples. |
| `strategy_max_spread_atr_pct` | `0.0` | `0.0-100.0` | Optional spread filter as a percentage of ATR; zero disables it. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` — trend-capable gold CFD named directly in the approved card.
- `GDAXI.DWX` — canonical DWX DAX symbol used for the card's `GER40.DWX` target because `GER40.DWX` is not in the DWX matrix.
- `NDX.DWX` — trend-capable Nasdaq 100 CFD named directly in the approved card.
- `GBPJPY.DWX` — trend-capable JPY cross named directly in the approved card.
- `EURJPY.DWX` — trend-capable JPY cross named directly in the approved card.

**Explicitly NOT for:**
- Any symbol outside the registered list above — no runtime universe expansion is intended.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` and `H4` |
| Multi-timeframe refs | none by default; `strategy_signal_tf` can pin all strategy reads to one timeframe |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `35` |
| Expected trade frequency | Not specified in frontmatter; card narrative implies regular trend-following signals on H1/H4. |
| Typical hold time | Not specified in frontmatter; expected to hold until Supertrend reversal, emergency stop, news gate, or Friday close. |
| Expected drawdown profile | Fixed-risk, trend-following whipsaw risk bounded by the V5 risk model and 2 ATR emergency stop. |
| Regime preference | Trend-following / multi-filter confirmation. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView open-source script
**Pointer:** `https://www.tradingview.com/script/ChaVrUF9-Triple-Supertrend-with-EMA-and-ADX-strategy/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10227_tv-triple-st-adx.md`

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
| v1 | 2026-06-10 | Initial build from card | 8bc7e7ad-5da6-41cf-bfb7-ab63274aaa88 |
