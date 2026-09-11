# QM5_41405 framework alignment

Approved card: `strategy_card.md`, copied from the runtime approved reservoir.

- No-trade, news, Friday close and kill switch: inherited OnTick framework calls, mandatory PRE30_POST30 / DXZ; staleness ceiling 336h.
- Entry: Strategy_BuildRangeForToday selects closed H1/M30/M5 bars; Strategy_BuildStraddlePlan applies the ATR-band switch, points buffer and four outside rules before the inherited permission decision and trade-manager calls.
- Time: Strategy_ClockTime supplies fixed UTC+3, raw broker, or Europe/Berlin UTC+1/+2 using EU last-Sunday transitions at 01:00 UTC. The same clock controls range membership, day keys, placement and evening exit.
- Management/close: parent trailing, pending cancellation, evening flat and range-boundary exits preserved, with only the clock helper substituted.
- Risk/magic: framework sizing, RISK_FIXED=1000/RISK_PERCENT=0; existing registry 41405/slot 0 resolves 414050000. No registry writes.
- Validation: six new inputs are range checked in OnInit; H1 plus a half-hour endpoint is rejected. The half-hour placement path uses ticks after :30; all minute-zero configurations retain parent H1 new-bar admission.

The inherited permission-intent/day-completion defect is deliberately unchanged. The published Balke no-trailing behavior is not introduced as an unapproved seventh input; any exact published-settings replication requires resolving that scope separately.

Source review confirms nine inherited hook bodies remain identical after the clock helper rename; the reference s0_l8 set differs only in qm_ea_id plus the six new default inputs. This is source verification, not runtime identity. Seven annual control deal-list comparisons remain mandatory before the stage-2 matrix is enqueued. Compile evidence and review are required before any pipeline claim.
