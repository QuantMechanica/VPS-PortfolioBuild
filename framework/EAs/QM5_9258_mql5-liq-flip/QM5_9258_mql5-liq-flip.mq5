#property strict
#property version   "5.0"
#property description "QM5_9258 MQL5 liquidity zone flip retest"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9258;
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
input ENUM_TIMEFRAMES strategy_zone_timeframe = PERIOD_H1;
input int    strategy_zone_scan_bars      = 160;
input int    strategy_zone_expiry_bars    = 96;
input int    strategy_atr_period          = 14;
input double strategy_impulse_atr_mult    = 1.5;
input double strategy_body_atr_mult       = 0.7;
input double strategy_zone_pad_atr_mult   = 0.10;
input double strategy_retest_pad_atr_mult = 0.25;
input double strategy_stop_atr_buffer     = 0.50;
input double strategy_fallback_rr         = 2.0;
input double strategy_opposing_zone_max_rr = 3.0;
input int    strategy_max_hold_bars       = 64;
input int    strategy_max_spread_pips     = 30;

struct StrategyZone
  {
   double low;
   double high;
   int    formed_shift;
   bool   supply;
  };

double g_active_zone_low = 0.0;
double g_active_zone_high = 0.0;
bool   g_active_zone_long = false;
bool   g_have_active_zone = false;
bool   g_cached_zone_exit_long = false;
bool   g_cached_zone_exit_short = false;

double BarBody(const MqlRates &bar)
  {
   return MathAbs(bar.close - bar.open);
  }

double BarRange(const MqlRates &bar)
  {
   return MathAbs(bar.high - bar.low);
  }

double AtrProxy(MqlRates &rates[], const int copied, const int shift, const int period)
  {
   if(period <= 0 || shift + period >= copied)
      return 0.0;

   double sum = 0.0;
   int samples = 0;
   for(int i = shift + 1; i <= shift + period && i < copied; ++i)
     {
      const double range = BarRange(rates[i]);
      if(range > 0.0)
        {
         sum += range;
         samples++;
        }
     }

   if(samples <= 0)
      return 0.0;
   return sum / samples;
  }

bool IsBullishImpulse(MqlRates &rates[], const int copied, const int shift)
  {
   if(shift < 1 || shift >= copied)
      return false;

   const double atr = AtrProxy(rates, copied, shift, strategy_atr_period);
   if(atr <= 0.0)
      return false;

   return (rates[shift].close > rates[shift].open &&
           BarRange(rates[shift]) >= atr * strategy_impulse_atr_mult &&
           BarBody(rates[shift]) >= atr * strategy_body_atr_mult);
  }

bool IsBearishImpulse(MqlRates &rates[], const int copied, const int shift)
  {
   if(shift < 1 || shift >= copied)
      return false;

   const double atr = AtrProxy(rates, copied, shift, strategy_atr_period);
   if(atr <= 0.0)
      return false;

   return (rates[shift].close < rates[shift].open &&
           BarRange(rates[shift]) >= atr * strategy_impulse_atr_mult &&
           BarBody(rates[shift]) >= atr * strategy_body_atr_mult);
  }

void BuildBaseZone(MqlRates &rates[], const int base_shift, const bool supply, const double pad, StrategyZone &zone)
  {
   zone.low = MathMin(rates[base_shift].open, rates[base_shift].close) - pad;
   zone.high = MathMax(rates[base_shift].open, rates[base_shift].close) + pad;
   if(zone.high <= zone.low)
     {
      zone.low = rates[base_shift].low - pad;
      zone.high = rates[base_shift].high + pad;
     }
   zone.formed_shift = base_shift;
   zone.supply = supply;
  }

bool IsZoneRetested(const StrategyZone &zone,
                    const bool flipped_to_demand,
                    const double pad,
                    MqlRates &rates[])
  {
   if(flipped_to_demand)
      return (rates[1].low <= zone.high + pad && rates[1].close >= zone.low - pad);
   return (rates[1].high >= zone.low - pad && rates[1].close <= zone.high + pad);
  }

bool BullishEngulfing(MqlRates &rates[])
  {
   return (rates[2].close < rates[2].open &&
           rates[1].close > rates[1].open &&
           rates[1].open <= rates[2].close &&
           rates[1].close >= rates[2].open);
  }

bool BearishEngulfing(MqlRates &rates[])
  {
   return (rates[2].close > rates[2].open &&
           rates[1].close < rates[1].open &&
           rates[1].open >= rates[2].close &&
           rates[1].close <= rates[2].open);
  }

