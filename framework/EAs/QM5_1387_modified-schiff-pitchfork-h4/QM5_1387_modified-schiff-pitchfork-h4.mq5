#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA - Modified Schiff Pitchfork H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1387;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_timeframe = PERIOD_H4;
input int    strategy_atr_period         = 14;
input int    strategy_pivot_scan_bars    = 100;
input int    strategy_zigzag_depth       = 12;
input int    strategy_zigzag_backstep    = 3;
input double strategy_zigzag_dev_pips    = 5.0;
input double strategy_swing1_d1_atr      = 2.0;
input double strategy_swing2_d1_atr      = 1.5;
input int    strategy_fresh_p2_bars      = 50;
input double strategy_line_touch_atr     = 0.20;
input double strategy_body_ratio_min     = 0.40;
input double strategy_spread_atr         = 0.40;
input double strategy_vol_spike_mult     = 2.50;
input double strategy_stop_atr           = 1.50;
input int    strategy_tp_projection_bars = 12;
input int    strategy_time_stop_bars     = 24;
input int    strategy_reuse_guard_bars   = 12;
input int    strategy_session_start_hour = 7;
input int    strategy_session_end_hour   = 21;
input int    strategy_friday_cutoff_hour = 16;

struct MSP_Pivot
  {
   int      shift;
   double   price;
   int      type;
   datetime time;
  };

struct MSP_Fork
  {
   bool     valid;
   int      direction;
   int      p0_shift;
   int      p1_shift;
   int      p2_shift;
   double   p0_price;
   double   p1_price;
   double   p2_price;
   double   shifted_p0_shift;
   double   shifted_p0_price;
   double   slope;
   double   upper_offset;
   double   lower_offset;
   datetime p0_time;
   datetime p1_time;
   datetime p2_time;
   string   key;
  };

MSP_Fork g_active_fork;
bool     g_have_active_fork = false;
bool     g_partial_done = false;
string   g_last_fork_key = "";
datetime g_reuse_guard_until = 0;

double MSP_NormalizePrice(const double price)
  {
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

double MSP_PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   return (digits == 3 || digits == 5) ? point * 10.0 : point;
  }

double MSP_LineAtShift(const MSP_Fork &fork, const double offset, const int shift)
  {
   return fork.shifted_p0_price + offset + fork.slope * (fork.shifted_p0_shift - (double)shift);
  }

bool MSP_CurrentSymbolAllowed()
  {
   const string s = _Symbol;
   return (s == "EURUSD.DWX" || s == "GBPUSD.DWX" || s == "USDJPY.DWX" ||
           s == "AUDUSD.DWX" || s == "USDCAD.DWX" || s == "USDCHF.DWX" ||
           s == "XAUUSD.DWX" || s == "NDX.DWX" || s == "WS30.DWX" ||
           s == "GDAXI.DWX" || s == "UK100.DWX");
  }

bool MSP_IsSessionAllowed(const datetime bar_open_time)
  {
   const datetime bar_close_time = bar_open_time + (datetime)PeriodSeconds(strategy_timeframe);
   MqlDateTime dt;
   TimeToStruct(bar_close_time, dt);
   if(dt.hour < strategy_session_start_hour || dt.hour > strategy_session_end_hour)
      return false;
   if(dt.day_of_week == 5 && dt.hour >= strategy_friday_cutoff_hour)
      return false;
   return true;
  }

bool MSP_IsFractalPivot(const MqlRates &rates[], const int count, const int shift, const int type)
  {
   if(shift < strategy_zigzag_backstep || shift + strategy_zigzag_depth >= count)
      return false;

   for(int j = 1; j <= strategy_zigzag_depth; ++j)
     {
      if(type > 0)
        {
         if(rates[shift].high <= rates[shift - j].high || rates[shift].high <= rates[shift + j].high)
            return false;
        }
      else
        {
         if(rates[shift].low >= rates[shift - j].low || rates[shift].low >= rates[shift + j].low)
            return false;
        }
     }
   return true;
  }

bool MSP_AppendPivot(MSP_Pivot &pivots[], int &pivot_count, const MSP_Pivot &candidate, const double min_dev)
  {
   if(pivot_count > 0)
     {
      MSP_Pivot last = pivots[pivot_count - 1];
      if(last.type == candidate.type)
        {
         const bool replace = (candidate.type > 0) ? (candidate.price > last.price) : (candidate.price < last.price);
         if(replace)
            pivots[pivot_count - 1] = candidate;
         return true;
        }
      if(MathAbs(candidate.price - last.price) < min_dev)
         return true;
     }

   if(pivot_count >= 80)
      return false;

   pivots[pivot_count] = candidate;
   pivot_count++;
   return true;
  }

