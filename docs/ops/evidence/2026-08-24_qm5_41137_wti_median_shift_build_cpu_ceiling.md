# QM5_41137 WTI median-shift build and CPU-ceiling stop

Date: 2026-08-24

Branch: `agents/board-advisor`

Status:
`SOURCE_READY_COMPILE_RELEASED_PENDING_UNCLAIMED_Q02_NOT_ENQUEUED_CPU_CEILING`

## Selected sleeve

The mission's one new commodity sleeve is
`QM5_41137_wti-mmedian-shift-mom`, strategy ID
`MOP-WTI-MMEDIAN-SHIFT-MOM-2026_S01`.

On the first executable `XTIUSD.DWX` D1 bar of a new normalized broker month,
the EA selects every accepted daily close from the two immediately completed
consecutive months. It converts each close to a log-price level, independently
sorts both 17-23 observation samples, computes ordinary odd/even medians, and
follows the strict newest-versus-parent location shift for one month. Exact
equality is flat. The signal has no daily return, endpoint, range, oscillator,
trained model, or fitted coefficient.

This is direct WTI physical-energy exposure and a different mechanic from the
certified XAU/SP500/NDX/XNG book, including the long-only two-day XNG RSI
pullback in `QM5_12567`. Instrument and mechanic separation do not establish
realized decorrelation; unchanged Q09 alone owns that decision.

## Governed research and identity

- reputable source approval commit: `6ebf566fb`;
- bounded complete-read extraction commit: `3772df384`;
- approved card and G0 commit: `5ba5e4074`;
- exact EA identity reservation commit: `02ed444f7`;
- slot-zero `XTIUSD.DWX` magic allocation commit: `cbe2df463`;
- source package commit: `154a3042c`;
- exact approved-card build binding commit: `3c908bbed`.

Canonical pre-allocation dedup was `CLEAN` across 4,636 registry identities,
1,304 cards, and 45 current Strategy Wiki nodes. The post-allocation receipt
finds only the just-reserved `41137` slug and strategy ID. The magic resolver
retains 17,989 rows with zero drops under the reviewed `--keep-obsolete`
fallback for the unchanged missing-directory legacy IDs `1001`, `1015`, and
`1016`; `--allow-dropped` was not used.

## Source-ready build

The committed V5 package contains:

- `QM5_41137_wti-mmedian-shift-mom.mq5`;
- `SPEC.md`;
- an exact copy of the approved card;
- a 14-case deterministic monthly-median reference suite;
- exactly one `XTIUSD.DWX` D1 backtest setfile with
  `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

MQ5 SHA-256:
`D465E76F0B0578C6983245442D279C87843A74F003FBC6B93E71B51784C343CC`.

Deterministic preflight passed:

- approved-card schema lint: PASS, zero missing sections and zero ML hits;
- reference suite: PASS, 14/14;
- `validate_spec_doc.py`: PASS, 1/1;
- MQ5 and setfile `validate_build_guardrails.py`: PASS, zero findings;
- `validate_symbol_scope.py --fail-on-leak`: `SINGLE_SYMBOL_OK`, zero
  violations;
- exact approved-card copy, one-setfile count, fixed-risk defaults, registry
  identity, symbol slot, and magic bindings: PASS;
- `git diff --check`: PASS.

The generic magic-resolver unit group produced 12 passes and one known
repository-baseline failure because its binary-search test invokes strict
generation without `--keep-obsolete` and therefore sees the same three legacy
missing directories. Allocation evidence proves no row was dropped.

## Governed compile release

The canonical compile enqueue created exactly one source-hash-bound row:
`83eb3349-3931-40e9-b79a-70bf0700a7b5`. Its payload binds the MQ5 hash above,
`XTIUSD.DWX`, D1, and fixed risk. The initial activation hold was then released
only for that exact row after a dry run matched expected and actual source
hashes. The release took SQLite backup
`farm_state_before_compile_wave_20260824T014908Z_807350bd.sqlite`, SHA-256
`EEF9050C46920963CACafa48354dc25efac9681eaf41c15aeeb58190d0fa2c6f`.

Machine-readable receipts are:

- `artifacts/qm5_41137_compile_enqueue_20260824.json`;
- `artifacts/qm5_41137_compile_release_plan_20260824.json`;
- `artifacts/qm5_41137_compile_release_20260824.json`.

The release did not claim or execute the row and did not launch a terminal.

## Binding CPU stop

Pre-enqueue and pre-release five-sample windows remained below the 97.0%
claim ceiling. Immediately after release, a fresh window was
`100.0, 100.0, 100.0, 100.0, 99.9` percent, averaging 99.98% and peaking at
100.0%. This triggers the mission's explicit backtest CPU-ceiling stop.

The final readback at the stop boundary showed the compile item still pending,
unclaimed, attempt zero, and verdict-free. No EX5 exists. There are zero
`QM5_41137` Q02 rows, so Q02 was not enqueued without a legal Q01 compile PASS.
No compile claim, retry, dispatcher tick, tester action, or queue mutation was
performed after the ceiling trip.

Machine-readable stop evidence is
`artifacts/qm5_41137_compile_cpu_stop_20260824.json`.

## Safety boundary

No manual backtest, terminal control, AutoTrading change, live/demo/shadow/
stress/optimization setfile, `T_Live`, deploy or live manifest, portfolio-gate
edit, portfolio admission, correlation waiver, or second strategy was created.
