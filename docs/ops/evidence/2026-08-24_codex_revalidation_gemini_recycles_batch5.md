# Codex revalidation — recycled Gemini EA reviews, batch 5

- Reviewed at: `2026-08-24T15:41:32Z`
- Router agent/state: `codex / IN_PROGRESS`
- Scope: eight priority-51 `review_ea` tasks still assigned at the submission preflight
- Disposition: **REVIEW / FAIL** for every task below; none is accepted or advanced to PIPELINE
- Review mode: read-only source/card/build-evidence inspection plus focused static tests; no EA,
  setfile, registry, resolver, compiler queue, backtest queue, terminal, factory, AutoTrading, or
  `T_Live` state was changed

## Cohort result

The source repairs for QM5_12922, QM5_34003, and QM5_12940 pass their focused regression tests and
static guards, but their tracked EX5 files still predate the repaired source. They therefore remain
build-blocked. The other five EAs retain independently reproduced source/corset defects. Static
guardrail PASS is recorded where obtained, but is not treated as card fidelity, a compile receipt,
or pipeline evidence.

## Task findings

### `9de2c519-2ca6-480b-a568-ac5f90611962` — QM5_12936

- MQ5 SHA-256: `d3b929391c52589845eb05ba7fe91a7cb014046d0db02ceff8e37fbd3440e03c`
  (`9ad5fd821af7c1955921e4f68ee4b24f31f1f167`, 2026-08-23).
- EX5 SHA-256: `b84346fc6bf6b7bdbd8f2656b35df6d4b5bef61c89ce67b104134a9beca28934`
  (`6d41fee804b9f2fb4ab585004190aa6ae18c4c94`, 2026-08-21). The binary predates the source rewrite.
  `build_result.json` repeats both current file hashes and claims compile success, but supplies no
  post-source compile provenance; it cannot bind the old EX5 to the current MQ5.
- The card requires the standard QM news-calendar pause. Source lines 22-26 default temporal,
  compliance, and legacy news modes OFF, and none of the 13 setfiles overrides them.
- The stateful `QM_IsNewBar` edge is consumed in `Strategy_ExitSignal` at line 310 and again at the
  entry gate at line 375. A close on that edge suppresses a valid same-edge entry. The eight-H4-bar
  card time stop is wall-clock seconds at line 306, and directional cooldown is consumed at signal
  creation (lines 185/211), before confirmed order success at line 382.
- Verdict: **FAIL** — current source needs the news/new-bar/lifecycle fixes, followed by a governed
  compile that binds the resulting MQ5 to a fresh EX5.

### `189e5210-e341-47ea-8465-6838bdeeaa83` — QM5_12946

- MQ5 SHA-256: `e0adb638e3586a0c6d492e03f2ec2685cd49a63482a9ee2ba583166c3c3213b8`.
- EX5 SHA-256: `35d2f0c19faea9e15da547a2416627789e3e6f009f00786c839c93893e9bb52a`.
  The tracked build result matches these bytes and the binary commit follows the source commit.
- The remaining defect is source-level: `g_exit_cached` is set only inside
  `Strategy_EntrySignal` (lines 298/302). In `OnTick`, the cache is consumed at line 450, but the
  only code that can refresh it runs at line 483, after the news rejection at line 473 and new-bar
  rejection at line 476. Opposite-divergence/MACD-zero protective exits arising during a blackout
  are therefore not detected independently of entry filters.
- Verdict: **FAIL** — relocate exit detection into news-independent management/exit handling and
  recompile before acceptance.

### `98a8ca09-c712-4064-866e-cf7112c465d5` — QM5_1417

- MQ5 SHA-256: `81ef61c05c0fb6be24cdb1b58b537eeaf5f77fa30a9754afcbcaef264d22f3bc`
  (`0c4d5e34df7807038b9fc60b3e8d2c6351821263`, 2026-08-24).
- EX5 SHA-256: `a22a278f4526793299851a1f4557bcaa9ee3fceb411c14d26726e68051830ee9`
  (`09f175aefd1dd11f0af0ac66dd14923a6b0f1528`, 2026-08-22). The source artifact was built from
  MQ5 hash `8f01e6c7...`; it does not cover the reviewed rework.
- The four earlier card defects are fixed and label-scoped semantic hardening is clean. However,
  raw `CopyBuffer` calls remain at lines 303 and 443 without a permitted framework helper path.
  This is the unconditional `EA_FRAMEWORK_RAW_COPYBUFFER` build-corset defect.
- Verdict: **FAIL** — replace both raw reads with QM indicator readers while preserving shift
  chronology, then obtain a governed compile receipt for the repaired source.

### `aa15d2e4-40a5-40b0-a8a1-0df2d4b3cc62` — QM5_12931

- MQ5 SHA-256: `332a07aa4649abc7421544c9c79f4f15a587d07a30371e8b09fe5f0b6d9af994`
  (`02f10d024c13745e9270478456fbfe92aaa625c0`, 2026-08-23).
- EX5 SHA-256: `bbec94b09d6a542508e22da0f64661b11444ddb3f992b67559bd756aaa6ad98f`
  (`c8b3857cd1f795414a0d3136353c039f08de9815`, earlier than the source rewrite).
- Fresh semantic hardening reproduces four failures: missing card-required SELL_STOP, inverted D1
  SMA direction at line 187, 30/30-minute news versus the card's 480/480 minutes, and news return
  before management at line 575. Direct inspection also confirms dead
  `strategy_peak_height_atr` (declaration only), raw indicator/buffer access, ignored
  `QM_TM_PartialClose` result at line 490 with unconditional `g_tp1_done` at line 492, and
  restart-unsafe management state.
