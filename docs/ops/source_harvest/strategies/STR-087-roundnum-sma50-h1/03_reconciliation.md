# STR-087 — Spec reconciliation (Claude 01 vs Codex 02)

Date: 2026-07-25. Tie-breaks per tranche protocol.

## Agreements

- H1; SMA(50, Close); 25-pip grid at .000/.250/.500/.750 endings;
  regime = close vs SMA (equal → no setup); stop entry at nearest
  forward line ± 3 pips; SL 30 / TP 50; BE ratchet +10 pips → BE+1
  (BE+5 and +15 trigger = variants); one pending/position per magic;
  pending cancel on regime flip / geometry loss / replacement by newly
  nearest line; NO bar expiry, NO time exit, NO spread veto, NO
  opposite-grid gate (the QM5_10039 additions stay excluded per the
  G0_REVIEW_T6 contest); sideways 25/25 mode = unbuildable-as-baseline
  variant; H4/D1-100-pip family and MA200/EMA = variants.

## Resolved differences

1. **Cohort.** Claude: EURUSD/GBPUSD (from chart examples). Codex:
   GBPUSD + EURJPY. VERIFIED verbatim (00_source.md line 69: "Pair
   that i Trade usually GPBUSD & EURJPY"); EURJPY.DWX history 2017-2026
   present on T1-T10 (dwx_symbol_history_ranges.csv:230) → **codex
   adopted**: GBPUSD.DWX + EURJPY.DWX.
2. **MA-proximity threshold.** Claude: 10 pips provisional. Codex: 5
   pips baseline with {5,10,15} sensitivity. Source gives NO number
   ("too close"). Both are projections; final default = **10 pips**
   (midpoint of the declared family, matching the author's 10-15-pip
   BE band scale), FLAGGED PROVISIONAL; {5,15} = Q03 sweep values.
   Tie-break 3.
3. **Post-SL re-entry.** Claude: block the same line until regime
   change. Codex: minimal next-closed-bar evaluation, no auto-reverse.
   Source (p.3): "i wont buy straight away when my SL hit" — the
   minimal next-bar wait IS the verbatim reading; the line-block is an
   unsourced strengthening. Tie-break 1 → **codex adopted**; Claude's
   line-block retired.

## Outcome

Final spec = codex 02 with MinLineToSmaPips default lifted 5 → 10
(flagged). No escalation needed.
