#property strict
#property version   "5.0"
#property description "QM5_12537 ICT OTE Displacement XAU"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12537;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_FTMO;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf        = PERIOD_M15;
input int             strategy_session_start_h  = 14;
input int             strategy_session_end_h    = 17;
input int             strategy_time_exit_h      = 21;
input int             strategy_asia_start_h     = 0;
input int             strategy_asia_end_h       = 8;
input int             strategy_pivot_left_bars  = 2;
input int             strategy_pivot_right_bars = 2;
input int             strategy_pool_lookback_m15 = 96;
input int             strategy_mss_max_bars     = 8;
input int             strategy_limit_valid_bars = 12;
input int             strategy_atr_period       = 14;
input double          strategy_ote_leg_fraction = 0.295;
input double          strategy_stop_atr_buffer  = 0.30;
input double          strategy_max_risk_atr     = 1.50;
input double          strategy_runner_rr        = 2.50;
input double          strategy_partial_fraction = 0.50;
input double          strategy_max_spread_points = 0.0;

struct StrategySetup
  {
   bool     active;
   datetime sweep_time;
   int      bars_since_sweep;
   double   sweep_extreme;
   double   mss_level;
  };

StrategySetup g_long_setup;
StrategySetup g_short_setup;
int           g_day_key = 0;
bool          g_order_or_trade_today = false;
double        g_pending_tp1 = 0.0;
int           g_pending_side = 0;
ulong         g_active_ticket = 0;
double        g_active_tp1 = 0.0;
bool          g_active_partial_done = false;

void Strategy_ResetSetup(StrategySetup &setup)
  {
   setup.active = false;
   setup.sweep_time = 0;
   setup.bars_since_sweep = 0;
   setup.sweep_extreme = 0.0;
   setup.mss_level = 0.0;
  }

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

void Strategy_EnsureDay(const datetime t)
  {
   const int key = Strategy_DayKey(t);
   if(key == g_day_key)
      return;

   g_day_key = key;
   g_order_or_trade_today = false;
   Strategy_ResetSetup(g_long_setup);
   Strategy_ResetSetup(g_short_setup);
   g_pending_tp1 = 0.0;
   g_pending_side = 0;
  }

int Strategy_Hour(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return dt.hour;
  }

bool Strategy_InHourWindow(const datetime t, const int start_h, const int end_h)
  {
   const int h = Strategy_Hour(t);
   if(start_h == end_h)
      return true;
   if(start_h < end_h)
      return (h >= start_h && h < end_h);
   return (h >= start_h || h < end_h);
  }

bool Strategy_SpreadAllows()
  {
   if(strategy_max_spread_points <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   return ((ask - bid) / point <= strategy_max_spread_points);
  }

bool Strategy_IsOurPendingLimitType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_SELL_LIMIT);
  }

bool Strategy_HasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(Strategy_IsOurPendingLimitType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

bool Strategy_SelectOurPosition(ulong &ticket,
                                ENUM_POSITION_TYPE &pos_type,
                                double &volume,
                                double &open_price,
                                double &sl)
  {
   ticket = 0;
   pos_type = POSITION_TYPE_BUY;
   volume = 0.0;
   open_price = 0.0;
   sl = 0.0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      volume = PositionGetDouble(POSITION_VOLUME);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      return true;
     }
   return false;
  }

void Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY_LIMIT;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_LoadSignalBars(MqlRates &rates[], const int need)
  {
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_signal_tf, 1, need, rates); // perf-allowed: bounded ICT structure scan; Strategy_EntrySignal is called only after QM_IsNewBar().
   return (copied >= need);
  }

bool Strategy_LoadPrevDay(double &prev_low, double &prev_high)
  {
   MqlRates daily[1];
   if(CopyRates(_Symbol, PERIOD_D1, 1, 1, daily) != 1) // perf-allowed: one closed D1 liquidity reference, new-bar only.
      return false;

   prev_low = daily[0].low;
   prev_high = daily[0].high;
   return (prev_high > prev_low && prev_low > 0.0);
  }

