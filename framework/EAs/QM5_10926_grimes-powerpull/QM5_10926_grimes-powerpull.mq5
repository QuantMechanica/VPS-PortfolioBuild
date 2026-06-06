#property strict
#property version   "5.0"
#property description "QM5_10926 Grimes PowerPull Level Magnet"
// Strategy Card: QM5_10926 (grimes-powerpull), G0 APPROVED 2026-05-22.
// Source: Adam H. Grimes, "How to Trade Support and Resistance Levels", 2020-10-16.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10926;
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
input int    strategy_atr_period             = 20;
input int    strategy_ema_period             = 20;
input double strategy_target_distance_atr    = 1.25;
input int    strategy_momentum_window_bars   = 4;
input int    strategy_momentum_min_count     = 3;
input double strategy_stop_atr_mult          = 1.20;
input double strategy_min_target_r           = 0.80;
input int    strategy_prior_touch_bars       = 6;
input int    strategy_daily_lookback_days    = 20;
input int    strategy_pivot_left_bars        = 3;
input int    strategy_pivot_right_bars       = 3;
input int    strategy_pivot_scan_bars        = 96;
input double strategy_trail_trigger_r        = 0.75;
input int    strategy_trail_lookback_bars    = 3;
input int    strategy_time_exit_bars         = 8;
input double strategy_away_atr_mult          = 0.80;
input double strategy_spread_stop_frac       = 0.08;

ulong  g_active_ticket          = 0;
int    g_position_direction     = 0;
double g_entry_price            = 0.0;
double g_initial_risk           = 0.0;
double g_target_level           = 0.0;
double g_best_favorable_close   = 0.0;
double g_last_closed_close      = 0.0;
double g_cached_long_trail_sl   = 0.0;
double g_cached_short_trail_sl  = 0.0;
int    g_bars_in_trade          = 0;
bool   g_close_away_exit        = false;

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
   return iClose(_Symbol, tf, shift); // perf-allowed: O(1) closed-bar read, no warmup scan or raw indicator handle.
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

void ResetTradeState()
  {
   g_active_ticket = 0;
   g_position_direction = 0;
   g_entry_price = 0.0;
   g_initial_risk = 0.0;
   g_target_level = 0.0;
   g_best_favorable_close = 0.0;
   g_last_closed_close = 0.0;
   g_cached_long_trail_sl = 0.0;
   g_cached_short_trail_sl = 0.0;
   g_bars_in_trade = 0;
   g_close_away_exit = false;
  }

void TrackPositionIfNeeded(const ulong ticket, const ENUM_POSITION_TYPE ptype)
  {
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return;

   if(g_active_ticket == ticket)
      return;

   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double sl = PositionGetDouble(POSITION_SL);
   const double tp = PositionGetDouble(POSITION_TP);
   if(open_price <= 0.0 || sl <= 0.0)
      return;

   g_active_ticket = ticket;
   g_position_direction = (ptype == POSITION_TYPE_BUY) ? +1 : -1;
   g_entry_price = open_price;
   g_initial_risk = MathAbs(open_price - sl);
   g_target_level = tp;
   g_best_favorable_close = open_price;
   g_last_closed_close = open_price;
   g_cached_long_trail_sl = 0.0;
   g_cached_short_trail_sl = 0.0;
   g_bars_in_trade = 0;
   g_close_away_exit = false;
  }

bool HasOurPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   return SelectOurPosition(ticket, ptype);
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

bool DailyExtremes(double &highest_high, double &lowest_low)
  {
   highest_high = -DBL_MAX;
   lowest_low = DBL_MAX;
   for(int shift = 1; shift <= strategy_daily_lookback_days; ++shift)
     {
      const double h = BarHigh(PERIOD_D1, shift);
      const double l = BarLow(PERIOD_D1, shift);
      if(h <= 0.0 || l <= 0.0)
         return false;
      if(h > highest_high)
         highest_high = h;
      if(l < lowest_low)
         lowest_low = l;
     }
   return (highest_high > 0.0 && lowest_low < DBL_MAX);
  }

int MomentumTowardCount(const int direction)
  {
   int count = 0;
   for(int s = 1; s <= strategy_momentum_window_bars; ++s)
     {
      const double newer = BarClose(PERIOD_H1, s);
      const double older = BarClose(PERIOD_H1, s + 1);
      if(newer <= 0.0 || older <= 0.0)
         return 0;
      if(direction > 0 && newer > older)
         count++;
      if(direction < 0 && newer < older)
         count++;
     }
   return count;
  }

