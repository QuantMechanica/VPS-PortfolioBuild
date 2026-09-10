# QM5_41416 XAU/XAG Relative-Vote Flip Reversion — Build And Q02 Handoff

Date: 2026-09-10
Branch: `agents/board-advisor`
Outcome: `Q01 PASS; Q02 ENQUEUED`

## Edge

`QM5_41416_xauxag-wrelvote-flip-fade` is a low-frequency, market-neutral-
intent XAU/XAG basket. At a new broker week it compares strict sign majorities
in two overlapping three-week windows of synchronized relative returns. When
the majority flips, it fades the newer relative winner for one week. It uses
opposed equal-notional legs, one aggregate fixed-dollar risk budget, and
independent frozen ATR stops.

This is not the continuation sibling `QM5_41414`: that EA follows the same
newly flipped majority, while QM5_41416 takes the opposite side. The dedup
receipt found no exact identity and records the direction as the load-bearing
economic distinction.

## Deterministic Evidence

- Approved card: `strategy-seeds/cards/approved/QM5_41416_xauxag-wrelvote-flip-fade_card.md`
- EA source: `framework/EAs/QM5_41416_xauxag-wrelvote-flip-fade/QM5_41416_xauxag-wrelvote-flip-fade.mq5`
- Magic rows: slot 0 `414160000` XAU, slot 1 `414160001` XAG
- PACER input-pin audit: exit 0, `EA_FRAMEWORK_INPUT_PINNED` hit count 0
- Reference oracle: 6/6 PASS
- Symbol scope: `BASKET_OK`, zero violations
- Build guardrails: PASS
- Compile item: `74eeb745-6936-4afe-abce-ed85595bf4c6`
- Compile: `COMPILE_OK`, zero compiler errors/warnings, build-check PASS
- Binary SHA256: `795eea75dfd14a2c996ec738f756c138f6dcd9b473b45414c4a1a52ccdafea0f`

## Q02 Enqueue

The first-Q02 dry run selected the logical basket set and returned `ELIGIBLE`.
Immediately before the successful apply, five one-second CPU samples were
`25.7, 40.1, 38.4, 44.6, 46.9`; the 46.9% maximum was below the binding 97%
ceiling. The first apply met a transient factory mutation lock and did not
override it. After the lock cleared, the same governed intake succeeded.

- Q02 work item: `f5f4b2e0-7172-42cc-bbd0-8a01de1c776d`
- Symbol: `QM5_41416_XAU_XAG_WRELVOTE_FLIP_FADE_D1`
- Timeframe: D1
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- Immediate status: pending

No manual tester was launched and no portfolio gate, deployment artifact,
live manifest, `T_Live`, terminal control, or AutoTrading state was changed.
Q09 alone may establish realized decorrelation.
