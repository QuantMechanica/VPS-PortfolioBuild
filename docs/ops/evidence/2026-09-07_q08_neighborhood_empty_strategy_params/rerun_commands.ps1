# REVIEW-ONLY COMMAND MANIFEST. Do not dot-source or auto-execute.
# These append-only operations require CEO/OWNER review. Historical rows remain immutable.

python C:/QM/repo/tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest `
  --ea QM5_11179 `
  --phase Q08 `
  --from-work-item-id 88a7cb34-450b-4f2f-8509-1c4de2aef239 `
  --append-only-rerun-of 906b7644-c9ce-4b4c-925a-a11054a95226 `
  --replacement-setfile framework/EAs/QM5_11179_ft001-ema-ha/sets/QM5_11179_ft001-ema-ha_XAUUSD.DWX_M5_backtest_s20260907-001.set `
  --rerun-reason "OWNER-reviewed Q08.5 empty-strategy-parameter lineage repair; task 49f79e94; preserve 906b7644 as evidence" `
  --expected-current-ex5-sha256 8fe714193162102c5c77890e10396d3d4d12f85319fdfac0fc4513857fda63ac

python C:/QM/repo/tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest `
  --ea QM5_10928 `
  --phase Q08 `
  --from-work-item-id b3b83c7c-0e6e-4553-9fdf-ca4241c6771d `
  --append-only-rerun-of 2cdb6a16-de65-4ef8-91aa-e45ba4d0704a `
  --replacement-setfile framework/EAs/QM5_10928_grimes-yoyo-break/sets/QM5_10928_grimes-yoyo-break_XAUUSD.DWX_M30_backtest_s20260907-001.set `
  --rerun-reason "OWNER-reviewed Q08.5 empty-strategy-parameter lineage repair; task 49f79e94; preserve 2cdb6a16 as evidence" `
  --expected-current-ex5-sha256 e587f079a3f17664af2a08adda6128ee53dcf6e0793d3cd23c44b34c85c45e53
