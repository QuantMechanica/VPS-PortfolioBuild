# QM5_11084_tlb-flip — Strategy Spec

**EA ID:** QM5_11084
**Slug:** `tlb-flip`
**Source:** `0693c604-4f96-56ef-be79-15efe9f48b86` (EarnForex "Three-Line Break", GitHub + MQL5 source)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

The EA reconstructs a Three-Line-Break (TLB) chart deterministically from
confirmed H4 bar closes (shift >= 1 only, never the forming bar, so there is no
repaint). The TLB series is a sequence of directional "blocks": in an up-series
a confirmed close above the running block-high prints a new up block; in a
down-series a confirmed close below the running block-low prints a new down
block. A reversal ("color flip") prints when the confirmed close breaks the
extreme of the last `LinesToBreak` (default 3) opposite blocks. The EA goes
LONG on a fresh bullish flip (down-series turns up) and SHORT on a fresh bearish
flip (up-series turns down), evaluated once per closed bar. An optional EMA(14)
of the TLB block closes filters flips (longs only above the EMA, shorts only
below), mirroring the EarnForex EnableMA/MA_Period option. A position is exited
on the next opposite TLB flip; a catastrophic ATR(14) stop at 2.5x ATR can close
first. There is no take-profit — the trade rides until the opposite flip. One
position per symbol/magic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lines_to_break` | 3 | 2-5 | TLB reversal threshold (EarnForex LinesToBreak): blocks to break for a flip |
| `strategy_tlb_window_bars` | 240 | 60-500 | Confirmed-close window used to rebuild the TLB series each bar |
| `strategy_min_block_pts` | 0 | 0-1000 | Minimum close move (points) to print a new block; 0 = any move |
| `strategy_use_ema_filter` | true | true/false | EarnForex EnableMA — gate flips by an EMA of TLB block closes |
| `strategy_ema_period` | 14 | 5-50 | EarnForex MA_Period — EMA of TLB block closes |
| `strategy_atr_period` | 14 | 7-28 | ATR period for the catastrophic stop |
| `strategy_sl_atr_mult` | 2.5 | 1.0-4.0 | Catastrophic stop distance = mult x ATR (card P2 baseline) |
| `strategy_spread_pct_of_stop` | 15.0 | 5-50 | Skip entry if spread exceeds this % of the stop distance (fail-open on zero spread) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid major; clean H4 swing structure for TLB reversals.
- `GBPUSD.DWX` — liquid major with strong directional H4 swings.
- `USDJPY.DWX` — liquid major; trends well on H4, suits flip-following.
- `XAUUSD.DWX` — gold; pronounced H4 trends and reversals, a classic TLB instrument.

**Explicitly NOT for:**
- Index CFDs (NDX/WS30/GDAXI) — not in the card's R3 basket; TLB cadence and the
  ATR stop are tuned to the FX-major + gold basket above. Could be re-evaluated
  in a later phase but is out of scope for this build.

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
| Trades / year / symbol | `25` |
| Typical hold time | `days (rides until the opposite TLB flip)` |
| Expected drawdown profile | `trend-following: many small losses, occasional large trend wins` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `low` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Source type:** `forum/repo` (EarnForex public indicator)
**Pointer:** `https://github.com/EarnForex/Three-Line-Break` (article: https://www.earnforex.com/metatrader-indicators/Three-Line-Break/)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11084_tlb-flip.md`

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
| v1 | 2026-06-17 | Initial build from card | board-advisor lane build |
