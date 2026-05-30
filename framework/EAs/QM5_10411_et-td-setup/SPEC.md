# QM5_10411_et-td-setup - Strategy Spec

**EA ID:** QM5_10411
**Slug:** et-td-setup
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA trades a TD setup exhaustion pattern on closed H1 bars. A long setup requires at least nine consecutive closes below the close four bars earlier, plus a recent swing-low confirmation from the current or prior setup bar. A short setup mirrors this with at least nine consecutive closes above the close four bars earlier and a recent swing-high confirmation. Entries are market-equivalent on the next bar, with a structure-plus-ATR stop, 1.5R target, a two-bar close-comparison exit, and a 20-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_setup_count` | 9 | 1+ | Number of consecutive close-vs-close[4] bars required for TD setup. |
| `strategy_atr_period` | 20 | 1+ | ATR period used for stop buffer. |
| `strategy_stop_buffer_atr` | 0.25 | 0.0+ | ATR multiple added beyond the lower/higher setup structure stop. |
| `strategy_target_rr` | 1.5 | 0.1+ | Fixed target in R multiple from entry to stop. |
| `strategy_time_stop_bars` | 20 | 1+ | Maximum holding period in bars before strategy exit. |
| `strategy_session_filter_enabled` | false | true/false | Enables optional source time window only for P3 testing. |
| `strategy_session_start_hour` | 0 | 0-23 | Broker-hour start for optional session window. |
| `strategy_session_end_hour` | 24 | 0-24 | Broker-hour end for optional session window. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed liquid FX target with clean H1 OHLC history.
- `GBPUSD.DWX` - Card-listed liquid FX target with clean H1 OHLC history.
- `XAUUSD.DWX` - Card-listed metal target suited to exhaustion/reversal testing.
- `SP500.DWX` - Card-listed S&P 500 custom symbol, valid for backtest registration.
- `NDX.DWX` - Card-listed Nasdaq 100 index target and live-routable index proxy.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not broker/custom-symbol validated for DWX pipeline use.

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
| Trades / year / symbol | 45 |
| Typical hold time | hours to about 20 H1 bars |
| Expected drawdown profile | Reversal/exhaustion entries can draw down during persistent trends. |
| Regime preference | exhaustion-reversal with swing confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/t-demark-s-trend-lines.135311/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10411_et-td-setup.md`

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
| v1 | 2026-05-25 | Initial build from card | 1f5825db-3583-4902-bae2-4bdcd48148b4 |
