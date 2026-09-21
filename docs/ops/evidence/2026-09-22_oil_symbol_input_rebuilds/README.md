# Oil symbol-input rebuilds: QM5_41488 and QM5_41489

Task: `273f2de8-8408-4a9a-9054-b55040576bec`  
Authority: `OWNER-DEC-FTMO-DUAL-TRACK-20260921`; identity procedure `OWNER-DEC-IDENTITY-EQUIVALENCE-20260913`  
Scope: new identities derived from QM5_12710 and QM5_20266; no parent edit, roster change, deployment, T_Live, FTMO-demo, or AutoTrading action.

## Verdict

Both new identities compile and pass a canonical governed Q02 canary on `XTIUSD.DWX`. The identity proof is `EQUIVALENT_EXACT` against a matching parent Q02 for each pair:

- QM5_12710 -> QM5_41488: 95/95 deal rows, zero field mismatches, exact volume and P&L.
- QM5_20266 -> QM5_41489: 491/491 deal rows, zero field mismatches, exact volume and P&L.

This proves the symbol-input change is non-economic on the governed 2018-07-02 through 2022-12-31 Q02 interval. It does **not** manufacture a Q-gate verdict and it is not the requested stronger 2017-01-01 through 2025-12-31 parent-Q08-window replay. The canonical Q02 append command and current proof tool bind Q02 work items; no governed custom-window Q02 append path was found. That gap remains explicit.

QM5_41489 is eligible for the ratified manifest-substitution / inherited book-evidence treatment because parent QM5_20266 has a qualified Q08 PASS and the exact proof below. QM5_41488 is not eligible for that treatment because parent QM5_12710's Q08 verdict is FAIL_SOFT. Neither rebuilt identity has its own completed Q03-Q10 chain or its own Q10 seal. Neither is independently deployable.

## Bound identities

| Rebuild | Parent | Slug | Magic | MQ5 SHA-256 | EX5 SHA-256 | backtest set SHA-256 |
|---|---:|---|---:|---|---|---|
| QM5_41488 | QM5_12710 | `commodity-tsmom-12m-atr-symbolinput` | 414880000 | `e8ff5415daf04c74c46421c50b177a43797dd68b2055cd7b4cfaf7d432b63e63` | `3c2cac2fe817fb60fbef394ba4b1ee46a39423c563c46797fd99262593b4eb08` | `9e8efb17798a3ea20f5e2255507abada381f04e4a73c67830c51928ebe5ca504` |
| QM5_41489 | QM5_20266 | `collins-66mom-symbolinput` | 414890000 | `25fd30a52a8f2a56a614b132616b6e20b46957db95e28ff46a1367cbe7f027fa` | `e582501f16fb9820bb4ec53ca18a880a0ee044b16f3ce3637fa8ee1c031da842` | `f709fc0f9773b389069ba5769cbb10a5757b0d6b51c8c111ca34d96279014341` |

Registry bindings:

- `framework/registry/ea_id_registry.csv:4971-4972` allocates IDs 41488 and 41489 and binds their parent lineage in the allocation reason.
- `framework/registry/magic_numbers.csv:18627-18628` allocates slot-0 `XTIUSD.DWX` magics 414880000 and 414890000.
- `framework/registry/ea_origin.v1.csv:4464-4465` preserves the parent origin programme and binds `lineage:QM5_12710` / `lineage:QM5_20266`.
- `framework/include/QM/QM_MagicResolver.mqh` was regenerated with both identity cases.

## Minimal source change

The parents were not modified. Each rebuilt source is a copy under a new identity with only identity-bearing values and the hard-coded host gate changed:

- QM5_41488 declares `strategy_host_symbol = "XTIUSD"` at line 45 and compares `QM_MagicSymbolCanonical(_Symbol)` with `QM_MagicSymbolCanonical(strategy_host_symbol)` at lines 57-60.
- QM5_41489 declares the same input at line 46 and performs the canonical comparison at lines 70-73.
- Neither rebuilt `.mq5` contains the literal `XTIUSD.DWX`.
- Functional setfile assignments match each parent after excluding `qm_ea_id` and the new transport-only `strategy_host_symbol` input. All generated test presets use `RISK_FIXED=1000` and `RISK_PERCENT=0`.

The Q02/backtest preset uses `strategy_host_symbol=XTIUSD`; the stress and Q10 presets use `XTIUSD.DWX`. Both values canonicalize to the same base.

## Governed compile

| Rebuild | compile work item | Result | Compiler | build_check | Evidence SHA-256 |
|---|---|---|---|---|---|
| QM5_41488 | `c9b81f7e-2723-4161-878a-8badaeded7fb` | PASS | 0 errors, 0 warnings | PASS; 0 failures, 3 card-undecidable advisory warnings | `a49056f3f0eabc35004f8f53b09d3a6f9dd1efc83b726e930f614757fdddc5fc` |
| QM5_41489 | `3056a976-b5ec-43da-b5be-b73bbe750402` | PASS | 0 errors, 0 warnings | PASS; 0 failures, 3 card-undecidable advisory warnings | `1e942ad19cd648d338a1ca41e80c917e6b121ccaef5cc75a834ade8ed9b0984a` |

Evidence paths:

- `D:/QM/reports/work_items/c9b81f7e-2723-4161-878a-8badaeded7fb/QM5_41488/COMPILE_EA/compile_evidence.json`
- `D:/QM/reports/work_items/3056a976-b5ec-43da-b5be-b73bbe750402/QM5_41489/COMPILE_EA/compile_evidence.json`

The compiler produced nine governed presets for each identity. The binary and compile-bound presets were committed only after the governed compile/janitor receipts passed.

