#property strict
#property version   "5.0"
#property description "QM5_10181 TradingView XAU NY ORB Retest"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10181;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_period_h1        = 50;
input int    strategy_atr_period_m5        = 14;
input double strategy_or_max_atr_mult      = 2.0;
input double strategy_break_body_ratio     = 0.70;
input double strategy_break_range_atr_mult = 1.20;
input int    strategy_pivot_left           = 3;
input int    strategy_pivot_right          = 3;
input int    strategy_pivot_scan_bars      = 48;
input double strategy_min_stop_atr_mult    = 0.50;
input double strategy_max_stop_atr_mult    = 2.50;
input double strategy_take_profit_rr       = 2.50;
input int    strategy_or_start_hhmm_ny     = 930;
input int    strategy_or_end_hhmm_ny       = 945;
input int    strategy_time_exit_hhmm_ny    = 1600;

int    g_day_key             = 0;
double g_or_high             = 0.0;
double g_or_low              = 0.0;
bool   g_or_ready            = false;
bool   g_skip_day            = false;
bool   g_trade_taken_today   = false;
int    g_breakout_dir        = 0;
double g_broken_level        = 0.0;

datetime BrokerToNewYork(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   return utc + (QM_IsUSDSTUTC(utc) ? -4 * 3600 : -5 * 3600);
  }

int DayKeyNY(const datetime broker_time)
  {
   MqlDateTime t;
   TimeToStruct(BrokerToNewYork(broker_time), t);
   return t.year * 10000 + t.mon * 100 + t.day;
  }

int HhmmNY(const datetime broker_time)
  {
   MqlDateTime t;
   TimeToStruct(BrokerToNewYork(broker_time), t);
   return t.hour * 100 + t.min;
  }

void ResetDay(const int day_key)
  {
   g_day_key = day_key;
   g_or_high = 0.0;
   g_or_low = 0.0;
   g_or_ready = false;
   g_skip_day = false;
   g_trade_taken_today = false;
   g_breakout_dir = 0;
   g_broken_level = 0.0;
  }

bool HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      g_trade_taken_today = true;
      return true;
     }
   return false;
  }

void UpdateOpeningRange(const datetime bar_time, const double high1, const double low1)
  {
   const int day_key = DayKeyNY(bar_time);
   if(day_key != g_day_key)
      ResetDay(day_key);

   const int hhmm = HhmmNY(bar_time);
   if(hhmm >= strategy_or_start_hhmm_ny && hhmm < strategy_or_end_hhmm_ny)
     {
      g_or_high = (g_or_high <= 0.0) ? high1 : MathMax(g_or_high, high1);
      g_or_low = (g_or_low <= 0.0) ? low1 : MathMin(g_or_low, low1);
      g_or_ready = false;
      return;
     }

   if(!g_or_ready && hhmm >= strategy_or_end_hhmm_ny && g_or_high > g_or_low)
     {
      g_or_ready = true;
      const double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period_m5, 1);
      if(atr > 0.0 && (g_or_high - g_or_low) > strategy_or_max_atr_mult * atr)
         g_skip_day = true;
     }
  }

bool StrongBreakoutCandle(const int dir, const double open1, const double high1,
                          const double low1, const double close1, const double atr)
  {
   const double range = high1 - low1;
   if(range <= 0.0 || atr <= 0.0)
      return false;

   const double body = MathAbs(close1 - open1);
   if(body < strategy_break_body_ratio * range)
      return false;
   if(range < strategy_break_range_atr_mult * atr)
      return false;

   if(dir > 0)
      return (close1 > g_or_high && close1 > open1);
   return (close1 < g_or_low && close1 < open1);
  }