- Verdict: **FAIL** — substantive card/corset rework and a fresh governed compile are required.

### `c70f99bf-2ad7-46a6-a399-3fa8b0213fa9` — QM5_12932

- MQ5 SHA-256: `5c7d464458c606691c0eaa03824e9f02b3f3acf053a76a95e617775fb72330ab`
  (`c7e76646dff5fe43c54b872e61197a470ab75671`, 2026-08-23).
- EX5 SHA-256: `b4fed9ffa6c40e8ecaec9ac5a68059edbc96f5100a0c4b690408dcfb0bb8e391`
  (`c8b3857cd1f795414a0d3136353c039f08de9815`, earlier than the source rewrite).
- Fresh semantic hardening reproduces the card news failure: all news defaults are OFF at lines
  22-26 versus the required 480/480-minute blackout. Direct inspection also confirms kill-switch
  return before MAE sampling (lines 447-448), a wall-clock rather than completed-H4-bar time stop
  (line 406), range state consumed before order success (lines 350-351), the one-sided Gate-6
  resistance condition (lines 285-287), and no card-required 60% TP1 partial / TP2 at 1.5 range.
- The approved card is currently present on `D:`; the earlier "card missing" observation is not
  repeated here.
- Verdict: **FAIL** — source lifecycle/exit/news rework and a fresh governed compile are required.

### `089cc8c8-db14-4c63-90fc-7fa2aa5f711f` — QM5_12922

- Repaired MQ5 SHA-256: `bc443d4aa952b076caa50cbd9b0ce2b63514067f7466d6865d37d18fd77b0415`
  (`eb9b986d01c280f7bb874b9d7b34ef85c6c77ebe`, 2026-08-24).
- Tracked EX5 SHA-256: `49ab4db2d889eff07eb7441388b6222bf253f16cb52446704991c3581204e274`
  (`06e013ec4eade4039975e832cab3f2924822eb26`, 2026-08-21).
- Focused rework tests pass and current hardening/guardrails are clean. Restart-safe monthly-state
  reconstruction, named macro-day deferral, success-gated signal consumption, and disabled Friday
  liquidation are present. The existing build result is bound to older MQ5 hash
  `02bdd8bd...`, not the reviewed source, and its EX5 is unchanged.
- Verdict: **FAIL (binary binding only)** — source rework is review-clean, but a governed compiler
  must build and bind this exact source before Q02.

### `1ff032e2-8ae5-44ed-9494-9832debee9bb` — QM5_34003

- Repaired MQ5 SHA-256: `fd6990e4d3c1d26c13bca696f8ab9c200856318447a71628eda680385d9d48d7`
  (`f6e7ed208e6fc61bd04b738fe3f31974823d6a4f`, 2026-08-24).
- Tracked EX5 SHA-256: `5b4d5c197f621d2c5e987631ec1c285b1dc923fdc8255a3b443b35cce45d2a6a`
  (`c30b529bf0f7be9901199fb7b926268245204ea1`, 2026-08-17).
- Focused rework tests pass and current hardening/guardrails are clean. Card risk, UTC rollover,
  framework wiring, MAE ordering, and the three-symbol universe are covered. All three setfiles
  deliberately retain `build_hash: pending`; the source artifact covers older MQ5 hash
  `d276dac1...` and the old EX5.
- Verdict: **FAIL (binary binding only)** — source rework is review-clean; fresh governed EX5 and
  setfile build-hash binding are required before Q02.

### `c600e224-e78c-46a2-853e-b1f4ffd26e42` — QM5_12940

- Repaired MQ5 SHA-256: `2d320dc7c7bb9d5c5c2a3baf2b7831b7531b6f23fc5d2fb94e8484278ea0e68b`
  (`9dc2c7a60ed7f007f945355c749ea2984411093f`, 2026-08-24).
- Tracked EX5 SHA-256: `a0e09832809f652fd62fb674208bf4b49f6775a173fa9a655e17b1f1ee292c28`
  (`c877d9f987336208576e213755f7247cbd8263a3`, 2026-08-21).
- Focused rework tests pass and current hardening/guardrails are clean. The current source has
  bounded DSS arrays, success-gated partial state, durable T1 reconstruction, accepted-order-only
  cooldown, and management before entry filters. The current build result covers older MQ5 hash
  `1f7db842...` and the unchanged old EX5.
- Verdict: **FAIL (binary binding only)** — source rework is review-clean, but the governed compile
  and regenerated binding evidence remain mandatory.

## Focused verification

- `pytest` over the QM5_1417, QM5_12922, QM5_34003, and QM5_12940 rework suites:
  `23 passed`.
- `build_gate_hardening.py --ea-label ...`:
  - QM5_12931: four failures listed above.
  - QM5_12932: one failure, news window OFF versus 480/480.
  - QM5_1417, QM5_12922, QM5_12936, QM5_12940, QM5_12946, QM5_34003: zero
    label-scoped semantic-hardening failures.
- `validate_build_guardrails.py` on all eight directories: PASS, zero findings, news stale ceiling
  `336` hours.
- Every setfile in the eight directories has `RISK_FIXED > 0`, `RISK_PERCENT = 0`, and no
  `qm_news_stale_max_hours` above 336. All eight MQ5 defaults are exactly 336.

## Handoff

These are Gemini-origin code tasks, so they remain in REVIEW. This evidence supplies review
verdicts only; it does not authorize pipeline progression, compile/backtest work, or live use.
