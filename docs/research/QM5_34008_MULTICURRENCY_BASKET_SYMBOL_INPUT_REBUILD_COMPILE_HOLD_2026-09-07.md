# QM5_34008 Multi-Currency Basket — Portable Rebuild and Compile Hold

## Outcome

`QM5_34008_multicurrency-basket-dispersion-hedger` is now a portable,
non-live V5 market-neutral FX basket source build on `agents/board-advisor`.
The seven registry slots remain unchanged, while their broker symbols moved
from an EA-owned literal array to seven user-visible `strategy_symbol_*`
inputs. The cross-sectional dispersion signal, equal risk split, two-leg
package ownership, and aggregate exits did not change.

The governed Q01 compile item exists but is pending behind
`COMPILE_EA_WORKER_ROLLOUT_PENDING`. The stale pre-rebuild `.ex5` was removed
before enqueue so it cannot be mistaken for evidence for the new source. Q02
was not enqueued because canonical intake requires `COMPILE_OK`. No compile
hold was released and no tester was launched.

## Selection and Diversity

The deterministic strategy-priority report ranked the nominal top card
`QM5_30001` first, but that card has `g0_status: REJECTED` and is explicitly
retired for martingale/grid behavior. `QM5_34008` is the highest-value eligible
structural alternative in the requested diversity lanes: a seven-major FX
relative-value basket rather than another index, metal, or energy sleeve.
The live farm DB had no prior task or work-item row for this identity, so the
new build task is a distinct claim rather than a collision with another paced
agent.

## Build Evidence

- Approved runtime card:
  `D:/QM/strategy_farm/artifacts/cards_approved/QM5_34008_multicurrency-basket-dispersion-hedger.md`.
- Build task: `c97b5cdc-8d55-404e-9ec0-47496d1a75f6`.
- MQ5 SHA-256:
  `7203979e4a508dee2a5e041c57538e29b8bb107dbdf0cf0d53b0d76c977266ae`.
- Mandatory framework-input pin audit: `ok=true`, `hit_count=0`, no
  `EA_FRAMEWORK_INPUT_PINNED` finding. It was rerun immediately before the
  successful compile enqueue.
- Symbol-literal inventory: seven findings, all seven classified
  `symbol_input_default` with severity `ALLOW`; no trading/universe symbol
  remains hidden in EA logic.
- Strategy inputs reject empty, duplicate, or unavailable basket slots before
  framework initialization. Runtime magic registration remains suffix-tolerant
  and registry-bound for slots 0 through 6.
- Seven H1 backtest presets were regenerated. Every preset declares
  `RISK_FIXED=1000`, `RISK_PERCENT=0`, and all seven ordered symbol inputs.
- `validate_spec_doc.py`: PASS.
- The standalone `build_check.ps1` attempt correctly refused with
  `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`; the governed compile queue was used
  exactly as directed and no ad-hoc retry ran.
- Compile item: `1c77fcf2-39ef-47f6-a448-5dd1457bce03`, status `pending`,
  activation-held. No fresh `.ex5`, strict build-check receipt, compile PASS,
  or smoke PASS is claimed.

## Q02 Admission Result

Canonical first-Q02 intake dry-run returned
`compile_work_item_not_done_compile_ok`. At
`2026-09-07T01:36:20.9498359Z`, five one-second whole-host CPU samples were
`88.187755%`, `91.139572%`, `89.852868%`, `94.435526%`, and `91.701824%`.
Average utilization was `91.063509%`; maximum utilization was `94.435526%`.
Both were strictly below the 97% ceiling, but CPU capacity cannot waive the
missing `COMPILE_OK` precondition. No Q02 row was created.

Resume only after the governed compile becomes `COMPILE_OK`, then take a new
five-sample CPU window. If it still clears the ceiling, apply:

```powershell
python tools/strategy_farm/farmctl.py intake-first-q02 --compile-work-item-id 1c77fcf2-39ef-47f6-a448-5dd1457bce03 --apply
```

## Safety Boundary

No portfolio gate, `T_Live`, deploy/live manifest, AutoTrading, manual
backtest, optimization, terminal restart, compile-hold bypass, priority boost,
or live surface was touched.
