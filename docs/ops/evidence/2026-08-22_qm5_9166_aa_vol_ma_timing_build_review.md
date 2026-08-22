# QM5_9166 Alpha Architect Volatility-Sorted MA Timing Build Review Handoff

Date: 2026-08-22

Task: 7124029-0e45-4137-be9e-49e31f685b6a

Branch: gents/board-advisor

## Scope

Replace the inert QM5_9166_aa-vol-ma-timing skeleton with the OWNER-authorized G0 strategy-card implementation and submit it for independent review by Codex. This is build-only evidence; it asserts no pipeline or live verdict.

## Deterministic Preflight

- Approved card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_9166_aa-vol-ma-timing.md
- Card identity: a_id=QM5_9166, slug=aa-vol-ma-timing, g0_status=APPROVED, R1-R4 all PASS.
- Source citation: Wesley Gray, PhD, "Technical Analysis may actually work!", 2011-05-02, Alpha Architect (de348b4-0fa7-5be1-baa8-09e9089b67b7).
- EA registry: active rows in ramework/registry/magic_numbers.csv for slots 0-12 (91660000 - 91660012).
- Active EA ID in ramework/registry/ea_id_registry.csv (row 517).

## Delivered Build Surface

- Monthly timing evaluation on completed D1 bars using 10-month SMA ( \times 21 = 210$ trading days) and 252-day realized volatility.
- Long entry when closed price is above 10-month SMA ($\text{Close}_1 > \text{SMA}_{210}$).
- Long exit on monthly rebalance when closed price falls below or equals 10-month SMA ($\text{Close}_1 \le \text{SMA}_{210}$).
- Initial Catastrophic Stop Loss: .0 \times \text{ATR}(20, D1)$ via QM_StopATR.
- 252 D1 bar initialization warm-up and 20-day median spread entry filter (.5 \times \text{MedianSpreadD1}$).
- Strategy specification: ramework/EAs/QM5_9166_aa-vol-ma-timing/SPEC.md.
- All framework guardrails adhered to: qm_news_stale_max_hours = 336, backtest sets use RISK_FIXED=1000 and RISK_PERCENT=0.

## Focused Verification

1. python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_9166_aa-vol-ma-timing/QM5_9166_aa-vol-ma-timing.mq5 returned PASS with zero findings.
2. python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_9166_aa-vol-ma-timing --json returned SINGLE_SYMBOL_OK with 0 violations.
3. python tools/strategy_farm/build_gate_hardening.py --repo-root C:/QM/repo --ea-label QM5_9166_aa-vol-ma-timing returned PASS with 0 failures across all D2-D11 checks.

## Review Boundary

Code draft and specification are complete and validated statically. Leaving in REVIEW for independent Codex review and governed compilation in pipeline lane.
