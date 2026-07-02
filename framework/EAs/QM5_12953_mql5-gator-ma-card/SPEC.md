# QM5_12953 MQL5 Gator MA Phase Signal

**EA ID:** QM5_12953
**Slug:** mql5-gator-ma-card
**Card Status:** G0 APPROVED
**Source ID:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb

## 1. Strategy Logic

The EA trades closed H1 Gator Oscillator phase bars with an SMA(50) side filter. Long entries require the upper Gator bar to expand, the lower Gator bar to extend lower, the last closed bar to close above SMA(50), and the SMA(50) slope over five bars to be positive. Short entries require the inverse phase, close below SMA(50), and negative SMA(50) slope.

Exits close longs when the Gator phase contracts into the card's sated condition or close falls below SMA(50). Shorts close when the Gator phase flips bullish or close rises above SMA(50). A 48-bar H1 failsafe exit also applies. The EA is one position per magic number.

## 2. Parameters

- Alligator/Gator defaults: Jaws 13 shift 8, Teeth 8 shift 5, Lips 5 shift 3, SMMA median price.
- SMA side and slope filter: SMA(50), five-bar slope direction.
- ATR stop: ATR(14) * 1.7.
- Take profit: 2.1R from initial stop distance.
- Max holding period: 48 H1 bars.
- Local spread cap: 1000 points, with framework news and Friday-close controls enabled by default.

## 3. Symbol Universe

The registered research and backtest symbols are EURUSD.DWX, GBPUSD.DWX, and XAUUSD.DWX.

## 4. Timeframe

Primary timeframe is H1. All entry, exit, Gator, SMA, and ATR reads use the chart timeframe and closed bars.

## 5. Expected Behaviour

The card expects medium frequency, roughly 45 to 95 trades per year per symbol, driven by Gator double-bar phase changes aligned with the SMA side filter. Orders are sent at the next bar open after a closed-bar signal.

## 6. Source Citation

Mohamed Abdelmaaboud, "Learn how to design a trading system by Gator Oscillator", MQL5 Articles, 2023-01-12, https://www.mql5.com/en/articles/11928.

## 7. Risk Model

Backtest setfiles use V5 fixed risk with `RISK_FIXED = 1000.0`, `RISK_PERCENT = 0.0`, and `PORTFOLIO_WEIGHT = 1.0`. Live percent risk remains disabled in the EA default and is only introduced by live deployment packaging after approval.
