#property strict
#property version   "5.0"
#property description "QM5_10938 Grimes New-High Acceptance Continuation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10938;
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
input int    strategy_breakout_lookback          = 40;
input int    strategy_acceptance_min_bars        = 4;
input int    strategy_acceptance_max_bars        = 16;
input double strategy_acceptance_close_fraction  = 0.70;
input double strategy_acceptance_fail_atr_mult   = 0.50;
input int    strategy_atr_period                 = 20;
input double strategy_impulse_atr_mult           = 2.0;
input double strategy_breakout_bar_atr_max       = 3.0;
input double strategy_stop_atr_buffer            = 0.25;
input double strategy_max_stop_atr_mult          = 2.5;
input double strategy_acceptance_width_fraction  = 0.50;
input int    strategy_ema_period                 = 20;
input int    strategy_ema_slope_bars             = 5;
input double strategy_tp_rr                      = 2.0;
input double strategy_be_trigger_rr              = 1.0;
input int    strategy_max_hold_bars              = 24;
input double strategy_spread_stop_fraction       = 0.08;

double             g_pending_breakout_level = 0.0;
ENUM_POSITION_TYPE g_pending_position_type  = POSITION_TYPE_BUY;
ulong              g_context_ticket         = 0;
double             g_context_breakout_level = 0.0;
ENUM_POSITION_TYPE g_context_position_type  = POSITION_TYPE_BUY;

double H1Open(const int shift)
  {
   return iOpen(_Symbol, PERIOD_H1, shift); // perf-allowed: bounded H1 card structure in closed-bar hook.
  }

double H1High(const int shift)
  {
   return iHigh(_Symbol, PERIOD_H1, shift); // perf-allowed: bounded H1 breakout/acceptance structure.
  }

double H1Low(const int shift)
  {
   return iLow(_Symbol, PERIOD_H1, shift); // perf-allowed: bounded H1 swing and stop structure.
  }

double H1Close(const int shift)
  {
   return iClose(_Symbol, PERIOD_H1, shift); // perf-allowed: bounded H1 closed-bar acceptance math.
  }

double D1Close(const int shift)
  {
   return iClose(_Symbol, PERIOD_D1, shift); // perf-allowed: D1 trend filter close vs EMA.
  }

bool SelectOurPosition(ulong &ticket,
                       ENUM_POSITION_TYPE &ptype,
                       double &open_price,
                       double &sl,
                       datetime &open_time)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_price = 0.0;
   sl = 0.0;
   open_time = 0;

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
      sl = PositionGetDouble(POSITION_SL);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

double HighestHigh(const int start_shift, const int count)
  {
   double highest = -DBL_MAX;
   for(int i = 0; i < count; ++i)
     {
      const double h = H1High(start_shift + i);
      if(h <= 0.0)
         return 0.0;
      highest = MathMax(highest, h);
     }
   return highest;
  }

double LowestLow(const int start_shift, const int count)
  {
   double lowest = DBL_MAX;
   for(int i = 0; i < count; ++i)
     {
      const double l = H1Low(start_shift + i);
      if(l <= 0.0)
         return 0.0;
      lowest = MathMin(lowest, l);
     }
   return lowest;
  }

double LastSwingLowBeforeBreakout(const int breakout_shift)
  {
   double fallback = DBL_MAX;
   for(int shift = breakout_shift + 1; shift <= breakout_shift + strategy_breakout_lookback; ++shift)
     {
      const double l = H1Low(shift);
      if(l <= 0.0)
         return 0.0;
      fallback = MathMin(fallback, l);

      const double older = H1Low(shift + 1);
      const double newer = H1Low(shift - 1);
      if(older > 0.0 && newer > 0.0 && l <= older && l < newer)
         return l;
     }
   return (fallback == DBL_MAX) ? 0.0 : fallback;
  }

double LastSwingHighBeforeBreakout(const int breakout_shift)
  {
   double fallback = -DBL_MAX;
   for(int shift = breakout_shift + 1; shift <= breakout_shift + strategy_breakout_lookback; ++shift)
     {
      const double h = H1High(shift);
      if(h <= 0.0)
         return 0.0;
      fallback = MathMax(fallback, h);

      const double older = H1High(shift + 1);
      const double newer = H1High(shift - 1);
      if(older > 0.0 && newer > 0.0 && h >= older && h > newer)
         return h;
     }
   return (fallback == -DBL_MAX) ? 0.0 : fallback;
  }

