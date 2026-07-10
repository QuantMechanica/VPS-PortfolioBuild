# QM5_13109 XNG February-June Trading-Time Q02 Enqueue

Date: 2026-07-10  
Branch: agents/board-advisor

## Outcome

One new structural natural-gas sleeve was carded, built, compiled, and
enqueued:

- EA: QM5_13109_xng-febjun-long.
- Signal: XNGUSD.DWX D1 first-tradable-bar weekly long tranches during
  February-May, with Friday flatten before the source's June offset month.
- Q02 work item: 5a8bd70d-08ef-4772-a029-a527dfeb2f6e.
- Handoff: pending, unclaimed, XNGUSD.DWX, D1.
- Risk: RISK_FIXED=1000, RISK_PERCENT=0, PORTFOLIO_WEIGHT=1.
- Magic: 131090000, slot 0.

No manual MT5 run was launched. At the CPU guard scan, T1/T3/T6/T7/T8 were
active and seven paced terminal workers covered T1/T2/T3/T4/T6/T7/T8. The
build therefore used deferred_p2_smoke and handed the setfile to Q02 without
competing with factory automation.

## Source And Mechanization

Primary source: Ewald, C.-O.; Haugom, E.; Lien, G.; Stordal, S.; and Wu, Y.
(2022), "Trading time seasonality in commodity futures: An opportunity for
arbitrage in the natural gas and crude oil markets?" *Energy Economics* 115,
106324, https://doi.org/10.1016/j.eneco.2022.106324. Full open version:
https://eprints.gla.ac.uk/281581/1/281581.pdf.

The full paper was reviewed. Its natural-gas rule buys matched-maturity futures
in February and sells them in June after finding February trading-month lows
and June highs. The continuous CFD cannot reproduce a futures maturity matrix,
so the card explicitly tests a directional carrier: non-overlapping weekly
long tranches from February through May, flattened on Friday, with a 20-day
ATR hard stop and seven-day stale guard.

The paper reports fragility in later natural-gas samples and a large 2008
contribution. Those limitations are preserved as kill risks; no source
performance is imported as a forecast.

## Non-Duplicate Decision

Before allocation, repository dedup produced one fuzzy hit against
QM5_13107_wti-juldec-short because both cards are source-defined siblings.
Manual review cleared it: the existing card trades WTI short from July toward
December, while this card trades natural gas long from February toward June.

The XNG implementation is also materially different from:

- QM5_12567_cum-rsi2-commodity: RSI2 pullback logic;
- QM5_12704_xngusd-summer-power-long: June-August plus SMA confirmation;
- QM5_12706_xngusd-seasonal-dual-peak: dual monthly regimes plus SMA;
- QM5_12575_eia-xng-season: long/short month map plus SMA.

This rule has a locked February-May weekly calendar gate, long-only direction,
and no price-confirmation signal.

## Build Evidence

- Approved card:
  strategy-seeds/cards/approved/QM5_13109_xng-febjun-long_card.md.
- Source packet:
  strategy-seeds/sources/EWALD-WTI-TRDTIME-2022/source.md.
- EA source, binary, setfile, SPEC, and build-time card:
  framework/EAs/QM5_13109_xng-febjun-long/.
- Build record: artifacts/qm5_13109_build_result.json.
- Enqueue record: artifacts/qm5_13109_q02_enqueue_20260710.json.

Verification:

- EA-ID allocation: QM5_13109, directory-first registration.
- Card schema lint and G0 lint: PASS.
- SPEC validation: PASS.
- Symbol scope: SINGLE_SYMBOL_OK, zero violations.
- Magic resolver: 131090000 present.
- Strict compile: PASS, 0 errors, 0 warnings.
- Build check: PASS, 0 failures, 0 warnings.
- Backtest setfile: RISK_FIXED=1000, RISK_PERCENT=0, Friday close enabled.
- Q02 enqueue: one pending row, zero skipped.

Global registry validation still reports longstanding malformed legacy rows.
Resolver generation repeated three pre-existing missing-directory warnings for
EA IDs 1001, 1015, and 1016. None is caused by QM5_13109, and none was repaired
or normalized in this mission.

## Guardrails

- No T_Live file or process action.
- No AutoTrading action.
- No live setfile or deploy manifest.
- No portfolio gate, admission, KPI, or correlation code touched.
- Existing unrelated dirty FTMO/Q08 paths were left untouched.
