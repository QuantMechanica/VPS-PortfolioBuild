# QM5_41399 XAU/XAG Median-Return Source Build — CPU Stop

- Date: 2026-09-09
- Branch: `agents/board-advisor`
- EA: `QM5_41399_xauxag-medret-rv`
- Outcome: source build committed; compile pending; Q02 not enqueued

## Delivered Identity

The new market-neutral-style commodity sleeve fades the ordinary even median
of twelve individual synchronized completed-month XAU/XAG log-ratio changes.
It is not the existing four-block median-of-means, Winsorized mean, ratio-level
median/MAD, old/recent median shift, or outright-WTI median continuation.

- Source approval commit: `a68d6ec421`
- Identity reservation commit: `9bf725ffa2`
- Approved card/G0 commit: `63bf0498f0`
- Two-slot magic allocation commit: `49d1b625f2`
- EA source/build artifact commit: `1572c6d0da`
- Active slots: XAU `413990000`; XAG `413990001`

## Validation Completed

- Card schema/ML lint: PASS, no missing sections and no ML hits.
- Independent reference suite: 10/10 PASS.
- Binding PACER audit command:
  `python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_41399_xauxag-medret-rv/QM5_41399_xauxag-medret-rv.mq5"`
- PACER result: exit 0, `ok=true`, `hit_count=0`, no
  `EA_FRAMEWORK_INPUT_PINNED` finding.
- Guard pins only `strategy_*`, `qm_ea_id`, `qm_magic_slot_offset`, and fixed
  backtest risk mode. It does not equality-check RNG, news, Friday, or stress;
  stress is checked only for finiteness and inclusive `[0,1]` range.

## Compile State

The direct strict compile was attempted only after the PACER audit and was
refused without retry by the live-factory guard:

`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` / `INCLUDE_MIRROR_REFUSED` because
`terminal64` processes were alive. It produced no `.ex5`.

The canonical compile path was then used:

- Work item: `269fc1ff-f77a-4bf2-b6c1-5a6d715dd51b`
- Initial hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`
- Exact source SHA-256 in queue and working tree:
  `ca14b532f4757d96461d641536996e6914909d066087ebfae98fa0fac21e69bf`
- Bounded release: one exact item only; backup
  `D:/QM/strategy_farm/state/backups/farm_state_before_compile_wave_20260909T144837Z_5659de43.sqlite`
- State at stop: pending, unheld, unclaimed, no verdict, no build-check result,
  no evidence path, no `.ex5`.

## Binding CPU Stop And Q02

Five read-only two-second host CPU samples after release were:

```text
99.02, 99.13, 100.00, 99.95, 100.00 percent
average 99.62 percent; maximum 100.00 percent
```

This exceeds the 97% backtest CPU ceiling. Per the OWNER pacer instruction,
work stops here. Q02 is not enqueued because the CPU ceiling was hit and Q01
has neither compile PASS nor a current `.ex5`. No terminal, AutoTrading,
`T_Live`, portfolio gate, live manifest, or deployment artifact was changed.

## Governed Continuation

Let the released compile item finish through the resident worker when capacity
returns. Only after `done/COMPILE_OK`, strict build-check PASS, current `.ex5`
binding, and a fresh below-ceiling CPU sample may the canonical basket Q02
intake be enqueued. Do not bypass or duplicate the existing compile item.
