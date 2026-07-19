# DXZ 10939 GBPUSD H4 — Repair and Requalification Packet — 2026-07-16

## Verdict

`10939:GBPUSD.DWX H4` is a promising research sleeve, not a qualified
DarwinexZero strategy. The selected native report has 92 round trips and the
conservative `0.005%` round-trip commission bound leaves PF `1.5830`, net
`EUR 3,888.27` and close-to-close drawdown `EUR 1,139.91`. Mathematically,
`0.005% = 0.5 bp`, not 5 bp. Existing `5bp` artifact/directory names are legacy
labels; the applied fraction is `0.00005`, so none of the economics is rescaled.
Those figures cannot be promoted yet: Card semantics, signed OWNER evidence,
news policy, binary lineage, full Q08 identity, B/C/D-safe segmentation and
externally certified five-axis execution costs remain open. Friday semantics
are no longer an open choice: OWNER directed no weekend holdings and a broker-
hour-21 Friday close, but that directive is recorded and not yet sealed.

This packet is read-only. It did not execute or mutate MT5, T1-T10, `T_Live`,
an APPROVED Card, EA, preset, registry, portfolio, risk setting or deployment.

## Packet identity

| Artifact | SHA-256 | Result |
|---|---|---|
| `docs/ops/evidence/dxz_10939_gbpusd_h4_repair_spec_20260716.json` | `39bed34818ac349585a90b3ef8d6aae0714d3e9edccaba11cdb02a873d433173` | 16/16 baseline file bindings verified |
| `tools/strategy_farm/dxz_10939_repair_packet.py` | `5a44bcc98569d831005d6fd29f990226bc70abdf1ffbeec7964b738c92a0e60c` | read-only, fail-closed validator |
| `tools/strategy_farm/tests/test_dxz_10939_repair_packet.py` | `d7ab3c06727ba474af505c1913553d67d7fafb704cabb6f66084cebb28741d71` | 28 tests PASS; 113 related DXZ security tests PASS |

The JSON spec binds the v1 Card, SPEC, source, repo EX5, repo presets,
read-only deployed EX5/preset, E4 receipt/report/Q08/native stream/tester.ini,
the old sealed reference and both cost-evidence generations by path, byte
length and SHA-256. Schema-v3 is the canonical commission baseline:
`D:/QM/reports/portfolio/dxz_cost_evidence_20260716_v3/report.json`, SHA-256
`98ea8553f4fb6044d757e90c964c8b6fda4f8f40f653e75510833f8f49c694fd`.
Schema-v2 remains immutable superseded audit evidence only and is explicitly
not a qualification input.

## Root findings

### 1. The Card is a QM interpretation, not a mechanical source strategy

