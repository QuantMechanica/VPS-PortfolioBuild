#property strict
#property version   "5.0"
#property description "QM5_9259 MQL5 validated structure pullback"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9259;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal        = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_swing_lookback      = 5;
input double strategy_displacement_factor = 1.5;
input int    strategy_structure_hold_bars = 3;
input int    strategy_atr_period          = 14;
input double strategy_atr_buffer_mult     = 0.25;
input double strategy_risk_reward_ratio   = 2.0;
input int    strategy_scan_bars           = 100;
input int    strategy_avg_candle_bars     = 50;
input int    strategy_equal_zone_points   = 10;
input int    strategy_min_bars_between_trades = 3;

enum StrategyMarketState
  {
   STRAT_ACCUMULATION = 0,
   STRAT_EXPANSION    = 1,
   STRAT_DISTRIBUTION = 2,
   STRAT_REVERSAL     = 3
  };

struct StrategySwing
  {
   datetime time;
   double   price;
   bool     is_high;
   bool     is_valid;
   bool     is_used;
   int      bar_index;
   double   candle_points;
   bool     displacement;
   bool     liquidity_sweep;
   bool     break_structure;
   bool     time_respect;
  };

struct StrategyLiquidityZone
  {
   datetime time;
   double   price;
   bool     is_high;
   bool     taken;
   int      bar_index;
  };

bool g_cached_exit_long = false;
bool g_cached_exit_short = false;
int  g_entry_cooldown_remaining = 0;

void ResetSwing(StrategySwing &swing_item)
  {
   swing_item.time = 0;
   swing_item.price = 0.0;
   swing_item.is_high = true;
   swing_item.is_valid = false;
   swing_item.is_used = false;
   swing_item.bar_index = -1;
   swing_item.candle_points = 0.0;
   swing_item.displacement = false;
   swing_item.liquidity_sweep = false;
   swing_item.break_structure = false;
   swing_item.time_respect = false;
  }

void AddSwing(StrategySwing &swings[], StrategySwing &swing_item)
  {
   const int n = ArraySize(swings);
   ArrayResize(swings, n + 1);
   swings[n] = swing_item;
  }

void AddZone(StrategyLiquidityZone &zones[], StrategyLiquidityZone &zone_item)
  {
   const int n = ArraySize(zones);
   ArrayResize(zones, n + 1);
   zones[n] = zone_item;
  }

double AvgCandlePoints(MqlRates &rates[], const int copied)
  {
   const int max_bars = MathMin(copied - 1, strategy_avg_candle_bars);
   if(max_bars <= 0)
      return 0.0;

   double sum = 0.0;
   int samples = 0;
   for(int i = 1; i <= max_bars; ++i)
     {
      const double range_points = (rates[i].high - rates[i].low) / _Point;
      if(range_points > 0.0)
        {
         sum += range_points;
         samples++;
        }
     }

   if(samples <= 0)
      return 0.0;
   return sum / samples;
  }

double FindPreviousHigh(StrategySwing &valid_swings[], const int before_index)
  {
   double previous = 0.0;
   for(int i = 0; i < before_index; ++i)
     {
      if(valid_swings[i].is_high)
         previous = valid_swings[i].price;
     }
   return previous;
  }

double FindPreviousLow(StrategySwing &valid_swings[], const int before_index)
  {
   double previous = 0.0;
   for(int i = 0; i < before_index; ++i)
     {
      if(!valid_swings[i].is_high)
         previous = valid_swings[i].price;
     }
   return previous;
  }

bool CheckTimeRespect(MqlRates &rates[], const int bar_index, const bool is_high, const double price)
  {
   if(bar_index - strategy_structure_hold_bars < 1)
      return false;

   for(int i = 1; i <= strategy_structure_hold_bars; ++i)
     {
      const int newer = bar_index - i;
      if(is_high && rates[newer].high > price)
         return false;
      if(!is_high && rates[newer].low < price)
         return false;
     }
   return true;
  }

bool CheckLiquiditySweepAtBar(MqlRates &rates[],
                              const int bar_index,
                              const bool is_high,
                              StrategySwing &valid_swings[])
  {
   for(int i = 0; i < ArraySize(valid_swings); ++i)
     {
      if(valid_swings[i].is_high != is_high)
         continue;

      const double level = valid_swings[i].price;
      if(is_high && rates[bar_index].high > level && rates[bar_index].close < level)
         return true;
      if(!is_high && rates[bar_index].low < level && rates[bar_index].close > level)
         return true;
     }
   return false;
  }

