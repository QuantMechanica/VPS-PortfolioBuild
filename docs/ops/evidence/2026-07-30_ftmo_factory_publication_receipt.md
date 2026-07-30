# FTMO Book 3 and Factory-preparation publication receipt

Captured through: 2026-07-30T05:31:50Z

Authority: `SOURCE_AND_DASHBOARD_PUBLICATION_ONLY_NO_FACTORY_OR_TRADING_AUTHORITY`

## Durable source publication

- Canonical checkout: `C:\QM\repo`
- Branch: `agents/board-advisor`
- Implementation commit: `ce160628391bbd3e4278fc5e14dbf90c067ab471`
- Commit subject: `ftmo: publish book evaluation and harden factory restart`
- Remote branch: `origin/agents/board-advisor`
- Draft PR: `https://github.com/QuantMechanica/VPS-PortfolioBuild/pull/5`
- PR base/head: `main` / `agents/board-advisor`

The implementation commit was pushed without force. The PR remains deliberately draft;
the long-lived branch must be reviewed and integrated deliberately rather than auto-merged
as a side effect of this publication.

## FTMO native-MT5 outcome

The final native R2 run is bound to work item
`2c92e30e-df68-51fe-b1f8-d90901f43dc8` under:

`D:\QM\strategy_farm\artifacts\ftmo_book3_v2_full_lifecycle_20260730_a02\standalone_diagnostic_f8593cd4b`

- native trades: 548;
- net profit: USD 9,078.52;
- profit factor: 1.12;
- drawdown: USD 7,151.65;
- lifecycle reconciliation: PASS, 548/548, zero mismatches;
- evaluation manifest SHA-256:
  `fdd26cc9d794c8420ab2f2914aa147f60dc3bdc3a7c4df8bd3c05d2ad91081ab`;
- evaluation receipt SHA-256:
  `303857750a452c538cfad41ea1026b78b717f92d949cc4abc8594c4a1ddb5b38`;
- status: `RESEARCH_MODEL_COMPLETE_STRICT_QUALIFICATION_UNVERIFIED`;
- paid challenge: `NO_GO`;
- all deployment, purchase, money, Factory and trading authorizations: false.

The next admissible evaluation step is a preregistered shared-account FTMO Free Trial or
shadow run. The historical/bootstrap and holdout figures are explicitly non-gate-eligible
and do not authorize a paid challenge.

## Verification baseline

- Green lane: 3,399 passed, 1 skipped, 5 deselected and 49 subtests passed in
  448.80 seconds.
- Separate external-residual lane: exactly the five declared fail-closed tests failed;
  no additional failure occurred and no assertion was weakened.
- Factory process-scope suite: 278 assertions passed.
- Factory restore-intent suite: PASS.
- Factory post-start-health suite: 22 PowerShell assertions passed.
- Focused final Python lane: 56 passed.
- Changed Python compilation, PowerShell AST, strict JSON parsing and staged diff checks:
  PASS.

## Dashboard publication

Both requested pages were rendered directly from implementation commit `ce1606283...`:

```text
python -B tools/strategy_farm/dashboards/render_dashboards.py --root D:\QM\strategy_farm --strategies-only
python -B tools/strategy_farm/render_cockpit.py
```

Immediate committed-source outputs captured at 2026-07-30T05:30:21Z:

- `D:\QM\strategy_farm\dashboards\strategies.html`: 1,163,447 bytes,
  SHA-256 `e019e21702ea42c2d938265b213fd4ba3dff1ab60f231ee3f9ba969dedea2599`,
  mtime `2026-07-30T05:29:58.6393353Z`;
- `D:\QM\strategy_farm\dashboards\cockpit.html`: 64,152 bytes,
  SHA-256 `ab8133f210e97f401b463d445e334225fd7052bbb9a3f7537767e0c64fd94f7f`,
  mtime `2026-07-30T05:30:21.3553521Z`.

