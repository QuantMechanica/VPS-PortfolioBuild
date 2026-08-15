# QM5_10565 GBPUSD H6 Q02 performance repair

Date: 2026-08-15

Branch: `agents/board-advisor`

EA / symbol: `QM5_10565_mql5-rvidiff` / `GBPUSD.DWX` H6

## Outcome

The source-exact RVIDiff turn is now evaluated once per completed H6 bar rather
than on every modeled tick while a position is open. The repaired, strictly
compiled EA was appended to Q02 as work item
`5228a7e6-70bd-43f2-a891-59ea36cdfefd`. At handoff it was `pending`; normal
paced-fleet dispatch owns execution.

This is a diversity-throughput unit: GBPUSD is an FX sleeve, while all seven
current Q08 `FAIL_SOFT` survivors are concentrated in indices, metals, and
energy. The approved-build backlog review exposed no collision-free, genuinely
unbuilt diversity card that was eligible to build: the apparent candidates were
already built/progressed or remained blocked upstream by feed/source-mechanic
gates. This made the existing diverse Q02 infrastructure failure the next
eligible mission priority.

The approved Strategy Card is
`D:\QM\strategy_farm\artifacts\cards_approved\QM5_10565_mql5-rvidiff.md`.
Its R1-R4 criteria are `PASS`; the reputable source is Nikolay Kositsin's MQL5
CodeBase RVIDiff implementation (`https://www.mql5.com/en/code/16222`). The
strategy is structural and low-frequency: closed-bar RVIDiff direction changes
on H6, with an ATR hard stop and fixed reward/risk target.

## Farm coordination

- repair task: `249b9f36-e54c-46b3-8d2c-25f06fe7a0f9`
- claim:
  `manual:codex:agents/board-advisor:QM5_10565:GBPUSD.DWX:q02-h6-hotpath-recovery:20260815T195131Z`
- pre-claim database backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10565_gbpusd_hotpath_claim_20260815T195131Z.sqlite`
- pre-enqueue database backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10565_gbpusd_fresh_q02_seed_20260815T200237Z.sqlite`

The atomic claim check found no open exact-target work item and no competing
claim. Other active agents owned distinct EAs. Before enqueue, factory capacity
was 2/7 terminals and the latest five-sample host CPU average/max was
58.34%/63.97%, below the farm ceiling.

## Diagnosis

The latest artifact-bound GBPUSD row,
`7ceeb1b3-2936-488e-ad1f-222aab61faff`, is terminal
`failed / INFRA_FAIL / ACTIVE_TIMEOUT`. It reached 61% tester progress after
57.86 minutes and was killed by its outer absolute ceiling. No report-based
economic verdict exists.

Its bound artifacts were:

- MQ5: `e8a6395f3bd285c7533b1312dbfbde6372ac3bd1e13582ae9cdf778f187f5137`
- EX5: `617f604e8bdd0efb85e1c45887f0bac58a59f53e4d2b84939b883d7a886aad12`
- setfile: `1918da3e4cbc1f51349bca96e16a766a990d7a7d34277f2e2f5b7cbf3bf35f9a`

The implementation called `Strategy_RviDiffTurn` from the per-tick exit path
whenever the EA held a position. One turn calculation expands to three
RVIDiffs; each RVIDiff expands to five ten-period RVI-main evaluations, and
each raw RVI sample performs four OHLC series reads across four bars. That is
approximately 2,400 raw series reads per modeled tick even though the source
signal can only change at an H6 close. This deterministic hot path explains the
long active run without converting the infrastructure timeout into a strategy
failure.

## Repair

- Added one cached `g_rvidiff_bar_turn` value.
- Used the framework's `QM_IsNewBar(_Symbol, strategy_signal_tf)` gate before
  computing the turn.
- Reused that single closed-bar value for the opposite-turn exit and same-bar
  entry.
- Retained the source-exact RVI OHLC kernel; its four bespoke series calls are
  explicitly marked `perf-allowed` because they now execute only once per H6
  bar.
- Updated `SPEC.md` revision history to document the performance repair.

No entry condition, exit condition, period, ATR bracket, target, symbol scope,
or risk setting changed. All four backtest presets remain `RISK_FIXED=1000`
and `RISK_PERCENT=0`.

## Validation and artifact binding

Strict compilation completed with `0 errors, 0 warnings`:

- log:
  `C:\QM\repo\framework\build\compile\20260815_200456\QM5_10565_mql5-rvidiff.compile.log`
- log SHA-256:
  `5544658121da13a92cb8d4ed814052e17d701e4742c7d4a057efe43acf936780`

The EA-scoped strict build check completed `PASS` with zero failures and zero
warnings:

- report: `D:\QM\reports\framework\21\build_check_20260815_200541.json`
- report SHA-256:
  `d1ec236cd7617845710738176b31fb68639c3886276dd4c0be5773df6cc0ba64`

Additional checks passed: Strategy Card/spec validation, build guardrails with
no findings, `SINGLE_SYMBOL_OK` symbol scope, and magic-registry resolver dry
run (`15970 rows kept, 0 dropped`). The resolver used registry SHA-256
`990dd148b961198c19cb620a8f83e228a8cd8b88d94d0505d762ec8e845cb423`.

Current bound artifacts are:

- MQ5:
  `2bd60dacb140020ad3837480d2dec1196ea8086eb421ecce3ef2efeccff783a9`
- EX5:
  `c7637a0a966d6697749bb5a37c959679b70055dd39431e358b21d829e80e0a4b`
- GBPUSD H6 backtest setfile:
  `1fb323cc231cfb7d0f82887389a9994c06d7225dfe38fdf984783af952058278`

Implementation commits:

- `1351851c7f3559eed4f28e3f846dc4f00fa7ce2b` — gate RVIDiff to completed H6
  bars and rebuild the EA.
- `9441313193404039065898a4769429002156b6fd` — seal the four fixed-risk
  backtest presets to the final build.

## Governed Q02 handoff

The evidence log named by the later artifact-bound timeout row has been purged,
so that immutable row was not reused as rerun evidence and was not modified.
The governed `farmctl seed-fresh-q02` path instead preserved terminal
pre-execution-binding row `efbe636c-1fd7-49fe-91dc-e22d26457b0f` and appended
one current-hash Q02 row:

- new work item: `5228a7e6-70bd-43f2-a891-59ea36cdfefd`
- phase / instrument / period: `Q02 / GBPUSD.DWX / H6`
- range: `2017.01.01` through `2022.12.31`
- enqueue mode: `fresh_q02_seed=true`, historical row preserved
- risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- expected MQ5, EX5, and setfile hashes: exactly the current hashes above

Both predecessor rows remained terminal and unchanged. No local smoke test,
manual dispatch, or backtest was started. `T_Live`, AutoTrading, the portfolio
gate, and the live deploy manifest were not touched.
