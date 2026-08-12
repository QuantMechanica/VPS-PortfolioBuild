# STR-103 — Reconciliation (Claude spec ↔ Codex spec)

## Consensus
W55(W1)/D21(D1)/H34(H4) SMA alignment on CLOSED bars; touch-and-close H4 entry
(Low≤SMA34≤ range, Close beyond); entry after H4 close; ATR-offset stop beyond
SMA34; SMA-following ratchet trail per H4 close; open target (no TP); re-entry on
fresh full signal; 8 source pairs; 1%/trade live intent; framework overlay.

## Divergences → decisions

1. **Staged-alignment fallback (first post) vs "fresh signal" (post #105).**
   Claude implemented the first-post staged entry; Codex found the author's later,
   more restrictive clarification: "if you're late to the action … wait for
   confirmation of a new signal". → **Codex wins (source's final ruleset +
   restrictive):** NO staged entry. Alignment must already hold when the H4
   touch-and-close bar prints; otherwise wait for a fresh touch signal.
2. **ATR "display High/Low" lookback.** Claude proposed 100 bars (chart proxy);
   Codex surfaced the only in-thread concrete number: the community EA's
   max/min of ATR(14) over **30 H4 bars** (post #70). → **30 bars** (tie-break 1:
   the thread's own concretization beats an invented proxy). Recorded as
   in-thread precedent, not author-stated.
3. **Stop cap.** Codex found post #40 "I'm setting the stop to a max of 100
   [pips]" (scope ambiguous). → **Adopt globally: entry-to-stop distance capped at
   100 pips** (tie-break 2: restrictive risk variant).
4. **Trail definition drift (post #27 at-SMA vs #99/#100 offset-behind-SMA).**
   Both read final practice = offset trail. → offset-behind-SMA34, ratchet-only,
   updated per closed H4 bar.
5. **Weekend.** Source holds over weekends (post #108); company No-Weekend
   directive + framework Friday-close override. → **Friday-close stays ON** —
   documented fidelity deviation (compliance beats source).
6. **W1/D1 closed-bar semantics.** Both chose closed higher-TF bars (no-repaint)
   while noting the author likely used forming bars live. → closed bars; fidelity
   note in card.
7. **W1/D1 flip while open:** no forced exit (both; source: trailing stop only).
8. **Touch mechanics:** `Low[1] <= SMA34[1] && Close[1] > SMA34[1]` (long);
   approach direction not constrained (not stated).

## Frequency
Both: ~12–35/yr/symbol; above floor, episodic clustering in aligned trends.
