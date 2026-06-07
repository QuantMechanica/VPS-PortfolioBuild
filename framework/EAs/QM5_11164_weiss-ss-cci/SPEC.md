# QM5_11164_weiss-ss-cci - Strategy Spec

**EA ID:** QM5_11164
**Slug:** weiss-ss-cci
**Source:** 3005c768-aa91-5daf-9dd7-500d7bfcb7a6 (see `strategy-seeds/sources/3005c768-aa91-5daf-9dd7-500d7bfcb7a6/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed D1 bars. It opens long when the slow stochastic main line crosses below 15 and CCI(10) is below -100, and it opens short when the slow stochastic main line crosses above 85 and CCI(10) is above 100. Long positions close when stochastic crosses back above 30; short positions close when stochastic crosses back below 70. Any position that has not exited by the oscillator rule is closed after 15 D1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_D1` | M1-MN1 | Timeframe used for stochastic, CCI, and max-hold bar counting. |
| `strategy_stoch_k_period` | `14` | `1+` | Stochastic K period from the card. |
| `strategy_stoch_d_period` | `3` | `1+` | Stochastic D period from the card. |
| `strategy_stoch_slowing` | `3` | `1+` | Stochastic slowing value from the card. |
| `strategy_cci_period` | `10` | `1+` | CCI confirmation period. |
| `strategy_long_entry_k` | `15.0` | `0-100` | Long entry threshold crossed downward by stochastic. |
| `strategy_short_entry_k` | `85.0` | `0-100` | Short entry threshold crossed upward by stochastic. |
| `strategy_long_exit_k` | `30.0` | `0-100` | Long mean-exit threshold crossed upward by stochastic. |
| `strategy_short_exit_k` | `70.0` | `0-100` | Short mean-exit threshold crossed downward by stochastic. |
| `strategy_cci_long_max` | `-100.0` | unrestricted | Maximum CCI value allowed for long entries. |
| `strategy_cci_short_min` | `100.0` | unrestricted | Minimum CCI value allowed for short entries. |
| `strategy_stop_pct` | `1.5` | `0+` | Percent stop distance from entry price. |
| `strategy_max_hold_bars` | `15` | `1+` | Maximum D1 bars to hold before time exit. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major FX pair in the card's R3 basket.
- `EURJPY.DWX` - liquid FX cross in the card's R3 basket.
- `AUDCAD.DWX` - FX cross in the card's R3 basket.
- `GBPCHF.DWX` - FX cross in the card's R3 basket.
- `SP500.DWX` - S&P 500 custom symbol explicitly listed in the card's R3 basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no DWX data contract for pipeline testing.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P 500 variants; the canonical custom symbol is `SP500.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `3` |
| Typical hold time | Up to 15 D1 bars |
| Expected drawdown profile | Mean-reversion drawdowns can cluster during persistent directional moves. |
| Regime preference | mean-revert / oscillator-extreme |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3005c768-aa91-5daf-9dd7-500d7bfcb7a6
**Source type:** book
**Pointer:** Richard L. Weissman, *Mechanical Trading Systems: Pairing Trader Psychology with Technical Analysis*, Wiley, 2005, Chapter 4, pp. 83-84, https://studylib.net/doc/28245153/richard-l.-weissman---mechanical-trading-systems
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11164_weiss-ss-cci.md`

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
| v1 | 2026-06-07 | Initial build from card | 7f28c2d4-3ac6-44ce-80fb-5f6469e085db |
