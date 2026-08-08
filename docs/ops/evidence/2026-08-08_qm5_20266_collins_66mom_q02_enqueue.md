# QM5_20266 Collins 66% Momentum — build and Q02 enqueue evidence

Date: 2026-08-08
Branch: `agents/board-advisor`
EA: `QM5_20266_collins-66mom`
Carrier: `XTIUSD.DWX`, D1, magic slot 0 (`202660000`)

## Outcome

A new low-frequency energy sleeve was extracted, approved, registered, built,
strictly compiled, and admitted to Q02. The governed baseline work item is
pending; no local backtest was launched by this mission.

## Edge selection and non-duplication

- Selected edge: Art Collins' Continuous 66 Percent Momentum geometry, ported
  to WTI as `SRC08_S01_XTI`.
- The initial repository state contained the source seed card but no allocated
  EA ID, EA directory, executable, magic row, or Q02 work item for this edge.
- Gold/silver ratio reversion was rejected because exact basket variants were
  already built. The WTI alternative adds crude-oil exposure rather than
  another index, metal, or XNG signal.
- The closest Collins WTI build, `QM5_12767_collins-15rex`, uses SMA(25) plus
  1.5 times the prior daily range. QM5_20266 instead uses the completed
  nine-day close-location distances `XH`, `XL`, and `XX` with source fractions
  0.66 and 1.32. It is therefore mechanically distinct, not a parameter clone.
- The G0 decision and comparison record is
  `decisions/2026-08-08_qm5_20266_collins_66mom_g0.md`
  (SHA-256 `e2714f882b6c51985e18573b60212182244ea157ee72fbb576d61d24a353790c`).

## Source and authorization

The primary source is Art Collins, *Beating the Financial Futures Market*,
John Wiley & Sons (2006), Chapter 41 printed pages 177-179 and Appendix Table
41.3 printed page 232. The bounded section was read from the durable,
OWNER-approved local `SRC08` source packet. The card explicitly treats WTI as
an out-of-sample falsification carrier and transfers no source performance.

Research and registry commits:

- `4ae49685feec13a913e695b31c17feb7a135b8a9` — approved source-backed card and G0 decision.
- `5f34182783718049cecd504dbf86d55dba6bb3f1` — deterministic EA ID reservation.
- `4d7b5f07071baeab4ff26f465b820ad0149a4176` — EA, executable, RISK_FIXED setfile, magic row, and resolver.

## Build identity

| Artifact | SHA-256 |
|---|---|
| `QM5_20266_collins-66mom.mq5` | `26965c9164b887e81e533837eb9b8005a3981d027619b718bcab014ab874394c` |
| `QM5_20266_collins-66mom.ex5` | `8760402ac1ba34d9631b125989d13e63a737a0a305f6b3d6b00f3d1b6e128fed` |
| `QM5_20266_collins-66mom_XTIUSD.DWX_D1_backtest.set` | `1e5db116a559198cf26b27c099728b636e3fce05b5cbf899a1fffafbcbe3f6e9` |
| Approved card before queue-history update | `6bb1d7e062cc8492019b30771ac9a54b4e64fe8fff4f35cbb2663438a7fc9368` |

The backtest setfile fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, with the source defaults 9 / 0.66 / 1.32 / 20. No live
setfile exists.

## Mechanical verification

- Card schema lint: PASS; no ML hits and no missing sections.
- G0 card lint: PASS.
- Targeted build preflight: EA registry row, magic row, and EA directory PASS.
- Magic resolver regeneration: 15,559 rows kept, zero dropped. The build
  commit's staged registry SHA and embedded resolver SHA both equal
  `60B719FE9DE5D23CA134FC90674EFD56B973C4421973464CFCDF2870D2EF5D2A`.
- Strict compile: PASS, zero errors, zero warnings. Final compile log:
  `C:/QM/repo/framework/build/compile/20260808_174623/QM5_20266_collins-66mom.compile.log`.
- Framework build check: PASS, zero failures, zero warnings. Report:
  `D:/QM/reports/framework/21/build_check_20260808_174623.json`.
- Build guardrails: PASS with no findings.
- P1 binary-presence validation: PASS. Evidence:
  `D:/QM/reports/pipeline/QM5_20266/P1/P1_QM5_20266_result.json`.

The repository-wide registry validator still reports its pre-existing legacy
registry backlog; the targeted 20266 preflight and collision checks pass, and
no reported issue names EA 20266.

## Q02 receipt

Targeted dry run found exactly one never-tested candidate and no capacity
skip. Applying the same targeted sweep created:

| Field | Value |
|---|---|
| work item | `8927c178-1c81-46bd-84fd-33f3d6c77132` |
| kind | `backtest` |
| phase | `Q02` |
| symbol | `XTIUSD.DWX` |
| status at verification | `pending` |
| attempt count | `0` |
| created UTC | `2026-08-08T17:48:47+00:00` |

## Scope controls

No portfolio gate, T_Live manifest, deploy manifest, `C:/QM/mt5/T_Live`
artifact, terminal AutoTrading state, or live preset was readied or changed.
The mission stopped at governed Q02 enqueue.
