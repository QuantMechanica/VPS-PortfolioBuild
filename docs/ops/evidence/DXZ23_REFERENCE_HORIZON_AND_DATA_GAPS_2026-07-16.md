# DXZ-23 Reference Horizon and Data-Gap Adjudication — 2026-07-16

## Scope and verdict

This is a read-only adjudication of the 23 sealed DXZ audit sleeves. It does not
approve a Strategy Card, EA, portfolio, resize, deploy, or live action.

The prior 23-stream snapshot is complete as an immutable audit input, but it is
not a uniform 2018-2025 truth set:

- 6 sleeves reproduce the sealed signal identity exactly.
- 6 more reproduce the native close sequence exactly; their live binary writes
  the legacy Q08 format, so signal-identity promotion is blocked by
  instrumentation rather than by a demonstrated strategy mismatch.
- 3 sealed references have a proven host-history horizon defect: `10476:USDCAD`,
  `11421:AUDUSD`, and `12778:AUDUSD`.
- 8 require substantive lineage, parameter, binary, magic, risk-contract, or
  exit-semantic resolution. They must not be relabeled as history defects.

All rows are independently exposed to one or more known discontinuities in the
literal `.DWX` raw history. A trade-count match across those gaps is therefore
necessary evidence, not sufficient evidence for economic qualification.

## Immutable and runtime evidence

| ID | Evidence |
|---|---|
| E0 | `D:\QM\reports\portfolio\dxz23_audit_requal_input_20260715T221618Z` — immutable corrected input; source manifest SHA-256 `ee47e67f8c9a006452ca39672f8165668381fa78e90999e05a249ac810868ac7`; reference manifest SHA-256 `ad2916865261435c6af0de168734e028714d71011ad1e5a0479105aa2c221940`; seal SHA-256 `4b2d84be0fccfd701e4ce94ced04c30402ca57ff9baa4cb4ec3a05f9bea2cf83` |
| E1 | `D:\QM\reports\portfolio\dxz23_as_live_requal_20260716_hardened\20260716T051551Z` — 23-row full sweep |
| E2 | `D:\QM\reports\portfolio\dxz23_as_live_requal_20260716_technical_retry\20260716T060039Z` — focused retry |
| E3 | `D:\QM\reports\portfolio\dxz23_as_live_requal_20260716_effective_h1_staged_serial\20260716T071056Z` — serial H1 evidence |
| E4 | `D:\QM\reports\portfolio\dxz23_as_live_requal_20260716_effective_h4_staged_serial\20260716T075313Z` — serial H4 evidence |
| E5 | `D:\QM\reports\portfolio\dxz23_as_live_requal_20260716_effective_d1_staged_serial\20260716T080201Z` — serial D1 evidence |
| E6 | `D:\QM\reports\pipeline\QM5_12778\Q08\_baseline\QM5_12778\20260704_203041\raw\run_01` — original 12778 reference-producing tester run |

The staged conversion-history receipt is
`D:\QM\reports\portfolio\dxz23_sandbox_stage_20260716T071000Z\stage_receipt.json`
(SHA-256 `03ac3a9b80ed06f7a0540df9816eba87a52cfd321efbd45ecf84350c971b823d`).
It binds 324 copied files and 4,359,703,959 bytes; the source files were not
modified.

## Gap legend

The dates below are bounded, symbol-dependent observations. They are not a
claim that every venue should trade continuously through weekends or holidays.
Coverage must be evaluated against each symbol's broker session calendar.

| Code | Bounded discontinuity | Exposure |
|---|---|---|
| B | approximately 2023-12-12/13 through 2023-12-18; multiple missing trading days | market-wide `.DWX` cohort |
| C | approximately 2025-10-08/10 through 2025-11-03; observed span about 552-622 hours depending on symbol | FX hosts and all FX/conversion dependencies |
| D | approximately 2025-12-17/18 through 2025-12-22; observed span about 78-104 hours depending on symbol | market-wide `.DWX` cohort |

`H` in the matrix is separate from B/C/D. It means that the reference-producing
host bar series itself ended in 2024 even though the tester requested a 2025 end
date. `R` means a later NDX HCC copy differs from the frozen/sandbox copy; it is
not inherited by the sealed reference and requires its own requalification.

