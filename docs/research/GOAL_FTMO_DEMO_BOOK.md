# Goal: an FTMO-demo-testable book

Status: ACTIVE · set by OWNER 2026-07-26 · owner of execution: Claude

## The goal in one sentence

Assemble and deploy a **multi-sleeve QuantMechanica book onto an FTMO demo account**, where
every sleeve carries a complete, binary-current evidence chain, and the book as a whole is
shown by simulation to survive FTMO's Phase-1 loss limits — so that live demo behaviour can
be compared against the modelled expectation.

The purpose of the demo is **falsification, not profit**: it answers "does what we modelled
actually happen on an FTMO server", which is the one question backtests cannot.

## Definition of done — all seven must hold

1. **≥ 5 sleeves, every one `CHALLENGE_READY`.** That is the existing fail-closed contract in
   `ftmo_qualification.py`: build clean, magic registered, all eight strict phases
   (Q02–Q08, Q10) verdict `PASS` — soft passes do not count — evidence files present and
   **newer than the deployed `.ex5`**, Q08 durable baseline stream linked, fresh intraday MAE
   stream, ≥ 50 trades.
2. **Diversified: ≥ 3 distinct symbols and ≥ 2 asset classes.** A gold-only book is not a
   book. (Today's two ready sleeves are both XAUUSD — explicitly not sufficient.)
3. **`ftmo_book_readiness.py --book-manifest` returns `status: READY`.** All-or-nothing:
   `partial_book_approval: false`, and every sleeve must also pass stream reconciliation.
4. **Book-level drawdown survives the cap with margin.** FTMO Phase 1 allows 10 % total loss
   and 5 % daily. Required: modelled **book** MaxDD ≤ 6 % on full history at the deployed
   sizing, and no single day breaching 3 %. Sleeve drawdown is not book drawdown — this must
   come from `ftmo_bar_joint_book_sim.py` run over the **actual candidate set**, not from
   summing sleeves and not from the historical four-sleeve admissible book.
5. **Enough activity to learn something.** Aggregate ≥ 150 trades/year across the book, so a
   demo month produces a double-digit trade count rather than noise.
6. **Deployable artefacts exist and verify.** Presets (`ENV=live`, `RISK_PERCENT` set,
   `RISK_FIXED=0`), a deploy manifest, magic-number consistency (`ea_id*10000+slot`), SHA256
   match from `framework/EAs/` to the demo terminal, news calendar present in
   `Common\Files` — the file the EA actually reads.
7. **A decision record** under `decisions/` naming the composition, the sizing, the
   simulation result, and the falsifiable expectation the demo is meant to test.

## Explicitly NOT in scope

- **The paid challenge.** `P(pass) ≥ 0.80` in ≤ 30 days needs six to eleven uncorrelated
  intraday-flat density motors; we have two. That is a multi-week sourcing programme and it
  is a separate goal.
- **Any real-money account, and any change to T_Live.** The demo is a separate terminal.
  T_Live's AutoTrading remains OWNER + Claude only and is untouched by this work.
- **Profit as an acceptance criterion.** A demo that loses money but behaves as modelled is a
  success; a demo that makes money for reasons the model did not predict is a failure.

## How progress is measured

The single number is `ready_count` from a fresh qualification run. It went **0 → 2** on
2026-07-26. The goal needs 5 with diversification.

| checkpoint | state |
|---|---|
| qualification chain proven end-to-end | ✅ done (10128, 10145) |
| ≥ 5 ready sleeves | in flight — 18 backtests for 11421/EURUSD, 13013/NDX, 12567/XAUUSD |
| ≥ 3 symbols, ≥ 2 asset classes | reachable with the above (metal + FX + index) |
| joint simulation over the real set | not started |
| manifest + presets + SHA verification | not started |
| decision record | not started |

## Operational lesson from stage 1 (2026-07-26 20:05) — requeue the shallowest gate only

I requeued Q02–Q07 for all three stage-1 candidates in one go. The workers then claimed the
**deep** gates first, and they died exactly as they must: Q07 at 19:17
(`seeds_invalid_evidence`, every seed `exit_code=1`), Q06 19:19 and Q05 19:21
(`summary_missing`), Q04 19:41 (`F1:SOURCE_SUMMARY_MISSING;F2;F3`) — while Q02 only passed
at **19:50**.

The pipeline is a cascade: Q04 consumes Q03's summary, Q05 consumes Q04's. Flipping all six
rows to `pending` simultaneously destroyed the very evidence the deep gates read. Four
wasted deep-gate runs, self-inflicted.

**Correct shape, and it is already built in:** requeue only the shallowest missing gate.
`dispatch_tick` auto-enqueues the next phase on every PASS (`farmctl.py:5933`), so the
cascade drives itself in order. Restored the ten deep-gate rows from the snapshot (skipping
the two a worker was actively running — never yank a row out from under a live process) and
left Q02/Q03 in flight.

Consequence for the timeline: stage 1 is **six sequential gates per EA**, not eighteen
parallel backtests. Q07 multiseed is the expensive one. Hours, not minutes.

## Stage-3 prerequisite audit (2026-07-26 20:20) — one hard constraint found

Checked the joint simulator's inputs ahead of time rather than discovering them at
assembly. Per sleeve it needs the Q08 summary, the Q08 trade stream
(`Common\Files\QM\q08_trades\*.jsonl`, 6,530 present), an M15 bar CSV from the export
terminal, and a cost block (`framework/registry/venue_cost_model.json` exists).

| sleeve | Q08 summary | trade stream | M15 bars |
|---|---|---|---|
| 10128 XAUUSD | ✅ | 33 KB | 8 MB |
| 10145 XAUUSD | ✅ | 25 KB | 8 MB |
| 12567 XAUUSD | ✅ | 14 KB | 8 MB |
| 13013 NDX | ✅ | 11 KB | 6 MB |
| **11421 EURUSD** | ✅ | 2 KB | **MISSING** |

**The export terminal holds nine M15 series and not one of them is FX**: GDAXI, NDX, SP500,
UK100, WS30, XAGUSD, XAUUSD, XNGUSD, XTIUSD. So condition 4 — book drawdown from the joint
simulator over the real candidate set — **cannot currently be evaluated for any FX sleeve**.

Two ways out, and the choice matters for the goal:

- **Export the missing FX M15 series.** Restores EURUSD as a diversification candidate and
  unblocks every future FX sleeve. The export terminal already produced the other nine.
- **Build the demo book from symbols that have bars.** Metals (XAU, XAG), indices (NDX,
  GDAXI, SP500, WS30, UK100) and energy (XTI, XNG) already satisfy "≥ 3 symbols, ≥ 2 asset
  classes" without any FX. Tonight's recompile of the 27 stale-resolver EAs makes **energy a
  live asset class again** — those are almost all WTI and natural gas strategies that had
  been failing silently for weeks.

Preferred: do both, but do not let the FX export block the book. The second path is
available now.

There is also **no manifest builder** — the 2026-07-22 manifest was assembled by hand. One
will be needed, and it is a natural companion to the cascade driver.

## ★ The finding that reshapes this goal (2026-07-26 22:40): swap, not merit

The stage-3 chain now runs end to end — manifest builder → stream reconciliation (PASS on
both ready sleeves) → joint simulator. The first result over a real, tool-built candidate
set is decisive, and it is not what the qualification contract measures:

| sleeve | trades | FTMO net | FTMO swap | FTMO commission |
|---|---:|---:|---:|---:|
| 10128 XAUUSD | 433 | **−7,556** | −9,792 | 463 |
| 10145 XAUUSD | 314 | +1,775 | −16,612 | 452 |
| **book** | | **−5,780** | **−26,404** | 915 |

**Without swap the same book earns +20,624.** Commission is noise by comparison — 915
against a swap bill 29× larger. Both sleeves hold gold overnight, and FTMO's gold swap
consumes the entire edge.

So our two `CHALLENGE_READY` sleeves — which pass all eight strict gates, reconcile cleanly
and are the only qualified sleeves the farm has ever produced — are **not FTMO-viable**.
That is not a defect in them; they were validated against Darwinex costs, where they work.

**This is a gap in the qualification contract.** `challenge_ready` certifies robustness and
evidence integrity, and says nothing about whether a strategy survives the venue it is
being sent to. A sleeve can be flawless by every gate we run and still be structurally
unable to make money at FTMO.

Consequences, and they are large:

1. **Adding more overnight sleeves to this book is pointless.** The three stage-1
   candidates in flight (11421 EURUSD, 13013 NDX, 12567 XAUUSD) must be re-checked under
   FTMO swap before they count toward the goal — passing Q02–Q10 is necessary, not
   sufficient.
2. **An FTMO book has to be intraday-flat.** No overnight position means no swap, which is
   precisely why 12969 (gotobi, PF 1.54 at 2.0 % DD) and 20039 (onr-mid-brk) are the
   archetypes. The density programme is not a parallel nice-to-have; it is the only route
   to a viable book.
3. **An eighth condition belongs in this goal:** every sleeve must show **net > 0 under FTMO
   costs** in the joint simulator, not merely `CHALLENGE_READY`. A demo book of
   swap-negative sleeves would falsify nothing — it would only re-measure the swap bill.

The 30-day scenario grid confirms it from the other side: at 2 % risk the book breaches
neither the daily nor the total cap (0.00 % both) but reaches +10 % in 0 % of runs; pushing
sizing to 16 % lifts pass probability only to 12.5 % while daily-breach risk climbs to
60 %. Safe and far too slow — the density conclusion, now measured on this book rather than
inferred.

## Where that leaves the candidate pool (2026-07-26 23:00) — the intersection is empty

Putting the eight conditions against what actually exists:

| candidate | intraday-flat | FTMO-viable | Q08 strict PASS | stream reconciles | verdict |
|---|---|---|---|---|---|
| 10128 XAUUSD | no (overnight gold) | **no** — net −7,556, swap −9,792 | yes | yes | qualified, unusable |
| 10145 XAUUSD | no (overnight gold) | marginal — net +1,775 on swap −16,612 | yes | yes | qualified, marginal |
| 12969 USDJPY (gotobi) | **yes** — the archetype | untested | **no — FAIL_SOFT** | **no** — net delta 43.19 vs tolerance 3.31 | blocked twice |
| 20039 NDX (onr-mid-brk) | **yes** | untested | not reached — stalled at Q05 | n/a | too early |

**No sleeve satisfies all eight conditions, and the two sets barely overlap:** what is
`CHALLENGE_READY` is not FTMO-viable, and what is FTMO-viable in principle is not
`CHALLENGE_READY`. That is not a scheduling problem to be waited out — it is a statement
about the pool.

Actions taken from this: 12969's Q08 requeued to regenerate a stream that reconciles (its
current one breaks the reconciler's one-entry/one-exit assumption, and the tool is right to
refuse it); 20039's Q05 remains the other live thread. Both are prerequisites, neither is
sufficient — 12969 also needs its Q08 to move from `FAIL_SOFT` to a strict PASS, which is a
merit question, not an evidence one.

