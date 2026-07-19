# DXZ 12567 / XAUUSD.DWX D1 — repair and requalification packet

Date: 2026-07-16  
Scope: DarwinexZero MT5 Base research, literal `.DWX` history only  
Status: **RESEARCH_CANDIDATE — BLOCKED_PENDING_OWNER_AND_NEW_EVIDENCE**  
Deployment eligibility: **false**

## Outcome

EA 12567 on **XAUUSD.DWX D1** remains a useful research candidate, but it is not a qualified strategy, not DarwinIA-ready and not eligible for portfolio resizing or deployment.

The existing diagnostic report is economically interesting: 73 native round trips, native PF 1.5904 and conservative commission-adjusted PF 1.5743. Those figures are not carried forward as qualification proof. The prior run has unresolved lineage, Q08, cost, risk-contract and discontinuous-history defects. This packet converts those defects into a deterministic, fail-closed requalification protocol.

This packet is deliberately distinct from the **12567/XNGUSD.DWX** commodity variant. No XNG data, result, identity stream, symbol specification or cost evidence may satisfy an XAU gate.

## Hash-bound packet components

| Artifact | SHA-256 | Purpose |
|---|---|---|
| `dxz_12567_xauusd_d1_repair_spec_20260716.json` | `5ca71ddc7e2f1be89d4183f63d76ab4638564c3caea31eef3cfe9997b5aa025c` | Machine-readable repair and qualification contract |
| `dxz_12567_xau_repair_packet.py` | `3a9ac16667bd2e60dd1072e19542b365d23c6b2df8a70910008aec328deaae9a` | Read-only fail-closed validator |
| `test_dxz_12567_xau_repair_packet.py` | `d9d8e721c0776a80119f72e73f1e069f98e3feb07f98988b3e9c1e3ada5caf68` | Adversarial contract tests |
| Canonical cost-v3 `report.json` | `98ea8553f4fb6044d757e90c964c8b6fda4f8f40f653e75510833f8f49c694fd` | Commission-axis baseline only |

The cost-v3 canonical payload SHA-256 is `a3cd2748ddffd571152203bf6485eaeb8b1285614715929523e4e9ce2314fbb6`.

## What the current evidence actually establishes

The read-only baseline used the deployed binary and preset then found on T_Live. It did not alter T_Live and is not a qualification run.

| Diagnostic | Observed |
|---|---:|
| Window requested | 2018-03-01 through 2025-12-31 |
| Native round trips | 73 |
| Native net | EUR 3,623.51 |
| Native PF | 1.5903558907 |
| Native close-to-close DD | EUR 1,699.08 |
| Native history quality | 100% real ticks |
| Conservative commission-adjusted net | EUR 3,540.0576 |
| Conservative commission-adjusted PF | 1.5743318807 |
| Conservative commission-adjusted close-to-close DD | EUR 1,717.3249 |
| Commission ambiguity | 0 ambiguous / 0 unbounded trades |

The exact DarwinexZero commission unit contract used by schema v3 is:

`0.00005 decimal = 0.005 percent = 0.5 basis points round-trip`

The older “5 bp” label was a factor-ten terminology error. The numerical `0.00005` calculation was unchanged, but only schema v3 carries the correct unit declaration. The canonical v3 artifact certifies the commission calculation for this sleeve; by its own limitations it does **not** certify current spread parity, current swap-rate parity or slippage.

## Why the old result is not qualification evidence

1. The cited cumulative-RSI page defines daily RSI(2) accumulation and a two-day cumulative RSI(2) below 35 tested on SPY. It does not define the commodity/XAU port, SMA(200), RSI>65 exit, five-bar exit, ATR stop, Friday close, news handling or sizing. The current strategy is therefore a **QM interpretation**, not a verbatim source implementation.
2. The deployed EX5 differs from the repository EX5. Selecting whichever binary produced the better backtest would be outcome-conditioned lineage selection.
3. The deployed preset used `RISK_PERCENT=0.7938`, `RISK_FIXED=0`, `PORTFOLIO_WEIGHT=1`. The repository live preset used 0.7500. The historical source manifest used `RISK_PERCENT=0.793826` and `PORTFOLIO_WEIGHT=0.081418`, dimensionally applying sleeve weight twice. That rejected tuple targets only 1/12.2819 of the as-found continuous risk.
4. The old fixed-risk reference matches 73/73 entry timestamps, 73/73 exit timestamps and 73/73 gross outcome signs, but only 9/73 lots. It lacks full signal, side, price, stop, target, exit-reason and PnL identity and is inadmissible.
5. The legacy Q08 stream has 28 rows, lacks entry time on every row and provides zero valid full-identity rows.
6. The shared XAU/EUR conversion history contains dependency breaks. A pooled 73-trade result may not bridge those breaks.
7. The baseline certifies neither all five execution-cost axes nor current broker parity.
8. The current repository source evaluates `Strategy_NewsFilterHook` and `QM_NewsAllowsTrade2` and can return before `QM_FrameworkHandleFridayClose`. With the active PRE30/POST30 plus DXZ policy, a news blackout can therefore suppress the mandatory Friday-close path. This is **BLOCKING_REMEDIATION_REQUIRED**; the current source is not qualification-eligible.

