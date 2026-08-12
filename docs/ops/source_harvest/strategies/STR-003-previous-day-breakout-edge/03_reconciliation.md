# STR-003 — Spec reconciliation (claude 01 vs codex 02), 2026-07-24

## Convergent

H1 closed-bar; body-close strictly beyond level (wick/equality never counts);
first qualifying close per level per trading day only; entry at next-bar first
tick; fixed SL 12.5 / TP 25 pips from ACTUAL fill; one position per symbol; no
session filter (author's London = preference, no hours given); no scale-ins;
fundamentals overlay → framework news blackout, no directional exception;
restart replay of current-day bars to rebuild consumed flags; NO extra exits
(no opposite-break exit, no rollover exit — deliberate difference vs
QM5_10007, which added tiny-range skip + opposite-break/rollover exits and
died at Q04).

## Conflicts and resolutions

1. **Trading-day anchor.** Claude: broker-D1 bars (house NY-close; 1h summer
   drift vs author's fixed 22:00 GMT). Codex: cyclic [22:00, 22:00) UTC day
   computed from H1 bars, exact year-round. RESOLVED → codex (tie-break 1,
   source verbatim: "trading day starts at 10 PM GMT"). Implementation uses
   the framework's existing broker↔UTC conversion primitive (news-filter
   convention) for bucketing closed H1 bars; the ≤1-bar ambiguity in the two
   DST switch weeks is documented, not modeled away. Prev-day high/low =
   max(High)/min(Low) over the preceding complete cyclic day's H1 bars,
   frozen until the next 22:00 UTC roll.
2. **SMA(34) filter default.** Claude: ON (author uses it). Codex: OFF (OP
   rules label it optional). RESOLVED → codex, default OFF (tie-break 1: the
   OP's numbered core rules govern the baseline; author preference = card
   variant; Q03 sweep can enable).
3. **Consumed-on-block.** Codex: the first break consumes the day-direction
   even when entry is blocked (news/position/filter) — no late chase. Claude
   spec was silent. RESOLVED → codex (tie-break 2, more restrictive).
4. **Hook placement of position/consumed checks.** Codex had them in
   NoTradeFilter; V5 skeleton calls NoTradeFilter before Manage → convention:
   EntrySignal owns them (tie-break 3; harmless here since Manage is empty,
   but fleet convention consistency wins).
5. **Pip definition.** Codex fixed 0.0001; final spec uses the framework pip
   helper (identical on the 5-digit cohort, no hand-rolled constant).

## Net result

The final spec is codex's baseline with claude's hook-placement convention
and framework-primitive substitutions. Both specs' variant lists (ATR stops,
breakeven, 3-day levels, M30, scale-ins) stay card-documented, unbuilt.