## Final 23-row matrix

| # | Sleeve | Ref -> fresh native | Horizon / identity adjudication | Primary class | Secondary blocker | Gaps | Evidence |
|---:|---|---:|---|---|---|---|---|
| 1 | 10403 XAUUSD D1 | 209 -> 209 | exact Q08 identity | `SIGNAL_IDENTITY_PASS` | 187/209 Friday 21:00 exits require explicit Card semantics | B,D | E1/01 |
| 2 | 10440 NDX H1 | 618 -> 193 | horizon clear; not identity | `PRESET_DRIFT_AND_LEGACY_NDX_NEWS_BINARY` | live `.07/.65/3.25` versus Card `.10/.50/2.50` | B,D(R) | E1/02 |
| 3 | 10476 USDCAD H1 | 257 -> 299 | **H: proven reference horizon defect** | `REFERENCE_HOST_HISTORY_HORIZON_DEFECT` | legacy Q08 instrumentation; 42 additional 2025 closes | B,C,D | E3/03 |
| 4 | 10513 XAUUSD D1 | 76 -> 104 | horizon clear; derivative lineage | `PRESET_LINEAGE_DRIFT` | live `6/18/68, ATR18` versus Card/default `9/26/52, ATR14` | B,D | E2/04 |
| 5 | 10692 NDX H1 | 676 -> 529 | horizon clear; not identity | `LEGACY_NDX_NEWS_BINARY_DRIFT` | reference-era binary test still required | B,D(R) | E1/05 |
| 6 | 10715 USDJPY M15 | 1466 -> 0 | sealed identity invalid | `REFERENCE_MAGIC_SLOT_MISBIND` | sealed slot 2 resolves to GDAXI; correct USDJPY slot is 4 | B,C,D | E1/06 |
| 7 | 10911 GDAXI H1 | 331 -> about 296 | horizon clear; substantive delta | `SIGNAL_DRIFT_UNRESOLVED` | legacy Q08 undercount (about 268) is an additional defect | B,D | E1/07 |
| 8 | 10919 XTIUSD H4 | 30 -> 30 | exact native close sequence | `NATIVE_CLOSE_SEQUENCE_PASS` | legacy Q08 omits required identity fields/events | B,D | E1/08 |
| 9 | 10939 GBPUSD H4 | 92 -> 92 | exact native close sequence | `NATIVE_CLOSE_SEQUENCE_PASS` | legacy Q08 instrumentation | B,C,D | E4/09 |
| 10 | 11132 SP500 D1 | 73 -> 75 | horizon clear; mismatch unresolved | `SIGNAL_OR_EXIT_SEMANTIC_DRIFT` | test/live alias is `SP500.DWX` -> routable broker `SP500`; Card/Friday/source/binary requal remains | B,D | E1/10 |
| 11 | 11165 AUDCAD H1 | 133 -> 133 | exact native close sequence | `NATIVE_CLOSE_SEQUENCE_PASS` | legacy Q08 instrumentation | B,C,D | E3/11 |
| 12 | 11165 EURUSD H1 | 260 -> 260 | exact native close sequence | `NATIVE_CLOSE_SEQUENCE_PASS` | legacy Q08 instrumentation | B,C,D | E2/12 |
| 13 | 11421 AUDUSD D1 | 81 -> 90 | **H: proven reference horizon defect** | `REFERENCE_HOST_D1_HORIZON_DEFECT` | legacy Q08 instrumentation; 9 additional 2025 closes | B,C,D | E5/13 |
| 14 | 11421 EURUSD D1 | 92 -> 92 | exact native close sequence | `NATIVE_CLOSE_SEQUENCE_PASS` | legacy Q08 instrumentation | B,C,D | E1/14 |
| 15 | 11708 EURUSD D1 | 178 -> 178 | exact Q08 identity | `SIGNAL_IDENTITY_PASS` | Friday/Card execution governance | B,C,D | E1/15 |
| 16 | 12567 XAUUSD D1 | 73 -> 73 | exact native close sequence | `NATIVE_CLOSE_SEQUENCE_PASS` | legacy Q08 instrumentation; commodity costs uncertified | B,D | E5/16 |
| 17 | 12567 XNGUSD D1 | 58 -> 49 | horizon clear; parameter drift | `THRESHOLD_DRIFT` | live threshold 30 versus Card/reference 35; commodity costs uncertified | B,D | E1/17 |
| 18 | 12778 AUDUSD/EURJPY D1 | 195 -> 210 | **H: proven reference host-D1 horizon defect** | `REFERENCE_HOST_D1_HORIZON_DEFECT` | legacy Q08 omits AUDUSD end-of-test exit | B,C,D | E5/18, E6 |
| 19 | 12969 USDJPY M30 | 331 -> 331 | exact Q08 identity | `SIGNAL_IDENTITY_PASS` | Card says no fixed stop; EA has active 120-pip stop (2/331 triggers) | B,C,D | E1/19 |
| 20 | 12989 XAUUSD H4 | 51 -> 51 | exact Q08 identity | `SIGNAL_IDENTITY_PASS` | Friday/Card execution governance | B,D | E2/20 |
| 21 | 13128 NDX H1 | 56 -> 56 | exact Q08 identity | `SIGNAL_IDENTITY_PASS` | Card/calendar/source/binary synchronization | B,D(R) | E1/21 |
| 22 | 1556 XAUUSD D1 | 53 -> 53 | exact Q08 identity | `SIGNAL_IDENTITY_PASS` | Friday/Card governance; commodity costs uncertified | B,D | E1/22 |
| 23 | 10706 GBPUSD H1 | 367 -> 367 | entries and outcome signs reproduce; risk contract does not | `REFERENCE_RISK_CONTRACT_DEFECT` | sealed ref uses fixed 1000/USD; as-live uses 0.0564%/EUR; runner sign gate was falsely coupled to identity | B,C,D | E3/23 |

