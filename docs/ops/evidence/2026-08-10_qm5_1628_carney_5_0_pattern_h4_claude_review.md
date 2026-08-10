# QM5_1628 carney-5-0-pattern-h4 — Claude code review

- **Task:** review_ea `3c46e814-d8b2-429c-9a15-d7660a3376d1` (source_agent: gemini, source_execution_backend: agy)
- **Card:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1628_carney-5-0-pattern-h4.md`
- **Reviewer:** Claude, 2026-08-10
- **Verdict:** NEEDS_FIX (3 preflight-blocking gaps + 1 mechanical mismatch on the structural SL + 1 missing exit trigger); left in REVIEW per Hard Rule "Codex review is mandatory before acceptance" — not self-approved to APPROVED/PIPELINE.

## Mechanical verification (independently re-run, not trusted from source_verdict)

- `.mq5`/`.ex5` present, canonical `QM5_1628_carney-5-0-pattern-h4` naming correct.
- `magic_numbers.csv` has all 4 rows (16280000-16280003, EURUSD/GBPUSD/USDJPY/XAUUSD.DWX, `reserved_by: Gemini`) — consistent with card's 4 `target_symbols`. No collision.
- Source build result (`D:/QM/strategy_farm/artifacts/builds/c1c715e2-d00f-4bfe-b82b-ff12ddc65b3e.json`): `build_check_passed: true`, `compile_succeeded: true`, `smoke_result: "deferred_p2_smoke"` — sanctioned pattern, informational only.

## Finding 1 [block]: no `ea_id_registry.csv` row

Same defect as QM5_1630 (companion review this cycle) and QM5_1627 (Codex's independent
review, finding 6) — no active row for ea_id 1628 in `framework/registry/ea_id_registry.csv`.

## Finding 2 [block]: `SPEC.md` missing

Same defect class as QM5_1630/QM5_1627 — `framework/EAs/QM5_1628_carney-5-0-pattern-h4/`
has no `SPEC.md`; `validate_spec_doc.py` would FAIL, blocking Q02 promotion.

## Finding 3 [block]: setfiles missing entirely

Same defect class — `sets/` is empty, build result's `setfiles_generated: []` confirms
it. Q02 phase runner cannot run without them.

(See the companion QM5_1630 review for the note that findings 1-3 recur identically
across both `review_ea` tasks routed this cycle — likely a systemic gap in the current
Gemini/agy build path rather than two independent one-offs.)

## Finding 4 [block]: stop-loss anchored to the D-pivot, not the C-pivot the card specifies

Card `Stop Loss` section (explicit, twice): *"Structural: SL = beyond C-pivot by
0.5 × ATR(14) ... if price breaches C, the 5-0's 'literal-50% pullback' thesis is
broken."* The stop-loss anchor is unambiguously the **C-pivot**.

The implementation instead anchors to the **D-pivot** (the entry price itself):

```
// Strategy_BuildEntry(bullish, c_price, d_price, zone_edge, atr, req):
double sl = bullish ? (d_price - strategy_sl_atr_mult * atr)
                    : (d_price + strategy_sl_atr_mult * atr);
```

(`QM5_1628_carney-5-0-pattern-h4.mq5:213-214`). Called as
`Strategy_BuildEntry(true, c.price, d_bar.low, zone_low, atr, req)`
(`...mq5:291`) — `c_price` (the actual C-pivot value) is passed in but never used for
the SL calculation; only `d_price` is used.

**Why this matters:** by construction, D sits at the 50%-retracement-of-BC entry zone —
i.e. D is *close to* the entry price, while C is the far end of the BC leg (materially
farther away, per the card's own 1.618-2.240 BC/AB extension ratio). Anchoring SL near
D instead of C produces a substantially *tighter* stop than the card's approved
structural-invalidation design, which will change the trade's realized R distribution
and stop-out frequency relative to what R2/R4 evaluated. This is the same class of
defect independently found in this session's QM5_1355 review (wrong-bar SL anchor) —
worth flagging as a recurring pattern across Gemini-authored EAs this batch: SL/TP pivot
references get mis-wired to the nearer/more-convenient point instead of the card's
specified structural anchor.

**Fix:** use `c_price` instead of `d_price` in the SL calculation at
`QM5_1628_carney-5-0-pattern-h4.mq5:213-214`.

## Finding 5 [warn]: card's independent +1.5×ATR breakeven trigger is missing

Card `Exit` section: two independent triggers — *"at +1.5 × ATR(14) profit, move SL to
break-even-plus-spread; at C-pivot-50%, close 50% of position."* These are two different
price levels (a fixed ATR-multiple from entry vs. the TP1 harmonic level) that will
rarely coincide.

The implementation collapses both actions onto a single trigger — reaching TP1
(`g_active_tp1_price`, 50% of the C-D leg from D) fires both the partial close *and*
the BE-move together (`Strategy_ManageOpenPosition`, lines 424-448). There is no
`strategy_*atr_mult` input or any code path implementing an independent +1.5×ATR
breakeven trigger — it is simply absent. Practical effect: if TP1 is farther from entry
than 1.5×ATR (common when the C-D leg is wide), the position rides fully exposed for
longer than the card intends before any protective SL move happens.

**Fix:** add an independent BE-move check gated on `+1.5×ATR(14)` open profit
(same pattern as the sibling QM5_1630 build's `strategy_trailing_atr_mult=1.5` BE
trigger in this same batch), separate from the TP1 partial-close trigger.

## Card-fidelity checks that passed (no defect)

- X-A-B-C-D pivot detection via ZigZag-equivalent fractal-pivot scan
  (`Strategy_CollectPivots`/`Strategy_FractalHigh`/`Strategy_FractalLow`), gated
  `QM_IsNewBar()`-once-per-bar and bounded by `strategy_scan_bars`/`strategy_max_xd_bars`
  — reasonable, bounded-cost implementation of the card's `zigzag_depth/deviation/backstep`
  pivot spec.
- Ratio gates: AB/XA ∈ [1.130, 1.618], BC/AB ∈ [1.618, 2.240], CD 50%-of-BC ± 2% tolerance
  (`strategy_cd_tolerance=0.02`) — all match card exactly.
- Minimum pattern size (XA ≥ 2.0×ATR), D-price-within-0.3×ATR-of-theoretical-level,
  candle confirmation at D, D1 SMA(200) with-trend gate — all match card.
- Time-stop 48 H4 bars via `iBarShift(_Symbol, PERIOD_H4, PositionGetInteger(POSITION_TIME), false)`
  (`Strategy_ExitSignal`, lines 458-461) — **correctly restart-safe**, unlike the
  companion QM5_1630 build's hand-rolled bar counter (see that review's Finding 5).
- Reverse-pattern exit, cooldown 12 bars, spread filter 0.3×ATR, one-position-per-magic,
  no raw `iATR/iMA/iRSI/iMACD/iADX/iBands` calls — all match card / framework convention.
