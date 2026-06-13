#property strict
#property version   "5.0"
#property description "QM5_10616 MQL5 Daily Pivot Support-Resistance Bounce"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10616;
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
input int    strategy_target_variant    = 1;
input int    strategy_touch_tolerance_points = 2;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.0;
input bool   strategy_intraday_close_enabled = true;
input int    strategy_intraday_close_hour_broker = 23;
input bool   strategy_move_be_at_first_target = true;
input int    strategy_be_buffer_points  = 2;

double g_strategy_levels[7];
bool   g_strategy_levels_ready = false;

double Strategy_Point()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return (point > 0.0) ? point : 0.0;
  }

double Strategy_MinStopDistance()
  {
   const double point = Strategy_Point();
   if(point <= 0.0)
      return 0.0;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   return MathMax(0, stops_level) * point;
  }

bool Strategy_LoadPivotLevels()
  {
   MqlRates daily[];
   ArraySetAsSeries(daily, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, 1, daily); // perf-allowed: daily pivot ladder is structural and this function is called from Strategy_EntrySignal after the framework QM_IsNewBar() gate.
   if(copied != 1)
     {
      g_strategy_levels_ready = false;
      return false;
     }

   const double high = daily[0].high;
   const double low = daily[0].low;
   const double close = daily[0].close;
   if(high <= 0.0 || low <= 0.0 || close <= 0.0 || high <= low)
     {
      g_strategy_levels_ready = false;
      return false;
     }

   const double pivot = (high + low + close) / 3.0;
   const double range = high - low;
   const double r1 = 2.0 * pivot - low;
   const double s1 = 2.0 * pivot - high;
   const double r2 = pivot + range;
   const double s2 = pivot - range;
   const double r3 = high + 2.0 * (pivot - low);
   const double s3 = low - 2.0 * (high - pivot);

   g_strategy_levels[0] = s3;
   g_strategy_levels[1] = s2;
   g_strategy_levels[2] = s1;
   g_strategy_levels[3] = pivot;
   g_strategy_levels[4] = r1;
   g_strategy_levels[5] = r2;
   g_strategy_levels[6] = r3;
   g_strategy_levels_ready = true;
   return true;
  }

bool Strategy_LoadSignalBars(MqlRates &signal_bar, MqlRates &prior_bar)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 2, rates); // perf-allowed: two closed intraday bars are the source bounce condition and EntrySignal is framework new-bar gated.
   if(copied != 2)
      return false;

   signal_bar = rates[0];
   prior_bar = rates[1];
   return (signal_bar.open > 0.0 && signal_bar.high > 0.0 &&
           signal_bar.low > 0.0 && signal_bar.close > 0.0 &&
           prior_bar.open > 0.0);
  }

bool Strategy_HasOurPosition()
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

int Strategy_LevelIndexForPrice(const double price, const bool support_side)
  {
   if(!g_strategy_levels_ready || price <= 0.0)
      return -1;

   const int first = support_side ? 0 : 4;
   const int last = support_side ? 2 : 6;
   int best = -1;
   double best_dist = DBL_MAX;
   for(int i = first; i <= last; ++i)
     {
      const double dist = MathAbs(price - g_strategy_levels[i]);
      if(dist < best_dist)
        {
         best_dist = dist;
         best = i;
        }
     }
   return best;
  }

bool Strategy_LevelDistanceAllowed(const double entry, const double level)
  {
   const double min_dist = Strategy_MinStopDistance();
   if(entry <= 0.0 || level <= 0.0)
      return false;
   return (MathAbs(entry - level) >= min_dist);
  }

double Strategy_StopFromPivot(const QM_OrderType side, const int level_idx, const double entry)
  {
   if(!g_strategy_levels_ready || entry <= 0.0)
      return 0.0;

   if(side == QM_BUY)
     {
      for(int i = level_idx - 1; i >= 0; --i)
         if(g_strategy_levels[i] < entry && Strategy_LevelDistanceAllowed(entry, g_strategy_levels[i]))
            return NormalizeDouble(g_strategy_levels[i], _Digits);
     }
   else
     {
      for(int i = level_idx + 1; i < 7; ++i)
         if(g_strategy_levels[i] > entry && Strategy_LevelDistanceAllowed(entry, g_strategy_levels[i]))
            return NormalizeDouble(g_strategy_levels[i], _Digits);
     }

   return QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
  }

