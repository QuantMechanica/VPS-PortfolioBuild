# Q10_NEWS aged sealed-plan hold recovery — 2026-08-29

Task: `08f928e7-e885-49bd-8eb9-ce805f03abfe`

## Outcome

All 17 aged `Q09_AWAITING_SEALED_PLAN` holds were re-evaluated through the
contract-v3 autosealer. The six opaque include-closure failures were repaired:
the autosealer now reached their actual dependency gates. No hold was released
without an authenticated plan.

The resulting current census is:

- 10 `Q09_AUTOSEAL_VALIDATE_Q08_VINTAGE_FAILED`;
- 6 `Q09_AUTOSEAL_BIND_PLAN_FAILED` (three missing Q07 lineage and three
  missing authenticated Q07 evidence);
- 1 `Q09_AUTOSEAL_DERIVE_LINEAGE_FAILED` (missing historical Q08 evidence).

Seven rows now have exact append-only recovery work pending. Ten have terminal
strategy/evidence blockers which require an OWNER retire, new-candidate, or full
current-identity requalification decision. Those ten remain held; replaying or
rebinding their historical evidence would weaken the gate.

## Include-closure defect and repair

The existing recovery path preserved the canonical closure and created one
per-work-item immutable successor. Several work-item successors later became
stale as source inventories changed again. `_validated_q09_include_closure`
then revalidated that same successor forever and had no second append-only
generation path.

`build_q09_include_closure.include_closure_generation_key()` now hashes the
current exact closure identity: EA, root source, EX5 path/hash, and the complete
recursive include inventory with hashes and sizes. If both canonical and first
scoped closures are stale, the autosealer writes below
`<work-item>/successors/<generation-sha256>/`. Existing files are never
overwritten. A non-recognized validation error remains fatal.

The targeted live reseal attempted exactly the 17 held IDs. All six former
closure failures built/validated hash-scoped closure evidence and advanced to
their real Q07 binding failures. Contract-v3 plan binding still refused them,
as required.

## Exact row disposition

| Held row | Pair | Current blocker | Durable disposition |
|---|---|---|---|
| `49a059da` | QM5_10847 / GDAXI | no authentic Q07 lineage; prior economic failure | OWNER retire/new-candidate decision; held |
| `aa80274f` | QM5_13128 / NDX | current source/closure differs from Q08 vintage | OWNER full rebuild/requalification; held |
| `1cff016c` | QM5_12989 / XAUUSD | current setfile/source differs from Q08 vintage | OWNER full rebuild/requalification; held |
| `57d8bacd` | QM5_10815 / GDAXI | bound historical Q08 evidence file missing | OWNER rebuild/requalification; held |
| `2604a1f0` | QM5_1567 / EURUSD | current-identity chain incomplete | OWNER full rebuild/requalification; held |
| `84c6e9e9` | QM5_13301 / GDAXI | recovery Q07 `e04ed006` economic FAIL | OWNER retire/new candidate; held |
| `36304cfd` | QM5_13013 / NDX | no Q07 lineage | existing Q07 recovery `68875929` pending |
| `9812fc7b` | QM5_10114 / SP500 | Q07 evidence missing after launch fault | Q07 retry `504d0bf7` pending |
| `7bbeef66` | QM5_12567 / XAUUSD | recovery Q08 invalid perturbation neighborhood | OWNER repair/new candidate; held |
| `d81d9ea8` | QM5_1556 / XAUUSD | stale Q08 after launch fault | Q08 retry `ea0cd059` pending |
| `9639a773` | QM5_10939 / GBPUSD | recovery Q08 `8234812d` degenerate baseline | OWNER repair/new candidate; held |
| `30584122` | QM5_11421 / EURUSD | recovery Q08 `9d183609` invalid/infra outcome | OWNER repair/new candidate; held |
| `f290aa11` | QM5_11708 / EURUSD | prior recovery Q07 PASS became setfile-stale | current-identity Q07 `cbe612cd` pending |
| `e6aaf4b4` | QM5_12823 / USDJPY | prior recovery Q07 PASS became setfile-stale | current-identity Q07 `b6679b2f` pending |
| `08fe4173` | QM5_11476 / USDJPY | no authentic Q07 predecessor | OWNER requalify from last valid gate or retire; held |
| `72f7d4c1` | QM5_13213 / USDJPY | prior recovery Q07 PASS became setfile-stale | current-identity Q07 `d50a994c` pending |
| `84608819` | QM5_12831 / XTI-AUDUSD basket | recovery Q07 launch fault | current-identity Q07 retry `f9b561b3` pending |

The four new Q07 rows were created by the canonical
`farmctl enqueue-backtest --phase Q07 --from-work-item-id ...
--append-only-rerun-of ... --expected-current-ex5-sha256 ...` path. Their
historical Q07 rows and verdicts remain unchanged. The autosealer will only
append a replacement news row and retire a stale hold after an authenticated
current Q07/Q08 chain completes.

## Verification and safety

- Python compilation passed for `build_q09_include_closure.py` and `farmctl.py`.
- Focused tests: **32 passed** across include-closure and Q09 farm integration.
- A positive test proves a stale scoped successor produces a deterministic
  hash-scoped generation; the previous canonical/scoped files stay unchanged.
- A generation-key test proves exact identity changes alter the key and an
  unchanged identity is deterministic.
- Targeted live autoseal: 17 attempted; closure stage cleared for all six prior
  closure failures; zero improperly bound plans.

No gate criterion, historical verdict, terminal, AutoTrading control, or
T_Live setting was changed.
