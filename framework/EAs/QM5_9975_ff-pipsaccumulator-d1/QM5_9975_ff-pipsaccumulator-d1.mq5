#property strict
#property version   "5.0"
#property description "QM5_9975 FF PipsAccumulator D1 pullback stop"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9975 — ForexFactory PipsAccumulator D1 Pullback Stop
// Card: QM5_9975_ff-pipsaccumulator-d1
// Source: bpola, PipsAccumulator, ForexFactory 2021
// Logic: EMA5/10 trend filter on D1; place buy/sell stop 1pip beyond pullback
//        bar; SL at local N-bar extrema +-3pips; TP=3R; BE@1R; trail from day5.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9975;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal      = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance    = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours                 = 336;
input string qm_news_min_impact                      = "high";
input QM_NewsMode qm_news_mode_legacy                = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled                 = true;
input int    qm_friday_close_hour_broker             = 21;

input group "Stress"
input double qm_stress_reject_probability            = 0.0;

input group "Strategy"
input int    strategy_ema_fast         = 5;     // EMA fast period (card: 5)
input int    strategy_ema_slow         = 10;    // EMA slow period (card: 10)
input int    strategy_entry_pips       = 1;     // pips beyond pullback bar high/low for stop entry
input int    strategy_sl_buffer_pips   = 3;     // pips beyond local extrema for SL
input double strategy_tp_r_multiple    = 3.0;   // TP as R multiple (card: 3R)
input int    strategy_sl_lookback      = 3;     // local extrema lookback in D1 bars (P3: sweep 1/3/5)
input int    strategy_trail_start_days = 5;     // trailing starts after this many days from entry
input int    strategy_trail_lookback   = 3;     // bars for trailing low/high
input int    strategy_stale_bars       = 5;     // cancel pending after this many D1 bars
input double strategy_spread_max_pct   = 6.0;   // max spread as % of SL distance

// File-scope cached trail SL — updated once per D1 bar in UpdateTrailCache(),
// applied every tick in Strategy_ManageOpenPosition().
double g_cached_trail_sl = 0.0;

// =============================================================================
// Helpers
// =============================================================================

ulong FindPendingTicket()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong t = OrderGetTicket(i);
      if(t == 0 || !OrderSelect(t))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot == ORDER_TYPE_BUY_STOP || ot == ORDER_TYPE_SELL_STOP)
         return t;
     }
   return 0;
  }

ulong FindPositionTicket(ENUM_POSITION_TYPE &pos_type)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return t;
     }
   return 0;
  }

// Called once per new D1 bar (from Strategy_EntrySignal).
// Updates g_cached_trail_sl for use by Strategy_ManageOpenPosition.
void UpdateTrailCache()
  {
   ENUM_POSITION_TYPE pos_type;
   const ulong ticket = FindPositionTicket(pos_type);
   if(ticket == 0)
     {
      g_cached_trail_sl = 0.0;
      return;
     }

   const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
   if((TimeCurrent() - open_time) < (datetime)(strategy_trail_start_days * 86400))
     {
      g_cached_trail_sl = 0.0;
      return;
     }

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int    pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   const double pip = point * pip_factor;
   const bool   is_buy = (pos_type == POSITION_TYPE_BUY);

   if(is_buy)
     {
      double lo_min = iLow(_Symbol, PERIOD_D1, 1); // perf-allowed: bespoke structural trail
      for(int i = 2; i <= strategy_trail_lookback; ++i)
        {
         const double v = iLow(_Symbol, PERIOD_D1, i); // perf-allowed
         if(v > 0.0 && v < lo_min)
            lo_min = v;
        }
      g_cached_trail_sl = NormalizeDouble(lo_min - strategy_sl_buffer_pips * pip, _Digits);
     }
   else
     {
      double hi_max = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed: bespoke structural trail
      for(int i = 2; i <= strategy_trail_lookback; ++i)
        {
         const double v = iHigh(_Symbol, PERIOD_D1, i); // perf-allowed
         if(v > 0.0 && v > hi_max)
            hi_max = v;
        }
      g_cached_trail_sl = NormalizeDouble(hi_max + strategy_sl_buffer_pips * pip, _Digits);
     }
  }

// =============================================================================
// No Trade Filter
// =============================================================================

bool Strategy_NoTradeFilter()
  {
   return false;
  }

