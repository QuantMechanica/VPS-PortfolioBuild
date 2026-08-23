# QM5_40005 build contract blocker

- Task: `788cf6e9-a0dc-4ccc-8462-48650989f114`
- EA: `QM5_40005_tradingview-multitimeframe-supertrend-atr`
- Checked: 2026-08-23
- Verdict: `BLOCKED_CARD_MECHANICS`

## Decision

No EA source, preset, binary, registry, or pipeline state was changed. The approved
card does not specify a reproducible Supertrend state machine, so completing the
build would require Development to invent strategy mechanics. That is outside the
build-only contract.

## Authoritative inputs

- Approved card:
  `D:/QM/strategy_farm/artifacts/cards_approved/QM5_40005_tradingview-multitimeframe-supertrend-atr.md`
  (SHA-256 `094bee5401161ba2376bc6f0bf827dba4dd922df4df63a6810e16e4bf9d070a7`).
- The canonical seeded card has the same SHA-256.
- EA registry row 4492 is active for EA ID 40005.
- Magic registry rows 17531-17533 are active for `EURUSD.DWX`, `GBPJPY.DWX`,
  and `XAUUSD.DWX` with slots 0-2.

## Upstream contract gap

The card supplies only the one-bar basic-band expression
`(High + Low) / 2 +/- 3 * ATR(10)` and BULL/BEAR observations at H1/H4 shifts.
It does not define the path-dependent mechanics needed to derive those states:

1. final upper/lower band recurrence and its ordering relative to a direction flip;
2. initialization of the first direction and bands;
3. the deterministic history boundary or warm-up used to seed the recursive state;
4. equality/tie behavior at the median and final bands; and
5. whether the 2-pip offset applies to every trailing update or only the initial SL,
   and whether an opposite flip is a market exit or only changes the trailing band.

The source pointer named by the card/SPEC,
`strategy-seeds/sources/tradingview-multitimeframe-supertrend-atr-official-source/`,
is absent from the canonical checkout, so there is no durable source algorithm to
resolve these omissions.

The existing MQ5 demonstrates the ambiguity rather than resolving it. It introduces
an unapproved `InpWarmupBars=100`, seeds direction with `close >= median`, chooses a
particular recursive-band implementation, clamps the exact card SL to 0.5-3.5 ATR,
and adds a direct opposite-flip market exit. Those choices are not authorized by the
approved card. The existing MQ5 SHA-256 is
`3987f621520bd7b1faa393ff522db794d4956d265928e93f520211a68cadaf20`;
its existing EX5 SHA-256 is
`bdef574b18f3f875801f27a6419d8e708df762e3142a8b2eba1ee70eeb98bb5e`.
Neither is accepted as a conformant build.

## Focused verification

Run from `C:/QM/repo`:

```text
python tools/strategy_farm/build_gate_hardening.py --repo-root C:/QM/repo --ea-label QM5_40005_tradingview-multitimeframe-supertrend-atr
```

Result: FAIL. Six deterministic findings remain in the existing source: two pip
double conversions, all three card loss limits absent, and raw broker time used for
the GMT rollover window.

```text
python tools/strategy_farm/validate_build_guardrails.py <MQ5> <three backtest setfiles>
```

Result: PASS for the canonical MQ5 and all three canonical setfiles. This only
confirms the news-staleness/risk-preset guardrails; it does not cure the strategy
contract gap.

```text
python framework/scripts/validate_spec_doc.py framework/EAs/QM5_40005_tradingview-multitimeframe-supertrend-atr
```

Result: PASS for document structure. The SPEC merely repeats the invented
`InpWarmupBars=100`, so structural validity is not mechanical authorization.

No compile, backtest, terminal start, or pipeline phase was run because the card
contract is an upstream prerequisite.

## Required unblock

Research/OWNER must amend and approve the card with the complete recursive
Supertrend algorithm, deterministic initialization/history rule, tie semantics,
and exact trailing/flip-exit behavior (or attach an immutable source implementation
that defines them). Development can then remove the unauthorized mechanics, add the
card loss/risk/time/slippage controls, run the strict build gate, and submit a
hash-bound binary and presets for review.
