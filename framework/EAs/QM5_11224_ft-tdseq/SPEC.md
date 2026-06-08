# QM5_11224_ft-tdseq — Strategy Spec

**EA ID:** QM5_11224
**Slug:** ft-tdseq
**Source:** 1580128f-e465-5454-bb97-a7572a6cfd6d (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

The EA trades the long side of a TD Sequential exhaustion setup on closed H1 bars. It counts consecutive bars where the close is lower than the close four bars earlier, then enters long at the first tick of the next H1 bar when the count reaches the configured setup threshold and the ideal low condition is present. The ideal low condition checks whether the low of setup bar 8 or 9 is below the low of setup bar 6 or 7. Existing long positions close when the opposite sell sequence reaches the setup threshold or its ideal high condition appears; broker SL and framework Friday close remain active.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_setup_count` | 9 | 7-11 | TD Sequential setup threshold for buy and sell counts. |
| `strategy_compare_lag` | 4 | 3-5 | Lagged bar distance for close-vs-close sequence comparisons. |
| `strategy_require_ideal_exceed_low` | true | true-false | Requires the TD Sequential ideal low condition before long entry. |
| `strategy_atr_period` | 14 | fixed baseline | ATR period used for the initial stop. |
| `strategy_atr_stop_mult` | 1.5 | 1.0-2.0 | ATR multiplier for the MT5 baseline stop. |
| `strategy_disaster_stop_pct` | 5.0 | fixed baseline | Source stop-loss cap retained as a maximum percent loss from entry. |
| `strategy_warmup_bars` | 30 | fixed baseline | Minimum available closed bars before evaluating the setup. |
| `strategy_max_spread_stop_fraction` | 0.06 | fixed baseline | Blocks entry when spread exceeds 6% of planned stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card-listed liquid FX major with H1 OHLC coverage in the DWX matrix.
- `GBPUSD.DWX` — card-listed liquid FX major with H1 OHLC coverage in the DWX matrix.
- `USDJPY.DWX` — card-listed liquid FX major with H1 OHLC coverage in the DWX matrix.
- `XAUUSD.DWX` — card-listed gold market with H1 OHLC coverage in the DWX matrix.

**Explicitly NOT for:**
- Non-DWX symbols — the V5 pipeline requires broker/custom symbols from `framework/registry/dwx_symbol_matrix.csv`.
- Unlisted indices or commodities — the approved card names only the four-symbol FX/gold basket above.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Typical hold time | H1 exhaustion-reversal hold; hours to days depending on opposite sequence or stop. |
| Expected drawdown profile | Medium risk; ATR stop plus 5% disaster cap bounds individual trades. |
| Regime preference | Exhaustion-reversal / mean-revert after persistent directional runs. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Source type:** GitHub strategy
**Pointer:** `TDSequentialStrategy.py`, freqtrade-strategies, https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/berlinguyinca/TDSequentialStrategy.py
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11224_ft-tdseq.md`

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
| v1 | 2026-06-08 | Initial build from card | 26de2918-fe85-4c99-9592-8e1ee31a7bec |
