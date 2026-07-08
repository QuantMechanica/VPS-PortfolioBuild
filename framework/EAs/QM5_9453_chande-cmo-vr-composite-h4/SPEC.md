# QM5_9453 Chande CMO VR Composite H4

**EA ID:** QM5_9453
**Slug:** chande-cmo-vr-composite-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Codex
**Last revised:** 2026-07-08

---

## 1. Strategy Logic

This EA trades H4 trend breakouts only when Chande's volatility ratio says the symbol is in a trending regime. It computes `CMO(14)` from closed H4 closes and requires `ATR(7) / ATR(28) > 1.30`. A long entry fires when CMO crosses from at-or-below +50 to above +50 and the trigger bar closes bullish; a short entry mirrors this at -50 with a bearish trigger bar.

The EA rejects one-bar blow-offs when the trigger close-to-close move exceeds `2.0 * ATR(14)` from the prior closed bar. Stops are placed one ATR from entry. Exits occur when CMO crosses back through zero against the position, or after 16 closed H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_cmo_period` | 14 | 2+ | Chande Momentum Oscillator lookback in H4 bars. |
| `strategy_vr_fast_atr` | 7 | 1+ | Fast ATR period for volatility ratio. |
| `strategy_vr_slow_atr` | 28 | greater than fast ATR | Slow ATR period for volatility ratio. |
| `strategy_vr_min` | 1.30 | >0 | Minimum `ATR(fast) / ATR(slow)` trending-regime gate. |
| `strategy_cmo_breakout_level` | 50.0 | 0-100 | CMO breakout threshold; short threshold is the negative mirror. |
| `strategy_atr_period` | 14 | 1+ | ATR period for stops, spread scaling, and blow-off filter. |
| `strategy_blowoff_atr_mult` | 2.0 | >0 | Reject entry if the trigger bar move exceeds this multiple of prior ATR. |
| `strategy_sl_atr_mult` | 1.0 | >0 | Initial stop distance in ATR multiples. |
| `strategy_time_stop_bars` | 16 | 1+ | Maximum H4 bars to hold a position. |
| `strategy_spread_atr_frac_max` | 0.20 | >=0 | Maximum modeled spread as a fraction of ATR; zero spread is allowed. |
| `strategy_shorts_enabled` | true | true/false | Enables the short-side CMO -50 breakout. |
| `strategy_whipsaw_guard` | true | true/false | After a closed position, wait for CMO to revisit zero before re-entry. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — FX major in the approved broad DWX basket.
- `GBPUSD.DWX` — FX major in the approved broad DWX basket.
- `USDJPY.DWX` — FX major in the approved broad DWX basket.
- `AUDUSD.DWX` — FX major in the approved broad DWX basket.
- `USDCAD.DWX` — FX major in the approved broad DWX basket.
- `USDCHF.DWX` — FX major in the approved broad DWX basket.
- `NZDUSD.DWX` — FX major in the approved broad DWX basket.
- `XAUUSD.DWX` — metal sleeve for non-index diversification.
- `XTIUSD.DWX` — energy sleeve beyond XNG.
- `GDAXI.DWX` — European index CFD available in the DWX matrix.
- `NDX.DWX` — US growth index CFD available in the DWX matrix.
- `WS30.DWX` — US large-cap index CFD available in the DWX matrix.
- `UK100.DWX` — UK index CFD available in the DWX matrix.

**Explicitly NOT for:**
- `FRA40.DWX` — listed by the card but absent from `framework/registry/dwx_symbol_matrix.csv`.
- `JP225.DWX` — listed by the card but absent from `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the standard OnTick entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | Hours to a few days, capped at 16 H4 bars |
| Expected drawdown profile | Trend-breakout sleeve with ATR-bounded losses and no pyramiding |
| Regime preference | Volatility expansion and trend continuation |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum plus book lineage
**Pointer:** ForexFactory Chande/Kroll thread cluster plus Tushar Chande and Stanley Kroll, *The New Technical Trader*, Wiley 1994, chapters 5 and 6
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9453_chande-cmo-vr-composite-h4.md`

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
| v1 | 2026-07-08 | Initial build from card | ec95129d-ccb7-4256-8de3-972cd15ef2ef |
