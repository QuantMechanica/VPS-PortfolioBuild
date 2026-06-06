#property strict
#property version   "5.0"
#property description "QM5_10916 Grimes Impulse Reluctant Pullback"
// Strategy Card: QM5_10916 (grimes-impulse), G0 APPROVED 2026-05-22.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Strategy-specific code is limited to inputs, helpers used by the five
// Strategy_* hooks, and the hook bodies. Framework lifecycle remains intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10916;
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
input int    strategy_atr_period             = 14;
input int    strategy_ema_period             = 50;
input int    strategy_impulse_bars           = 5;
input int    strategy_impulse_min_closes     = 3;
input double strategy_impulse_atr_mult       = 2.0;
input int    strategy_min_pullback_bars      = 2;
input int    strategy_max_pullback_bars      = 8;
input double strategy_max_retrace_fraction   = 0.382;
input double strategy_pullback_range_atr_mult = 0.80;
input double strategy_stop_buffer_atr_mult   = 0.25;
input double strategy_max_stop_atr_mult      = 2.50;
input double strategy_target_r_multiple      = 1.50;
input double strategy_trail_trigger_r        = 1.00;
input double strategy_trail_atr_mult         = 2.00;
input double strategy_spread_stop_fraction   = 0.10;
input int    strategy_time_exit_bars         = 18;

ulong  g_active_ticket = 0;
bool   g_active_is_long = false;
double g_entry_price = 0.0;
double g_initial_risk = 0.0;
double g_extreme_close = 0.0;
bool   g_trail_armed = false;

double StrategyNormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = _Digits;
   return NormalizeDouble(price, digits);
  }

void StrategyInitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool StrategyGetOurPosition(ulong &ticket,
                            ENUM_POSITION_TYPE &ptype,
                            double &open_price,
                            double &current_sl)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_price = 0.0;
   current_sl = 0.0;

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
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      current_sl = PositionGetDouble(POSITION_SL);
      return true;
     }

   return false;
  }

bool StrategyHasOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double current_sl;
   return StrategyGetOurPosition(ticket, ptype, open_price, current_sl);
  }

void StrategyEnsureTracking(const ulong ticket,
                            const ENUM_POSITION_TYPE ptype,
                            const double open_price,
                            const double current_sl)
  {
   if(ticket == g_active_ticket)
      return;

   g_active_ticket = ticket;
   g_active_is_long = (ptype == POSITION_TYPE_BUY);
   g_entry_price = open_price;
   g_initial_risk = MathAbs(open_price - current_sl);
   g_extreme_close = open_price;
   g_trail_armed = false;
  }

void StrategyAdvanceOpenStateOnNewBar()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double current_sl;
   if(!StrategyGetOurPosition(ticket, ptype, open_price, current_sl))
     {
      g_active_ticket = 0;
      return;
     }

   StrategyEnsureTracking(ticket, ptype, open_price, current_sl);
   const double close1 = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: one closed-bar close, called only from the new-bar-gated entry hook.
   if(close1 <= 0.0)
      return;

   if(ptype == POSITION_TYPE_BUY)
      g_extreme_close = MathMax(g_extreme_close, close1);
   else
      g_extreme_close = MathMin(g_extreme_close, close1);
  }

double StrategyHighestHigh(const MqlRates &rates[], const int from_shift, const int to_shift)
  {
   double highest = -DBL_MAX;
   for(int s = from_shift; s <= to_shift; ++s)
      highest = MathMax(highest, rates[s].high);
   return highest;
  }

double StrategyLowestLow(const MqlRates &rates[], const int from_shift, const int to_shift)
  {
   double lowest = DBL_MAX;
   for(int s = from_shift; s <= to_shift; ++s)
      lowest = MathMin(lowest, rates[s].low);
   return lowest;
  }

double StrategyAverageRange(const MqlRates &rates[], const int from_shift, const int to_shift)
  {
   double total = 0.0;
   int count = 0;
   for(int s = from_shift; s <= to_shift; ++s)
     {
      const double range = rates[s].high - rates[s].low;
      if(range <= 0.0)
         return 0.0;
      total += range;
      count++;
     }
   return (count > 0) ? total / count : 0.0;
  }

