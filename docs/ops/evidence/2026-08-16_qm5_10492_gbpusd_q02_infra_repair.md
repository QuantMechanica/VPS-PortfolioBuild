# QM5_10492 GBPUSD Q02 infrastructure repair

Date: 2026-08-16 Europe/Berlin

Branch: `agents/board-advisor`

Outcome: the legacy GBPUSD initialization failure was repaired as a current,
hash-bound build and one append-only Q02 successor was queued. No tester was
started manually.

## Selection and ownership

- The remaining apparent diversity build candidates were either already built
  and advanced or blocked by unavailable governed DWX history/timeframes. This
  unit therefore used mission priority 2 rather than adding another build.
- `QM5_10492_mql5-daydream` is an approved structural H1 FX/channel-reversal
  sleeve from Scriptor's idea and Vladimir Karputov's MQL5 CodeBase
  implementation, published 2018-10-25. Its card records R1-R4 PASS and an
  evidence-corrected expectation of about eight trades per year per symbol.
- Farm task `fbe99975-2d40-4679-9d80-d4895b51a4cf` atomically claimed the
  single GBPUSD repair for `codex:agents/board-advisor`. The claim found no open
  GBPUSD work item, exact-symbol Q02 PASS/higher phase, or competing EA claim.
- Pre-claim backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10492_gbpusd_q02_claim_20260816T211616Z.sqlite`.
  Pre-enqueue backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10492_gbpusd_q02_enqueue_20260816T212417Z.sqlite`.
  `PRAGMA quick_check` returned `ok` for both.

## Bound failure and classification

- Exact predecessor `676a45ac-576d-4112-b66b-9b0f59e03a01` remains unchanged
  as `failed / INFRA_FAIL`. It was GBPUSD.DWX H1 over 2017-01-01 through
  2024-12-31 and ended on 2026-06-19 with
  `run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS`.
- The first failed layer is **setup/initialization**, before entry, order, or
  economic evaluation. The row predates execution-binding capture: it contains
  no MQ5, EX5, or setfile hashes, and its named runner log/report directory has
  since been purged. The precise historical `OnInit` subcause therefore cannot
  be reconstructed and is not over-claimed here.
- Artifact chronology still proves the row was stale relative to the repaired
  lineage. The canonical June 3 EX5 was 137,998 bytes with SHA-256
  `1b1b104ab95383d6bade468b0f4c75cb2ecd573c6cb5e7bb53d2b0399421fa78`;
  the failed row is dated June 19; and the canonical EA was rebuilt on June 21.
  Later Q02 rows on EURUSD, USDJPY, and XAUUSD passed with the post-June-21
  binary. This does not prove which bytes T3 loaded on June 19, but it does show
  that the failed pre-binding row is not a valid economic verdict for the
  current artifact.
- The current guardrail pass also exposed a reproducibility defect: all four
  setfiles left the card's 48-bar time stop at the EA default. That omission is
  not asserted to be the historical init cause.

## Minimal repair

- Strategy source is byte-for-byte unchanged. MQ5 SHA-256 remains
  `5df629bc8bd152bed9d3c404f570e373d7b99b687886e4b9b6848af9e62dfecd`.
- The unchanged source was strictly rebuilt against the current framework and
  magic resolver (resolver SHA-256
  `4076e4af4836caa95e86555c945b45bf07e0f3a830dd39b8be386301c11923fc`).
  New EX5 SHA-256 is
  `050192a713b5d30d6f860a1cb48b2260e1c227ea75fdc08146defa1989008c09`.
- The build checker refreshed the four backtest build-hash headers. Each set
  now explicitly serializes the approved/default
  `strategy_time_stop_bars=48`; all retain `RISK_FIXED=1000` and
  `RISK_PERCENT=0`. GBPUSD remains H1, slot 1, magic 104920001.
- A missing `SPEC.md` was added from the approved card and existing source so
  the Q01 card-to-code contract is durable.
- No entry, exit, threshold, stop, target, sizing, filter, timeframe, or symbol
  mechanic changed.

## Verification

- Strict MetaEditor compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:\QM\repo\framework\build\compile\20260816_211735\QM5_10492_mql5-daydream.compile.log`.
- Compile summary: `D:\QM\reports\compile\20260816_211735\summary.csv`.
- Full build check after rebuild: PASS, 0 failures, 0 warnings;
  `D:\QM\reports\framework\21\build_check_20260816_211939.json`.
- Final build check after explicit setfile sealing: PASS, 0 failures, 0
  warnings; `D:\QM\reports\framework\21\build_check_20260816_212107.json`.
- SPEC validation: PASS (1/1).
- Build-skill registry preflight: PASS for EA allocation, magic rows, and EA
  directory.
- Build guardrails: PASS with no findings.
- Symbol-scope validation: `BASKET_OK`, zero violations.

## Q02 admission

The ordinary authenticated-rerun path does not accept this legacy source class
because its execution evidence and hashes were never captured. The
governed `farmctl seed-fresh-q02` path is specifically constrained to such an
exact terminal pre-binding row and preserves that row unchanged.

- New work item: `63189efa-6770-4610-88b2-1bd9feb63b7f`.
- State at creation: `pending`, Q02, GBPUSD.DWX, H1.
- Historical source preserved: `676a45ac-576d-4112-b66b-9b0f59e03a01`.
- Bound EX5 SHA-256:
  `050192a713b5d30d6f860a1cb48b2260e1c227ea75fdc08146defa1989008c09`.
- Bound GBPUSD setfile SHA-256:
  `3e6a9f187c82760510a16d89eb4d7c744dcaf7e1b8b20f45c39da75788bcecee`.
- The successor payload records `RISK_FIXED=1000`, `RISK_PERCENT=0`, the exact
  symbol/period/expert identities, and active governed custom-history admission.
- No dispatch tick, terminal reservation, smoke test, or other backtest was
  launched. The fleet worker's claim-time CPU gate controls when this pending
  row can consume a tester slot.

## Recovery record

| EA | Bound run | Root cause | Repair | Compile | Entry events | Trades | Remaining gaps |
|---|---|---|---|---|---:|---:|---|
| QM5_10492 | Predecessor `676a45ac-…`, GBPUSD.DWX H1, 2017-2024; exact DB identity but legacy pre-artifact-binding execution | Setup failed at `OnInit`; exact historical subcause unavailable after evidence purge. Setfile also lacked explicit 48-bar time-stop serialization. | Strict current-framework rebuild; explicit card time stop in all backtest sets; missing SPEC restored; one hash-bound fresh Q02 seed | PASS, 0 errors, 0 warnings | Not yet measured; Q02 pending | Not yet measured; Q02 pending | Q02 economic result, then Q04 and later governed gates |

This unit establishes only a reproducible, queued Q02 test. It does not claim
trade capability, strategy success, or promotion.

## Safety boundary

No portfolio gate, T_Live artifact, deploy manifest, AutoTrading setting, live
state, or unrelated shared-worktree change was touched.
