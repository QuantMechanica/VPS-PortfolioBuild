# QM5_41149 — AUDUSD Local-Session Inventory Drift

## 1. Provenance and hypothesis

The approved Strategy Card is `D:\QM\strategy_farm\artifacts\cards_approved\QM5_41149_audusd-local-session-inventory-drift.md`. Its Tier-A source is Francis Breedon and Angelo Ranaldo, “Intraday Patterns in FX Returns and Order Flow,” *Journal of Money, Credit and Banking* 45(5), 2013. The source's Table 1 defines Australian local trading hours as 10:00–16:00, and the card predeclares the source-signed AUD depreciation expression. No source performance statistic is transferred to this EA.

This is a structural local-inventory/session edge on `AUDUSD.DWX`, not a momentum signal. It is deliberately a low-frequency, one-attempt-per-Sydney-business-date sleeve.

## 2. Market, clock, and data contract

- Execution carrier: the chart symbol (`_Symbol`), with the registry/setfile binding it to `AUDUSD.DWX`.
- Literal chart and decision timeframe: H1.
- Australia/Sydney session: 10:00 inclusive to 16:00 exclusive local civil time.
- Sydney DST is computed from the statutory recurring rule: first Sunday in October start and first Sunday in April end. Local-to-UTC conversion round-trips both possible offsets and fails closed unless exactly one is valid.
- ATR is H1 ATR(14), read only from shift 1 at the entry decision.
- A session without an exact executable 10:00 H1 bar is operationally non-trading. This also makes a closed-market holiday fail closed; no unapproved jurisdictional holiday series is synthesized.

## 3. Entry rules

On the exact 10:00 Australia/Sydney H1 bar of Monday through Friday, submit one market SELL if and only if all of the following hold:

1. No position is owned by this magic and ownership integrity is clean.
2. The local date has not already been consumed.
3. The completed H1 ATR is finite and positive, quotes and symbol metadata are valid, and fixed-risk sizing produces positive volume.
4. Six uncached one-hour news-calendar checks cover the full [10:00,16:00] owned interval and all allow trading. Missing or stale calendar coverage fails closed.
5. The initial stop satisfies broker minimum-distance geometry.

The local date is written to a terminal Global Variable and flushed before order submission. A rejection therefore consumes the opportunity. Deal history is also checked on each new Sydney date so a restart cannot duplicate a filled entry.

## 4. Exit and position integrity

- Initial hard stop: 1.5 completed H1 ATR above the expected SELL fill; it is never widened or trailed.
- No profit target.
- Flatten at or after 16:00 Australia/Sydney on the same local date. A date mismatch or an owned position observed before 10:00 is also flattened.
- Friday-close and kill-switch handling execute before strategy entry logic.
- More than one owned position, another owned symbol, a BUY, missing/invalid stop, nonzero target, or invalid volume is an ownership fault and triggers flattening of all exposure owned by this magic.

## 5. Declared parameter surface and build guard

The only strategy parameters are `strategy_atr_period_h1=14` and `strategy_hard_stop_atr=1.5`; both are card-locked. The EA also locks `qm_ea_id=41149`, `qm_magic_slot_offset=0`, and fixed-risk mode (`RISK_PERCENT=0`, finite `RISK_FIXED>0`).

No equality guard is applied to RNG, news, Friday-close, portfolio-weight, or stress defaults. `qm_stress_reject_probability` is checked only for finiteness and inclusive 0..1 range. News and Friday-close inputs remain framework-governed.

## 6. Failure policy and prohibited behavior

Clock ambiguity, missing history, stale/missing news data, invalid ATR/quotes/metadata, risk-sizing failure, stop-rule failure, duplicate state, and ownership faults all fail closed. There is no grid, martingale, averaging, pyramiding, reversal, discretionary filter, banned indicator, or ML/adaptive component. The EA does not access live deployment controls.

## 7. Verification and open questions

Reference tests verify the Sydney DST boundaries, unambiguous 10:00/16:00 conversions, session membership, and source/card/static guard invariants. The mandatory framework-input-pin audit must pass after source generation and immediately before compile enqueue. Compilation, strict build checks, canonical setfile validation, and Q02 are separate governed evidence.

Open question for later research review: the approved card does not identify a versioned Australian/NSW holiday dataset. This implementation therefore treats “holiday” as a missing exact executable H1 session-open bar and does not invent a civil-holiday exclusion. Any broader holiday definition requires a new governed calendar artifact rather than an undeclared code rule.