bool StrategyBuildLongRequest(const double pullback_low,
                              const double atr,
                              QM_EntryRequest &req)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid || atr <= 0.0)
      return false;

   const double sl = StrategyNormalizePrice(pullback_low - strategy_stop_buffer_atr_mult * atr);
   if(sl <= 0.0 || sl >= ask)
      return false;

   const double stop_dist = ask - sl;
   if(stop_dist <= 0.0 || stop_dist > strategy_max_stop_atr_mult * atr)
      return false;

   const double spread = ask - bid;
   if(spread > strategy_spread_stop_fraction * stop_dist)
      return false;

   const double tp = StrategyNormalizePrice(ask + strategy_target_r_multiple * stop_dist);
   if(tp <= ask)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = "GRIMES_IMPULSE_LONG";
   return true;
  }

bool StrategyBuildShortRequest(const double pullback_high,
                               const double atr,
                               QM_EntryRequest &req)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid || atr <= 0.0)
      return false;

   const double sl = StrategyNormalizePrice(pullback_high + strategy_stop_buffer_atr_mult * atr);
   if(sl <= 0.0 || sl <= bid)
      return false;

   const double stop_dist = sl - bid;
   if(stop_dist <= 0.0 || stop_dist > strategy_max_stop_atr_mult * atr)
      return false;

   const double spread = ask - bid;
   if(spread > strategy_spread_stop_fraction * stop_dist)
      return false;

   const double tp = StrategyNormalizePrice(bid - strategy_target_r_multiple * stop_dist);
   if(tp <= 0.0 || tp >= bid)
      return false;

   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = "GRIMES_IMPULSE_SHORT";
   return true;
  }

bool StrategyLongSetup(const MqlRates &rates[],
                       const int pullback_bars,
                       const double atr,
                       QM_EntryRequest &req)
  {
   const int impulse_last = pullback_bars + 2;
   const int impulse_first = impulse_last + strategy_impulse_bars - 1;

   int higher_closes = 0;
   for(int s = impulse_first; s >= impulse_last; --s)
      if(rates[s].close > rates[s + 1].close)
         higher_closes++;
   if(higher_closes < strategy_impulse_min_closes)
      return false;

   const double impulse_high = StrategyHighestHigh(rates, impulse_last, impulse_first);
   const double impulse_start = rates[impulse_first].low;
   const double impulse_move = impulse_high - impulse_start;
   if(impulse_start <= 0.0 || impulse_move < strategy_impulse_atr_mult * atr)
      return false;

   const double ema = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, impulse_last);
   if(ema <= 0.0 || rates[impulse_last].close <= ema)
      return false;

   const double pullback_low = StrategyLowestLow(rates, 2, pullback_bars + 1);
   const double pullback_high = StrategyHighestHigh(rates, 2, pullback_bars + 1);
   const double pullback_avg_range = StrategyAverageRange(rates, 2, pullback_bars + 1);
   if(pullback_low <= 0.0 || pullback_high <= 0.0 || pullback_avg_range <= 0.0)
      return false;
   if(pullback_avg_range >= strategy_pullback_range_atr_mult * atr)
      return false;

   const double max_retrace_low = impulse_high - strategy_max_retrace_fraction * impulse_move;
   const double midpoint = impulse_start + 0.5 * impulse_move;
   if(pullback_low < max_retrace_low || pullback_low <= midpoint)
      return false;

   if(rates[1].close <= pullback_high)
      return false;

   return StrategyBuildLongRequest(pullback_low, atr, req);
  }

bool StrategyShortSetup(const MqlRates &rates[],
                        const int pullback_bars,
                        const double atr,
                        QM_EntryRequest &req)
  {
   const int impulse_last = pullback_bars + 2;
   const int impulse_first = impulse_last + strategy_impulse_bars - 1;

   int lower_closes = 0;
   for(int s = impulse_first; s >= impulse_last; --s)
      if(rates[s].close < rates[s + 1].close)
         lower_closes++;
   if(lower_closes < strategy_impulse_min_closes)
      return false;

   const double impulse_low = StrategyLowestLow(rates, impulse_last, impulse_first);
   const double impulse_start = rates[impulse_first].high;
   const double impulse_move = impulse_start - impulse_low;
   if(impulse_low <= 0.0 || impulse_move < strategy_impulse_atr_mult * atr)
      return false;

   const double ema = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, impulse_last);
   if(ema <= 0.0 || rates[impulse_last].close >= ema)
      return false;

   const double pullback_high = StrategyHighestHigh(rates, 2, pullback_bars + 1);
   const double pullback_low = StrategyLowestLow(rates, 2, pullback_bars + 1);
   const double pullback_avg_range = StrategyAverageRange(rates, 2, pullback_bars + 1);
   if(pullback_low <= 0.0 || pullback_high <= 0.0 || pullback_avg_range <= 0.0)
      return false;
   if(pullback_avg_range >= strategy_pullback_range_atr_mult * atr)
      return false;

   const double max_retrace_high = impulse_low + strategy_max_retrace_fraction * impulse_move;
   const double midpoint = impulse_start - 0.5 * impulse_move;
   if(pullback_high > max_retrace_high || pullback_high >= midpoint)
      return false;

   if(rates[1].close >= pullback_low)
      return false;

   return StrategyBuildShortRequest(pullback_high, atr, req);
  }

