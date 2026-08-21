# Cards-review G0 adjudication — wave 2

Date: 2026-08-21

Task: `3fb70df8-bfcd-4511-b9b5-21f4dbe0fe4d` (`review_strategy`, assigned claude)

Authority: OWNER drain directive D1; wave 1 (`88273f13`) closed APPROVED by Claude
with one rubric correction. This wave continues the 191-row `ADJUDICATE` backlog
in `2026-08-21_ea_id_disposition_963.csv`.

Selection: the 25 `ADJUDICATE` rows at index 25–49 (0-indexed) of the filtered
decision list (`QM5_11930` … `QM5_11954`), preserving decision-list order, PLUS a
mandated one-attempt RESPECIFY re-open of three wave-1 R2-only rejections
(`QM5_11924`, `QM5_11926`, `QM5_11927`).

Rubric v2 applied verbatim: **R1** traceable source, **R2** closed-form mechanical
completeness, **R3** governed DWX data, **R4** ML-forbidden; plus duplicate-of-
approved-primitive. APPROVE clears R1–R4; REJECT fails R1/R3/R4 or duplicates;
RESPECIFY only when R2 is the *sole* failure AND the cited source carries the closed
form — one attempt, then approve-card if it clears.

## Concurrency note (dual-lane convergence)

While this session was executing, a concurrent `agents/board-advisor` lane processed
the identical wave-2 + re-open selection. The 21 rejections below were applied by
this session's `reject-card` calls (their `g0_rejection_reason` strings are the ones
authored here). The 7 approvals were found already applied by the concurrent lane via
governed `approve-card` (each carries a `g0_approval_reasoning` receipt). This session
reached the **identical** approve/respecify/reject partition independently before
observing the concurrent state — an unplanned dual-forensics cross-check that
converged 28/28. Every approved card was re-validated here against the card-content
gates (see Verification). No card was hand-moved or edited outside the governed
`approve-card` / `reject-card` / respecify-edit paths.

## Result

All 28 cards carry a terminal G0 decision.

| Outcome | Count |
|---|---:|
| Approved (respecified → approved) | 4 |
| Rejected | 21 |
| Undecided | 0 |
| **Wave-2 subtotal** | **25** |
| Re-opened R2-only rejections respecified → approved | 3 / 3 |

Wave-2: 4 of 25 cleared R1–R4 after an R2-only respecification; the other 21 failed a
gate as written and were rejected without weakening the rubric. All 3 re-opened
wave-1 rejections were successfully respecified and approved.

## Rubric-failure distribution (the 21 rejections)

Failures do not overlap this wave — each rejection turns on a single decisive gate.

| Finding | Cards |
|---|---:|
| R1 source/track-record failure | 0 |
| R2 mechanical-closure failure | 20 |
| R3 governed-data failure | 1 |
| R4 ML violation | 0 |
| Duplicate of an approved primitive | 0 |

R1 passed across the wave: every card names a documented, traceable system (a
Forex-Factory thread by named author, a published book, a named methodology, or the
live-traded René Balke family), so none failed on "no traceable source". The single
R3 failure is `QM5_11931` (SPY cash-session overnight-gap edge not reproducible on the
governed continuous 24 h DWX index CFDs). Every other rejection is R2: a discretionary
core, a proprietary indicator lacking a closed-form definition, an unresolved free
parameter with no source value to pin, a repainting indicator, or a prohibited
add-to-position construct.

## Per-card decisions — wave 2

