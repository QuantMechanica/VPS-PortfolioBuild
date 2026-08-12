# STR-143 — Spec reconciliation (Claude 01 vs Codex 02)

Date: 2026-07-25. Tie-breaks per tranche protocol.

## Agreements

H1; SMA(100/200, close); armed-episode state per crossover; trigger =
K crossing OUT through the 25/75 level (not a K/D cross — both,
FLAG STR143-I2); first instance per episode only, trigger consumes
the arm even on gate rejection; entry next bar; SL 150 / TP 300 pips
server-side from fill; BE move to fill after +150 pips favorable;
no recross/stoch/time exits, no partials.

## Resolved differences

1. **Stoch price field.** Claude: unspecified. Codex: STO_LOWHIGH
   (the conventional default for a bare "Stochastic (14,3,3)" citation)
   → **codex adopted** (STR143-I1).
2. **Same-bar ordering.** Codex STR143-I3: a stoch boundary cross on
   the SMA-cross bar itself cannot trigger (strictly-later bars only)
   → adopted.
3. **BE semantics.** Claude: tick-based +150. Codex STR143-I4:
   closed-bar high/low ≥ fill ± 150 pips latches BE; stop moved next
   bar, tighten-only; broker fills before the update are final (no
   intrabar reconstruction) → **codex adopted** (deterministic,
   testable).
4. **Cohort.** Claude: EURUSD + GBPUSD (test-design). Codex: EURUSD
   only (the single illustrated symbol; STR143-C1 strict). Tie-break 3
   (conservative baseline) → **codex adopted**: EURUSD.DWX only;
   multi-pair = labeled variant.

## Outcome

Final spec = codex 02 unchanged. The blog's "looking good" = proposal-
stage narrative (card R1). No escalation. Overlap: distinct from
QM5_20138 (stoch-zone H4 metals/FX) and QM5_20143 (EMA6/17-campaign
M5) — different MA sets, triggers, exits.