void DetectValidatedSwings(MqlRates &rates[],
                           const int copied,
                           const double avg_points,
                           StrategySwing &valid_swings[])
  {
   ArrayResize(valid_swings, 0);
   const int min_index = strategy_swing_lookback + 1;
   const int max_index = copied - strategy_swing_lookback - 1;
   if(min_index > max_index)
      return;

   for(int i = max_index; i >= min_index; --i)
     {
      bool swing_high = true;
      bool swing_low = true;
      for(int j = 1; j <= strategy_swing_lookback; ++j)
        {
         if(rates[i].high <= rates[i - j].high || rates[i].high <= rates[i + j].high)
            swing_high = false;
         if(rates[i].low >= rates[i - j].low || rates[i].low >= rates[i + j].low)
            swing_low = false;
        }

      if(!swing_high && !swing_low)
         continue;

      StrategySwing swing_item;
      ResetSwing(swing_item);
      swing_item.time = rates[i].time;
      swing_item.bar_index = i;
      swing_item.candle_points = (rates[i].high - rates[i].low) / _Point;

      if(swing_high)
        {
         swing_item.is_high = true;
         swing_item.price = rates[i].high;
         const double previous_high = FindPreviousHigh(valid_swings, ArraySize(valid_swings));
         swing_item.break_structure = (previous_high > 0.0 && rates[i].close > previous_high);
        }
      else
        {
         swing_item.is_high = false;
         swing_item.price = rates[i].low;
         const double previous_low = FindPreviousLow(valid_swings, ArraySize(valid_swings));
         swing_item.break_structure = (previous_low > 0.0 && rates[i].close < previous_low);
        }

      swing_item.displacement = (avg_points > 0.0 &&
                                 swing_item.candle_points > avg_points * strategy_displacement_factor);
      swing_item.liquidity_sweep = CheckLiquiditySweepAtBar(rates, i, swing_item.is_high, valid_swings);
      swing_item.time_respect = CheckTimeRespect(rates, i, swing_item.is_high, swing_item.price);
      swing_item.is_valid = (swing_item.break_structure ||
                             swing_item.displacement ||
                             swing_item.liquidity_sweep ||
                             swing_item.time_respect);

      if(swing_item.is_valid)
         AddSwing(valid_swings, swing_item);
     }
  }

bool ZoneTakenAfter(MqlRates &rates[], const int zone_bar_index, const bool is_high, const double price)
  {
   for(int i = zone_bar_index - 1; i >= 1; --i)
     {
      if(is_high && rates[i].high > price)
         return true;
      if(!is_high && rates[i].low < price)
         return true;
     }
   return false;
  }

void BuildLiquidityZones(MqlRates &rates[],
                         StrategySwing &valid_swings[],
                         StrategyLiquidityZone &zones[])
  {
   ArrayResize(zones, 0);
   const double tolerance = strategy_equal_zone_points * _Point;

   for(int i = 0; i < ArraySize(valid_swings); ++i)
     {
      for(int j = i + 1; j < ArraySize(valid_swings); ++j)
        {
         if(valid_swings[i].is_high != valid_swings[j].is_high)
            continue;
         if(MathAbs(valid_swings[i].price - valid_swings[j].price) > tolerance)
            continue;

         StrategyLiquidityZone equal_zone;
         equal_zone.time = valid_swings[j].time;
         equal_zone.price = valid_swings[j].price;
         equal_zone.is_high = valid_swings[j].is_high;
         equal_zone.bar_index = valid_swings[j].bar_index;
         equal_zone.taken = ZoneTakenAfter(rates, equal_zone.bar_index, equal_zone.is_high, equal_zone.price);
         AddZone(zones, equal_zone);
         break;
        }
     }

   for(int i = 0; i < ArraySize(valid_swings); ++i)
     {
      StrategyLiquidityZone untouched_zone;
      untouched_zone.time = valid_swings[i].time;
      untouched_zone.price = valid_swings[i].price;
      untouched_zone.is_high = valid_swings[i].is_high;
      untouched_zone.bar_index = valid_swings[i].bar_index;
      untouched_zone.taken = ZoneTakenAfter(rates, untouched_zone.bar_index, untouched_zone.is_high, untouched_zone.price);
      AddZone(zones, untouched_zone);
     }
  }

bool RecentLowHighPair(StrategySwing &valid_swings[],
                       double &recent_low,
                       double &previous_low,
                       double &recent_high,
                       double &previous_high)
  {
   recent_low = 0.0;
   previous_low = 0.0;
   recent_high = 0.0;
   previous_high = 0.0;

   for(int i = ArraySize(valid_swings) - 1; i >= 0; --i)
     {
      if(valid_swings[i].is_high)
        {
         if(recent_high == 0.0)
            recent_high = valid_swings[i].price;
         else if(previous_high == 0.0)
            previous_high = valid_swings[i].price;
        }
      else
        {
         if(recent_low == 0.0)
            recent_low = valid_swings[i].price;
         else if(previous_low == 0.0)
            previous_low = valid_swings[i].price;
        }
     }

   return (recent_low > 0.0 && previous_low > 0.0 && recent_high > 0.0 && previous_high > 0.0);
  }

