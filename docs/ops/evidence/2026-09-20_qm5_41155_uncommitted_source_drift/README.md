# QM5_41155 uncommitted source drift (2026-09-20)

Found after the 15:23Z reboot: `QM5_41155_gbpjpy-carry-unwind-crisis-momentum.mq5` and two setfiles modified in the
canonical checkout at 09:02Z (exit gate refactored to `QM_IsNewCalendarPeriod`, setfile `build_hash` headers changed),
tracked `.ex5` byte-identical to the committed one, no COMPILE_EA row, no agent task, no orchestration log naming the
change (Codex 09:00Z/12:45Z/14:30Z/14:45Z sessions only reported it as the dirty file). The drift blocked
`repo_dirty_build_guard` for six hours (86 builds pending).

Disposition (Fable): diff preserved as `working_tree.patch`, working tree restored to the committed source so the
committed `.mq5` matches the committed `.ex5`; review ticket opened — re-apply only through the governed path
(source-repair authority → enqueue-compile → COMPILE_OK → intake) with an author and a receipt.
