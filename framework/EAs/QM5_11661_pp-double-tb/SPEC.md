# QM5_11661_pp-double-tb - Strategy Spec

**EA ID:** QM5_11661
**Slug:** pp-double-tb
**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades PatternPy-style double-top and double-bottom reversals on closed H4 bars. On each new H4 bar it evaluates the PatternPy label two bars back, after the right-side neighbour required by `shift(-1)` has closed. A double top opens a short when the labelled bar's high is below both neighbouring highs, the three-bar rolling high is at least as high as both neighbours, and both neighbouring bars have high-low ranges no wider than 5 percent of their average price. A double bottom mirrors the rule on lows. Positions close on the opposite pattern, after 12 H4 bars, or when the last closed bar breaks the stored pattern high or pattern low; the broker stop is seeded at 2.0 x ATR(14).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_window | 3 | fixed at 3 | PatternPy rolling high/low window used for the source label. |
| strategy_threshold | 0.05 | 0.001-0.20 | Maximum allowed high-low range for each neighbouring bar, expressed as a fraction of that bar's average price. |
| strategy_atr_period | 14 | 2-100 | ATR period used for the emergency protective stop. |
| strategy_atr_sl_mult | 2.0 | 0.5-10.0 | ATR multiplier for the protective stop distance. |
| strategy_max_hold_bars | 12 | 1-100 | Maximum position age in base-timeframe bars before strategy exit. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`; this table lists only strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card target EURUSD; liquid DWX forex major with H4 OHLC coverage.
- GBPUSD.DWX - card target GBPUSD; liquid DWX forex major with H4 OHLC coverage.
- XAUUSD.DWX - card target XAUUSD; DWX metal symbol with OHLC pattern portability.
- GDAXI.DWX - canonical DWX DAX 40 symbol used for card target GER40.
- NDX.DWX - card target NDX; DWX Nasdaq 100 index symbol.

**Explicitly NOT for:**
- GER40.DWX - not present in `dwx_symbol_matrix.csv`; GDAXI.DWX is the canonical registered DAX target for this build.
- SPX500.DWX / SPY.DWX / ES.DWX - not card targets and not canonical DWX symbols for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework wiring |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 20 |
| Expected trade frequency | not specified in card frontmatter; inferred as roughly monthly to bi-monthly from 20 trades/year/symbol |
| Typical hold time | maximum 12 H4 bars, about 48 hours, unless opposite pattern or pattern break exits first |
| Expected drawdown profile | reversal pattern with ATR emergency stop; losses should cluster during persistent trend legs |
| Regime preference | reversal / mean-reversion after local double-top or double-bottom retests |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Source type:** GitHub repository source
**Pointer:** Keith Orange / `keithorange`, PatternPy, `tradingpatterns/tradingpatterns.py`, `detect_double_top_bottom`, retrieved 2026-05-24 from `https://github.com/keithorange/PatternPy/blob/main/tradingpatterns/tradingpatterns.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11661_pp-double-tb.md`

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
| v1 | 2026-06-11 | Initial build from card | 1bed8e64-2280-4cfb-8061-e50d98ad444c |
