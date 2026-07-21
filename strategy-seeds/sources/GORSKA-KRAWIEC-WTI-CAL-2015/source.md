---
source_id: GORSKA-KRAWIEC-WTI-CAL-2015
title: Calendar Effects in the Market of Crude Oil
status: approved
approved_by: OWNER commodity-sleeve mission
approved_at: 2026-07-21
primary_url: https://doi.org/10.22630/PRS.2015.15.4.54
---
# Source
Gorska and Krawiec (2015), peer-reviewed *Problems of World Agriculture*
15(4), 62-70, study daily WTI/Brent closes from 2000-2014. Table 4 reports WTI
mean daily log returns of 0.00252 in February and -0.00155 in October; Table 5
reports their difference significant at 5% (z=2.27121).

R1 PASS: DOI and university-hosted full text. R2 PASS: deterministic month
signs and one-session returns. R3 PASS: registered XTIUSD.DWX D1 with >5
annual packages. R4 PASS: no ML, banned indicator, or external runtime feed.
Exact search found whole-month WTI holds and weekday one-session cards, but no
daily-reset February-long/October-short rotation.

The source was read end-to-end for the second extraction. Table 1 reports WTI
Monday mean -0.000943 and Friday mean 0.001731; Table 2 rejects equality for
Monday-Friday at 5% (z=-2.3617). `GORSKA-KRAWIEC-WTI-CAL-2015_S02` mechanizes
that tested contrast as one signed carrier: Monday short and Friday long, each
reset at the next D1 boundary. Exact repository search found the two one-sided
weekday EAs but no combined signed Monday-Friday carrier.
