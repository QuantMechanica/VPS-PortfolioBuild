# QM5_10038_ff-4x25ema-mtf-h4 — Strategy Spec

**EA ID:** QM5_10038
**Slug:** `ff-4x25ema-mtf-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (foff00, "4x25MA Simple Strategy", ForexFactory, 2019)
**Author of this spec:** Claude
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

A four-timeframe EMA-side trend strategy executed on H4 closed bars. Go LONG when
the last three closed bars on M15, H1, H4 AND D1 each close above their own
EMA(25), the broker time is inside the liquid session, and H4 ATR(14) sits above
the 30th percentile of the last 100 H4 bars. Go SHORT on the mirror condition
(all four timeframes closing below EMA(25)). The stop is 2.0 × ATR(14,H4) and the
target is 3.5 × ATR(14,H4) (the midpoint of the source's 3–4× ATR target). A
position is closed early on a full opposite four-timeframe EMA alignment, or after
a 20 H4-bar time stop, whichever comes first. Only one position per symbol/magic
is held at a time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 25 | 5-200 | EMA period applied on each of the four timeframes. |
| `strategy_atr_period` | 14 | 5-50 | ATR period for stop, target and the volatility filter (H4). |
| `strategy_atr_sl_mult` | 2.0 | 0.5-5.0 | Stop-loss distance as a multiple of ATR(14,H4). |
| `strategy_atr_tp_mult` | 3.5 | 1.0-8.0 | Take-profit distance as a multiple of ATR(14,H4). |
| `strategy_alignment_bars` | 3 | 1-10 | Number of last closed bars that must sit the same side of EMA on every TF. |
| `strategy_atr_percentile_bars` | 100 | 20-300 | Lookback window (H4 bars) for the ATR percentile filter. |
| `strategy_min_atr_percentile` | 30.0 | 0-100 | Minimum H4 ATR percentile required to allow an entry. |
| `strategy_max_spread_stop_fraction` | 0.08 | 0.0-1.0 | Skip entry if current spread exceeds this fraction of the stop distance. |
| `strategy_session_start_hour` | 8 | 0-23 | Liquid-session start (broker hour, inclusive). |
| `strategy_session_end_hour` | 21 | 0-23 | Liquid-session end (broker hour, exclusive) — not after NY close. |
| `strategy_max_hold_h4_bars` | 20 | 1-200 | Time stop expressed in H4 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid major; clean multi-timeframe EMA trends.
- `GBPUSD.DWX` — liquid major with sustained directional legs that suit MTF alignment.
- `USDJPY.DWX` — trending major; EMA-stack continuation behaves well.
- `XAUUSD.DWX` — high-volatility metal; ATR-scaled stops/targets fit its range.

**Explicitly NOT for:**
- Index CFDs (`NDX.DWX`, `WS30.DWX`, `SP500.DWX`) — the card's basket is FX/metals;
  index microstructure and session profile differ from the source intent.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | EMA(25) read on `M15`, `H1`, `H4`, `D1` (last 3 closed bars each) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~32 (card estimate 20–45) |
| Typical hold time | hours to ~3 days (capped at 20 H4 bars ≈ 3.3 days) |
| Expected drawdown profile | moderate; ATR-scaled 2× stop, single position per symbol |
| Regime preference | trend (four-timeframe EMA continuation) |
| Win rate target (qualitative) | low-to-medium (positive expectancy via 3.5:2.0 reward:risk) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** foff00, "4x25MA Simple Strategy", ForexFactory, 2019 — https://www.forexfactory.com/thread/932507-4x25ma-simple-strategy
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_10038_ff-4x25ema-mtf-h4.md`

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
| v1 | 2026-05-23 | Initial build from card | skeleton-derived MTF EMA implementation |
| v2 | 2026-06-05 | Corset rebuild-in-place (DL-069): MTF alignment via QM_Sig_Price_Above_MA cached once per H4 bar (removed raw iClose + per-tick EMA recompute); session/spread/volatility gates scoped to entry so exit cadence is no longer session-blocked | ff4e8d5c-7732-4b4b-b77f-c47f995a4cae |
