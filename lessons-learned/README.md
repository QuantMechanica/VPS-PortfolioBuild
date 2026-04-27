# Lessons Learned

Kept / changed / discarded entries from incidents, gate reviews, and retrospectives. Owned by Documentation-KM.

Recent entries:

- `2026-04-26_dwx_spec_patch_blockers.md` - QUA-15 run evidence and unblock criteria for DWX spec patch verification.
- `2026-04-27_qua95_xtiusd_verifier_failure_investigation.md` - QUA-95 rerun evidence for `XTIUSD.DWX`; failure remains systemic verifier/runtime bars-read class (`disposition=defer`) and is blocked on verifier hardening.
- `evidence/2026-04-27_qua95_xtiusd_probe.md` - QUA-95 targeted preflight + chunked probe: tail ticks recover in preflight, but bars remain zero in one-shot and chunked reads (`Invalid params`), tightening unblock scope to verifier bars-read path.
- `evidence/2026-04-27_qua95_xtiusd_source_vs_custom_api_probe.md` - QUA-95 side-by-side MT5 API probe proves source `XTIUSD` bars are readable while custom `XTIUSD.DWX` bars are not, isolating blocker to custom-symbol/runtime visibility (plus verifier handling).
- `evidence/2026-04-27_qua95_xtiusd_custom_visibility_probe.md` - QUA-95 automated custom-vs-source visibility probe (`probe_custom_symbol_visibility.py`) returned `isolated_custom_bars_visibility_failure=true` with source bars available and custom bars zero.
- `evidence/2026-04-27_qua95_custom_visibility_scope_matrix.md` - six-symbol scope matrix shows custom-bars visibility failure across multiple families (`XTI/XNG/XAU/XAG/EURUSD`), with `WS30.DWX` as a partial exception.
- `evidence/2026-04-27_qua95_xtiusd_warmup_attempt.md` - read-only MT5 warm-up retry (40 iterations) did not restore `XTIUSD.DWX` bars visibility; post-warmup probe and verifier rerun remained `defer`.
- `2026-04-27_qua94_xngusd_verifier_failure_investigation.md` - QUA-94 evidence showing XNGUSD failure matches systemic verifier/runtime bars-read condition; same-day rerun remained FAIL, structured disposition JSON was generated (`defer`), and escalation is on verifier owner.
- `evidence/2026-04-27_qua94_rates_probe.md` - One-shot vs chunked rates-read probe showing XNG/XTI/XAU hard-zero bars while WS30 returns partial chunked bars; refines escalation scope.
- `evidence/2026-04-27_qua94_chunked_verifier_probe.md` - Verifier-mirror probe with `terminal_maxbars` evidence (100k cap) and differential behavior (`XNG` hard-zero vs `WS30` partial chunked bars).
- `evidence/2026-04-27_qua94_xng_chunked_probe.json` and `evidence/2026-04-27_qua94_ws30_chunked_probe.json` - machine-readable probe payloads for owner handoff.
