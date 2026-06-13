#property strict
#property version   "5.0"
#property description "QM5_12551 ICT Turtle Soup Asian False Break M15"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12551;
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
input int    strategy_asian_start_gmt_hour     = 23;
input int    strategy_asian_end_gmt_hour       = 3;
input int    strategy_london_start_gmt_hour    = 7;
input int    strategy_london_end_gmt_hour      = 9;
input int    strategy_session_scan_bars        = 160;
input int    strategy_min_asian_bars           = 12;
input int    strategy_judas_max_bars           = 8;
input int    strategy_pullback_expiry_bars     = 3;
input int    strategy_atr_period               = 14;
input double strategy_atr_sl_mult              = 0.5;
input double strategy_breakout_buffer_pips     = 1.0;
input double strategy_rr_fallback              = 2.0;
input double strategy_atr_trail_mult           = 1.0;
input int    strategy_max_spread_points        = 80;

int    g_session_key = 0;
bool   g_range_ready = false;
double g_asian_high = 0.0;
double g_asian_low = 0.0;

bool   g_bear_sweep_seen = false;
bool   g_bull_sweep_seen = false;
bool   g_fake_bear_confirmed = false;
bool   g_fake_bull_confirmed = false;
int    g_bear_bars_after_confirm = 0;
int    g_bull_bars_after_confirm = 0;
double g_fake_bear_extreme = 0.0;
double g_fake_bull_extreme = 0.0;
bool   g_long_order_submitted = false;
bool   g_short_order_submitted = false;

double g_active_long_tp1 = 0.0;
double g_active_short_tp1 = 0.0;
bool   g_partial_done = false;

double PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

double NormalizeStrategyPrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
  }

int DateKeyFromUTC(const datetime utc)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

datetime UTCFromKeyHour(const int key, const int hour)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   dt.year = key / 10000;
   dt.mon = (key / 100) % 100;
   dt.day = key % 100;
   dt.hour = hour;
   return StructToTime(dt);
  }

int SessionKeyForUTC(const datetime utc)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc, dt);
   if(dt.hour >= strategy_asian_start_gmt_hour)
      return DateKeyFromUTC(utc + 86400);
   return DateKeyFromUTC(utc);
  }

bool IsUTCInLondonKZ(const datetime utc)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc, dt);
   return (dt.hour >= strategy_london_start_gmt_hour &&
           dt.hour < strategy_london_end_gmt_hour);
  }

void ResetSessionState(const int session_key)
  {
   g_session_key = session_key;
   g_range_ready = false;
   g_asian_high = 0.0;
   g_asian_low = 0.0;
   g_bear_sweep_seen = false;
   g_bull_sweep_seen = false;
   g_fake_bear_confirmed = false;
   g_fake_bull_confirmed = false;
   g_bear_bars_after_confirm = 0;
   g_bull_bars_after_confirm = 0;
   g_fake_bear_extreme = DBL_MAX;
   g_fake_bull_extreme = -DBL_MAX;
   g_long_order_submitted = false;
   g_short_order_submitted = false;
   g_active_long_tp1 = 0.0;
   g_active_short_tp1 = 0.0;
   g_partial_done = false;
  }

bool ComputeAsianRangeForSession(const int session_key)
  {
   const datetime session_end_utc = UTCFromKeyHour(session_key, strategy_asian_end_gmt_hour);
   const datetime session_start_utc = session_end_utc - 4 * 3600;

   double hi = -DBL_MAX;
   double lo = DBL_MAX;
   int count = 0;
   const int max_scan = MathMax(strategy_session_scan_bars, 32);

   // perf-allowed: bounded M15 structural scan inside the framework QM_IsNewBar entry gate.
   for(int shift = 1; shift <= max_scan; ++shift)
     {
      const datetime broker_bar = iTime(_Symbol, PERIOD_M15, shift); // perf-allowed
      if(broker_bar <= 0)
         break;

      const datetime utc_bar = QM_BrokerToUTC(broker_bar);
      if(utc_bar < session_start_utc)
         break;
      if(utc_bar >= session_start_utc && utc_bar < session_end_utc)
        {
         const double h = iHigh(_Symbol, PERIOD_M15, shift); // perf-allowed
         const double l = iLow(_Symbol, PERIOD_M15, shift); // perf-allowed
         if(h > 0.0 && l > 0.0)
           {
            hi = MathMax(hi, h);
            lo = MathMin(lo, l);
            count++;
           }
        }
     }

   if(count < strategy_min_asian_bars || hi <= 0.0 || lo <= 0.0 || hi <= lo)
      return false;

   g_asian_high = hi;
   g_asian_low = lo;
   g_range_ready = true;
   return true;
  }

