# DXZ 10706 / GBPUSD.DWX H1 repair and requalification packet

Date: 2026-07-16  
Scope: `10706:GBPUSD.DWX:H1`, DarwinexZero only  
State: **BLOCKED_OWNER_TRUST_EARLY_CLOSE_AND_NEWS_ORDERING_RUNTIME_REMEDIATION; no qualifying run has been executed**

This packet turns the 10706 finding into an executable, fail-closed evidence
contract. It does not edit the APPROVED Card, EA, EX5, preset or registry; it
does not run MT5; and it grants no deployment authority. T_Live was used only
as a read-only artifact source. T_Live and T1-T10 are forbidden execution
roots.

Bound artifacts introduced by this packet:

| Artifact | SHA-256 |
|---|---|
| `docs/ops/evidence/dxz_10706_gbpusd_requalification_spec_20260716.json` | `45abd4a82e8b30314b09fffcb779cc7a62913f5e9ed4b37ea211651cd1986060` |
| `tools/strategy_farm/dxz_10706_requal_packet_validate.py` | `30cae9f18eae4115ae4b45586a2246c5852f465efa74da6b676d03bd5569e3bd` |
| `tools/strategy_farm/tests/test_dxz_10706_requal_packet_validate.py` | `dd3344bcd987b0b48553310f5ccbb4ede443b968cc3bc5d74f58148a2061e731` |

The specification deliberately contains neither its own path nor its own
hash. The evidence bundle, not the specification, must bind the external spec
path and hash. This removes a self-hash cycle and is enforced by the validator.

## Decision in one page

The current E3 result is useful but not a valid qualification reference:

| Reproduction dimension | Result |
|---|---:|
| Entry timestamps | 367 / 367 exact |
| Gross outcome signs | 367 / 367 exact |
| Close timestamps | 364 / 367 exact |
| Lots | 0 / 367 exact |
| Old fixed-risk lot sum | 1,616.54 |
| E3 as-live lot sum | 102.95 |

Therefore the defensible conclusion is **signal/entry and outcome direction
reproduced; execution, size and P&L not reproduced**. The 367 count and the
273/85/7/2 segment attribution are diagnostic oracles, not hard acceptance
targets for the new segmented protocol. New acceptance is consensus between
fresh repeats under one sealed contract, not forced agreement with the invalid
fixed-risk reference.

The repair has five independent gates:

1. OWNER selects the canonical `PORTFOLIO_WEIGHT=1` risk tuple.
2. Three structured OWNER receipts are pinned by expected SHA-256 supplied
   out of band; hashes declared by the evidence bundle itself are never trust.
3. Card/source/binary remediation implements session-aware early close and
   Friday/weekend risk handling before optional news returns.
4. Two unreferenced baseline repeats create a deterministic, owner-sealed
   post-consensus reference; two later qualification repeats compare against
   that external seal.
5. A structured five-axis execution-cost manifest passes semantic validation.

Technical identity and costs may pass while the runtime gate remains open.
Neither state changes the registry automatically.

## Risk-contract OWNER gate

The current framework formula in `QM_RiskSizer.mqh` is:

```text
continuous target risk = equity * (RISK_PERCENT / 100) * PORTFOLIO_WEIGHT
```

At EUR 100,000 initial equity:

| Contract | Effective risk | Continuous target |
|---|---:|---:|
| Current live preset: `0.0564`, `0`, `1` | 0.0564% | EUR 56.40 |
| Source-precision proposal: `0.056389`, `0`, `1` | 0.056389% | EUR 56.389 |
| Rejected double scaling: `0.056389`, `0`, `0.005783` | 0.000326097587% | EUR 0.326097587 |

Holding every other input constant, `PORTFOLIO_WEIGHT=1` targets exactly
**172.9206294310911291717101850x** the continuous risk and continuous lot size
of `PORTFOLIO_WEIGHT=0.005783`. Applying `0.005783` to the observed E3 range
of 0.06-1.20 lots gives only 0.00034698-0.00693960 lots before volume-step
flooring. That range is an inference, not an executable-lot conclusion: the
future instrument snapshot must bind volume minimum/maximum/step, contract
size, tick size/value and the EUR conversion path.

