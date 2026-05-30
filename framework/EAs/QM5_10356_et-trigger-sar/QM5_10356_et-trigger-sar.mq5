#property strict
#property version   "5.0"
#property description "QM5_10356 Elite Trader Intraday Trigger SAR"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10356;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period        = 14;
input double strategy_atr_stop_cap_mult = 1.5;
input int    strategy_stop_offset_ticks = 1;
input double strategy_spread_median_mult = 2.5;
input int    strategy_spread_median_bars = 96;
input int    strategy_skip_open_minutes = 5;
input int    strategy_skip_close_minutes = 15;
input int    strategy_session_start_hour = -1;
input int    strategy_session_start_min  = -1;
input int    strategy_session_end_hour   = -1;
input int    strategy_session_end_min    = -1;

int    g_trade_day_key = 0;
bool   g_session_extremes_ready = false;
double g_session_high = 0.0;
double g_session_low = 0.0;
double g_best_long_high = 0.0;
double g_best_short_low = 0.0;
double g_spread_points[256];
int    g_spread_count = 0;
double g_median_spread_points = 0.0;
bool   g_bar_cache_ready = false;
datetime g_closed_bar_time = 0;
double g_high1 = 0.0;
double g_low1 = 0.0;
double g_close1 = 0.0;
double g_high2 = 0.0;
double g_low2 = 0.0;

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_MinuteOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

void Strategy_DefaultSession(int &start_hour, int &start_min, int &end_hour, int &end_min)
  {
   start_hour = strategy_session_start_hour;
   start_min = strategy_session_start_min;
   end_hour = strategy_session_end_hour;
   end_min = strategy_session_end_min;

   if(start_hour >= 0 && start_min >= 0 && end_hour >= 0 && end_min >= 0)
      return;

   if(_Symbol == "GDAXI.DWX")
     {
      start_hour = 10;
      start_min = 0;
      end_hour = 18;
      end_min = 30;
      return;
     }

   start_hour = 16;
   start_min = 30;
   end_hour = 22;
   end_min = 45;
  }

bool Strategy_MinuteInWindow(const int now_min, const int start_minute, const int end_minute)
  {
   if(start_minute <= end_minute)
      return (now_min >= start_minute && now_min < end_minute);
   return (now_min >= start_minute || now_min < end_minute);
  }

bool Strategy_InCoreSession(const datetime t)
  {
   int sh, sm, eh, em;
   Strategy_DefaultSession(sh, sm, eh, em);
   return Strategy_MinuteInWindow(Strategy_MinuteOfDay(t), sh * 60 + sm, eh * 60 + em);
  }

bool Strategy_InEntryWindow(const datetime t)
  {
   int sh, sm, eh, em;
   Strategy_DefaultSession(sh, sm, eh, em);
   int start_minute = sh * 60 + sm + MathMax(strategy_skip_open_minutes, 0);
   int end_minute = eh * 60 + em - MathMax(strategy_skip_close_minutes, 0);
   while(start_minute >= 1440)
      start_minute -= 1440;
   while(end_minute < 0)
      end_minute += 1440;
   return Strategy_MinuteInWindow(Strategy_MinuteOfDay(t), start_minute, end_minute);
  }

bool Strategy_AfterSessionEnd(const datetime t)
  {
   int sh, sm, eh, em;
   Strategy_DefaultSession(sh, sm, eh, em);
   const int now_min = Strategy_MinuteOfDay(t);
   const int start_minute = sh * 60 + sm;
   const int end_minute = eh * 60 + em;
   if(start_minute <= end_minute)
      return (now_min >= end_minute);
   return (now_min >= end_minute && now_min < start_minute);
  }

void Strategy_ResetDay(const datetime t)
  {
   const int day_key = Strategy_DayKey(t);
   if(day_key == g_trade_day_key)
      return;

   g_trade_day_key = day_key;
   g_session_extremes_ready = false;
   g_session_high = 0.0;
   g_session_low = 0.0;
   g_best_long_high = 0.0;
   g_best_short_low = 0.0;
   g_spread_count = 0;
   g_median_spread_points = 0.0;
  }

