# QM5_12779 WTI Weekend Gap Bounce Q02 Enqueue

Date: 2026-06-29

## Scope

- Built `QM5_12779_wti-weekend-gap-bounce`, a structural low-frequency
  `XTIUSD.DWX` D1 negative Monday weekend-gap-fill sleeve.
- Source lineage: "TGIF? The weekend effect in energy commodities", Journal of
  Finance Issues, URL https://jfi-aof.org/index.php/jfi/article/view/2264.
- Runtime logic: long only when the Monday D1 open gaps meaningfully below the
  prior Friday close, ATR hard stop, prior-Friday-close TP, Monday/max-hold
  stale exit.
- Backtest setfile risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Non-Duplicate Selection

- Rejected XAU/XAG ratio reversion because XAU/XAG ratio and breakout baskets
  already exist.
- Rejected positive WTI Monday weekend-gap fade because `QM5_12750` already
  covers that short-only side.
- Rejected all-Monday WTI short and WTI weekday/month/event/roll/refinery/OPEC/
  hurricane/trend concepts already present in the registry.
- Selected the one-sided negative Monday WTI gap-fill long because it is a
  distinct information set and direction from the existing WTI gap/day sleeves.

## Files

- EA: `framework/EAs/QM5_12779_wti-weekend-gap-bounce/QM5_12779_wti-weekend-gap-bounce.mq5`
- Binary: `framework/EAs/QM5_12779_wti-weekend-gap-bounce/QM5_12779_wti-weekend-gap-bounce.ex5`
- Setfile:
  `framework/EAs/QM5_12779_wti-weekend-gap-bounce/sets/QM5_12779_wti-weekend-gap-bounce_XTIUSD.DWX_D1_backtest.set`
- Approved card:
  `strategy-seeds/cards/approved/QM5_12779_wti-weekend-gap-bounce_card.md`
- Build result: `artifacts/qm5_12779_build_result.json`

## Validation

- `python framework/scripts/update_magic_resolver.py`: PASS, resolver updated.
- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_12779_wti-weekend-gap-bounce`:
  PASS.
- `python framework/scripts/skill_card_schema_lint.py --card strategy-seeds/cards/approved/QM5_12779_wti-weekend-gap-bounce_card.md`:
  PASS.
- Targeted registry check: PASS, exactly one `ea_id_registry.csv` row for
  `12779` and one `magic_numbers.csv` row for `127790000`,
  `XTIUSD.DWX`, slot `0`.
- `powershell -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12779_wti-weekend-gap-bounce/QM5_12779_wti-weekend-gap-bounce.mq5 -Strict`:
  PASS, 0 errors, 0 warnings.
- `powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12779_wti-weekend-gap-bounce -RepoRoot C:/QM/repo -SkipCompile`:
  PASS, 0 failures, 16 shared-framework DWX advisory warnings.
- `python framework/scripts/validate_registries.py --json`: not used as a
  blocking signal because the working tree already has unrelated legacy
  registry issues; targeted checks for this EA passed.

## Hashes

- MQ5 SHA256:
  `605c4b5c69b4446e748c652e937f2e0825a9e93d37e9949bc6a88d128f99484b`
- EX5 SHA256:
  `41edbc4f0c97be837ec1b8f57440fcda9625f0c8a6e9e5ff301de418d515e400`
- Setfile current SHA256:
  `cc359e8bdfeecf589454edb5372aab7311b1983d6453db3ed5430fdc0ea29f88`
- Setfile header `build_hash`:
  `91211967c6d7f27c69675c90aff0037867327f908de4fb6326503502d51adb99`

## Q02 Queue

- Enqueue command:
  `python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_12779 --queue-ceiling 10000 --max-part2-per-run 0`
- Queue DB: `D:\QM\strategy_farm\state\farm_state.sqlite`
- Work item: `83042e3e-6215-46e2-8ddb-1dc306edd1ad`
- Phase: `Q02`
- Kind: `backtest`
- Symbol: `XTIUSD.DWX`
- Status after final check: `pending`
- Created/updated: `2026-06-29T13:53:36+00:00`

## Safety

- No `T_Live` manifest touched.
- No AutoTrading toggle or live terminal action.
- No portfolio gate, portfolio admission, portfolio KPI, or Q08 contribution
  artifact touched.
- No manual MT5 backtest was launched; paced fleet Q02 owns execution.
