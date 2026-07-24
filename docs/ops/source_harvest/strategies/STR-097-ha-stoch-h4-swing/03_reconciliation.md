# STR-097 — Reconciliation (Claude spec ↔ Codex spec)

## Consensus (no action)
Indicators/params (HA, SMA100 close, Stoch 8,3,3 low/high), H4 closed-bar
discipline, SMA-side trend gate, entry at next-bar open after signal close,
mirror short, no pyramiding, framework compliance overlay (news, Friday-close),
50-pip initial SL.

## Divergences → decisions

1. **Exit package.** Claude picked variant 2 (50/50 + BE@25) as "most
   deterministic"; Codex found post #16 (PDF p.6): the author SELECTED variant 1
   and quantified the trail — "trail the stop behind the second to last heiken
   ashi" + "exit on a HA change against the trade" (post #8). → **Codex wins,
   tie-break 1 (source literal):** variant 1: 50p initial SL, NO TP, per-H4-close
   trail to beyond HA bar[2] extreme (long: below its low; short: above its high),
   ratchet-only, plus market exit when a CLOSED HA candle flips colour against the
   trade. Variants 2/3 documented as source alternatives, not built.
2. **Stoch cross timing.** Claude allowed cross on b1 or b2; Codex strict cross on
   b1 (`K[2]<=D[2] && K[1]>D[1]`). → **Strict b1** (tie-break 1+3: source couples
   flip and cross in one trigger sentence; stricter and simpler).
3. **Stoch zone.** Both flag "towards the bottom" as unquantified; Claude proposed
   <50, Codex refused to pick. → **Decision: %D[1] < 50 (long) / > 50 (short)** —
   the least-inventive deterministic reading of "bottom/top half of the window";
   explicitly NOT 20/80 (never stated in source). Recorded as reconciliation
   choice in the card.
4. **Pullback length.** Codex "one or more red"; Claude ≥2. → **≥2 consecutive
   red HA candles immediately before the flip bar** (source's plural "candles";
   stricter reading).
5. **"Smooth trend" / zigzag.** Both agree it is not mechanizable. → No additional
   slope filter; the SMA-side gate + pullback structure is the mechanical trend
   definition. Recorded as fidelity limitation.
6. **Trail anchor semantics.** "Second to last heiken ashi" → literal bar-index
   reading HA[2] at each H4 close (Codex's "closest mapping"), no buffer, never
   widen. Precedence: closed-HA-flip exit fires first (market close), else trail.
7. **Price vs SMA:** ordinary Close (source "100 sma close"); stoch MA method =
   platform default SMA — recorded choices. HA = platform-standard formula
   (author's prose approximation does not override).
8. **Weekend:** source silent; framework Friday-close stays ON (company
   No-Weekend directive; compliance overlay, documented deviation class).

## Frequency
Both estimate ≥12 trades/yr/symbol on H4 (source: ≥5/week across watchlist).
Above Q02 floor; episodic risk noted.
