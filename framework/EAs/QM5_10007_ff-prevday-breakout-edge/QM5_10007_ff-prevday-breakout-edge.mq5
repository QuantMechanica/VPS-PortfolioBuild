#property strict
#property version   "5.0"
#property description "QM5_10007 ForexFactory previous-day breakout edge"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 10007;
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
input int    strategy_sma_period         = 34;
input int    strategy_atr_period_d1      = 14;
input double strategy_min_range_atr_mult = 0.5;
input double strategy_sl_pips            = 12.5;
input double strategy_tp_pips            = 25.0;
input double strategy_max_spread_pips    = 2.0;
input double strategy_spread_sl_fraction = 0.16;
input int    strategy_source_boundary_utc_hour = 22;
input int    strategy_pd_scan_h1_bars    = 120;

int g_last_long_breakout_source_day = -2147483647;
int g_last_short_breakout_source_day = -2147483647;
int g_cached_breakout_source_day = -2147483647;
int g_cached_breakout_direction = 0;

double Strategy_PipDistance(const double pips)
  {
   if(pips <= 0.0)
      return 0.0;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return pips * point * pip_factor;
  }

double Strategy_SpreadPips()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double pip = Strategy_PipDistance(1.0);
   if(ask <= 0.0 || bid <= 0.0 || pip <= 0.0)
      return DBL_MAX;
   return (ask - bid) / pip;
  }

datetime Strategy_DateFloor(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

int Strategy_BoundaryHour()
  {
   return MathMax(0, MathMin(23, strategy_source_boundary_utc_hour));
  }

int Strategy_SourceDayIndexUTC(const datetime utc_time)
  {
   const datetime day_floor = Strategy_DateFloor(utc_time);
   const datetime boundary = day_floor + Strategy_BoundaryHour() * 3600;
   datetime shifted = utc_time;
   if(utc_time < boundary)
      shifted -= 86400;
   return (int)(Strategy_DateFloor(shifted) / 86400);
  }

datetime Strategy_SourceDayStartUTC(const int source_day_index)
  {
   return (datetime)(source_day_index * 86400 + Strategy_BoundaryHour() * 3600);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_PreviousDayRange(const datetime signal_bar_broker_time,
                               const MqlRates &rates[],
                               const int copied,
                               double &out_pdh,
                               double &out_pdl,
                               int &out_source_day)
  {
   out_pdh = 0.0;
   out_pdl = 0.0;
   out_source_day = -2147483647;
   if(signal_bar_broker_time <= 0 || copied <= 0)
      return false;

   const datetime signal_utc = QM_BrokerToUTC(signal_bar_broker_time);
   const int source_day = Strategy_SourceDayIndexUTC(signal_utc);
   const datetime prev_start_utc = Strategy_SourceDayStartUTC(source_day - 1);
   const datetime prev_end_utc = Strategy_SourceDayStartUTC(source_day);

   bool found = false;
   double high = -DBL_MAX;
   double low = DBL_MAX;
   for(int i = 0; i < copied; ++i)
     {
      const datetime bar_utc = QM_BrokerToUTC(rates[i].time);
      if(bar_utc < prev_start_utc || bar_utc >= prev_end_utc)
         continue;
      if(rates[i].high <= 0.0 || rates[i].low <= 0.0)
         continue;

      high = MathMax(high, rates[i].high);
      low = MathMin(low, rates[i].low);
      found = true;
     }

   if(!found || high <= low)
      return false;

   out_pdh = high;
   out_pdl = low;
   out_source_day = source_day;
   return true;
  }

int Strategy_LastClosedBreakout(double &out_pdh, double &out_pdl, int &out_source_day, double &out_close)
  {
   out_pdh = 0.0;
   out_pdl = 0.0;
   out_close = 0.0;
   out_source_day = -2147483647;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H1, 1, MathMax(48, strategy_pd_scan_h1_bars), rates);
   if(copied <= 0)
      return 0;

   out_close = rates[0].close;
   if(out_close <= 0.0)
      return 0;

   if(!Strategy_PreviousDayRange(rates[0].time, rates, copied, out_pdh, out_pdl, out_source_day))
      return 0;

   const double prior_range = out_pdh - out_pdl;
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(atr_d1 <= 0.0 || prior_range < strategy_min_range_atr_mult * atr_d1)
      return 0;

   if(out_close > out_pdh)
      return 1;
   if(out_close < out_pdl)
      return -1;
   return 0;
  }

bool Strategy_NoTradeFilter()
  {
   const double spread_pips = Strategy_SpreadPips();
   const double max_by_sl = strategy_sl_pips * strategy_spread_sl_fraction;
   if(spread_pips > strategy_max_spread_pips)
      return true;
   if(max_by_sl > 0.0 && spread_pips > max_by_sl)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   double pdh = 0.0;
   double pdl = 0.0;
   double close_1 = 0.0;
   int source_day = -2147483647;
   const int breakout = Strategy_LastClosedBreakout(pdh, pdl, source_day, close_1);
   g_cached_breakout_source_day = source_day;
   g_cached_breakout_direction = breakout;

   if(breakout == 0 || Strategy_HasOpenPosition())
      return false;

   const double sma_1 = QM_SMA(_Symbol, PERIOD_H1, strategy_sma_period, 1, PRICE_CLOSE);
   if(sma_1 <= 0.0)
      return false;

   if(breakout > 0)
     {
      if(g_last_long_breakout_source_day == source_day || close_1 <= sma_1)
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl_dist = Strategy_PipDistance(strategy_sl_pips);
      const double tp_dist = Strategy_PipDistance(strategy_tp_pips);
      if(entry <= 0.0 || sl_dist <= 0.0 || tp_dist <= 0.0)
         return false;

      req.type = QM_BUY;
      req.sl = QM_StopRulesStopFromDistance(_Symbol, req.type, entry, sl_dist);
      req.tp = QM_StopRulesTakeFromDistance(_Symbol, req.type, entry, tp_dist);
      req.reason = "FF_PREVDAY_BREAKOUT_LONG";
      g_last_long_breakout_source_day = source_day;
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   if(g_last_short_breakout_source_day == source_day || close_1 >= sma_1)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double sl_dist = Strategy_PipDistance(strategy_sl_pips);
   const double tp_dist = Strategy_PipDistance(strategy_tp_pips);
   if(entry <= 0.0 || sl_dist <= 0.0 || tp_dist <= 0.0)
      return false;

   req.type = QM_SELL;
   req.sl = QM_StopRulesStopFromDistance(_Symbol, req.type, entry, sl_dist);
   req.tp = QM_StopRulesTakeFromDistance(_Symbol, req.type, entry, tp_dist);
   req.reason = "FF_PREVDAY_BREAKOUT_SHORT";
   g_last_short_breakout_source_day = source_day;
   return (req.sl > 0.0 && req.tp > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   if(g_cached_breakout_direction == 0)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && g_cached_breakout_direction < 0)
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
      if(pos_type == POSITION_TYPE_SELL && g_cached_breakout_direction > 0)
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const datetime now_utc = QM_BrokerToUTC(TimeCurrent());
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_utc = QM_BrokerToUTC((datetime)PositionGetInteger(POSITION_TIME));
      const int open_source_day = Strategy_SourceDayIndexUTC(open_utc);
      const datetime day_end_utc = Strategy_SourceDayStartUTC(open_source_day + 1);
      if(now_utc >= day_end_utc)
         return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10007\",\"source\":\"forexfactory_prevday_breakout\"}");
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

   if(!QM_IsNewBar())
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