void Strategy_AdvanceStateOnNewBar()
  {
   const datetime bar_time = iTime(_Symbol, _Period, 1);
   if(bar_time <= 0)
     {
      g_bar_cache_ready = false;
      return;
     }

   Strategy_ResetDay(bar_time);
   Strategy_UpdateSpreadMedian();

   g_closed_bar_time = bar_time;
   g_high1 = iHigh(_Symbol, _Period, 1);
   g_low1 = iLow(_Symbol, _Period, 1);
   g_close1 = iClose(_Symbol, _Period, 1);
   g_high2 = iHigh(_Symbol, _Period, 2);
   g_low2 = iLow(_Symbol, _Period, 2);
   g_bar_cache_ready = (g_high1 > 0.0 && g_low1 > 0.0 && g_close1 > 0.0 && g_high2 > 0.0 && g_low2 > 0.0);
  }

double Strategy_CurrentSpreadPoints()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return 0.0;
   return (ask - bid) / point;
  }

void Strategy_UpdateSpreadMedian()
  {
   const double spread = Strategy_CurrentSpreadPoints();
   if(spread <= 0.0)
      return;

   const int max_bars = (int)MathMin((double)strategy_spread_median_bars, 256.0);
   if(max_bars <= 0)
      return;

   if(g_spread_count < max_bars)
      g_spread_points[g_spread_count++] = spread;
   else
     {
      for(int i = 1; i < max_bars; ++i)
         g_spread_points[i - 1] = g_spread_points[i];
      g_spread_points[max_bars - 1] = spread;
      g_spread_count = max_bars;
     }

   double sorted[256];
   for(int i = 0; i < g_spread_count; ++i)
      sorted[i] = g_spread_points[i];

   for(int i = 1; i < g_spread_count; ++i)
     {
      const double value = sorted[i];
      int j = i - 1;
      while(j >= 0 && sorted[j] > value)
        {
         sorted[j + 1] = sorted[j];
         --j;
        }
      sorted[j + 1] = value;
     }

   const int mid = g_spread_count / 2;
   if((g_spread_count % 2) == 0 && g_spread_count > 1)
      g_median_spread_points = (sorted[mid - 1] + sorted[mid]) * 0.5;
   else
      g_median_spread_points = sorted[mid];
  }

bool Strategy_SpreadOK()
  {
   if(g_median_spread_points <= 0.0 || strategy_spread_median_mult <= 0.0)
      return true;
   const double spread = Strategy_CurrentSpreadPoints();
   if(spread <= 0.0)
      return false;
   return (spread <= g_median_spread_points * strategy_spread_median_mult);
  }

