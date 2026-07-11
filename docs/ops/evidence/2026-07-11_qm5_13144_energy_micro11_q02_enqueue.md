# QM5_13144 Energy Microscopic-Momentum Rank - Q02 Enqueue Evidence

**Date:** 2026-07-11

**Branch:** agents/board-advisor

**EA:** QM5_13144_energy-micro11

**Status:** Q01 PASS; one logical Q02 basket pending

## Edge And Evidence Boundary

The new edge is the isolated 11-to-10-month commodity return slice from John
Hua Fan's 2014 Griffith University PhD thesis, *Momentum Investing in Commodity
Futures*, complete Chapter 3, "Microscopic Momentum," pp. 62-106. The related
Bianchi, Drew, and Fan working paper is SSRN 2827237.

The source ranks a broad commodity-futures universe on one distant historical
month, buys winners, shorts losers, and holds for one month. WTI and natural gas
are explicit source instruments. QM5_13144 narrows that hypothesis to a
two-name continuous-CFD falsification; no source return, significance,
drawdown, cost, or correlation number is imported. The exact rule is complete
institutional thesis/working-paper evidence rather than a peer-reviewed journal
result, which remains a Q02 kill risk.

Primary source:
https://research-repository.griffith.edu.au/server/api/core/bitstreams/5b940466-77cf-5789-bdf3-14987ca5a12a/content

Related record: https://ssrn.com/abstract=2827237

## Locked Mechanical Baseline

On the first tradable XTIUSD.DWX D1 bar of broker month t:

1. For XTIUSD.DWX and XNGUSD.DWX, select the last completed D1 close before
   each t-11 and t-10 broker-month boundary.
2. Compute `log(close(t-10) / close(t-11))` for each leg.
3. Buy the higher-return leg and short the lower-return leg; reject ties,
   missing/stale endpoints, invalid arithmetic, or invalid execution metadata.
4. Allocate one `RISK_FIXED=1000` package as equal fixed-risk halves with
   independent frozen ATR(20) times 3.5 broker hard stops.
5. Close at the next monthly transition or after 35 days; immediately flatten
   invalid composition or an orphan leg and prohibit same-month re-entry.

## Non-Duplicate Decision

The canonical pre-allocation check returned CLEAN across 4,030 registry rows
and 332 cards. The post-allocation exact match is QM5_13144's own reservation.
Manual signal/input/window/direction review found no duplicate:

- QM5_12567 is a two-day RSI pullback, not a distant return rank.
- QM5_12603 is standalone WTI trailing-12-month return sign.
- QM5_12733 uses recent cumulative cross-energy momentum.
- QM5_13115 averages matching calendar-month returns across prior years.
- QM5_13120 interacts cumulative 12- and 18-month ranks.
- QM5_13121 combines cumulative 12-month rank with a trend mean.
- QM5_13126 combines cumulative momentum with broker carry.

Verdict: `CLEAN_PRE_ALLOCATION; POST_ALLOCATION_EXACT_MATCH_IS_SELF`.

## Identity And Registry Evidence

- EA reservation:
  `13144,energy-micro11,FAN-MICROMOM-2014_XTI_XNG_S01,active`.
- Magic slot 0: XTIUSD.DWX to `131440000`.
- Magic slot 1: XNGUSD.DWX to `131440001`.
- The clean staged resolver retains 14,881 rows and both new magic values.
- Clean magic-registry SHA256:
  `2C9A265525C9F71DE0982E76643725F1F9F075312A0CABFFE9463D504FAE4EA8`.
- Resolver SHA256:
  `7BB755B24FD91EB56C002B0C426C05360D4BF7A49FCCD1A576BDB1D2D514AD16`.

The staged resolver preserves the pre-existing QM5_13122 binding and drops
only historical missing-directory IDs 1001, 1015, and 1016. Unrelated dirty
fleet allocations were excluded from build commit
`b13120dadb06386adbf26142b9752da32204e9a9`.

## Q01 Build Evidence

- Build commit: `b13120dadb06386adbf26142b9752da32204e9a9`.
- Strict clean-staged-resolver compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `D:/QM/reports/compile/20260711_155605/QM5_13144_energy-micro11.compile.log`.
- Build check: PASS, 0 failures, 0 warnings.
- Build report:
  `D:/QM/reports/framework/21/build_check_20260711_155510.json`.
- Card schema lint, G0 lint, SPEC validator, build guard, basket symbol-scope
  validator, and setfile/source hash check: PASS.
- MQ5 SHA256:
  `37DAA9C3945D480938888BBB4DBD4064798BF2D4EDF45262B01F5E9186FEB6B6`.
- EX5 SHA256:
  `9FDFC46DF9424BA7BCB8E3639E556AB7F94A5023EA7974FED68073D577A4337E`.

## Risk And Setfile Evidence

- Logical symbol: `QM5_13144_XTI_XNG_MICRO11_D1`; host XTIUSD.DWX, D1.
- Setfile:
  `framework/EAs/QM5_13144_energy-micro11/sets/QM5_13144_energy-micro11_QM5_13144_XTI_XNG_MICRO11_D1_D1_backtest.set`.
- Setfile SHA256:
  `CF0D7787E67CCA4282765F1D97E8534C874C1C7B7042A4CFB94118F1F6D0E8BB`.
- Setfile build/source hash:
  `37daa9c3945d480938888bbb4dbd4064798bf2d4edf45262b01f5e9186feb6b6`.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Friday close is disabled only for the source-aligned monthly hold.

## Q02 Queue Evidence

- Build task: `00dbacdc-b4db-406f-9efe-5903b9f18165`, done.
- Work item: `c9aacee9-af30-40f6-b0f7-1b6ad2960a9b`.
- Phase/kind: Q02 / backtest.
- Logical basket: `QM5_13144_XTI_XNG_MICRO11_D1`.
- Host/timeframe: XTIUSD.DWX / D1.
- Status at handoff: pending, attempt 0, unclaimed.
- `farmctl record-build` enqueued one item and skipped none.

No dispatch tick, worker tick, terminal launch, smoke test, or backtest was
started by this work. Q02 owns the first CPU-bearing validation pass.

## Safety Boundary

- Structural D1/monthly logic only; no ML or banned indicator.
- No live setfile, T_Live artifact, AutoTrading action, deploy manifest,
  T_Live manifest, portfolio gate, portfolio admission, or portfolio KPI was
  touched.
- Opposite directions and equal fixed-risk halves are implementation-level
  common-direction reduction, not a claim of dollar, beta, volatility,
  factor, or realized market neutrality.
- Realized book orthogonality remains unclaimed until the later portfolio gate.