// =============================================================================
// Entry Signal — called once per new D1 bar (QM_IsNewBar gate in OnTick)
// =============================================================================

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Update trail cache for any open position (runs once per D1 bar)
   UpdateTrailCache();

   // --- Pending order management ---
   const ulong pend_ticket = FindPendingTicket();
   if(pend_ticket != 0)
     {
      const datetime placed = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      const bool is_stale   = ((TimeCurrent() - placed) >= (datetime)(strategy_stale_bars * 86400));
      if(is_stale)
        {
         QM_TM_RemovePendingOrder(pend_ticket, "stale_5d");
         return false;
        }
      // Cancel for rework — re-place below if conditions still valid
      QM_TM_RemovePendingOrder(pend_ticket, "rework_d1");
     }

   // --- No new entry if position already open ---
   ENUM_POSITION_TYPE dummy;
   if(FindPositionTicket(dummy) != 0)
      return false;

   // --- EMA trend filter ---
   const double ema_fast = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_fast, 1);
   const double ema_slow = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_slow, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   const bool long_trend  = (ema_fast > ema_slow);
   const bool short_trend = (ema_fast < ema_slow);
   if(!long_trend && !short_trend)
      return false;

   // --- Pullback bar detection (perf-allowed: bespoke structural logic, QM_IsNewBar gated) ---
   const double high1 = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed
   const double high2 = iHigh(_Symbol, PERIOD_D1, 2); // perf-allowed
   const double low1  = iLow (_Symbol, PERIOD_D1, 1); // perf-allowed
   const double low2  = iLow (_Symbol, PERIOD_D1, 2); // perf-allowed
   if(high1 <= 0.0 || high2 <= 0.0 || low1 <= 0.0 || low2 <= 0.0)
      return false;

   const bool long_pb  = long_trend  && (low1  < low2);  // pullback lower low
   const bool short_pb = short_trend && (high1 > high2); // retracement higher high
   if(!long_pb && !short_pb)
      return false;

   // --- Local extrema for SL (perf-allowed: bespoke structural logic, loop bounded by sl_lookback<=5) ---
   const double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const int    digits     = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int    pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   const double pip        = point * pip_factor;

   double entry_price = 0.0;
   double sl_price    = 0.0;

   if(long_pb)
     {
      double lo_min = low1;
      for(int i = 2; i <= strategy_sl_lookback; ++i)
        {
         const double v = iLow(_Symbol, PERIOD_D1, i); // perf-allowed
         if(v > 0.0 && v < lo_min)
            lo_min = v;
        }
      entry_price = high1 + strategy_entry_pips * pip;
      sl_price    = lo_min - strategy_sl_buffer_pips * pip;
     }
   else
     {
      double hi_max = high1;
      for(int i = 2; i <= strategy_sl_lookback; ++i)
        {
         const double v = iHigh(_Symbol, PERIOD_D1, i); // perf-allowed
         if(v > 0.0 && v > hi_max)
            hi_max = v;
        }
      entry_price = low1 - strategy_entry_pips * pip;
      sl_price    = hi_max + strategy_sl_buffer_pips * pip;
     }

   if(entry_price <= 0.0 || sl_price <= 0.0)
      return false;

   const double sl_dist = MathAbs(entry_price - sl_price);
   if(sl_dist <= 0.0)
      return false;

   // --- Spread filter: spread <= spread_max_pct % of SL distance ---
   if(strategy_spread_max_pct > 0.0)
     {
      const double spread_val = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * point;
      if(spread_val > sl_dist * strategy_spread_max_pct / 100.0)
         return false;
     }

   // --- Compute TP at 3R ---
   const double tp_price = long_pb ? (entry_price + sl_dist * strategy_tp_r_multiple)
                                   : (entry_price - sl_dist * strategy_tp_r_multiple);

   // --- Fill request ---
   req.type               = long_pb ? QM_BUY_STOP : QM_SELL_STOP;
   req.price              = NormalizeDouble(entry_price, _Digits);
   req.sl                 = NormalizeDouble(sl_price,    _Digits);
   req.tp                 = NormalizeDouble(tp_price,    _Digits);
   req.reason             = long_pb ? "ff_pipsaccum_buy_stop" : "ff_pipsaccum_sell_stop";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   return true;
  }

// =============================================================================
// Trade Management — called every tick
// =============================================================================

void Strategy_ManageOpenPosition()
  {
   ENUM_POSITION_TYPE pos_type;
   const ulong ticket = FindPositionTicket(pos_type);
   if(ticket == 0)
      return;

   const bool   is_buy     = (pos_type == POSITION_TYPE_BUY);
   const double pos_open   = PositionGetDouble(POSITION_PRICE_OPEN);
   const double pos_sl     = PositionGetDouble(POSITION_SL);
   const double point      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pos_open <= 0.0 || pos_sl <= 0.0 || point <= 0.0)
      return;

   // --- Breakeven at +1R ---
   const double sl_dist = MathAbs(pos_open - pos_sl);
   if(sl_dist > 0.0)
     {
      const int    digits     = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      const int    pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
      const int    sl_pips    = (int)MathRound(sl_dist / (point * pip_factor));
      if(sl_pips > 0)
         QM_TM_MoveToBreakEven(ticket, sl_pips, 0);
     }

   // --- Trailing stop (cached D1 value, active after strategy_trail_start_days) ---
   if(g_cached_trail_sl > 0.0)
     {
      const double curr_sl  = PositionGetDouble(POSITION_SL);
      const bool   improves = (curr_sl <= 0.0) ||
                              (is_buy ? (g_cached_trail_sl > curr_sl + point * 0.5)
                                      : (g_cached_trail_sl < curr_sl - point * 0.5));
      if(improves)
         QM_TM_MoveSL(ticket, g_cached_trail_sl, "trail_d1_low_high");
     }
  }

// =============================================================================
// Exit Signal — called every tick; returns true to close position
// =============================================================================

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE pos_type;
   const ulong ticket = FindPositionTicket(pos_type);
   if(ticket == 0)
      return false;

   // Close on opposite EMA5/10 cross (bar[2] aligned, bar[1] crossed)
   const double ef1 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_fast, 1);
   const double es1 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_slow, 1);
   const double ef2 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_fast, 2);
   const double es2 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_slow, 2);
   if(ef1 <= 0.0 || es1 <= 0.0 || ef2 <= 0.0 || es2 <= 0.0)
      return false;

   if(pos_type == POSITION_TYPE_BUY)
      return (ef2 >= es2 && ef1 < es1);   // bearish cross → close long
   else
      return (ef2 <= es2 && ef1 > es1);   // bullish cross → close short
  }

// =============================================================================
// News Filter Hook
// =============================================================================

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// =============================================================================
// Framework wiring — do NOT edit below this line unless you know why.
// =============================================================================

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9975\",\"slug\":\"ff-pipsaccumulator-d1\"}");
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
