# QM5_20094_xng-fri-short

Source: `BOROWSKI-COMM-DOW-2016_S02`.

On the first executable tick of a genuine `XNGUSD.DWX` D1 bar timestamped
Friday (`day_of_week == 5`, Sunday=0), consume one daily decision and attempt
one short. Close at the next D1 boundary or after one stale calendar day.
Use a frozen completed-bar ATR(20) x 2.75 hard stop, no target, a 2500-point
spread cap, framework news controls, and Friday close at broker hour 21.

All parameters are locked. No live setfile or live authorization exists.
