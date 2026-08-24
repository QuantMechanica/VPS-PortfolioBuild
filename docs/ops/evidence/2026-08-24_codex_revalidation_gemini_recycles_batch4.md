# Codex revalidation — recycled Gemini EA cohort (batch 4)

Date: 2026-08-24  
Branch: `agents/board-advisor`  
Scope: independent review against current canonical bytes after the 2026-08-24 rework merges. No queue, registry, terminal, backtest, or live-trading mutation was performed.

## Decisions

| Router task | EA | Verdict | Current blocker |
|---|---|---|---|
| `1db5da1a-e87a-486f-a6f6-2224724a09fe` | `QM5_9932` | **FAIL / REVIEW** | The universe repair is present, but current source bytes do not match the isolated-compile/build identity and `build_check_passed` remains false. |
| `9cb9c40c-317e-4a6b-be47-513aa088ecee` | `QM5_9922` | **FAIL / RECYCLE** | D1 initialization is still undeclared; set provenance and approved-universe defects remain unrepaired. |
| `bcfe1a9b-ca66-4c45-bd5b-868b0167acb9` | `QM5_9923` | **FAIL / RECYCLE** | The shared `QM_HMA` primitive still omits the defining outer WMA pass, so entries and exits use the wrong series. |
| `d6ea3abe-d44b-4861-b466-475a28899eaa` | `QM5_9909` | **FAIL / REVIEW** | Source/card repairs pass focused tests, but the governed compile is pending and the current EX5 is explicitly stale/unbound. |
| `9bd88385-fdac-4b6d-9437-0cdc14fb3f25` | `QM5_9908` | **FAIL / REVIEW** | Source/card repairs are present, but current source bytes and set headers do not match the isolated-compile identity; strict build and smoke evidence are absent. |
| `a6de7c37-1c79-4bbe-b97a-7ab0acba91b4` | `QM5_9730` | **FAIL / RECYCLE** | The unapproved spread filter can still suppress mandatory exits, the package exceeds the index card, and valid RSI=0 is rejected. |

All six Gemini-origin tasks remain in `REVIEW`; none is authorized for pipeline promotion.

## Hash-bound review

### QM5_9932 — ROC z-score normalized index MR

- Current MQ5 SHA-256: `754854d50d5875ceed0e0435cb651daaaa524a0f482168fd923ffda44fc1fee7`.
- Current EX5 SHA-256: `feea799e3e46a96c0f6094e76d6d4dfc1f4069c6c800195430be00b99f2d83dc`.
- The rework correctly trims the runnable package to the card's NDX/SP500/WS30 universe (three sets) without rewriting pre-existing magic allocations.
- `build_result.json` and `build_identity.json` bind MQ5 hash `20553e4da0339eb9a8d5a949a230b67c5980cd7957bcdf607f6700613e970a34`, not the current canonical bytes. They truthfully retain `build_check_passed=false`.
- Fresh focused test result: `test_qm5_9932_review_rework.py` = **1 failed, 4 passed**. The failure is the exact source-hash assertion (`754854...` actual versus `20553e...` bound). Existing governed compile rows are failed and predate the repaired source.
- Disposition: semantic repair accepted for review purposes, build identity rejected until a governed strict compile binds the current bytes.

### QM5_9922 — Vortex crossover trend

- MQ5 SHA-256 `77d234edd9c1234d169972858ba489a5453ddecfecf47762e91aaade5c132ced`; EX5 SHA-256 `7509b7bb413c9cf367e404886788533d4ff866044d70dbde53a126ffa7677ea7`.
- Source remains at commit `be380b9b49342d7a37936608f26ff34e22b4e211` (2026-08-23); no repair followed the recycle.
- All signals read D1, but `OnInit` has no D1 contract and entry uses bare chart-period `QM_IsNewBar()` (`mq5:348`).
- The 13 set files still predate the delivered source and carry nonmatching per-file build hashes.
- The package still omits card-authorized oil and adds GDAXI/UK100 beyond the approved card scope.

### QM5_9923 — HMA crossover trend

- MQ5 SHA-256 `457d114229c77f1c68bda4f9a65ed7b1a604fe0bfc68934a646d7dba2387ce0f`; EX5 SHA-256 `20443824c83d4ef5ae9a0f254fa9b5d7404638e0eee493ae4efac6c8f1437c8f`.
- Source remains at commit `367ac9f0fd0fcad80a4c541762862d6ea785a473` (2026-08-23).
- The card defines `HMA(n) = WMA(2*WMA(close,n/2)-WMA(close,n),sqrt(n))`. Current `QM_HMA` in `QM_Indicators.mqh:586-604` computes the inner difference and returns it directly at line 603. `sqr` is still dead and the outer WMA is absent.
- `QM5_9923` calls that primitive for every fast/slow entry and exit value (`mq5:125-128,182-185`), so the tested mechanism is not the approved HMA crossover.