**Honest read:** the demo book is gated on the density programme producing intraday-flat
sleeves that survive Q08 strictly. Everything built tonight — the manifest builder, the
reconciliation path, the FX bars, the cascade driver — is the machinery that will evaluate
those sleeves the moment they exist, and it is now proven to work end to end. What it
cannot do is manufacture a sleeve that is both robust and swap-immune.

## ★ Best FTMO candidate found by measuring, not by reading code (2026-07-26 23:20)

The swap finding makes intraday-flat a hard requirement, so the obvious next question is
which EAs actually are. I first tried to answer it with a regex over EA source and
**validated the detector before trusting it** — it failed: it missed both known
intraday-flat EAs (12969 expresses its rule as `Strategy_InExitWindow`/`exit_minute`,
20039 as `cash_close_new_york`) and caught only 20007, which happens to use the literal
token `eod_flat`. A pattern list that misses one author's idiom produces a confidently
wrong answer, so that approach was discarded rather than published.

The property is directly observable instead: a trade that opens and closes on the same day
pays no swap. Walking the Q08 trade streams of every strict-Q08-PASS sleeve:

| EA | symbol | trades | overnight | share |
|---|---|---:|---:|---:|
| **13036** | **GDAXI** | **1,352** | **1** | **0.1 %** |
| 10938 | GDAXI | 61 | 10 | 16.4 % |
| 13013 | NDX | 68 | 21 | 30.9 % |
| 10911 | GDAXI | 312 | 113 | 36.2 % |
| 10692 | NDX | 687 | 405 | 59.0 % |
| 11421 | EURUSD | 91 | 67 | 73.6 % |
| 10128 / 10145 / 10183 | XAUUSD | 433 / 314 / 347 | 386 / 289 / 344 | 89–99 % |
| 20048 | XTIUSD | 60 | 60 | 100 % |

