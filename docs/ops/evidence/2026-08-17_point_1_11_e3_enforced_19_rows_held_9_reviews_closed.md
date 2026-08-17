# Point 1.11 — E3 enforced: 19 rows held at the claim gate, 9 FAIL reviews closed

v6 E3: *"Jeder Review-FAIL sperrt den Pipeline-Eintritt, nicht nur HIGH."* The previous round
measured the population and found the withdraw-or-hold set empty. This round **enforced** it against
the live queue, using the supported operator rather than a new mechanism.

## What was done

| | rows |
|---|---:|
| pending rows under an open FAIL `review_ea`, at 20:15 UTC | 19 |
| held via `governed_work_item_hold.py apply` | **19** |
| still claimable after the hold (verified against the real selector) | **0** |
| active rows — deliberately untouched | 4 |
| verdicts these EAs already produced before the hold | 2 (QM5_33002 XAUUSD/Q02 + NDX/Q02, both PASS) |

Hold code `REVIEW_FAIL_PIPELINE_ENTRY_BLOCKED`, seven groups (one per `(ea_id, phase)`, all Q02),
seven SQLite backups, `already_held=0` everywhere.

## The mechanism, verified at the enforcement point

`work_item_holds` is not an annotation — the claim selector excludes on it, fail-closed:

```sql
-- tools/strategy_farm/farmctl.py:1169-1172
AND NOT EXISTS (
  SELECT 1 FROM work_item_holds h
  WHERE h.work_item_id=w.id AND h.active=1
)
```

`governed_work_item_hold.py` satisfies the v6 intervention rules without modification: SQLite backup,
`BEGIN IMMEDIATE`, revalidation of every `id=symbol` target **inside** the transaction both before
and after the write, audit events (`governed_hold_activated`), rollback on any failure, and a
pre-commit read-back that raises `pre_commit_claimable_row` if any target would still be claimable.
It never changes `work_items.status`.

It also only accepts `status='pending' AND claimed_by IS NULL AND verdict IS NULL`, so the four
running backtests were **structurally** out of reach. That is the desired behaviour — running
backtests are not interrupted — not a gap in the hold.

**Positive control:** three arbitrary unheld Q02 rows return `claimable=1` under the same predicate.
Without it, a selector that answered "no" to everything would have looked like success.

## Codex's reviews were spot-checked before closing, and they discriminate

Three of the nine verdicts assert "build is uncommitted". Measured against `git ls-files`:

| EA | tracked files | working tree | claim |
|---|---:|---|---|
| QM5_34004 | **0** | `??` whole dir | correct, still true |
| QM5_34005 | **0** | `??` whole dir | correct, still true |
| QM5_34007 | 5 | clean | correct **when written** — see below |
| the other six | 5–6 | clean | not claimed |

QM5_34007 was committed in `039a86fae` at **19:57:57 UTC**; its review opened at **19:51:44 UTC**.
The claim was true for six minutes and was then fixed. *A verdict holds only under the state it
arose in* — this is that rule with a six-minute half-life, and it counts as correct.

The claim appears on exactly the EAs where it is true and on no others. That is a discriminating
control on the reviewer, which is why the remaining findings were accepted without re-deriving all
nine from source.

**Correction to my own reporting inside this round:** I first wrote "exactly the two Codex flagged,
and no others", having read truncated verdict strings that hid QM5_34007's occurrence of the same
claim. The full strings carry it three times, not twice. The conclusion is unchanged and slightly
stronger.

## Close states, and why not APPROVED

No `review_ea` task has ever been closed with a FAIL-prefixed verdict — 79 historical closes, zero
precedent. The router's semantics decide it (`agent_router.py:1440-1475`):

- `APPROVED` → for non-pipeline-bound task types, terminal `PASSED`, "approved_accepted_terminal".
  It would not have triggered pipeline entry, but it records a broken EA's review as
  accepted-and-finished. Wrong signal.
- `RECYCLE` → `TODO` requeue, bounded by `RECYCLE_MAX_ATTEMPTS = 3`, after which it degrades to
  `BLOCKED` ("recycle_attempts_exhausted"). A bounded rework loop — correct for a repairable
  implementation defect.
- `BLOCKED` → terminal, needs a named operator.

**Eight closed RECYCLE. One closed BLOCKED.**

QM5_34007 (`sergeev-hft-tick-momentum-interceptor`) is the exception because rebuilding cannot fix
it. Codex's headline was "HFT violates active charter", which is sharper than the charter actually
reads: `decisions/2026-07-06_ftmo_scalping_grid_mandate.md` §3 bans *latency/tick arbitrage* and
*cross-broker* HFT, neither of which this is. But §4 requires high-frequency **FX** ideas to carry
explicit commission-survival evidence at Q04/DL-072, and this card's symbols are EURUSD/GBPUSD —
precisely the class the mandate says "dies at the ~$45/lot round-trip".

The decisive defect is the second one: the card specifies 10-second and 5-second signals, which the
tester cannot represent, so the build substituted M1 proxies. **The card is not faithfully
executable on this platform.** That needs a decision — retire the card or restate it on a
representable timeframe — not a rework attempt.

## What this does not fix

The holds stop the 19 rows that exist. They do not stop the **next** sweep from enqueuing new rows
for the same EAs, because `sweep_enqueue_built_eas.py` still reads no task state. The holds are a
tourniquet; the gate in the sweep is the repair.

Worth noting for that repair: the sweep already contains the exact hold-writing idiom it needs, at
`:660-686`, complete with `ON CONFLICT(work_item_id) DO UPDATE`. 1.11 is therefore a join, a
predicate, and a reuse of code already in the file. `work_item_id` is UNIQUE — one hold per row —
so the gate must check for an existing hold rather than blind-insert, or it will overwrite holds
placed for other reasons.

The two Q02 PASS rows QM5_33002 produced before the hold stand as evidence produced by a binary its
own review calls defective. They are not withdrawn here; they need `supersedes` (1.13), which is
still machine-invisible.

## Evidence

- operator: `tools/strategy_farm/governed_work_item_hold.py`, schema `qm.governed-work-item-hold/v1`
- per-group outputs: `D:/QM/strategy_farm/artifacts/e3_holds/QM5_*_Q02.json` (7 files)
- backups: `D:/QM/strategy_farm/state/backups/farm_state_before_governed_hold_20260817T2017*.sqlite`
- enforcement point: `tools/strategy_farm/farmctl.py:1169-1172`
- close semantics: `tools/strategy_farm/agent_router.py:1440-1475`
- charter: `decisions/2026-07-06_ftmo_scalping_grid_mandate.md` §3, §4
- reviews: `D:\QM\strategy_farm\artifacts\reviews\{c734242f,85fd5256,39c6a58d,da921b20,91dfb3c7,73eb18d9,feb8cb93,33203a5c,4309d167}-*.json`
- continues `docs/ops/evidence/2026-08-17_point_1_11_the_withdraw_or_hold_set_is_empty.md`
