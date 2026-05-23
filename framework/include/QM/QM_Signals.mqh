//+------------------------------------------------------------------+
//| QM_Signals.mqh                                                   |
//| Optional composable +1 / 0 / -1 signal primitives for EAs.       |
//|                                                                  |
//| Each function returns:                                           |
//|    +1  bullish / long-bias                                       |
//|     0  neutral / no signal                                       |
//|    -1  bearish / short-bias                                      |
//|                                                                  |
//| Codex (or a human) composes these inside Strategy_EntrySignal:   |
//|                                                                  |
//|     if(QM_Sig_MA_Position(_Symbol, PERIOD_H4, 200, 1) > 0 &&     |
//|        QM_Sig_RSI_Reversal(_Symbol, PERIOD_H1, 14, 30, 70) > 0)  |
//|         { build LONG req; return true; }                         |
//|                                                                  |
//| These are ADDITIVE helpers, NOT mandatory. EAs with novel /      |
//| structural logic (Order Blocks, Heiken Ashi sequences, custom    |
//| regime detection) should keep their own implementations in       |
//| Strategy_EntrySignal — these primitives only cover the common    |
//| 80%: MA-cross, range-breakout, threshold-cross, calendar gates.  |
//|                                                                  |
//| All readers delegate to QM_Indicators.mqh (pooled handles, single|
//| CopyBuffer per call) — no per-tick recompute hazard.             |
//+------------------------------------------------------------------+
#ifndef __QM_SIGNALS_MQH__
#define __QM_SIGNALS_MQH__

#include <QM/QM_Indicators.mqh>

