# QM5_1491_ehlers-sinewave-leadsine-cross-h4 - Strategy Spec

**EA ID:** QM5_1491
**Slug:** ehlers-sinewave-leadsine-cross-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see `sources/forexfactory-trading-systems`)
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

This EA trades H4 closes where Ehlers LeadSine crosses Sinewave in the direction of a cycle turn. A long needs a bullish LeadSine/Sinewave cross near the lower cycle extreme, three closed bars out of trend mode, D1 close above a rising D1 SMA(50), ATR(14) above 60% of its 200-bar average, and no bearish cross in the prior 12 H4 bars; shorts mirror those gates. Entries are market orders on the next available tick after the H4 close, with a fixed 2.0 ATR hard stop, a 60% partial close at +1.5 ATR, and final exit on the next opposite LeadSine/Sinewave cross. If TP1 is not reached within 24 H4 bars, the full position closes at market.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_warmup_bars` | 200 | 80+ | Minimum H4 closes required before evaluating the Hilbert/Sinewave signal. |
| `strategy_atr_period` | 14 | 1+ | ATR period for the ATR floor, stop distance, and TP1 distance. |
| `strategy_atr_sma_period` | 200 | 1+ | Number of H4 ATR samples used for the ATR floor baseline. |
| `strategy_atr_floor_ratio` | 0.6 | >0 | Requires ATR(14) to exceed this multiple of the ATR average. |
| `strategy_macro_sma_period` | 50 | 2+ | D1 SMA period for macro bias. |
| `strategy_macro_sma_slope_bars` | 5 | 1+ | D1 lookback for the SMA slope gate. |
| `strategy_recent_opp_bars` | 12 | 0+ | Blocks entry when the opposite cross occurred within this many H4 bars. |
| `strategy_cycle_extreme_level` | 0.5 | >0 | Longs require Sinewave below -level; shorts require Sinewave above +level. |
| `strategy_sl_atr_mult` | 2.0 | >0 | Fixed hard stop distance in ATR multiples. |
| `strategy_tp1_atr_mult` | 1.5 | >0 | TP1 distance in ATR multiples from entry. |
| `strategy_tp1_close_pct` | 60.0 | 0-100 | Percent of initial volume to close at TP1. |
| `strategy_time_stop_bars` | 24 | 1+ | H4 bars allowed without TP1 before market exit. |
| `strategy_spread_median_bars` | 20 | 1+ | Closed H4 bars used for the spread median. |
| `strategy_spread_mult` | 1.5 | >0 | Current spread must be at or below this multiple of the 20-bar median. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major with native DWX H4 close data for Ehlers cycle DSP.
- `GBPUSD.DWX` - FX major with native DWX H4 close data for Ehlers cycle DSP.
- `USDJPY.DWX` - FX major with native DWX H4 close data for Ehlers cycle DSP.
- `AUDUSD.DWX` - FX major with native DWX H4 close data for Ehlers cycle DSP.
- `NDX.DWX` - Liquid index CFD included by the card for cyclic index evidence.
- `WS30.DWX` - Liquid index CFD included by the card for cyclic index evidence.
- `GDAXI.DWX` - Liquid European index CFD included by the card.
- `UK100.DWX` - Liquid European index CFD included by the card.
- `XAUUSD.DWX` - Commodity symbol included by the card as P2 negative-control evidence.
- `XTIUSD.DWX` - Commodity symbol included by the card as P2 negative-control evidence.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no DWX tester data guarantee.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 close and D1 SMA(50) for macro bias |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework OnTick gate; P2 setfiles run H4 |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Up to 24 H4 bars without TP1; otherwise until TP1 plus the next opposite cycle cross |
| Expected drawdown profile | ATR-bounded single-position losses with no trailing stop |
| Regime preference | Cyclic/ranging H4 regimes inside a D1 trend bias |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum / book / article cluster
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1491_ehlers-sinewave-leadsine-cross-h4.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1491_ehlers-sinewave-leadsine-cross-h4.md`

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
| v1 | 2026-07-07 | Initial build from card | f6786307-b7ad-4bd5-ba8e-3849695a4e7a |
