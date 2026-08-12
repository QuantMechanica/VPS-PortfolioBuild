# QM5_20234 XAU/XAG RSJ Build And CPU-Ceiling Handoff

Date: 2026-08-06 (Europe/Berlin)

Branch: `agents/board-advisor`

Status: Q01 PASS; Q02 eligible but not enqueued because the CPU ceiling was
already exceeded

## Outcome

One new structural, low-frequency commodity basket was researched, approved,
allocated, built, committed, and strictly validated:

- EA: `QM5_20234_xauxag-rsj`.
- Logical carrier: `QM5_20234_XAU_XAG_RSJ_D1`, hosted on `XAUUSD.DWX` D1 and
  trading registered `XAUUSD.DWX` and `XAGUSD.DWX` legs.
- Mechanic: at each broker-month transition, calculate normalized relative
  signed jump from synchronized simple D1 returns ending in the immediately
  preceding complete month. Buy the lower-RSJ metal and short the higher-RSJ
  metal. Ties, invalid denominators, or fewer than 15 common observations
  consume the month and remain flat.
- Lifecycle: monthly close and rerank, 35-day stale guard, persistent attempt
  state, same-month deal guard, orphan cleanup, and second-leg rollback.
- Risk: one `RISK_FIXED=1000` package split into equal stop-risk halves, with
  `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, and `3.5 * ATR(20,D1)` hard stops.

No Q02 row was inserted. The targeted dry run selected exactly one priority
item, but the mandatory pre-apply scan found 10 active factory terminals
against the binding ceiling of 7. The mission's stop condition therefore
precluded the apply step.

## Source And Non-Duplicate Boundary

The governed source is Kiss and Ferreira Batista Martins (2025), "Good
Volatility, Bad Volatility and the Cross Section of Commodity Returns,"
*Finance Research Letters* 86 Part D, article 108656, DOI
`10.1016/j.frl.2025.108656`. The durable packet is
`strategy-seeds/sources/KISS-RSJ-2025/source.md`, and the carrier approval is
`decisions/2026-08-06_qm5_20234_xauxag_rsj_g0.md`.

The paper reports a cross-sectional commodity-futures RSJ relation; it does
not test this two-metal CFD carrier. The existing energy RSJ sibling's adverse
Q02 result was disclosed during G0 and no source or sibling efficacy,
correlation, or cost result transfers.

The deterministic pre-allocation check found no exact slug or strategy-ID
identity across 4,291 registry rows and 407 cards. Manual review resolved the
three fuzzy relatives (`cme-xauxag-brk`, `energy-rsj`, and `xauxag-rev18`):
this candidate uses a normalized signed-semivariance cross-sectional rank,
not a ratio breakout, energy carrier, or fixed-horizon ratio-reversion signal.

## Allocation And Commit Chain

- Source packet and durable G0 decision: `1269f26c0`.
- Canonical card and EA-ID allocation: `f4169cf70`.
- Magic rows, regenerated resolver, EA source/binary, specification, basket
  manifest, governed card copies, and fixed-risk setfile: `9e6be25cf`.

The magic allocation is `202340000` for `XAUUSD.DWX` slot 0 and `202340001`
for `XAGUSD.DWX` slot 1.

## Q01 Evidence

- Card extraction schema lint: PASS.
- G0 card lint: PASS.
- Seven-section SPEC validator: PASS.
- Strict MetaEditor compile: PASS, zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260805_233838/QM5_20234_xauxag-rsj.compile.log`.
- Compile summary: `D:/QM/reports/compile/20260805_233838/summary.csv`.
- Strict V5 build check: PASS, zero failures and zero warnings:
  `D:/QM/reports/framework/21/build_check_20260805_233838.json`.
- EX5 size: 375,974 bytes.
- Setfile build hash:
  `5960ce7cc374d5934fc30355e0783f19da6a21cecaae7d7992e677dd8ad62353`.

Artifact SHA-256 values:

| Artifact | SHA-256 |
|---|---|
| Source packet | `87679A706DA34734A845C5BC932DEB75603B3B9B03D56BC88A8CFEC779ACACC8` |
| G0 decision | `0B96F94EA3C6F10FE37290C4DED32E8388F41F8F3CBE824FE30D7352A79BF544` |
| Canonical/approved/build card | `2962ED925CA70C2B6620D767DA81FD124832B0E91A0D6DE7D2B765A1EE50696D` |
| MQ5 | `8FBD109B8E96F7657F120C64BB41DADDAA1EB969FF5E3A1F397017DC1A1E1055` |
| EX5 | `FA35D44BBDC1DD80E5F0D6146D4637CA1223B5A01F925DECCBA9558C0AE2B48F` |
| SPEC | `AFDDB93BC69178BEA084C47F309D34CEB6339A309F8323704E6258F988E31105` |
| Basket manifest | `4C1B93113D7F59C23BFDCDC78ADBD4C1CBBC6794BBA906C100864C2FCA43079D` |
| Backtest set | `F94BE16A6399C9CAE94003F435F6125B3BC0DBF769B79346E636DDB05B2A0637` |

## Q02 Dry Run And CPU-Ceiling Evidence

The exact no-mutation dry run was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20234 --symbols QM5_20234_XAU_XAG_RSJ_D1 --max-part2-per-run 0

It selected one `never_tested` priority item and no stranded/recovery item.
The queue had 1,517 pending rows against its separate 7,000-row ceiling, and
there was no existing work item for `QM5_20234`.

At `2026-08-05T23:41:01.5551480Z`, a read-only process scan anchored exactly
to `D:\QM\mt5\T1..T10\terminal64.exe` and excluding `T_Live` found all ten
factory terminals active: T1 through T10. Because 10 is at or above the
binding CPU ceiling of 7, the apply command was not run. No work-item ID
exists and no manual dispatch occurred.

## Safety Boundary

- No manual backtest, dispatch tick, terminal reservation, or tester launch
  was run.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled.
- The portfolio gate and T_Live manifest were not touched.
- Existing unrelated working-tree changes were preserved and excluded from
  every task commit.