bool SweptActiveZone(MqlRates &rates[], StrategyLiquidityZone &zones[], const bool high_zone)
  {
   for(int i = 0; i < ArraySize(zones); ++i)
     {
      if(zones[i].is_high != high_zone || zones[i].taken)
         continue;
      if(high_zone && rates[1].high > zones[i].price && rates[1].close < zones[i].price)
         return true;
      if(!high_zone && rates[1].low < zones[i].price && rates[1].close > zones[i].price)
         return true;
     }
   return false;
  }

StrategyMarketState ResolveMarketState(MqlRates &rates[],
                                       StrategySwing &valid_swings[],
                                       StrategyLiquidityZone &zones[])
  {
   double recent_low;
   double previous_low;
   double recent_high;
   double previous_high;
   if(!RecentLowHighPair(valid_swings, recent_low, previous_low, recent_high, previous_high))
      return STRAT_ACCUMULATION;

   const bool bullish = (recent_low > previous_low && recent_high > previous_high);
   const bool bearish = (recent_low < previous_low && recent_high < previous_high);
   const bool sweep_failure = (SweptActiveZone(rates, zones, true) || SweptActiveZone(rates, zones, false));

   if(sweep_failure)
      return STRAT_REVERSAL;
   if(bullish)
      return STRAT_EXPANSION;
   if(bearish)
      return STRAT_DISTRIBUTION;
   return STRAT_ACCUMULATION;
  }

bool LatestSwing(StrategySwing &valid_swings[], StrategySwing &out_swing)
  {
   if(ArraySize(valid_swings) <= 0)
      return false;
   out_swing = valid_swings[ArraySize(valid_swings) - 1];
   return true;
  }

bool IsHigherLow(StrategySwing &valid_swings[], const StrategySwing &latest)
  {
   if(latest.is_high)
      return false;
   for(int i = ArraySize(valid_swings) - 2; i >= 0; --i)
     {
      if(!valid_swings[i].is_high)
         return (latest.price > valid_swings[i].price);
     }
   return false;
  }

bool IsLowerHigh(StrategySwing &valid_swings[], const StrategySwing &latest)
  {
   if(!latest.is_high)
      return false;
   for(int i = ArraySize(valid_swings) - 2; i >= 0; --i)
     {
      if(valid_swings[i].is_high)
         return (latest.price < valid_swings[i].price);
     }
   return false;
  }

bool BullishDisplacement(MqlRates &rates[], const double avg_points)
  {
   if(avg_points <= 0.0)
      return false;
   const double body_points = (rates[1].close - rates[1].open) / _Point;
   return (body_points > avg_points * strategy_displacement_factor);
  }

bool BearishDisplacement(MqlRates &rates[], const double avg_points)
  {
   if(avg_points <= 0.0)
      return false;
   const double body_points = (rates[1].open - rates[1].close) / _Point;
   return (body_points > avg_points * strategy_displacement_factor);
  }

double CurrentEntryPrice(const QM_OrderType side)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(side == QM_BUY)
     {
      if(ask > 0.0)
         return ask;
      return bid;
     }
   if(bid > 0.0)
      return bid;
   return ask;
  }

double NearestStructureStop(const QM_OrderType side,
                            const double entry,
                            const double atr_value,
                            StrategySwing &valid_swings[])
  {
   double structure = 0.0;
   for(int i = ArraySize(valid_swings) - 1; i >= 0; --i)
     {
      if(side == QM_BUY && !valid_swings[i].is_high && valid_swings[i].price < entry)
        {
         if(structure == 0.0 || valid_swings[i].price > structure)
            structure = valid_swings[i].price;
        }
      if(side == QM_SELL && valid_swings[i].is_high && valid_swings[i].price > entry)
        {
         if(structure == 0.0 || valid_swings[i].price < structure)
            structure = valid_swings[i].price;
        }
     }

   if(structure <= 0.0 || atr_value <= 0.0)
      return 0.0;

   const double buffer = atr_value * strategy_atr_buffer_mult;
   if(side == QM_BUY)
      return QM_StopRulesNormalizePrice(_Symbol, structure - buffer);
   return QM_StopRulesNormalizePrice(_Symbol, structure + buffer);
  }

