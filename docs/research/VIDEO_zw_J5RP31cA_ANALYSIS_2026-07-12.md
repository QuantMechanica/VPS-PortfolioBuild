# Video Analysis — zw_J5RP31cA (ICT/SMC "Standard Deviation off the First Swing")

**URL:** https://www.youtube.com/watch?v=zw_J5RP31cA
**Duration:** ~51:58 · **Format:** screen-share trading presentation (webinar-style)
**Analyzed:** 2026-07-12 by Claude

## Provenance & method (READ FIRST)
agy (Antigravity) could **not** watch this video: the current agy build has **no native
multimodal video tool** (only web-search / URL-fetch / terminal), and YouTube bot-blocks
the VPS IP (`LOGIN_REQUIRED`) for transcript/scrape paths. agy correctly refused to
fabricate (blocked reports preserved: `*.blocked_attempt1.md` + agy retry log).

This analysis is therefore built from the **audio captions only**, obtained via the
proven proxy-rotation method (`tools/strategy_farm/fetch_transcript.py`, 933 caption rows,
proxy 19/150). **All on-screen content is a GAP** — the presenter is a chart screen-share,
so exact fib readings, indicator settings panels, symbols, timeframes actually charted,
and every "look at that" price level are NOT in captions. Timestamps `[MM:SS]` below are
from the caption track and are real. Nothing is invented; unstated items are marked GAP.

## What it teaches
An **ICT / Smart-Money-Concepts** discretionary method. The presenter's "own sauce"
`[02:32]`: instead of throwing the standard-deviation ("flip"/fib projection) tool across
the *whole* consolidation like most ICT traders `[08:32]`, he measures the **first
significant swing** into the opposite direction right after an expansion, and projects
std-dev levels off *that* leg for targets `[09:24, 13:57]`.

Framework scaffolding (all standard ICT): Market-Maker Buy/Sell model —
consolidation→expansion cycles, accumulation / distribution / re-accumulation /
re-distribution, smart-money reversals `[03:44–05:16]`.

## Mechanical specification (from captions; on-screen = GAP)
- **(a) Entry setup.** Bullish: after a down-expansion into a **higher-timeframe PD array**
  (support: fair-value-gap / new-day-opening-gap / new-week-opening-gap / order block)
  `[03:11]`, price makes the **first swing** low→high `[09:24]`; look for a **liquidity
  sweep** of the swing low — ideally just a wick below the support `[11:05, 21:16]`;
  sometimes one sweep, sometimes two, sometimes none `[11:05–11:33]` (GAP: no fixed rule).
  Entry example given = **FVG inversion + retest** `[39:21–39:40]`. Bearish = exact inverse.
- **(b) Exits / targets.** Project the measured first-swing by std-dev multiples. Fib tool
  settings stated verbatim: **0, 0.5, 1, 2, 3, 4, 5** `[19:19]`. Level **1** = first take
  profit and a "reaction test" `[19:46, 21:16]`; **2** = second TP; **3** = final target in
  normal conditions; **4/5** = extended targets only in high volatility `[21:45, 22:01–
  22:44]`. **Stop to break-even after TP1** `[27:50]`. Stop-loss = above/below the
  sweep/swing extreme `[36:15]`. "Take profit a few points early, don't be greedy."
- **(c) Timeframe.** Multi-TF, discretionary. Examples mention 15-min entries with 1-hour
  as the "higher timeframe", zooming to 5-min `[24:17]`. No single canonical TF (GAP).
- **(d) Session / news filters.** NONE mentioned (GAP).
- **(e) Risk / lot model.** NONE mentioned — no lot sizing, no % risk stated (GAP). Only
  SL placement + multi-level TP scaling described.
- **(f) Grid / martingale / averaging / recovery / hedging.** **NONE.** Single-entry
  reversal with a hard stop, BE move, and scale-*out* TPs. No averaging down, no recovery.
  Clean on this axis.
- **(g) Machine learning.** **NONE.**
- **(h) Instruments.** Not stated explicitly (GAP). Content is index/FX-agnostic ICT; the
  "extreme volatility right now" remark `[22:01]` hints indices but is not confirmed.
- **(i) On-screen input settings.** GAP (screen-share; captions only). Only the fib preset
  `0/0.5/1/2/3/4/5` was spoken `[19:19]`.
- **(j) Source code.** None — discretionary chart webinar, no EA/code shown.

## Mechanizability verdict: **PARTIALLY MECHANIZABLE — discretionary core**
The **primitives are mechanizable**: swing/pivot detection, std-dev projection of a fixed
leg (0.5/1/2/3/4/5), FVG detection, new-day/new-week opening gaps, equal-highs/lows
liquidity, wick-sweep detection, FVG-inversion retest entry, SL-beyond-sweep, BE-after-TP1,
scale-out TPs. All deterministic.