The `about` counts for 10911 are triage observations, not a promotion receipt.
That row remains fail-closed until a clean repaired-binary run produces a sealed
receipt.

## Exact horizon proofs

### 10476 USDCAD

- Sealed reference: 257 closes, last close 2024-10-11.
- Fresh as-live: 299 closes, last close 2025-12-05.
- In positional comparison, 255/257 reference closes are within one second of
  the fresh native closes and all 257 outcome signs agree.
- All 42 added closes are in 2025 (first 2025-02-11, last 2025-12-05).
- Receipt SHA-256:
  `b01b865cc393c42f07c125f03b2d87691e86b9731608cc8dab31de9122372460`.

This is a reference horizon failure, not evidence that the 2025 trades should be
discarded. They need a new content-addressed reference and independent repeat.

### 11421 AUDUSD

- Sealed reference: 81 closes, last close 2024-12-13.
- Fresh as-live: 90 closes, last close 2025-12-23.
- The first 81 fresh closes and outcome signs reproduce the entire reference;
  all 9 added closes occur in 2025.
- Receipt SHA-256:
  `43f091471b505ef22628f8b0e7baeb6ec87bdb0b99ff9d65ab309999d4e4f9b6`.

### 12778 AUDUSD/EURJPY

- Fresh native and current Q08 each contain 210 closes; the sealed stream has
  195.
- The first 194 sealed identities, close times, and outcome signs reproduce
  exactly.
- The first divergence is the pair entered 2024-12-30 00:05. With complete
  host D1 history the two legs close on Friday 2025-01-03 21:00. In the old run,
  EURJPY instead hits its stop on 2025-06-20 16:52:35 and the AUDUSD leg is
  forcibly closed only at end-of-test on 2025-12-30.
- The old Q08 stream records the EURJPY stop but omits the AUDUSD forced close;
  this is the known pre-history-rebuild Q08 instrumentation defect.
- The original tester log explicitly says
  `AUDUSD.DWX: history synchronized from 2017.10.02 to 2024.12.31` while ticks
  were synchronized through 2025. The report contains only 1,782 D1 bars.
- The original Card/backtest set does not override Friday close; the EA/Card
  default is enabled. The evidence therefore does not support a primary
  Friday-configuration-drift label.
- Fresh receipt SHA-256:
  `11f6a459ffa426bba3df312243f1e63770b6083429ff717c575b3a464cc78697`.
- Original report SHA-256:
  `aa8df1b89cbe10a6b0f26655cad0e2a6ef183600c39dc273143b7e9527ca9eb4`.
