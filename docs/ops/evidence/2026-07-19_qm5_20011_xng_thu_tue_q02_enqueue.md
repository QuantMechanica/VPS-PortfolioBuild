# QM5_20011 XNG Thursday-Tuesday Carry - Q02 Enqueue Evidence

**Date:** 2026-07-19

**Branch:** `agents/board-advisor`

**EA:** `QM5_20011_xng-thu-tue`

**Status:** Q01 PASS; one `XNGUSD.DWX` Q02 item pending

## Edge And Source Boundary

The carrier implements the integrated Natural Gas weekly rule stated by Meek
and Hoelscher (2023), *Day-of-the-week effect: Petroleum and petroleum
products*, *Cogent Economics & Finance* 11(1), article 2213876, DOI
`10.1080/23322039.2023.2213876`. The full peer-reviewed paper is available at
https://www.econstor.eu/bitstream/10419/304091/1/10.1080_23322039.2023.2213876.pdf.
Section 4 prescribes one long package from Thursday close through Tuesday
close after reporting positive Natural Gas Monday/Tuesday effects and a
negative Thursday effect.

On Darwinex D1 bars, the executable mapping is Friday open through Wednesday
open. The EA permits only the first tradable tick inside a locked five-minute
opening grace, persists the weekly decision before news gating, holds over the
weekend, and exits on Wednesday or the next tradable D1 bar. Deal-history
uncertainty consumes the weekly decision before failing closed, preventing a
restart-dependent recovery entry. A frozen `3.5 * ATR(20)` hard stop and
seven-day stale guard are deterministic V5 risk overlays; they are not claims
from the paper.

## Non-Duplicate Decision

Tracked card, EA and setfile searches found no exact Thursday-close through
Tuesday-close XNG package. The mechanic is materially different from certified
`QM5_12567_cum-rsi2-commodity`: fixed unconditional weekly calendar carry
versus an SMA(200)-conditioned cumulative-RSI(2) pullback with RSI/time exits
and normal Friday flattening.

`KNOWN_RETURN_WINDOW_OVERLAP` is explicit. The package contains the Monday-long
window sampled by pending `QM5_12806` and the Tuesday-long window sampled by
pending `QM5_12818`. Its incremental exposure is Friday/weekend plus the
persistent multi-day lifecycle. This build makes no claim of positive
expectancy or decorrelation from those pending siblings before testing.

## Identity And Q01 Evidence

- EA reservation: `QM5_20011`, strategy
  `MEEK-HOELSCHER-XNG-DOW-2023_S03`.
- Magic slot 0: `XNGUSD.DWX` to `200110000`.
- Resolver retains 14,945 rows and embeds the current magic-registry SHA256
  `A96CC58344AF54AB86CC64953F8ECDE9D249C101AA905FEAE636242CCF052467`.
  Strict regeneration retained QM5_20011 and separately reported the
  pre-existing missing EA directories for IDs 1001, 1015 and 1016; those
  unrelated registry records were not changed.
- Build/card commits carrying this work include `05a362ccb`, `ad1280715`,
  `6fceabafd`, `1cf9bbcae`, `96e2764ab`, `8c4c49a3e`, `64fbdc39a` and
  `20a822d70`.
- Final strict compile: PASS, 0 errors, 0 warnings; log
  `C:/QM/repo/framework/build/compile/20260719_204002/QM5_20011_xng-thu-tue.compile.log`.
- Final build check: PASS, 0 failures, 0 warnings; report
  `D:/QM/reports/framework/21/build_check_20260719_203930.json`.
- G0 card lint, SPEC validation and build guardrails: PASS.
- Independent semantic review: PASS after late-attach, news-restart and
  history-uncertainty paths were made deterministic.
- MQ5 SHA256:
  `E2D73538FB38E51B81167FDE3995895F4DBC49D2D1C800D121A496FB7D553464`.
- EX5 SHA256:
  `58F5B2ACEC76CE584E6F55B3E8A4441A81D9685F538CEF6C8075E4E9DA37D625`.

## Risk And Q02 Queue Evidence

- Setfile:
  `framework/EAs/QM5_20011_xng-thu-tue/sets/QM5_20011_xng-thu-tue_XNGUSD.DWX_D1_backtest.set`.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Setfile build hash:
  `9fe85cdecb27d9bd81205ee6653b2f3b2699d9b6fe47cc5a4768301f4e7b8f85`.
- Build task `dfa80ef0-0aa0-4ab5-bb46-a95b59b32157`: done.
- Q02 work item `aa33ca98-bc8a-4015-abc7-24f3f6e5b2ab`: pending,
  attempt 0, unclaimed, `XNGUSD.DWX` D1.
- Enqueued at `2026-07-19T20:37:42+00:00` by `farmctl record-build`;
  one item enqueued and none skipped.

The paced-fleet scan showed the MT5 tester CPU ceiling already occupied. Smoke
was recorded as `deferred_p2_smoke`; no dispatch tick, worker tick, terminal
launch, tester run, optimization or backtest was started by this mission.

## Safety And Falsification Boundary

- Structural broker-calendar and ATR logic only; no banned indicator or ML.
- No live setfile, `T_Live` artifact, AutoTrading action, deploy manifest,
  T_Live manifest, portfolio gate, portfolio admission or KPI was touched.
- The source uses energy futures while this build uses a continuous Darwinex
  Natural Gas CFD plus deterministic V5 risk/execution overlays. Basis,
  weekday alignment, costs, weekend gaps, expectancy, drawdown and realized
  correlation to the certified book remain unproven kill risks for Q02 and
  later gates.
