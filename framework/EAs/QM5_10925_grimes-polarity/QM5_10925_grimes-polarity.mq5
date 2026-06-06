#property strict
#property version   "5.0"
#property description "QM5_10925 Grimes Polarity Retest"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10925;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period             = 20;
input int    strategy_pivot_left_bars        = 3;
input int    strategy_pivot_right_bars       = 3;
input int    strategy_pivot_scan_bars        = 96;
input double strategy_breakout_atr_mult      = 0.25;
input int    strategy_retest_window_bars     = 12;
input double strategy_retest_atr_mult        = 0.15;
input double strategy_stop_buffer_atr_mult   = 0.25;
input double strategy_min_stop_atr_mult      = 0.50;
input double strategy_max_stop_atr_mult      = 3.00;
input double strategy_target_r_mult          = 1.80;
input double strategy_breakeven_trigger_r    = 1.00;
input int    strategy_time_exit_bars         = 18;
input int    strategy_ema_period             = 20;
input double strategy_spread_stop_frac       = 0.10;

ulong    g_polarity_ticket       = 0;
int      g_polarity_direction    = 0;
double   g_polarity_level        = 0.0;
double   g_polarity_initial_risk = 0.0;
datetime g_polarity_entry_time   = 0;

double BarHigh(const ENUM_TIMEFRAMES tf, const int shift)
  {
   return iHigh(_Symbol, tf, shift); // perf-allowed: bounded structural level read, called from framework-gated strategy code.
  }

double BarLow(const ENUM_TIMEFRAMES tf, const int shift)
  {
   return iLow(_Symbol, tf, shift); // perf-allowed: bounded structural level read, called from framework-gated strategy code.
  }

double BarClose(const ENUM_TIMEFRAMES tf, const int shift)
  {
   return iClose(_Symbol, tf, shift); // perf-allowed: O(1) closed-bar polarity read; no warmup scan or handle allocation.
  }

bool SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = candidate;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

bool HasOurPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   return SelectOurPosition(ticket, ptype);
  }

void ResetPolarityState()
  {
   g_polarity_ticket = 0;
   g_polarity_direction = 0;
   g_polarity_level = 0.0;
   g_polarity_initial_risk = 0.0;
   g_polarity_entry_time = 0;
  }

void TrackPositionIfNeeded(const ulong ticket, const ENUM_POSITION_TYPE ptype)
  {
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return;

   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double sl = PositionGetDouble(POSITION_SL);
   if(open_price <= 0.0 || sl <= 0.0)
      return;

   if(g_polarity_ticket != ticket)
     {
      g_polarity_ticket = ticket;
      g_polarity_direction = (ptype == POSITION_TYPE_BUY) ? +1 : -1;
      g_polarity_initial_risk = MathAbs(open_price - sl);
      g_polarity_entry_time = (datetime)PositionGetInteger(POSITION_TIME);
     }
  }

bool IsConfirmedSwingHigh(const int shift)
  {
   const double pivot = BarHigh(PERIOD_H1, shift);
   if(pivot <= 0.0)
      return false;

   for(int k = 1; k <= strategy_pivot_left_bars; ++k)
     {
      const double h = BarHigh(PERIOD_H1, shift + k);
      if(h <= 0.0 || h >= pivot)
         return false;
     }
   for(int k = 1; k <= strategy_pivot_right_bars; ++k)
     {
      const double h = BarHigh(PERIOD_H1, shift - k);
      if(h <= 0.0 || h >= pivot)
         return false;
     }

   return true;
  }

bool IsConfirmedSwingLow(const int shift)
  {
   const double pivot = BarLow(PERIOD_H1, shift);
   if(pivot <= 0.0)
      return false;

   for(int k = 1; k <= strategy_pivot_left_bars; ++k)
     {
      const double l = BarLow(PERIOD_H1, shift + k);
      if(l <= 0.0 || l <= pivot)
         return false;
     }
   for(int k = 1; k <= strategy_pivot_right_bars; ++k)
     {
      const double l = BarLow(PERIOD_H1, shift - k);
      if(l <= 0.0 || l <= pivot)
         return false;
     }

   return true;
  }

