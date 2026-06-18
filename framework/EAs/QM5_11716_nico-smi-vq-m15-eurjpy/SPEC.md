# QM5_11716_nico-smi-vq-m15-eurjpy — Strategy Spec

**EA ID:** QM5_11716
**Slug:** `nico-smi-vq-m15-eurjpy`
**Source:** `5071d002-b640-5386-a182-9c7dd3551d60` (see `strategy-seeds/sources/5071d002-b640-5386-a182-9c7dd3551d60/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Multi-indicator confluence on M15 EURJPY. The trade trigger is a Stochastic
Momentum Index (SMI) curl out of an extreme zone; three states must confirm.

Long: on a closed M15 bar, SMI must have been below `-smi_extreme` two bars ago
and be turning up (`SMI[2] < -40 AND SMI[1] > SMI[2]`), AND EMA(5) > EMA(6), AND
the Heiken-Ashi candle is white (`HA_Close > HA_Open`), AND the VQ (Volatility
Quality) value is rising. Short is the mirror: SMI curling down out of the
`+smi_extreme` zone with EMA(5) < EMA(6), a red Heiken-Ashi candle, and a falling
VQ. Entries are only taken from `smi_session_start_h` (broker hour) onward. Stop
is `sl_atr_mult × ATR(14)`; take-profit is `tp_rr ×` the stop distance. The SMI
trigger is the single cross EVENT; EMA bias, HA color, VQ direction and session
are STATES — this avoids the two-cross-same-bar zero-trade trap. SMI and VQ are
not native MT5 indicators, so both are computed in-EA via recursive double-EMA /
ATR-normalized accumulators, advanced once per closed bar and cached.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `smi_hl_period` | 14 | 5-30 | SMI N-bar high/low lookback (%K length) |
| `smi_smooth1` | 10 | 3-30 | SMI first EMA smoothing period |
| `smi_smooth2` | 14 | 3-30 | SMI second EMA smoothing period |
| `smi_extreme` | 40.0 | 20-60 | SMI extreme zone threshold (±) |
| `ema_fast_period` | 5 | 2-20 | MA-crossover fast EMA |
| `ema_slow_period` | 6 | 3-30 | MA-crossover slow EMA |
| `vq_period` | 5 | 2-20 | VQ ATR-normalization / damping period |
| `atr_period` | 14 | 5-30 | ATR period (stop sizing + VQ scaling) |
| `sl_atr_mult` | 2.0 | 0.5-5 | Stop distance = mult × ATR |
| `tp_rr` | 1.5 | 0.5-5 | Take-profit = tp_rr × stop distance |
| `smi_session_start_h` | 7 | 0-23 | Earliest broker hour to take entries |
| `spread_pct_of_stop` | 15.0 | 1-100 | Skip if spread > this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURJPY.DWX` — the card's sole target symbol; SMI/VQ M15 confluence tuned to EURJPY volatility (JPY-cross, ~35-pip swings). Verified present in `dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- Index CFDs (`NDX.DWX`, `WS30.DWX`, `SP500.DWX`) — card is a JPY-cross M15 forex system; pip scaling and session logic do not transfer.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~120` |
| Typical hold time | `hours (intraday M15)` |
| Expected drawdown profile | `moderate; tight 2×ATR stop, RR-capped target` |
| Regime preference | `momentum / volatility-expansion out of extremes` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `5071d002-b640-5386-a182-9c7dd3551d60`
**Source type:** `forum`
**Pointer:** `forexstrategiesresources.com #301 "Easy 15min Trading System" (Nico, ~2012), local PDF 353827940`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11716_nico-smi-vq-m15-eurjpy.md`

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
