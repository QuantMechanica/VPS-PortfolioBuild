# QM5_41105 WTI Monthly Close-Location Source Build and Compile Handoff

Date: 2026-08-29

Branch: `agents/board-advisor`

Outcome: `SOURCE_BUILD_COMMITTED; COMPILE_HELD; Q01_PENDING; Q02_NOT_ENQUEUED`

## Selected commodity edge

`QM5_41105_wti-mclose-location-mom` is a new low-frequency structural WTI
candidate on `XTIUSD.DWX`, not another instance of the certified XNG pullback.
On the first tradable normalized D1 bar of each broker month, it reconstructs
the two immediately preceding completed months. Each month must contain 17 to
23 sessions. For the newest completed month it computes
`r = ln(C0 / C1)` from consecutive month-end closes and
`clv = (C0 - L0) / (H0 - L0)` from that month's aggregate range. It buys only
when `r > 0` and `clv > 0.75`, sells only when `r < 0` and `clv < 0.25`, and
otherwise consumes the monthly attempt flat.

The position uses a frozen `3.5 * ATR(20,D1)` stop, no take profit, and exits at
the next broker-month boundary or through the forty-day stale repair. The sole
backtest preset fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`; news and Friday-close overrides are off. This monthly
WTI momentum/close-location mechanic has a different carrier, horizon,
directional state, and signal construction from `QM5_12567`, the long-only XNG
two-day cumulative-RSI pullback. Diversification is only a hypothesis here;
Q09 remains authoritative for measured correlation.

## Governed source and identity

The durable OWNER-approved source record is
`decisions/2026-08-22_wti_monthly_close_location_momentum_source_approval.md`.
The extraction packet at
`strategy-seeds/sources/MOP-WTI-MCLOSE-LOCATION-MOM-2026/source.md` uses the
peer-reviewed time-series-momentum evidence of Moskowitz, Ooi, and Pedersen
(Journal of Financial Economics, 2012), whose commodity futures universe
explicitly includes WTI. The monthly close-location filter is disclosed as a
QM implementation rule rather than attributed paper performance. G0 approval
is recorded in
`decisions/2026-08-22_qm5_41105_wti_monthly_close_location_momentum_g0.md`.

The approved card's preallocation review scanned 4,594 registry identities,
1,273 cards, and 45 Strategy Wiki nodes. Manual semantic review separated this
mechanic from weekly WTI close-location, unconditional WTI time-series
momentum, final-five-day WTI momentum, WTI range migration, and the certified
XNG strategy. The deterministic registries already bind active EA ID `41105`
and active slot-zero magic `411050000` to `XTIUSD.DWX`.

## Committed build

Source commit `00644dc395bee851f86191e0cdcf016be613acec` adds the V5 EA,
the exact fixed-risk D1 preset, eleven deterministic reference tests, and the
reconciled specification. Artifact identities at handoff are:

- approved card SHA-256:
  `0EAE98EBD889ED99BF642D9569BF4C82BBD84D981BED7D9B2003EFD01FB1D078`;
- source packet SHA-256:
  `2283C2F59BEB9D35FDCD40E03CB3CFFF0CC738C4FEE6D8CA8A39A4853AB1CB6C`;
- source-approval SHA-256:
  `692E97473FE805BDF010554F44D02C622C35B741F59E5124C33B92A003728A64`;
- G0 decision SHA-256:
  `A5A448A50FCF39ABAB3B9DB8694861680ABE65B78A9674B2B15CD247BB786B46`;
- MQ5 SHA-256:
  `9FA2683395D762FE3A1260F957003D419167E8717A42EE9E3AD1247E5778B007`;
- backtest set SHA-256:
  `5DC83D7F59F45AD2F050F1C3A68B62E1F8A09AE12A82AE7FD1232F320AA1B1DF`;
- reference-suite SHA-256:
  `C51AE034DCA93E934F04DD150832ABD1EDC21CC225A5F87729752D3D9A1DB320`;
- SPEC SHA-256:
  `6311286428FD87F1374C9D79E50063D2DA1B53633175D20429C750860B03F033`.

## Source-level verification

The deterministic reference suite passes 11/11 tests. It covers both signal
directions, session-count limits, strict threshold equality, close-location
and return disagreement, correct consecutive month-end closes, malformed and
zero-range data, nonconsecutive months, duplicate normalized dates, D1 label
equivalence, entry grace, persistent monthly-attempt consumption, year
rollover, and lifecycle/static bindings.

The card-schema/prohibited-ML lint and G0-card lint pass. The governed build
prerequisite guard confirms the EA registry row, magic row, and EA directory.
SPEC validation passes 1/1, build guardrails return `PASS` with no findings,
and symbol-scope validation returns `SINGLE_SYMBOL_OK` with zero violations.
The preset contains all 24 source inputs exactly once and retains the required
fixed-risk values. These are source-level checks; they do not claim a compiled
binary, Q01 smoke verdict, or economic result.

## Governed compile and Q02 disposition

The strict ad-hoc compile stopped before MetaEditor execution with
`INCLUDE_MIRROR_REFUSED` / `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because live
factory terminals held the include-mirror interlock. It was not retried or
bypassed. The durable summary is
`D:/QM/reports/compile/20260829_094223/summary.csv`, SHA-256
`A009ED1D24CA24807A1D06FE2C86408E74305FA6A9540CDC1DDFF7D71614514D`.

The sanctioned lane accepted exactly one source-bound compile work item,
`72e08081-b13c-4168-8988-8b790fa0340c`. At the 2026-08-29 handoff it is
`pending`, unclaimed, at attempt zero, with no verdict, build-check result,
evidence path, setfile binding, or EX5 hash. Its active hold is
`COMPILE_EA_WORKER_ROLLOUT_PENDING`, and no `.ex5` exists. The hold was not
released because rollout/restart authority is separate from this build
mission.

Q02 was therefore not enqueued. A valid Q02 row requires the current strict
compile product and its admitted Q01 smoke/build predecessor; creating it now
would break the fail-closed phase contract. The next governed continuation
must consume the existing compile item, require zero errors and zero warnings,
bind the preset to the resulting EX5, complete Q01 review, and then enqueue
exactly one `XTIUSD.DWX` / `D1` Q02 row. It must not create a duplicate compile
item.

## Capacity and safety boundary

The final five whole-host CPU samples were `53.293673`, `42.926981`,
`51.234571`, `40.648076`, and `52.881553` percent: average `48.196971%`,
maximum `53.293673%`. The CPU ceiling was not hit. No backtest was launched,
and no terminal was started, stopped, reserved, released, or reaped.
AutoTrading was not toggled. T_Live, its manifest, the portfolio gate, deploy
records, and portfolio-admission records were untouched. Unrelated dirty
fleet-generated files were preserved and excluded from the mission commit.