## OWNER directive: no weekend holdings

The OWNER directive recorded on 2026-07-16 closes the substantive Friday choice:

- no weekend holdings;
- Friday close enabled, with broker/server hour 21 as the latest normal framework safety cutoff;
- earlier strategy/Card exits remain allowed;
- on a holiday or early-close week, the effective deadline is the earlier of Friday 21:00 and the last tradable broker-session close before the weekend;
- purpose: avoid weekend gaps and prepare the sleeve for prop-firm constraints.

The spec records this as `OWNER_DIRECTIVE_RECORDED_UNSEALED`. It is not yet cryptographic approval. Qualification requires a receipt whose decision is exactly `FRAMEWORK_OVERRIDE_FRIDAY_21_BROKER`, signed with Ed25519 under the public-key hash registered in the spec. The validator caller must additionally supply the same absolute key path and expected SHA-256 independently via `--owner-trust-anchor` and `--owner-trust-anchor-sha256`. A key self-pinned only by a modified spec or bundle cannot establish trust.

The runtime proof is not satisfied by preset text. A complete, hash-bound `DXZ_XAU_WEEKEND_FLAT_BROKER_CALENDAR` must cover every qualification week and bind a frozen DarwinexZero broker-session/literal-`.DWX` source export. For each week, the validator recomputes `min(Friday 21:00, last tradable close)` and rejects any round trip still open past that effective cutoff.

## History segmentation

Both **XAUUSD.DWX** and **EURUSD.DWX** are mandatory because XAU P/L is USD-denominated while the account is EUR. The EUR conversion dependency splits the evidence even where the host XAU series is continuous.

| Segment | Role | Warm-up / score rule | Intersection bars |
|---|---|---|---:|
| S0 | INFERENCE | 200 D1 bars; score from 2018-07-12 until gap B | 1,600 |
| S1 | INFERENCE | fresh 200-D1 warm-up; score from 2024-09-26 until gap C | 467 |
| S2 | CONTINUITY_ONLY | 33 bars, insufficient for SMA(200) | 33 |
| S3 | CONTINUITY_ONLY | 7 bars, insufficient for SMA(200) | 7 |

Known split points are B (144 hours after 2023-12-12), C (624-hour EURUSD dependency gap after 2025-10-08) and D (120 hours after 2025-12-17). Each segment needs a fresh process, indicator state, rolling state, positions and pending-order state. No trade, forced liquidation or economic score is allowed in S2/S3.

## Qualification protocol

The repair does not reuse the old report as a reference.

1. Baseline A and B run serially in `DISCOVERY_COMPLETE_UNREFERENCED` mode. They must use distinct, non-nested roots and globally unique case-folded IDs.
2. Before any run is admissible, the selected source/include closure must clean-compile and pass runtime ordering checks. A calendar-aware `QM_EnforceWeekendFlatDeadline` path and `QM_FrameworkHandleFridayClose` must precede every news/entry filter. A preceding `QM_KillSwitchCheck` guard is allowed only when its bound include proves trip-time flattening and a 60-broker-second halted retry sweep.
3. Each run executes S0–S3 serially from fresh literal-`.DWX` copies. Every segment binds actual HCC, TKC and segmentation CSV files for both required symbols plus semantic MT5 symbol-spec exports. HCC/TKC magic, kind and embedded symbol are revalidated, cross-symbol byte reuse is rejected, and every generated segment artifact must live inside its own output root.
4. Q08 and native-report identities are produced by distinct, hash-bound deterministic extractors. The validator reads the target Q08 events itself and independently parses the native MT5 HTML through `dxz_cost_evidence.extract_round_trips`; matching two fabricated normalized JSONL files is insufficient. Continuity reports are parsed too, so a declared zero cannot conceal native deals.
5. A post-consensus OWNER seal binds the byte hashes of baseline A/B receipts, every full identity axis, the complete weekend calendar and all sealed inputs. Its OWNER approval is Ed25519-signed against the independently supplied out-of-band pinned public key.
6. Qualification C and D start after the seal, select its exact case-normalized path and SHA-256, and reproduce every segment identity and data-manifest identity.
7. All four run roots, sixteen segment output roots, run/isolation/execution/sandbox IDs, receipts, reports, raw streams, normalized streams and extractor receipts are globally independent. Nested roots, cross-segment artifact placement and case-only aliases fail.
8. OWNER receipts, trust key, Card v2, source closure, EX5, preset, extractor sources, weekend calendar, cost artifacts, sealed input, spec, bundle and reference seal must be outside every run/output root; primary/external controls also fail inside MT5 trees.