bool BullishPinBar(MqlRates &rates[])
  {
   const double body = MathMax(BarBody(rates[1]), _Point);
   const double lower_wick = MathMin(rates[1].open, rates[1].close) - rates[1].low;
   const double upper_wick = rates[1].high - MathMax(rates[1].open, rates[1].close);
   return (rates[1].close > rates[1].open && lower_wick > 2.0 * body && lower_wick > upper_wick);
  }

bool BearishPinBar(MqlRates &rates[])
  {
   const double body = MathMax(BarBody(rates[1]), _Point);
   const double upper_wick = rates[1].high - MathMax(rates[1].open, rates[1].close);
   const double lower_wick = MathMin(rates[1].open, rates[1].close) - rates[1].low;
   return (rates[1].close < rates[1].open && upper_wick > 2.0 * body && upper_wick > lower_wick);
  }

bool BullishInsideBreak(MqlRates &rates[])
  {
   const bool inside = (rates[2].high < rates[3].high && rates[2].low > rates[3].low);
   return (inside && rates[1].close > rates[3].high);
  }

bool BearishInsideBreak(MqlRates &rates[])
  {
   const bool inside = (rates[2].high < rates[3].high && rates[2].low > rates[3].low);
   return (inside && rates[1].close < rates[3].low);
  }

bool BullishReversalPattern(MqlRates &rates[])
  {
   return (BullishEngulfing(rates) || BullishPinBar(rates) || BullishInsideBreak(rates));
  }

bool BearishReversalPattern(MqlRates &rates[])
  {
   return (BearishEngulfing(rates) || BearishPinBar(rates) || BearishInsideBreak(rates));
  }

bool ZoneStillActive(MqlRates &rates[], const StrategyZone &zone, const int latest_shift)
  {
   for(int i = zone.formed_shift - 1; i >= latest_shift && i >= 1; --i)
     {
      if(zone.supply && rates[i].close > zone.high)
         return false;
      if(!zone.supply && rates[i].close < zone.low)
         return false;
     }
   return true;
  }

bool FindFlippedRetestZone(MqlRates &rates[],
                           const int copied,
                           const bool want_long,
                           StrategyZone &out_zone)
  {
   bool found = false;
   int best_age = 1000000;
   const double atr = QM_ATR(_Symbol, strategy_zone_timeframe, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double zone_pad = atr * strategy_zone_pad_atr_mult;
   const double retest_pad = atr * strategy_retest_pad_atr_mult;
   const int oldest = copied - strategy_atr_period - 3;
   for(int base_shift = oldest; base_shift >= 3; --base_shift)
     {
      const int impulse_shift = base_shift - 1;
      if(impulse_shift < 2)
         continue;

      StrategyZone zone;
      bool valid_base = false;
      if(want_long && IsBearishImpulse(rates, copied, impulse_shift))
        {
         BuildBaseZone(rates, base_shift, true, zone_pad, zone);
         valid_base = true;
        }
      if(!want_long && IsBullishImpulse(rates, copied, impulse_shift))
        {
         BuildBaseZone(rates, base_shift, false, zone_pad, zone);
         valid_base = true;
        }
      if(!valid_base)
         continue;

      for(int break_shift = impulse_shift - 1; break_shift >= 2; --break_shift)
        {
         const bool break_to_demand = (want_long &&
                                       IsBullishImpulse(rates, copied, break_shift) &&
                                       rates[break_shift].close > zone.high);
         const bool break_to_supply = (!want_long &&
                                       IsBearishImpulse(rates, copied, break_shift) &&
                                       rates[break_shift].close < zone.low);
         if(!break_to_demand && !break_to_supply)
            continue;

         const int age = break_shift - 1;
         if(age > strategy_zone_expiry_bars)
            continue;
         if(!IsZoneRetested(zone, want_long, retest_pad, rates))
            continue;
         if(want_long && !BullishReversalPattern(rates))
            continue;
         if(!want_long && !BearishReversalPattern(rates))
            continue;
         if(age < best_age)
           {
            best_age = age;
            out_zone = zone;
            found = true;
           }
         break;
        }
     }

   return found;
  }

double OpposingZoneTarget(MqlRates &rates[],
                          const int copied,
                          const QM_OrderType side,
                          const double entry,
                          const double fallback_tp)
  {
   double target = 0.0;
   const double atr = QM_ATR(_Symbol, strategy_zone_timeframe, strategy_atr_period, 1);
   const double pad = (atr > 0.0) ? atr * strategy_zone_pad_atr_mult : 0.0;
   const int oldest = copied - strategy_atr_period - 3;

   for(int base_shift = oldest; base_shift >= 3; --base_shift)
     {
      const int impulse_shift = base_shift - 1;
      StrategyZone zone;
      bool candidate = false;
      if(side == QM_BUY && IsBearishImpulse(rates, copied, impulse_shift))
        {
         BuildBaseZone(rates, base_shift, true, pad, zone);
         candidate = ZoneStillActive(rates, zone, 1) && zone.low > entry && zone.low <= fallback_tp;
        }
      if(side == QM_SELL && IsBullishImpulse(rates, copied, impulse_shift))
        {
         BuildBaseZone(rates, base_shift, false, pad, zone);
         candidate = ZoneStillActive(rates, zone, 1) && zone.high < entry && zone.high >= fallback_tp;
        }
      if(!candidate)
         continue;

      const double level = (side == QM_BUY) ? zone.low : zone.high;
      if(target <= 0.0)
         target = level;
      else if(side == QM_BUY && level < target)
         target = level;
      else if(side == QM_SELL && level > target)
         target = level;
     }

   if(target <= 0.0)
      return fallback_tp;
   return QM_StopRulesNormalizePrice(_Symbol, target);
  }

bool HasOurPosition()
  {
   return (QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0);
  }

double CurrentEntryPrice(const QM_OrderType side)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(side == QM_BUY)
      return (ask > 0.0) ? ask : bid;
   return (bid > 0.0) ? bid : ask;
  }

