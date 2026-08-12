# STR-002 — Spec reconciliation (claude 01 vs codex 02), 2026-07-24

## Convergent (no discussion needed)

Both specs independently agree on: H1 closed-bar discipline (shifts ≥1);
standard HA recursion with (O+C)/2 seed; EMA(100) close trend gate read at
shift 1; flip = shift-2 colour ≠ shift-1 colour (single flip, no pullback-length
requirement); session = signal formation only, 06:00 GMT + 9h default (both
picked 9 from "8-9"); entry at next-bar first tick; A/B close at +1R, C
trailed to HA extreme per new closed bar, never widened; NO opposite-flip
market exit (trailing stop realizes the trend-change exit — deliberate
difference vs QM5_9977's invented flip-exit); one campaign per symbol, no
re-entry while any own position exists; netting account → ONE position with
2/3 partial close at 1R + 1/3 runner.

## Conflicts and resolutions

1. **SL at HA extreme vs 1 tick beyond.** Codex: extreme ± 1 trade tick
   (mechanizes "above/below"). RESOLVED → codex (tie-break 1, verbatim
   fidelity; consistent with QM5_20098's 1-tick convention).
2. **Session check placement.** Codex put the session gate in
   Strategy_NoTradeFilter. The V5 skeleton calls NoTradeFilter BEFORE
   ManageOpenPosition — an out-of-session block would freeze trailing, which
   codex's own prose forbids ("positions remain managed outside it").
   RESOLVED → claude: session gate lives in EntrySignal only (tie-break 3,
   framework-contract correctness). Same for position-cardinality checks.
3. **Campaign risk: 3×1% vs 1% total.** Source risks 1% per order (3%
   campaign). Codex flags it as a house-risk decision and forbids silent
   reinterpretation; claude spec set 1% total. RESOLVED → **1% total campaign
   risk** under tie-break 2 (risk → more restrictive) — an explicit,
   documented decision, not a silent one: RISK_FIXED sizes the single netted
   position; A/B/C are volume fractions (1/3+1/3+1/3) of that position. The
   source's 3×1% remains a card-documented variant requiring an OWNER risk
   decision if ever wanted.
4. **GMT handling.** Both: fixed UTC, no invented DST. Implementation uses the
   framework's existing broker↔UTC conversion primitive (as used by the news
   filter) — no new offset model.
5. **Tranche fractions input.** Claude had A/B fraction inputs; codex fixed
   equal thirds (source "same lot size"). RESOLVED → codex: equal thirds,
   no fraction inputs (fewer invented parameters).

## Restart-safety agreement

Reconstruct campaign state from position volume vs initial volume (volume
reduced ≈ 1R partial done → trailing active) + deal history; no files.