- Original log SHA-256:
  `2645058a33c11122ee986189b8793d7ff183e28081fe47b9e240e5fc4301b500`.
- Original tester.ini SHA-256:
  `28acc0b3a719ffd59228e2ca3ddf588734799b94319a941a386dea694285f91f`.

## Terminal-copy search

The ten historical factory terminals are replicated copies, not independent
data vendors: for the ordinary 2025 `.hcc` files, byte lengths, timestamps, and
content are identical across T1-T10. Copying between them cannot repair B/C/D.

The only materially different later 2025 host-history copy found is NDX:

| Symbol | Copy | Bytes | SHA-256 |
|---|---|---:|---|
| NDX.DWX | later T1-T10 shared copy | 26,773,056 | `b9c94b19673b17c9a36860e6babdda763330d2d334486b3fe5c6eb0d18deb6e4` |
| NDX.DWX | frozen DXZ Truth sandbox copy | 21,025,377 | `f7e8f9c4fd6bcc53a12faa79fde12127b8106982a44df662c02007b534c6d8e6` |
| AUDUSD.DWX | T1 and sandbox | 20,560,764 | `2773a11f160d294f9bee5a64d5b71a0484cc0a0f9bc24ddfcb11c0460f1d9924` |
| USDCAD.DWX | T1 and sandbox | 20,776,782 | `ab78be0acbaa33bf65ebaf9b1ce678c699c25ea8a7655e7ebd35feb4d41dca5e` |
| EURUSD.DWX | T1 and sandbox | 20,571,204 | `c5c806d345d65e1b1c8cbc4230b0e00a7a85f4b46f208b907b07f40a1c462ae4` |

The larger NDX file is a candidate repair only. It cannot be substituted into
the sealed run silently: its provenance, bar continuity, source identity, and
two independent MT5 reproductions must pass before it becomes a new reference.

## Required continuous-segment gates

Future qualification must fail closed on these rules:

1. **Bind every input.** Freeze host, dependency, conversion, calendar, EX5,
   preset, tester window, and cost-model hashes before the run.
2. **Prove the requested endpoints.** The first and last session-valid bar for
   every required symbol must cover the declared evaluation window. A requested
   `ToDate=2025.12.31` is not proof that the loaded series reached that date.
3. **Use session-aware gaps.** Detect missing expected bars against the broker
   session calendar, not against naive wall-clock continuity. Weekends and
   declared holidays are allowed; B/C/D are not.
4. **Intersect multi-symbol coverage.** A basket segment is the intersection of
   continuous host, leg, conversion, and account-currency history. Never use a
   host-only coverage decision for 12778 or another basket.
5. **Reset at every discontinuity.** No indicator state, rolling window,
   pending order, or open position may cross B, C, D, or an endpoint. Any such
   trade makes the segment invalid; a tester-forced close is not a strategy
   exit.
6. **Warm up, then score.** Rebuild the full causal lookback inside each segment
   and begin scoring only after the EA's declared warmup. Do not borrow pre-gap
   values to seed post-gap indicators.
7. **Score segments separately.** At minimum use:
   - pre-B: effective start to the symbol-specific B boundary;
   - post-B/pre-C for FX, or post-B/pre-D for non-FX;
   - post-C/pre-D for FX;
   - post-D tail only as a continuity/reproduction check unless it contains
     enough observations for inference.
8. **Require identity before economics.** Within each valid segment, require
   non-empty complete signal identity, exact trade count, exact close sequence,
   and independently evaluated outcome-sign identity. Do not couple the sign
   gate to another identity gate.
9. **Require two independent repetitions.** A rebased reference is admissible
   only after two serial, collision-free runs on the same sealed inputs produce
   identical signal/close hashes.
10. **Keep costs fail-closed.** Signal reproduction does not certify economics.
    Commission, spread, swap, and slippage evidence must be complete before a
    PF, resize, challenge-success, or deployment claim.

## Decision

Do not force the three horizon-defect sleeves to match their truncated sealed
streams. Rebase them from complete, hash-bound `.DWX` segments and repeat. Do
not use B/C/D-spanning pooled metrics for any sleeve. Continue to treat all
Card/EA/Friday/magic/risk/cost blockers in the matrix as independent gates.