The approved v1 Card says `g0_status: APPROVED`, while its body says
`G0: PENDING`. More importantly, the cited Grimes article supplies qualitative
context: momentum without climax, surprise, measured-move risk and
higher-timeframe context. It does not define EMA(20/50), ADX(14/16), ATR(20),
12/30-bar lookbacks, a 25%-55% pullback, 0.25/2.25 ATR stops, 2R target, 1R
breakeven or 18-H4-bar exit. Those are QuantMechanica choices and must appear
as a named QM variant in Card-v2, not as source-defined mechanics. See the
[primary Grimes article](https://www.adamhgrimes.com/context-in-pullbacks-what-should-happen/).

Card-v2 must also explicitly order the broker SL/TP, breakeven management,
61.8% adverse-close exit, 18-bar exit, news gate and the required Friday
override.

### 2. Friday is OWNER-selected but unsealed; news is still an open policy gate

The v1 Card declares neither Friday close nor news behavior. The E4 native
report records the effective runtime as:

- Friday close enabled at broker hour 21;
- news temporal `3` and compliance `1` (`PRE30_POST30` plus DXZ);
- percent risk `0.2007` on EUR 100,000.

These are strategy outcomes, not harmless metadata: Friday can replace a
source/QM exit, and news can remove entries. OWNER's 2026-07-16 directive now
fixes Friday close to enabled at broker hour 21 to avoid weekend gaps and
prepare for prop operation. Its state is `OWNER_DIRECTIVE_RECORDED_UNSEALED`:
the required detached receipt and external trust anchor still do not exist, so
the directive cannot by itself qualify a run. News remains an explicit OWNER
choice. A machine may not inherit either setting and retroactively call it Card
semantics.

### 3. The tested binary is not the repo binary

| Input | SHA-256 / value |
|---|---|
| E4/deployed EX5, read-only | `ed64e912ab95c803cb4bbbdeb0001091bf49efe15f5358fae616804ae136bda3` |
| repository EX5 | `8fb85437bd67a51c2a0b050246632fc316b938b4992653479a83a573cb691e77` |
| E4/deployed preset risk | `0.2007%` |
| repository live preset risk | `0.7500%` |

Strategy parameters match their source defaults, but that does not prove the
recursive include closure or make either binary authoritative. OWNER selects
the source-of-record; Development then performs a clean, hash-bound compile.
Profitability is not a binary-selection rule.

### 4. Native close reproduction passed; Q08 identity failed

- Native report: 92 round trips.
- Old sealed reference: 92 rows and exact native close sequence.
- E4 legacy Q08: 67 rows.
- Valid E4 Q08 identity rows: 0; every row lacks `entry_time`.

The old reference is byte-identical to the 2026-07-12 clean-book stream from a
historical T2/Common workflow. It lacks a self-contained producer receipt that
binds the binary, preset, complete data, segment resets and output origin. It is
useful audit evidence, but is intentionally inadmissible as the new reference.

The replacement proof normalizes the Q08 emitter separately, while the
validator semantically reparses every native MT5 Deals table with the existing
round-trip parser. Compact, MT5-comment-safe `QM10939E|TOKEN|SL|TP` and
`QM10939X|TOKEN` markers carry reason and initial SL/TP fields absent from
standard deal columns without exceeding the normal comment envelope. The native
identity JSONL must be byte-content-equivalent to those report-derived rows;
an arbitrary report string or self-declared `source_sha256` cannot pass. Entry,
exit, outcome-sign, close-sequence and full-round-trip digests must all match.

### 5. Six zero-move commissions remain bounded, not exactly resolved

Darwinex describes Forex commission as approximately `0.005%` of base-currency
nominal for the round trip, with account-currency conversion; this is `0.5 bp`
round trip. Spread and variable swap are separate costs. See the
[official execution-cost page](https://help.darwinex.com/execution-costs).

The canonical schema-v3 report records the unit contract explicitly as
`0.00005 decimal = 0.005% = 0.5 bp` and reproduces the conservative 10939
economics quoted above. It still classifies the six rows below as
`BOUNDED_AMBIGUOUS_FAIL_CLOSED`, so schema-v3 corrects and seals the baseline;
it does not waive exact row resolution or certify all five cost axes.

| Index | Entry -> exit, MT5 server | Side | Price | Lots |
|---:|---|---|---:|---:|
| 2 | 2018-01-02 12:00:00 -> 2018-01-03 16:22:29 | buy | 1.35486 | 0.39 |
| 7 | 2018-04-10 12:00:00 -> 2018-04-11 14:33:13 | buy | 1.41671 | 0.44 |
| 13 | 2018-08-08 12:00:00 -> 2018-08-09 13:20:18 | sell | 1.29053 | 0.38 |
| 58 | 2022-11-15 12:00:00 -> 2022-11-15 20:28:59 | buy | 1.18238 | 0.16 |
| 79 | 2024-09-23 16:00:00 -> 2024-09-25 19:45:43 | buy | 1.33277 | 0.25 |
| 80 | 2024-11-13 20:00:00 -> 2024-11-14 17:22:00 | sell | 1.27100 | 0.32 |

Because signed move and gross P/L are zero, the existing replay cannot infer an
exact per-trade account-currency multiplier. The new bundle must resolve every
fingerprint either from native DXZ deal commission or exact base nominal plus a
hash-bound conversion and rounding rule. Required final counts are
`ambiguous=0`, `unbounded=0`; same-symbol K bounds alone do not pass.

## B/C/D segment contract

The gap dates are search bounds. Exact first/last session-valid bars must be
detected against a hash-bound DarwinexZero server-session/DST calendar and the
intersection of GBPUSD H4, GBPUSD D1 and the EUR account-conversion dependency.

| Segment | Role | Rule |
|---|---|---|
| pre-B | inference | new process; at least 60 H4 and 50 D1 segment-local warmup bars; non-empty identity |
| post-B / pre-C | inference | same; non-empty identity |
| post-C / pre-D | continuity only | interval is shorter than D1 EMA(50) warmup; no economics |
| post-D tail | continuity only | year-end tail is shorter than warmup; no economics |

Every segment is a separate process/state domain. Pre-gap prices may not seed
indicators or rolling state. Entries during warmup are forbidden. Position and
pending-order counts must be zero at both endpoints. A tester-forced close
invalidates the segment; it is not a strategy exit. B/C/D-spanning PF is never
carried forward.

## OWNER gates versus machine work

Five detached OWNER receipts are required before reference production:

1. Card-v2 classifies the quantitative mechanics as a named QM interpretation.
2. Friday is the already selected 21:00 broker-time framework override; the
   receipt seals that fixed directive rather than reopening the choice.
3. News is explicitly `DXZ_PRE30_POST30` or off.
4. One positive as-live percent-risk contract on EUR 100,000 is frozen with
   `RISK_FIXED=0` and `PORTFOLIO_WEIGHT=1`.
5. One source/include closure is named as source-of-record.

Each approval must arrive as a structured receipt binding `gate_id`, the exact
decision, this spec's SHA-256, `approved_by: OWNER` and a UTC approval time. In
addition, the validator requires an OWNER trust-anchor path and its expected
file SHA-256 via separate command-line inputs. That external anchor pins every
receipt hash and decision. A receipt's self-hash or a bare `APPROVED` field in
the bundle is integrity metadata, not OWNER authority.

Machines then perform only deterministic work: clean compile, literal `.DWX`
history sealing, session-aware segmentation, process/reset receipts, warmup
enforcement, independent native/Q08 extraction, identity comparison and cost
certification. No machine gate is allowed to decide Card meaning.

## Fail-closed evidence envelope

The bundle's sealed-input manifest is structured JSON, not an empty hashable
placeholder. It binds the exact Card-v2, all OWNER receipts, external trust-
anchor hash, source manifest, source/include closure, compile log, EX5,
approved live preset, structured literal `.DWX` series-file/instrument/session
manifests, segment boundaries, both extractor contracts, external cost manifest
and effective runtime contract. Every series manifest binds a non-empty data
file, range and record count; instrument files bind digits, point, contract
size and currencies; the session artifact binds weekly hours and DST changes.
The preset itself is parsed and must
declare `environment: live`, `RISK_FIXED=0`, the exact approved `RISK_PERCENT`
and `PORTFOLIO_WEIGHT=1`.

Cost status cannot be supplied by five bundle-local `PASS` strings. The
validator reuses the hardened external cost-manifest loader and rechecks its
immutable sidecars, exact source-manifest hash, validation time, evaluation
window and required `10939:GBPUSD.DWX:H4` coverage. Commission, historical
tester spread, current broker spread parity, current broker swap parity and
slippage stress must all independently revalidate as `PASS`; `{}` cannot pass.
The schema-v3 standalone report is the canonical commission baseline, while
the completed bundle must additionally provide this separate full five-axis
manifest. Superseded schema-v2 is accepted for neither role.

## Non-self-referential three-run proof

Qualification requires three run groups on the same sealed inputs:

1. `REFERENCE_PRODUCER` completes first and is sealed by structured JSON that
   binds its run ID, finish/seal times, input-contract hash, every run artifact
   and every per-segment identity digest.
2. Verification run 1 starts only after the seal.
3. Verification run 2 starts only after run 1 finishes.

All run IDs, execution IDs, sandbox IDs and isolation IDs must be globally
casefold-distinct. Output and isolated MT5 roots may not equal, contain or
descend from another run root. Every generated artifact must lie below its own
output root, the report below its own MT5 root, and no generated path may be
reused or nested. OWNER, control, cost and seal artifacts must remain outside
all run and MT5 roots. The seal cannot list itself as a run artifact. Within
every execution, Q08 must equal the semantically parsed native report. Per
segment, all five identity digests and trade counts must then be identical
across reference, run 1 and run 2. This is three provenance-distinct
productions of the same result, not one output copied into three filenames.

Finally, the runner's five DarwinexZero cost axes must all be `PASS`:
commission, historical tester spread, current broker spread parity, current
broker swap parity and adverse slippage stress. DarwinexZero's independent
risk engine does not repair an unstable signal-account risk contract; its
published design uses the strategy's exposed-day history and risk adjustment,
so consistent sizing remains relevant. See the [official risk-engine description](https://www.darwinexzero.com/docs/en/risk-engine).

## Validation

Spec-only validation (already PASS):

```powershell
python tools/strategy_farm/dxz_10939_repair_packet.py `
  --spec docs/ops/evidence/dxz_10939_gbpusd_h4_repair_spec_20260716.json
```

Completed-bundle validation, when the separately authorized evidence exists:

```powershell
python tools/strategy_farm/dxz_10939_repair_packet.py `
  --spec docs/ops/evidence/dxz_10939_gbpusd_h4_repair_spec_20260716.json `
  --bundle D:/QM/reports/portfolio/dxz_10939_requal_<run>/bundle.json `
  --owner-trust-anchor D:/QM/owner-trust/dxz_10939_owner_anchor.json `
  --owner-trust-anchor-sha256 <OWNER_SUPPLIED_SHA256>
```

The validator only reads and hashes artifacts. Its positive fixture proves a
complete three-group bundle. Twenty-eight tests also reject reused,
self-referential, nested or foreign-root artifacts; casefold ID collisions;
unstructured data/instrument files; arbitrary native-report text; native
identity not derived from the report; short warmup; unresolved commission rows;
Friday/OWNER mismatch; overlapping verification runs; forbidden terminal
roots; arbitrary cost JSON; risk double scaling; an empty reference seal; and
self-rehashed OWNER receipts without the externally pinned trust anchor.

Current decision: `BLOCKED_PENDING_SIGNED_OWNER_EVIDENCE_AND_NEW_RUNS`. The
92-trade PF is a repair priority signal, not a sustainable-strategy or
deployment claim.
