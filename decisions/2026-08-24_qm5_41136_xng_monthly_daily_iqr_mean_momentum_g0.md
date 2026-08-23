# QM5_41136 XNG Completed-Month Daily-Return Interquartile-Mean Momentum - G0 Decision

Date: 2026-08-24

Decision: `APPROVED`

## Authority and scope

The current explicit OWNER commodity/energy portfolio instruction delivered
to Codex on branch `agents/board-advisor` authorizes one new structural,
low-frequency commodity edge and explicitly permits a second XNG edge whose
logic differs from `QM5_12567`. It requires reputable-source criteria,
`RISK_FIXED` backtest configuration, committed non-duplicate work, and one
paced Q02 enqueue. It excludes `T_Live`, AutoTrading, portfolio-gate, and
T_Live-manifest changes.

This decision approves
`strategy-seeds/cards/approved/QM5_41136_xng-mdaily-iqrmean-mom_card.md` for one
branch-only non-live build, strict Q01 validation, and one paced non-live Q02
handoff if the factory CPU ceiling permits.

## Identity

- EA: `QM5_41136_xng-mdaily-iqrmean-mom`
- strategy ID: `MOP-MEEK-XNG-MDAILY-IQRMEAN-2026_S01`
- source ID: `MOP-MEEK-XNG-MDAILY-IQRMEAN-2026`
- symbol/slot/magic: `XNGUSD.DWX` / 0 / `411360000`
- timeframe: D1
- decision clock: first executable bar of a new normalized broker month

The numeric identity is fixed for deterministic registry reservation. Build
work may start only after the EA identity and slot-zero magic survive the
governed registry/resolver allocation.

## Approved source boundary

Source intake was approved before extraction at commit `c24a87615` in
`decisions/2026-08-24_xng_monthly_daily_iqr_mean_momentum_source_approval.md`.
The bounded source packet is
`strategy-seeds/sources/MOP-MEEK-XNG-MDAILY-IQRMEAN-2026/source.md`, SHA-256
`AB0F8B5C47748783169EAB542C56FFC5ABC20D3D5F5D8F3D14832F50939A1C3A`,
committed at `c3ad3a01b`.

The complete governed parent records were read before approval:

- Moskowitz, Ooi, and Pedersen (2012), \"Time Series Momentum,\" *Journal of
  Financial Economics* 104(2), 228-250, DOI
  `10.1016/j.jfineco.2011.11.003`; complete 23-page author-hosted published PDF
  receipt and durable PDF hash are preserved.
- Meek and Hoelscher (2023), \"Day-of-the-week effect: Petroleum and petroleum
  products,\" *Cogent Economics & Finance* 11(1), DOI
  `10.1080/23322039.2023.2213876`; the governed record preserves a complete
  review of the 21-page open-access copy and its natural-gas return treatment.

The first paper supports own-price monthly continuation and explicitly
includes natural gas. The second supplies natural-gas close-to-close
daily-log-return and ending-session lineage. Neither tests the
integer-quartile-trimmed mean of all daily returns inside one completed month.
That statistic, Darwinex continuous CFD carrier, broker-month labels, fixed
cash risk, ATR stop, spread ceiling, retry ledger, and lifecycle are disclosed
QM translations. No source efficacy or correlation result transfers.

## Locked rule

On the first executable D1 bar of a new normalized broker month:

1. Choose one uniform energy-label convention: raw broker date or a uniform
   `+1` day correction when the current D1 label is exactly one day behind
   broker date. Reject mixed, colliding, weekend-ending, or other offsets.
2. Persist the normalized decision `yyyymm` before history, signal, news,
   spread, quote, ATR, sizing, margin, or order submission. Permit no retry.
3. Within 45 completed D1 bars, select every bar in the immediately preceding
   normalized calendar month plus one adjacent older boundary close. Require
   17-23 month sessions, unique timestamps, strict chronology, positive
   finite closes, and no current-month observation.
