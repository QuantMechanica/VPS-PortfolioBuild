# QM5_10269 EURUSD.DWX Q02 requalification

- Outcome: appended Q02 successor `126a18c2-63cd-4ac7-b7b8-feb97178c835` in `pending` state for `EURUSD.DWX` / `D1`.
- Coordination task: `a535db5f-e9ff-4028-8b4c-c9d9f37b98d8` (`infra_repair`), claimed and completed by `codex:agents/board-advisor`.
- Preserved predecessor: `c246db5e-4425-4cb8-82d9-fe48deaa1c5a`, `done` / `INFRA_FAIL` (`ONINIT_FAILED;INCOMPLETE_RUNS`).
- Diagnosis: the failed run was bound to the stale June EX5 `13e0f1e170447b6a951a19f617b8f8534337bc428219467d48f0d7a57cb8680c`. The authorized September source repair rebuilt against the current expanded magic resolver and restored framework wiring without changing the WMA30 strategy.
- Current MQ5: `ba1bdd99f02957c30d854a243aa870fdbda719cdee8fc0d76b8d788a1c0b1801`.
- Current EX5: `284d46702d34032f95322197fed9295d6e4296ffd387da49c5aa76b7961aecf6`.
- Governed compile: work item `3a92321c-deb2-45a0-872e-c39d8602d5cb`, PASS with 0 errors and 0 warnings; evidence SHA-256 `224f984c0cdd03c3f5d0d35075f0aa39f40eee449e24b912b60ee59f5ea2fb74`.
- Current setfile: `1eaca5f887334b2d06d7413c52f4d0fe7c8fcf1bb82787e3da7b5a7eec8010b0`; `RISK_FIXED=1000`, `RISK_PERCENT=0`, `qm_magic_slot_offset=5`.
- Semantic comparison: 10 parameters recovered from the predecessor; parameter change count 0, including all `strategy_*`, EA/magic, and risk fields.
- PACER input-pin audit: exit 0, `EA_FRAMEWORK_INPUT_PINNED` hit count 0.
- CPU admission sample immediately before the mutation: 94.9%, 79.7%, 87.3%, 82.4%, 71.6%; average 83.2%, maximum 94.9%, both below the 97% ceiling.
- Mutation boundary: governed `farmctl requalify-q02 --apply`; no compile enqueue, terminal launch, AutoTrading, portfolio-gate, T_Live, or live-manifest mutation.
- Receipt: `q02_requalification_receipts/c246db5e-4425-4cb8-82d9-fe48deaa1c5a_126a18c2-63cd-4ac7-b7b8-feb97178c835.json`, SHA-256 `21c29a2f22751482646f073dea4c4d212a81148bbb878fb6b21ce0b26600009e`.