bool D1TrendAllows(const bool want_long)
  {
   const int slope_shift = 1 + MathMax(1, strategy_ema_slope_bars);
   const double close_d1 = D1Close(1);
   const double ema_now = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_period, 1);
   const double ema_then = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_period, slope_shift);
   if(close_d1 <= 0.0 || ema_now <= 0.0 || ema_then <= 0.0)
      return false;

   if(want_long)
      return (close_d1 > ema_now && ema_now > ema_then);
   return (close_d1 < ema_now && ema_now < ema_then);
  }

bool FindAcceptanceSetup(const int entry_shift,
                         const bool want_long,
                         double &old_breakout_level,
                         double &acceptance_low,
                         double &acceptance_high)
  {
   old_breakout_level = 0.0;
   acceptance_low = 0.0;
   acceptance_high = 0.0;

   if(strategy_breakout_lookback < 2 ||
      strategy_acceptance_min_bars < 1 ||
      strategy_acceptance_max_bars < strategy_acceptance_min_bars ||
      strategy_acceptance_close_fraction <= 0.0 ||
      strategy_acceptance_close_fraction > 1.0)
      return false;

   if(!D1TrendAllows(want_long))
      return false;

   const double entry_close = H1Close(entry_shift);
   if(entry_close <= 0.0)
      return false;

   for(int acc_bars = strategy_acceptance_min_bars; acc_bars <= strategy_acceptance_max_bars; ++acc_bars)
     {
      const int first_acceptance_shift = entry_shift + 1;
      const int breakout_shift = entry_shift + acc_bars + 1;
      const double breakout_close = H1Close(breakout_shift);
      const double breakout_high = H1High(breakout_shift);
      const double breakout_low = H1Low(breakout_shift);
      const double breakout_range = breakout_high - breakout_low;
      const double breakout_atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, breakout_shift);
      if(breakout_close <= 0.0 || breakout_high <= 0.0 || breakout_low <= 0.0 || breakout_atr <= 0.0)
         continue;
      if(breakout_range <= 0.0 || breakout_range > strategy_breakout_bar_atr_max * breakout_atr)
         continue;

      const double prior_high = HighestHigh(breakout_shift + 1, strategy_breakout_lookback);
      const double prior_low = LowestLow(breakout_shift + 1, strategy_breakout_lookback);
      if(prior_high <= 0.0 || prior_low <= 0.0)
         continue;

      const double level = want_long ? prior_high : prior_low;
      if(want_long && breakout_close <= level)
         continue;
      if(!want_long && breakout_close >= level)
         continue;

      const double impulse_anchor = want_long ? LastSwingLowBeforeBreakout(breakout_shift)
                                              : LastSwingHighBeforeBreakout(breakout_shift);
      if(impulse_anchor <= 0.0)
         continue;

      const double impulse = want_long ? (breakout_high - impulse_anchor)
                                       : (impulse_anchor - breakout_low);
      if(impulse < strategy_impulse_atr_mult * breakout_atr)
         continue;

      double acc_low = DBL_MAX;
      double acc_high = -DBL_MAX;
      int accepted_closes = 0;
      bool failed_acceptance = false;

      for(int shift = first_acceptance_shift; shift < first_acceptance_shift + acc_bars; ++shift)
        {
         const double c = H1Close(shift);
         const double h = H1High(shift);
         const double l = H1Low(shift);
         if(c <= 0.0 || h <= 0.0 || l <= 0.0)
           {
            failed_acceptance = true;
            break;
           }

         acc_low = MathMin(acc_low, l);
         acc_high = MathMax(acc_high, h);
         if(want_long)
           {
            if(c >= level)
               accepted_closes++;
            if(c < level - strategy_acceptance_fail_atr_mult * breakout_atr)
               failed_acceptance = true;
           }
         else
           {
            if(c <= level)
               accepted_closes++;
            if(c > level + strategy_acceptance_fail_atr_mult * breakout_atr)
               failed_acceptance = true;
           }
        }

      if(failed_acceptance || acc_low == DBL_MAX || acc_high == -DBL_MAX)
         continue;

      const int min_accepted = (int)MathCeil(strategy_acceptance_close_fraction * (double)acc_bars);
      if(accepted_closes < min_accepted)
         continue;

      const double acceptance_width = acc_high - acc_low;
      if(acceptance_width <= 0.0 || acceptance_width > strategy_acceptance_width_fraction * impulse)
         continue;

      if(want_long && entry_close <= acc_high)
         continue;
      if(!want_long && entry_close >= acc_low)
         continue;

      old_breakout_level = level;
      acceptance_low = acc_low;
      acceptance_high = acc_high;
      return true;
     }

   return false;
  }