### QM5_9909 — linear-regression channel breakout

- Current MQ5 SHA-256 `20a4b055cf6e046c0ab041e3c2bf911d74977765afe7192c89c902a827b547c5`; current EX5 SHA-256 `e83cdf3119b6e008198cb326edab358740c51220b1050ea4dab2c736952531ee`.
- Rework commit `ca9e74d4a431db37481f954c68b6f42144eec71e` repairs the D1 cadence, management reachability, two-layer stop lifecycle, dead input, bounded reads, documentation, and runnable 12-symbol card universe.
- Fresh `test_qm5_9909_rework_static.py` result: **6 passed**.
- `build_identity.json` truthfully records `compile_succeeded=false`, `build_check_passed=false`, no EX5 hash, and deferred smoke. Governed compile work item `5f4c9079-449c-4230-b9db-3cde2c7ce6a5` remains pending; the on-disk EX5 is the prior binary and is not evidence for the repaired source.
- Disposition: semantic source repair passes; acceptance remains blocked solely on governed current-source compile/strict identity evidence.

### QM5_9908 — PSAR flip trend

- Current MQ5 SHA-256 `55593f9475a8d73cf0e863c4f5f10a38ec51151db533bc0acf739041aae0cddb`; current EX5 SHA-256 `fdb24a8f857df584e007f6bed94b775656930fd33cff179306e1a3c120a3abba`.
- Rework commit `d1f05b3d07424387dd87017415e45e0c487006a5` materially repairs D1 cadence, PSAR-distance risk sizing, catastrophe persistence, PSAR trailing, management reachability, and the 12-symbol card universe.
- `build_identity.json` binds source hash `587525bbf2413cde5bbdb44fbdefc86f95fe6710c964b1268254d3c3092c121f`, not the current canonical source hash. It truthfully records `build_check_passed=false`; smoke is `framework_error`.
- Fresh `test_qm5_9908_review_rework_static.py` result: **2 failed, 4 passed**. Both failures are provenance failures: the current MQ5 hash does not equal the identity or set-file build hashes.
- Disposition: semantic repair accepted for review purposes; build identity rejected pending exact-current-source governed verification.

### QM5_9730 — weekly RSI extreme / D1 trigger MR

- MQ5 SHA-256 `406a8740c2469fac9e6fd384fee1380532f13a65bb15b65350f11ecd30bdde92`; EX5 SHA-256 `ceef802588a001e12961a1a6f20e2a76755cd676cf72841da9076b8f136cd92f`.
- Source remains at commit `028750a9ebc5d1617e5f4c6897cb4fb7ab53e1bb` (2026-08-23).
- `strategy_spread_max_atr` is not authorized by the card and its no-trade return (`mq5:56-68,198`) precedes the time/RSI exits (`mq5:201-203`).
- Entry rejects `rsi3_w1 <= 0.0 || rsi2_d1 <= 0.0`, discarding valid RSI zero values that most strongly satisfy the card's entry threshold.
- The delivered 13-symbol set/magic package still exceeds the approved SP500/NDX/WS30 index scope.

## Focused verification and guardrails

- Current source hashes, EX5 hashes, source histories, card contracts, set counts, build identities, and control-flow/indicator primitives were read from the canonical checkout after the rework merges.
- Fresh task-specific tests: QM5_9932 `1 failed, 4 passed`; QM5_9909 `6 passed`; QM5_9908 `2 failed, 4 passed`. The failures are exact, reproducible build-provenance mismatches, not strategy-test threshold changes.
- Every reviewed source retains `qm_news_stale_max_hours=336`, `RISK_FIXED=1000`, and `RISK_PERCENT=0`. Rework/package tests confirm fixed-risk sets for the changed cohorts.
- A fresh multi-EA guardrail scan was started but became I/O-stalled and was terminated without a verdict; no PASS is claimed from that attempt. Existing task-specific rework evidence records scoped guardrail PASS, while the current hash/provenance failures above independently prevent acceptance.
- No compiler, smoke, backtest, queue, registry, terminal, factory, or live-trading action was taken while producing this review.

## Required next action

- QM5_9932 and QM5_9908: normalize and re-seal the canonical source/set/build identity, then obtain governed strict evidence for those exact bytes.
- QM5_9909: allow its already-pending governed compile to produce a current EX5 and strict identity.
- QM5_9922, QM5_9923, and QM5_9730: repair the named semantic/card-contract defects, rebuild, and resubmit for independent Codex review.
