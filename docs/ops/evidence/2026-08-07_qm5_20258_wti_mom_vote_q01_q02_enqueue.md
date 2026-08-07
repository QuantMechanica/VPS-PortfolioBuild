# QM5_20258 WTI Momentum Vote Q01 And Q02 Enqueue

Date: 2026-08-07 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20258_wti-mom-vote` is built and Q01 is `PASS`. Q02 is
`ENQUEUED`: work item `ff028e35-d4c2-49ad-98c4-e0acc80b55c5` was read back as
pending, unclaimed, and attempt 0 for `XTIUSD.DWX` immediately after the single
apply-mode enqueue. No dispatch command or manual backtest was run.

## Edge And Non-Duplicate Boundary

At the first processed D1 bar of a genuine new broker month, the EA derives
thirteen consecutive completed WTI month-end closes. It calculates the signs
of WTI's completed one-, three-, and twelve-month log returns from the common
newest endpoint and trades their fixed two-of-three majority. A zero component,
invalid arithmetic, nonconsecutive history, or stale endpoint consumes the
month flat. One frozen `3.5*ATR(20,D1)` stop protects the position, which exits
at the next broker month or after forty calendar days.

The deterministic pre-allocation checker scanned 4,315 EA-registry rows and
432 cards, found no exact slug or strategy-ID collision, and returned two
expected source-family fuzzy neighbors. Manual review resolved them and the
economically closest WTI systems:

- `QM5_20187`, `QM5_20055`, and `QM5_12603` follow one horizon alone;
- `QM5_20056` requires three/twelve agreement and is flat on disagreement;
- `QM5_12711` requires six/twelve agreement and `QM5_12616` requires
  three/nine agreement;
- `QM5_20244` combines twelve-month direction with monthly-sign breadth;
- `QM5_20239` is an older-trend/newest-month pullback state; and
- `QM5_20253`, `QM5_20256`, and `QM5_20257` require variance-ratio memory
  significance states.

The exact nested one/three/twelve horizons, strict component signs,
two-of-three aggregation, persisted monthly attempt, and package renewal are
jointly load-bearing. This is direct crude-oil exposure rather than another
XAU, SP500, NDX, or XNG carrier. Realized decorrelation is not claimed; Q09
alone may measure it if every preceding gate passes.

## Source And G0 Record

The tier-A source is Moskowitz, Ooi, and Pedersen (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The complete governed review is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`; the bounded WTI vote
extraction is `strategy-seeds/sources/MOP-WTI-MOMVOTE-2026/source.md`.

The source supplies explicit WTI membership and monthly own-return-sign rules
across formation lags. The two-of-three aggregation is a transparent QM
hypothesis, not an author result. No source profitability, density,
WTI-constituent, cost, or portfolio-correlation result transfers.

G0 authorization is
`decisions/2026-08-07_qm5_20258_wti_mom_vote_g0.md`. The authorization is
commit `06850ebe9`, source/card approval `e36c003ed`, deterministic registry
allocation `3daeda513`, and build `4d6bbbe53`.

## Deterministic Allocation And Q01 Evidence

- EA ID/slug: `QM5_20258` / `wti-mom-vote`.
- Strategy ID: `MOP-TSMOM-2012_XTI_MAJ1312_S12`.
- Symbol/slot/magic: `XTIUSD.DWX` / 0 / `202580000`.
- Card schema/ML lint: PASS on both intake and canonical cards; no missing
  sections or ML hits.
- SPEC validation: PASS, one target and zero failures.
- Strict target-scoped build gate:
  `D:/QM/reports/framework/21/build_check_20260807_024058.json` (`PASS`,
  strict mode, 0 failures, 0 warnings).
- The gate's single compiler invocation:
  `D:/QM/reports/compile/20260807_024058/summary.csv` (`PASS`, 0 errors,
  0 warnings).
- Compile log:
  `C:/QM/repo/framework/build/compile/20260807_024058/QM5_20258_wti-mom-vote.compile.log`.
- EX5 size: 377,760 bytes.
- Setfile risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; generated header build hash
  `b1bd743a557bdfbc95c97fbc845593e6edfccea40e9d2bf8a561b215c6956e4e`.
- Manual smoke/backtest: none.

Artifact SHA-256 values after the Q01/Q02 card-status update:

| Artifact | SHA-256 |
|---|---|
| Source packet | `3F4EF172E9B299CC4EF328395B7DE74B8C66891C6CF40337A3CF24929D5C944F` |
| Canonical/build card | `89C35A03D6FF0565812FB8AD81A569115F3A4ECD7D1960DAE78222D67D65C550` |
| MQ5 | `CD97C2E6B8EDB16A4B804A22C3091DE9034FBA4D3034EF0283EEC92AA395962F` |
| EX5 | `B4036464B095783C590671C0DC60892BCB2F44DF0AC928101AF372D1B3022934` |
| SPEC | `2D2C0C278FEF37C105355E80D3A3E4480943A02925FB9049AD97A60E3FC46FD1` |
| Backtest set | `7A3A733C51F77C27D2C0AA606E83391DE4AAA84BCD01E751CDCB4936122E239F` |

## Q02 Capacity And Enqueue

`farmctl mt5-slots` sampled governed processes at
`2026-08-07T02:42:42+00:00` and found six active factory terminals against the
paced ceiling of seven:

| Terminal | PID | Active phase |
|---|---:|---|
| T2 | 20804 | Q02 |
| T3 | 17240 | Q02 |
| T4 | 19124 | Q02 |
| T8 | 19600 | Q02 |
| T9 | 16868 | Q02 |
| T10 | 4048 | Q07 |

Only executables rooted under `D:/QM/mt5/T1..T10/terminal64.exe` count. The
separate `C:/QM/mt5/T_Live` and FTMO processes were observed by the read-only
sample but excluded and were not accessed or changed. With governed load at
6/7, the target-only dry run reported one eligible never-tested item. The
single apply-mode command then reported one Q02 enqueue, zero stranded items,
and zero deferred promotions.

Immediate readback recorded:

- work item: `ff028e35-d4c2-49ad-98c4-e0acc80b55c5`;
- phase/kind: `Q02` / `backtest`;
- symbol: `XTIUSD.DWX`;
- status: `pending`;
- attempt count: 0;
- claimed by: null;
- created: `2026-08-07T02:43:06+00:00`.

This is an enqueue handoff, not a Q02 screening verdict.

## Safety Boundary

- No dispatch tick, manual backtest, or downstream phase was run.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading and `T_Live` were not touched.
- The portfolio gate and T_Live manifest were not touched.