The `0.005783` tuple is **not OWNER-selectable** in this packet. It is classified
`REJECTED_DIMENSIONAL_DOUBLE_SCALING`. The only contract compatible with the
currently hash-bound live preset is `LIVE_AS_FOUND_RP0_0564_PW1`. Selecting the
source-precision `0.056389/PW1` tuple requires separately authorized preset
mutation, a new preset hash and a new immutable specification; it cannot be
called current as-live under this packet.

This is an exact OWNER gate. No agent may resolve it by silently editing a
preset or APPROVED Card.

## OWNER weekend directive

The 2026-07-16 OWNER directive is semantically decided and is no longer an
open policy question: **no weekend holdings** for weekend-gap avoidance and
prop-firm preparation. For 10706, the Card/strategy close at broker time 18:30
remains primary; framework hour 21 is only the latest normal safety fallback,
not a prohibition on earlier exits. The hard flat deadline is the earliest of
Card 18:30, framework Friday 21 and the last tradable session/tick before the
weekend. The spec records this as `OWNER_DIRECTIVE_RECORDED_UNSEALED`. This
packet did not alter the Card, source, preset, EX5 or any MT5 runtime.

Recorded semantics are not a cryptographic approval. Qualification still
requires the out-of-band pinned `RISK_CONTRACT`, `SEALED_INPUT` and
`REFERENCE_SEAL` OWNER receipt hashes. An inline `approved_by` string or a
self-computed approval hash is rejected.

The validator also proves this policy from the parsed native round trips and a
hash-bound DarwinexZero broker-time session calendar. It rejects entries or
positions beyond the effective per-week deadline and every Saturday/Sunday
interval. The calendar must cover every Friday in the effective window and
bind the server-derived last tradable time, including holiday/early-close
weeks. A preset field or a self-declared calendar hash alone is not evidence.

## Blocking runtime remediation

The bound 10706 source is not capable of guaranteeing the clarified directive:

- it implements fixed strategy 18:30 and framework 21:00 Friday times, but no
  bound last-tradable-session/holiday-early-close fallback;
- `OnTick` runs `Strategy_NewsFilterHook` and the active two-axis news check
  before `QM_FrameworkHandleFridayClose`;
- source defaults are `PRE30_POST30` / `DXZ`; the live preset has only legacy
  unread `qm_filter_news_*` keys, so a blocking or stale/missing-news return can
  prevent the Friday close path for this exact source/preset contract.

The required order is kill switch first, effective Friday/weekend risk closure
second, and optional news/entry filters third. Kill switch may remain first
because its bound closure owns flatten/retry behavior while halted. The same
ordering is a farmwide portability rule even for EAs whose current news axes
are `NONE`.

Therefore a complete technical reproduction and certified cost evidence now
ends as `TECHNICAL_PASS_RUNTIME_POLICY_BLOCKED`, never `PASS`. Development
requires a separately authorized Card/source/binary remediation and fresh
requalification. No EA or preset was changed by this packet.

## Card / source / binary / preset lineage

| Artifact | SHA-256 |
|---|---|
| APPROVED Card | `54b67c13235f6be8e47a1054a31b4e4391423f2fb870d71a327f001d17a3d366` |
| EA `SPEC.md` | `e0bb872fdfaa1cff415127d826872bb6c13529661fe18932fd9ffa67e440c647` |
| EA source | `fbb632c78461abc858218207768a53b50fa56a4cb63d1fa237d60de99318c5f6` |
| Source dependency closure | `421e42c77d391a4ef8ee8fe30ab638569f9023e23d6b62a4b2c8bcad6f378085` |
| Repo EX5 | `01e34b2059de6ed505d445ce9fcbac7da0eb10d51e5cbcbbd18d38a968916078` |
| T_Live EX5, read-only | `01e34b2059de6ed505d445ce9fcbac7da0eb10d51e5cbcbbd18d38a968916078` |
| T_Live preset, read-only | `b96504629a0af66c7d7dab21a08c64dbe8376ee422a925e18098c16804422a17` |
| Risk sizer include | `e75d7aaa48f3eae0d298ac67ba0db4404089f9b1abc7ea361fee7662c342fbed` |

