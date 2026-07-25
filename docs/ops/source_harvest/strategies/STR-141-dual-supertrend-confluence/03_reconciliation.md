# STR-141 — Spec reconciliation (Claude 01 vs Codex 02)

Date: 2026-07-25. Tie-breaks per tranche protocol.

## Agreements

H1 (ledger placeholder, both flag it); EMA 99 — prose wins over the
code fragment's 9 (both; 9 = labeled variant only); "RSA" = RSI typo
(both); strict confluence: fast-ST flip + slow already aligned + EMA99
slope + RSI9 vs 50 + ADX9 > 25; SOURCE-FAITHFUL ASYMMETRY preserved
(long = fast 0.9 flip, short = slow 1.8 flip; stop lines likewise —
both specs, flagged); exit on either-ST color flip OR EMA slope
reversal, next bar; no TP/time exit; hard server stop from the
prescribed ST line, reject invalid-side geometry (never synthesize).

## Resolved differences

1. **Supertrend definition.** Claude: "classic recursion" (underspec).
   Codex §3: full deterministic spec — Wilder ATR(7) with mean seed,
   basic/final band carry rules, direction recursion, explicit seed
   bar, warmup — "part of the strategy identity" → **codex adopted**
   verbatim (STR141-I3).
2. **Stop management.** Claude: static initial stop. Codex rule 7:
   ratchet the server stop to the current prescribed ST line per
   completed bar, tighten-only — faithful to "stop-loss at the
   Supertrend level" (the line trails by construction) → **codex
   adopted** (STR141-D1).
3. **Cohort.** Claude: EURUSD/GBPUSD. Codex: 7 liquid majors (EURUSD,
   GBPUSD, USDJPY, USDCAD, AUDUSD, USDCHF, NZDUSD .DWX), declared
   research cohort (STR141-C1; QM5_20127 Sisyphus 7-major precedent)
   → **codex adopted**.
4. **"Already aligned" definition.** Codex STR141-I4: the
   non-triggering ST must hold the direction on bars 2 AND 1
   (simultaneous dual flip ≠ "already") → adopted.

## Outcome

Final spec = codex 02 unchanged. R1 caveat (author admits untested;
"not a system until there's evidence") recorded in the card. No
escalation.
