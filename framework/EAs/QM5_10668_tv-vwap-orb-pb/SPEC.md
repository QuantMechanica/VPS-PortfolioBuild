# QM5_10668_tv-vwap-orb-pb - Strategy Spec

**EA ID:** QM5_10668
**Slug:** `tv-vwap-orb-pb`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

At the symbol's cash/session open, the EA records the first 15 minutes as the opening range and advances a session VWAP from closed bars. After that range completes, it waits for a close beyond the range in the same direction as VWAP and EMA(9), then enters only after price retests either VWAP or the broken opening-range boundary and closes back in the breakout direction. It skips the session when the opening range is wider than 1.5 ATR(14) or when price crosses VWAP more than the allowed chop count. Exits are a capped ATR/structure stop, a 1.5R target, or a forced flat at session end.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_opening_range_minutes` | 15 | 5-30 P3 sweep | Minutes from session open used to define the opening range. |
| `strategy_ema_period` | 9 | >=1 | EMA period used as directional confirmation. |
| `strategy_atr_period` | 14 | >=1 | ATR period used for range filter and stop cap. |
| `strategy_atr_stop_mult` | 1.0 | >0 | Maximum stop distance as a multiple of ATR. |
| `strategy_rr_target` | 1.5 | >0 | Profit target in R multiples. |
| `strategy_max_or_atr_mult` | 1.5 | >0 | Blocks entries when opening-range width exceeds this ATR multiple. |
| `strategy_max_vwap_crosses` | 3 | >=0 | Maximum post-ORB VWAP crosses allowed before treating the session as chop. |
| `strategy_pullback_tolerance_pts` | 5 | >=0 | Point tolerance around VWAP or the broken opening-range level for retest detection. |
| `strategy_session_open_hour` | -1 | -1 or 0-23 | Optional session-open hour override; -1 uses symbol defaults. |
| `strategy_session_open_minute` | -1 | -1 or 0-59 | Optional session-open minute override; -1 uses symbol defaults. |
| `strategy_session_end_hour` | -1 | -1 or 0-23 | Optional session-end hour override; -1 uses symbol defaults. |
| `strategy_session_end_minute` | -1 | -1 or 0-59 | Optional session-end minute override; -1 uses symbol defaults. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - primary Nasdaq index target named in the card's P2 basket.
- `GDAXI.DWX` - available DWX DAX custom symbol used for the card's GER40 exposure.
- `WS30.DWX` - Dow index target named in the card's P2 basket.
- `XAUUSD.DWX` - gold/metals target named in the card's P2 basket.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.
- `SP500.DWX` - listed as optional backtest-only in the card, not part of the primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Typical hold time | Intraday, flat by session end |
| Expected drawdown profile | Volatility-normalized stops with fixed 1.5R targets |
| Regime preference | Breakout with VWAP pullback confirmation |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** TradingView script `VWAP ORB Pullback Strategy`, author `TraderTed420`, published 2026-05-01, https://www.tradingview.com/script/75epRRh2-VWAP-ORB-Pullback-Strategy/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10668_tv-vwap-orb-pb.md`

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
| v1 | 2026-05-31 | Initial build from card | b9340fb4-051a-491d-ba67-e11143b5bb3e |