//+------------------------------------------------------------------+
//| MA-position: is fast MA above / below slow MA?                   |
//+------------------------------------------------------------------+
int QM_Sig_MA_Position(const string sym, const ENUM_TIMEFRAMES tf,
                       const int fast_period, const int slow_period,
                       const int shift=1)
{
   const double f = QM_EMA(sym, tf, fast_period, shift);
   const double s = QM_EMA(sym, tf, slow_period, shift);
   if(f > s) return +1;
   if(f < s) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| MA-cross: did fast MA just cross slow MA on the last closed bar? |
//| Returns +1 on bullish cross, -1 on bearish, 0 otherwise.         |
//+------------------------------------------------------------------+
int QM_Sig_MA_Cross(const string sym, const ENUM_TIMEFRAMES tf,
                    const int fast_period, const int slow_period,
                    const int shift=1)
{
   const double f_now  = QM_EMA(sym, tf, fast_period, shift);
   const double s_now  = QM_EMA(sym, tf, slow_period, shift);
   const double f_prev = QM_EMA(sym, tf, fast_period, shift + 1);
   const double s_prev = QM_EMA(sym, tf, slow_period, shift + 1);
   if(f_prev <= s_prev && f_now > s_now) return +1;
   if(f_prev >= s_prev && f_now < s_now) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| Price vs MA: is current price meaningfully above/below MA?       |
//| `deadband_pts` lets you avoid noise around exact equality.       |
//+------------------------------------------------------------------+
int QM_Sig_Price_Above_MA(const string sym, const ENUM_TIMEFRAMES tf,
                          const int ma_period,
                          const double deadband_pts=0.0,
                          const int shift=1)
{
   const double ma    = QM_EMA(sym, tf, ma_period, shift);
   const double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   const double price = iClose(sym, tf, shift);
   const double band  = deadband_pts * point;
   if(price > ma + band) return +1;
   if(price < ma - band) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| Range-breakout: did the last closed bar break the N-bar high/low?|
//| Lookback excludes the breakout bar itself (uses shift+1..shift+N)|
//+------------------------------------------------------------------+
int QM_Sig_Range_Breakout(const string sym, const ENUM_TIMEFRAMES tf,
                          const int lookback_bars,
                          const int shift=1)
{
   if(lookback_bars < 1) return 0;
   const double brk_close = iClose(sym, tf, shift);
   double hi = -DBL_MAX, lo = DBL_MAX;
   for(int i = shift + 1; i <= shift + lookback_bars; ++i)
   {
      const double h = iHigh(sym, tf, i);
      const double l = iLow(sym, tf, i);
      if(h > hi) hi = h;
      if(l < lo) lo = l;
   }
   if(brk_close > hi) return +1;
   if(brk_close < lo) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| RSI reversal: oversold→up gives +1, overbought→down gives -1.    |
//| Fires once on the bar where RSI crosses back across the bound.   |
//+------------------------------------------------------------------+
int QM_Sig_RSI_Reversal(const string sym, const ENUM_TIMEFRAMES tf,
                        const int period,
                        const double oversold=30.0,
                        const double overbought=70.0,
                        const int shift=1)
{
   const double r_now  = QM_RSI(sym, tf, period, shift);
   const double r_prev = QM_RSI(sym, tf, period, shift + 1);
   if(r_prev < oversold   && r_now >= oversold)   return +1;
   if(r_prev > overbought && r_now <= overbought) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| ADX strength gate: 1 if trending (ADX > threshold), else 0.      |
//| Direction-agnostic — pair with QM_Sig_MA_Position for bias.      |
//+------------------------------------------------------------------+
int QM_Sig_ADX_Strong(const string sym, const ENUM_TIMEFRAMES tf,
                      const int period=14,
                      const double threshold=25.0,
                      const int shift=1)
{
   const double adx = QM_ADX(sym, tf, period, shift);
   return (adx > threshold) ? 1 : 0;
}

//+------------------------------------------------------------------+
//| Bollinger mean-reversion: long when close pierces lower band,    |
//| short when close pierces upper band.                             |
//+------------------------------------------------------------------+
int QM_Sig_BB_MeanRev(const string sym, const ENUM_TIMEFRAMES tf,
                     const int period, const double devs,
                     const int shift=1)
{
   const double upper = QM_BB_Upper(sym, tf, period, devs, shift);
   const double lower = QM_BB_Lower(sym, tf, period, devs, shift);
   const double close = iClose(sym, tf, shift);
   if(close < lower) return +1;
   if(close > upper) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| Calendar — turn-of-month window.                                 |
//| Returns +1 inside [day_from_end..end-of-month] OR                |
//| [1..day_into_next], else 0. Use multipliers, not direction.      |
//| Common params: McConnell uses day_from_end=4, day_into_next=4.   |
//+------------------------------------------------------------------+
int QM_Sig_TurnOfMonth(const datetime broker_now,
                       const int day_from_end=4,
                       const int day_into_next=4)
{
   MqlDateTime t; TimeToStruct(broker_now, t);
   // Last day of current month = (first of next month) - 1 day
   const int next_year = (t.mon < 12) ? t.year : t.year + 1;
   const int next_mon  = (t.mon < 12) ? t.mon + 1 : 1;
   const datetime first_of_next = StringToTime(StringFormat(
      "%04d.%02d.01 00:00", next_year, next_mon));
   MqlDateTime last; TimeToStruct(first_of_next - 86400, last);
   const int days_in_month = last.day;
   if(t.day >= days_in_month - day_from_end + 1) return +1;
   if(t.day <= day_into_next) return +1;
   return 0;
}

//+------------------------------------------------------------------+
//| Calendar — day-of-week gate. Pass a 7-element bool array         |
//| {mon,tue,wed,thu,fri,sat,sun} = trade on TRUE days.              |
//| Returns +1 if today is enabled, else 0.                          |
//+------------------------------------------------------------------+
int QM_Sig_DayOfWeek(const datetime broker_now,
                     const bool &day_enabled[])
{
   if(ArraySize(day_enabled) != 7) return 0;
   MqlDateTime t; TimeToStruct(broker_now, t);
   // MqlDateTime.day_of_week: 0=Sunday..6=Saturday
   // Our array convention: 0=Monday..6=Sunday
   const int idx = (t.day_of_week == 0) ? 6 : (t.day_of_week - 1);
   return day_enabled[idx] ? +1 : 0;
}

//+------------------------------------------------------------------+
//| Calendar — session gate by broker-time hour.                     |
//| Handles wrap-around (e.g. NY session 22-06).                     |
//+------------------------------------------------------------------+
int QM_Sig_Session(const datetime broker_now,
                   const int start_hour_broker,
                   const int end_hour_broker)
{
   MqlDateTime t; TimeToStruct(broker_now, t);
   const int h = t.hour;
   if(start_hour_broker <= end_hour_broker)
      return (h >= start_hour_broker && h < end_hour_broker) ? 1 : 0;
   // Wrap (e.g. 22 → 06)
   return (h >= start_hour_broker || h < end_hour_broker) ? 1 : 0;
}

#endif // __QM_SIGNALS_MQH__
