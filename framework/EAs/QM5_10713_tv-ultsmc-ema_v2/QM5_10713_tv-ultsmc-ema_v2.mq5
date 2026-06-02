#property strict
#property version   "5.0"
#property description "QM5_10713 TradingView Ultimate SMC EMAs Day Trading Strategy v2"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10713;
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
input int    strategy_sma_period             = 200;
input int    strategy_ema_fast_period        = 9;
input int    strategy_ema_slow_period        = 21;
input int    strategy_h4_fractal_width       = 2;
input int    strategy_h4_scan_bars           = 240;
input int    strategy_atr_period             = 14;
input double strategy_atr_floor_mult         = 1.0;
input double strategy_min_target_stop_ratio  = 1.2;

struct StrategyH4Context
  {
   bool   valid;
   double swing_high;
   double swing_low;
   bool   demand_valid;
   double demand_low;
   double demand_high;
   bool   supply_valid;
   double supply_low;
   double supply_high;
  };

bool Strategy_IsPivotHigh(MqlRates &rates[], const int index, const int width, const int copied)
  {
   if(index < width || index + width >= copied)
      return false;

   const double value = rates[index].high;
   for(int offset = 1; offset <= width; ++offset)
     {
      if(rates[index - offset].high >= value)
         return false;
      if(rates[index + offset].high >= value)
         return false;
     }
   return true;
  }

bool Strategy_IsPivotLow(MqlRates &rates[], const int index, const int width, const int copied)
  {
   if(index < width || index + width >= copied)
      return false;

   const double value = rates[index].low;
   for(int offset = 1; offset <= width; ++offset)
     {
      if(rates[index - offset].low <= value)
         return false;
      if(rates[index + offset].low <= value)
         return false;
     }
   return true;
  }

bool Strategy_LoadH4Context(StrategyH4Context &ctx, MqlRates &h4[], int &copied)
  {
   ctx.valid = false;
   ctx.swing_high = 0.0;
   ctx.swing_low = 0.0;
   ctx.demand_valid = false;
   ctx.demand_low = 0.0;
   ctx.demand_high = 0.0;
   ctx.supply_valid = false;
   ctx.supply_low = 0.0;
   ctx.supply_high = 0.0;
   copied = 0;

   const int width = MathMax(1, strategy_h4_fractal_width);
   const int scan_bars = MathMax(width * 4 + 20, strategy_h4_scan_bars);
   ArraySetAsSeries(h4, true);
   copied = CopyRates(_Symbol, PERIOD_H4, 1, scan_bars, h4); // perf-allowed: bounded H4 structural scan, called only inside Strategy_EntrySignal after the framework QM_IsNewBar gate.
   if(copied <= width * 2 + 4)
      return false;

   for(int i = width; i < copied - width; ++i)
     {
      if(ctx.swing_high <= 0.0 && Strategy_IsPivotHigh(h4, i, width, copied))
         ctx.swing_high = h4[i].high;
      if(ctx.swing_low <= 0.0 && Strategy_IsPivotLow(h4, i, width, copied))
         ctx.swing_low = h4[i].low;
      if(ctx.swing_high > 0.0 && ctx.swing_low > 0.0)
         break;
     }

   for(int i = 1; i < copied - 1; ++i)
     {
      if(!ctx.demand_valid &&
         h4[i].close < h4[i].open &&
         h4[i - 1].close > h4[i].high)
        {
         ctx.demand_valid = true;
         ctx.demand_low = h4[i].low;
         ctx.demand_high = h4[i].high;
        }

      if(!ctx.supply_valid &&
         h4[i].close > h4[i].open &&
         h4[i - 1].close < h4[i].low)
        {
         ctx.supply_valid = true;
         ctx.supply_low = h4[i].low;
         ctx.supply_high = h4[i].high;
        }

      if(ctx.demand_valid && ctx.supply_valid)
         break;
     }

   ctx.valid = (ctx.swing_high > 0.0 && ctx.swing_low > 0.0 && ctx.swing_high > ctx.swing_low);
   return ctx.valid;
  }

double Strategy_NearestPivotHighAbove(MqlRates &h4[], const int copied, const int width, const double price)
  {
   double nearest = 0.0;
   for(int i = width; i < copied - width; ++i)
     {
      if(!Strategy_IsPivotHigh(h4, i, width, copied))
         continue;
      const double level = h4[i].high;
      if(level <= price)
         continue;
      if(nearest <= 0.0 || level < nearest)
         nearest = level;
     }
   return nearest;
  }

double Strategy_NearestPivotLowBelow(MqlRates &h4[], const int copied, const int width, const double price)
  {
   double nearest = 0.0;
   for(int i = width; i < copied - width; ++i)
     {
      if(!Strategy_IsPivotLow(h4, i, width, copied))
         continue;
      const double level = h4[i].low;
      if(level >= price)
         continue;
      if(nearest <= 0.0 || level > nearest)
         nearest = level;
     }
   return nearest;
  }

