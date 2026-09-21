# Card-intake prescreen timeframe box — M30 amendment (2026-09-21)

- **Before:** `card_intake_prescreen._timeframe_allowed` accepted M5..M15, H1..H24, D1 (commit 33ef5d23f5, default-off prescreen).
- **Trigger:** `QM5_41485_ny-preopen-range-breakout-jpy` (H-V4, QM-RESEARCH-2026-0012 revision 2) freezes an **M30** chart because the
  framework news filter caches its verdict per chart bar; an H1 chart is not equivalent (critique d7ed93cd section 3.1, revision 2
  point 1). Prescreen result before the amendment: `REJECT [TIMEFRAME_OUTSIDE_BOX:M30]` (advisory; approve-card and intake-first-q02
  do not consult it).
- **Decision (Fable):** M30 is a standard MT5 timeframe between the existing M15 and H1 bounds; its omission was a gap of the
  2026-09 Edge-Lab box, not a criterion (no evidence-integrity, provenance, look-ahead, holdout, determinism or data-validity rule
  is touched — OWNER-DEC-D3-20260915 section 30 scope). Box now M5..M30. Rollback: revert this one line.
- **Test:** `tools/strategy_farm/tests/test_card_intake_prescreen_timeframe_box.py`.
