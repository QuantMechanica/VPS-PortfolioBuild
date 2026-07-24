# STR-003 / QM5_20102 — Smoke record (2026-07-24)

**PASS** — GBPUSD.DWX H1 2024 on T5, `-MinTrades 1 -SmokeMode`, deterministic
across both runs. Valid despite T5's dead indicator engine: with the default
set (strategy_sma_filter=false) the EA creates NO indicator handles (verified
in source — the SMA handle is gated behind the filter input), and a POSITIVE
result is valid evidence regardless (trades happened, full framework stack
ran). Evidence: `D:\QM\reports\smoke\QM5_20102\20260724_150401\` (see
summary.json for metrics; economics are Q02+'s judgment).

Note: an EURUSD.DWX attempt on T5 failed with `history synchronization
error` (T5 EURUSD H1 .hcc cold since the 2026-07-24 agent-dir wipe; GBPUSD
was warm from earlier runs) — environment, not EA; evidence
`D:\QM\reports\smoke\QM5_20102\20260724_150111\`.
