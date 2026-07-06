# DL — FTMO challenge-sprint mandate: scalping + scale-in/grid/martingale (OWNER, 2026-07-06)

**Status: OWNER-DIRECTED (chat 2026-07-06 evening).** Verbatim intent: find
scalping ideas via Antigravity (video mining); scale-in, grid and martingale
are PERMITTED — **FTMO track only** — to win challenges FAST; hard cap:
**maximum 1% account risk IN TOTAL per symbol** (worst case across the entire
position stack / all grid levels).

## Scope and guardrails (binding for every card/EA under this mandate)

1. **FTMO-track only.** The DXZ live book keeps the existing conservative
   regime (no grid/martingale there). Cards under this mandate carry flag
   `ftmo_challenge_sprint` and must NOT enter DXZ admission.
2. **Σ-risk ≤ 1% per symbol:** the worst-case loss with ALL levels/adds open
   and every stop hit must be ≤ 1% of account equity. Grid/scale-in must be
   BOUNDED (max levels fixed, worst case computable at OnInit — the
   QM_GridValidateConfig shape). Unbounded martingale remains forbidden;
   bounded martingale-spacing inside the 1% envelope is allowed.
3. **FTMO legality:** no latency/tick arbitrage, no cross-broker HFT; grid/
   martingale/scalping are permitted by FTMO terms. News-window compliance
   binds funded (E4 live enforcement now exists), not the challenge.
4. **Commission physics (non-negotiable):** FX scalping dies at the ~$45/lot
   round-trip class; scalping candidates target INDEX (US100/GDAXI/WS30
   ≈ $4.4) and metals/energy first. High-frequency FX ideas need explicit
   commission survival evidence at Q04/DL-072 like everything else.
5. **Pipeline unchanged:** cards go through the normal G0 (R1-R4 citations,
   deterministic rules) and the full Q02-Q08 cascade. The mandate loosens
   MECHANISM constraints (grid/martingale/scale-in), not evidence standards.
6. **Prerequisite before first grid build:** QM_TM_Grid hardening (audit
   register F6/F7 + B5: untrack-only-on-close-success, restart state rebuild
   from open positions, volume-step normalization, reject worst-case=0
   validation) — the module has 0 users today and ships fixed with the first
   adopter.
7. Kill-switch stack (−3% daily flatten + state persistence + book tag) wraps
   these EAs like every FTMO leg; the 1%/symbol cap sits INSIDE the −3%
   daily budget (≥3 symbols' full stacks must fail same-day to trip it).

## Research lane

Antigravity (video_analysis) tickets issued 2026-07-06: (a) index/metal
scalping with exact mechanical rules, (b) bounded scale-in/grid/martingale
mechanics with computable worst case. Claude mechanizes deliverables into
cards (agy extracts, never designs — standing role contract).