bool Strategy_FindAsiaRange(const int day_key, double &asia_low, double &asia_high)
  {
   asia_low = DBL_MAX;
   asia_high = -DBL_MAX;

   const int need = MathMax(32, strategy_pool_lookback_m15 + 32);
   MqlRates rates[];
   if(!Strategy_LoadSignalBars(rates, need))
      return false;

   for(int i = 0; i < ArraySize(rates); ++i)
     {
      if(Strategy_DayKey(rates[i].time) != day_key)
         continue;
      if(!Strategy_InHourWindow(rates[i].time, strategy_asia_start_h, strategy_asia_end_h))
         continue;

      asia_low = MathMin(asia_low, rates[i].low);
      asia_high = MathMax(asia_high, rates[i].high);
     }

   return (asia_low < DBL_MAX && asia_high > -DBL_MAX && asia_high > asia_low);
  }

bool Strategy_IsPivotLow(const MqlRates &rates[], const int index, const int left, const int right)
  {
   const double v = rates[index].low;
   for(int j = index - right; j <= index + left; ++j)
     {
      if(j == index)
         continue;
      if(j < 0 || j >= ArraySize(rates))
         return false;
      if(rates[j].low <= v)
         return false;
     }
   return true;
  }

bool Strategy_IsPivotHigh(const MqlRates &rates[], const int index, const int left, const int right)
  {
   const double v = rates[index].high;
   for(int j = index - right; j <= index + left; ++j)
     {
      if(j == index)
         continue;
      if(j < 0 || j >= ArraySize(rates))
         return false;
      if(rates[j].high >= v)
         return false;
     }
   return true;
  }

bool Strategy_FindPivotPools(const MqlRates &rates[],
                             const double reference_close,
                             double &lowest_pivot_low,
                             double &highest_pivot_high)
  {
   lowest_pivot_low = 0.0;
   highest_pivot_high = 0.0;

   const int left = MathMax(1, strategy_pivot_left_bars);
   const int right = MathMax(1, strategy_pivot_right_bars);
   const int max_i = MathMin(ArraySize(rates) - left - 1, strategy_pool_lookback_m15);
   if(max_i <= right)
      return false;

   for(int i = right; i <= max_i; ++i)
     {
      if(Strategy_IsPivotLow(rates, i, left, right) && rates[i].low < reference_close)
        {
         if(lowest_pivot_low <= 0.0 || rates[i].low < lowest_pivot_low)
            lowest_pivot_low = rates[i].low;
        }

      if(Strategy_IsPivotHigh(rates, i, left, right) && rates[i].high > reference_close)
        {
         if(highest_pivot_high <= 0.0 || rates[i].high > highest_pivot_high)
            highest_pivot_high = rates[i].high;
        }
     }

   return (lowest_pivot_low > 0.0 || highest_pivot_high > 0.0);
  }

bool Strategy_FindRecentPivotHigh(const MqlRates &rates[], double &pivot_high)
  {
   pivot_high = 0.0;
   const int left = MathMax(1, strategy_pivot_left_bars);
   const int right = MathMax(1, strategy_pivot_right_bars);
   const int max_i = MathMin(ArraySize(rates) - left - 1, strategy_pool_lookback_m15);

   for(int i = right + 1; i <= max_i; ++i)
     {
      if(Strategy_IsPivotHigh(rates, i, left, right))
        {
         pivot_high = rates[i].high;
         return true;
        }
     }
   return false;
  }

bool Strategy_FindRecentPivotLow(const MqlRates &rates[], double &pivot_low)
  {
   pivot_low = 0.0;
   const int left = MathMax(1, strategy_pivot_left_bars);
   const int right = MathMax(1, strategy_pivot_right_bars);
   const int max_i = MathMin(ArraySize(rates) - left - 1, strategy_pool_lookback_m15);

   for(int i = right + 1; i <= max_i; ++i)
     {
      if(Strategy_IsPivotLow(rates, i, left, right))
        {
         pivot_low = rates[i].low;
         return true;
        }
     }
   return false;
  }

bool Strategy_SweptAnyLongPool(const MqlRates &bar,
                               const double prev_day_low,
                               const double asia_low,
                               const double pivot_low)
  {
   if(prev_day_low > 0.0 && bar.low < prev_day_low && bar.close > prev_day_low)
      return true;
   if(asia_low > 0.0 && bar.low < asia_low && bar.close > asia_low)
      return true;
   if(pivot_low > 0.0 && bar.low < pivot_low && bar.close > pivot_low)
      return true;
   return false;
  }

bool Strategy_SweptAnyShortPool(const MqlRates &bar,
                                const double prev_day_high,
                                const double asia_high,
                                const double pivot_high)
  {
   if(prev_day_high > 0.0 && bar.high > prev_day_high && bar.close < prev_day_high)
      return true;
   if(asia_high > 0.0 && bar.high > asia_high && bar.close < asia_high)
      return true;
   if(pivot_high > 0.0 && bar.high > pivot_high && bar.close < pivot_high)
      return true;
   return false;
  }

