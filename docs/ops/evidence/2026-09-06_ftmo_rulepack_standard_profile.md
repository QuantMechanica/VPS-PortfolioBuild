# FTMO Standard V2 rulepack and M13 binding — 2026-09-06

## Disposition

- Router task: `6b291f21-0e6e-415e-90c1-e973cb3fd09c`
- Verdict: **REVIEW — pin incoherence documented and M13 Standard binding implemented**
- Code branch: `agents/codex-ftmo-rulepack-standard-20260906`
- Code commit: `f6e957410bc84d3cb64764fffb9cc8ae8af07266`
- Parent dependency: FTMO governor commit `bcb589a0656f0ea83580bbd7972de2093ccac35d`
- Live boundary: no terminal, `T_Live`, account, chart, preset installation, AutoTrading, purchase, or pipeline state was changed by this task.

## What was incoherent

Commit `0abbc24b02cac27632a2e449128589aa9d2abffe` (2026-09-02) renamed the FTMO Swing rulepack from V1 to `FTMO_2S_100K_SWING_V2`, advanced `profile_version` from 1 to 2 and `as_of` from 2026-07-29 to 2026-09-02, and repointed **all seven** official-source rows to:

- `docs/ops/evidence/2026-09-02_ftmo_economic_terms_snapshot.json`
- SHA-256 `daef9de5a3c9093a8b13d9f86cf7525937d4d5c0e0bade1c4aedaa31658e933d`
- declared identity basis `NORMALIZED_PROVIDER_RULE_SNAPSHOT`

That target was not a complete provider-rule snapshot. Its schema was `qm.ftmo-economic-terms-snapshot/v1`; it contained only three economic component URLs and facts for fee/refund/reward split/scaling plus Swing leverage. It contained no normalized 2-Step objective, daily-loss, total-loss, minimum-days, news, weekend, EA-limit, or prohibited-practice contract. In particular, the source rows named `ftmo_trading_objectives_official`, `ftmo_news_official`, `ftmo_weekend_official`, `ftmo_ea_official`, and `ftmo_forbidden_practices_official` claimed an identity that the target snapshot did not contain. This was the precise V2 pin-chain defect.

The Swing chain was subsequently repaired before this task:

- `2d3a3cf272` — initial coherence repair.
- `82e14c7e80` — retained real 2026-09-04 VPS responses, normalized 28 of 30 claims, recorded two carried-over Swing leverage claims after the trading-symbols URL returned HTTP 404, and repointed all seven rows to the full official-rules snapshot.

Current Swing V2 now has `profile_version=2`, `as_of=2026-09-04`, and all seven sources bind `docs/ops/evidence/2026-09-04_ftmo_official_rules_snapshot.json` at SHA-256 `c199b8f5f528cce5a93f4751f63394de63e5fe832483ac9c4b9d0314732d2905`. This task did **not** edit the Swing profile.

## Remaining account/profile mismatch

M13 is login `1514536732` on `FTMO-Demo`, account variant `STANDARD_2STEP_100K_FREE_TRIAL`, with terminal-observed leverage `1:100`; see `docs/ops/evidence/2026-09-06_ftmo_demo_account_terms.md` at SHA-256 `3b1d605ab0a45f0c2115ca14c17701788f47610ce936bd4b59b8b27b4bc39964`.

Before this task:

- `tools/strategy_farm/ftmo/trial_setpath.py` hard-coded an absolute canonical path to `FTMO_2S_100K_SWING_V2.json` while its own manifest declared a Standard Free Trial.
- `tools/strategy_farm/portfolio/ftmo_book3_standalone_evaluator.py` accepted only the exact Swing header/rule set. It had no explicit Standard selection contract.
- QM5_13206's M13 governor presets already carried the conservative Standard-demo controls, but no durable configuration bound those presets and the evaluator to a Standard target profile.

## Resolution

### Separate Standard rulepack

Added `tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_STANDARD_V2.json`:

- rulepack ID `FTMO_2S_100K_STANDARD_V2`
- `profile_version=2`
- `as_of=2026-09-04`, matching the source corpus actually pinned
- file SHA-256 `dbec549474680a2e04b7677f249d180d7dbd65af1a8a6a0e72c654682707faa3`
- QM canonical JSON SHA-256 `d24b19d7080bae2302846072cf7b6ed74bc0082ebede684979e292ea8269f276`
- official 2-Step maximum daily loss 5% / USD 5,000, Prague midnight reset
- official maximum loss 10% / USD 10,000, static USD 90,000 floor
- no Swing rule IDs or Swing leverage claims
- Standard funded-account selected-news restriction represented explicitly: ±2 minutes, targeted instruments, opening/closing/pending execution prohibited, pre-existing holding permitted except stop/target execution in the window
- Standard funded-account weekend/long-break restriction represented explicitly: close before the weekend or a market break longer than two hours

