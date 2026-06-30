# QM5_12832_dax-range-breakout - Strategy Spec

**EA ID:** QM5_12832
**Slug:** `dax-range-breakout`
**Source:** `balke-range-breakout-dax-transfer-20260630`
**Author of this spec:** Codex
**Last revised:** 2026-06-30

---

## 1. Strategy Logic

The EA builds an overnight GDAXI.DWX M15 range from 22:00 through 07:59 broker time, locks the high and low after 08:00, then trades one confirmed DAX breakout per day. A long entry requires the last closed M15 bar to close above the locked range high; a short entry requires a close below the locked range low. It filters out ranges that are too small or too large versus D1 ATR, requires a closed-bar tick-volume surge, uses the opposite range edge as the initial stop, targets a fixed reward/risk multiple, and closes any open position before the DAX cash close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `range_start_hour` | `22` | `0-23` | Broker-hour when overnight range accumulation starts. |
| `range_end_hour` | `8` | `0-23` | Broker-hour when range accumulation ends and breakout trading can begin. |
| `exit_hour` | `17` | `0-23` | Broker-hour for forced flat close. |
| `exit_min` | `0` | `0-59` | Broker-minute for forced flat close. |
| `entry_buffer_atr` | `0.0` | `0.0+` | ATR multiple added beyond the range edge before breakout confirmation. |
| `use_vol_filter` | `true` | `true/false` | Enables the closed-bar volume-surge filter. |
| `vol_mult` | `1.5` | `0.1+` | Required volume multiple versus the prior 20-bar average. |
| `strategy_rr` | `2.5` | `0.1+` | Take-profit reward/risk multiple. |
| `strategy_atr_period` | `14` | `1+` | ATR period for D1 range filter and fallback stop. |
| `atr_sl_mult` | `1.5` | `0.1+` | Fallback stop distance if the range-edge stop is invalid. |
| `min_range_atr_mult` | `0.60` | `0.0+` | Minimum locked range size as a multiple of D1 ATR. |
| `max_range_atr_mult` | `2.50` | `0.1+` | Maximum locked range size as a multiple of D1 ATR. |
| `spread_cap_points` | `30` | `0+` | Maximum allowed modeled spread in points; zero spread is allowed. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` - DAX 40 custom-symbol history is available in the DWX matrix, and the card targets a DAX transfer of the validated Balke range breakout mechanic.

**Explicitly NOT for:**
- `USDJPY.DWX` - parent sleeve uses a different Tokyo-session range and is already represented by QM5_12700.
- `XAUUSD.DWX`, `XAGUSD.DWX`, `XTIUSD.DWX`, `XNGUSD.DWX` - metals and energy do not share the DAX cash-open session structure.
- `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `UK100.DWX` - other indices require their own range-window validation.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `D1 ATR(14)` for range-size filtering |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` |
| Typical hold time | Intraday; flat by 17:00 broker time. |
| Expected drawdown profile | Low-frequency breakout with drawdown expected to stay below the card's 6% prior if the DAX session transfer is valid. |
| Regime preference | `volatility-expansion / breakout` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `balke-range-breakout-dax-transfer-20260630`
**Source type:** `OWNER / validated-strategy transfer`
**Pointer:** `docs/research/BALKE_RANGE_BREAKOUT_QM5_12700_2026-06-27.md` and `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12832_dax-range-breakout.md`
**R1-R4 verdict (Q00):** all PASS / see `framework/EAs/QM5_12832_dax-range-breakout/docs/strategy_card.md`

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
| v1 | 2026-06-30 | Initial build from approved DAX transfer card | build task `940f4709-fa6f-4470-8487-f5d297f78ca2` |
