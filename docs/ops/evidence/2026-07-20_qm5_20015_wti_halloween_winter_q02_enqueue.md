# QM5_20015 WTI Winter Season - Q02 Enqueue Evidence

**Date:** 2026-07-20  
**Branch:** `agents/board-advisor`  
**EA:** `QM5_20015_wti-halloween-winter`  
**Status:** Q01 PASS; one `XTIUSD.DWX` D1 Q02 item pending

## Edge and source boundary

The carrier implements the West Texas alternative-two winter interval in
Burakov, Freidin and Solovyev (2018), "The Halloween Effect on Energy
Markets: An Empirical Study," *International Journal of Energy Economics and
Policy* 8(2), 121-126. The official article and complete publisher-hosted text
are available at:

- https://www.econjournals.com/index.php/ijeep/article/view/6092
- https://www.econjournals.com/index.php/ijeep/article/download/6092/3608/15549

The authors use monthly IMF energy prices over 1985-2016. Section 3 defines
alternative two from the final October close through the following final May
close. For West Texas, Table 2 reports average winter return `16.65%` versus
summer `-5.3%`, with winter higher in 23 of 32 years (`72%`); Table 3 reports
preferred Wilcoxon `p=0.0031`.

The paper has disclosed editorial inconsistencies: Table 2 repeats the
alternative-one month captions and the abstract reverses the higher-return
direction. The methods, WTI rows, discussion and conclusion agree on the
November-May winter leg. The card locks that explicit definition.

The source tests one continuous seasonal hold. V5 segments it into seven
monthly fixed-risk packages: long on the first tradable D1 bar of each
November-May month, close/reopen at the next in-season month boundary, flatten
at the June boundary, and remain flat June-October. Monthly renewal, the
terminal-persistent no-retry marker, `4.0 * ATR(20)` hard stop, 35-day stale
guard and spread cap are disclosed QM adaptations, not source-authored results.

## Non-duplicate decision

Repository and source searches found no unconditional WTI November-May long / 
June-October flat carrier.

- `QM5_20008_wti-month-ch3` is symmetric price-channel continuation.
- `QM5_12576_eia-wti-season` uses different months plus SMA/ROC filters and a
  summer short leg.
- `QM5_12726_wti-nov-fade` shorts November only.
- `QM5_13107_wti-juldec-short` is a weekly July-November short window.
- `QM5_12813_eia-energy-switch` is an XTI/XNG seasonal basket.
- Existing Halloween EAs trade equity indices, not WTI.

The exact WTI carrier/mechanic is new. Its realized correlation to the
certified index/metal/XNG book remains unproven and must be measured later.

## Identity and Q01 evidence

- EA reservation: `QM5_20015`, strategy
  `BURAKOV-WTI-HALLOWEEN-2018_S01`.
- Magic slot 0: `XTIUSD.DWX` to `200150000`.
- Resolver retains 14,952 rows and embeds magic-registry SHA256
  `9BB9BE4D7175218E88DC91E279B3D8266F98768AE1E9CCA4409A95FD511A53D0`.
- Strict compile: PASS, 0 errors, 0 warnings; log
  `framework/build/compile/20260720_071405/QM5_20015_wti-halloween-winter.compile.log`.
- Strict build check: PASS, 0 failures, 0 warnings; report
  `D:/QM/reports/framework/21/build_check_20260720_071439.json`.
- SPEC, approved-card preflight, symbol scope, magic and setfile guardrails:
  PASS.
- MQ5 SHA256:
  `CFA6ED60B604A06D8262194B474D41C1B04326FB37AE0909A7ABF4B6FA1FDA04`.
- EX5 SHA256:
  `CCF72804E35DFD75BF0683EF0AE9101EB1F501B59B5F0CA2CD933FDBB5A95AEE`.

## Risk and Q02 queue evidence

- Setfile:
  `framework/EAs/QM5_20015_wti-halloween-winter/sets/QM5_20015_wti-halloween-winter_XTIUSD.DWX_D1_backtest.set`.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Setfile build hash:
  `1e338a6fbec61807fccf08c3728fcb64d0fee5ec52da8dfb18a723d925d8bb6d`.
- Build task `5f18eea1-3d7e-4787-ba31-b823373c7569`: done.
- Q02 work item `2c022cc5-f7d7-480b-8d87-4d6aa8f475ff`: pending,
  attempt 0, unclaimed, `XTIUSD.DWX` D1.
- Enqueued at `2026-07-20T07:18:41+00:00` by `farmctl record-build`;
  one item enqueued and none skipped.

The paced-fleet scan showed six active pipeline terminals and six
`metatester64` processes. Smoke was recorded as `deferred_p2_smoke`; no
dispatch tick, worker tick, terminal launch, tester run, optimization or
backtest was started by this mission.

## Safety and falsification boundary

- Structural calendar arithmetic and ATR risk only; no ML or banned indicator.
- No live setfile, T_Live artifact/action, AutoTrading action, deploy manifest,
  T_Live manifest, portfolio admission, KPI or portfolio gate was touched.
- The source uses an IMF West Texas monthly series, while the build uses a
  continuous Darwinex WTI CFD. Transfer, costs, financing, gaps, post-2016
  persistence, monthly risk renewal and realized book correlation are unproven
  kill risks. Q02 and later gates—not G0/Q01—must measure them.
