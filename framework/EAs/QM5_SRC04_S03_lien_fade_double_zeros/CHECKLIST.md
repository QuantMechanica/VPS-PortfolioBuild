# DL-036 Checklist - QM5_SRC04_S03 lien-fade-double-zeros

- timestamp_utc: 2026-05-06T20:55:03Z
- compile_pass: True
- errors_zero: True
- warnings_zero: True
- compile_log: C:\QM\repo\framework\build\compile\20260506_185454\QM5_SRC04_S03_lien_fade_double_zeros.compile.log
- card_ref: strategy-seeds/cards/lien-fade-double-zeros_card.md
- review_gate: DL-036
- state: READY_FOR_CTO_REVIEW
- task_alignment: QM-00082 Path A (revert variant defaults to card-faithful baseline)
- revert_evidence:
  - ea_impl: stage_max_distance_pips=50.0; order_expiration_minutes=60; relaxed_entry_logic=false; directional_round_selection=false; use_half_step_levels=false; entry_at_round_mode=false
  - clean_ref_commit: a61fccd9
  - research_note_ref: QUA-740 comment 57cc35c2 (2026-05-06 17:48Z)