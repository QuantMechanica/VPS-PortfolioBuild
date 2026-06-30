#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA: ForexFactory WMD BOP Hook H1"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9905;
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
input int    strategy_scan_bars              = 160;
input int    strategy_fractal_left_right     = 3;
input int    strategy_atr_period             = 14;
input double strategy_touch_atr_mult         = 0.35;
input double strategy_break_atr_mult         = 0.25;
input double strategy_retest_atr_mult        = 0.25;
input int    strategy_retest_window_bars     = 10;
input double strategy_min_retest_range_atr   = 0.60;
input double strategy_hook_close_fraction    = 0.35;
input double strategy_stop_buffer_atr_mult   = 0.25;
input double strategy_min_stop_atr_mult      = 0.50;
input double strategy_max_stop_atr_mult      = 2.40;
input double strategy_min_next_level_rr      = 2.00;
input double strategy_take_profit_rr         = 2.50;
input int    strategy_time_stop_bars         = 18;
input int    strategy_entry_start_hour       = 9;
input int    strategy_entry_end_hour         = 20;
input int    strategy_friday_last_hour       = 18;
input double strategy_max_spread_atr_fraction = 0.15;

double   g_last_entry_level     = 0.0;
int      g_last_entry_direction = 0;
datetime g_last_entry_time      = 0;

bool Strategy_ReadRates(MqlRates &rates[], const int count)
  {
   if(count <= 0)
      return false;

   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, count, rates); // perf-allowed: bounded closed-bar structural scan; EntrySignal is called only after the framework QM_IsNewBar gate.
   if(copied < count)
      return false;
   ArraySetAsSeries(rates, true);
   return true;
  }

bool Strategy_IsTradingHour()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   if(tm.day_of_week == 0 || tm.day_of_week == 6)
      return false;
   if(tm.day_of_week == 5 && tm.hour >= strategy_friday_last_hour)
      return false;
   return (tm.hour >= strategy_entry_start_hour && tm.hour < strategy_entry_end_hour);
  }

bool Strategy_SpreadOk(const double atr)
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;
   if(ask > bid && atr > 0.0 && (ask - bid) > strategy_max_spread_atr_fraction * atr)
      return false;
   return true;
  }

bool Strategy_IsSwingHigh(const MqlRates &rates[], const int idx, const int total)
  {
   if(idx < strategy_fractal_left_right || idx + strategy_fractal_left_right >= total)
      return false;
   const double price = rates[idx].high;
   for(int j = 1; j <= strategy_fractal_left_right; ++j)
     {
      if(rates[idx - j].high >= price || rates[idx + j].high > price)
         return false;
     }
   return true;
  }

bool Strategy_IsSwingLow(const MqlRates &rates[], const int idx, const int total)
  {
   if(idx < strategy_fractal_left_right || idx + strategy_fractal_left_right >= total)
      return false;
   const double price = rates[idx].low;
   for(int j = 1; j <= strategy_fractal_left_right; ++j)
     {
      if(rates[idx - j].low <= price || rates[idx + j].low < price)
         return false;
     }
   return true;
  }

void Strategy_AddLevel(const double price,
                       const int kind,
                       const double tolerance,
                       double &level_price[],
                       int &level_kind[],
                       int &level_touches[],
                       int &level_count)
  {
   if(price <= 0.0 || tolerance <= 0.0)
      return;

   for(int i = 0; i < level_count; ++i)
     {
      if(level_kind[i] != kind)
         continue;
      if(MathAbs(level_price[i] - price) <= tolerance)
        {
         const double touches = (double)level_touches[i];
         level_price[i] = (level_price[i] * touches + price) / (touches + 1.0);
         level_touches[i]++;
         return;
        }
     }

   if(level_count >= 96)
      return;
   level_price[level_count] = price;
   level_kind[level_count] = kind;
   level_touches[level_count] = 1;
   level_count++;
  }

int Strategy_BuildLevels(const MqlRates &rates[],
                         const int total,
                         const double atr,
                         double &level_price[],
                         int &level_kind[],
                         int &level_touches[])
  {
   int level_count = 0;
   const int scan = MathMin(strategy_scan_bars, total - strategy_fractal_left_right - 1);
   const double tolerance = strategy_touch_atr_mult * atr;

   for(int idx = strategy_fractal_left_right; idx < scan; ++idx)
     {
      if(Strategy_IsSwingHigh(rates, idx, total))
         Strategy_AddLevel(rates[idx].high, 1, tolerance, level_price, level_kind, level_touches, level_count);
      if(Strategy_IsSwingLow(rates, idx, total))
         Strategy_AddLevel(rates[idx].low, -1, tolerance, level_price, level_kind, level_touches, level_count);
     }

   return level_count;
  }

bool Strategy_HasBreakout(const MqlRates &rates[],
                          const int direction,
                          const double level,
                          const double atr)
  {
   const int window = MathMax(1, strategy_retest_window_bars);
   const double break_distance = strategy_break_atr_mult * atr;
   for(int i = 1; i <= window; ++i)
     {
      if(direction > 0 && rates[i].close > level + break_distance)
         return true;
      if(direction < 0 && rates[i].close < level - break_distance)
         return true;
     }
   return false;
  }