The full round-trip identity covers signal time/value, side, entry time/price/reason, initial stop/target, exit time/price/reason, lot, gross P/L, swap, commission, net P/L and gross outcome sign.

## Execution-cost gate

A simple `{status: PASS}` artifact is inadmissible. Qualification requires the hardened `DXZ_EXECUTION_COST_EVIDENCE_MANIFEST` schema and all five XAU-specific axes:

- commission;
- historical tester spread;
- current DarwinexZero broker spread parity;
- current broker swap-rate parity, both long and short plus triple rollover;
- adverse slippage quantile plus gap stress.

The validator reuses `dxz_as_live_requal.load_execution_cost_evidence_manifest`, verifies manifest and axis sidecars, re-evaluates fixed sample/quantile/freshness thresholds, binds exact sleeve/window/source identity and checks the artifacts again after loading. The commission axis must additionally bind the canonical schema-v3 artifact above and state `0.005% = 0.5 bp` exactly.

## Remaining OWNER and build gates

| Gate | Current state | Required closure |
|---|---|---|
| Source semantics / Card v2 | PENDING | Approve the QM commodity interpretation, exit precedence, dependencies and falsification rules |
| Friday close | DIRECTIVE RECORDED, UNSEALED | Ed25519-sign no-weekend-holdings with Friday 21 as latest normal cutoff and the bound early-close fallback |
| News policy | PENDING | Approve `DXZ_PRE30_POST30` or explicitly disable it |
| Risk contract | PENDING | Select one `PORTFOLIO_WEIGHT=1` tuple; double scaling is prohibited |
| Source-of-record build | **BLOCKING_REMEDIATION_REQUIRED** | Move/provide the mandatory calendar-aware weekend and framework close paths before news/entry filters, retain bound kill-switch flatten/retry semantics, then select the closure and clean-compile it |
| New evidence | MISSING | Produce the broker-session calendar, A/B, seal, C/D and all structured five-axis cost artifacts |

Until all gates pass, the only valid status is **RESEARCH_CANDIDATE_NOT_QUALIFIED**.

## Verification performed

```text
python tools/strategy_farm/dxz_12567_xau_repair_packet.py \
  --spec docs/ops/evidence/dxz_12567_xauusd_d1_repair_spec_20260716.json

status: BLOCKED_OWNER_AND_NEW_EVIDENCE
errors: 0
verified static bindings: 22
execution_performed: false
```

```text
python -m pytest tools/strategy_farm/tests/test_dxz_12567_xau_repair_packet.py -q
30 passed
```

The complete `test_dxz*.py` family also passed: **219 passed** in the broad regression run.

The adversarial tests cover XAU/XNG scope separation, pending/self-pinned/incorrect/correct OWNER trust, fixed and early-close weekend deadlines, current-source news-order rejection, bound kill-switch flatten/retry semantics, dummy hashes, case-fold/nested paths, segment-output containment, arbitrary native HTML rejection, Q08 raw-event normalization, native HCC/TKC headers and cross-symbol byte reuse, semantic instrument exports, deterministic extractor receipts, an exact approved preset, recursive source closure, cost-source/window binding, canonical cost v3, sealed inputs and MT5-tree exclusion.

## Safety and mutation record

No Strategy Card, EA source, EX5, preset, registry, MT5 terminal or T_Live file was changed. No MT5 execution occurred. AutoTrading and deployment state were untouched. This work created only the repair spec, read-only validator, tests and this evidence note in the repository.