**QM5_13036 on GDAXI is the find: 1,352 trades and exactly one overnight hold.** It is
dense *and* swap-immune, and it already carries Q02, Q04–Q08 and Q10 as PASS — Q08 at
PF 1.04 on 1,352 trades, net +3,433, drawdown 8.1 %. A low edge repeated very often with
no overnight exposure is precisely the FTMO shape; the gold sleeves have the opposite
profile and that is why swap eats them.

Its only structural gap is Q03: **no work item for that phase has ever existed**, and
`enqueue-backtest` handles only cascade phases from Q04 up. Requeued its Q02 so
`dispatch_tick` auto-enqueues Q03 on the PASS and the chain advances in order — driving the
deep gates directly is what broke the cascade earlier tonight.

Runner-up worth checking once this lands: **10938 GDAXI** at 16.4 % overnight, which pays
some swap but far less than the gold sleeves.

## Known blockers between here and done

1. **Deep-gate starvation.** The pending queue is 96 % Q02 with one pending Q08 and no
   pending Q10, so the gates that produce `challenge_ready` get almost no capacity. The
   poison-pill quarantine (371 dead triples) exists to fix exactly this.
2. **Q10 coverage.** 175 of 209 candidates have never reached the closing verdict. Every
   additional ready sleeve beyond the evidence-only three requires Q10 work.
3. **Evidence durability.** Sleeves silently lose `challenge_ready` when report files are
   deleted or a rebuild post-dates them. This is how both of today's ready sleeves were
   blocked. It will recur unless evidence retention is tied to the binary.