double Strategy_NextOpposingLevel(const int direction,
                                  const double entry,
                                  const double &level_price[],
                                  const int &level_kind[],
                                  const int &level_touches[],
                                  const int level_count)
  {
   double best = 0.0;
   for(int i = 0; i < level_count; ++i)
     {
      if(level_touches[i] < 2)
         continue;
      if(direction > 0 && level_kind[i] == 1 && level_price[i] > entry)
        {
         if(best <= 0.0 || level_price[i] < best)
            best = level_price[i];
        }
      if(direction < 0 && level_kind[i] == -1 && level_price[i] < entry)
        {
         if(best <= 0.0 || level_price[i] > best)
            best = level_price[i];
        }
     }
   return best;
  }

bool Strategy_BuildRequest(const int direction,
                           const double level,
                           const double atr,
                           const double next_level,
                           QM_EntryRequest &req)
  {
   const QM_OrderType side = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const double buffer = strategy_stop_buffer_atr_mult * atr;
   const double retest_low = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);   // perf-allowed: one closed retest-bar bound for structural stop placement.
   const double retest_high = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: one closed retest-bar bound for structural stop placement.
   double sl = 0.0;
   if(direction > 0)
      sl = QM_StopRulesNormalizePrice(_Symbol, retest_low - buffer);
   else
      sl = QM_StopRulesNormalizePrice(_Symbol, retest_high + buffer);
   if(sl <= 0.0)
      return false;

   const double risk = MathAbs(entry - sl);
   if(risk < strategy_min_stop_atr_mult * atr || risk > strategy_max_stop_atr_mult * atr)
      return false;

   if(next_level > 0.0)
     {
      const double room = (direction > 0) ? (next_level - entry) : (entry - next_level);
      if(room < strategy_min_next_level_rr * risk)
         return false;
     }

   const double rr_tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_take_profit_rr);
   double tp = rr_tp;
   if(next_level > 0.0)
     {
      if(direction > 0)
         tp = MathMin(rr_tp, next_level);
      else
         tp = MathMax(rr_tp, next_level);
     }
   tp = QM_StopRulesNormalizePrice(_Symbol, tp);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = StringFormat("wmd_bop_hook_%s_%.5f", (direction > 0) ? "long" : "short", level);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_last_entry_level = level;
   g_last_entry_direction = direction;
   g_last_entry_time = TimeCurrent();
   return true;
  }

bool Strategy_CheckRetest(const MqlRates &bar,
                          const int direction,
                          const double level,
                          const double atr)
  {
   const double range = bar.high - bar.low;
   if(range < strategy_min_retest_range_atr * atr)
      return false;

   const double retest_distance = strategy_retest_atr_mult * atr;
   if(direction > 0)
     {
      if(bar.low > level + retest_distance || bar.close <= level)
         return false;
      return (bar.close >= bar.low + range * (1.0 - strategy_hook_close_fraction));
     }

   if(bar.high < level - retest_distance || bar.close >= level)
      return false;
   return (bar.close <= bar.low + range * strategy_hook_close_fraction);
  }

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_H1)
      return false;
   if(strategy_scan_bars < 40 || strategy_fractal_left_right < 1)
      return false;
   if(!Strategy_IsTradingHour())
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0 || !Strategy_SpreadOk(atr))
      return false;

   const int need_bars = MathMax(strategy_scan_bars + strategy_fractal_left_right + 2,
                                 strategy_retest_window_bars + 4);
   MqlRates rates[];
   if(!Strategy_ReadRates(rates, need_bars))
      return false;

   double level_price[96];
   int level_kind[96];
   int level_touches[96];
   ArrayInitialize(level_price, 0.0);
   ArrayInitialize(level_kind, 0);
   ArrayInitialize(level_touches, 0);
   const int level_count = Strategy_BuildLevels(rates, need_bars, atr, level_price, level_kind, level_touches);
   if(level_count <= 0)
      return false;

   for(int i = 0; i < level_count; ++i)
     {
      if(level_touches[i] < 2)
         continue;

      const int direction = (level_kind[i] == 1) ? 1 : -1;
      const double level = level_price[i];
      if(!Strategy_HasBreakout(rates, direction, level, atr))
         continue;
      if(!Strategy_CheckRetest(rates[0], direction, level, atr))
         continue;

      const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                           : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double next_level = Strategy_NextOpposingLevel(direction, entry, level_price, level_kind, level_touches, level_count);
      if(Strategy_BuildRequest(direction, level, atr, next_level, req))
         return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const int total = PositionsTotal();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const datetime entry_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int seconds_per_bar = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
      if(seconds_per_bar > 0 && TimeCurrent() - entry_time >= strategy_time_stop_bars * seconds_per_bar)
         return true;

      if(g_last_entry_level > 0.0 && g_last_entry_direction != 0)
        {
         const double close1 = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: single closed-bar close-through-level exit.
         if(g_last_entry_direction > 0 && close1 > 0.0 && close1 < g_last_entry_level)
            return true;
         if(g_last_entry_direction < 0 && close1 > 0.0 && close1 > g_last_entry_level)
            return true;
        }
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
