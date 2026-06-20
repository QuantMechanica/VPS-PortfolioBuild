# QM5_9403_williams-pro-go-h4 - Strategy Spec

**EA ID:** QM5_9403
**Slug:** `williams-pro-go-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `sources/forexfactory-strategies-and-systems`)
**Author of this spec:** Codex
**Last revised:** 2026-06-21

---

## 1. Strategy Logic

The EA trades the H4 Williams Pro body component, where `Pro[t]` is the 14-bar sum of `Close - Open`. It enters long when `Pro[t] > 0`, `Pro[t-1] <= 0`, the closed bar is above SMA(50), and the close is no more than 1.5 ATR(14) above the SMA. It enters short on the mirrored cross below zero with the close below SMA(50) and no more than 1.5 ATR below the SMA.

Entries are market orders at the next H4 bar after the signal bar. Initial SL is 1.0 ATR(14) from the signal close, TP is 2.0 ATR(14) from the signal close, and discretionary exit occurs when Pro flips through zero against the open position or when the position reaches the 30-H4-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_pro_period` | 14 | >= 1 | Closed H4 bars summed for the Williams Pro component. |
| `strategy_sma_period` | 50 | >= 1 | SMA trend filter period on H4 closes. |
| `strategy_atr_period` | 14 | >= 1 | ATR period for extension filter, SL, TP, and spread cap. |
| `strategy_max_extension_atr` | 1.5 | >= 0.0 | Maximum distance from SMA(50), measured in ATR units. |
| `strategy_sl_atr_mult` | 1.0 | > 0.0 | Stop-loss distance from the signal close in ATR units. |
| `strategy_tp_atr_mult` | 2.0 | > 0.0 | Profit-target distance from the signal close in ATR units. |
| `strategy_time_stop_bars` | 30 | >= 1 | Maximum H4 bars to hold before strategy exit. |
| `strategy_weekly_open_skip_hours` | 4 | >= 0 | Monday broker-time hours skipped after weekly open. |
| `strategy_spread_atr_mult` | 0.20 | >= 0.0 | Blocks entry only when modeled spread is wider than this ATR fraction. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major named by the card and present in the DWX matrix.
- `GBPUSD.DWX` - FX major named by the card and present in the DWX matrix.
- `USDJPY.DWX` - FX major named by the card and present in the DWX matrix.
- `AUDUSD.DWX` - FX major named by the card and present in the DWX matrix.
- `USDCAD.DWX` - FX major named by the card and present in the DWX matrix.
- `USDCHF.DWX` - FX major named by the card and present in the DWX matrix.
- `NZDUSD.DWX` - FX major named by the card and present in the DWX matrix.
- `XAUUSD.DWX` - Gold CFD named by the card and present in the DWX matrix.
- `XTIUSD.DWX` - Oil CFD named by the card and present in the DWX matrix.
- `SP500.DWX` - S&P 500 custom symbol referenced by the R3 caveat; backtest-only.
- `NDX.DWX` - US index CFD named by the card and present in the DWX matrix.
- `WS30.DWX` - US index CFD named by the card and present in the DWX matrix.
- `GDAXI.DWX` - DAX index CFD named by the card and present in the DWX matrix.
- `UK100.DWX` - FTSE index CFD named by the card and present in the DWX matrix.

**Explicitly NOT for:**
- `FRA40.DWX` - named by the card but absent from `dwx_symbol_matrix.csv`; no phantom symbol registered.
- `JP225.DWX` - named by the card but absent from `dwx_symbol_matrix.csv`; no phantom symbol registered.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton entry path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | H4 swing hold, capped at 30 closed H4 bars |
| Expected drawdown profile | ATR-defined per-trade loss with no pyramiding or averaging |
| Regime preference | trend-following participation divergence with SMA trend filter |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum plus book lineage
**Pointer:** ForexFactory Larry Williams Pro-Go thread cluster and Larry Williams, *Long-Term Secrets to Short-Term Trading*, ch. 14
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9403_williams-pro-go-h4.md`

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
| v1 | 2026-06-21 | Initial build from card | 1bc889a2-a35c-4ca2-8bb4-654f6b6672a0 |