bool MostRecentSwingHigh(double &level)
  {
   level = 0.0;
   const int first_shift = strategy_pivot_right_bars + 1;
   for(int shift = first_shift; shift <= strategy_pivot_scan_bars; ++shift)
     {
      if(IsConfirmedSwingHigh(shift))
        {
         level = BarHigh(PERIOD_H1, shift);
         return (level > 0.0);
        }
     }
   return false;
  }

bool MostRecentSwingLow(double &level)
  {
   level = 0.0;
   const int first_shift = strategy_pivot_right_bars + 1;
   for(int shift = first_shift; shift <= strategy_pivot_scan_bars; ++shift)
     {
      if(IsConfirmedSwingLow(shift))
        {
         level = BarLow(PERIOD_H1, shift);
         return (level > 0.0);
        }
     }
   return false;
  }

bool EmaSlopeAllows(const int direction)
  {
   const double ema_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period, 1);
   const double ema_2 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period, 2);
   if(ema_1 <= 0.0 || ema_2 <= 0.0)
      return false;
   if(direction > 0)
      return (ema_1 > ema_2);
   return (ema_1 < ema_2);
  }

bool SpreadWithinStopCap(const double stop_distance)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid || stop_distance <= 0.0)
      return false;
   return ((ask - bid) <= strategy_spread_stop_frac * stop_distance);
  }

void ClearEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool HasBreakoutWithinWindow(const double level, const int direction)
  {
   for(int shift = 2; shift <= strategy_retest_window_bars + 1; ++shift)
     {
      const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, shift);
      const double close_break = BarClose(PERIOD_H1, shift);
      const double close_before = BarClose(PERIOD_H1, shift + 1);
      if(atr <= 0.0 || close_break <= 0.0 || close_before <= 0.0)
         continue;

      if(direction > 0)
        {
         if(close_before <= level && close_break >= level + strategy_breakout_atr_mult * atr)
            return true;
        }
      else
        {
         if(close_before >= level && close_break <= level - strategy_breakout_atr_mult * atr)
            return true;
        }
     }
   return false;
  }

bool TryBuildLong(const double level, QM_EntryRequest &req)
  {
   if(level <= 0.0 || !EmaSlopeAllows(+1) || !HasBreakoutWithinWindow(level, +1))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double retest_low = BarLow(PERIOD_H1, 1);
   const double retest_close = BarClose(PERIOD_H1, 1);
   if(atr <= 0.0 || retest_low <= 0.0 || retest_close <= 0.0)
      return false;
   if(retest_low > level + strategy_retest_atr_mult * atr)
      return false;
   if(retest_close <= level)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double sl = QM_StopRulesNormalizePrice(_Symbol, retest_low - strategy_stop_buffer_atr_mult * atr);
   if(entry <= 0.0 || sl <= 0.0 || sl >= entry)
      return false;

   const double stop_distance = entry - sl;
   if(stop_distance < strategy_min_stop_atr_mult * atr ||
      stop_distance > strategy_max_stop_atr_mult * atr ||
      !SpreadWithinStopCap(stop_distance))
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = QM_StopRulesNormalizePrice(_Symbol, entry + strategy_target_r_mult * stop_distance);
   req.reason = "polarity_long";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_polarity_level = level;
   g_polarity_direction = +1;
   g_polarity_initial_risk = stop_distance;
   return (req.tp > entry);
  }

bool TryBuildShort(const double level, QM_EntryRequest &req)
  {
   if(level <= 0.0 || !EmaSlopeAllows(-1) || !HasBreakoutWithinWindow(level, -1))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double retest_high = BarHigh(PERIOD_H1, 1);
   const double retest_close = BarClose(PERIOD_H1, 1);
   if(atr <= 0.0 || retest_high <= 0.0 || retest_close <= 0.0)
      return false;
   if(retest_high < level - strategy_retest_atr_mult * atr)
      return false;
   if(retest_close >= level)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double sl = QM_StopRulesNormalizePrice(_Symbol, retest_high + strategy_stop_buffer_atr_mult * atr);
   if(entry <= 0.0 || sl <= 0.0 || sl <= entry)
      return false;

   const double stop_distance = sl - entry;
   if(stop_distance < strategy_min_stop_atr_mult * atr ||
      stop_distance > strategy_max_stop_atr_mult * atr ||
      !SpreadWithinStopCap(stop_distance))
      return false;

   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = QM_StopRulesNormalizePrice(_Symbol, entry - strategy_target_r_mult * stop_distance);
   req.reason = "polarity_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_polarity_level = level;
   g_polarity_direction = -1;
   g_polarity_initial_risk = stop_distance;
   return (req.tp > 0.0 && req.tp < entry);
  }

