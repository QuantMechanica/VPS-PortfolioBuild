# Review — QM5_9949 bandy-bbwidth-contraction-breakout-trend

- **Reviewer:** Claude (review lane)
- **Date:** 2026-08-23
- **Router task:** 315a0d2d-63aa-46e5-92d1-c0731183a255 (review_ea)
- **Source build task:** 528d9db8-5f15-4c26-81bf-887a4b6deb17 (agy/gemini, BUILD_COMPLETE_PASS)
- **EA dir:** `framework/EAs/QM5_9949_bandy-bbwidth-contraction-breakout-trend/`
- **Card:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9949_bandy-bbwidth-contraction-breakout-trend.md`
- **mq5 sha256:** `a05654921ff354fe942b3a78f13fde3869a56890638d366a72a18118acfc2b60` (matches build identity; ex5 present, build_check_passed=true)

## Verdict: RECYCLE

The build is framework-clean and most of the mechanism is card-faithful, but a **card-mandated
mechanic (one-shot consumption + re-arm gate) is not implemented**, and its parameter
`strategy_rearm_pct` is a dead input. Recyclable with a single, well-scoped fix.

## Blocking defect

**Missing re-arm / one-shot-consumption gate — `strategy_rearm_pct` is a dead input.**

- Card mechanic #5 (`cards_approved/…QM5_9949…md`, "Entry" §5): *"once a breakout fires, the
  compression flag is consumed — the same compression episode cannot fire a second entry.
  Re-arm only after `bb_width` rises above the 60th-percentile of the rolling 120-bar window."*
- Card "Build-EA Notes" bullet 3 and P1 reviewer item (b) explicitly require an
  `in_compression_episode` state flag + 60th-pct release gate to prevent double-firing.
- In the EA, `strategy_rearm_pct` (declared `QM5_9949…mq5:42`, default 60.0) is referenced
  **only** in `Strategy_ParamsValid` (`:79`, `:80`) — never in any entry/exit decision.
  Grep confirms no third use site.
- The only re-entry guard present is `QM_TM_OpenPositionCount(magic) > 0` (`:196`), which blocks
  *concurrent* entries but not re-entry into the same compression episode after the position
  exits. There is no state flag tracking episode consumption and no 60th-pct release check.
- Consequence: after an exit (e.g. midband trail after a few days), if shift-2 width is still
  ≤ 10th-pct, `Strategy_EntrySignal` (`:216`) can re-fire within the same unreleased episode —
  the exact behaviour the card's re-arm gate exists to prevent. The declared mechanism is
  incompletely realised.

**Fix:** implement the episode state machine per card note: arm on first `is_compressed`,
consume on breakout fire, and require `bb_width > percentile(window, strategy_rearm_pct)`
before re-arming. This wires `strategy_rearm_pct` into the mechanism and closes the double-fire path.

## Verified conformant (no action)

- Card mechanism otherwise faithful:
  - BB(20,2.0) sample stdev ddof=0 (`:104` `MathSqrt(sum_sq/period)`), width `(ub-lb)/mid` (`:110`).
  - Percentile-window exclusivity honoured: breakout evaluated at shift 1, compression at
    shift 2, window = shift 3..122 (`:203-216`) — today's width not in its own sample.
  - Percentile index: `floor((10/100)*120)=12` (`:144`), matches card "index 12" note.
  - Regime gate SMA(200) at shift 1 (`:228`); long needs `close1>ub1 && close1>regime` (`:252`),
    short mirror (`:271`).
  - Cat-SL `entry ± 2.5*ATR(14)` with stops-level clamp (`:254-256`, `:273-275`).
  - Extreme-range guard `high1-low1 > 4*ATR` (`:235`); time stop `max_hold_bars*period` (`:320`);
    midband-touch trail-exit uses consistent shift-1 bar semantics (`:328-333`), resolving the
    card's open P1 shift question toward closed-bar.
- Framework conformity: `#include <QM/QM_Common.mqh>` (`:5`); `RISK_FIXED=1000`/`RISK_PERCENT=0`
  (`:19-20`); magic via `QM_FrameworkMagic()` (`:195`, registry rows `99490000+slot` verified in
  `framework/registry/magic_numbers.csv`); news wired via `QM_NewsAllowsTrade2` (`:411-415`);
  MAE hook `QM_FrameworkTrackOpenPositionMae` (`:381`); kill-switch (`:383`); Friday close
  (`:389`); new-bar gate (`:419`). No ML libs, no hardcoded commission/swap.
- Symbol guard matches registry universe (`:55-70`), D1-only (`:164`), warmup gate (`:168`).
- Set files generated via governed build path (13 backtest sets in identity artifact);
  no raw MQ5 promotion — ex5 built, build_check_passed=true, source hash matches.

## Evidence
- `framework/EAs/QM5_9949_bandy-bbwidth-contraction-breakout-trend/QM5_9949_bandy-bbwidth-contraction-breakout-trend.mq5`
- `docs/ops/evidence/528d9db8_qm5_9949_bandy-bbwidth-contraction-breakout-trend_build_identity.json`
- `framework/registry/magic_numbers.csv` (rows 99490000..)
