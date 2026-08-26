# QM5_41174 XAU/XAG Spearman basket — source build and CPU stop

Date: 2026-08-26 UTC (`2026-08-26T23:25:49.8522516Z`)

Branch: `agents/board-advisor`

Status: a new, non-duplicate XAU/XAG structural relative-value source build is
committed and its governed compile is queued; Q02 was not enqueued because the
compile worker is activation-held and the explicit backtest CPU ceiling is
binding.

## New sleeve

`QM5_41174_xauxag-mspearman-rv` evaluates thirteen synchronized completed
monthly `log(XAU)-log(XAG)` endpoints. It assigns strict price ranks, computes
the integer displacement score `T = 364 - sum((rank_i-i)^2)`, and fades only
inclusive `abs(T) >= 104` observations with an opposite-side, equal-notional
XAU/XAG package. Exact ties and interior scores consume the monthly attempt
flat. Open packages exit at the next broker month or after forty days.

The aggregate package uses one `RISK_FIXED=1000` budget split across both
frozen `3.5 * ATR(20,D1)` stops. No ML, banned indicator, external runtime
dataset, live setfile, or percent-risk setfile was introduced.

This construction is mechanically distinct from the directional WTI Spearman
build `QM5_41173` and from the fourteen-endpoint, seven-fixed-pair Cox-Stuart
XAU/XAG basket `QM5_41168`. The preallocation receipt found no canonical
duplicate across 4,673 EA-registry rows, 1,324 cards, and 45 wiki files. Actual
portfolio decorrelation remains a later Q09 question; it is not claimed by the
source build.

## Committed records

- `6d967cde8` — reputable composite source approval and clean dedup receipt.
- `3a7eaf8c7` — deterministic EA ID 41174, approved G0 card, and decision.
- `ea0e9ac87` — two-leg V5 source, basket manifest, three fixed-risk backtest
  setfiles, reference suite, documentation, magic rows `411740000/411740001`,
  and resolver update.

Both strategy-card copies have SHA-256
`EC1A681180F6467BCBB1D7CB9C78B95517015CFC739DFBA4608359B41855B715`.
The EA source has SHA-256
`91ACE245813C2444AF70D65E723611082BB083418A4DBFD6C68E4578FBA6F740`.

Eight deterministic reference tests pass. Card schema lint, build guardrails,
static build hardening, SPEC validation, and basket symbol-scope validation all
pass. The hardening scan has no failures; its card-discovery-only warnings are
recorded rather than guessed away.

## Governed compile and Q02 disposition

Ad-hoc compilation correctly refused while factory terminals were alive and
was not retried. Governed compile work item
`f36b05fd-699d-4c18-9103-bdb1e2ebad64` was enqueued once, but its last status
was `pending` under `COMPILE_EA_WORKER_ROLLOUT_PENDING`. There is no `.ex5` and
no Q01 PASS yet.

Five fresh one-second whole-host CPU samples were `100.0%`, `100.0%`, `100.0%`,
`100.0%`, and `99.903829%`. Their average was `99.980766%` and their maximum
was `100.0%`, independently crossing the `97.0%` ceiling. Seven `terminal64`
and five `metatester64` processes were observed. Therefore no Q02 row was
enqueued and no tester was launched.

## Safety boundary

No terminal was started or stopped, AutoTrading was not toggled, and neither
the portfolio gate, `T_Live`, nor the `T_Live` manifest was touched. Existing
unrelated worktree changes were preserved.

Machine-readable receipt:
`artifacts/qm5_41174_compile_handoff_20260826T232549Z_board_advisor.json`.
