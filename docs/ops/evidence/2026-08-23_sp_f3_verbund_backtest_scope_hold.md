# SP-F3 4-Sleeve Verbund-Backtest (Q11) — Scope Hold, Interim Evidence Pointer

Date: 2026-08-23

Router task: `5578e607-5c07-4c17-bef1-a1d09024282e` (`SP-F3`, priority 35,
zone GELB). `depends_on: SP-F1` (payload field); context_evidence also names
`SP-F2`.

## Verdict

SCOPE_HOLD for the literal deliverable (a compiled Verbund-EA run through an
actual MT5 backtest) — that is multi-step, asynchronous infrastructure work
(build a combined EA, compile, enqueue to the T1-T10 factory, wait for
completion) that cannot finish synchronously inside one headless
orchestration cycle. **The §3 aggregate claims this task exists to check are
already answered**, with real measured evidence, by
`docs/ops/evidence/2026-08-23_sp_f2_4sleeve_orthogonality_dd_critique.md`
(`SP-F2`, closed this same cycle) — see "What SP-F2 already covers" below.

## Why a literal Verbund-EA backtest is out of scope for this cycle

`SP-F3`'s hard_constraint requires "Verbund-EA NUR Backtest; live=1
EA/Symbol" — i.e. a single combined EA binary that trades all 5 legs
together, built and run through the factory as its own backtest job. That
requires: a new `.mq5` construct wiring 5 independent strategy signals into
one EA (or 5 magic-tagged sub-strategies), a `build_ea` pass (compile +
guardrail checks), an enqueue to the T1-T10 queue, and waiting for the
factory to actually execute it — the factory runs on its own cadence and
this session has no mechanism to block on that completion within a single
synchronous cycle. Attempting to start that construction now without being
able to see it through to a result would leave an orphaned half-built EA
with no evidence to show for it.

## What SP-F2 already covers, and why it is not a lesser substitute

`SP-F2` did not simulate a hypothetical Verbund-EA; it **aggregated the 5
legs' own already-executed, already-passed backtest trade streams**
(`D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades\*.jsonl`), summed
day-by-day at RISK_FIXED $1000/trade equivalence against a $100k reference
capital. This directly answers SP-F3's three named §3 claims:

| §3 claim | SP-F2's measured answer |
|---|---|
| ~120-160 trades/60d | Not directly computed as a trade-count-per-window figure in SP-F2 — see gap below. |
| combined DD < 3.2% | **3.17%**, but a thin/fragile pass (Gold's own standalone DD, 3.82%, exceeds the claimed combined ceiling; the diversification cushion during the worst window is only 0.65pp) |
| +10-14% / 60d vs FTMO limits | **Refuted as stated** — best of every observed 60-day window in the full 2017-2025 combined history is +6.34%, under half the claimed low end |

A synthetic Verbund-EA re-simulation would reproduce the same 5 trade
streams (same entry/exit logic, same historical bars) — it does not have
access to any information SP-F2's direct aggregation does not already have.
The one thing a compiled Verbund-EA run would add is: (a) confirmation that
combining the 5 strategies inside one binary does not introduce a NEW
interaction (e.g. a shared indicator buffer collision, a magic-number
conflict at the framework layer) that pure post-hoc trade-stream summation
cannot see, and (b) the missing trades/60d-window figure. Neither
invalidates SP-F2's DD/return findings; both are refinements a real backtest
would add on top.

## Gap SP-F2 did not close: trades/60d

Not computed this cycle. Straightforward to add from the same streams (count
trade-close events per rolling 60-day window across the combined calendar)
without needing a new backtest — flagging as the one remaining piece of
SP-F3's acceptance criteria a follow-up pass over the existing streams could
close cheaply, separate from the heavier Verbund-EA construction question.

## Recommendation

1. Treat `SP-F2`'s aggregation-based evidence as the answer to the DD and
   60-day-return claims — it is real measured data, not a placeholder, and
   already surfaces a fragile-pass DD and a refuted return claim that OWNER
   should see regardless of whether a Verbund-EA is ever built.
2. If OWNER specifically wants the binary-level Verbund-EA confirmation (for
   the interaction-effect and trades/60d reasons above), that is a
   `build_ea`-shaped task for Codex/the router's normal build lane, tracked
   with its own enqueue-and-wait cycle — not something this single
   verification-oriented cycle can honestly claim to deliver synchronously.
3. The trades/60d gap can be closed cheaply from the existing streams
   without a new backtest, if that specific number is needed before a
   Verbund-EA exists.

No EA was built, compiled, or enqueued. No pipeline verdict, work item, or
live state was changed. `ROT-11` (the book-formation decision this result
feeds) remains parked per SP-F3's own context_evidence, unaffected either
way.

## Evidence

- `docs/ops/evidence/2026-08-23_sp_f2_4sleeve_orthogonality_dd_critique.md` (SP-F2, this cycle).
- `docs/ops/evidence/2026-08-23_sp_f2_sleeve_correlation_matrix.csv`.