bool EmaFilterAllows(const int direction, const double close_price)
  {
   const double ema1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period, 1);
   const double ema2 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period, 2);
   if(ema1 <= 0.0 || ema2 <= 0.0 || close_price <= 0.0)
      return false;
   if(direction > 0)
      return (close_price > ema1 && ema1 > ema2);
   return (close_price < ema1 && ema1 < ema2);
  }

bool LevelTouchedRecently(const double level, const int direction)
  {
   if(level <= 0.0)
      return true;
   for(int shift = 1; shift <= strategy_prior_touch_bars; ++shift)
     {
      if(direction > 0)
        {
         const double h = BarHigh(PERIOD_H1, shift);
         if(h <= 0.0 || h >= level)
            return true;
        }
      else
        {
         const double l = BarLow(PERIOD_H1, shift);
         if(l <= 0.0 || l <= level)
            return true;
        }
     }
   return false;
  }

bool ConsiderTarget(const double level,
                    const int direction,
                    const double close_price,
                    const double entry_price,
                    const double atr,
                    double &best_level)
  {
   if(level <= 0.0 || close_price <= 0.0 || entry_price <= 0.0 || atr <= 0.0)
      return false;

   const double stop_distance = strategy_stop_atr_mult * atr;
   const double min_target_distance = strategy_min_target_r * stop_distance;

   if(direction > 0)
     {
      if(level <= close_price)
         return false;
      const double close_distance = level - close_price;
      const double entry_distance = level - entry_price;
      if(close_distance > strategy_target_distance_atr * atr)
         return false;
      if(entry_distance < min_target_distance)
         return false;
      if(LevelTouchedRecently(level, direction))
         return false;
      if(best_level <= 0.0 || level < best_level)
         best_level = level;
      return true;
     }

   if(level >= close_price)
      return false;
   const double close_distance = close_price - level;
   const double entry_distance = entry_price - level;
   if(close_distance > strategy_target_distance_atr * atr)
      return false;
   if(entry_distance < min_target_distance)
      return false;
   if(LevelTouchedRecently(level, direction))
      return false;
   if(best_level <= 0.0 || level > best_level)
      best_level = level;
   return true;
  }

void AdvanceOpenTradeOnClosedBar()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   if(!SelectOurPosition(ticket, ptype))
     {
      ResetTradeState();
      return;
     }

   TrackPositionIfNeeded(ticket, ptype);
   if(g_active_ticket != ticket || g_initial_risk <= 0.0)
      return;

   const int direction = (ptype == POSITION_TYPE_BUY) ? +1 : -1;
   const double c1 = BarClose(PERIOD_H1, 1);
   if(c1 > 0.0)
     {
      g_last_closed_close = c1;
      if(direction > 0)
         g_best_favorable_close = MathMax(g_best_favorable_close, c1);
      else
         g_best_favorable_close = MathMin(g_best_favorable_close, c1);
     }

   double trail_long = DBL_MAX;
   double trail_short = -DBL_MAX;
   for(int shift = 1; shift <= strategy_trail_lookback_bars; ++shift)
     {
      const double l = BarLow(PERIOD_H1, shift);
      const double h = BarHigh(PERIOD_H1, shift);
      if(l <= 0.0 || h <= 0.0)
        {
         trail_long = 0.0;
         trail_short = 0.0;
         break;
        }
      if(l < trail_long)
         trail_long = l;
      if(h > trail_short)
         trail_short = h;
     }
   g_cached_long_trail_sl = (trail_long > 0.0 && trail_long < DBL_MAX) ? NormalizeDouble(trail_long, _Digits) : 0.0;
   g_cached_short_trail_sl = (trail_short > 0.0) ? NormalizeDouble(trail_short, _Digits) : 0.0;

   g_bars_in_trade++;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr > 0.0 && g_best_favorable_close > 0.0 && c1 > 0.0)
     {
      if(direction > 0 && c1 < g_best_favorable_close - strategy_away_atr_mult * atr)
         g_close_away_exit = true;
      if(direction < 0 && c1 > g_best_favorable_close + strategy_away_atr_mult * atr)
         g_close_away_exit = true;
     }
  }

