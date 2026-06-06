# QM5_10914_grimes-vol-comp — Strategy Spec

**EA ID:** QM5_10914
**Slug:** `grimes-vol-comp`
**Source:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c` (see `strategy-seeds/sources/fbfd7f6e-462a-55c8-9efa-9005a70c9f5c/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades the first range-expansion break out of a volatility-compressed
consolidation, after Adam Grimes' "Volatility Compression" work. On each closed
H1 bar it first checks for compression: the ratio ATR(5)/ATR(60) must be below
0.75 for at least 3 of the last 5 bars, and the high-low range of the prior
20-bar window must be no wider than 1.25 × ATR(60). When that compressed state
holds, it watches the just-closed bar for a break: a long fires when the close
breaks above the prior 20-bar high by at least 0.1 × ATR(14); a short fires when
the close breaks below the prior 20-bar low by the same margin. Direction is not
pre-selected — whichever side breaks first is taken (one position per
symbol/magic). The protective stop is the opposite side of the compression range
or entry ∓ 1.2 × ATR(14), whichever sits closer to entry, but never tighter than
0.8 × ATR(14). Management takes a partial (50%) at 1.5R, trails the remainder
with a 2.0 × ATR(14) chandelier from the highest close (long) / lowest close
(short) since entry, and time-exits after 20 H1 bars if neither stop nor target
is hit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `InpAtrFastPeriod` | 5 | 3-15 | Fast ATR leg of the compression ratio |
| `InpAtrSlowPeriod` | 60 | 30-120 | Slow ATR leg / baseline volatility |
| `InpAtrSignalPeriod` | 14 | 7-30 | ATR for breakout offset, stop, and trail |
| `InpCompressionRatioMax` | 0.75 | 0.5-0.95 | ATR(5)/ATR(60) must be below this to be "compressed" |
| `InpCompressionLookback` | 5 | 3-10 | Window over which the ratio condition is counted |
| `InpCompressionMinCount` | 3 | 1-5 | Min compressed bars within the lookback |
| `InpRangeLookback` | 20 | 10-40 | Consolidation window for range + breakout level |
| `InpRangeAtrMult` | 1.25 | 1.0-2.0 | Range must be ≤ this × ATR(60) |
| `InpBreakoutAtrMult` | 0.10 | 0.0-0.5 | Close must exceed the range by this × ATR(14) |
| `InpStopAtrMult` | 1.20 | 0.8-2.5 | ATR-based stop candidate distance |
| `InpStopAtrMinMult` | 0.80 | 0.3-1.5 | Minimum stop distance floor (× ATR(14)) |
| `InpTpRMultiple` | 1.50 | 1.0-3.0 | Partial-target distance in R |
| `InpPartialCloseFraction` | 0.50 | 0.1-0.9 | Fraction closed at the 1.5R target |
| `InpChandelierAtrMult` | 2.00 | 1.0-4.0 | Chandelier trail distance (× ATR(14)) |
| `InpTimeExitBars` | 20 | 5-60 | Time stop in closed H1 bars |
| `InpSpreadCapFrac` | 0.10 | 0.02-0.30 | Skip entry if spread > this × stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — S&P 500 index; clean volatility-compression/expansion cycles (backtest-only).
- `NDX.DWX` — Nasdaq 100; high-beta index where range expansion follows compression well; live-tradable.
- `GDAXI.DWX` — DAX 40; card requested "GER40", ported to the canonical DWX DAX symbol; live-tradable.
- `XAUUSD.DWX` — Gold; pronounced volatility regimes suit compression breakout logic.

**Explicitly NOT for:**
- `SPX500.DWX` / `SPY.DWX` / `ES.DWX` — not canonical DWX symbols; S&P exposure is `SP500.DWX` only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` (daily-bar variant deferred to Q03) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~35` (card: 25-55 ATR-compression breakout mode) |
| Typical hold time | `hours to ~1 day` (≤ 20 H1 bars time stop) |
| Expected drawdown profile | `clustered losses in choppy/false-break regimes; convex winners on expansion` |
| Regime preference | `volatility-expansion / breakout` |
| Win rate target (qualitative) | `low/medium` (R-multiple driven; partial at 1.5R + trail) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c`
**Source type:** `forum` (author blog — Adam H. Grimes)
**Pointer:** `https://www.adamhgrimes.com/volatility-compression/` (+ `/volatility-compression-2/`)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10914_grimes-vol-comp.md`

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
| v1 | 2026-06-06 | Initial build from card | 48485318-e4d2-4dcf-abf5-768a30ee59f3 |