bool FindPivotStop(const QM_OrderType side, const double level, double &stop)
  {
   const int left = MathMax(1, strategy_pivot_left);
   const int right = MathMax(1, strategy_pivot_right);
   const int max_center = MathMax(left + right + 1, strategy_pivot_scan_bars);

   for(int center = right + 1; center <= max_center; ++center)
     {
      bool pivot = true;
      if(side == QM_BUY)
        {
         const double low = iLow(_Symbol, PERIOD_M5, center);
         if(low <= 0.0 || low >= level)
            continue;
         for(int k = 1; k <= left; ++k)
            if(iLow(_Symbol, PERIOD_M5, center + k) <= low)
               pivot = false;
         for(int k = 1; k <= right; ++k)
            if(iLow(_Symbol, PERIOD_M5, center - k) <= low)
               pivot = false;
         if(pivot)
           {
            stop = NormalizeDouble(low, _Digits);
            return true;
           }
        }
      else
        {
         const double high = iHigh(_Symbol, PERIOD_M5, center);
         if(high <= 0.0 || high <= level)
            continue;
         for(int k = 1; k <= left; ++k)
            if(iHigh(_Symbol, PERIOD_M5, center + k) >= high)
               pivot = false;
         for(int k = 1; k <= right; ++k)
            if(iHigh(_Symbol, PERIOD_M5, center - k) >= high)
               pivot = false;
         if(pivot)
           {
            stop = NormalizeDouble(high, _Digits);
            return true;
           }
        }
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   // EntrySignal must still run on M5 closed bars during 09:30-09:45 NY
   // so it can build the opening range. Trade blocking for that window lives
   // in Strategy_EntrySignal after the range state is advanced.
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

   HasOurOpenPosition();
   if(g_trade_taken_today)
      return false;

   const datetime bar_time = iTime(_Symbol, PERIOD_M5, 1);
   if(bar_time <= 0)
      return false;

   const double open1 = iOpen(_Symbol, PERIOD_M5, 1);
   const double high1 = iHigh(_Symbol, PERIOD_M5, 1);
   const double low1 = iLow(_Symbol, PERIOD_M5, 1);
   const double close1 = iClose(_Symbol, PERIOD_M5, 1);
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return false;

   UpdateOpeningRange(bar_time, high1, low1);
   const int hhmm = HhmmNY(bar_time);
   if(g_skip_day || !g_or_ready || hhmm < strategy_or_end_hhmm_ny || hhmm >= strategy_time_exit_hhmm_ny)
      return false;

   const double ema_h1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period_h1, 1);
   const double h1_close = iClose(_Symbol, PERIOD_H1, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period_m5, 1);
   if(ema_h1 <= 0.0 || h1_close <= 0.0 || atr <= 0.0)
      return false;

   const bool long_bias = (h1_close > ema_h1);
   const bool short_bias = (h1_close < ema_h1);

   if(g_breakout_dir == 0)
     {
      if(long_bias && StrongBreakoutCandle(1, open1, high1, low1, close1, atr))
        {
         g_breakout_dir = 1;
         g_broken_level = g_or_high;
        }
      else if(short_bias && StrongBreakoutCandle(-1, open1, high1, low1, close1, atr))
        {
         g_breakout_dir = -1;
         g_broken_level = g_or_low;
        }
      return false;
     }

   QM_OrderType side = (g_breakout_dir > 0) ? QM_BUY : QM_SELL;
   if(side == QM_BUY && !(low1 <= g_broken_level && close1 > g_broken_level && long_bias))
      return false;
   if(side == QM_SELL && !(high1 >= g_broken_level && close1 < g_broken_level && short_bias))
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double stop = 0.0;
   if(!FindPivotStop(side, g_broken_level, stop))
      return false;

   double stop_distance = MathAbs(entry - stop);
   const double min_stop = strategy_min_stop_atr_mult * atr;
   const double max_stop = strategy_max_stop_atr_mult * atr;
   if(stop_distance < min_stop)
     {
      stop = (side == QM_BUY) ? entry - min_stop : entry + min_stop;
      stop_distance = min_stop;
     }
   if(stop_distance > max_stop)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = NormalizeDouble(stop, _Digits);
   req.tp = QM_TakeRR(_Symbol, side, entry, req.sl, strategy_take_profit_rr);
   req.reason = (side == QM_BUY) ? "TV_XAU_NY_ORB_RETEST_LONG" : "TV_XAU_NY_ORB_RETEST_SHORT";
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   g_trade_taken_today = true;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card baseline: no partial close, no trailing, full position exits at 2.5R.
  }

bool Strategy_ExitSignal()
  {
   if(!HasOurOpenPosition())
      return false;
   return (HhmmNY(TimeCurrent()) >= strategy_time_exit_hhmm_ny);
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
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10181\",\"ea\":\"tv-xau-ny-orb-retest\"}");
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
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

   QM_EquityStreamOnNewBar();

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

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