The retained 2026-09-04 snapshot envelope was produced for the Swing audit, so its normalized-claim names remain Swing-specific. It is reused here as an immutable **source corpus** because it contains and hash-binds the same seven official pages plus retained raw news/weekend responses from which the Standard facts were checked. The old 2026-09-02 economics-only snapshot is not reused. No source vintage was restamped and no evidence file was rewritten.

FTMO's retained provider pages say the selected-news and weekend rules apply to Standard funded FTMO Accounts and do not apply during Evaluation. The OWNER nevertheless requires M13's Standard Free Trial to use the stricter blackout and Friday-flat posture. The profile therefore keeps those two authorities separate:

- provider facts: `ftmo_standard_news` and `ftmo_standard_weekend`, including `evaluation_restricted=false` and `ftmo_account_standard_restricted=true`;
- QM/account facts: OWNER-ratified `qm_ftmo_m13_standard_demo_operating_overlay`, including observed `1:100`, PRE30/POST30 FTMO compliance, fail-closed news age `336` hours, Friday close at broker hour 21, and five-minute flat lead.

The `1:100` value is deliberately **not** presented as a public-provider rule derived from the 2026-09-04 snapshot. It is an exact M13 terminal observation bound to the account-terms evidence.

### M13 configuration binding

Added `tools/strategy_farm/config/ftmo_m13_standard_demo.v1.json`. It binds all of the following in one review-only contract:

- exact M13 account variant/login/server and the 1:100 account-terms evidence hash;
- Standard V2 path, ID, version, vintage, file hash, and canonical hash;
- standalone evaluator selection mode `EXPLICIT_M13_DEMO_BINDING`;
- 5% daily / 10% total / Europe-Prague limits;
- the exact QM news and Friday-flat overlay, with `news_stale_max_hours=336`;
- governor EA 13206 and signed policy `FTMO_2S_P1_100K_V2`;
- bootstrap preset SHA-256 `c189004f19e89fd83dd563cfd9334bc5b60c67cb9302b65217ad3ebbb7fb40f2`;
- active preset SHA-256 `8537309436144497e42ccdee94426eeb5d7bad95f3568f92ba01bf532dedb061`;
- explicit false values for install, attachment, AutoTrading, and purchase authority.

`trial_setpath.py` now consumes this binding instead of the old absolute Swing path. It refuses account/evidence/rulepack/preset hash drift, rule semantics drift, overlay drift, or any widened authority. Its review manifest is now `qm.ftmo-trial-setpath/v3` and names Standard V2 directly rather than describing a Swing rulepack with Standard overrides.

The standalone evaluator retains Swing as its historical default, but now validates Standard V2 under a separate exact header/rule/guardrail/deployment contract. Its `--m13-demo-binding` option resolves the Standard path from the hash-bound configuration and is valid only while preparing a manifest with no competing `--rulepack` override. Thus existing Swing Book-3 evidence is not silently reinterpreted, while M13 has an explicit Standard selection path.

The target-rulepack validator now accepts only the two exact FTMO V2 identities (Swing and Standard), rejects profile cross-contamination, and requires the M13 Standard overlay to retain 1:100, PRE30/POST30, `336`, and Friday-flat parameters. The review-SLA tracker includes Standard V2 through 2026-12-05.

## Verification

Executed in `C:/QM/worktrees/codex-ftmo-rulepack-standard-20260906` at code commit `f6e957410b`:

```text
python -m pytest \
  tools/strategy_farm/tests/test_target_rulepacks.py \
  tools/strategy_farm/tests/test_rulepack_review_sla.py \
  tools/strategy_farm/tests/test_target_outcome_dossier.py \
  tools/strategy_farm/tests/test_ftmo_trial_setpath.py \
  tools/strategy_farm/tests/test_ftmo_evaluator_fidelity.py \
  tools/strategy_farm/tests/test_ftmo_demo_governor_contract.py \
  tools/strategy_farm/tests/test_runtime_execution_contract_static.py \
  tools/strategy_farm/tests/test_ftmo_book3_standalone_evaluator.py -q

171 passed in 39.47s
```

Additional checks:

```text
python -m py_compile tools/strategy_farm/target_rulepacks.py \
  tools/strategy_farm/ftmo/trial_setpath.py \
  tools/strategy_farm/portfolio/ftmo_book3_standalone_evaluator.py
PASS

python tools/strategy_farm/target_rulepacks.py FTMO_2S_100K_STANDARD_V2 --json
PASS canonical_sha256=d24b19d7080bae2302846072cf7b6ed74bc0082ebede684979e292ea8269f276

python -c "from tools.strategy_farm.portfolio.ftmo_book3_standalone_evaluator import resolve_m13_standard_rulepack; print(resolve_m13_standard_rulepack())"
PASS .../FTMO_2S_100K_STANDARD_V2.json

git diff --check
PASS
```

No pipeline verdict is asserted. The code and this evidence remain in REVIEW for Codex/OWNER close-out and integration.