bool BuildTradeRequest(QM_EntryRequest &req,
                       const QM_OrderType side,
                       const StrategyZone &zone,
                       MqlRates &rates[],
                       const int copied)
  {
   const double entry = CurrentEntryPrice(side);
   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   double sl = 0.0;
   if(side == QM_BUY)
      sl = QM_StopRulesNormalizePrice(_Symbol, zone.low - atr * strategy_stop_atr_buffer);
   else
      sl = QM_StopRulesNormalizePrice(_Symbol, zone.high + atr * strategy_stop_atr_buffer);

   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;

   const double rr_for_target = MathMax(strategy_fallback_rr, strategy_opposing_zone_max_rr);
   const double max_zone_tp = QM_TakeRR(_Symbol, side, entry, sl, rr_for_target);
   const double fallback_tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_fallback_rr);
   if(max_zone_tp <= 0.0 || fallback_tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = OpposingZoneTarget(rates, copied, side, entry, max_zone_tp);
   if(req.tp <= 0.0)
      req.tp = fallback_tp;
   req.reason = (side == QM_BUY) ? "LIQ_FLIP_LONG" : "LIQ_FLIP_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_active_zone_low = zone.low;
   g_active_zone_high = zone.high;
   g_active_zone_long = (side == QM_BUY);
   g_have_active_zone = true;
   return true;
  }

void RefreshCachedZoneExit(MqlRates &rates[])
  {
   g_cached_zone_exit_long = false;
   g_cached_zone_exit_short = false;
   if(!g_have_active_zone)
      return;

   if(g_active_zone_long && rates[1].close < g_active_zone_low)
      g_cached_zone_exit_long = true;
   if(!g_active_zone_long && rates[1].close > g_active_zone_high)
      g_cached_zone_exit_short = true;
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_pips <= 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
   if(ask > 0.0 && bid > 0.0 && ask > bid && cap > 0.0 && (ask - bid) > cap)
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

   if(strategy_zone_scan_bars < strategy_atr_period + 20 ||
      strategy_zone_expiry_bars < 1 ||
      strategy_atr_period < 2 ||
      strategy_impulse_atr_mult <= 0.0 ||
      strategy_body_atr_mult <= 0.0 ||
      strategy_stop_atr_buffer <= 0.0 ||
      strategy_fallback_rr <= 0.0 ||
      strategy_opposing_zone_max_rr <= 0.0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_zone_timeframe, 0, strategy_zone_scan_bars, rates); // perf-allowed: bounded HTF structural zone scan; EntrySignal is called only after the framework QM_IsNewBar() gate.
   if(copied < strategy_atr_period + 20)
      return false;

   RefreshCachedZoneExit(rates);
   if(HasOurPosition())
      return false;

   StrategyZone zone;
   if(FindFlippedRetestZone(rates, copied, true, zone))
      return BuildTradeRequest(req, QM_BUY, zone, rates, copied);
   if(FindFlippedRetestZone(rates, copied, false, zone))
      return BuildTradeRequest(req, QM_SELL, zone, rates, copied);

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
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

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int period_seconds = PeriodSeconds(_Period);
      if(period_seconds > 0 && open_time > 0)
        {
         const int held_bars = (int)((TimeCurrent() - open_time) / period_seconds);
         if(held_bars >= strategy_max_hold_bars)
            return true;
        }

      if(position_type == POSITION_TYPE_BUY && g_cached_zone_exit_long)
         return true;
      if(position_type == POSITION_TYPE_SELL && g_cached_zone_exit_short)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_9258_mql5-liq-flip\"}");
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
