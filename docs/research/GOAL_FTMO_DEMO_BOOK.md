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

## Known blockers between here and done

1. **Deep-gate starvation.** The pending queue is 96 % Q02 with one pending Q08 and no
   pending Q10, so the gates that produce `challenge_ready` get almost no capacity. The
   poison-pill quarantine (371 dead triples) exists to fix exactly this.
2. **Q10 coverage.** 175 of 209 candidates have never reached the closing verdict. Every
   additional ready sleeve beyond the evidence-only three requires Q10 work.
3. **Evidence durability.** Sleeves silently lose `challenge_ready` when report files are
   deleted or a rebuild post-dates them. This is how both of today's ready sleeves were
   blocked. It will recur unless evidence retention is tied to the binary.
