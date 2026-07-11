# QM5_13134 Energy Variance-Ratio Momentum — Q02 Enqueue Evidence

**Date:** 2026-07-11
**Branch:** `agents/board-advisor`
**EA:** `QM5_13134_energy-vr-mom`
**Strategy ID:** `MEHLITZ-AUER-MEM-2024_XTI_S01`

## Outcome

A new low-frequency WTI structural sleeve was carded, allocated, built, and
left pending in Q02. The EA applies the published monthly `R1-q2`
memory-enhanced momentum rule: continue the latest WTI monthly return when a
q=2 robust variance-ratio test shows significant persistence, reverse it on
significant anti-persistence, and remain flat when the test is insignificant.

This is new XTI exposure for a certified book currently concentrated in
XAU/SP500/NDX/XNG. Portfolio decorrelation is a Q09 measurement, not a build
claim.

## Source And Card Evidence

- Canonical source: Mehlitz and Auer (2024), "Memory-enhanced momentum in
  commodity futures markets," *The European Journal of Finance* 30(8),
  773-802, DOI `10.1080/1351847X.2023.2220118`.
- Open complete precursor: Mehlitz (2021) doctoral thesis, Chapter 3 pp. 51-74
  and Appendix C pp. 110-113.
- Source packet:
  `strategy-seeds/sources/MEHLITZ-AUER-MEM-2024/source.md`.
- Card of record: `strategy-seeds/cards/energy-vr-mom_card.md`.
- G0: R1-R4 PASS under the OWNER mission directive.
- Pre-allocation dedup: no exact slug or strategy-ID collision. Manual review
  cleared the existing weekly persistence counter, the generic Chan momentum
  card, and two common-`energy-*` fuzzy matches as different mechanics.

## Locked Mechanic

1. Group completed XTI D1 bars by broker month and retain each month-end close.
2. Form the latest 32 chronological monthly log returns.
3. Compute `VR(2) = 1 + rho_hat(1)` and the source's
   heteroskedasticity-robust Lo-MacKinlay standard error.
4. Require `abs(z) > 1.64485362695147` (two-sided 10%).
5. Continue the latest return for significant persistence and reverse it for
   significant anti-persistence.
6. Enter at most once per broker month and renew at the next month transition.
7. Use a frozen D1 `ATR(20) * 3.0` hard stop and V5 fixed stop-risk sizing.

D1 month-end grouping is required because `.DWX` custom-symbol tests do not
reliably expose native MN1 bars. It preserves monthly observations and changes
no source signal.

## Identity And Registry Evidence

- EA registry:
  `13134,energy-vr-mom,MEHLITZ-AUER-MEM-2024_XTI_S01,active`.
- Magic slot 0: `XTIUSD.DWX -> 131340000`.
- `QM_MagicResolver.mqh` was regenerated with 14,849 retained rows and contains
  `131340000`.
- Resolver SHA256:
  `8026C8163EC6A39ADF8ED1EA1B2D1DB59CA4E988AD100196CC06C2B05F136D95`.

The resolver retained the repository's three pre-existing missing-directory
warnings for IDs 1001, 1015, and 1016; no 13134 defect remained.

## Q01 Build Evidence

- EA source:
  `framework/EAs/QM5_13134_energy-vr-mom/QM5_13134_energy-vr-mom.mq5`.
- Compiled artifact:
  `framework/EAs/QM5_13134_energy-vr-mom/QM5_13134_energy-vr-mom.ex5`.
- Strict compile: PASS, 0 errors, 0 compiler warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260711_062803/QM5_13134_energy-vr-mom.compile.log`.
- Build check: PASS, 0 failures, 0 warnings.
- Build report:
  `D:/QM/reports/framework/21/build_check_20260711_063405.json`.
- Targeted SPEC validator: PASS.
- MQ5 SHA256:
  `F6A428BA3D13701ECA542CD97170DD8C1BCF1AA9DEABC915B6CB4AD2F7994741`.
- EX5 SHA256:
  `E7A2447353BEE40C44EEFF34B3F0314D7806F7BA80D93F854C2AD22B5A1BB367`.

## Risk And Setfile Evidence

- Symbol: `XTIUSD.DWX`, D1.
- Setfile:
  `framework/EAs/QM5_13134_energy-vr-mom/sets/QM5_13134_energy-vr-mom_XTIUSD.DWX_D1_backtest.set`.
- Setfile SHA256:
  `8FDA63772648177E8B92E4256ED21E7486F2F23A705F6E79BAC24D54E44F99DF`.
- Setfile build hash:
  `a1cfee5b99f41a41fb20c11e9dbd4458c59c6d299533a3155bcffe24efa7db51`.
- `RISK_FIXED=1000`.
- `RISK_PERCENT=0`.
- `PORTFOLIO_WEIGHT=1`.
- Friday close is disabled only for the source-aligned monthly hold.

## Q02 Queue Evidence

- Build task: `ef83d2dc-a9bb-4821-9ffd-4c18d47c9897` (`done`).
- Work item: `3b9928b5-3fdc-4866-b9c0-b73556e40e13`.
- Phase: `Q02`.
- Kind: `backtest`.
- Symbol: `XTIUSD.DWX`.
- Status at verification: `pending`.
- Attempt count: `0`.
- Claimed by: none.
- Enqueued at: `2026-07-11T06:31:16+00:00`.
- Queue path: `record_build_result.auto_q02`.

No manual smoke, tester, terminal launch, dispatch tick, or worker tick was
started. This work consumed no backtest CPU and left paced Q02 dispatch intact.

## Safety Boundary

- No T_Live path changed.
- No AutoTrading setting changed.
- No live setfile or deploy manifest was created.
- No portfolio gate, gate threshold, portfolio KPI, admission file, or T_Live
  manifest was changed.
