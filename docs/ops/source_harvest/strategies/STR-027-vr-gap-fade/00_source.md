# STR-027-vr-gap-fade — Source extract (verbatim pypdf text, 2026-07-24)

PDF: G:\My Drive\QuantMechanica - VPS Portfolio Build\Web-Sources$2.pdf

```

===== PAGE 1/2 =====
S.1
VR Gap Open Source Trading Strategy
ForexFactory Thread 1394867 — 1 Beiträge, KOMPLETT (1 Seite(n))
Voldemar227
VR Gap is an automated trading system for the MetaTrader platform, based on the classic market phenomenon of
price gaps. The strategy is designed to work on any timeframe and assumes that the market tends to return to
levels where a sharp price jump occurred, aiming to "close the window".
Attached Image (click to enlarge)
Core Concept and Entry Logic
The Expert Advisor operates exclusively upon the formation of a new candlestick on the chart. At the opening of
each new bar, a comparison is made between two key price levels:
The closing price of the previous completed bar.
The opening price of the current forming bar.
If the absolute difference between these values exceeds a threshold set by the trader (the Minimum Gap Size
parameter), a price gap is confirmed. The strategy then acts against the initial impulse, betting on a correction:
Downward Gap (opening price is lower than the previous close): A long position (Buy) is opened,
anticipating a rise and the closure of the gap from above.
Upward Gap (opening price is higher than the previous close): A short position (Sell) is opened,
anticipating a decline and the closure of the gap from below.
Entry is executed immediately at the market price upon the opening of the new bar. It is important to note that the
EA uses a fixed volume for each trade and does not analyze additional indicators, trend filters, or news
backgrounds.
Position Management and Tracking Algorithm
===== PAGE 2/2 =====
A distinctive feature of this implementation is the delayed placement of protective orders. At the moment a
position is opened, Stop Loss and Take Profit levels are not set. Instead, the EA monitors its open trades on every
subsequent tick using its magic number and symbol.
As soon as a position is found with missing Stop Loss or Take Profit levels (equal to zero), their calculation and
modification take place.
Stop Loss Calculation:
The loss limitation level is fixed and defined in points within the input parameters. It is placed at a strictly defined
distance from the position's opening price:
For Buy positions �  below the entry price.
For Sell positions �  above the entry price.
Take Profit Calculation:
The profit-taking level is not a fixed constant. The Take Profit dynamically equals the size of the gap itself,
which served as the entry signal. The target is set at a distance equal to the difference between the previous bar's
close and the current bar's open. This is logical, as the gap is considered fully closed at precisely this price level.
Before sending an order to modify the position, the system verifies that the new levels comply with the broker's
minimum distance requirements for pending orders (stop level). If the verification passes, the position is modified,
and trading enters a waiting mode for one of the orders to trigger.
Strategy Configuration Parameters
Four main input parameters are provided for adaptation to various instruments and trading styles:
Trading Volume: A fixed lot size for each opened position. The system does not use dynamic risk calculation
(e.g., percentage of deposit); the lot remains constant, rounded to the allowable volume step of the symbol.
Minimum Gap Size: The key filter, measured in points. It determines how strong the price break must be for
the EA to consider the signal valid. Increasing this parameter reduces trade frequency but increases the
likelihood of dealing with more significant market imbalances.
Stop Loss Size: A fixed distance in points from the opening price at which a loss will be recorded if the price
moves against the anticipated gap closure.
Magic Number and Slippage: An identifier to distinguish the EA's trades from other account operations and
the permissible price deviation when executing market orders.
Conclusion
VR Gap represents a simple and transparent implementation of a gap trading strategy. Its strength lies in its clear
mathematical logic without the use of subjective indicators. The primary risk of the strategy occurs when the gap
does not close and the price continues moving in the direction of the initial impulse � in which case the position will
be stopped out. This version of the EA is not intended for trading during news releases or periods of extreme
volatility without prior adjustment of the Minimum Gap Size parameter to the specific instrument.
VR Gap - Expert Advisor for MetaTrader 4 https://www.mql5.com/en/code/9994
VR Gap - Expert Advisor for MetaTrader 5 https://www.mql5.com/en/code/72239```
