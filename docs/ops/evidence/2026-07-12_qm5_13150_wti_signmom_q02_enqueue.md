# QM5_13150 WTI Return-Sign Momentum - Q02 Enqueue Evidence

**Date:** 2026-07-12

**Branch:** agents/board-advisor

**EA:** QM5_13150_wti-signmom

**Status:** Q01 PASS; one XTIUSD.DWX Q02 item pending

## Edge And Evidence Boundary

The edge is the fixed-threshold return signal momentum rule in Papailias, Liu,
and Thomakos (2021), "Return Signal Momentum," *Journal of Banking & Finance*
124, article 106063.

DOI and journal record:
https://doi.org/10.1016/j.jbankfin.2021.106063

Complete peer-reviewed accepted manuscript:
https://pureadmin.qub.ac.uk/ws/files/229452162/RSM_011220.pdf

The complete 83-page manuscript and Appendices A-I were reviewed. WTI is an
explicit source instrument. The source rule converts each of the prior twelve
completed monthly returns to a binary sign, averages those signs, buys at a
fixed positive-sign fraction of at least 0.40, sells below it, and renews
monthly.

The individual WTI appendix is deliberately carried with both favorable and
adverse evidence. Tables G.1 and G.2 report higher WTI RSM0.4 mean return and
Sharpe ratio than conventional TSM in the source sample; Table G.3 reports a
larger maximum drawdown. No source performance, cost, drawdown, or correlation
number is imported as evidence for the DWX carrier. Q02 owns the first economic
evidence for this translation.

## Locked Mechanical Baseline

On the first tradable XTIUSD.DWX D1 bar of broker month `t`:

1. Reconstruct the final completed D1 close in each of the thirteen completed
   broker months ending at `t-1`.
2. Convert the twelve monthly returns to one for non-negative and zero for
   negative, then calculate `positive_count / 12`.
3. Buy at or above 0.40; sell below 0.40.
4. Allocate `RISK_FIXED=1000`, attach a frozen ATR(20) times 3.5 hard stop,
   and set no take-profit.
5. Close on the next broker-month transition or after 35 days. Position and
   entry-deal history prevent a stopped position or restart from entering the
   same broker month again.

Expected density is approximately twelve completed positions/year after the
thirteen-month warm-up. The binding Q02 floor is five trades/year.

## Non-Duplicate Decision

The pre-allocation checker found no exact slug, strategy-ID, or registry
duplicate. It returned one fuzzy same-source card:
`QM5_13116_xng-signmom`. That natural-gas carrier is explicitly linked as the
same anomaly on a different source instrument; no renamed statistical claim is
made.

For WTI, the new statistic is not the existing TSMOM family. Existing 6/9/12
month WTI TSMOM rules take the sign of one cumulative start-to-end return.
QM5_13150 counts the signs of twelve separate completed monthly returns and
discards their magnitudes. It is also not the WTI daily moving-average,
partial-moment, event, calendar, carry, breakout, ratio, reversal, or RSI logic.
Manual verdict:
`FUZZY_SAME_SOURCE_SYMBOL_EXTENSION_MANUALLY_RESOLVED`.

## Identity And Registry Evidence

- EA reservation:
  `13150,wti-signmom,PAPAILIAS-RSM-2021_XTI_S02,active`.
- Magic slot 0: XTIUSD.DWX to `131500000`.
- The committed resolver contains the mapping and retains 14,891 rows.
- Committed magic-registry SHA256:
  `815945957F6F5142AA1B1FF413769ED633CF2108DFCD03707A8C1BEF1BCF4831`.
- Committed resolver SHA256:
  `7FBAF4564418F393DC7B8F80D7163E2B09DC73E38E9051DC038D338361337BB5`.

The shared worktree contained unrelated fleet allocations before this build.
The feature commit was assembled from clean HEAD registry blobs plus only EA
13150. The final isolated worktree disabled automatic CRLF conversion before
resolver generation; the resolver's embedded registry SHA matches the
committed LF registry exactly.

## Q01 Build Evidence

- Build commit:
  `9f0348c2298c929d954abaf3755022b2ef4ca93a`.
- Strict compile: PASS, 0 errors, 0 warnings.
- Build check: PASS, 0 failures, 0 warnings.
- Preserved compile log:
  `D:/QM/reports/compile/20260712_021050/QM5_13150_wti-signmom.compile.log`.
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260712_021057.json`.
- Card schema/G0, SPEC, build guardrails, and single-symbol scope: PASS.
- MQ5 SHA256:
  `0C038939EC0AC03AE5D76379B37FC21F15C8EB3A5BA93A3FC1331AE30310AAAC`.
- Committed EX5 SHA256:
  `C798CCDF23E0CDB05100496858B2E188DC1DE97410EE6B27EA4CC220A2169C79`.

The final strict compile and build check ran from the LF-safe isolated staged
tree. No compile or resolver claim depends on the unrelated working changes.

## Risk And Setfile Evidence

- Symbol/timeframe: XTIUSD.DWX / D1.
- Setfile:
  `framework/EAs/QM5_13150_wti-signmom/sets/QM5_13150_wti-signmom_XTIUSD.DWX_D1_backtest.set`.
- Setfile SHA256:
  `B55CA435C6BC35A3C94C9465D5B383FD75B1D5C3516CD6295520C03401CBB1FD`.
- Setfile build hash:
  `0baad49d5117aca7f14668602ef90e0b9a601e4b47b5b53bfa9f235abc3678bc`.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Friday close is disabled only for the declared monthly hold.

## Q02 Queue Evidence

- Build task: `62dcab41-07d3-42d1-994b-32e35f37e0f1`, done.
- Work item: `a88b8890-3cb2-4ec7-bff0-bc72325057dd`.
- Phase/kind: Q02 / backtest.
- Symbol/timeframe: XTIUSD.DWX / D1.
- Status at handoff: pending, attempt 0, unclaimed.
- Enqueued at: `2026-07-12T02:13:38+00:00`.
- `farmctl record-build` enqueued one item and skipped none.

No dispatch tick, worker tick, terminal launch, smoke test, or backtest was
started. No backtest CPU slot was consumed, so the backtest CPU ceiling was not
encountered; Q02 owns the first CPU-bearing validation pass.

## Safety And Kill Boundary

- Structural D1/monthly price arithmetic only; no ML or banned indicator.
- No live setfile, T_Live artifact, AutoTrading action, deploy manifest,
  T_Live manifest, portfolio gate, portfolio admission, or portfolio KPI was
  touched.
- The adverse individual-source drawdown, rolled-futures-to-continuous-CFD
  translation, financing, crude gaps, ATR overlay, costs, and unproven book
  correlation are kill risks, never waiver grounds.
- New WTI exposure and a different signal statistic make diversification
  plausible; certification and realized orthogonality remain unclaimed until
  later gates measure them.
