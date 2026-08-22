# QM5_9113 Alpha Architect Alpha-Beta Velocity Filter Build Review Handoff

Date: 2026-08-22

Task: 9c481197-288f-4c07-9714-637ecc8bd624

Branch: gents/board-advisor

## Scope

Replace the inert QM5_9113_aa-ab-velocity skeleton with the OWNER-authorized G0 strategy-card implementation and submit it for independent review by Codex. This is build-only evidence; it asserts no pipeline or live verdict.

## Deterministic Preflight

- Approved card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_9113_aa-ab-velocity.md
- Card identity: a_id=QM5_9113, slug=aa-ab-velocity, g0_status=APPROVED, R1-R4 all PASS.
- Source citation: Henry Stern, "Trend-Following Filters: Part 1/2", 2020-12-29, Alpha Architect (de348b4-0fa7-5be1-baa8-09e9089b67b7).
- EA registry: active rows in ramework/registry/magic_numbers.csv for slots 0-12 (91130000 - 91130012).
- Active EA ID in ramework/registry/ea_id_registry.csv (row 471).

## Delivered Build Surface

- Faithful Alpha-Beta tracking filter recursive evaluation on D1:
  - Prediction: $\hat{x}_t = x_{t-1} + v_{t-1}$, $\hat{v}_t = v_{t-1}$
  - Innovation:  = \text{Close}_t - \hat{x}_t$
  - State update:  = \hat{x}_t + \alpha \cdot r_t$,  = \hat{v}_t + \beta \cdot r_t$ with fixed $\alpha = 0.29896$ and $\beta = 0.05295$.
- Closed D1 bar zero-cross long entry ( > 0 \land v_2 \le 0$).
- Exit on opposite zero-cross ( < 0$).
- Initial Catastrophic Stop Loss: .0 \times \text{ATR}(20, D1)$ via QM_StopATR.
- 120 D1 bar initialization warm-up and 20-day median spread entry filter (.5 \times \text{MedianSpreadD1}$).
- Strategy specification: ramework/EAs/QM5_9113_aa-ab-velocity/SPEC.md.
- All framework guardrails adhered to: qm_news_stale_max_hours = 336, backtest sets use RISK_FIXED=1000 and RISK_PERCENT=0.

## Focused Verification

1. python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_9113_aa-ab-velocity/QM5_9113_aa-ab-velocity.mq5 returned PASS with zero findings.
2. python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_9113_aa-ab-velocity --json returned SINGLE_SYMBOL_OK with 0 violations.
3. python tools/strategy_farm/build_gate_hardening.py --repo-root C:/QM/repo --ea-label QM5_9113_aa-ab-velocity returned PASS with 0 failures across all D2-D11 checks.

## Review Boundary

Code draft and specification are complete and validated statically. Leaving in REVIEW for independent Codex review and governed compilation in pipeline lane.
