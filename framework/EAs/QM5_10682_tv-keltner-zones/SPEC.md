# QM5_10682_tv-keltner-zones - Strategy Spec

**EA ID:** QM5_10682
**Slug:** tv-keltner-zones
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades completed-bar mean reversion after price stretches outside a Keltner-style volatility envelope. A long setup requires the prior close to be below the lower Keltner band, an oversold SMI-style momentum reading that is turning up, RVOL above threshold, and a recent rally-base-rally demand-zone touch. A short setup mirrors this at the upper Keltner band with overbought momentum turning down and a drop-base-drop supply-zone touch. Each trade exits as a full position at the locked mean-reversion target or at the hard stop; no partial close, runner, break-even, or trailing logic is enabled for P2.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_keltner_period | 20 | >= 2 | EMA and ATR lookback for the Keltner envelope. |
| strategy_keltner_atr_mult | 1.5 | > 0 | ATR multiple for the outer Keltner trigger band. |
| strategy_inner_band_atr_mult | 0.75 | > 0 | ATR multiple for the opposite inner-band target. |
| strategy_smi_period | 14 | >= 2 | Lookback for the SMI-style closed-bar momentum proxy. |
| strategy_smi_threshold | 40.0 | 0-100 | Oversold/overbought threshold for long and short entries. |
| strategy_rvol_period | 20 | >= 2 | Tick-volume average lookback for RVOL proxy. |
| strategy_rvol_min | 1.10 | > 0 | Minimum last-bar tick volume divided by average tick volume. |
| strategy_zone_lookback | 24 | >= 3 | Closed-bar scan window for RBR/DBD zone context. |
| strategy_zone_impulse_atr_min | 0.80 | > 0 | Minimum impulse candle range as ATR multiple. |
| strategy_zone_base_atr_max | 0.55 | > 0 | Maximum base candle range as ATR multiple. |
| strategy_stop_pct | 0.008 | > 0 | Fixed-percent component of the hard stop distance. |
| strategy_stop_atr_min | 1.0 | > 0 | Minimum stop distance as ATR multiple. |
| strategy_stop_atr_cap | 2.5 | > 0 | Maximum stop distance as ATR multiple. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed FX major with DWX tick data.
- GBPUSD.DWX - card-listed FX major with DWX tick data.
- XAUUSD.DWX - card-listed metal, normalized from XAUUSD to the canonical DWX symbol.
- NDX.DWX - card-listed liquid index CFD with DWX tick data.
- GDAXI.DWX - canonical DWX DAX symbol used in place of the card's GER40.DWX label.

**Explicitly NOT for:**
- GER40.DWX - not present in `dwx_symbol_matrix.csv`; use GDAXI.DWX.
- SP500.DWX - mentioned only as a future validation caveat, not part of the card's P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Typical hold time | Intraday scalping hold, minutes to hours |
| Expected drawdown profile | Mean-reversion drawdowns during persistent one-way trend extensions |
| Regime preference | Mean-reversion at Keltner extremes with volume and supply/demand-zone confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView script page
**Pointer:** TradingView script `Scalping Strat-Keltner + SMI + RVOL + RBR/DBD Zones (Flexible)`, author handle `briankantanka`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10682_tv-keltner-zones.md`

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
| v1 | 2026-06-14 | Initial build from card | f6af8631-18d1-4cc8-9a16-21b707de0287 |