bool Strategy_ValidateLimitGeometry(const QM_OrderType type,
                                    const double entry,
                                    const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || entry <= 0.0 || sl <= 0.0)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double spread_points = MathMax(0.0, (ask - bid) / point);
   const double min_points = (double)((stops_level > 0) ? stops_level : 0) + spread_points;

   if(type == QM_BUY_LIMIT && entry >= ask - point)
      return false;
   if(type == QM_SELL_LIMIT && entry <= bid + point)
      return false;

   const double entry_points = (type == QM_BUY_LIMIT) ? ((ask - entry) / point) : ((entry - bid) / point);
   const double sl_points = MathAbs(entry - sl) / point;
   return (entry_points > min_points && sl_points > min_points);
  }

bool Strategy_BuildOteRequest(const bool want_long,
                              const MqlRates &mss_bar,
                              const StrategySetup &setup,
                              QM_EntryRequest &req)
  {
   const double atr = QM_ATR(_Symbol, strategy_signal_tf, MathMax(1, strategy_atr_period), 1);
   if(atr <= 0.0 || setup.sweep_extreme <= 0.0)
      return false;

   const double fraction = MathMax(0.0, MathMin(1.0, strategy_ote_leg_fraction));
   double entry = 0.0;
   double sl = 0.0;
   double tp1 = 0.0;
   double tp2 = 0.0;

   if(want_long)
     {
      const double leg_high = mss_bar.high;
      const double leg = leg_high - setup.sweep_extreme;
      if(leg <= 0.0)
         return false;

      entry = setup.sweep_extreme + fraction * leg;
      sl = setup.sweep_extreme - strategy_stop_atr_buffer * atr;
      const double risk = entry - sl;
      if(risk <= 0.0 || risk > strategy_max_risk_atr * atr)
         return false;

      tp1 = leg_high;
      tp2 = entry + strategy_runner_rr * risk;
      if(tp1 <= entry || tp2 <= entry)
         return false;

      req.type = QM_BUY_LIMIT;
      req.reason = "ICT_OTE_LONG";
     }
   else
     {
      const double leg_low = mss_bar.low;
      const double leg = setup.sweep_extreme - leg_low;
      if(leg <= 0.0)
         return false;

      entry = setup.sweep_extreme - fraction * leg;
      sl = setup.sweep_extreme + strategy_stop_atr_buffer * atr;
      const double risk = sl - entry;
      if(risk <= 0.0 || risk > strategy_max_risk_atr * atr)
         return false;

      tp1 = leg_low;
      tp2 = entry - strategy_runner_rr * risk;
      if(tp1 >= entry || tp2 >= entry)
         return false;

      req.type = QM_SELL_LIMIT;
      req.reason = "ICT_OTE_SHORT";
     }

   req.price = NormalizeDouble(entry, _Digits);
   req.sl = NormalizeDouble(sl, _Digits);
   req.tp = NormalizeDouble(tp2, _Digits);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = MathMax(1, strategy_limit_valid_bars) * PeriodSeconds(strategy_signal_tf);

   if(req.expiration_seconds <= 0 || !Strategy_ValidateLimitGeometry(req.type, req.price, req.sl))
      return false;

   g_pending_tp1 = NormalizeDouble(tp1, _Digits);
   g_pending_side = want_long ? 1 : -1;
   return true;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   Strategy_EnsureDay(TimeCurrent());

   ulong ticket;
   ENUM_POSITION_TYPE pos_type;
   double volume;
   double open_price;
   double sl;
   if(Strategy_SelectOurPosition(ticket, pos_type, volume, open_price, sl) || Strategy_HasOurPendingOrder())
      return false;

   if(!Strategy_SpreadAllows())
      return true;

   return !Strategy_InHourWindow(TimeCurrent(), strategy_session_start_h, strategy_session_end_h);
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);

   const int need = MathMax(strategy_pool_lookback_m15 + 16, 128);
   MqlRates rates[];
   if(!Strategy_LoadSignalBars(rates, need))
      return false;

   const MqlRates bar = rates[0];
   Strategy_EnsureDay(bar.time);

   ulong ticket;
   ENUM_POSITION_TYPE pos_type;
   double volume;
   double open_price;
   double sl;
   if(Strategy_SelectOurPosition(ticket, pos_type, volume, open_price, sl) || Strategy_HasOurPendingOrder())
     {
      g_order_or_trade_today = true;
      return false;
     }
   if(g_order_or_trade_today)
      return false;
   if(!Strategy_InHourWindow(bar.time, strategy_session_start_h, strategy_session_end_h))
      return false;

   double prev_low = 0.0;
   double prev_high = 0.0;
   if(!Strategy_LoadPrevDay(prev_low, prev_high))
      return false;

   double asia_low = 0.0;
   double asia_high = 0.0;
   Strategy_FindAsiaRange(g_day_key, asia_low, asia_high);

   double pivot_pool_low = 0.0;
   double pivot_pool_high = 0.0;
   Strategy_FindPivotPools(rates, bar.close, pivot_pool_low, pivot_pool_high);

   if(!g_long_setup.active &&
      Strategy_SweptAnyLongPool(bar, prev_low, asia_low, pivot_pool_low))
     {
      double mss_level = 0.0;
      if(Strategy_FindRecentPivotHigh(rates, mss_level) && mss_level > bar.close)
        {
         g_long_setup.active = true;
         g_long_setup.sweep_time = bar.time;
         g_long_setup.bars_since_sweep = 0;
         g_long_setup.sweep_extreme = bar.low;
         g_long_setup.mss_level = mss_level;
        }
     }

   if(!g_short_setup.active &&
      Strategy_SweptAnyShortPool(bar, prev_high, asia_high, pivot_pool_high))
     {
      double mss_level = 0.0;
      if(Strategy_FindRecentPivotLow(rates, mss_level) && mss_level < bar.close)
        {
         g_short_setup.active = true;
         g_short_setup.sweep_time = bar.time;
         g_short_setup.bars_since_sweep = 0;
         g_short_setup.sweep_extreme = bar.high;
         g_short_setup.mss_level = mss_level;
        }
     }

   if(g_long_setup.active)
     {
      g_long_setup.bars_since_sweep++;
      if(g_long_setup.bars_since_sweep > strategy_mss_max_bars)
         Strategy_ResetSetup(g_long_setup);
      else if(bar.close > g_long_setup.mss_level &&
              Strategy_BuildOteRequest(true, bar, g_long_setup, req))
        {
         g_order_or_trade_today = true;
         Strategy_ResetSetup(g_long_setup);
         Strategy_ResetSetup(g_short_setup);
         return true;
        }
     }

   if(g_short_setup.active)
     {
      g_short_setup.bars_since_sweep++;
      if(g_short_setup.bars_since_sweep > strategy_mss_max_bars)
         Strategy_ResetSetup(g_short_setup);
      else if(bar.close < g_short_setup.mss_level &&
              Strategy_BuildOteRequest(false, bar, g_short_setup, req))
        {
         g_order_or_trade_today = true;
         Strategy_ResetSetup(g_long_setup);
         Strategy_ResetSetup(g_short_setup);
         return true;
        }
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE pos_type;
   double volume;
   double open_price;
   double sl;
   if(!Strategy_SelectOurPosition(ticket, pos_type, volume, open_price, sl))
     {
      g_active_ticket = 0;
      g_active_tp1 = 0.0;
      g_active_partial_done = false;
      return;
     }

   g_order_or_trade_today = true;
   if(g_active_ticket != ticket)
     {
      g_active_ticket = ticket;
      g_active_tp1 = g_pending_tp1;
      g_active_partial_done = false;
     }

   if(g_active_partial_done || g_active_tp1 <= 0.0 || volume <= 0.0)
      return;

   const bool is_buy = (pos_type == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market <= 0.0)
      return;

   if((is_buy && market >= g_active_tp1) || (!is_buy && market <= g_active_tp1))
     {
      const double close_lots = volume * MathMax(0.0, MathMin(1.0, strategy_partial_fraction));
      if(QM_TM_PartialClose(ticket, close_lots, QM_EXIT_PARTIAL))
         g_active_partial_done = true;
     }
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(Strategy_Hour(TimeCurrent()) < strategy_time_exit_h)
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE pos_type;
   double volume;
   double open_price;
   double sl;
   return Strategy_SelectOurPosition(ticket, pos_type, volume, open_price, sl);
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   Strategy_ResetSetup(g_long_setup);
   Strategy_ResetSetup(g_short_setup);

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12537\",\"strategy\":\"ict_ote_displacement_xau\"}");
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

   if(!QM_IsNewBar(_Symbol, strategy_signal_tf))
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
