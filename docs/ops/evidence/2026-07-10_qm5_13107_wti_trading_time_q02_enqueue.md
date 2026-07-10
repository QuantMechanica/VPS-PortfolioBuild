# QM5_13107 WTI Trading-Time Seasonality Q02 Enqueue

Date: 2026-07-10  
Branch: `agents/board-advisor`

## Outcome

One new structural energy sleeve was carded, built, compiled, and enqueued:

- EA: `QM5_13107_wti-juldec-short`.
- Signal: short `XTIUSD.DWX` on the first tradable D1 bar of each broker week
  from July through November; V5 Friday close creates non-overlapping weekly
  tranches.
- Q02 work item: `0251f2ca-5a43-4ebf-9b25-f4f4ab910996`.
- Handoff: `pending`, unclaimed, `XTIUSD.DWX`, D1.
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Magic: `131070000`, slot 0.

No manual MT5 run was launched. At the CPU guard scan, T1/T3/T4/T6/T8 were
actively backtesting and seven paced worker wrappers were present. The build
therefore used `deferred_p2_smoke` and handed the setfile to Q02 without
competing with factory automation.

## Source And Mechanization

Primary source: Ewald, Haugom, Lien, Stordal, and Wu (2022), "Trading time
seasonality in commodity futures: An opportunity for arbitrage in the natural
gas and crude oil markets?" *Energy Economics* 115, 106324,
https://doi.org/10.1016/j.eneco.2022.106324. Open published version:
https://eprints.gla.ac.uk/281581/1/281581.pdf.

The full paper was reviewed. It finds that fixed-maturity WTI futures prices
are highest when traded in July and lowest when traded in December, then tests
a short-July, cover-December strategy. `XTIUSD.DWX` cannot reproduce matched
futures maturities, so the card explicitly tests the directional CFD carrier as
weekly July-November tranches. The translation preserves the source direction
and exposure window, avoids overlapping positions, retains Friday flattening,
and expects 20-23 completed trades/year before Q02.

The futures-to-CFD basis change is a kill risk, not a hidden equivalence claim.
No source performance number was imported.

## Non-Duplicate Decision

The initially suggested XAU/XAG route was rejected because the repository
already contains:

- `QM5_12577`: fixed-beta gold/silver log-ratio z-score reversion.
- `QM5_12724`: gold/silver ratio channel breakout.
- `QM5_12862`: gold/silver return-spread z-score reversion.
- `QM5_1083`: rolling-OLS XAU/XAG cointegration proxy.

The selected WTI rule is also distinct from one-month WTI July premiums,
December fades, broad February-September first-day trades, EIA/OPEC/inventory
events, roll/expiry rules, carry, ratios, RSI, Donchian, NR7/IDNR4, and generic
trend/reversal systems. Repository dedup returned `CLEAN` before allocation.

## Build Evidence

- Approved card:
  `strategy-seeds/cards/approved/QM5_13107_wti-juldec-short_card.md`.
- Source packet:
  `strategy-seeds/sources/EWALD-WTI-TRDTIME-2022/source.md`.
- EA source, binary, setfile, and SPEC:
  `framework/EAs/QM5_13107_wti-juldec-short/`.
- Build record: `artifacts/qm5_13107_build_result.json`.
- Enqueue record: `artifacts/qm5_13107_q02_enqueue_20260710.json`.

Verification:

- EA-ID allocation: `QM5_13107`, atomic reservation.
- Card schema lint: `PASS`.
- SPEC validation: `PASS`.
- Symbol scope: `SINGLE_SYMBOL_OK`, zero violations.
- Magic resolver: `131070000` present after directory-first registration.
- Strict compile: `PASS`, 0 errors, 0 warnings.
- Build check: `PASS`, 0 failures, 0 warnings.
- Backtest setfile: `RISK_FIXED=1000`, `RISK_PERCENT=0`, Friday close enabled.
- Q02 enqueue: one pending row, zero skipped.

Resolver generation repeated three pre-existing missing-directory warnings for
EA IDs 1001, 1015, and 1016. They are unrelated to QM5_13107 and were not
repaired or normalized in this mission.

## Guardrails

- No `T_Live` file or process action.
- No AutoTrading action.
- No live setfile or deploy manifest.
- No portfolio gate, admission, KPI, or correlation code touched.
- Existing unrelated dirty FTMO/Q08 worktree paths were left untouched.
