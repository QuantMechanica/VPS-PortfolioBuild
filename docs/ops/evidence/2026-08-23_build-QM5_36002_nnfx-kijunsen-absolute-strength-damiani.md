# build-QM5_36002_nnfx-kijunsen-absolute-strength-damiani evidence

- Ticket: `build-QM5_36002_nnfx-kijunsen-absolute-strength-damiani`
- EA: `QM5_36002_nnfx-kijunsen-absolute-strength-damiani`
- Approved runtime card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_36002_nnfx-kijunsen-absolute-strength-damiani.md`
- Source SHA-256: `c5e1a8fee00b74a80f82c28397fa02bdc02557db0fc59ea9e04a1386df695480`
- Build boundary: source/spec/setfiles/registries/static validation only. No compile, smoke, backtest enqueue, router task, factory toggle, verdict mutation, or `T_Live` access.

## What changed

The ticket premise that the EA and registry rows did not exist was stale in this
worktree. The pre-existing partial build was completed in place without creating
duplicate IDs or magic allocations.

- `framework/EAs/QM5_36002_nnfx-kijunsen-absolute-strength-damiani/QM5_36002_nnfx-kijunsen-absolute-strength-damiani.mq5:37-57`
  exposes the approved Kijun, ASO, Aroon and live-risk inputs plus the fixed
  card mechanics. `Strategy_ConfigValid` at line 77 keeps the approved sweep
  ranges and rejects changes to fixed ATR, TP1, spread, loss-limit, risk-cap and
  slippage rules.
- The same source implements Kijun/ASO/Aroon/Damiani at lines 216-273, the UTC
  rollover/spread/realized-loss/one-position no-trade filters at line 276, and
  the exact shift-1 long/short entries with 1 ATR server stop at line 302.
- TP1 volume is preflighted for an exact broker-valid 50/50 split at line 134.
  Lines 167-213 reconstruct partial-close completion from position deal history,
  and management at line 370 performs TP1 once, then independently maintains the
  entry-plus/minus-one-pip runner stop. The transaction hook invalidates the
  reconstruction cache at line 593.
- The Kijun re-cross runner exit is at line 454. `OnInit` declares the D1
  execution contract at line 506 and wires the card's 2.5% daily / 5.0% total
  kill-switch limits at line 511. `OnTick` starts with the Q08 MAE hook at line
  543 and keeps management/exits ahead of entry-only news and no-trade filters.
- `framework/EAs/QM5_36002_nnfx-kijunsen-absolute-strength-damiani/SPEC.md:11`
  documents the exact strategy; TP1 restart and split semantics are explicit at
  line 41, all strategy inputs at line 51, symbols/timeframe/expected behaviour
  at lines 84/98/108, source lineage at line 121, and the stock V5 risk model at
  line 133.
- `framework/EAs/QM5_36002_nnfx-kijunsen-absolute-strength-damiani/docs/strategy_card.md:1`
  is a content-equivalent mirror of the approved card.
- `tools/strategy_farm/tests/test_qm5_36002_build.py:55-204` adds six regression
  tests for the card mirror, framework corset, execution contract, every card
  rule, exact/restart-safe TP1, input use, fixed-risk presets, registry formula,
  active-magic uniqueness and resolver coverage.

## Registry and setfile evidence

- `framework/registry/ea_id_registry.csv:4457` already held the single active
  `36002` slug row, so no duplicate was appended and that CSV did not need a
  content change.
- `framework/registry/magic_numbers.csv:17430-17433` contains slots 0-3 for
  EURUSD.DWX, GBPJPY.DWX, AUDCAD.DWX and NZDUSD.DWX with magics
  `360020000..360020003`, status `active`, and the required reservation label
  `Codex burn-window build`.
- `python framework/scripts/update_magic_resolver.py --keep-obsolete` returned:
  `[OK] ... 17994 rows kept, 0 dropped, sha=9A43798123A86ED2...`.
  The derived row count/hash are at
  `framework/include/QM/QM_MagicResolver.mqh:16-18`.
- Independent CSV verification returned
  `active_rows=16560`, `duplicate_active_magics=0`, and the four formula-correct
  target rows.
- `gen_setfile.ps1` was invoked separately and scoped with
  `-EaSlug QM5_36002_nnfx-kijunsen-absolute-strength-damiani -Symbol <symbol> -TF D1 -Env backtest`
  for all four symbols. Each invocation returned `status=ok`. The presets retain
  `RISK_FIXED=1000`, `RISK_PERCENT=0`, all strategy inputs, and no `.DWX` symbol
  leakage. Their hashes are:

  - AUDCAD: `08aad5266a9adfd5087bdb9f06b484a8feaaabab16941dcca38fe5ae0f296eb8`
  - EURUSD: `e199d51b0e34d8675818c7e79ad4f17147e3a661b53a10f4d386a4cef47f869d`
  - GBPJPY: `643bd7a4d3e494401335722b18b98804c58a01a16288b36f4cfb2a4e63c3ba8e`
  - NZDUSD: `2943d6625bd41529ddd4ab95bdb114b2132aa96494fc91575188357dd87627cb`

## Validation output

1. `python -m pytest tools/strategy_farm/tests/test_qm5_36002_build.py -q`

   Result: `6 passed in 0.81s`.

2. `python -m pytest tools/strategy_farm/tests/test_qm5_36002_build.py tools/strategy_farm/tests/test_build_gate_hardening.py -q`

   Result: `36 passed in 537.97s (0:08:57)`.

3. `python tools/strategy_farm/build_gate_hardening.py --repo-root . --ea-label QM5_36002_nnfx-kijunsen-absolute-strength-damiani`

   Result: exit 0, `failures=[]`, `warnings=[]`; four authorized symbols,
   D2 2.0/2.5/5.0 loss contract, D5 UTC conversion, D7 MAE, D10 buffer bounds,
   D17 universe and the remaining mechanized checks all PASS.

4. `python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_36002_nnfx-kijunsen-absolute-strength-damiani`

   Result: `verdict=PASS`, five files checked, zero findings, news stale ceiling
   336 hours.

5. `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_36002_nnfx-kijunsen-absolute-strength-damiani`

   Result: `1 PASS, 0 FAIL`.

6. `python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_36002_nnfx-kijunsen-absolute-strength-damiani --json --fail-on-leak`

   Result: `SINGLE_SYMBOL_OK`, zero violations.

7. Scoped authoritative check attempted exactly once:

   `powershell -NoProfile -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_36002_nnfx-kijunsen-absolute-strength-damiani -SkipCompile`

   Result: fail-closed before validation with
   `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because `terminal64` processes were
   alive. The prescribed alternative is the governed COMPILE_EA lane. Per this
   ticket, no compile work was enqueued and no terminal/factory process was
   altered. The generator therefore leaves `build_hash: pending`; the governed
   compile lane will seal it.

8. `git diff --check` returned no errors.

## Risks and open questions

- No `.ex5`, compile receipt, or smoke claim is produced; compilation belongs to
  the governed COMPILE_EA lane explicitly excluded by this ticket.
- Exact 50/50 TP1 intentionally rejects risk-sized volumes that the broker lot
  step cannot divide into two equal valid halves. This preserves card fidelity
  but can reduce entries at small risk sizes.
- The card names ASO and Damiani outputs but does not spell out their complete
  internal formulas. This build retains the existing deterministic definitions
  documented in SPEC: mean positive/negative close deltas for ASO and
  `ATR(13)/ATR(40) > 1.40 * StdDev(13)/StdDev(40)` for Damiani. Changing those
  definitions requires an amended approved card rather than an implementation
  tweak.

## Rollback

Use `git revert <this-commit-sha>`. This restores the prior EA, SPEC, presets,
magic-row provenance and generated resolver hash, and removes the mirrored card,
tests and this evidence note. No database, verdict, queue, router, factory,
terminal, backtest, or live rollback is required.
