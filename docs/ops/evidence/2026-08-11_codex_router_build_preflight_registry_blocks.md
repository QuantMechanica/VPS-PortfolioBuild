# Codex router build preflight — registry and charter blocks

Date: 2026-08-11  
Role: Development / Codex  
Scope: one scheduled router cycle; build only

## Outcome

Five priority-50 `build_ea` tasks reached Codex with OWNER-authorized Strategy Cards, but none passed the deterministic pre-build gates required by `qm-build-ea-from-card`. No EA source, registry, resolver, setfile, compiled binary, smoke run, pipeline row, terminal, AutoTrading setting, or live setting was changed for these tasks.

| Router task | EA | Approved card | EA registry | Required magic rows | Additional gate | Verdict |
|---|---|---|---|---|---|---|
| `6c35c3ec-b576-4919-a321-796b7c813350` | `QM5_20077_atr-channel-trail-breakout-h1` | PASS (`g0_status: APPROVED`) | PASS: active row for `20077` / exact slug | FAIL: 0/5 active rows for `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `XAUUSD.DWX`, `NDX.DWX` | — | `BLOCKED_PREBUILD` |
| `751d8eb5-d9de-4cfe-85c6-27468c409078` | `QM5_20078_volume-profile-poc-retest-intraday` | PASS (`g0_status: APPROVED`) | PASS: active row for `20078` / exact slug | FAIL: 0/7 active rows for the card's target basket | — | `BLOCKED_PREBUILD` |
| `a6092797-1416-4719-8c13-cc60829247bb` | `QM5_20079_pip-boxer-bounded-grid-h1` | PASS (`g0_status: APPROVED`) | PASS: active row for `20079` / exact slug | FAIL: 0/5 active rows for the card's target basket | FAIL: the active Edge Lab charter prohibits grid and averaging into losers; the card explicitly requires a five-level averaging grid | `BLOCKED_PREBUILD` |
| `89195162-745e-4f46-aa8c-12924b6981a3` | `QM5_20080_goodman-wave-theory-intersection-h1` | PASS (`g0_status: APPROVED`) | PASS: active row for `20080` / exact slug | FAIL: 0/8 active rows for the card's target basket | — | `BLOCKED_PREBUILD` |
| `fdf510ce-db61-46f3-a1da-dad1559c0a73` | `QM5_20081_renko-triple-block-flip-h1` | PASS (`g0_status: APPROVED`) | PASS: active row for `20081` / exact slug | FAIL: 0/7 active rows for the card's target basket | — | `BLOCKED_PREBUILD` |

## Evidence checked

- All five cards of record were read in full from `D:/QM/strategy_farm/artifacts/cards_approved/`.
- EA allocation was checked in `C:/QM/repo/framework/registry/ea_id_registry.csv` using exact numeric ID, slug, and active-status matches.
- Magic allocation was checked in `C:/QM/repo/framework/registry/magic_numbers.csv` using exact numeric ID and active-status matches.
- Every frontmatter `target_symbols` member was checked against `C:/QM/repo/framework/registry/dwx_symbol_matrix.csv`; symbol availability is not the blocker.
- The existing canonical `.mq5` file for each label was checked. Each is the tracked auto-generated skeleton with an explicit unimplemented `Strategy_EntrySignal` TODO and empty strategy-management behavior; none was treated as a completed build or modified.
- `docs/ops/EDGE_LAB_CHARTER_2026-05-22.md` was checked for the `QM5_20079` technique boundary. Its no-grid/no-averaging rule is explicit and binding for Edge Lab work.

## Focused verification result

The selected build skill requires the allocated EA row and all `(ea_id, symbol_slot)` magic rows to exist before implementation. It explicitly forbids Development from allocating either registry. All five fail that magic-row gate, so `build_check`, compile, setfile generation, and smoke were correctly not run; none could provide valid build evidence before allocation.

`QM5_20079` has an independent charter failure and must not be made buildable merely by adding registry rows. It requires OWNER-governed retirement or a newly approved, non-grid Strategy Card; Development must not rewrite the approved mechanics ad hoc.

Required recovery for `QM5_20077`, `QM5_20078`, `QM5_20080`, and `QM5_20081` is OWNER-governed allocation of every required magic row, followed by fresh deterministic routing. Build approval, pipeline advancement, and live authorization are not implied by this preflight.