bool MSP_BuildFork(MSP_Fork &fork)
  {
   fork.valid = false;

   const int needed = strategy_pivot_scan_bars + strategy_zigzag_depth + strategy_zigzag_backstep + 8;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_timeframe, 0, needed, rates);
   if(copied < needed - 2)
      return false;

   const double d1_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double pip = MSP_PipSize();
   if(d1_atr <= 0.0 || pip <= 0.0)
      return false;

   MSP_Pivot pivots[80];
   int pivot_count = 0;
   const double min_dev = strategy_zigzag_dev_pips * pip;
   const int max_shift = MathMin(strategy_pivot_scan_bars, copied - strategy_zigzag_depth - 1);
   for(int shift = max_shift; shift >= strategy_zigzag_backstep + 1; --shift)
     {
      MSP_Pivot candidate;
      candidate.shift = shift;
      candidate.time = rates[shift].time;
      candidate.type = 0;
      candidate.price = 0.0;

      if(MSP_IsFractalPivot(rates, copied, shift, 1))
        {
         candidate.type = 1;
         candidate.price = rates[shift].high;
        }
      else if(MSP_IsFractalPivot(rates, copied, shift, -1))
        {
         candidate.type = -1;
         candidate.price = rates[shift].low;
        }

      if(candidate.type == 0)
         continue;
      if(!MSP_AppendPivot(pivots, pivot_count, candidate, min_dev))
         break;
     }

   for(int i = pivot_count - 3; i >= 0; --i)
     {
      MSP_Pivot p0 = pivots[i];
      MSP_Pivot p1 = pivots[i + 1];
      MSP_Pivot p2 = pivots[i + 2];
      if(!(p0.type == p2.type && p0.type != p1.type))
         continue;
      if(p2.shift > strategy_fresh_p2_bars)
         continue;
      if(MathAbs(p0.price - p1.price) < strategy_swing1_d1_atr * d1_atr)
         continue;
      if(MathAbs(p2.price - p1.price) < strategy_swing2_d1_atr * d1_atr)
         continue;

      const bool bullish = (p1.price < p0.price && p1.price < p2.price);
      const bool bearish = (p1.price > p0.price && p1.price > p2.price);
      if(!bullish && !bearish)
         continue;

      const double shifted_p0_shift = 0.5 * ((double)p0.shift + (double)p1.shift);
      const double shifted_p0_price = 0.5 * (p0.price + p1.price);
      const double mid_shift = 0.5 * ((double)p1.shift + (double)p2.shift);
      const double mid_price = 0.5 * (p1.price + p2.price);
      const double denom = shifted_p0_shift - mid_shift;
      if(MathAbs(denom) <= 0.0)
         continue;

      const double slope = (mid_price - shifted_p0_price) / denom;
      const double p1_offset = p1.price - (shifted_p0_price + slope * (shifted_p0_shift - (double)p1.shift));
      const double p2_offset = p2.price - (shifted_p0_price + slope * (shifted_p0_shift - (double)p2.shift));

      fork.valid = true;
      fork.direction = bullish ? 1 : -1;
      fork.p0_shift = p0.shift;
      fork.p1_shift = p1.shift;
      fork.p2_shift = p2.shift;
      fork.p0_price = p0.price;
      fork.p1_price = p1.price;
      fork.p2_price = p2.price;
      fork.shifted_p0_shift = shifted_p0_shift;
      fork.shifted_p0_price = shifted_p0_price;
      fork.slope = slope;
      fork.upper_offset = MathMax(p1_offset, p2_offset);
      fork.lower_offset = MathMin(p1_offset, p2_offset);
      fork.p0_time = p0.time;
      fork.p1_time = p1.time;
      fork.p2_time = p2.time;
      fork.key = StringFormat("%I64d-%I64d-%I64d", (long)p0.time, (long)p1.time, (long)p2.time);
      return true;
     }

   return false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(!MSP_CurrentSymbolAllowed())
      return true;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double atr60 = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 60);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || atr60 <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;
   if((ask - bid) >= strategy_spread_atr * atr)
      return true;
   if(atr > strategy_vol_spike_mult * atr60)
      return true;
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime current_bar = iTime(_Symbol, strategy_timeframe, 0);
   if(g_reuse_guard_until > 0 && current_bar <= g_reuse_guard_until)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, strategy_timeframe, 0, 4, rates) < 4)
      return false;
   if(!MSP_IsSessionAllowed(rates[1].time))
      return false;

   MSP_Fork fork;
   if(!MSP_BuildFork(fork))
      return false;
   if(fork.key == g_last_fork_key)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0 || (ask - bid) >= strategy_spread_atr * atr)
      return false;

   const double open1 = rates[1].open;
   const double close1 = rates[1].close;
   const double high1 = rates[1].high;
   const double low1 = rates[1].low;
   const double range1 = high1 - low1;
   if(open1 <= 0.0 || close1 <= 0.0 || range1 <= 0.0)
      return false;

   const double body_ratio = MathAbs(close1 - open1) / range1;
   if(body_ratio < strategy_body_ratio_min)
      return false;

   const double ml1 = MSP_LineAtShift(fork, 0.0, 1);
   const double upper1 = MSP_LineAtShift(fork, fork.upper_offset, 1);
   const double lower1 = MSP_LineAtShift(fork, fork.lower_offset, 1);
   const double pivot_mid = 0.5 * (fork.p0_price + fork.p1_price);

   if(fork.direction > 0)
     {
      if(low1 > lower1 + strategy_line_touch_atr * atr)
         return false;
      if(!(close1 > open1 && close1 > lower1 && close1 > pivot_mid))
         return false;

      const double entry_price = ask;
      const double sl = lower1 - strategy_stop_atr * atr;
      const double tp = MSP_LineAtShift(fork, 0.0, -strategy_tp_projection_bars);
      if(sl >= entry_price || tp <= entry_price)
         return false;

      req.type = QM_BUY;
      req.sl = MSP_NormalizePrice(sl);
      req.tp = MSP_NormalizePrice(tp);
      req.reason = "modified_schiff_lwl_rejection_buy";
     }
   else
     {
      if(high1 < upper1 - strategy_line_touch_atr * atr)
         return false;
      if(!(close1 < open1 && close1 < upper1 && close1 < pivot_mid))
         return false;

      const double entry_price = bid;
      const double sl = upper1 + strategy_stop_atr * atr;
      const double tp = MSP_LineAtShift(fork, 0.0, -strategy_tp_projection_bars);
      if(sl <= entry_price || tp >= entry_price)
         return false;

      req.type = QM_SELL;
      req.sl = MSP_NormalizePrice(sl);
      req.tp = MSP_NormalizePrice(tp);
      req.reason = "modified_schiff_uwl_rejection_sell";
     }

   g_active_fork = fork;
   g_have_active_fork = true;
   g_partial_done = false;
   g_last_fork_key = fork.key;
   g_reuse_guard_until = current_bar + (datetime)(strategy_reuse_guard_bars * PeriodSeconds(strategy_timeframe));
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   if(!g_have_active_fork || g_partial_done)
      return;

   const int magic = QM_FrameworkMagic();
   const double close1 = iClose(_Symbol, strategy_timeframe, 1);
   const double close2 = iClose(_Symbol, strategy_timeframe, 2);
   const double ml1 = MSP_LineAtShift(g_active_fork, 0.0, 1);
   const double ml2 = MSP_LineAtShift(g_active_fork, 0.0, 2);
   if(close1 <= 0.0 || close2 <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic || PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      if(type == POSITION_TYPE_BUY && close2 < ml2 && close1 >= ml1)
        {
         QM_TM_PartialClose(ticket, volume * 0.50, QM_EXIT_PARTIAL);
         g_partial_done = true;
        }
      else if(type == POSITION_TYPE_SELL && close2 > ml2 && close1 <= ml1)
        {
         QM_TM_PartialClose(ticket, volume * 0.50, QM_EXIT_PARTIAL);
         g_partial_done = true;
        }
     }
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const double close1 = iClose(_Symbol, strategy_timeframe, 1);
   if(close1 <= 0.0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic || PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int entry_shift = iBarShift(_Symbol, strategy_timeframe, open_time, false);
      if(entry_shift >= strategy_time_stop_bars)
         return true;

      if(!g_have_active_fork)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double ml1 = MSP_LineAtShift(g_active_fork, 0.0, 1);
      const double upper1 = MSP_LineAtShift(g_active_fork, g_active_fork.upper_offset, 1);
      const double lower1 = MSP_LineAtShift(g_active_fork, g_active_fork.lower_offset, 1);
      const double rail_width = MathAbs(upper1 - ml1);
      if(type == POSITION_TYPE_BUY && close1 < lower1 - rail_width)
         return true;
      if(type == POSITION_TYPE_SELL && close1 > upper1 + rail_width)
         return true;
     }
   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(qm_news_mode == QM_NEWS_OFF)
      return false;
   return !QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode);
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar(_Symbol, strategy_timeframe))
      return;

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
