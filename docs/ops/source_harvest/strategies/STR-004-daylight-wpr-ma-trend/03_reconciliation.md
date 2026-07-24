# STR-004 — Spec reconciliation (claude 01 vs codex 02), 2026-07-24

## Convergent

M15 closed-bar; indices cohort NDX/GDAXI; green = SMMA(5) close; red = the
same SMMA displaced +5 (both specs' formulations are mathematically identical:
native iMA ma_shift=5 read at shift 1 ≡ unshifted SMMA read at shift 6 — the
implementation reads ONE unshifted handle at [1] and [6]); WPR(14) with
in-EA SMMA(8)/SMMA(21) on the WPR series (no indicator-on-indicator handle);
sub-window daylight = directional separation ≥ 4.0 WPR units (source p.17);
exit = source option 2 (main-MA recross) as a LEVEL condition (restart-safe),
no TP; emergency ATR stop mechanizes "emergency stops far away" (flagged
unsourced by both); one position, no stacking, opposite signal ≠ reversal;
no session, no MTF.

## Conflicts and resolutions

1. **Main-chart daylight.** Claude: gap>0 with 2-bar persistence. Codex: gap ≥
   1 trade tick, no persistence, plus FULL-CONDITION EDGE TRIGGER (false on
   shift 2 → true on shift 1). RESOLVED → codex (tie-break 3: the edge trigger
   is the cleaner anti-churn device, adds no sweepable parameter, and the
   author's "jump in and out of the same trend multiple times" supports
   condition-edge re-entries over a strict close-cross event).
2. **Entry trigger.** Claude: literal close-cross event. Codex: full-condition
   edge (subsumes the cross; also fires when daylight forms while price is
   already beyond green). RESOLVED → codex (same rationale; after stop-out the
   condition must go false→true again — natural re-entry throttle).
3. **Emergency ATR multiple.** Claude 3.0 vs codex 4.0. RESOLVED → 4.0
   (tie-break 1: "far away" — farther is more faithful to an emergency-only
   stop; risk is normalized by RISK_FIXED sizing anyway). ATR period 14 both.
4. **SMMA seed depth.** Codex: "enough warm-up" (unfixed). Claude: fixed
   400-bar seed depth for determinism/restart-identity. RESOLVED → claude
   (tie-break 3: unfixed seeding makes live-vs-restart values path-dependent;
   fixed depth is deterministic). Input `strategy_smma_seed_depth = 400`.
5. **Exit hook placement.** Codex: ExitSignal (skeleton's designed slot,
   closes all magic positions). Claude: Manage. RESOLVED → codex — ExitSignal
   with an internal closed-bar read (level condition at shift 1); Manage stays
   empty except protection reconciliation.
6. **Hook placement of position checks:** EntrySignal owns them (fleet
   convention; NoTradeFilter must not starve Manage/Exit paths).

7. **WPR SMMA colour mapping (decisive).** Claude's 01 argued red=slow(21) by
   main-chart colour analogy → short = fast below slow. Codex read red=8
   literally → short = fast(8) ABOVE slow(21). The validated SOURCE_LEDGER
   row binds the colours explicitly (Red=8-SMMA, Blue=21-SMMA, from the
   original harvest chart read) → **codex wins**; C3 is a pullback-depth
   condition (see 04_spec_final C3 note), not trend alignment. Claude's
   objection withdrawn against ledger evidence.

## Variant register (card)

WPR-slope exit (opt 1), WPR recross (opt 3), ADR/ATR target (opt 4), M5
indices variant, −50 trend filter, add-to-winner stacking, Roadmap hybrids —
documented, unbuilt. QM5_9956 (H4 FX approximation with invented thresholds,
Q02-FAIL NDX) is the prior non-faithful attempt; this is the faithful M15
indices baseline.
