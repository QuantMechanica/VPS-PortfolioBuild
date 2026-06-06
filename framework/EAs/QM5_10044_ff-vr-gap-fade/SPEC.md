# QM5_10044_ff-vr-gap-fade - Strategy Spec

**EA ID:** QM5_10044
**Slug:** ff-vr-gap-fade
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA evaluates only on new H1 bars. It compares the current H1 bar open with the previous completed H1 bar close; if the open gaps up by at least the configured minimum, it sells, and if the open gaps down by at least the configured minimum, it buys. The take-profit distance equals the absolute gap size, the stop distance is the larger of 20 pips and 1.25 times the gap, and any surviving position is closed after 12 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_min_gap_pips | 10 | 1-1000 | Fixed minimum gap component in pips. |
| strategy_min_gap_atr_mult | 0.35 | 0.01-10.0 | ATR(14,H1) multiplier used in the minimum gap threshold. |
| strategy_atr_period | 14 | 1-500 | H1 ATR period for the dynamic gap threshold. |
| strategy_min_stop_pips | 20 | 1-5000 | Fixed minimum stop component in pips. |
| strategy_stop_gap_mult | 1.25 | 0.01-20.0 | Gap-size multiplier used in the stop distance. |
| strategy_max_hold_bars | 12 | 1-500 | Maximum holding period in H1 bars before strategy exit. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card R3 primary FX basket symbol with continuous DWX H1 OHLC.
- GBPUSD.DWX - card R3 primary FX basket symbol with continuous DWX H1 OHLC.
- USDJPY.DWX - card R3 primary FX basket symbol with continuous DWX H1 OHLC.
- XAUUSD.DWX - card R3 metals symbol with DWX H1 OHLC; same mechanical gap-fade rule applies.

**Explicitly NOT for:**
- Non-DWX symbols - registry and backtest artifacts must retain the `.DWX` suffix.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no validated DWX data source.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 14 |
| Expected trade frequency | Gap open fade on continuous FX/CFD feeds is sparse outside week/session opens; conservative estimate 8-20 trades/year/symbol. |
| Typical hold time | Intraday, capped at 12 H1 bars. |
| Expected drawdown profile | About 22% expected drawdown from card frontmatter. |
| Regime preference | Mean-reversion after H1 opening gaps. |
| Win rate target qualitative | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** Voldemar227, "VR Gap Open Source Trading Strategy", ForexFactory, 2026-04-22, https://www.forexfactory.com/thread/1394867-vr-gap-open-source-trading-strategy
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10044_ff-vr-gap-fade.md`

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
| v1 | 2026-06-06 | Initial build from card | 625c673c-da7f-415e-ba71-a10eea2c8aec |
