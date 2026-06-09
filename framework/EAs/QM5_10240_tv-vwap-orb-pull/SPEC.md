# QM5_10240_tv-vwap-orb-pull - Strategy Spec

**EA ID:** QM5_10240
**Slug:** `tv-vwap-orb-pull`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA defines the opening range during the first configurable minutes after the 09:30 New York cash-session open, then waits for a completed breakout beyond that range. A long setup requires a breakout above the opening-range high, price above session VWAP and EMA(9), then a later pullback toward VWAP before entry. A short setup mirrors the rule below the opening-range low, below VWAP, and below EMA(9). Exits are the initial ATR(14) stop, the risk/reward take-profit target, or a flat-by-session-end close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_or_start_hhmm_ny` | `930` | `0`-`2359` | New York session opening time in HHMM form. |
| `strategy_or_minutes` | `15` | `1`-`120` | Number of minutes used to build the opening range. |
| `strategy_session_end_hhmm_ny` | `1600` | `0`-`2359` | New York session end time for new-entry blocking and forced flat exit. |
| `strategy_ema_period` | `9` | `1`-`200` | EMA period for the source-side trend filter. |
| `strategy_atr_period` | `14` | `1`-`200` | ATR period for stop and target calculation. |
| `strategy_atr_sl_mult` | `1.0` | `0.1`-`10.0` | ATR multiple used for the stop distance. |
| `strategy_take_profit_rr` | `1.5` | `0.1`-`10.0` | Take-profit distance as a multiple of stop risk. |
| `strategy_vwap_pullback_atr_tolerance` | `0.25` | `0.0`-`5.0` | Maximum ATR fraction away from VWAP that still counts as a pullback. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT, qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*) are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 intraday CFD port named by the card.
- `WS30.DWX` - Dow 30 intraday CFD port named by the card.
- `GDAXI.DWX` - available DAX custom symbol used in place of card-stated `GER40.DWX`, which is not in the DWX matrix.
- `XAUUSD.DWX` - liquid gold CFD port named by the card.
- `SP500.DWX` - S&P 500 custom symbol named by the card; backtest-only per owner note.

**Explicitly NOT for:**
- Any symbol outside the registered list; no implicit runtime expansion is intended.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1`, `M5`, or `M15` from the tester chart period; smoke uses `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | intraday, flat by New York session close |
| Expected drawdown profile | fixed-risk intraday breakout/pullback, bounded by ATR stop |
| Regime preference | opening-range breakout with VWAP continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script page
**Pointer:** `https://www.tradingview.com/script/75epRRh2-VWAP-ORB-Pullback-Strategy/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10240_tv-vwap-orb-pull.md`

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
| v1 | 2026-06-09 | Initial build from card | 221e9833-c247-446d-83fe-de8c66d9c981 |
