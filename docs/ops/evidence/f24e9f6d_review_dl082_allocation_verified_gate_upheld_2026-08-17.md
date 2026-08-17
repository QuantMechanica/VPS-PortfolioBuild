# Review of f24e9f6d — DL-082 allocation verified, build gate upheld, and the four card defects are three plus one

Reviewer: Claude. Ticket: `f24e9f6d` (opened by me to undo my own wrongful refusal of the four
DL-082 grid cards). Delivery: `93abea3b6`, artifact
`docs/ops/evidence/f24e9f6d_dl082_grid_magic_allocation_and_build_gate_2026-08-17.md`.

**Verdict: APPROVED.** The allocation is real and correct; the build gate is the right call and was
made for stated, checkable reasons; the 1% cap was not widened.

## What I verified, and one bug of my own

### The 14 magic rows — verified present

My first check reported **0 active rows for all four EAs** and I nearly filed that as a false
delivery claim. That zero was my own bug: `magic_numbers.csv` keys `ea_id` as the bare number
(`30001`), and I filtered on `QM5_30001`. The rule "a zero when re-deriving is first your own bug"
applied literally, in the same session it was written.

Re-derived against the real key format:

| EA | active rows | expected | formula `ea_id*10000+slot` |
|---|---:|---:|---|
| 30001 | 3 | 3 | 3/3 ok |
| 30005 | 4 | 4 | 4/4 ok |
| 30006 | 4 | 4 | 4/4 ok |
| 38007 | 3 | 3 | 3/3 ok |
| **33007 (control)** | 3 | 3 | 3/3 ok |

Registry-wide: **15,898 active rows, 0 duplicate magics, 0 duplicate `(ea_id, symbol_slot)` keys.**
The control matters because it is the *other* allocation in the same commit — had the file been
stale rather than the rows absent, the control would have been missing too.

Codex's provenance claim is also accurate: `c3f3261be` adds exactly 17 registry lines = the 14 grid
rows + 3 for QM5_33007, and it is an ancestor of HEAD.

### The build gate — upheld

No `.ex5`, no `SPEC.md`, no set file was produced for any of the four; the sources remain the
126-line `Unknown Strategy` skeletons. `worst_case_loss_cap_pct` was not raised anywhere. Codex
declined to claim `QM_GridInit` / `QM_GridMaxDrawdownGuard` wiring it had not created — which is the
honest form of my ticket's load-bearing requirement, not an evasion of it.

Request #5 of my ticket explicitly authorised this outcome ("report that as a finding rather than
widening the cap"). It was exercised correctly.

## The correction to the delivery: four gates, but not four defects

Codex reported the blocking mechanics per card, and named essentially the same problem three times:
*"the no-trade rule blocks whenever one strategy position is already open, contradicting the
multi-level basket."* Under "a defect in a shared template is never a single case", I tested whether
that is one cause.

It is. The three cards carry a **byte-identical generated line**:

```
4. **Max Open Positions**: Active concurrent positions for this strategy instance $\ge 1$.
```

**81 approved cards carry it.** Of those, exactly **3 also declare a grid/martingale schedule** —
QM5_30005, QM5_30006, QM5_38007 — and those three are the self-contradictory ones. The other **78
are single-position strategies where the line is correct.**

So the scope is precisely bounded, and in both directions:

- It is **one defect, not three**: the card generator emits the one-position no-trade filter without
  a grid-aware branch. Fixing three cards by hand leaves the generator able to mint a fourth.
- It is **not fleet-wide**: 78 of 81 occurrences are correct. This does not warrant a sweep.

**QM5_30001 is genuinely different** and Codex was right to gate it separately: it lacks the
template line entirely, and its blocker is substantive — a widening 24/24/28/28/35/40/45/50-pip
schedule scaled by `ATR_D1[1] / ATR_Historical_Mean`, against a module that validates worst-case
loss from **one fixed distance**. The lookback of the historical mean and any bound on the ratio are
undefined, so no worst-case loss is computable. That is a card-content gap, not a template artefact.

Method note: my first two attempts at this test returned 0/4 and failed their own controls
(prose regex, then a mis-escaped `\ge`). The controls suppressed both. The census is the third
attempt, on a literal substring.

## What this does not resolve

The cards need amendment before a build is possible, and that is card work, not build work:

- **QM5_30005** — the trigger opening levels 2..7; a base lot that does not depend on the undefined
  `SL_Distance_Points`; the intended exception to the one-position filter.
- **QM5_30006** — grid distance, level limit, base lot, added-level trigger; same exception.
- **QM5_38007** — how Level 0 / `FirstEntry` is created and its direction chosen; same exception.
- **QM5_30001** — define the ATR mean's lookback and a finite multiplier bound, then either supply a
  module-compatible fixed distance or authorise a reviewed extension of `QM_TM_Grid.mqh` that
  validates a per-level schedule.

The generator branch is the fourth item and belongs with 1.9, not here.

Both deferred DL-082 questions were correctly left untouched: the `QM_GridInit` equity-snapshot vs
FTMO `STATIC_INITIAL` basis divergence (now v6 point 1.10) and book-level aggregation (v6 E4 —
resolved as *no* hard book limit, with tail coupling carried as a proxy in 3.2).

## Evidence

- `framework/registry/magic_numbers.csv` — 14 rows, verified with control QM5_33007
- `c3f3261be` — 17 added registry lines; ancestor of HEAD
- `docs/ops/evidence/f24e9f6d_dl082_grid_magic_allocation_and_build_gate_2026-08-17.md`
- card census: 81 carrying the template line, 3 contradictory, 78 correct
- `decisions/DL-082_grid_cap_extended_commercial_ea_deconstructions.md` (ADOPTED 2026-08-16)
