# Build Checklist — QM5_1017 chan-pairs-stat-arb

- Card: `strategy-seeds/cards/chan-pairs-stat-arb_card.md`
- Card status: `APPROVED`
- EA ID / registry slug: `1017` / `chan-pairs-stat-arb`
- Concrete pair: `AUDUSD.DWX` / `NZDUSD.DWX`, D1
- Magic rows: AUDUSD slot 4 (`10170004`), NZDUSD slot 26 (`10170026`)
- Logical Q02 symbol: `QM5_1017_AUDUSD_NZDUSD_COINTEGRATION_D1`
- Risk mode: backtest `RISK_FIXED=1000`, `RISK_PERCENT=0`
- Friday close: disabled under the approval recorded in the card
- Native stop: none, per the approved Chan reversal-model rule
- Two-leg executor: synchronized open, rollback on partial fill, orphan-leg cleanup
- Entry model: annual prior-data OLS + one-lag CADF + OU half-life gate
- Exits: mean reach or fitted half-life time stop
- ML / grid / martingale / pyramiding: absent
- Strict compile: PASS, 0 errors, 0 warnings
- Scoped build check: PASS, 0 failures, 0 warnings
- SPEC validation: PASS
- Basket-manifest regression tests: PASS (14 tests)
- Symbol-scope validation: `BASKET_OK`, 0 violations

The May scaffold described the second leg as adjacent slot `N+1`. The active
registry is symbol-slotted, so the completed executor uses the actual registered
AUDUSD and NZDUSD slots (4 and 26). No magic row was added or repurposed.
