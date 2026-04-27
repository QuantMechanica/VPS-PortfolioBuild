# Lessons Learned

Kept / changed / discarded entries from incidents, gate reviews, and retrospectives. Owned by Documentation-KM.

Recent entries:

- `2026-04-26_dwx_spec_patch_blockers.md` - QUA-15 run evidence and unblock criteria for DWX spec patch verification.
- `2026-04-27_qua95_xtiusd_verifier_failure_investigation.md` - QUA-95 rerun evidence for `XTIUSD.DWX`; failure remains systemic verifier/runtime bars-read class (`disposition=defer`) and is blocked on verifier hardening.
- `2026-04-27_qua94_xngusd_verifier_failure_investigation.md` - QUA-94 evidence showing XNGUSD failure matches systemic verifier/runtime bars-read condition; same-day rerun remained FAIL, structured disposition JSON was generated (`defer`), and escalation is on verifier owner.
- `evidence/2026-04-27_qua94_rates_probe.md` - One-shot vs chunked rates-read probe showing XNG/XTI/XAU hard-zero bars while WS30 returns partial chunked bars; refines escalation scope.
- `evidence/2026-04-27_qua94_chunked_verifier_probe.md` - Verifier-mirror probe with `terminal_maxbars` evidence (100k cap) and differential behavior (`XNG` hard-zero vs `WS30` partial chunked bars).