bool RestorePositionContext(const ulong ticket,
                            const ENUM_POSITION_TYPE ptype,
                            const datetime open_time)
  {
   if(ticket == g_context_ticket && g_context_breakout_level > 0.0 && ptype == g_context_position_type)
      return true;

   if(g_pending_breakout_level > 0.0 && ptype == g_pending_position_type)
     {
      g_context_ticket = ticket;
      g_context_breakout_level = g_pending_breakout_level;
      g_context_position_type = ptype;
      return true;
     }

   const int open_shift = iBarShift(_Symbol, PERIOD_H1, open_time, false); // perf-allowed: one position-age lookup for context restore.
   if(open_shift < 0)
      return false;

   const int signal_shift = open_shift + 1;
   double level = 0.0;
   double acc_low = 0.0;
   double acc_high = 0.0;
   const bool want_long = (ptype == POSITION_TYPE_BUY);
   if(!FindAcceptanceSetup(signal_shift, want_long, level, acc_low, acc_high))
      return false;

   g_context_ticket = ticket;
   g_context_breakout_level = level;
   g_context_position_type = ptype;
   return true;
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

   if((ENUM_TIMEFRAMES)_Period != PERIOD_H1)
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double current_sl;
   datetime open_time;
   if(SelectOurPosition(ticket, ptype, open_price, current_sl, open_time))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid || point <= 0.0 || atr <= 0.0)
      return false;

   double level = 0.0;
   double acc_low = 0.0;
   double acc_high = 0.0;
   bool want_long = true;
   bool setup_ok = FindAcceptanceSetup(1, true, level, acc_low, acc_high);
   if(!setup_ok)
     {
      want_long = false;
      setup_ok = FindAcceptanceSetup(1, false, level, acc_low, acc_high);
     }
   if(!setup_ok)
      return false;

   const QM_OrderType side = want_long ? QM_BUY : QM_SELL;
   const double entry = want_long ? ask : bid;
   const double raw_sl = want_long ? (acc_low - strategy_stop_atr_buffer * atr)
                                   : (acc_high + strategy_stop_atr_buffer * atr);
   const double sl = QM_StopRulesNormalizePrice(_Symbol, raw_sl);
   if(sl <= 0.0)
      return false;
   if(want_long && sl >= entry)
      return false;
   if(!want_long && sl <= entry)
      return false;

   const double stop_distance = MathAbs(entry - sl);
   if(stop_distance <= 0.0 || stop_distance > strategy_max_stop_atr_mult * atr)
      return false;

   const double spread = ask - bid;
   if(strategy_spread_stop_fraction > 0.0 && spread > strategy_spread_stop_fraction * stop_distance)
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = want_long ? "GRIMES_ACCEPT_HIGH_LONG" : "GRIMES_ACCEPT_HIGH_SHORT";

   g_pending_breakout_level = level;
   g_pending_position_type = want_long ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double sl;
   datetime open_time;
   if(!SelectOurPosition(ticket, ptype, open_price, sl, open_time))
      return;

   if(open_price <= 0.0 || sl <= 0.0 || strategy_be_trigger_rr <= 0.0)
      return;

   const bool is_long = (ptype == POSITION_TYPE_BUY);
   const double current_price = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(current_price <= 0.0 || point <= 0.0)
      return;

   const double initial_risk = MathAbs(open_price - sl);
   if(initial_risk <= 0.0)
      return;

   const double moved = is_long ? (current_price - open_price)
                                : (open_price - current_price);
   if(moved < strategy_be_trigger_rr * initial_risk)
      return;

   const bool improves = is_long ? (sl < open_price - point * 0.5)
                                 : (sl > open_price + point * 0.5);
   if(improves)
      QM_TM_MoveSL(ticket, NormalizeDouble(open_price, _Digits), "grimes_accept_high_be_1r");
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double sl;
   datetime open_time;
   if(!SelectOurPosition(ticket, ptype, open_price, sl, open_time))
     {
      g_context_ticket = 0;
      g_context_breakout_level = 0.0;
      return false;
     }

   const int open_shift = iBarShift(_Symbol, PERIOD_H1, open_time, false); // perf-allowed: one H1 age lookup for time exit.
   if(strategy_max_hold_bars > 0 && open_shift >= strategy_max_hold_bars)
      return true;

   if(!RestorePositionContext(ticket, ptype, open_time))
      return false;

   const double c1 = H1Close(1);
   const double c2 = H1Close(2);
   if(c1 <= 0.0 || c2 <= 0.0 || g_context_breakout_level <= 0.0)
      return false;

   if(ptype == POSITION_TYPE_BUY && c1 < g_context_breakout_level && c2 < g_context_breakout_level)
      return true;
   if(ptype == POSITION_TYPE_SELL && c1 > g_context_breakout_level && c2 > g_context_breakout_level)
      return true;

   return false;
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