| EA | Decision | Failed check | Short reason |
|---|---|---|---|
| QM5_11930 carver-ewm-volat | REJECTED | R2 | Vol-budget sizing ("e.g. 10%"), vol-EWMA span, and "daily or weekly" rebalance unresolved; 28-instrument vol-target allocator not expressible as closed single-symbol rules. |
| QM5_11931 qp-spy-overnight-gap | REJECTED | R3 | SPY cash overnight-gap edge not reproducible on continuous 24 h DWX index CFDs; cash "open"/60-min window undefined for the CFD. |
| QM5_11932 ff-tms-big-e | REJECTED | R2 | TDI periods unspecified; primary exit ("flattens / hooks back") discretionary; 50–80 pip stop range unresolved. |
| QM5_11933 ff-holo-tooslow | REJECTED | R2 | Take-profit unresolved between an undefined trailing stop and a 10–20 pip range. |
| QM5_11934 ff-nel-4h-macd | REJECTED | R2 | ZLR entry ("pull back without crossing", "bounce off 21 EMA") discretionary; swing stop + H4 trailing exit undefined. |
| QM5_11935 ff-sonic-r | REJECTED | R2 | "First retest of the Dragon that fails to close below" discretionary; target = undefined S/R; stop an unresolved alternative. |
| QM5_11936 ff-millipede-pipeasy | REJECTED | R2 | Core "stacking" adds a position at each Daily Open (pyramiding) — contradicts its own No-Averaging block, not a single-position rule. |
| QM5_11937 ff-agnew-h1-break | REJECTED | R2 | Take-profit an unresolved 5–20 pip range with no source value to pin. |
| QM5_11938 ff-paulus-4h-trend | REJECTED | R2 | SuperTrend ATR multiplier missing; "BB MACD dots turn Green/Red" has no defined threshold — both need invention. |
| QM5_11939 ff-j16-pin-rejection | REJECTED | R2 | Fixed 5-pip stop inconsistent with a D1/H4 pin entry at 50% wick (stop inside entry); D1-or-H4 unresolved — needs redesign. |
| QM5_11940 ff-two-stroke-chow | REJECTED | R2 | "Tight consolidation/compression" width undefined; opens two simultaneous positions with divergent management, neither closed-form. |
| QM5_11941 ff-inst-code-levels | REJECTED | R2 | Entries gated on undefined "align with the 1-hour trend"; which "institutional code" level to trade unspecified. |
| QM5_11943 ff-wae-explosion | REJECTED | R2 | WAE has no parameters / no "Explosion Line" threshold; Buy and Sell triggers mis-stated identically; swing stop undefined. |
| QM5_11944 ff-d1-simplicity | REJECTED | R2 | Entry order internally contradictory — a Buy "limit at the high of the signal candle" sits above market; intended order model unrecoverable. |
| QM5_11946 ff-genesis-matrix | REJECTED | R2 | Proprietary composite (TVI/T3/GannHiLo "squares turn white/red") with no formulas or settings — mechanization = invention. |
| QM5_11947 ff-baguba-pullback | REJECTED | R2 | Entry needs an undefined currency-strength index (multi-pair aggregation) + discretionary "clear TMA slope"; not closed-form single-symbol. |
| QM5_11948 ff-davit-pivots | REJECTED | R2 | Pivot period (Daily/Weekly), timeframe (H1/H4), and stop (30–50 pips or beyond S2/R2) all unresolved free choices. |
| QM5_11951 ff-extreme-tma | REJECTED | R2 | TMA is centered/repainting (invalid closed-bar backtest); band multiplier + "slope > 0.30" units undefined; conservative/standard exit unresolved. |
| QM5_11952 ff-mad-scalper | REJECTED | R2 | "Shade" color + "DoubleCCI" periods undefined; swing stop undefined; 10–25 pip target range unresolved. |
| QM5_11953 ff-g7-strategy | REJECTED | R2 | Fibonacci zone anchored to an undefined "current move"; "bounces off" MA/BB discretionary; stop over-parameterized (5–10 / min 20 / max 60). |
| QM5_11954 ff-jarroo-boss | REJECTED | R2 | HCR/LCS level identification has no lookback window or selection rule, so the levels the entry depends on are not mechanically determined. |
| QM5_11942 ff-10gmt-ema50 | RESPECIFIED → APPROVED | (was R2) | "or" SL/TP resolved to deterministic crossover-candle-extreme (20-pip floor) + first-touch-of-either (14:00 GMT or 1.5R); first-cross-after-10:00 latched. |
| QM5_11945 ff-the-strat-212 | RESPECIFIED → APPROVED | (was R2) | Strat 2-1-2 pinned to bars [3]/[2]/[1] with closed-form scenario inequalities; target "or" resolved to candle[3] prior extreme; FTFC = Weekly+Daily same color. |
| QM5_11949 ff-london-7am-break | RESPECIFIED → APPROVED | (was R2) | TP "or" resolved to first-touch-of-either (2:1 or 13:30 GMT); reference candle / OCO stops / 12:00 expiry already mechanical. |
| QM5_11950 ff-ozfx-mechanical | RESPECIFIED → APPROVED | (was R2) | "5-lot rule" re-expressed as one position with four 20% partial closes + runner (HR14 1-pos-per-magic); AC-zero-cross and Stoch(5,3,3) entries given closed form. |

## Re-opened wave-1 R2-only rejections (one RESPECIFY attempt each)

All three were R2-only in wave 1, R1 (`live_balke`) / R3 / R4 already clean, so each
qualified for the single respecify attempt. All three carried a closed form from the
Balke source and now clear R1–R4.

