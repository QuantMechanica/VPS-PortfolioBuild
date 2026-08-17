# QM5_21503_xti-weekly-tsmom-lowvol

**EA ID:** QM5_21503

**Source strategy:** `ZHAO-ST-MOMREV-2026_XTI_S02`

## Build identity

This directory is the governed V5 build target for the OWNER-approved WTI
exact-calendar-week low-volatility momentum card. The strategy trades only
`XTIUSD.DWX` on D1, attempts once on Monday within a 180-minute grace window,
and follows the sign of the immediately preceding Monday-to-Friday return only
when that week's five-return realized volatility ranks in the lowest 13 of 40
older, non-overlapping weekly blocks.

The build contract fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`, an ATR(20) stop
at 3.0x, a 1,500-point entry spread ceiling, and the framework Friday-close
lifecycle at broker hour 21. There is no take-profit, optimization, live/demo
preset, paired leg, external runtime feed, or portfolio-admission claim.

The approved card is
`strategy-seeds/cards/approved/QM5_21503_xti-weekly-tsmom-lowvol_card.md`.

## Version history

| Version | Date | Change | Status |
|---|---|---|---|
| v1 | 2026-08-17 | approved build-directory identity | G0 approved; implementation pending |
