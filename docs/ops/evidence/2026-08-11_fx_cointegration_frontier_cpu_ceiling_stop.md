# FX Cointegration Frontier / Q02 Paced-Fleet Stop

Date: 2026-08-11

Branch: `agents/board-advisor`

Repository head at audit: `94eba9bcd1769e93bca64de29272fb7abe15a771`

Status: no non-duplicate pair remains in the frozen 66-pair scan; fallback
Q02 selection stopped at the binding paced-fleet CPU ceiling

## Outcome

The requested anchors do not require a Q02 infrastructure repair. Durable
pipeline evidence records:

- `QM5_12532` logical-basket Q02 PASS and Q04 PASS, followed by Q05 FAIL.
- `QM5_12533` logical-basket Q02 PASS, followed by Q04 FAIL.
- Neither anchor has an outstanding Q02 `ONINIT` or `NO_HISTORY` blocker.

The frozen scan is also exhausted. The original governed research found only
`AUDUSD` / `NZDUSD` and `EURJPY` / `GBPJPY` above its strict positive-beta
selection threshold. The later sign-aware replay retained all 66 ranked rows
and repository reconciliation found every relationship already mechanized,
including the final two rows through existing explicit pair coverage. A new
Strategy Card or basket EA would therefore duplicate an existing relationship
and would not satisfy the governed card/build preflight.

Per the mission fallback, an existing low-frequency reputable-source FX card
could be considered only if immediate paced-fleet capacity permitted a fresh,
target-only Q02 dry run. Capacity did not permit that selection or enqueue.

## Binding CPU ceiling

The immediate read-only sample was taken with:

```powershell
python tools/strategy_farm/farmctl.py mt5-slots
```

At `2026-08-11T06:33:53+00:00`, eight factory terminals were running:

```text
T2, T3, T4, T5, T7, T8, T9, T10
```

Eight is above the binding seven-terminal ceiling. All ten enabled terminal
workers (`T1` through `T10`) were present. The separately observed `T_Live`
and FTMO terminal processes were excluded from the factory count and were not
controlled.

The mission therefore stopped before choosing another fallback EA, applying
an enqueue, dispatching work, launching a tester, reserving a terminal, or
altering any terminal process.

## Reproducibility and sources

- Governed scan and OWNER-requested research result:
  `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
- Full-frontier replay and current duplicate coverage:
  `docs/research/FX_COINTEGRATION_FRONTIER_Q02_CPU_CEILING_STOP_2026-08-07.md`
- Reputable structural method preserved from Ernest P. Chan,
  *Quantitative Trading* (Wiley, 2009):
  `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`

## Safety

- No Strategy Card, EA source, binary, setfile, basket manifest, EA registry,
  or magic-number row changed.
- No queue row was inserted, claimed, dispatched, or duplicated.
- No backtest, tester process, or pipeline phase was launched.
- No portfolio-admission, portfolio KPI, or Q08-contribution path changed.
- No `T_Live` manifest, live setfile, terminal state, or AutoTrading state
  changed.
- Existing unrelated dirty-worktree files were left untouched.