| EA | Wave-1 R2 defect | Respecification (closed form) | Outcome |
|---|---|---|---|
| QM5_11924 rb-mean-reversion | "RSI period left as 14 or 20" | Pinned **RSI(14)** (Wilder canonical default; matches sibling Balke card QM5_11926); fade direction made explicit (below-band → Long / above-band → Short) under the D1 20-SMA filter; closed-bar convention + fixed-fractional sizing tied to the 2% stop. | APPROVED |
| QM5_11926 rb-rsi-ma-filter | "Alternative exits unresolved; sizing absent" | Resolved to the single **Standard** exit (5.0% SL / 1.0% TP, the source's primary regime); trailing alternative removed; RISK_FIXED/RISK_PERCENT sizing tied to the 5% stop. | APPROVED |
| QM5_11927 rb-atr-candle-break | "Direction & closed-bar entry trigger absent" | "Current candle" pinned to the last closed **H1 bar [1]**; entry = market at next bar open; direction from the outlier candle's own sign (bullish → Long / bearish → Short); quartile proximity filter as explicit inequalities. | APPROVED |

Each approved card retains a `## Respecification Provenance (2026-08-21)` body section
naming date, authority, the defective passage, the correction, and the reasoning that
the resolved value is *traced* (canonical indicator default / source-primary regime /
thesis-determined direction), not invented.

## Verification

Governed receipts (grepped from the runtime cards in
`D:/QM/strategy_farm/artifacts/cards_review/`):

- 7 / 7 approved cards (`11924, 11926, 11927, 11942, 11945, 11949, 11950`) hold
  `g0_status: APPROVED` + a `g0_approval_reasoning` line (governed `approve-card`
  receipt).
- 21 / 21 rejected cards hold `g0_status: REJECTED` + an explicit
  `g0_rejection_reason` authored this session.

Card-content validators (`farmctl`, run from `C:/QM/repo/tools/strategy_farm`, same
harness as `2026-08-21_six_cards_amendment_applied.md`) for the 7 approved cards:

```
11924  r_gate.ok=True  body_coverage.ok=True  missing=[]
11926  r_gate.ok=True  body_coverage.ok=True  missing=[]
11927  r_gate.ok=True  body_coverage.ok=True  missing=[]
11942  r_gate.ok=True  body_coverage.ok=True  missing=[]
11945  r_gate.ok=True  body_coverage.ok=True  missing=[]
11949  r_gate.ok=True  body_coverage.ok=True  missing=[]
11950  r_gate.ok=True  body_coverage.ok=True  missing=[]
```

`strategy_card_r_gate_consistency` passes (no body R-table → benign
`r_gate_body_rows_missing` warning only); `_verify_card_body_coverage` is clean
(source, entry, exit, stop, `.DWX` target symbol, period literal, and trade frequency
all present); `approve-card`'s own contract + archive-admission gates already cleared
at approval time (that is what produced `g0_status: APPROVED`).

**Known downstream artifact (not a card-content defect):** `prebuild_validate_card`
returns `ok=False` for all 7 with `card_not_in_approved_dir` + `card_filename_mismatch`
+ `r{2,3,4}_*_not_PASS:'true'`. These are consequences of the sanctioned in-place
approval path: `approve-card` relocates only `cards_draft` inputs, so a `cards_review`
card stays in place with its `QM5_` filename, and `approve-card` does not rewrite the
`r2/r3/r4` frontmatter (they remain `true`, not the literal `PASS` the build-queue
gate wants). This is identical for both this session's and the concurrent lane's
approvals. Promotion into `cards_approved/` with the canonical `<ea_id>_<slug>.md`
filename and `r*: PASS` normalization is the downstream build-queue step (pump /
factory), left out of scope here because it is outside the governed
`approve-card`/`reject-card`/respecify-edit paths this task is bounded to.

Runtime source-of-truth paths for the 7 respecified/approved cards (operative store
the factory reads; each carries an embedded provenance section):

```
D:/QM/strategy_farm/artifacts/cards_review/QM5_11924_rb-mean-reversion.md
D:/QM/strategy_farm/artifacts/cards_review/QM5_11926_rb-rsi-ma-filter.md
D:/QM/strategy_farm/artifacts/cards_review/QM5_11927_rb-atr-candle-break.md
D:/QM/strategy_farm/artifacts/cards_review/QM5_11942_ff-10gmt-ema50.md
D:/QM/strategy_farm/artifacts/cards_review/QM5_11945_ff-the-strat-212.md
D:/QM/strategy_farm/artifacts/cards_review/QM5_11949_ff-london-7am-break.md
D:/QM/strategy_farm/artifacts/cards_review/QM5_11950_ff-ozfx-mechanical.md
```

These review-stage cards are not present in the git-tracked mirror
`strategy-seeds/cards/` (that mirror holds approved-stage cards); a byte-for-byte copy
of the 7 is committed alongside this doc so the respecification is durable in-repo.

## Backlog frontier

- ADJUDICATE rows total in `2026-08-21_ea_id_disposition_963.csv`: **191**.
- Decided: wave 1 (25) + wave 2 (25) = **50**.
- **Remaining undecided in the ADJUDICATE list: 141** (index 50–190), for the next
  wave's continuation. The 3 re-opened wave-1 cards were already inside the wave-1
  count and do not change the remaining total.