The Card, source defaults, live preset and native E3 report agree on the core
strategy parameters, including the shifted Monday box, liquidity/wick/SL
percentages, 3.5R target, break-even logic, entry mode, spread/ATR guard and
Friday 18:30 strategy exit. Framework Friday force-close remains enabled.

The live preset contains eleven legacy `qm_filter_*` keys not read by the
current source. They do not explain the E3 mismatch and were not edited.

The earlier naked closure digest was replaced by a fail-closed structured
closure contract. On every validation, the tool recursively resolves the 26
MQL5 include members, hashes their repo-relative canonical list, and separately
checks the EA, `QM_Exit`, both kill-switch members and `QM_NewsFilter`. This
binds the exact source ordering on which the runtime blockers above rely.

A fidelity compile from the same source produced EX5
`88de34539ff41067ee839d6009cca456396771d45abc28a5409bb59f8715382e`,
while the compile log passed with zero errors/warnings. Because compiled bytes
differ despite the same source, this packet does not infer deterministic
source-to-binary provenance. The exact live EX5 byte hash is independently
bound as the executable identity.

## Why the old reference is disqualified

The current diagnostic E3 evidence is bound as follows:

| Artifact | SHA-256 |
|---|---|
| E3 receipt | `37a128c7efd9503737ac175f76d75165696c005b534366387f4ac77856150097` |
| E3 native report | `aab1bbad092dae3b499ee32c86de9b7196e9525b461b2b13df35483ec48a27ed` |
| Old reference stream | `3649e35f89030017e5e5fc07517bed476244dd22ca2534766cb8e8c25364d9a7` |
| Old fixed-risk Q08 report | `81328bdb4b412821c9c84504868cf0ad6c3ed11e8c31df6f65473b4dff689413` |

E3 used EUR 100,000, leverage 1:100, real-tick model, 100% history quality and
the exact live risk tuple. It produced 367 trades, EUR 4,497.68 report net,
PF 1.39 and EUR 936.25 equity drawdown. The conservative commission replay
reported PF 1.329 and EUR 3,899.95 net, but current spread parity, swap parity
and slippage remain open.

The old Q08 run used USD 100,000, fixed risk 1,000, only 91% real-tick history
quality and much larger lots. Its P&L is dimensionally incomparable. It also
crossed exceptional data gaps. It may diagnose signal stability, but it may
not be selected or relabelled as a new qualification reference.

The three close-time mismatches are explicitly bound in the JSON spec. No
claim of 367/367 full execution identity is permitted.

## B / C / D discontinuity repair

The segmentation oracle is the literal `.DWX` export
`GBPUSD.DWX_H1.csv`, SHA-256
`21f323f4e4a93fea4ce7f107095a62fded25fd38cc644ec9fbc88d0ec5d46924`.
It is a segmentation input, not independent market evidence.

| Gap | Last H1 open UTC | Next H1 open UTC | Delta |
|---|---|---|---:|
| B | 2023-12-12 01:00 | 2023-12-18 00:00 | 143h |
| C | 2025-10-09 02:00 | 2025-11-03 00:00 | 598h |
| D | 2025-12-17 18:00 | 2025-12-22 00:00 | 102h |

The required clean segments are:

| Segment | Tester dates | Scored UTC interval | Diagnostic E3 trades |
|---|---|---|---:|
| S0 | 2017-10-09 .. 2023-12-12 | 2017-10-10 07:00 .. 2023-12-12 02:00 exclusive | 273 |
| S1 | 2023-12-18 .. 2025-10-09 | 2023-12-19 07:00 .. 2025-10-09 03:00 exclusive | 85 |
| S2 | 2025-11-03 .. 2025-12-17 | 2025-11-04 07:00 .. 2025-12-17 19:00 exclusive | 7 |
| S3 | 2025-12-22 .. 2025-12-31 | 2025-12-23 07:00 .. 2026-01-01 00:00 exclusive | 2 |