// No Trade Filter (time, spread, news). Framework handles news and Friday close;
// the card's spread cap depends on the computed stop and is enforced at entry.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry. Caller guarantees QM_IsNewBar()==true. This hook also advances
// closed-bar state for any open PowerPull position so per-tick hooks stay O(1).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   AdvanceOpenTradeOnClosedBar();
   if(HasOurPosition())
      return false;

   if(strategy_atr_period < 1 || strategy_ema_period < 1 ||
      strategy_momentum_window_bars < 1 || strategy_momentum_min_count < 1 ||
      strategy_stop_atr_mult <= 0.0 || strategy_target_distance_atr <= 0.0 ||
      strategy_daily_lookback_days < 2 || strategy_pivot_scan_bars < strategy_pivot_left_bars + strategy_pivot_right_bars + 1)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double c1 = BarClose(PERIOD_H1, 1);
   if(atr <= 0.0 || c1 <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;
   const double spread = ask - bid;
   const double stop_distance = strategy_stop_atr_mult * atr;
   if(stop_distance <= 0.0 || spread > strategy_spread_stop_frac * stop_distance)
      return false;

   double d20_high = 0.0;
   double d20_low = 0.0;
   if(!DailyExtremes(d20_high, d20_low))
      return false;

   const double prev_d1_high = BarHigh(PERIOD_D1, 1);
   const double prev_d1_low = BarLow(PERIOD_D1, 1);
   if(prev_d1_high <= 0.0 || prev_d1_low <= 0.0)
      return false;

   double pivot_high = 0.0;
   double pivot_low = 0.0;
   MostRecentSwingHigh(pivot_high);
   MostRecentSwingLow(pivot_low);

   double long_target = 0.0;
   ConsiderTarget(prev_d1_high, +1, c1, ask, atr, long_target);
   ConsiderTarget(d20_high, +1, c1, ask, atr, long_target);
   ConsiderTarget(pivot_high, +1, c1, ask, atr, long_target);

   if(long_target > 0.0 &&
      MomentumTowardCount(+1) >= strategy_momentum_min_count &&
      EmaFilterAllows(+1, c1))
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(ask - stop_distance, _Digits);
      req.tp = NormalizeDouble(long_target, _Digits);
      req.reason = "grimes_powerpull_long";
      req.symbol_slot = qm_magic_slot_offset;
      return true;
     }

   double short_target = 0.0;
   ConsiderTarget(prev_d1_low, -1, c1, bid, atr, short_target);
   ConsiderTarget(d20_low, -1, c1, bid, atr, short_target);
   ConsiderTarget(pivot_low, -1, c1, bid, atr, short_target);

   if(short_target > 0.0 &&
      MomentumTowardCount(-1) >= strategy_momentum_min_count &&
      EmaFilterAllows(-1, c1))
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(bid + stop_distance, _Digits);
      req.tp = NormalizeDouble(short_target, _Digits);
      req.reason = "grimes_powerpull_short";
      req.symbol_slot = qm_magic_slot_offset;
      return true;
     }

   return false;
  }

// Trade Management. Trail after +0.75R using the cached prior-3-bar extreme.
void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   if(!SelectOurPosition(ticket, ptype))
     {
      ResetTradeState();
      return;
     }

   TrackPositionIfNeeded(ticket, ptype);
   if(g_initial_risk <= 0.0)
      return;

   const bool is_long = (ptype == POSITION_TYPE_BUY);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bid <= 0.0 || ask <= 0.0 || point <= 0.0 || !PositionSelectByTicket(ticket))
      return;

   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double current_tp = PositionGetDouble(POSITION_TP);
   const double exit_price = is_long ? bid : ask;
   const double favorable = is_long ? (exit_price - open_price) : (open_price - exit_price);
   if(favorable < strategy_trail_trigger_r * g_initial_risk)
      return;

   if(current_tp > 0.0)
     {
      if(is_long && exit_price >= current_tp)
         return;
      if(!is_long && exit_price <= current_tp)
         return;
     }

   const double trail_sl = is_long ? g_cached_long_trail_sl : g_cached_short_trail_sl;
   if(trail_sl <= 0.0)
      return;

   const bool valid = is_long ? (trail_sl < bid) : (trail_sl > ask);
   const bool improves = (current_sl <= 0.0) ||
                         (is_long ? (trail_sl > current_sl + point * 0.5)
                                  : (trail_sl < current_sl - point * 0.5));
   if(valid && improves)
      QM_TM_MoveSL(ticket, trail_sl, "powerpull_prior3_trail");
  }

// Trade Close. Time exit after 8 H1 bars or closed-bar away-from-target reversal.
bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   if(!SelectOurPosition(ticket, ptype))
     {
      ResetTradeState();
      return false;
     }

   TrackPositionIfNeeded(ticket, ptype);
   if(g_close_away_exit)
      return true;
   return (g_bars_in_trade >= strategy_time_exit_bars);
  }

// News Filter Hook (callable for P8/Q09 News Impact). Defer to the framework
// two-axis news filter; this card has no bespoke news logic.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10926_grimes-powerpull\"}");
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
