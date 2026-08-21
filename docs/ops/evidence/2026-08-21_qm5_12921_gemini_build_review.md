# QM5_12921 Gemini build review

- Review task: `d38222fd-9878-4d72-b1cf-c56cc03cc369`
- Source task: `63c95ae9-d593-403a-928b-c51ac9848a1b` (Gemini, retained in `REVIEW`)
- Reviewed artifact: `artifacts/qm5_12921_build_result.json`
- Located card: `D:/QM/strategy_farm/artifacts/cards_rejected/QM5_12921_qp-january-barometer-card.md`
- Verdict: **RECYCLE**

## Blocking findings

1. There is no current approved card of record. The only located card is in `cards_rejected`; the strict check independently warns that no unique approved/card-of-record file exists. A stale `g0_status` field inside a rejected artifact does not restore build authority.
2. The January opening price is calculated incorrectly. On the first observed January D1 transition, line 67 requests completed-bar shift 1 `PRICE_OPEN`, which is the prior December bar's open, not the first January trading session's open. This changes the card's primary January-return signal.
3. The card's primary mechanic is SP500, while the build creates active strategy setfiles for SP500, NDX, WS30, GDAXI, and UK100. That multi-index expansion is not authorized by the rejected source card.

These are card-authority and strategy-fidelity defects; no pipeline verdict is inferred.

## Checks that passed

- Strict static build check reports `PASS` with the two missing-card warnings in `D:/QM/reports/framework/21/build_check_20260821_152521.json`.
- Build guardrails, symbol-scope validation, and SPEC validation pass mechanically.
- Source SHA-256 matches the artifact: `ecf9d15035a8afbaa8daa0b795be545ff96e55173ee8fcac9d67cf8e31113f14`.
- EX5 SHA-256 matches the artifact: `72a3ea9eba7d08eee05e7f16ebac2f72f11f2dda82732d301c0d0ee838923112`.
- Generated setfiles include `qm_ea_id=12921`, `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `qm_news_stale_max_hours=336`.

## Focused verification

- Re-ran strict `build_check.ps1` static validation with compilation and set validation skipped.
- Re-ran build guardrails, symbol-scope validation, and SPEC validation.
- Recomputed MQ5/EX5 SHA-256 values, located the card across both approved and rejected stores, and inspected the January calendar transition and all setfiles.

No EA, card, setfile, registry, queue, terminal, or pipeline state was modified by this review.
