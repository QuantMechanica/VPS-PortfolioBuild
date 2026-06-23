# QM5_9454_williams-pro-go-go-trigger-h4 - Strategy Spec

**EA ID:** QM5_9454
**Slug:** williams-pro-go-go-trigger-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see `sources/forexfactory-strategies-and-systems`)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA trades Larry Williams' Pro/Go split on closed H4 bars. It sums 14 bars of `Close - Open` as Pro and 14 bars of `Open - prior Close` as Go, clipping the weekly gap contribution to +/-0.5 ATR. A long opens when Go crosses from negative to non-negative, Pro is positive, close is above SMA(50), and the close is not more than 2 ATR above the SMA; shorts mirror the rule below the SMA. The EA exits when Pro crosses back through zero against the open position, or when the position has aged past 18 closed H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_tf` | `PERIOD_H4` | H4 only for this card | Base timeframe for all Pro/Go, SMA, ATR, entry, and exit checks. |
| `strategy_pro_go_period` | `14` | `2+` | Rolling window length for Pro and Go cumulative sums. |
| `strategy_sma_period` | `50` | `2+` | Close SMA trend filter period. |
| `strategy_atr_period` | `14` | `1+` | ATR period for extension cap, gap clip, spread cap, and stop distance. |
| `strategy_extension_atr_mult` | `2.0` | `>0` | Maximum distance from close to SMA allowed at entry. |
| `strategy_stop_atr_mult` | `1.0` | `>0` | Stop-loss distance in ATR from entry. |
| `strategy_gap_clip_atr_mult` | `0.5` | `>=0` | Weekly gap Go-term clip as a multiple of prior ATR. |
| `strategy_spread_atr_mult` | `0.20` | `>=0` | Maximum live spread as a fraction of ATR; zero tester spread is allowed. |
| `strategy_time_stop_bars` | `18` | `1+` | Maximum closed H4 bars to hold before strategy exit. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major with continuous H4 OHLC history for Pro/Go calculations.
- `GBPUSD.DWX` - FX major with continuous H4 OHLC history for Pro/Go calculations.
- `USDJPY.DWX` - FX major with continuous H4 OHLC history for Pro/Go calculations.
- `AUDUSD.DWX` - FX major with continuous H4 OHLC history for Pro/Go calculations.
- `USDCAD.DWX` - FX major with continuous H4 OHLC history for Pro/Go calculations.
- `USDCHF.DWX` - FX major with continuous H4 OHLC history for Pro/Go calculations.
- `NZDUSD.DWX` - FX major with continuous H4 OHLC history for Pro/Go calculations.
- `XAUUSD.DWX` - liquid metal CFD with H4 OHLC support.
- `XTIUSD.DWX` - liquid energy CFD with H4 OHLC support.
- `SP500.DWX` - S&P 500 custom-symbol index proxy; backtest-only per DWX discipline.
- `NDX.DWX` - Nasdaq 100 index CFD for US large-cap exposure.
- `WS30.DWX` - Dow 30 index CFD for US large-cap exposure.
- `GDAXI.DWX` - DAX index CFD for European index exposure.
- `UK100.DWX` - FTSE 100 index CFD for European index exposure.

**Explicitly NOT for:**
- `FRA40.DWX` - named in the card but absent from `dwx_symbol_matrix.csv`; not registered.
- `JP225.DWX` - named in the card but absent from `dwx_symbol_matrix.csv`; not registered.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `40` |
| Typical hold time | Up to 18 H4 bars, about 3 trading days maximum |
| Expected drawdown profile | Trend-following pullbacks with ATR-defined per-trade risk |
| Regime preference | Trend-aligned directional regimes where Go and Pro agree |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum plus book lineage
**Pointer:** ForexFactory post cluster and Larry Williams, *Long-Term Secrets to Short-Term Trading*, ch. 14
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9454_williams-pro-go-go-trigger-h4.md`

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
| v1 | 2026-06-23 | Initial build from card | 8d134344-15c0-47a3-82e7-5c8f204e0d09 |