bool Strategy_RangeTouchesZone(const double bar_low,
                               const double bar_high,
                               const bool zone_valid,
                               const double zone_low,
                               const double zone_high)
  {
   if(!zone_valid || zone_low <= 0.0 || zone_high <= zone_low)
      return false;
   return (bar_low <= zone_high && bar_high >= zone_low);
  }

bool Strategy_NoTradeFilter()
  {
   return (_Period != PERIOD_M5 && _Period != PERIOD_M15);
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

   MqlRates exec[];
   ArraySetAsSeries(exec, true);
   const int exec_copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 4, exec); // perf-allowed: four closed execution bars, called only after the framework QM_IsNewBar gate.
   if(exec_copied < 4)
      return false;

   StrategyH4Context h4ctx;
   MqlRates h4[];
   int h4_copied = 0;
   if(!Strategy_LoadH4Context(h4ctx, h4, h4_copied))
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double close1 = exec[0].close;
   const double close2 = exec[1].close;
   const double ema_fast1 = QM_EMA(_Symbol, tf, strategy_ema_fast_period, 1);
   const double ema_slow1 = QM_EMA(_Symbol, tf, strategy_ema_slow_period, 1);
   const double ema_fast2 = QM_EMA(_Symbol, tf, strategy_ema_fast_period, 2);
   const double sma1 = QM_SMA(_Symbol, tf, strategy_sma_period, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(close1 <= 0.0 || close2 <= 0.0 || ema_fast1 <= 0.0 || ema_slow1 <= 0.0 ||
      ema_fast2 <= 0.0 || sma1 <= 0.0 || atr <= 0.0)
      return false;

   const double swing_range = h4ctx.swing_high - h4ctx.swing_low;
   if(swing_range <= 0.0)
      return false;
   const double fib_0618 = h4ctx.swing_low + swing_range * 0.618;

   const bool bullish_fvg = (exec[0].low > exec[2].high);
   const bool bearish_fvg = (exec[0].high < exec[2].low);
   const double bullish_fvg_mid = (exec[0].low + exec[2].high) * 0.5;
   const double bearish_fvg_mid = (exec[0].high + exec[2].low) * 0.5;

   const bool demand_touch = Strategy_RangeTouchesZone(exec[0].low, exec[0].high,
                                                       h4ctx.demand_valid,
                                                       h4ctx.demand_low,
                                                       h4ctx.demand_high);
   const bool supply_touch = Strategy_RangeTouchesZone(exec[0].low, exec[0].high,
                                                       h4ctx.supply_valid,
                                                       h4ctx.supply_low,
                                                       h4ctx.supply_high);

   const bool long_trend = (close1 > sma1 && ema_fast1 > ema_slow1);
   const bool short_trend = (close1 < sma1 && ema_fast1 < ema_slow1);
   const bool long_value = (close1 < fib_0618 || demand_touch);
   const bool short_value = (close1 > fib_0618 || supply_touch);
   const bool long_trigger = ((bullish_fvg && bullish_fvg_mid <= fib_0618) ||
                              (close1 > ema_fast1 && close2 <= ema_fast2));
   const bool short_trigger = ((bearish_fvg && bearish_fvg_mid >= fib_0618) ||
                               (close1 < ema_fast1 && close2 >= ema_fast2));

   const int width = MathMax(1, strategy_h4_fractal_width);
   const double min_stop_distance = atr * MathMax(0.1, strategy_atr_floor_mult);

   if(long_trend && long_value && long_trigger)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      double sl = Strategy_NearestPivotLowBelow(h4, h4_copied, width, entry);
      const double tp = Strategy_NearestPivotHighAbove(h4, h4_copied, width, entry);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      if(entry - sl < min_stop_distance)
         sl = entry - min_stop_distance;

      const double stop_dist = MathAbs(entry - sl);
      const double target_dist = MathAbs(tp - entry);
      if(stop_dist <= 0.0 || target_dist < stop_dist * strategy_min_target_stop_ratio)
         return false;

      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = "ULTSMC_EMA_LONG";
      return true;
     }

   if(short_trend && short_value && short_trigger)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      double sl = Strategy_NearestPivotHighAbove(h4, h4_copied, width, entry);
      const double tp = Strategy_NearestPivotLowBelow(h4, h4_copied, width, entry);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      if(sl - entry < min_stop_distance)
         sl = entry + min_stop_distance;

      const double stop_dist = MathAbs(sl - entry);
      const double target_dist = MathAbs(entry - tp);
      if(stop_dist <= 0.0 || target_dist < stop_dist * strategy_min_target_stop_ratio)
         return false;

      req.type = QM_SELL;
      req.sl = sl;
      req.tp = tp;
      req.reason = "ULTSMC_EMA_SHORT";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies static H4 SL/TP with no trailing, break-even, partial close, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   bool have_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      have_position = true;
      break;
     }

   if(!have_position)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double ema_fast = QM_EMA(_Symbol, tf, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, tf, strategy_ema_slow_period, 1);
   const double sma = QM_SMA(_Symbol, tf, strategy_sma_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0 || sma <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return (bid > 0.0 && bid < sma && ema_fast < ema_slow);
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return (ask > 0.0 && ask > sma && ema_fast > ema_slow);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10713_tv-ultsmc-ema\"}");
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
