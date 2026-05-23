#property strict
#property version   "5.0"
#property description "QM5_1045 Zarattini SPY Intraday Momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1045;
input int    qm_magic_slot_offset        = 2;

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
input int    strategy_session_open_hhmm  = 1630;
input int    strategy_session_close_hhmm = 2255;
input int    strategy_noise_lookback_days = 14;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 3.0;
input int    strategy_max_spread_points  = 250;

int  g_trade_day_key = -1;
bool g_long_taken_today = false;
bool g_short_taken_today = false;

int Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

datetime DayStart(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

datetime DateWithHhmm(const datetime day_start, const int hhmm)
  {
   const int hour = hhmm / 100;
   const int minute = hhmm % 100;
   return day_start + hour * 3600 + minute * 60;
  }

bool InSession(const datetime t)
  {
   const int hhmm = Hhmm(t);
   return (hhmm >= strategy_session_open_hhmm && hhmm < strategy_session_close_hhmm);
  }

bool HalfHourBoundaryBar(const datetime bar_time)
  {
   MqlDateTime dt;
   TimeToStruct(bar_time, dt);
   return (dt.min == 0 || dt.min == 30);
  }

bool GetOurPosition(ulong &ticket)
  {
   ticket = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = t;
      return true;
     }

   return false;
  }

bool HasOurPosition()
  {
   ulong ticket = 0;
   return GetOurPosition(ticket);
  }

void EnsureTradeDay(const int day_key)
  {
   if(day_key == g_trade_day_key)
      return;

   g_trade_day_key = day_key;
   g_long_taken_today = false;
   g_short_taken_today = false;
  }

bool SessionRangeForDay(const datetime day_start,
                        const int target_hhmm,
                        double &range_value)
  {
   range_value = 0.0;
   const datetime session_open_time = DateWithHhmm(day_start, strategy_session_open_hhmm);
   const datetime target_time = DateWithHhmm(day_start, target_hhmm);
   if(target_time < session_open_time)
      return false;

   const int open_shift = iBarShift(_Symbol, PERIOD_M30, session_open_time, false);
   const int target_shift = iBarShift(_Symbol, PERIOD_M30, target_time, false);
   if(open_shift < 0 || target_shift < 0 || open_shift < target_shift)
      return false;

   double high_value = -DBL_MAX;
   double low_value = DBL_MAX;
   int bars = 0;
   for(int shift = open_shift; shift >= target_shift; --shift)
     {
      const datetime bt = iTime(_Symbol, PERIOD_M30, shift);
      if(bt < session_open_time || bt > target_time)
         continue;

      const double high_price = iHigh(_Symbol, PERIOD_M30, shift);
      const double low_price = iLow(_Symbol, PERIOD_M30, shift);
      if(high_price <= 0.0 || low_price <= 0.0)
         continue;

      if(high_price > high_value)
         high_value = high_price;
      if(low_price < low_value)
         low_value = low_price;
      bars++;
     }

   if(bars <= 0 || high_value <= low_value)
      return false;

   range_value = high_value - low_value;
   return (range_value > 0.0);
  }

double AveragePriorSessionMove(const datetime current_bar_time,
                               const int target_hhmm,
                               const int lookback_days)
  {
   if(lookback_days <= 0)
      return 0.0;

   double sum = 0.0;
   int samples = 0;
   const datetime current_day = DayStart(current_bar_time);

   for(int d = 1; d <= 80 && samples < lookback_days; ++d)
     {
      const datetime d1_time = iTime(_Symbol, PERIOD_D1, d);
      if(d1_time <= 0)
         break;
      const datetime day_start = DayStart(d1_time);
      if(day_start >= current_day)
         continue;

      double day_range = 0.0;
      if(SessionRangeForDay(day_start, target_hhmm, day_range))
        {
         sum += day_range;
         samples++;
        }
     }

   if(samples < lookback_days)
      return 0.0;
   return sum / samples;
  }

double PriorDailyClose()
  {
   for(int d = 1; d <= 10; ++d)
     {
      const double close_price = iClose(_Symbol, PERIOD_D1, d);
      if(close_price > 0.0)
         return close_price;
     }
   return 0.0;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(HasOurPosition())
      return false;

   const datetime now = TimeCurrent();
   if(!InSession(now))
      return true;

   if(strategy_max_spread_points > 0)
     {
      const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }

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

   if(HasOurPosition())
      return false;

   const datetime bar_time = iTime(_Symbol, PERIOD_M30, 1);
   if(bar_time <= 0 || !InSession(bar_time) || !HalfHourBoundaryBar(bar_time))
      return false;

   const int day_key = DayKey(bar_time);
   EnsureTradeDay(day_key);

   const datetime day_start = DayStart(bar_time);
   const double session_open = iOpen(_Symbol, PERIOD_M30, iBarShift(_Symbol, PERIOD_M30, DateWithHhmm(day_start, strategy_session_open_hhmm), false));
   const double close_price = iClose(_Symbol, PERIOD_M30, 1);
   if(session_open <= 0.0 || close_price <= 0.0)
      return false;

   const int target_hhmm = Hhmm(bar_time);
   const double move = AveragePriorSessionMove(bar_time, target_hhmm, strategy_noise_lookback_days);
   if(move <= 0.0)
      return false;

   const double prior_close = PriorDailyClose();
   double gap_adj_up = 0.0;
   double gap_adj_dn = 0.0;
   if(prior_close > 0.0)
     {
      if(session_open < prior_close)
         gap_adj_up = prior_close - session_open;
      else if(session_open > prior_close)
         gap_adj_dn = session_open - prior_close;
     }

   const double upper = session_open + move + gap_adj_up;
   const double lower = session_open - move - gap_adj_dn;
   if(close_price > upper && !g_long_taken_today)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      req.type = QM_BUY;
      req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
      req.reason = "QM5_1045_NOISE_BOUNDARY_LONG";
      g_long_taken_today = true;
      return (req.sl > 0.0 && req.sl < entry);
     }

   if(close_price < lower && !g_short_taken_today)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      req.type = QM_SELL;
      req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
      req.reason = "QM5_1045_NOISE_BOUNDARY_SHORT";
      g_short_taken_today = true;
      return (req.sl > 0.0 && req.sl > entry);
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!HasOurPosition())
      return false;

   return (Hhmm(TimeCurrent()) >= strategy_session_close_hhmm);
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1045_zarattini-spy-intraday-momentum\"}");
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
