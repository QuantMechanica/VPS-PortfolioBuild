# QM5_41310 governed compile — CPU ceiling stop

Date: 2026-09-05 (Europe/Berlin)  
Branch: `agents/board-advisor`  
Outcome: `COMPILE_OK`; smoke and Q02 handoff deferred at the binding CPU ceiling

## Diversity choice

The canonical farm scorer and shared build-task claim guard selected
`QM5_41310_wti-mvnratio-tr` as the highest-priority claimable build row. Its
explicit priority score was `1010.95`; no live build dispatch, sibling build,
or open work item existed for the EA. The approved card specifies a structural
monthly `XTIUSD.DWX` D1 sleeve, approximately six completed positions per
post-warm-up year, one consumed attempt per broker month, and fixed-risk
backtests. It adds direct crude exposure outside the certified
XAU/SP500/NDX/XNG carrier set.

The rule is the strict raw von Neumann successive-difference ratio gate
`eta < 2.0` on twenty completed monthly WTI log returns, followed by the sign
of the newest twelve-month return. The card cites the official NIST method,
von Neumann (1941), and Moskowitz, Ooi, and Pedersen (2012). It explicitly
labels the exact conjunction as unproven QuantMechanica synthesis. No ML,
trained artifact, banned indicator, or external runtime feed is used.

## Governed coordination and compile

- Existing build task: `6e00d285-742e-4d69-aa06-802aaf59f126`.
- Governed `COMPILE_EA` item:
  `d9bbb5ae-03b7-4021-bd0a-3955ee7abd4d`.
- Enqueue was bound to the exact open build task; it created one held compile
  row and no sibling row.
- The release dry-run matched expected and actual MQ5 SHA-256
  `51f26c5e3668bb6b0d942801d7041936cd0baa56196ab0f64f3eb86b01e35d4d`.
- The exact one-item release used the factory mutation lock and an online,
  identity-checked backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_compile_wave_20260905T142022Z_d6784684.sqlite`,
  SHA-256
  `25c5b7669b26e2fabacde17808ede056ad698eaced8374509426ddbfe1f6191b`.
- Resident worker T9 claimed the row and completed it as
  `done / COMPILE_OK`; the claim was released normally.
- `build_check.result=PASS`, failures `0`, warnings `0`.
- `compile_one.result=PASS`, errors `0`, warnings `0`.
- The deterministic reference suite passed `12/12`, and the seven-section
  SPEC validator passed `1/1`.

Compile evidence:

`D:\QM\reports\work_items\d9bbb5ae-03b7-4021-bd0a-3955ee7abd4d\QM5_41310\COMPILE_EA\compile_evidence.json`

Compile-evidence SHA-256:
`1c3619524db5d9e6382f9e8b80f1f6eaaf69d730160f30e09b1733ef6cab8fc1`.

## Artifact bindings

| Artifact | SHA-256 |
|---|---|
| MQ5 | `51f26c5e3668bb6b0d942801d7041936cd0baa56196ab0f64f3eb86b01e35d4d` |
| EX5 | `23bf39e7b18b84a50838f2e0c1e546c18d4ce5c4055ccd747d45189159520361` |
| Regenerated backtest setfile | `635c343fead29f73ee6f69cd0b44d4987e79867164a16419fc7554ae00f684ff` |
| SPEC | `b635e3a65f14e5ab6a13df0f9ee93c2fa1d86addb7a4dfdc75cdaf6e55970df1` |
| Repo approved card | `c0881d8c68a0292ce01472a19172b3405a5feb3e38ca106945229a8e8770c470` |
| Farm task approved-card snapshot | `6a4f679c44514d00824eee2c3cd6724f63b9ab9d275b4fca5e4af2564265720f` |

The two approved-card copies differ only in informational R1 normalization
and G0 summary prose; the mechanical contract, identity, parameters, symbol,
timeframe, and R2-R4 rules are unchanged. The compiled source is byte-identical
to the source-bound release preimage.

The regenerated setfile is the single authorized
`QM5_41310_wti-mvnratio-tr_XTIUSD.DWX_D1_backtest.set`; it retains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, D1, and the locked
card parameters.

## Binding capacity stop

The mandatory post-compile five-sample whole-host window measured
`83.41%, 81.85%, 99.61%, 73.35%, 60.56%` (average `79.76%`, maximum
`99.61%`). The `97%` paced-fleet ceiling fired on the maximum sample.

Per the mission contract, work stopped immediately before `run_smoke.ps1` and
before `farmctl record-build`. No smoke/tester process was launched for this
EA, no build result was recorded, and no Q02 work item exists. The build task
therefore remains `pending`; the completed source-bound `COMPILE_OK` row is the
durable continuation point. A future paced worker should recheck artifact
hashes and capacity, make exactly one governed smoke attempt, then record the
build to create the single Q02 canary.

## Safety boundary

No portfolio gate, certification state, deploy manifest, T_Live manifest, or
T_Live file was touched. No terminal was started, stopped, or repurposed by
this unit, and AutoTrading was not toggled.