The **defining input is explicitly discretionary**: which swing is the "**first
*significant* swing"** is, in the presenter's own words, a trained-eye judgment —
*"you're going to have to look at charts and go back test a lot… train your eyes… it will
stand out like a sore thumb. But without you back testing… you will probably not see it"*
`[33:06–33:46]`. He also shows the swing-high itself is often ambiguous ("this one is a
little bit tricky… you could consider this or this… just measure both").

This is the **same class as ICT Silver Bullet** — see
`project_qm_silver_bullet_no_mechanical_edge_2026-06-27` ("ICT SB backtestet nicht; ohne
OWNER-Referenz nicht re-mechanisieren") and the Wyckoff two-track verdict. A *faithful*
port is impossible: the edge lives in the discretionary significance filter.

## Proposed concrete mechanization (a HYPOTHESIS, not a faithful port)
If we build it, the fuzzy pieces must be pinned to concrete rules (my operationalization,
NOT from the video — so this is a Q02 test hypothesis, not a reproduction):
- **Expansion:** last leg ≥ `k_exp × ATR(n)`.
- **"First significant swing":** first `M`-bar fractal pivot pair after the expansion whose
  range ≥ `k_sig × ATR(n)`.
- **PD-array confluence:** swing forms within a higher-TF FVG or new-day/new-week opening
  gap (both precisely definable).
- **Sweep:** wick beyond the swing extreme by ≤ `k_wick × ATR`, close back inside.
- **Entry:** reclaim / FVG-inversion retest. **SL:** beyond sweep. **TP:** 1×/2×/3× std-dev
  projection of the swing; BE after 1×. `RISK_FIXED` for backtest.

This is buildable and Q02 (the acid test) would judge it honestly — but every result would
be testing *my* significance definition, not the presenter's eye.

## Recommendation
This is discretionary ICT/SMC. Per the standing "don't re-mechanize ICT without an OWNER
reference" lesson, surface to OWNER before committing a build:
1. Build the concrete hypothesis above (Q02 judges) — accept it's a new hypothesis, not a port; or
2. OWNER supplies a concrete "first significant swing" definition / reference to port faithfully; or
3. Shelve as no-mechanical-edge (like Silver Bullet), keep this doc as the record.

## Build & test results (QM5_13204, 2026-07-12) — NO mechanical edge
OWNER approved building the concrete hypothesis (A: with confluence, then B: index).
Built `framework/EAs/QM5_13204_sd-first-swing-rev` (compiles 0/0; trades; no ML, no
grid/martingale). Ad-hoc Q02 smokes (Model 4 real-tick, 2024, M15, gross/commission-free):

Full config matrix, EURUSD.DWX 2024 M15 (natural = reversal; fade = OWNER's contra-indicator idea):

| direction | confluence | exit | trades | PF |
|---|---|---|---|---|
| natural | off | 2R | 190 | **0.99** ← best (coin-flip) |
| natural | on  | 2R | 78  | 0.59 |
| natural | on  | 1R | 82  | 0.54 |
| fade    | on  | 2R (SL 0.3·ATR) | 104 | 0.93 |
| fade    | on  | 2R (SL 1.5·ATR) | 185 | 0.86 |
| fade    | on  | 1R | 85  | 0.74 |
| fade    | on  | 2R (clean sweep) | 62 | 0.70 |
| fade    | on  | ATR-trail | 87 | 0.77 |
| fade    | off | ATR-trail | 92 | 0.50 |

WS30.DWX (index) either 0 trades (confluence over-filters / tight sweep rarely fires on a
gappy index) or blocked by broker-stops geometry. NDX.DWX could not be tested ad-hoc
(symbol-specific tester "history synchronization error"; factory backtests NDX fine).

**Verdict: NO mechanical edge in ANY of 9 tested configurations** (all PF < 1.0, best is the
bare coin-flip 0.99). OWNER's **contra-indicator insight was genuinely valuable** — fading
the confluence lifts the worst case 0.59 → 0.93 — but the signal is not strong or clean
enough to profit under any reasonable geometry (both directions, confluence on/off, 1R/2R
targets, SL 0.3–1.5·ATR, clean-sweep filter, fixed vs ATR-trailing exit all tested). The
confluence marks *high-noise* zones, not *directionally-predictive* ones. This confirms the
a-priori read: the ICT "first significant swing" edge lives in the discretionary trader's
eye, not in mechanizable rules — same class as ICT Silver Bullet. Further tuning = curve-fit.

Evidence smokes under `D:/QM/reports/smoke/QM5_13204/` (runs 141820, 150324, 150708, 151115,
163431, 163722, 164125, 164247, 164348, 164711, 164816).

## Evidence
- Captions: `docs/research/evidence/transcript_zw_J5RP31cA_timestamped.txt` (933 rows).
- agy block reports: `docs/research/VIDEO_zw_J5RP31cA_ANALYSIS_2026-07-12.blocked_attempt1.md`.