Every segment starts with EUR 100,000, a fresh EA instance, no open position or
pending order and no carried indicator state. It warms through ATR(14,H1) and
one complete shifted logical-Monday box; scoring begins Tuesday 07:00 UTC. It
must end flat without tester-forced liquidation. Currency P&L from independently
reset segments must not be naively summed.

## Frozen input contract

Qualification must freeze literal `GBPUSD.DWX` and `EURUSD.DWX` inputs for
2017-2025. `EURUSD.DWX` is required because GBPUSD P&L is quoted in USD while
the account is EUR and the risk sizer may use inverse EURUSD conversion.

The sealed-input manifest must be created outside every run root after the
OWNER risk decision and before baseline A. It binds:

- a structured data manifest with exact `EURUSD.DWX`/`GBPUSD.DWX`, 2017-2025,
  HCC/TKC coverage; the validator re-reads every file, checks size and SHA-256,
  and independently recomputes the canonical aggregate snapshot hash;
- a structured instrument manifest plus its raw DarwinexZero terminal export;
  the validator checks exact account, leverage, symbol and required-property
  coverage and recomputes the instrument snapshot hash;
- a structured DarwinexZero session-calendar manifest plus raw server-session
  export, with every Friday in 2017-2025 covered and each last-tradable broker
  timestamp capped by framework Friday 21 before the Card 18:30 minimum is
  applied;
- Card, source, dependency closure, EX5, preset and risk-sizer hashes;
- exact risk tuple, including `PORTFOLIO_WEIGHT=1` and effective-risk math;
- segment-contract hash;
- account/instrument properties including currencies, leverage, contract size,
  tick size/value and volume min/max/step;
- externally trust-anchored OWNER risk and sealed-input receipts.

Every receipt binds the sealed-input file hash in its canonical contract and
records identical start/end hash maps. Broker/live-derived history may be
called frozen execution input only. It is not an independent reference.

## Anti-self-reference qualification protocol

1. Run baseline A and B in two distinct isolated roots. Run-level artifacts
   must live directly under their own run root; each repeat contains four
   exact `segments/S0`-`segments/S3` roots whose artifacts live directly under
   the corresponding segment root. Each baseline is explicitly
   `DISCOVERY_COMPLETE_UNREFERENCED`, non-qualifying and reference-free.
2. Require A/B to have identical non-empty contract, signal, entry, close,
   outcome-sign, lot, P&L and full-stream hashes. Receipt byte hashes must be
   different.
3. OWNER copies/seals the consensus stream outside all run roots as
   `OWNER_SEALED_POST_CONSENSUS_BASELINE`. The seal explicitly says
   `independent_reference=false` and structurally binds both baseline receipt
   hashes, both run-identity hashes, contract hash, identity-axis hashes,
   Execution IDs, Sandbox IDs and output roots.
4. Only after the seal timestamp, run qualification C and D in two more
   distinct isolated roots. Both select the exact same external reference path,
   reference hash, seal hash and sealed-input hash.
5. Require all four output roots to be pairwise non-overlapping/non-nested,
   Execution IDs and Sandbox IDs to be globally case-insensitively distinct,
   and receipt hashes to be distinct, while contract and stream identity
   hashes remain identical.

The validator rejects a reference, seal, OWNER receipt, sealed input, data,
instrument or session-calendar manifest, or execution-cost artifact located inside/containing any
run root or under a `T1`-`T10`/`T_Live` path. It also rejects a reference equal
to any generated receipt/report/stream, a baseline containing
a reference, a qualification started before the seal, or a seal whose
provenance includes a qualification receipt. A post-consensus reference proves
repeatability against an externally frozen baseline; it is not independent
vendor evidence and is not qualification by itself.

## Separate identity dimensions

The acceptance contract never collapses reproduction into trade count or net
P&L. For every segment and aggregate, the validator parses the native MT5 HTML
with `dxz_as_live_requal._parse_native_report`, independently checks its real-
tick header with `parse_native_report_execution_evidence`, extracts structured
round trips, regenerates canonical JSONL bytes, and then derives seven
dimensions:

- signal identity;
- entry identity;
- close identity;
- outcome-sign identity;
- lot identity;
- P&L identity;
- complete canonical stream identity.

