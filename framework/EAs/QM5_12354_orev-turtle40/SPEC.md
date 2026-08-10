# QM5_12354_orev-turtle40 — Strategy Spec

**EA ID:** QM5_12354
**Slug:** `orev-turtle40`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab` (oreilm49/quantconnect, TurleTrading/main.py)
**Author of this spec:** Claude
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

Long-only, trend-following Donchian breakout on the D1 timeframe (ported Turtle-style
40-day breakout).

Entry (evaluated once per closed D1 bar, on the last closed bar, shift = 1):
- `close[1] > SMA(150)[1]` — price is above the long trend filter, AND
- `high[1]` is the maximum of the trailing 40-bar high window (a fresh 40-bar high
  just printed, i.e. `high[1] >= max(high[2..40])`), AND
- no open position already exists for this EA's magic on this symbol.

When all three hold, the EA sends a market BUY at the open of the new bar. Position
sizing is V5 fixed-risk (`QM_LotsForRisk` via the framework entry path) — the source's
ATR-based sizing is intentionally replaced.

Exit (long is closed if ANY of the following fire):
- Take-profit band: price reaches `entry × 1.20` (+20%), carried as the position TP.
- Stop-loss band: price reaches `entry × 0.92` (−8%), carried as the position SL.
- Trend break: last closed `close[1] < SMA(150)[1]` (Strategy_ExitSignal).
- Donchian low break: last closed `close[1] < lowest low of the prior 20 bars`
  (Strategy_ExitSignal, via `QM_Sig_Range_Breakout(..., 20, 1) == -1`).
- Friday close: enforced automatically by the V5 framework (not hand-rolled).

The +20% / −8% thresholds are FIXED percent-of-entry-price constants from the source
card — they are not adaptive or PnL-dependent (HR14 clear). Percent-of-price is
scale-correct across the FX / metals / index universe, so the EA does no pip
conversion anywhere.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_high_lookback` | 40 | 20-80 | Trailing high window (bars); a fresh N-bar high triggers entry. |
| `strategy_low_lookback` | 20 | 10-30 | Donchian low window (bars); close below it exits the long. |
| `strategy_sma_filter` | 150 | 100-200 | SMA period (close) used as the trend filter for entry and exit. |
| `strategy_tp_pct` | 20.0 | 10-30 | Take-profit as a percent of entry price (position TP). |
| `strategy_sl_pct` | 8.0 | 5-12 | Stop-loss as a percent of entry price (position SL). |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT, the
> qm_news_* axes, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*) are
> documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-documented here.
> The source's ATR(21) is informational only (the card's stops are the fixed
> percent bands, not an ATR multiple), so no `atr_period` input is declared.

---

## 3. Symbol Universe

**Designed for (7 symbols, D1):**
- `EURUSD.DWX` — deep, liquid FX major with multi-week trends suited to a 40-day breakout.
- `GBPUSD.DWX` — liquid FX major; sterling exhibits persistent directional legs.
- `USDJPY.DWX` — trending FX major, strong carry-driven persistence.
- `XAUUSD.DWX` — gold; a classic Turtle-style trend vehicle with sustained range expansions.
- `GDAXI.DWX` — German DAX 40 index. NOTE: the card lists `GER40.DWX`, which does NOT
  exist in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the canonical DAX symbol (verified
  present) and is substituted here.
- `NDX.DWX` — Nasdaq-100 index; strong secular uptrends reward long breakouts.
- `WS30.DWX` — Dow Jones 30 index; trend-persistent equity index.

**Explicitly NOT for:**
- Any symbol absent from `framework/registry/dwx_symbol_matrix.csv` — including the
  card's literal `GER40.DWX` token (non-existent; ported to `GDAXI.DWX`).
- Range-bound / mean-reverting instruments — the edge is trend persistence after a
  fresh range expansion, so chronic chop erodes it.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` (all reads are D1 closed bars, shift >= 1) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~16 (card frontmatter; range 8-25) |
| Typical hold time | Days to weeks (trend-following swing hold) |
| Expected drawdown profile | Moderate; long trend legs punctuated by −8% stop-outs on failed breakouts |
| Regime preference | breakout / trend |
| Win rate target (qualitative) | low (typical trend-following: many small losses, few large winners) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** forum (public GitHub quant repository)
**Pointer:** https://github.com/oreilm49/quantconnect/blob/master/TurleTrading/main.py
(repo `oreilm49/quantconnect`; source locations `TurleTrading`, `OnData`,
`handle_exit_strategy`, `SymbolData`)
**R1–R4 verdict (Q00):** all PASS / see
`artifacts/cards_approved/QM5_12354_orev-turtle40.md`

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
| v1 | 2026-08-10 | Initial build from card | task 5424e1a4-a11d-4422-a180-ef3c5e76f098; GER40.DWX→GDAXI.DWX port |
