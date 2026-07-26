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

## Known blockers between here and done

1. **Deep-gate starvation.** The pending queue is 96 % Q02 with one pending Q08 and no
   pending Q10, so the gates that produce `challenge_ready` get almost no capacity. The
   poison-pill quarantine (371 dead triples) exists to fix exactly this.
2. **Q10 coverage.** 175 of 209 candidates have never reached the closing verdict. Every
   additional ready sleeve beyond the evidence-only three requires Q10 work.
3. **Evidence durability.** Sleeves silently lose `challenge_ready` when report files are
   deleted or a rebuild post-dates them. This is how both of today's ready sleeves were
   blocked. It will recur unless evidence retention is tied to the binary.
