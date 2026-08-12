# Q8 / 12567 XNG Card-v2 approval request — 2026-07-16

Status: **IN_REVIEW / BUILD BLOCKED**  
Runtime effect: **NONE**

## Decision requested

Approve a Card-v2 execution contract for the sleeve
`12567:XNGUSD.DWX:D1` without retrospectively blessing the optimized live
threshold.

The requested qualification baseline is `XNG_BASE35`:

- cumulative RSI(2) entry strictly below `35`, as stated by the existing
  approved Card;
- all other strategy parameters equal to the Card/source-build baseline;
- framework news policy declared explicitly;
- mandatory no-weekend policy declared explicitly;
- sleeve-scoped execution identity `(ea_id, symbol, timeframe, variant_id)`;
- fresh isolated target-binary requalification and full cost evidence.

The existing `entry=30` preset is classified as the separate
`XNG_ENTRY30_CHALLENGER` variant. It was selected after a Q12 sweep on the
2017–2025 history and therefore must not inherit the Q8 baseline's historical
qualification. It may run only as a zero-risk/shadow challenger and needs a new
prospective confirmation period after its own freeze.

## Proposed Card-v2 contract

```yaml
card_schema_version: 2
ea_id: QM5_12567
slug: cum-rsi2-commodity
status: IN_REVIEW
g0_status: IN_REVIEW
execution_contract_status: IN_REVIEW
symbol: XNGUSD.DWX
timeframe: D1
variant_id: C_XNG_BASE35_POLICY
source_card_sha256: PENDING_REVIEW_BINDING
owner_approval: RECORDED_UNSEALED_CHAT_DIRECTION
quality_business_approval: PENDING
quality_tech_review: PENDING
```

The OWNER stated in chat on 2026-07-16 that everything on the OWNER side is
released. This is recorded as direction to continue preparation, but it is not
represented as the required artifact-hash-bound OWNER seal and does not supply
the separate Research, Quality-Business or Quality-Tech reviews.

### Source-defined rule

The cited source defines a two-observation cumulative RSI(2) oversold entry
with threshold `35`. It does not itself define the commodity port, SMA(200),
RSI(2)>65 exit, five-bar time exit, ATR stop, spread cap, news mode, Friday
flattening or position sizing.

### QM interpretations requiring explicit approval

| Variant/rule | Proposed value | Classification |
|---|---:|---|
| instrument port | `XNGUSD.DWX D1` | QM interpretation |
| trend alignment | close above SMA(200) | QM interpretation inherited from the approved Card |
| recovery exit | RSI(2) > 65 | QM interpretation inherited from the approved Card |
| time exit | 5 completed D1 bars | QM interpretation inherited from the approved Card |
| initial stop | 2.5 × ATR(14,D1), never widened | QM interpretation inherited from the approved Card |
| spread cap | 300 points | QM interpretation; must be checked against current broker parity |
| news | PRE30/POST30 plus DXZ compliance | framework override; must be Card-qualified |
| weekend | flat by the effective pre-weekend deadline | OWNER risk-policy override |
| risk | exact qualification set uses `RISK_FIXED=1000`; live percent risk comes only from a signed deploy manifest | framework risk contract |

### Exit and gate precedence

1. kill-switch and mandatory risk-reducing exits;
2. session-aware effective weekend deadline: the earlier of broker Friday 21:00
   and the last executable pre-weekend/holiday session minus an OWNER-approved
   safety buffer;
3. block and cancel new/pending risk after that deadline;
4. strategy RSI recovery / five-D1-bar exit;
5. news and other entry-only gates;
6. new entry evaluation on one completed D1 bar.

News must never suppress a mandatory close. Close failure must be logged and
retried according to the frozen execution contract.

## Predeclared variants

| Variant | Entry | Friday policy | Promotion use |
|---|---:|---|---|
| `R0_LEGACY_IDENTITY` | 30 | legacy fixed Friday 21 behavior | identity control only; never promotable |
| `A_SOURCE_BASE35_NATIVE` | 35 | off | research control only; violates OWNER no-weekend policy |
| `B_BASE35_FIXED_FRIDAY` | 35 | fixed Friday 21, no session fallback | negative execution control; never promotable |
| `C_XNG_BASE35_POLICY` | 35 | session-aware no-weekend deadline | sole immediate Q8 promotion candidate |
| `D_XNG_ENTRY30_CHALLENGER` | 30 | same policy as C | shadow/prospective only; cannot use 2017–2025 as confirmation |

No variant may be selected after observing its performance. `C` is the only
current qualification candidate. `D` remains a separate challenger regardless
of whether its historical metrics are better.

## Frozen qualification contract

- Development window: full available 2018–2025 data, explicitly labelled
  `DEVELOPMENT`; report 2018–2022 and 2023–2025 separately.
- Tester model: Every Tick Based on Real Ticks / Model 4.
- Literal symbol/timeframe: `XNGUSD.DWX`, `D1`.
- Two independent identical runs of the same hash-bound EX5, set, Card,
  execution contract, data snapshot and cost manifest.
- Primary identity hashes: entries, exits with reasons/times, lots, net P&L,
  daily MTM and complete receipt payload.
- Five cost axes: commission, historical spread provenance/coverage, current
  spread parity, swap and slippage/gap stress.
- Portfolio admission: synchronized Q8 MTM, common capital/margin and the
  predeclared correlation/return/DD gates; standalone PF is insufficient.
- Qualification runner: `TARGET_BINARY_REQUAL`; no mutation of `T_Live`, T1–T10
  or deployed presets/binaries.
- Prospective confirmation begins only after the final freeze. Any source,
  Card, set, binary, calendar, cost, variant or risk change starts a new version.

## Required approvals before Development may patch the EA

- OWNER: no-weekend safety buffer, retry deadline and risk posture.
- Research + Quality-Business: Card-v2 classification and the quarantine of
  `entry=30` as a hindsight-selected challenger.
- Quality-Tech: review the session-aware framework helper/API and
  Master-EA/module consequences proposed by Development.
- Development: only after all preceding approvals, implement the exact frozen
  contract and compile it.

Until these signatures are hash-bound, the valid state is `BLOCKED`, not PASS.

## Evidence

- Canonical legacy Card:
  `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12567_cum-rsi2-commodity.md`
- Current execution registry:
  `framework/registry/dxz23_execution_contracts.json`
- Weekend runtime gap:
  `docs/ops/evidence/DXZ_NO_WEEKEND_RUNTIME_ORDERING_GAP_2026-07-16.md`
- Existing lineage audit:
  `docs/ops/evidence/DXZ23_CARD_EA_PRESET_REPORT_LINEAGE_AUDIT_2026-07-16.md`
- Machine-readable predeclaration:
  `docs/ops/evidence/dxz_12567_xng_ablation_contract_20260716.json`
- Q8 Gold-only Gate-Matrix:
  `docs/ops/evidence/dxz_q8_fail_closed_gate_matrix_20260716.json`