4. Form exactly one chronological log return ending on every selected month
   session. Verify its sum equals the direct boundary-to-final log return
   within `1e-10`.
5. Sort all returns ascending; remove exactly `floor(n/4)` from each tail;
   average each retained return at indexes `floor(n/4)` through
   `n-floor(n/4)-1` exactly once.
6. Buy XNG when that central mean is strictly positive; sell when strictly
   negative; consume equality or any invalid state flat. The raw endpoint is
   diagnostic only and neither value scales risk.
7. Open at most one slot-zero XNG position with `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5 * ATR(20,D1)` hard stop, no take-profit, and a 3,000-point spread
   ceiling.
8. Close on the first tick of a later normalized broker month. Forty calendar
   days is stale repair only. Flatten malformed, duplicate, wrong-symbol,
   wrong-magic, or stopless owned exposure immediately.

Both news axes and Friday close are OFF. No fitted model, oscillator, moving
average, external feed, adaptive threshold, target, trail, break-even move,
partial close, opposite-signal exit, scale-in, pyramid, grid, or martingale is
authorized.

## Reputable-source criteria

- R1 `PASS_WITH_WITHIN_MONTH_IQR_MEAN_TRANSLATION_RISK`: two named-author,
  peer-reviewed papers with DOIs and complete-read evidence; explicit
  natural-gas membership and daily-return construction; exact central-band
  rule disclosed as untested.
- R2 `PASS`: clock, label convention, month, boundary, observation bounds,
  returns, endpoint identity, ascending sort, integer trim, retained mean,
  direction, attempt, risk, stop, spread, and lifecycle are deterministic.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK`: registered native
  XNG D1 history and MT5 state provide every runtime input.
- R4 `PASS`: deterministic timestamps, logarithms, arithmetic, sorting,
  comparison, ATR, and execution state only; no trained or prohibited signal,
  external runtime feed, grid, martingale, scale-in, or pyramid.

## Non-duplicate decision

The pre-allocation canonical checker found no exact collision across 4,635
registry identities, 1,303 cards, and 45 Strategy Wiki nodes. It raised the
expected WTI carrier sibling for manual review. Evidence is
`artifacts/qm5_xng_mdaily_iqrmean_mom_preallocation_dedup_20260824.json`.

Manual review separates the WTI carrier, the raw XNG one-month endpoint,
weekly/flow/calendar XNG families, and the certified cumulative-RSI pullback.
The repository already treats source-pure WTI and XNG single-symbol carriers
as separate hypotheses. The target removes four or five daily returns from
each tail and averages the exact 9-13-observation central band on XNG only.

Verdict:
`CLEAN_XNG_COMPLETED_MONTH_DAILY_INTERQUARTILE_MEAN_MOMENTUM_AFTER_CARRIER_FAMILY_REVIEW`.

## Risk and kill boundary

Every valid nonzero central mean can qualify, giving a pre-result density
prior near twelve decisions per year. Q02 must retire the candidate at zero
trades, below five completed positions in any full post-warm-up year, with
nonpositive governed economics, or on any label, month, return, sort, trim,
mean, side, attempt, risk, lifecycle, or determinism defect.

This rule is materially different from certified `QM5_12567`, but G0 does not
assert realized independence. Q09 alone may accept or reject portfolio
correlation. Do not change sample membership, trim formula, direction,
carrier, stop, risk, hold, or add endpoint agreement, weekday, event,
seasonal, volatility, external, or prior-result state to rescue failure.

## Safety boundary

Create one exact `XNGUSD.DWX` D1 backtest setfile with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. This decision excludes manual
backtests; live, demo, shadow, stress, or optimization setfiles; `T_Live`;
AutoTrading; deploy or T_Live manifests; portfolio admission; portfolio-gate
edits; and correlation waivers. If the paced factory CPU ceiling is binding
before enqueue, stop without starting, stopping, reserving, reaping, or
reprioritizing any terminal.
