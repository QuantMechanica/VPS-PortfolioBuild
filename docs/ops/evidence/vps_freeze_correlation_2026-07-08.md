# VPS Hard-Freeze vs RAM-Exhaustion Correlation — 2026-07-08

**Trigger:** VPS unreachable via RDP on 2026-07-08, OWNER hard-reset it (~06:49→07:02 local).
Question: are the recurring unclean reboots resource-exhaustion (in-guest, fixable) or
host/hypervisor-level (needs external mitigation)?

**Data:** `vps_freeze_correlation_2026-07-08.csv` (this dir). Sources = Windows System log
Event 41 (unclean reboot) + Event 6008 (embedded prior-shutdown time) + Event 2004
(Resource-Exhaustion-Detector, low virtual memory), all since 2026-06-01.

## Findings

- **6 unclean-reboot incidents** (Event 41): 19.06 (×2), 23.06, 05.07 (×2), 08.07.
  Doubles = reboot crashed again 0.5–4 min later (host-side signature, not a gradual guest leak).
- **35 Event-2004 (low-VM) events, span 2026-06-13 .. 2026-06-28, ALL `metatester64.exe`**
  (20–46 GB virtual memory each). **Zero Event-2004 in July.** The RAM-exhaustion era ended 28.06,
  coinciding with the tester-cap / `tester_cache_purge` (20 min) / watchdog-respawn-flap mitigations.
- **No Event-41 freeze coincides with an Event-2004 within 6 h** (nearest: 23.06 = 10.3 h; all
  July = 165–229 h prior). Even in June the hard-freezes did not line up with the OOM diagnostics —
  those were the "Windows diagnosed and survived by paging" cases.
- **Current resources healthy:** RAM 56 % used (27.7 GB free / 63 GB), D: 112 GB free.

## Conclusion

RAM exhaustion is **ruled out as the freeze trigger** for the July incidents (05.07, 08.07):
7–10 days after the last-ever OOM diagnostic, with RAM presently healthy. The signature —
whole-VM stall, unclean shutdown (Event 41), sometimes a double-crash on reboot, in-guest
`LsmHealthProbe` erroring (`0x800710E0`) ~49 min before the 08.07 freeze — points to
**host/hypervisor-level unresponsiveness**, which an in-guest watchdog cannot heal.

## Actions

- **External mitigation required:** enable a host-side "reboot-on-unresponsive" watchdog at the
  provider (in-guest self-heal is powerless against a frozen VM). OWNER/provider action.
- Consider tightening `QM_StrategyFarm_LsmHealthProbe` cadence below 6 h for faster *detection/alert*
  (cannot reboot a frozen VM, but flags a degrading guest sooner — the 08.07 probe errored 49 min pre-freeze).
- Live impact of 08.07 incident = negligible: both books recovered ≤13 min, 1 open DXZ position
  (AUDCAD) preserved, server-side SLs held throughout. See `live_book_pulse.json` (verdict OK).
