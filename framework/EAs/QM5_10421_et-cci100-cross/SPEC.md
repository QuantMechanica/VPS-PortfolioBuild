# QM5_10421_et-cci100-cross - Strategy Spec

**EA ID:** QM5_10421
**Slug:** `et-cci100-cross`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `artifacts/cards_approved/QM5_10421_et-cci100-cross.md`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA computes CCI(20) on the completed H1 bar. It opens long when CCI crosses upward through +100 and opens short when CCI crosses downward through -100, with the order sent on the next bar. A long closes when CCI crosses back below +100 or a short entry signal appears; a short closes when CCI crosses back above -100 or a long entry signal appears. Any remaining position is closed after 30 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_cci_period` | 20 | 1+ | CCI lookback period. |
| `strategy_cci_threshold` | 100.0 | >0 | Positive and negative CCI trigger level. |
| `strategy_atr_period` | 20 | 1+ | ATR lookback for initial stop distance. |
| `strategy_atr_sl_mult` | 2.0 | >0 | Initial stop distance as ATR multiple. |
| `strategy_max_hold_bars` | 30 | 1+ | Maximum holding period in current-chart bars. |
| `strategy_max_spread_atr_frac` | 0.25 | >0 | Blocks new work when spread exceeds this fraction of ATR. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX major with full DWX history.
- `GBPUSD.DWX` - card-listed liquid FX major with full DWX history.
- `XAUUSD.DWX` - card-listed metal symbol; CCI and ATR use OHLC only.
- `SP500.DWX` - card-listed S&P 500 custom symbol, valid for backtest registration.
- `NDX.DWX` - card-listed Nasdaq 100 index symbol.

**Explicitly NOT for:**
- Non-DWX symbols - the framework build and backtest registries require canonical `.DWX` symbols.

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
| Trades / year / symbol | `70` |
| Typical hold time | `H1 threshold recross, opposite signal, or up to 30 hours` |
| Expected drawdown profile | `ATR-stopped oscillator system with whipsaw risk in noisy regimes` |
| Regime preference | `momentum threshold expansion` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** `forum`
**Pointer:** `https://www.elitetrader.com/et/threads/amibroker-coding-question-question-on-which-markets-does-its-analysis-for.344617/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10421_et-cci100-cross.md`

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
| v1 | 2026-05-25 | Initial build from card | 8a3f3db9-efa5-4a33-9d74-3cb94a061f38 |
