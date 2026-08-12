# QM5_20268 XAU/XAG Quantile-Tail Reversion — Q01 PASS / Q02 Enqueued

Date: 2026-08-09 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20268_xauxag-qtail-rv` is a new D1 precious-metals relative-value
basket. It passed Q01 and has exactly one paced Q02 logical-basket work item:
`2b803c41-5ef5-4cf4-8b20-ce51681287bc`.

The row was `pending`, attempt 0, unclaimed, and without a verdict at the
confirmation readback. Enqueue is a screening handoff, not a performance,
neutrality, decorrelation, certification, or portfolio-admission result.

## Edge And Non-Duplicate Boundary

At each new `XAUUSD.DWX` D1 host bar, the EA aligns 129 completed XAU and XAG
closes and forms `ln(XAU)-ln(XAG)`. Completed shifts 4 through 129 define a
frozen 126-observation empirical distribution. The exact zero-based order
statistics are `q10=s[12]`, `q50=(s[62]+s[63])/2`, and `q90=s[113]`.

Shift 3 must be inside the outer-decile band and shifts 2 and 1 must both be
strictly beyond the same tail. The EA fades an upper event by selling XAU and
buying XAG, and fades a lower event with the inverse package. It exits through
the newest 21-ratio median, after 35 calendar days, or immediately on invalid
state/package composition. Restart recovery combines a persistent consumed-
bar marker, owned positions, and same-decision-cycle deal history.

The deterministic pre-allocation checker returned `CLEAN` across 4,325 EA
registry rows and 441 cards. Manual comparison separated this distribution-
free central-to-two-tail event from the existing mean/standard-deviation,
rolling OLS residual, conditional-quantile regression, median/MAD, breakout,
and failed-break/re-entry XAU/XAG families. The opposite-leg carrier seeks a
different return driver from the directional XAU/SP500/NDX/XNG book, but Q09
alone may establish realized portfolio correlation.

## Source And G0 Record

The bounded source packet is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-QTAIL-2026/source.md`. It uses
Schweikert (2018), *Journal of Banking & Finance* 88, 44–51, DOI
`10.1016/j.jbankfin.2017.11.010`; Yaya, Vo, and Olayinka (2021), *Resources
Policy* 72, 102045, DOI `10.1016/j.resourpol.2021.102045`; and CME Group's
Gold & Silver Ratio Spread material.

Those sources support only a potentially state-dependent gold/silver
relationship and the intermarket carrier. The empirical-tail event,
parameters, CFD mapping, risk, stops, density, efficacy, neutrality, and
portfolio fit remain transparent QM hypotheses. G0 authorization is
`decisions/2026-08-09_qm5_20268_xauxag_qtail_rv_g0.md`.

## Deterministic Allocation And Q01 Evidence

- EA/slug/strategy: `QM5_20268` / `xauxag-qtail-rv` /
  `SCHWEIKERT-CME-XAUXAG-QTAILRV-2026_S03`.
- Logical symbol: `QM5_20268_XAU_XAG_QTAILRV_D1`, hosted on
  `XAUUSD.DWX` D1.
- Slots/magics: XAU slot 0 / `202680000`; XAG slot 1 / `202680001`.
- Q02 contract: `2018.07.02` through `2024.12.31`, one aggregate
  `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1` budget.
- Strict compile: `D:/QM/reports/compile/20260809_105209/summary.csv`, PASS,
  zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260809_105209/QM5_20268_xauxag-qtail-rv.compile.log`.
- Strict target build check:
  `D:/QM/reports/framework/21/build_check_20260809_105240.json`, PASS, zero
  failures and zero warnings.
- P1/Q01 artifact check:
  `D:/QM/reports/pipeline/QM5_20268/P1/P1_QM5_20268_result.json`, PASS.
- Card-schema/ML lint: PASS on intake, canonical, and build card copies.
- G0 readiness lint, build prerequisite guard, SPEC validation, and build
  guardrails: PASS.
- Symbol-scope validator: `BASKET_OK`, zero violations, manifest limited to
  XAU and XAG.
- Generated setfile header build hash:
  `076540adcffe844b2dd742f8e8d4ff8b6882c066478e1182dce781b2ccc73a31`.
- Manual smoke/backtest: none.

Artifact SHA-256 values at handoff:

| Artifact | SHA-256 |
|---|---|
| EA registry | `D58854972EFBD3AE848DC23E710CA115D48050F3E20F2E749553F49E97323A3C` |
| Magic registry | `E545AADB9E8319FECABE8D5A5B28A9201DF50D8A3B4A1C2D1A029BB5B627094C` |
| Generated magic resolver | `E65D33226B90035E1007A925FBA654BA7A1BC4C3086EF32FA53CC61437024B24` |
| Source packet | `CD053C4A7666572442F40F250985A00E1D0612E91E7E1B7FEA677C495ADAB39A` |
| MQ5 | `86B6FEFF7491D979AB9CD642CC3E5CCBA8035B2B8BD503408A4289DDA4DE5FAA` |
| EX5 | `66578635021773CDD46D5004E980633C8245A3DA51EEF90650B2C9DC6C84FEDC` |
| SPEC | `01B08F60DB320766B0F81BFCE771E2E794DFD3C8F5FBEB7A7304F3E3B43489BB` |
| Basket manifest | `F3F7C353F6442EA3648EB527DF2A9D048A76D6D8F1067D136ADE70ECE7949DD5` |
| Backtest set | `35E92F6694FC9EB4486D3762E868430D2E8C2A4D938D47588989F408DCB42407` |

## Paced Q02 Handoff

The binding `farmctl mt5-slots` sample at
`2026-08-09T10:56:40+00:00` found two executing factory terminals, T3 and T7,
against the ceiling of seven. The process inventory also displayed T_Live and
FTMO terminals outside the factory roots; they were excluded from the count
and were not changed.

The canonical pump inserted the target while this mission's final build was
being validated:

- Work item: `2b803c41-5ef5-4cf4-8b20-ce51681287bc`.
- Created: `2026-08-09T10:52:58+00:00`.
- Phase/kind: Q02 / backtest.
- Logical basket/timeframe: `QM5_20268_XAU_XAG_QTAILRV_D1` / D1.
- Host: `XAUUSD.DWX`; basket: `XAUUSD.DWX`, `XAGUSD.DWX`.
- Window: `2018.07.02` through `2024.12.31`.
- Timeout/priority: 450 minutes / `priority_track=true`.
- Initial confirmation: pending, attempt 0, unclaimed, no verdict.

The subsequent target-scoped no-mutation sweep selected zero rows because
that exact EA already had the single Q02 item above. No apply command was
issued, preserving the one-item invariant. The paced fleet owns execution.

## Commits

- `f9830a530` — source-bounded G0 decision and approved/intake cards.
- `1cb74a776` — deterministic EA-ID reservation.
- `3b99583e9` — XAU/XAG magic allocation, SPEC, and resolver generation.
- `254115e89` — final restart-safe EA source, compiled EX5, manifest, build
  card, and fixed-risk setfile.

## Safety Boundary

- No manual backtest, smoke test, dispatch tick, or downstream phase was run.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled; T_Live was not changed.
- The portfolio gate and T_Live manifest were not touched.
- Unrelated pre-existing and concurrent working-tree edits were preserved and
  excluded from this mission's scoped commits.
