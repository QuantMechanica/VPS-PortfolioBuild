# QM5_1640 Gemini code review — 2026-08-23

## Decision

- Router review task: `65e3d317-40d4-4bba-a801-48bcc2ba89d9`
- Gemini source task: `f990754c-57b2-4be5-b6c3-c0e34c2b7dc2`
- EA: `QM5_1640_aa-indmom-12-0`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1640_aa-indmom-12-0.md`
- Reviewed build identity: `framework/EAs/QM5_1640_aa-indmom-12-0/build_identity.json`
- Verdict: **REQUEST_CHANGES**
- Promotion: **not accepted and not moved to PIPELINE**

The checked-in binary is reproducible from the recorded hashes and the generic
build guardrails pass, but the implementation is not the strategy approved by
the card. The differences affect instrument selection, signal data, portfolio
capacity, rebalance behavior, spread control, and exit safety. They are strategy
contract failures, not cosmetic review comments.

## Blocking findings

### 1. The cross-sectional top-five portfolio is absent

The approved rule ranks the complete index/sector proxy basket by
`ROC_12_0`, holds only the positive top five, caps total exposure at five slots,
and exits instruments that fall outside that set. The EA runs independently on
one chart and admits every symbol whose own ROC is positive. It neither reads
the other instruments nor constructs a ranking, and it has no shared portfolio
coordinator or five-slot admission control. Consequently all eligible charts
can enter simultaneously, and an existing position is exited only when its own
ROC becomes non-positive rather than when it leaves the top five.

Evidence: card lines 39-48 and 56; EA `Compute12MonthROC()`,
`Strategy_EntrySignal()`, and `Strategy_ExitSignal()`.

Required change: implement one deterministic monthly cross-sectional snapshot,
rank the approved available basket, persist/bind the selected membership to the
rebalance period, enforce a portfolio-wide maximum of five positions, and close
positions no longer in the positive top-five set.

### 2. Signal time series does not implement the approved formula

The card requires evaluation on the final completed `MN1` bar with
`Close(1) / Close(13) - 1` and at least 14 monthly bars. The EA instead uses
`PERIOD_D1`, `Close(1) / Close(252) - 1`, and a 260-daily-bar minimum. A nominal
252-day proxy is not equivalent to the fixed completed-month rule and changes
both observations and rebalance reproducibility.

Evidence: card lines 39-41 and 59; EA lines 46-47 and 107-117.

Required change: use the completed `MN1` series exactly as specified, fail
closed below 14 monthly bars, and make the monthly snapshot the only source for
ranking and membership decisions.

### 3. The generated cohort does not represent the approved universe

The approved initial proxy basket is SP500, NDX, WS30, GDAXI, FCHI, UK100,
SPA35, NETH25, and STOXX50E when available. The 13 generated set files include
seven FX/metal symbols (`AUDUSD`, `EURUSD`, `GBPUSD`, `NZDUSD`, `USDCAD`,
`USDCHF`, and `XAUUSD`), while `FCHI`, `SPA35`, `NETH25`, and `STOXX50E` are
absent. This would test a materially different universe and makes the missing
cross-sectional coordinator even more consequential.

Required change: bind generation/registration to the approved, availability-
checked sector/index proxy basket only. Any unavailable symbols and the final
rankable universe must be explicit in durable evidence.

### 4. Spread protection is a different rule

The card says to skip new entries when current D1 spread exceeds `2.5 x` the
20-day median spread. `SpreadAllows()` compares current spread with
`0.3 x ATR(20,D1)` and explicitly allows entry if ATR is non-positive. This is
neither the specified statistic nor fail-closed behavior.

Evidence: card line 62; EA lines 50 and 61-73.

Required change: maintain/read a deterministic 20-day spread sample, compare
against its median at the specified multiplier, and reject entry when the
sample is unavailable or invalid.

### 5. Monthly state allows same-month re-entry and is restart-dependent

`Strategy_EntrySignal()` reads `current_month_key` but never compares it with
`g_last_rebalance_key`. After a stop-out, the EA can therefore enter again on
each new chart bar during the same month while ROC remains positive.
`g_last_rebalance_key` is also initialized to zero on every process start, so
rebalance/exit semantics can change after restart.

Required change: persist or deterministically reconstruct the completed
rebalance snapshot and prevent repeated admission within the same monthly
portfolio decision.

### 6. The news gate can suppress risk-reducing exits

`OnTick()` returns immediately when the news gate denies a new trade, before
Friday-close handling and `Strategy_ExitSignal()`. This turns an entry blackout
into a blanket position-management blackout. Mandatory news blackout must block
new risk, not prevent strategy or framework exits.

Evidence: EA lines 229-267.

Required change: keep risk-reducing management and exits active while applying
news eligibility only to new entries.

## Checks that passed

- `python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_1640_aa-indmom-12-0`
  returned `PASS`, checking 14 files with zero findings and enforcing the
  336-hour maximum news-staleness bound.
- MQ5 SHA-256 is
  `bdbd01eb4fe94f7ee7bfc33376b154987b94a989bd9ec22daf72e5e6c5c9d724`,
  matching `build_identity.json`.
- EX5 SHA-256 is
  `5939b001f358b22cebfe033da804b1bf1aae9d17c858b6aa9aaffd3e1e752cd5`,
  matching `build_identity.json`.
- All 13 generated backtest sets use `RISK_FIXED=1000` and
  `RISK_PERCENT=0`.
- The EA preserves `qm_news_stale_max_hours=336` and contains no apparent
  martingale, grid, HFT, or ML mechanism.

These mechanical passes do not override the blocking card-to-code mismatches.
No pipeline verdict was inferred or issued during this review.
