# QM5_12929 seven-FX expanded micro-channel — Q01 recycle CPU-ceiling handoff

Date: 2026-08-23

Branch: `agents/board-advisor`

EA: `QM5_12929_brooks-expanded-micro-channel-h1`

Farm task: `7b431d7a-a902-4947-a932-ffa8ef3a54d7`

Outcome: **Q01 SOURCE/SPEC RECYCLE REPAIRED; COMPILE REFUSED AT CPU CEILING;
Q02 NOT ENQUEUED**

## Diversity selection and collision control

The farm task was claimed from `TODO` only after checking the approved build
backlog and current work-item inventory. No open work item or sibling claim
existed for QM5_12929. Crypto, rates, Brent, and lumber were unavailable on the
current validated `.DWX` matrix, while apparent market-neutral pair cards had
already entered Q02–Q04 and would have duplicated existing funnel work.

QM5_12929 was therefore the highest-diversity feasible approved Q01 candidate:
seven registered FX carriers (`EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`,
`USDCHF.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, and `NZDUSD.DWX`), five registered
index carriers, and `XAUUSD.DWX`. The seven FX carriers directly diversify the
current Q08 survivor concentration in indices, metals, and energy.

The approved card is structural, deterministic, and low frequency. It cites Al
Brooks, *Trading Price Action: Trends* (Wiley, 2012), ISBN
978-1-118-06624-0, chapters 12 and 14, plus the public ForexFactory source
cluster. Its durable Q00 frontmatter records `g0_status: APPROVED` and R1–R4
PASS.

## Recycle repair

The prior Q01 attempt had already left a complete, uncommitted implementation
in the shared checkout. The reviewer accepted its refusal to compile and
recycled the task for two specific hard-gate repairs. This unit preserves that
card-faithful implementation and closes those source-level defects:

- All 13 direct closed-bar OHLC reads now carry explicit `perf-allowed`
  reviewer annotations. Entry detection is reached only after
  `QM_IsNewBar(_Symbol, strategy_tf)`, position trailing returns unless the
  same new-bar flag is true, and every annotated read uses shift 1 or older.
- `SPEC.md` now implements the complete seven-section Q01 contract, including
  all 23 strategy inputs, the exact 13-carrier surface, H1 bar gating,
  behavioral priors, the reputable source pointer, fixed-risk backtest rules,
  and revision history.

The strategy remains the approved 8–20-bar HH/HL or LL/LH staircase with
no-thrust, least-squares slope, compactness, and SMA50/SMA200 macro-bias gates;
buffered stop entry; structural capped stop; 2 ATR target; three-bar one-way
trail; 36-bar time stop; and deterministic reuse, session, spread, news, and
Friday controls. No ML, banned indicator, grid, martingale, or live-enablement
mechanic was added.

## Deterministic identity and risk surface

`ea_id_registry.csv` already contains active EA ID 12929. The active magic rows
are slots 0–12 with values 129290000–129290012, covering exactly the 13
registered symbols described above. No registry mutation was required.

All 13 existing H1 backtest setfiles were audited. Each has
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. No live setfile,
live risk value, portfolio allocation, deploy record, or manifest was created
or changed.

The source SHA-256 after repair is
`90782AAFBE4773AA4644ED614A8DC1CBFAC8C459251FE1167F5D37198EF41DB5`.
The SPEC SHA-256 is
`5F2AE6EFCC36A9D804366C03F4D41FE81C21E2F6EF6106F93EAEC133FA38E367`.
The runtime approved card and EA-local card are byte-identical at SHA-256
`94FB997C302A7611ADCA3C40F196F9D97223DA8C8599614EA15992A69372F299`.

## Source-level validation

- Q01 SPEC validator: PASS (1 PASS, 0 FAIL).
- Build guardrails: PASS across 14 files with zero findings.
- Risk-set audit: 13/13 `RISK_FIXED=1000`, 13/13 `RISK_PERCENT=0`, and 13/13
  `PORTFOLIO_WEIGHT=1`.
- All 13 raw OHLC calls have the reviewer-requested new-bar performance
  annotation.
- Scoped `git diff --check`: PASS.

The standard build check was invoked exactly once. Its mandatory compile guard
refused before compilation with:

`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED: terminal64 processes are alive; ad-hoc
compile/build_check is refused.`

No retry was attempted. Consequently there is no build-check PASS report, EX5,
smoke report, or Q01 binary verdict from this wake.

## CPU-ceiling stop and Q02 state

Five consecutive whole-host `Processor(_Total)` samples at 02:15:16,
02:15:18, 02:15:20, 02:15:23, and 02:15:25 Europe/Berlin were all exactly
100.0 percent. The read-only farm inventory also reported eight active governed
terminals (`T1`, `T2`, `T4`, `T6`, `T7`, `T8`, `T9`, and `T10`), with no
duplicate terminal workers and no orphaned terminal process.

This is the mission's explicit stop condition. No compile utility, smoke test,
Q02 preview, Q02 work item, dispatcher tick, terminal reservation, tester, or
manual backtest was launched or enqueued. Q02 remains correctly gated by the
absent strict compile, EX5, final build binding, and Q01 PASS.

## Safe continuation and safety boundary

After sustained whole-host CPU is below the paced-fleet ceiling, enqueue the
source-fresh governed compile with:

`python tools/strategy_farm/farmctl.py enqueue-compile
QM5_12929_brooks-expanded-micro-channel-h1`

Then require zero compile errors and warnings, a non-empty EX5, build-check
PASS, final setfile build bindings, and exactly one successful smoke before
review and Q02 fan-out. Do not alter the approved strategy to manufacture
frequency; Q02 owns the full-history cadence finding.

No AutoTrading action, `T_Live` mutation, live/deploy-manifest change,
portfolio-gate change, portfolio admission, or certification claim occurred.
`T_Live` and the unrelated FTMO process were visible only in the read-only
process inventory and were not touched.