Both outputs contain the exact research-only status, `NO_GO`, `NON-GATE-ELIGIBLE`,
the no-runtime-revalidation caveat and explicit authority labeling. Productive database
SHA-256 before and after both render commands was exactly
`843dff440c5f67446ee18c9464472fcaa474b85af698ca3893e23210e2dc9a4e`;
its mtime remained exactly `2026-07-30T04:19:23.8824952Z`.

Durability uses the two pre-existing enabled tasks; neither task was registered, enabled,
disabled, started or stopped by this publication:

- `QM_StrategyFarm_Cockpit_2min` executes
  `C:\QM\repo\tools\strategy_farm\render_cockpit.py`; its naturally scheduled run at
  2026-07-30T07:31:31+02:00 completed with result 0.
- `QM_StrategyFarm_Dashboard_Hourly` executes
  `C:\QM\repo\tools\strategy_farm\dashboards\render_dashboards.py`; its 07:00+02:00
  run completed with result 0.

Because those tasks include render timestamps, later healthy scheduled runs may produce
new HTML hashes while retaining the same commit-bound status and authority contract.

## Commit-bound MNT-003 preparation

The read-only Factory task-contract plan was regenerated after the implementation commit:

- plan ID: `28ec0ed7d20d75a2b98f31d010095f7ebcf569e8b907383aa8ff0d2a408be70e`;
- source commit: `ce160628391bbd3e4278fc5e14dbf90c067ab471`;
- apply script SHA-256:
  `035899534a18f997b1a2fe710c3d23566543faed2bdf6661a1779f4cd4960d0e`;
- package aggregate SHA-256:
  `1176dd660e3e931c98e2eb5e7e08723e135535d4d034721f470478f3e76e9bd8`;
- exact OFF-flag SHA-256:
  `09cc4f83e8d5f384f03bc51306beff2cdd165108559a00dbf665097c60b47f1c`;
- scope/operation: `Factory` / `APPLY`;
- operations: five `REGISTER` actions, all currently `BEFORE` and disabled.

No WhatIf or apply was represented as OWNER-authorized. No task contract was changed.
A later apply requires a fresh durable OWNER decision bound to this exact plan and OFF
hash while the shared mutation lock is held.

## Open-worktree preservation and safety closeout

The five pre-existing user-owned changes were not staged or modified. Their final hashes
remained:

- `docs/ops/MNT043_044_CLOSURE_DRIFT_SCANNER.md`:
  `5ee59f93ca32e68c08fc1fcebd6a3babe005453d36f23d4fdcb50e02c6f85852`;
- `framework/EAs/QM5_20181_ftmo-joint-multisym-timer/QM5_20181_ftmo-joint-multisym-timer.ex5`:
  `f5be62ffeb9f83f60e4d1f27a060c2db0403a68d0310e43d638d24e89cd30210`;
- `public-data/process-roadmap.json`:
  `a7a4c97e73b069b5fb6f8c59d7a376a4eb9bb1eac8cf4eca7d26fe3818a017f6`;
- `public-data/public-snapshot.json`:
  `aadbabc8d55c808812437c43da1f2e0676912ca723a548730afbb92b3243e5e6`;
- `public-data/strategy-archive.json`:
  `5fe3985754f47bd59382b908aaa7fa4359ef89d08d57f187d775deef5bafd4e2`.

Factory remained intentionally OFF with the 66-byte flag at SHA-256
`09cc4f83e8d5f384f03bc51306beff2cdd165108559a00dbf665097c60b47f1c`.
`FACTORY_MUTATION.lock` remained absent. T_Live remained PID 5220 at
`C:\QM\mt5\T_Live\MT5_Base\terminal64.exe`, with its original start time. Factory_ON,
AutoTrading, terminal deployment, paid FTMO purchase/money state and live trading were not
mutated or authorized.

## Remaining restart blockers

The Factory source mechanics are prepared but restart is not yet authorized. The remaining
fail-closed decisions are the schema-v2 restore intent for 21 tasks, T5/minimum-worker
policy, the exact MNT-003 OWNER apply, the five external-residual exit-contract decisions,
and a final visible-session restart authorization. This receipt closes durable source and
dashboard publication only.
