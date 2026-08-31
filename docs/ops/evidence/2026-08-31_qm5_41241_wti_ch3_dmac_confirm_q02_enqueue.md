# QM5_41241 WTI CH3/DMAC Confirmation Q02 Enqueue

## Outcome

The OWNER commodity/energy mission produced one new branch-only structural WTI
sleeve. `QM5_41241_wti-ch3-dmac-confirm` passed strict Q01 compilation and was
enqueued exactly once into Q02 as pending work item
`bd5768f5-dbb7-437b-acda-717d071fb5df`.

No manual backtest, live action, portfolio-gate change, certification claim,
or correlation claim was made. Q09 remains the only authority for realized
decorrelation and portfolio value.

## Locked edge and non-duplicate evidence

At the first genuine normalized WTI broker-month transition, the EA closes the
prior package, consumes the new `yyyymm` attempt, and reconstructs exactly six
consecutive completed `XTIUSD.DWX` month-end closes, newest first. It trades
only when both source-family states agree:

```text
CH3  = BUY  if C0 > max(C1,C2,C3)
       SELL if C0 < min(C1,C2,C3)
       FLAT otherwise

mean6 = (C0+C1+C2+C3+C4+C5)/6
DMAC  = BUY  if C0 > mean6*1.025
        SELL if C0 < mean6*0.975
        FLAT otherwise

signal = CH3 when CH3 == DMAC and CH3 != FLAT; otherwise FLAT
```

Every comparison is strict. A missing endpoint, equality, invalid state,
parent flat, or disagreement consumes the month. Positions carry a frozen
`4.0*ATR(20,D1)` hard stop, renew at the next broker month, and have a 40-day
survivor repair plus a 1,500-point entry spread ceiling.

The reputable lineage is Szakmary, Shen, and Sharma (2010), *Journal of
Banking & Finance* 34(2), DOI `10.1016/j.jbankfin.2009.08.004`. The paper
supplies both monthly parent rule families and explicit crude-oil membership.
The AND intersection, Darwinex WTI CFD port, operational attempt state, risk,
stop, and lifecycle are disclosed pre-result QM translations.

The canonical dedup receipt was clean across 4,740 registry identities, 1,378
cards, and 45 Strategy Wiki nodes. The locked fixtures establish a decision
surface different from both built parents:

- `[103,100,99,98,120,120]`: CH3 buys, DMAC sells, this candidate stays flat;
- `[110,111,109,108,80,80]`: CH3 is flat, DMAC buys, this candidate stays flat;
- `[120,110,105,100,95,90]`: both buy, so this candidate buys; and
- `[80,90,95,100,105,110]`: both sell, so this candidate sells.

Governance records:

- source approval: `decisions/2026-08-31_wti_ch3_dmac_confirmation_source_approval.md`;
- bounded source packet: `strategy-seeds/sources/SZAKMARY-WTI-CH3-DMAC-CONFIRM-2026/source.md`;
- approved card: `strategy-seeds/cards/approved/QM5_41241_wti-ch3-dmac-confirm_card.md`;
- G0 decision: `decisions/2026-08-31_qm5_41241_wti_ch3_dmac_confirmation_g0.md`; and
- canonical dedup: `artifacts/qm5_wti_ch3_dmac_confirm_preallocation_dedup_20260831.json`.

## Build and Q01 result

The governed identity is `QM5_41241`, slot 0, magic `412410000`. The EA, SPEC,
one D1 `RISK_FIXED` setfile, byte-identical local card, independent fixtures,
and compiled binary are committed on `agents/board-advisor`.

Q01 utility work item `e08c9f5b-6da5-41b9-8de3-85f37691cba0` completed on T9:

- verdict: `COMPILE_OK`;
- strict compiler: PASS, 0 errors, 0 warnings;
- strict build check: PASS;
- failure classes: none;
- setfiles: exactly one;
- MQ5 SHA-256: `F3361DAE1BF71ED44A0D036E5DC1F11DBE6E3EB2D2B81C31D351110E914B30A6`;
- EX5 SHA-256: `6C5762A51B238C128CB5B5FC03A9ABCE036F1D7B8D66BA5803FD0480BC22E80D`;
- evidence SHA-256: `96DD45B547158E1C1086ACA0E812FAFFD789CA5006CAF3FE86596A5704FF6417`.

Additional validation passed: eight independent reference tests, card schema
lint, build skill guard, raw-MQ5 quarantine, strategy-entry gate, and final
SPEC validation. The sole preset locks `RISK_FIXED=1000`, `RISK_PERCENT=0`,
and `PORTFOLIO_WEIGHT=1`; build hash
`2eb95ab03c7d9251f408dd6e6e3963f7c32abc3fb4692ced7027f5ad4caccda3`
is sealed.

The first build-record task `8510c690-ce7f-48cc-8951-3707460daf3d` correctly
failed closed because SPEC lacked the validator's explicit bold EA-ID line. It
created no Q02 row. Commit `d7d8b3967d` added only that declaration; the
validator then passed, and successor task
`a08a3918-9366-4491-8d27-44416a35fce6` recorded the unchanged compiled build.

## Paced Q02 enqueue

The final whole-host five-sample CPU window immediately before the queue
mutation was `95.4129%, 88.9991%, 86.7313%, 82.6293%, 79.7977%` (average
`86.7141%`, maximum `95.4129%`). Every sample and the maximum were below the
97% hard ceiling.

The canonical build recorder created one Q02 row:

- work item: `bd5768f5-dbb7-437b-acda-717d071fb5df`;
- status at readback: pending, attempt count 0, unclaimed;
- symbol/timeframe: `XTIUSD.DWX / D1`;
- custom-history archive admission: ACTIVE, 108 selected rows;
- priority track: true; and
- duplicate or skipped rows: none.

This session enqueued but did not manually dispatch or execute that row.

## Safety boundary

AutoTrading was not toggled. `T_Live`, its manifest, deploy manifests, the
portfolio gate, portfolio admission, and certification state were untouched.
This receipt establishes a new testable direct-WTI sleeve, not performance or
realized decorrelation.

Machine-readable receipt:
`artifacts/qm5_41241_wti_ch3_dmac_confirm_q02_enqueue_20260831.json`.