void AdvanceSessionState(const datetime closed_bar_broker)
  {
   const datetime closed_bar_utc = QM_BrokerToUTC(closed_bar_broker);
   const int session_key = SessionKeyForUTC(closed_bar_utc);
   if(session_key != g_session_key)
      ResetSessionState(session_key);

   if(!g_range_ready && closed_bar_utc >= UTCFromKeyHour(session_key, strategy_asian_end_gmt_hour))
      ComputeAsianRangeForSession(session_key);
  }

bool HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool HasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT)
         return true;
     }
   return false;
  }

void RemoveExpiredSetupOrders()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type != ORDER_TYPE_BUY_LIMIT && type != ORDER_TYPE_SELL_LIMIT)
         continue;
      const datetime expiration = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
      if(expiration > 0 && TimeCurrent() > expiration)
         QM_TM_RemovePendingOrder(ticket, "turtle_soup_limit_expired");
     }
  }

double PriorDayHigh()
  {
   return iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed
  }

double PriorDayLow()
  {
   return iLow(_Symbol, PERIOD_D1, 1); // perf-allowed
  }

double ResolveLongTP1(const double entry_price, const double sl_price)
  {
   const double pdh = PriorDayHigh();
   if(pdh > entry_price)
      return NormalizeStrategyPrice(pdh);
   return NormalizeStrategyPrice(entry_price + MathAbs(entry_price - sl_price) * strategy_rr_fallback);
  }

double ResolveShortTP1(const double entry_price, const double sl_price)
  {
   const double pdl = PriorDayLow();
   if(pdl > 0.0 && pdl < entry_price)
      return NormalizeStrategyPrice(pdl);
   return NormalizeStrategyPrice(entry_price - MathAbs(entry_price - sl_price) * strategy_rr_fallback);
  }

