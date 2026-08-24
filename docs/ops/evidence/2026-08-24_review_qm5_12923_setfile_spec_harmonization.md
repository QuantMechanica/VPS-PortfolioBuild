# Review: QM5_12923 hopwood-dmi-cross-h1-card — agy setfile-gen + SPEC harmonization

- Router task: review_ea `a907ca7c-a3d5-4486-9ab6-f5c8715131b5`
  (reason `codex_review_required_for_gemini_code`, source_agent gemini/agy,
  source build task `f9e1abeb-a14c-4f02-9869-b9d99fcbf303`, task_type build_ea)
- Source artifact: `C:/QM/repo/artifacts/qm5_12923_build_result.json`
- Worker verdict: "Generated missing 4 setfiles (NDX, SP500, UK100, WS30) and
  harmonized SPEC.md symbol universe to match all 9 setfiles"
- Predecessor review: `docs/ops/evidence/2026-08-21_review_qm5_12923_hopwood_dmi_cross_h1.md`
  (Claude pass, no code defects, flagged exactly the missing NDX/WS30/UK100/SP500 setfiles)

## Scope of this delivery

The .mq5 is unchanged by this task (mtime 08-21 17:15; SPEC + sets 08-23 18:40).
This review covers only the agy delivery: the 4 new backtest setfiles and the SPEC
symbol-universe harmonization. Code was already reviewed clean on 08-21.

## Findings

- **Source hash still current.** `sha256(QM5_12923_...mq5) =
  6d0d02a3fcc80f9fdd01bde9fb1acd4638b1d34aaa4949d5c13442fbb60288e2`, matches the build
  artifact's `mq5_sha256`. Build evidence `build_check_passed: true` /
  `compile_succeeded: true` (compile log `framework/build/compile/20260821_151621/`)
  remains valid — the setfile/SPEC edits do not touch the compiled source.
- **All 7 strategy inputs wired** (re-confirmed): `strategy_dmi_period`,
  `strategy_adx_threshold`, `strategy_atr_period`, `strategy_atr_sl_mult`,
  `strategy_take_profit_rr`, `strategy_adx_exit_threshold`, `strategy_require_h1` each
  read at a use site in `Strategy_EntrySignal` / `Strategy_ExitSignal` /
  `Strategy_NoTradeFilter`. No dead inputs.
- **Framework conformity** (mq5): `#include <QM/QM_Common.mqh>`; `QM_FrameworkInit` arg
  order correct; MAE hook `QM_FrameworkTrackOpenPositionMae()` first in `OnTick`;
  RISK_FIXED=1000 / RISK_PERCENT=0 backtest mode; magic via `QM_FrameworkMagic()` and
  `req.symbol_slot = qm_magic_slot_offset`; news filter wired (temporal+compliance path);
  bounded `iADX`-family buffers via `QM_ADX*` helpers; no raw series, no ML, no invented
  commission/swap.
- **Setfiles: 9, all valid.** All params identical across sets except the correct
  per-symbol `qm_magic_slot_offset`. Each carries the governed-generator header (QM5 Set
  File / build_hash `c602c238…`, same hash as the 08-21 Codex-generated sets). 11
  key=value lines each. New sets omit two cosmetic comment lines
  (`must be appended below…`, `card_defaults_source=…`) that the 08-21 sets carry —
  format drift only, no functional difference.
- **Magic slots match registry exactly** (`framework/registry/magic_numbers.csv`,
  ea_id*10000+slot): GDAXI=0, NDX=1, SP500=2, UK100=3, WS30=4, EURUSD=6, GBPUSD=7,
  USDJPY=8, AUDUSD=10. No collisions.
- **XAUUSD correctly excluded.** Card §"Explicitly NOT for" lists XAUUSD; registry
  reserves slot 5 for it but no setfile was generated. Correct.
- **SPEC ↔ setfiles ↔ registry consistent.** SPEC §3 lists the same 9 symbols as the
  setfiles and the registry-active universe. The 08-21 review's setfile/SPEC symbol-count
  gap is now closed.

## Note (non-blocking)

The approved card's R3 "suggested P2 basket" names FX majors + JPY-crosses (EURUSD,
GBPUSD, USDJPY, AUDUSD, EURJPY, GBPJPY). The realized universe replaces the JPY-crosses
with equity indices (GDAXI, NDX, SP500, UK100, WS30). This universe was fixed by the
governed allocator on 08-17 (predates this task) and the card basket is a suggestion, not
a hard constraint (skeleton item). A DMI/ADX trend mechanic on indices is defensible;
Q02 economics + activity gate will judge each symbol on its own evidence. Not a defect in
this delivery.

## Verdict

**APPROVED (clean for Q02).** No code, setfile, registry, or SPEC defect. The delivery
closes the exact gap the 08-21 review flagged. Source hash unchanged and compile
evidence current. Smoke-under-privatized-worker is the normal Variant A custom-history
gate, handled by the pipeline, not a build defect.
