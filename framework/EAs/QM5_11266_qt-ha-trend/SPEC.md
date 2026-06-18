# QM5_11266_qt-ha-trend — Strategy Spec

**EA ID:** QM5_11266
**Slug:** `qt-ha-trend`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab` (je-suis-tm/quant-trading Heikin-Ashi backtest.py)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Long-only Heikin-Ashi (HA) trend/reversal system on H4. The framework has no HA
reader, so HA candles are reconstructed deterministically from raw OHLC by a
bounded forward roll: `HA_close=(O+H+L+C)/4`, `HA_open=(prevHA_open+prevHA_close)/2`,
`HA_high=max(HA_open,HA_close,H,L)`, `HA_low=min(HA_open,HA_close,H,L)`, seeded
`strategy_ha_warmup_bars` bars before the target shift and rolled forward a fixed
number of steps. A HA colour flip is the single trigger EVENT. Enter long when the
just-closed bar (shift 1) is a bearish-bodied HA candle with no upper shadow
(`HA_open==HA_high`), its body expands versus the prior HA body, the prior bar is
the same colour, and the body is at least `strategy_min_ha_body_atr_frac × ATR`.
Exit when two consecutive opposite-colour HA bars with no lower shadow
(`HA_open==HA_low`) appear, or after a `strategy_time_stop_bars` time stop. Stop is
a hard `strategy_sl_atr_mult × ATR(period)` level; there is no fixed take-profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ha_warmup_bars` | 50 | 20-150 | Bounded HA reconstruction seed depth (bars before target shift) |
| `strategy_atr_period` | 14 | 7-30 | ATR period for hard stop and body floor |
| `strategy_sl_atr_mult` | 2.0 | 1.5-2.5 | Hard stop distance = mult × ATR |
| `strategy_min_ha_body_atr_frac` | 0.25 | 0.0-0.5 | Skip entries with HA body < frac × ATR (off at 0.0) |
| `strategy_time_stop_bars` | 20 | 10-30 | Close long after N closed bars if no HA exit appears |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid FX major; clean HA trends on H4.
- `GBPUSD.DWX` — liquid FX major with sustained directional swings.
- `XAUUSD.DWX` — gold trends strongly; HA smoothing suits its momentum legs.
- `NDX.DWX` — Nasdaq 100 index, persistent trend regimes on H4.
- `GDAXI.DWX` — DAX 40; card named `GER40.DWX` which is NOT in `dwx_symbol_matrix.csv`. Ported to the canonical matrix name `GDAXI.DWX` (DAX 40). Flagged in build output.

**Explicitly NOT for:**
- `GER40.DWX` — not a canonical matrix symbol; no broker tick data. Use `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `35` |
| Typical hold time | `several days to ~2 weeks (≤20 H4 bars time stop)` |
| Expected drawdown profile | `medium; HA smoothing delays exits, ATR + time stop bound lag` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** `forum` (public GitHub repository)
**Pointer:** `https://github.com/je-suis-tm/quant-trading/blob/master/Heikin-Ashi%20backtest.py`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11266_qt-ha-trend.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor build |