## Q02 canaries and exact identity proof

Both rebuild canaries ran Model 4, D1, `XTIUSD.DWX`, 2018-07-02 through 2022-12-31 and returned Q02 PASS.

| Pair | Parent Q02 work item | Rebuild Q02 work item | Rebuild report SHA-256 | Proof SHA-256 | Result |
|---|---|---|---|---|---|
| 12710 -> 41488 | `f1378383-4b37-4329-a249-94118e353161` | `8cd9efe7-3faa-4727-8638-4af0b4ee2923` | `595a7b2c01c51ec30a11da3a996b16f3ec4616afb19e0ce9438754636a4ddabd` | `7b02fbf1aa903fc3084f42f67ff6c8201c602636d93915bb9030f77c8eaf8f37` | `EQUIVALENT_EXACT` |
| 20266 -> 41489 | `8927c178-1c81-46bd-84fd-33f3d6c77132` | `c9f367a9-8f0e-453d-bd11-261a4b1c3ad3` | `5857bc95449386bb6b2f9d7b491e06948b7481129787187a1a613b5d1be964c6` | `5e9f96e9f42378b745ffdd9fdd2ace0bb459c9be8b6ae9908341c8c8e5d1378c` | `EQUIVALENT_EXACT` |

Proof paths:

- `D:/QM/reports/identity_equivalence/QM5_12710__QM5_41488/XTIUSD.DWX/proof.json`
- `D:/QM/reports/identity_equivalence/QM5_20266__QM5_41489/XTIUSD.DWX/proof.json`

The proof-tool SHA-256 recorded in both proofs is `ba8a3a8888cebfffd72fab012963625930224948c3075fec33365de3965dd288`. The verifier reports `ok=true`, no failures, and no warnings for both artifacts.

The proof comparator now admits one narrow transport exception: a new `strategy_host_symbol` key may be ignored only when the parent lacks it and its canonical base exactly matches the tester symbol. Any other setfile difference or a mismatched host symbol remains disqualifying. Regression tests cover both accepted and rejected cases; commit `65f909eeb0` contains the change.

## Parent Q08 evidence and window limitation

The sealed parent Q08 context was inspected but not altered:

- QM5_12710 latest Q08 work item `bfda1943-a80e-42de-a872-d26029e3e428`: FAIL_SOFT; baseline report SHA-256 `b8303e639121e2262a525393cac1e65ee0d3fdc22ee73bd5c9f63953a3f423f4`; 82 trades; stream `D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/12710_XTIUSD_DWX.jsonl`, stream SHA-256 `c09e9ea0bdeb4d888300bf4fe5afa6d84dd097aba864472415facc643d7e8dcd`, identity SHA-256 `3a703798372b90d36f5ce064ad138786ecd9ffdc27f10a5738321475018f71f0`.
- QM5_20266 qualified Q08 work item `87731bac-29cc-4846-ac26-b348b13af59b`: PASS; baseline report SHA-256 `3f61e51666cb1eac48f6b1b07dfee149d59580bbc43ccfbddd354f0a1cee9202`; 432 trades; stream `D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/20266_XTIUSD_DWX.jsonl`, stream SHA-256 `c70651f78c4a5cd9aec42dda4207e14d206575134ccebb058b2e3e1e42f180d3`, identity SHA-256 `e0bd2449c46427631a10e65cc0e138e5f2112f2cd4411cba8ede44cfc42f5106`.

Those Q08 baselines span 2017-01-01 through 2025-12-31. The governed canary tooling instead selected the matching Q02 interval shown above. Therefore this artifact does not claim trade-by-trade equality against either Q08 stream. A governed full-window replay/proof facility is required to satisfy that stronger task wording.

## Static FTMO alias proof

`framework/include/QM/QM_MagicResolver.mqh` documents `USOIL.cash -> XTIUSD` at line 134 and maps base `USOIL` to `XTIUSD` at lines 143-144. Therefore:

`QM_MagicSymbolCanonical("USOIL.cash") == QM_MagicSymbolCanonical("XTIUSD.DWX") == "XTIUSD"`.

Static resolver/alias tests and the input-pin audit passed. No FTMO venue smoke was performed and no demo terminal state was changed.

## Q10 seal disposition

The identity proof does not grant a Q10 verdict. These are new EX5 identities, so the D2f stale-seal mechanics require append-only progression through the rebuilt identity's own eligible predecessor phases before Q09/Q10 can be enqueued and a Q10 seal can be created. At closeout only COMPILE_EA and Q02 exist for QM5_41488/41489; a direct Q09/Q10 append would violate predecessor eligibility and was not attempted.

For QM5_41489, any interim manifest substitution must cite this exact proof plus the qualified parent Q08 evidence and remains a separate reviewed deployment decision. QM5_41488 cannot inherit from its FAIL_SOFT parent. No deployment is authorized by this artifact.

## Focused verification

- `identity_equivalence_proof.py verify` on both proofs: `ok=true`, no failures/warnings.
- Identity proof tests: 9 passed.
- Resolver/alias focused tests: 2 passed (11 passed in the combined targeted selection).
- `audit_framework_input_pins`: `ok=true`, zero hits.
- Literal scan of both rebuilt `.mq5` files: zero `XTIUSD.DWX` occurrences.
- New registry rows: zero validation issues (the repository-wide validator still reports unrelated legacy issues).

## Commits

- `7a25daf47f` — new identities, presets, registry/origin bindings, generated magic resolver.
- `c3c17ed861` — compile binding set to pending before governed compile.
- `72568a0de3` — governed EX5 files and compile-bound presets.
- `65f909eeb0` — fail-closed identity-proof handling for the exact host-symbol transport input.