// No Trade Filter (time, spread, news). Framework handles news and Friday close;
// setup-specific spread is checked after the stop distance is known.
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_H1)
      return true;
   if(strategy_atr_period <= 0 ||
      strategy_pivot_left_bars <= 0 ||
      strategy_pivot_right_bars <= 0 ||
      strategy_pivot_scan_bars < strategy_pivot_left_bars + strategy_pivot_right_bars + 2 ||
      strategy_breakout_atr_mult <= 0.0 ||
      strategy_retest_window_bars <= 0 ||
      strategy_retest_atr_mult < 0.0 ||
      strategy_stop_buffer_atr_mult <= 0.0 ||
      strategy_min_stop_atr_mult <= 0.0 ||
      strategy_max_stop_atr_mult <= strategy_min_stop_atr_mult ||
      strategy_target_r_mult <= 0.0 ||
      strategy_breakeven_trigger_r <= 0.0 ||
      strategy_time_exit_bars <= 0 ||
      strategy_ema_period <= 1 ||
      strategy_spread_stop_frac <= 0.0)
      return true;

   return false;
  }

// Trade Entry: H1 close confirms a breakout of prior D1/swing support or
// resistance, then the latest closed H1 bar retests that level from the new side.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ClearEntryRequest(req);

   if(HasOurPosition())
      return false;
   ResetPolarityState();

   const double d1_high = BarHigh(PERIOD_D1, 1);
   const double d1_low = BarLow(PERIOD_D1, 1);
   double swing_high = 0.0;
   double swing_low = 0.0;
   MostRecentSwingHigh(swing_high);
   MostRecentSwingLow(swing_low);

   double resistance_levels[2];
   resistance_levels[0] = d1_high;
   resistance_levels[1] = swing_high;
   for(int i = 0; i < 2; ++i)
     {
      if(TryBuildLong(resistance_levels[i], req))
         return true;
     }

   double support_levels[2];
   support_levels[0] = d1_low;
   support_levels[1] = swing_low;
   for(int i = 0; i < 2; ++i)
     {
      if(TryBuildShort(support_levels[i], req))
         return true;
     }

   return false;
  }

// Trade Management: move stop to breakeven at 1R.
void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   if(!SelectOurPosition(ticket, ptype))
     {
      ResetPolarityState();
      return;
     }

   TrackPositionIfNeeded(ticket, ptype);
   if(g_polarity_initial_risk <= 0.0 || !PositionSelectByTicket(ticket))
      return;

   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const bool is_long = (ptype == POSITION_TYPE_BUY);
   const double market_price = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                       : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(open_price <= 0.0 || market_price <= 0.0)
      return;

   const double moved = is_long ? (market_price - open_price) : (open_price - market_price);
   if(moved < strategy_breakeven_trigger_r * g_polarity_initial_risk)
      return;

   const bool improves = (current_sl <= 0.0) ||
                         (is_long ? (open_price > current_sl) : (open_price < current_sl));
   if(improves)
      QM_TM_MoveSL(ticket, open_price, "polarity_breakeven_1R");
  }

// Trade Close: time exit after 18 H1 bars, or closed-bar failure back through
// the polarity level by 0.25 ATR against the position.
bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   if(!SelectOurPosition(ticket, ptype))
      return false;

   TrackPositionIfNeeded(ticket, ptype);
   if(PositionSelectByTicket(ticket))
     {
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int h1_seconds = PeriodSeconds(PERIOD_H1);
      if(h1_seconds > 0 && TimeCurrent() - open_time >= strategy_time_exit_bars * h1_seconds)
         return true;
     }

   if(g_polarity_level <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double close_1 = BarClose(PERIOD_H1, 1);
   if(atr <= 0.0 || close_1 <= 0.0)
      return false;

   if(ptype == POSITION_TYPE_BUY)
      return (close_1 <= g_polarity_level - strategy_breakout_atr_mult * atr);
   return (close_1 >= g_polarity_level + strategy_breakout_atr_mult * atr);
  }

// News Filter Hook: no card-specific override; central framework news axes apply.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10925\",\"ea\":\"grimes-polarity\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
