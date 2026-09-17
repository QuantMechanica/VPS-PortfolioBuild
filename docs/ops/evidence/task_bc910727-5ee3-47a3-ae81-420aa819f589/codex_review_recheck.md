# Codex re-review: QM5_35002

- Review task: `bc910727-5ee3-47a3-ae81-420aa819f589`
- Gemini source task: `da27d5d7-b9e2-44c7-892e-7253154a7ba7`
- Disposition: `CHANGES_REQUIRED`
- Router handoff: remain in `REVIEW`; no pipeline handoff

The 2026-08-21 card amendment made the directional DI rules symmetric and
fixed the stop at exactly 50 pips. The unchanged source already implements the
symmetric DI predicates, but it still does not implement the corrected stop or
the required unblocked trailing-management lifecycle. The router-listed review
skills are unavailable; Codex performed the mandatory review directly.

## Bound inputs

- Approved card SHA-256: `b71d0058e9a89edbdc6584338218898a88756c96f39e84b7e4f8d2c76bedab95`
- MQ5 SHA-256: `ca605b2e8b4312db36acb641311cb3ad1359c516c3929f5a6a02a2367d30a8be`
- EX5 SHA-256: `86b08bc27aa75a5caf03e227a3a1a5b0477a3b33c189edb02f53dfc4af9c411e`
- SPEC SHA-256: `54c42244ce664d8ef38678d87a1546345480cd0867b17dedbc77fa54a3d955b2`
- Active magic rows: `350020000`, `350020001`, `350020002`

## Blocking findings

1. The amended card requires a hard 50-pip stop and a 100-pip target (card
   lines 98-101). Source lines 131-139 still clamp 50 pips into an invented
   `[0.5 ATR, 3.5 ATR]` corridor, then size both SL and TP from the changed
   distance at lines 147-164. This is strategy drift.
2. The card states that trailing management runs unblocked by entry filters.
   `OnTick` returns on `Strategy_NoTradeFilter()` at source line 254 before
   invoking `Strategy_ManageOpenPosition()` at line 256. Spread or rollover
   conditions can therefore suspend the required trailing stop.

The corrected DI conditions are present at source lines 116-124 and 141-156;
that prior ambiguity is resolved. No amended-card rebuild or new RESULT packet
was supplied, and the MQ5/EX5 hashes remain those of the earlier failed review.

## Focused verification

- Build guardrails: PASS over four package files with
  `qm_news_stale_max_hours <= 336`.
- SPEC validation: PASS.
- Set risk: all three setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Registry: EA row is active and all three magic rows are active.
- Target EA directory: clean in Git.
- Compilation was not rerun because no source repair exists. The next build
  must use `COMPILE_EA`, include focused stop/management tests, and provide a
  new bound RESULT packet for Codex review.

Structural validation does not override either semantic defect. Pipeline
verdicts remain solely with the pipeline.
