# FTMO M13 symbol-alias completion — 2026-09-06

Task: `4778daa7-8eda-43bd-bd45-d393d7068223`

The prior implementation and receipts in
`2026-09-06_ftmo_sleeve_alias_rebuild` correctly handled the four observed
`.DWX` versus plain-symbol attach failures. This completion closes the remaining
declared oil alias: registry `XTIUSD.DWX` and FTMO `USOIL.cash` now canonicalize
to the same instrument. Canonical equivalence is used both at registry
resolution and while checking same-magic open positions. Unrelated instruments
remain unequal and fail closed. The generator owns the same logic, and a
regeneration retained 18,154 rows, dropped zero, and retained registry SHA
`3835CD76FA81FA369D343EC46B6DA9D622BF6ACB0289E3430C1B690BD4FFB1D1`.

Verification covered `.DWX` to plain, `.DWX` to `.cash`, the XTIUSD/USOIL
cross-name alias, and a GBPUSD/EURUSD negative case. Seven focused resolver and
host-slot tests passed.

Only the four OWNER-scoped M13 sleeve binaries were rebuilt with FTMO
MetaEditor in `D:/QM/ftmo/compile_probe_sleeves_20260906_codex`; all four logs
reported 0 errors and 0 warnings. The factory inventory was not compiled or
modified. The exact four binaries were installed to the demo terminal's
`MQL5/Experts/QM_FTMO`, with pre-install binaries retained under
`_pre_codex_alias_20260906_2047Z`. Installed hashes match compiled hashes; see
`install_receipt.json`.

The existing four Load-dialog presets under `MQL5/Presets` were not rewritten.
Their hashes match the sealed profile copies under
`MQL5/Profiles/Presets/QM_FTMO_M13`, including the QM5_1537
`strategy_calendar_symbol=XAGUSD.DWX` input. No chart, account, running EA,
governor, collector, terminal process, or AutoTrading setting was changed.
Loading/re-attaching the newly installed binaries remains an OWNER action.

Status: implementation complete; leave in `REVIEW`.
