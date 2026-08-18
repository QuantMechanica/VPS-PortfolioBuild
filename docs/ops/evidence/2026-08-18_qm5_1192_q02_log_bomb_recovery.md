# QM5_1192 XTI Q02 log-bomb recovery and CPU stop

Date: 2026-08-18 Europe/Berlin

Branch: `agents/board-advisor`

Farm claim: `f790fa19-d21e-41bf-a8ad-58e37aadb0ad`

## Outcome

`QM5_1192_qp-stress-oil-rebound` received a source-preserving infrastructure
repair for its `XTIUSD.DWX` D1 Q02 path. The required-symbol set is now
validated once during initialization, and slot 0 no longer selects the retired
Brent fallback or any auxiliary symbol on every tick. Entry, exit, stress
threshold, ATR stop, holding period, position sizing, and news behavior are
unchanged.

The repaired source passes the current Q01 specification and build gates and
has a fresh strict-compile binary. No Q02 successor was enqueued and no tester
was launched: five sustained factory-capacity samples were all `100.0%`, above
the governed `97.0%` CPU ceiling. The repair is therefore reproducible but is
not claimed to pass Q02, reach the entry signal, or satisfy economics.

## Selection and collision control

The remaining approved build backlog failed the deterministic build preflight:
the EA-ID rows and scaffolds exist, but the required magic rows do not. The
governed build skill does not authorize silently allocating those rows. Among
the unclaimed Q02-Q03 infrastructure candidates, `QM5_1192` was the eligible
low-frequency structural diversity unit: a G0-approved, Quantpedia-sourced
cross-asset stress-reversal rule on energy beyond XNG, with no economic verdict
or deeper-phase result on its current XTI host.

The claim was acquired atomically under
`manual:codex:agents/board-advisor:QM5_1192:xtiusd-q02-log-bomb-recovery:20260818T015058Z`
after rechecking that no live XTI work item or competing active agent task
existed. Its pre-claim backup is:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_1192_q02_log_bomb_claim_20260818T015058Z.sqlite`

The retired `XBRUSD.DWX` row is explicitly outside this repair and rerun scope.

## Bound failure evidence

The terminal Q02 row is
`662c278c-2cb2-4f33-99c0-bc7c23c9f642`, `XTIUSD.DWX`, D1. Its immutable
`log_bomb_evidence.json` records a 14.7 GB tester journal against a 4 GB cap;
the farm stopped T9 and classified the row `INFRA_FAIL / LOG_BOMB`. The bound
MQ5/EX5/setfile identities in the work item were the same canonical artifacts
present before this repair. The oversized raw journal was removed by the farm,
so no claim is made about a surviving repeated log line.

The source control flow nevertheless exposes the implementation defect:

1. `OnTick` called `Strategy_NoTradeFilter` on every tick.
2. That filter called `Strategy_SelectSymbols` on every tick.
3. The selector requested the host, both signal legs, both oil proxies, and in
   particular `XBRUSD.DWX` even for magic slot 0.
4. `XBRUSD.DWX` was later formally retired for absent governed custom history.

Repeated terminal-level symbol selection of an unavailable, unused leg is not
part of the trading rule and is capable of generating unbounded tester journal
noise. A fresh governed Q02 remains necessary to prove the runtime symptom is
gone.

## Minimal repair

- `Strategy_SelectSymbols` now selects only the current slot's trade symbol and
  the two required signal symbols.
- `OnInit` performs that selection once and fails closed if a required symbol
  is unavailable.
- `Strategy_NoTradeFilter` no longer performs symbol I/O per tick.
- Six legacy raw-series calls rejected by the current Q01 corset were migrated
  mechanically to `QM_ReadBar` and `QM_TM_HeldPeriods`. The same completed D1
  closes, timestamps, minimum-history depth, and held-bar threshold are used.
- The legacy spec was normalized to the required seven-section Q01 schema from
  the existing G0-approved local strategy card.
- Only the current XTI `RISK_FIXED` backtest setfile headers were refreshed by
  the build checker. XBR and live setfiles have no content diff.

Artifact identities:

| Artifact | Before SHA-256 | After SHA-256 |
|---|---|---|
| MQ5 | `efb87bcbe91ec96a52b4b7b778ec5f75b756255309ddc572a3bf36291db8badb` | `90449a15513b8e23cf00ac8bde912e2721083d9d69997e6bb9a47f0f5755a74d` |
| EX5 | `18bb5adcbe413995c6bded6b724386d2bddf37239935a3637516ce26cec80f92` | `afcf887f183de872d4b572c30c4883d15747b6b0c71912b7f78666c98c06c6d4` |
| XTI baseline backtest set | `24b8333fadbe7b4ad2b048dde357d611e1f983ca2aa26660f547f84dc3228f5e` | `6ea21444a34b122db3e9e485fde69f1b25fe9a3dd425990581a7ce5743a787b2` |
| XTI stress-0.5 backtest set | not claim-bound | `fcde48e87bbf62e6d218748d4cc438a0db402d1731be40c95e427d1e7a192065` |
| Canonical SPEC | legacy schema | `a11773510b9d7783aa92057bdbc2c76fbe8b919c06b08c1e7c0c26b22dbc61bd` |

The baseline set remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, magic slot 0,
D1, with the card's exact symbols and strategy parameters.

## Verification

- `validate_spec_doc.py`: PASS, 1/1.
- `build_check.ps1`: PASS, 0 failures, 0 warnings. Report:
  `D:\QM\reports\framework\21\build_check_20260818_015649.json`, SHA-256
  `d6f166a4ad509ed1a6f5397164475d92a1b76ef1d9ac5b8b76a9e7895535fa93`.
- Final `compile_one.ps1 -Strict`: PASS, 0 errors, 0 warnings. Log:
  `C:\QM\repo\framework\build\compile\20260818_020454\QM5_1192_qp-stress-oil-rebound.compile.log`,
  SHA-256
  `b78cedf1e832de82980bf0f5d43decbc9fa4336bd94ee662b07bb6f8a03fb6ab`.
- `validate_build_guardrails.py`: PASS, six files checked, no findings.
- No smoke test, terminal dispatch, or manual backtest was run.

## CPU ceiling disposition

The capacity probe used the same Windows `GetSystemTimes` delta sampler and
threshold constants as `terminal_worker.py`. After the baseline sample, five
one-second sustained samples were:

`100.0, 100.0, 100.0, 100.0, 100.0` percent.

Average and peak were both `100.0%`; the admission ceiling is `97.0%` and the
hysteresis resume threshold is `90.0%`. In accordance with the paced-fleet
mission, no append-only Q02 work item was created. The next operator should
seed one exact successor from work item
`662c278c-2cb2-4f33-99c0-bc7c23c9f642` only after factory capacity recovers,
binding the current EX5 SHA-256 above.

## Safety boundary

No T_Live path, AutoTrading state, portfolio gate, deploy manifest, live
manifest, portfolio admission, registry row, or unrelated EA was changed. The
compile helper performed only its standard include sync to configured compile
targets. No terminal process was started, stopped, or pre-empted.
