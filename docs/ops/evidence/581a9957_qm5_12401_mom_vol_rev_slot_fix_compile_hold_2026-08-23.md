# QM5_12401 Build Evidence — Registry Slot Rewired, Governed Compile Held

- Task: `581a9957-4c0b-47f8-9b4c-f9b373d9fcb2` (`build_ea`, priority 50, assigned to Codex)
- EA: `QM5_12401_mom-vol-rev`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12401_mom-vol-rev.md`
- Current MQ5 SHA-256: `87c6c41f761988ca6b5beba77b551e81a4fdd94bdfc7599e81cc094e6da56494`
- Outcome: `SOURCE_READY_COMPILE_HELD`

## Requested correction

The recycled review finding was exact: `Strategy_EntrySignal` hard-coded
`req.symbol_slot = 0` even though the governed seven-symbol package uses active
magic slots 0-6. The request now assigns `qm_magic_slot_offset`, so each generated
set file supplies the symbol's registry slot to the framework entry request.

The source-level `RISK_PERCENT` default was also restored to the required
backtest-safe value `0.0`. Live risk is not enabled here; any later approved live
set may explicitly supply the card's 0.25% value. No live or terminal control was
changed.

## Governed package

The approved card, EA registry entry, existing basket manifest, and folder identity
all resolve to `QM5_12401_mom-vol-rev`. Active magic rows bind slots 0-6 to
SP500.DWX, NDX.DWX, WS30.DWX, GDAXI.DWX, UK100.DWX, XAUUSD.DWX, and XTIUSD.DWX.
All seven D1 backtest presets were regenerated from those rows with
`RISK_FIXED=1000` and `RISK_PERCENT=0`.

## Focused verification

- `validate_spec_doc.py`: PASS (1/1).
- `validate_build_guardrails.py`: PASS; 8 files checked, zero findings, stale-news ceiling 336 hours.
- `validate_symbol_scope.py --fail-on-leak`: `BASKET_OK`, zero violations.
- Explicit set-risk audit: PASS for 7/7 D1 presets.
- Explicit source audit: PASS; no `req.symbol_slot = 0` assignment remains.
- `git diff --check`: clean for the EA package.

## Compile boundary

Direct strict `build_check.ps1` stopped before compilation with
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because terminal64 factory processes are active.
No terminal was started, stopped, interrupted, or bypassed. The tracked EX5 had no
governed compile record and predates the corrected source, so its stale artifact
(SHA-256 `4818253159aa8fd60ad7efd31636e37ea85aee7b2ca695dff3888c8717cdc8cb`)
was removed; it remains recoverable from Git.

The sanctioned compile command accepted governed work item
`e7845c7b-2a2c-4ee1-9372-8aa8595be0bd`, bound to the seven active magic rows and D1
sets. Activation is held under `COMPILE_EA_WORKER_ROLLOUT_PENDING`; no current EX5
or strict build PASS exists yet. Smoke was not run, and no pipeline verdict is
claimed.

The source, regenerated presets, stale-binary deletion, and this evidence were
committed on `agents/board-advisor` as `2f2e3c6de`. The requested `REVIEW`
transition was then attempted and refused by the router with
`D6_BUILD_IDENTITY_MISSING` / `build_identity_json_missing_review_dispatch_refused`.
A review packet must bind a committed current EX5 and strict build PASS; neither
can truthfully be asserted while the governed compile remains activation-held.
The task is therefore dispositioned `BLOCKED` without fabricating build identity.

Short verdict: `SOURCE_READY_COMPILE_HELD: registry slot wiring and static gates PASS; governed compile e7845c7b pending under worker-rollout activation hold.`