double Strategy_TakeFromPivot(const QM_OrderType side, const int level_idx, const double entry)
  {
   if(!g_strategy_levels_ready || entry <= 0.0)
      return 0.0;

   int steps = strategy_target_variant;
   if(steps < 1)
      steps = 1;
   if(steps > 5)
      steps = 5;

   if(side == QM_BUY)
     {
      for(int i = MathMin(6, level_idx + steps); i < 7; ++i)
         if(g_strategy_levels[i] > entry && Strategy_LevelDistanceAllowed(entry, g_strategy_levels[i]))
            return NormalizeDouble(g_strategy_levels[i], _Digits);
     }
   else
     {
      for(int i = MathMax(0, level_idx - steps); i >= 0; --i)
         if(g_strategy_levels[i] < entry && Strategy_LevelDistanceAllowed(entry, g_strategy_levels[i]))
            return NormalizeDouble(g_strategy_levels[i], _Digits);
     }

   return 0.0;
  }

double Strategy_FirstProfitLevel(const bool is_buy, const double open_price)
  {
   if(!g_strategy_levels_ready || open_price <= 0.0)
      return 0.0;

   if(is_buy)
     {
      for(int i = 0; i < 7; ++i)
         if(g_strategy_levels[i] > open_price)
            return g_strategy_levels[i];
     }
   else
     {
      for(int i = 6; i >= 0; --i)
         if(g_strategy_levels[i] < open_price)
            return g_strategy_levels[i];
     }
   return 0.0;
  }

void Strategy_ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_target_variant < 1 || strategy_target_variant > 5)
      return true;
   if(strategy_touch_tolerance_points < 0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_intraday_close_hour_broker < 0 ||
      strategy_intraday_close_hour_broker > 23 ||
      strategy_be_buffer_points < 0)
      return true;

   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread <= 0);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetRequest(req);

   if(!Strategy_LoadPivotLevels())
      return false;

   MqlRates signal_bar;
   MqlRates prior_bar;
   if(!Strategy_LoadSignalBars(signal_bar, prior_bar))
      return false;

   if(Strategy_HasOurPosition())
      return false;

   const double point = Strategy_Point();
   if(point <= 0.0)
      return false;
   const double tolerance = point * strategy_touch_tolerance_points;

   for(int i = 0; i <= 2; ++i)
     {
      const double support = g_strategy_levels[i];
      const bool crossed_support = (prior_bar.low <= support + tolerance);
      const bool closed_at_support = (MathAbs(prior_bar.close - support) <= tolerance);
      if(prior_bar.open > support && signal_bar.close > support &&
         (crossed_support || closed_at_support))
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(entry <= 0.0)
            return false;

         const double sl = Strategy_StopFromPivot(QM_BUY, i, entry);
         const double tp = Strategy_TakeFromPivot(QM_BUY, i, entry);
         if(sl <= 0.0 || tp <= 0.0 || sl >= entry || tp <= entry)
            return false;

         req.type = QM_BUY;
         req.price = 0.0;
         req.sl = sl;
         req.tp = tp;
         req.reason = "PIVOT_SUPPORT_BOUNCE_LONG";
         return true;
        }
     }

   for(int i = 4; i <= 6; ++i)
     {
      const double resistance = g_strategy_levels[i];
      const bool crossed_resistance = (prior_bar.high >= resistance - tolerance);
      const bool closed_at_resistance = (MathAbs(prior_bar.close - resistance) <= tolerance);
      if(prior_bar.open < resistance && signal_bar.close < resistance &&
         (crossed_resistance || closed_at_resistance))
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(entry <= 0.0)
            return false;

         const double sl = Strategy_StopFromPivot(QM_SELL, i, entry);
         const double tp = Strategy_TakeFromPivot(QM_SELL, i, entry);
         if(sl <= 0.0 || tp <= 0.0 || sl <= entry || tp >= entry)
            return false;

         req.type = QM_SELL;
         req.price = 0.0;
         req.sl = sl;
         req.tp = tp;
         req.reason = "PIVOT_RESISTANCE_BOUNCE_SHORT";
         return true;
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(!strategy_move_be_at_first_target || !g_strategy_levels_ready)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double point = Strategy_Point();
   if(point <= 0.0)
      return;

   const double buffer = point * strategy_be_buffer_points;
   const double spread_buffer = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * point;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (type == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double trigger = Strategy_FirstProfitLevel(is_buy, open_price);
      if(trigger <= 0.0)
         continue;

      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;

      const bool reached = is_buy ? (market >= trigger) : (market <= trigger);
      if(!reached)
         continue;

      const double target_sl = is_buy ? (open_price + spread_buffer + buffer)
                                      : (open_price - spread_buffer - buffer);
      const bool improves = (current_sl <= 0.0) ||
                            (is_buy ? (target_sl > current_sl + point * 0.5)
                                    : (target_sl < current_sl - point * 0.5));
      if(improves)
         QM_TM_MoveSL(ticket, NormalizeDouble(target_sl, _Digits), "pivot_first_target_breakeven");
     }
  }

bool Strategy_ExitSignal()
  {
   if(!strategy_intraday_close_enabled)
      return false;

   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   return (now.hour >= strategy_intraday_close_hour_broker);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

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