double OptionalLiquidityTarget(const QM_OrderType side,
                               const double entry,
                               const double rr_tp,
                               StrategySwing &valid_swings[],
                               StrategyLiquidityZone &zones[])
  {
   double target = 0.0;
   for(int i = 0; i < ArraySize(zones); ++i)
     {
      if(zones[i].taken)
         continue;
      if(side == QM_BUY && zones[i].is_high && zones[i].price > entry && zones[i].price < rr_tp)
        {
         if(target == 0.0 || zones[i].price < target)
            target = zones[i].price;
        }
      if(side == QM_SELL && !zones[i].is_high && zones[i].price < entry && zones[i].price > rr_tp)
        {
         if(target == 0.0 || zones[i].price > target)
            target = zones[i].price;
        }
     }

   for(int i = 0; i < ArraySize(valid_swings); ++i)
     {
      if(side == QM_BUY && valid_swings[i].is_high && valid_swings[i].price > entry && valid_swings[i].price < rr_tp)
        {
         if(target == 0.0 || valid_swings[i].price < target)
            target = valid_swings[i].price;
        }
      if(side == QM_SELL && !valid_swings[i].is_high && valid_swings[i].price < entry && valid_swings[i].price > rr_tp)
        {
         if(target == 0.0 || valid_swings[i].price > target)
            target = valid_swings[i].price;
        }
     }

   if(target <= 0.0)
      return rr_tp;
   return QM_StopRulesNormalizePrice(_Symbol, target);
  }

bool BuildTradeRequest(QM_EntryRequest &req,
                       const QM_OrderType side,
                       StrategySwing &valid_swings[],
                       StrategyLiquidityZone &zones[])
  {
   const double entry = CurrentEntryPrice(side);
   if(entry <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   const double sl = NearestStructureStop(side, entry, atr_value, valid_swings);
   if(sl <= 0.0)
      return false;

   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;

   const double rr_tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_risk_reward_ratio);
   if(rr_tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = OptionalLiquidityTarget(side, entry, rr_tp, valid_swings, zones);
   req.reason = (side == QM_BUY) ? "STRUCT_PULL_LONG" : "STRUCT_PULL_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

bool HasOurPositionType(ENUM_POSITION_TYPE &position_type)
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

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
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

   g_cached_exit_long = false;
   g_cached_exit_short = false;

   if(strategy_swing_lookback < 2 ||
      strategy_structure_hold_bars < 1 ||
      strategy_atr_period < 1 ||
      strategy_displacement_factor <= 0.0 ||
      strategy_risk_reward_ratio <= 0.0 ||
      strategy_scan_bars < strategy_swing_lookback * 2 + strategy_structure_hold_bars + 10)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, strategy_scan_bars, rates); // perf-allowed: Strategy_EntrySignal is called only after the framework QM_IsNewBar() gate.
   if(copied < strategy_swing_lookback * 2 + strategy_structure_hold_bars + 10)
      return false;

   const double avg_points = AvgCandlePoints(rates, copied);
   if(avg_points <= 0.0)
      return false;

   StrategySwing valid_swings[];
   DetectValidatedSwings(rates, copied, avg_points, valid_swings);
   if(ArraySize(valid_swings) < 2)
      return false;

   StrategyLiquidityZone zones[];
   BuildLiquidityZones(rates, valid_swings, zones);
   const StrategyMarketState state = ResolveMarketState(rates, valid_swings, zones);

   StrategySwing latest;
   if(!LatestSwing(valid_swings, latest))
      return false;

   const bool higher_low = IsHigherLow(valid_swings, latest);
   const bool lower_high = IsLowerHigh(valid_swings, latest);
   const bool sweep_below = SweptActiveZone(rates, zones, false);
   const bool sweep_above = SweptActiveZone(rates, zones, true);
   const bool bullish_displacement = BullishDisplacement(rates, avg_points);
   const bool bearish_displacement = BearishDisplacement(rates, avg_points);

   g_cached_exit_long = (latest.is_high && lower_high && bearish_displacement);
   g_cached_exit_short = (!latest.is_high && higher_low && bullish_displacement);

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(g_entry_cooldown_remaining > 0)
     {
      g_entry_cooldown_remaining--;
      return false;
     }

   const bool long_state = (state == STRAT_ACCUMULATION || state == STRAT_EXPANSION);
   const bool short_state = (state == STRAT_DISTRIBUTION || state == STRAT_REVERSAL);

   if(!latest.is_high && (higher_low || sweep_below || bullish_displacement) && long_state)
     {
      if(BuildTradeRequest(req, QM_BUY, valid_swings, zones))
        {
         g_entry_cooldown_remaining = strategy_min_bars_between_trades;
         return true;
        }
     }

   if(latest.is_high && (lower_high || sweep_above || bearish_displacement) && short_state)
     {
      if(BuildTradeRequest(req, QM_SELL, valid_swings, zones))
        {
         g_entry_cooldown_remaining = strategy_min_bars_between_trades;
         return true;
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(!HasOurPositionType(position_type))
      return false;

   if(position_type == POSITION_TYPE_BUY && g_cached_exit_long)
      return true;
   if(position_type == POSITION_TYPE_SELL && g_cached_exit_short)
      return true;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_9259_mql5-struct-pull\"}");
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