Receipt-declared report metrics, stream bytes and identity hashes are compared
to those independently derived values. A plain-text report, arbitrary JSONL,
or self-declared metric/hash set therefore cannot qualify. This directly
prevents the current 367/367 signal/outcome result from being misreported as
lot/P&L reproduction.

## Execution-cost gate

The five mandatory axes are commission, historical tester spread, current
broker spread parity, current broker swap-rate parity and adverse slippage
stress. `PASS` plus an arbitrary hash-bound file is insufficient. The packet
re-runs the semantic loader used by `dxz_as_live_requal` twice and binds the
manifest SHA, embedded payload SHA/sidecar, sleeve/window coverage, validity,
per-axis artifact type, structured scenarios/results, semantic-contract hash
and start/end axis snapshot hashes.

Commission terminology for future evidence is fixed: the official **0.005%
round trip equals 0.5 basis points**, i.e. decimal 0.00005. Legacy Cost-v2
field names that contain `5bp` must not be interpreted as five basis points;
future qualification must use the structured five-axis manifest with explicit
units and economics.

Without a semantically valid manifest, a clean technical result is reported as
`TECHNICAL_PASS_COST_AND_RUNTIME_POLICY_BLOCKED`. With all cost axes certified,
it remains `TECHNICAL_PASS_RUNTIME_POLICY_BLOCKED` until the two source/runtime
defects are remediated and the new binary is requalified.

## Validator and tests

Spec-only verification:

```powershell
python tools/strategy_farm/dxz_10706_requal_packet_validate.py `
  --spec docs/ops/evidence/dxz_10706_gbpusd_requalification_spec_20260716.json `
  --verify-anchors
```

The expected current status is `BLOCKED_OWNER_TRUST_AND_RUNTIME_REMEDIATION`
with no structural issues. Evidence
verification additionally supplies `--evidence-bundle` and
all three out-of-band receipt trust anchors:

```powershell
--expected-owner-receipt RISK_CONTRACT=<sha256> `
--expected-owner-receipt SEALED_INPUT=<sha256> `
--expected-owner-receipt REFERENCE_SEAL=<sha256>
```

Focused suite:

```text
python -m pytest -q tools/strategy_farm/tests/test_dxz_10706_requal_packet_validate.py
53 passed
```

Negative coverage includes spec self-reference, double scaling, preset-rebase
selection, nested/case-fold-colliding roots/IDs, generated-path collisions,
run/segment artifacts placed under the wrong nested output root, missing or
self-declared session calendars, holiday early-close advancement, parsed
trades beyond Card 18:30/framework 21/last-tradable cutoff or over a weekend,
plain-text/native-report forgery, self-declared metrics, arbitrary segment
streams and identity hashes, incomplete/fabricated data bindings, instrument
snapshot/raw-export drift, missing or mismatched external OWNER receipt hashes,
control/seal/cost artifacts in run or forbidden tier roots, contract/stream
drift, generated-stream self-reference, false independence, wrong seal
provenance, pre-seal qualification, seam state carry, start/end mutation,
identity-axis collapse and arbitrary hash-only cost evidence.

## Remaining authorized sequence

1. OWNER signs one `PORTFOLIO_WEIGHT=1` risk decision. The risk tuple compatible
   with the currently bound preset is `0.0564 / 0 / 1`.
2. Development, under separate authority, adds the bound session/holiday
   early-close fallback and moves effective Friday/weekend closure before news
   returns while preserving kill-switch-first behavior. Allocate/requalify a
   new source/binary/preset contract; this packet does not authorize that work.
3. Obtain and pass the three external expected OWNER receipt SHA-256 anchors;
   bundle-local self-attestation is never sufficient.
4. An authorized pipeline operator builds the external sealed-input, session
   calendar and run
   manifests, then executes A/B, owner seal, and C/D in isolated non-tier
   sandboxes.
5. Generate and semantically validate the structured five-axis cost manifest.
6. Run this validator against the final bundle.
7. Only after a complete final evidence hash exists may the parent governance
   process consider a registry decision. Deploy and AutoTrading remain separate
   OWNER-controlled phases.

No registry row was changed by this work.
