# review_ea — QM5_9979 bandy-index-gap-fade-mr-index — 2026-08-23

- Router task: `84776da8-b769-4828-8fed-ceb8f9c5b101` (state REVIEW, assigned claude)
- Source task: `a0768e09-7427-4ebe-87c1-19b4b17c9de1` (build_ea, source_agent gemini / agy backend)
- Source verdict claimed: "QM5_9979 built and verified; spec, mq5, sets, and guardrails PASS; ready for Codex review"
- Reviewer: Claude (review lane), independent verification
- **Verdict: RECYCLE** — mechanics card-faithful and controls-clean, but the registered
  symbol universe contradicts the card's explicit, reasoned scope. One actionable defect;
  no OWNER decision required for the recommended fix.

## Reviewed identity (hash-bound)

- MQ5 SHA-256: `4d873d6705b19bbf7621ab2a4dba3cd35d5e27cc5f812b315e03bd7de0c4360c`
  (matches `artifacts/qm5_9979_build_result.json` `mq5_sha256`).
- EX5 SHA-256: `ae0354af71cc647b56e3b482ccba4bf57f9390ec76c1bfd0dcff5421a0490fbf`
  (matches build result `ex5_sha256` → .ex5 compiled from the current source, COMPILE_OK).
- Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9979_bandy-index-gap-fade-mr-index.md`
  (`g0_status: APPROVED`, R1–R4 all PASS).
- SPEC: `framework/EAs/QM5_9979_bandy-index-gap-fade-mr-index/SPEC.md` (present; ex-post generated).

## Card fidelity — mechanics verified correct

D1 index gap-fade mean-reversion. Hand-verified against the card body:

- Gap `= bar1.open - bar2.close` (mq5:95) — post-new-bar-close indexing of the card's
  real-time `open_today - close_prev`; same quantity.
- ATR significance gate `MathAbs(gap) < strategy_gap_atr_mult * atr14` with
  `QM_ATR(..., shift=2)` (mq5:98,103). In this EA's post-close frame, shift=2 is the card's
  Build-EA Note (a) "shift=1, no look-ahead past the prior bar" — verified correct, not an
  off-by-one.
- Long fades a down-gap `gap<0 && close>open && close>SMA200` (mq5:110); short mirrors
  (mq5:113) — matches the card's opposite-direction-close fade confirmation + 200-SMA regime.
- Anti-cluster 2-bar window (mq5:121,146); cat-SL `1.5*ATR(14)` via `QM_StopATR` (mq5:128,153);
  time stop 5 D1 bars (mq5:192-195) — all match the card.
- Gap-fill exit target `gap_origin_close = iClose(shift = entry_bar_shift + 2)` (mq5:212),
  recomputed each check. Verified algebraically it resolves to the *same* historical bar's close
  as the shift index advances one-for-one with elapsed bars — functionally equivalent to
  "captured at entry and held" (card Build-EA Note (e)); no drift, no off-by-one.

## Framework conformity — clean

- Include chain `#include <QM/QM_Common.mqh>`; all framework calls resolve
  (`QM_ReadBar`, `QM_ATR`, `QM_SMA`, `QM_StopATR`, `QM_FrameworkMagic`,
  `QM_TM_OpenPositionCount` all present under `framework/include/QM/`).
- Risk: setfiles carry `RISK_FIXED=1000, RISK_PERCENT=0`, `; environment: backtest`,
  `; risk_mode: FIXED`; `card_defaults_source` comment present → governed generation path.
- Magic = `ea_id*10000+slot` (`99790000+slot`) consistent across `magic_numbers.csv` and each
  setfile's `qm_magic_slot_offset` (e.g. SP500 slot 2 → `qm_magic_slot_offset=2`).
- News wired in OnTick via `QM_NewsAllowsTrade2` (temporal PRE30_POST30, compliance DXZ);
  MAE hook `QM_FrameworkTrackOpenPositionMae()` present; no ML libs; no hardcoded
  commission/swap/DST.
- **No dead inputs.** All six strategy inputs have real use-sites beyond declaration:
  `strategy_gap_atr_mult` (mq5:103), `strategy_regime_sma_period` (mq5:106),
  `strategy_atr_period` (mq5:98,128,153), `strategy_atr_stop_mult` (mq5:128,153),
  `strategy_time_stop_days` (mq5:192-195), `strategy_anti_cluster_bars` (mq5:121,146).
- Build guardrails: `validate_build_guardrails.py` PASS, `validate_spec_doc.py` PASS,
  `compile_ea.py` COMPILED (per build_result.json + `docs/ops/evidence/build_ea_qm5_9979_20260823.md`).

## Blocking defect — symbol universe exceeds the card's explicit, reasoned scope

The card is explicit and reasoned, not merely silent, about its universe. Card §R3 / "Target
Symbols": **"SP500.DWX (backtest), NDX.DWX, WS30.DWX. Daily (D1) bars only … FX/XAU/oil
deliberately excluded (overnight liquidity too continuous for meaningful gap signal)"**, and the
card thesis: *"FX overnight gaps are too small … to clear the 0.5×ATR threshold; this card is
index-specific by design."*

`framework/registry/magic_numbers.csv` instead registers **13** symbols
(`99790000+slot`, allocated 2026-08-17 "Codex governed allocator"):
`GDAXI, NDX, SP500, UK100, WS30, XAUUSD, EURUSD, GBPUSD, USDJPY, USDCHF, AUDUSD, USDCAD, NZDUSD`,
and 13 matching backtest setfiles were generated. Ten of those
(`GDAXI, UK100, XAUUSD, EURUSD, GBPUSD, USDJPY, USDCHF, AUDUSD, USDCAD, NZDUSD`) are outside the
card's authorized universe — including exactly the FX/XAU classes the card reasons should be
excluded. The registry/setfile machinery is internally consistent (13 slots ↔ 13 setfiles,
correct per-slot offset), so this is a **scope violation from a generic default universe**, not a
wiring bug. `validate_symbol_scope.py` returns `SINGLE_SYMBOL_OK` because it checks per-EA symbol
leakage, not card-scope — it cannot catch this.

This matches the independent finding already recorded in
`docs/ops/evidence/2026-08-23_review_ea_11300_9972_9979.md` (§QM5_9979).

## Minor observation (non-blocking)

- Anti-cluster state (`g_last_long_entry_bar_time` / `g_last_short_entry_bar_time`, mq5:52-53)
  is in-memory only and resets on restart; card Build-EA Note (d) requested persistence across
  restarts. Irrelevant to backtest determinism (no restart); a minor live-only concern. Note for
  the builder, not a blocker on its own.

## Recommendation (actionable — no OWNER decision needed)

RECYCLE to the builder: restrict the EA to the card's authorized universe — keep the
`SP500.DWX / NDX.DWX / WS30.DWX` slots and setfiles, retire the 10 out-of-scope magic rows
(`GDAXI, UK100, XAUUSD, EURUSD, GBPUSD, USDJPY, USDCHF, AUDUSD, USDCAD, NZDUSD`) via the governed
allocator, and remove the corresponding out-of-scope setfiles, then re-verify magic-registry /
resolver / setfile consistency. Do not backtest or promote the FX/XAU/GDAXI/UK100 slots against a
card that deliberately excludes them. (A card-universe *widening* would instead need an OWNER /
card-amendment decision — candidate-pool/card-universe definition is ROT — so the clean path is
to align the build to the existing card, not to expand the card.) The entry/exit/stop mechanics
themselves are correct and card-faithful; only the universe needs to be brought back into scope.