bool Strategy_HasOurPosition()
  {
   const int magic = QM_FrameworkMagic();
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

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

void Strategy_UpdateSessionExtremes(const double high_value, const double low_value)
  {
   if(!g_session_extremes_ready)
     {
      g_session_high = high_value;
      g_session_low = low_value;
      g_session_extremes_ready = true;
      return;
     }

   g_session_high = MathMax(g_session_high, high_value);
   g_session_low = MathMin(g_session_low, low_value);
  }

bool Strategy_BuildMarketRequest(const QM_OrderType type,
                                 const double entry_estimate,
                                 const double trigger_stop,
                                 const string reason,
                                 QM_EntryRequest &req)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(point <= 0.0 || tick_size <= 0.0 || entry_estimate <= 0.0 || trigger_stop <= 0.0)
      return false;

   double sl = trigger_stop;
   const bool is_buy = (type == QM_BUY);
   const double atr_cap = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1) * strategy_atr_stop_cap_mult;
   const double raw_dist = MathAbs(entry_estimate - sl);
   if(atr_cap > 0.0 && raw_dist > atr_cap)
      sl = is_buy ? (entry_estimate - atr_cap) : (entry_estimate + atr_cap);

   const double stop_points = MathAbs(entry_estimate - sl) / point;
   const double spread_points = Strategy_CurrentSpreadPoints();
   if(spread_points <= 0.0 || stop_points < spread_points * 4.0)
      return false;

   if(is_buy && !(sl < entry_estimate))
      return false;
   if(!is_buy && !(sl > entry_estimate))
      return false;

   req.type = type;
   req.price = 0.0;
   req.sl = Strategy_NormalizePrice(sl);
   req.tp = 0.0;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return (req.sl > 0.0);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   const datetime now = TimeCurrent();
   Strategy_ResetDay(now);

   if(Strategy_HasOurPosition())
      return false;
   if(!Strategy_InCoreSession(now))
      return true;
   if(!Strategy_SpreadOK())
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

   if(!g_bar_cache_ready || g_closed_bar_time <= 0)
      return false;

   if(!Strategy_InCoreSession(g_closed_bar_time))
      return false;

   if(!g_session_extremes_ready)
     {
      Strategy_UpdateSessionExtremes(g_high1, g_low1);
      return false;
     }

   const double prior_high = g_session_high;
   const double prior_low = g_session_low;
   const bool long_signal = (g_close1 >= prior_high && g_low1 >= prior_high);
   const bool short_signal = (g_close1 <= prior_low && g_high1 <= prior_low);

   Strategy_UpdateSessionExtremes(g_high1, g_low1);

   if(Strategy_HasOurPosition() || !Strategy_InEntryWindow(g_closed_bar_time) || !Strategy_SpreadOK())
      return false;

   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double stop_offset = MathMax(strategy_stop_offset_ticks, 0) * tick_size;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(tick_size <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   if(long_signal)
      return Strategy_BuildMarketRequest(QM_BUY, ask, g_low1 - stop_offset, "ET_TRIGGER_SAR_LONG", req);

   if(short_signal)
      return Strategy_BuildMarketRequest(QM_SELL, bid, g_high1 + stop_offset, "ET_TRIGGER_SAR_SHORT", req);

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(tick_size <= 0.0 || point <= 0.0 || !g_bar_cache_ready)
      return;

   const double stop_offset = MathMax(strategy_stop_offset_ticks, 0) * tick_size;
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
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);

      if(pos_type == POSITION_TYPE_BUY)
        {
         if(g_best_long_high <= 0.0)
            g_best_long_high = open_price;
         if(g_high1 <= g_best_long_high + point * 0.5)
            continue;

         g_best_long_high = g_high1;
         const double target_sl = Strategy_NormalizePrice(g_low2 - stop_offset);
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(target_sl > 0.0 && target_sl < bid && (current_sl <= 0.0 || target_sl > current_sl + point * 0.5))
            QM_TM_MoveSL(ticket, target_sl, "et_trigger_sar_trail_long");
        }
      else if(pos_type == POSITION_TYPE_SELL)
        {
         if(g_best_short_low <= 0.0)
            g_best_short_low = open_price;
         if(g_low1 >= g_best_short_low - point * 0.5)
            continue;

         g_best_short_low = g_low1;
         const double target_sl = Strategy_NormalizePrice(g_high2 + stop_offset);
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(target_sl > 0.0 && target_sl > ask && (current_sl <= 0.0 || target_sl < current_sl - point * 0.5))
            QM_TM_MoveSL(ticket, target_sl, "et_trigger_sar_trail_short");
        }
     }
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOurPosition())
      return false;
   return Strategy_AfterSessionEnd(TimeCurrent());
  }

// News Filter Hook (callable for P8 News Impact phase)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10356_et-trigger-sar\"}");
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

   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
     {
      QM_EquityStreamOnNewBar();
      Strategy_AdvanceStateOnNewBar();
     }

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

   if(!is_new_bar)
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