void FillEntryRequestDefaults(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool BuildLongLimitRequest(QM_EntryRequest &req)
  {
   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   const double entry = NormalizeStrategyPrice(g_asian_high);
   const double sl = NormalizeStrategyPrice(g_fake_bear_extreme - atr * strategy_atr_sl_mult);
   if(atr <= 0.0 || entry <= 0.0 || sl <= 0.0 || sl >= entry)
      return false;

   req.type = QM_BUY_LIMIT;
   req.price = entry;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = "TS_ASIAN_BEAR_TRAP_LONG_LIMIT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = strategy_pullback_expiry_bars * 15 * 60;
   g_active_long_tp1 = ResolveLongTP1(entry, sl);
   return true;
  }

bool BuildShortLimitRequest(QM_EntryRequest &req)
  {
   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   const double entry = NormalizeStrategyPrice(g_asian_low);
   const double sl = NormalizeStrategyPrice(g_fake_bull_extreme + atr * strategy_atr_sl_mult);
   if(atr <= 0.0 || entry <= 0.0 || sl <= 0.0 || sl <= entry)
      return false;

   req.type = QM_SELL_LIMIT;
   req.price = entry;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = "TS_ASIAN_BULL_TRAP_SHORT_LIMIT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = strategy_pullback_expiry_bars * 15 * 60;
   g_active_short_tp1 = ResolveShortTP1(entry, sl);
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M15)
      return true;

   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_max_spread_points > 0 && spread > strategy_max_spread_points)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   FillEntryRequestDefaults(req);
   RemoveExpiredSetupOrders();

   const datetime closed_bar_broker = iTime(_Symbol, PERIOD_M15, 1); // perf-allowed
   if(closed_bar_broker <= 0)
      return false;

   AdvanceSessionState(closed_bar_broker);
   const datetime closed_bar_utc = QM_BrokerToUTC(closed_bar_broker);
   if(!g_range_ready || !IsUTCInLondonKZ(closed_bar_utc))
      return false;
   if(HasOurOpenPosition() || HasOurPendingOrder())
      return false;

   const double pip = PipSize();
   if(pip <= 0.0)
      return false;

   const double breakout_buffer = strategy_breakout_buffer_pips * pip;
   const double h = iHigh(_Symbol, PERIOD_M15, 1); // perf-allowed
   const double l = iLow(_Symbol, PERIOD_M15, 1); // perf-allowed
   const double c = iClose(_Symbol, PERIOD_M15, 1); // perf-allowed
   if(h <= 0.0 || l <= 0.0 || c <= 0.0)
      return false;

   const bool bear_confirmed_before = g_fake_bear_confirmed;
   const bool bull_confirmed_before = g_fake_bull_confirmed;

   if(l < g_asian_low)
     {
      g_bear_sweep_seen = true;
      g_fake_bear_extreme = MathMin(g_fake_bear_extreme, l);
     }
   if(g_bear_sweep_seen && !g_fake_bear_confirmed && c > g_asian_low)
     {
      g_fake_bear_confirmed = true;
      g_bear_bars_after_confirm = 0;
     }

   if(h > g_asian_high)
     {
      g_bull_sweep_seen = true;
      g_fake_bull_extreme = MathMax(g_fake_bull_extreme, h);
     }
   if(g_bull_sweep_seen && !g_fake_bull_confirmed && c < g_asian_high)
     {
      g_fake_bull_confirmed = true;
      g_bull_bars_after_confirm = 0;
     }

   if(bear_confirmed_before && !g_long_order_submitted &&
      g_bear_bars_after_confirm <= strategy_judas_max_bars &&
      h > g_asian_high + breakout_buffer)
     {
      if(BuildLongLimitRequest(req))
        {
         g_long_order_submitted = true;
         return true;
        }
     }

   if(bull_confirmed_before && !g_short_order_submitted &&
      g_bull_bars_after_confirm <= strategy_judas_max_bars &&
      l < g_asian_low - breakout_buffer)
     {
      if(BuildShortLimitRequest(req))
        {
         g_short_order_submitted = true;
         return true;
        }
     }

   if(g_fake_bear_confirmed && g_bear_bars_after_confirm <= strategy_judas_max_bars)
      g_bear_bars_after_confirm++;
   if(g_fake_bull_confirmed && g_bull_bars_after_confirm <= strategy_judas_max_bars)
      g_bull_bars_after_confirm++;

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   bool saw_position = false;
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

      saw_position = true;
      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const bool is_buy = (type == POSITION_TYPE_BUY);
      const double market = is_buy ? bid : ask;
      double target = is_buy ? g_active_long_tp1 : g_active_short_tp1;

      if(target <= 0.0)
         target = is_buy ? PriorDayHigh() : PriorDayLow();

      if(!g_partial_done && target > 0.0 &&
         ((is_buy && market >= target) || (!is_buy && market <= target)))
        {
         const double half_lots = volume * 0.5;
         if(half_lots >= min_lot)
            g_partial_done = QM_TM_PartialClose(ticket, half_lots, QM_EXIT_PARTIAL);
         else
            g_partial_done = true;
        }

      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_atr_trail_mult);
     }

   if(!saw_position)
      g_partial_done = false;
  }

bool Strategy_ExitSignal()
  {
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12551\",\"ea\":\"ict_turtle_soup_asian_false_break_m15\"}");
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