// No Trade Filter (time, spread, news). Time/news are handled by the framework;
// spread is checked against the computed stop distance in Strategy_EntrySignal.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (ask <= 0.0 || bid <= 0.0 || ask <= bid);
  }

// Trade Entry. Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   StrategyInitRequest(req);
   StrategyAdvanceOpenStateOnNewBar();

   if(StrategyHasOpenPosition())
      return false;
   if(strategy_atr_period < 2 || strategy_ema_period < 2 ||
      strategy_impulse_bars != 5 || strategy_impulse_min_closes < 1 ||
      strategy_min_pullback_bars < 1 ||
      strategy_max_pullback_bars < strategy_min_pullback_bars ||
      strategy_impulse_atr_mult <= 0.0 ||
      strategy_max_retrace_fraction <= 0.0 || strategy_max_retrace_fraction >= 0.5 ||
      strategy_pullback_range_atr_mult <= 0.0 ||
      strategy_stop_buffer_atr_mult < 0.0 ||
      strategy_max_stop_atr_mult <= 0.0 ||
      strategy_target_r_multiple <= 0.0 ||
      strategy_spread_stop_fraction < 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const int need_bars = strategy_max_pullback_bars + strategy_impulse_bars + 5;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, need_bars, rates); // perf-allowed: bounded closed-bar structural scan for the card's impulse/pullback sequence.
   if(copied < need_bars)
      return false;

   for(int pb = strategy_min_pullback_bars; pb <= strategy_max_pullback_bars; ++pb)
     {
      if(StrategyLongSetup(rates, pb, atr, req))
         return true;
      if(StrategyShortSetup(rates, pb, atr, req))
         return true;
     }

   return false;
  }

// Trade Management. Arm the 2*ATR trail only after price has moved at least 1R.
void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double current_sl;
   if(!StrategyGetOurPosition(ticket, ptype, open_price, current_sl))
     {
      g_active_ticket = 0;
      return;
     }

   StrategyEnsureTracking(ticket, ptype, open_price, current_sl);
   if(g_initial_risk <= 0.0)
      return;

   const bool is_long = (ptype == POSITION_TYPE_BUY);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bid <= 0.0 || ask <= 0.0 || point <= 0.0)
      return;

   const double market = is_long ? bid : ask;
   const double moved = is_long ? (market - g_entry_price) : (g_entry_price - market);
   if(!g_trail_armed && moved >= strategy_trail_trigger_r * g_initial_risk)
      g_trail_armed = true;
   if(!g_trail_armed)
      return;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_trail_atr_mult <= 0.0)
      return;

   double trail_sl = is_long ? (g_extreme_close - strategy_trail_atr_mult * atr)
                             : (g_extreme_close + strategy_trail_atr_mult * atr);
   trail_sl = StrategyNormalizePrice(trail_sl);
   if(trail_sl <= 0.0)
      return;

   const bool valid = is_long ? (trail_sl < bid) : (trail_sl > ask);
   const bool improves = (current_sl <= 0.0) ||
                         (is_long ? (trail_sl > current_sl + point * 0.5)
                                  : (trail_sl < current_sl - point * 0.5));
   if(valid && improves)
      QM_TM_MoveSL(ticket, trail_sl, "grimes_impulse_2atr_trail");
  }

// Trade Close. Time exit after the card-specified H1 bar count.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_time_exit_bars <= 0)
      return false;

   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(period_seconds <= 0)
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

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time > 0 && (TimeCurrent() - open_time) >= strategy_time_exit_bars * period_seconds)
         return true;
     }

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase).
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10916_grimes_impulse\"}");
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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
