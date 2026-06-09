# QM5_10205_tv-chop-dmi-psar — Strategy Spec

**EA ID:** QM5_10205
**Slug:** `tv-chop-dmi-psar`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA trades H1 trend entries from the TradingView CHOP Zone Entry Strategy with DMI/ADX confirmation and PSAR exits. A long setup requires smoothed CHOP(14, 4) above 61.8, ADX(14) above 25, and, when follow-trend mode is enabled, bullish PSAR state with +DI above -DI. A short setup requires CHOP below 38.2, ADX above 25, and bearish PSAR state with -DI above +DI. Positions close on ADX falling below the key level with the opposite DI cross, on PSAR flipping against the position, or, when both DMI and PSAR exits are disabled for a variant, on the opposite CHOP zone.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_H1` | MT5 timeframe enum | Signal timeframe from the card. |
| `strategy_chop_period` | `14` | `> 1` | Choppiness Index lookback. |
| `strategy_chop_smoothing` | `4` | `>= 1` | Simple average smoothing length for CHOP. |
| `strategy_chop_long_level` | `61.8` | `0-100` | Long-entry CHOP zone threshold. |
| `strategy_chop_short_level` | `38.2` | `0-100` | Short-entry CHOP zone threshold. |
| `strategy_dmi_period` | `14` | `> 1` | DMI and ADX lookback. |
| `strategy_adx_key_level` | `25.0` | `> 0` | ADX trend-strength threshold. |
| `strategy_psar_start` | `0.015` | `> 0` | PSAR initial acceleration factor. |
| `strategy_psar_increment` | `0.001` | `> 0` | PSAR acceleration increment. |
| `strategy_psar_maximum` | `0.20` | `> 0` | PSAR maximum acceleration factor. |
| `strategy_atr_period` | `14` | `> 0` | ATR period for emergency stop distance. |
| `strategy_emergency_atr_mult` | `3.0` | `> 0` | Maximum initial stop distance when PSAR is unavailable or wider. |
| `strategy_max_spread_stop_fraction` | `0.15` | `0-1` | Maximum spread as a fraction of PSAR/ATR stop distance. |
| `strategy_follow_trend` | `true` | boolean | Requires PSAR and DI state to agree with the entry direction. |
| `strategy_enable_psar_exit` | `true` | boolean | Enables PSAR-flip exits. |
| `strategy_enable_dmi_exit` | `true` | boolean | Enables ADX/DI cross exits. |
| `strategy_psar_warmup_bars` | `90` | `>= 20` | Closed-bar warmup window for PSAR reconstruction. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only strategy-specific inputs are listed.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card-listed major FX symbol with DWX H1 history.
- `GBPUSD.DWX` — card-listed major FX symbol with DWX H1 history.
- `XAUUSD.DWX` — card-listed gold symbol with DWX H1 history.
- `GDAXI.DWX` — DWX DAX custom symbol used as the available port for card-stated `GER40.DWX`.
- `NDX.DWX` — card-listed US index symbol with DWX H1 history.

**Explicitly NOT for:**
- `GER40.DWX` — not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- Any unregistered symbol — magic resolution is registered only for the designed universe above.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | Not specified in card; expected H1 trend holds from hours to days. |
| Expected drawdown profile | `18.0%` expected DD from card frontmatter. |
| Regime preference | Trend-following / regime-filtered directional moves. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** `TradingView script`
**Pointer:** `https://www.tradingview.com/script/GrP0zABg-CHOP-Zone-Entry-Strategy-DMI-PSAR-Exit/`
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10205_tv-chop-dmi-psar.md`

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
| v1 | 2026-06-09 | Initial build from card | ae692219-9c5a-4391-9ca3-6dc3e3fef6a3 |
