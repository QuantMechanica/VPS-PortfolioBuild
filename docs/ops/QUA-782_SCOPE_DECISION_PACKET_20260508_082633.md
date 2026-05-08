# QUA-782 Scope Decision Packet (20260508_082633)

## Current state
- M15 setfiles still missing for both required symbols.
- H1 sweep coverage is complete on unique grid cells.

## Verified evidence
- M15 setfiles present:
  - AUDCHF.DWX M15: False
  - EURNZD.DWX M15: False
- Unique H1 P3 cells covered: 24 (= 12 per symbol)
- H1 verdicts:
  - AUDCHF.DWX: 12 FAIL, 0 PASS
  - EURNZD.DWX: 12 FAIL, 0 PASS

## Decision needed (OWNER/CTO)
1. **Option A (continue full requested scope):** provide M15 setfiles for both symbols and resume P3.
2. **Option B (approve H1-only scope):** close P3 as 
o_edge_found on current runtime-available timeframe.

## Operator readiness
- Runner is resume-safe (dedup enabled), so if Option A lands, execution resumes without re-running completed H1 cells.
