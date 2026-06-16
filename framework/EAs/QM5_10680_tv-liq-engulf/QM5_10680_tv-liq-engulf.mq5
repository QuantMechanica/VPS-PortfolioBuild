#property strict
#property version   "5.0"
#property description "QM5_10680 TradingView Liquidity Engulfment Reversal"
// rework v2 2026-06-16 — fix 0-trade contradiction: sweep was required on the SAME
//   bar as the engulf (bar 1 had to make a fresh 20-bar extreme AND engulf the prior
//   bar AND stay <=2 ATR — mutually exclusive). Faithful "liquidity grab then engulf
//   reversal": bar 2 sweeps the liquidity line (extreme of bars 3..lookback+2), bar 1
//   is the engulfing reversal that closes back through it. Decouples the new-extreme
//   excursion (bar 2 wick) from the engulf-bar range (bar 1), so the <=2 ATR filter
//   no longer kills every signal.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10680;
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
input int    strategy_liquidity_lookback          = 20;
input int    strategy_atr_period                  = 14;
input double strategy_stop_buffer_atr             = 0.2;
input double strategy_max_stop_atr_mult           = 2.5;
input double strategy_tp_atr_mult                 = 2.0;
input double strategy_max_engulf_range_atr_mult   = 2.0;
input int    strategy_session_start_hour          = 15;
input int    strategy_session_start_min           = 0;
input int    strategy_session_end_hour            = 19;
input int    strategy_session_end_min             = 0;
input int    strategy_max_hold_bars               = 48;
input bool   strategy_allow_longs                 = true;
input bool   strategy_allow_shorts                = true;
input int    strategy_max_spread_points           = 0;

bool   g_strategy_exit_on_opposite = false;
int    g_strategy_locked_direction = 0;
double g_strategy_locked_line      = 0.0;

int Strategy_ClampMinute(const int hour, const int minute)
  {
   int h = hour;
   int m = minute;
   if(h < 0)
      h = 0;
   if(h > 23)
      h = 23;
   if(m < 0)
      m = 0;
   if(m > 59)
      m = 59;
   return h * 60 + m;
  }

int Strategy_MinuteOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

bool Strategy_MinuteInWindow(const int minute, const int start_minute, const int end_minute)
  {
   if(start_minute == end_minute)
      return true;
   if(start_minute < end_minute)
      return (minute >= start_minute && minute < end_minute);
   return (minute >= start_minute || minute < end_minute);
  }

bool Strategy_IsWithinSession(const datetime t)
  {
   const int start_minute = Strategy_ClampMinute(strategy_session_start_hour,
                                                 strategy_session_start_min);
   const int end_minute = Strategy_ClampMinute(strategy_session_end_hour,
                                               strategy_session_end_min);
   return Strategy_MinuteInWindow(Strategy_MinuteOfDay(t), start_minute, end_minute);
  }

bool Strategy_HasOpenPosition(ENUM_POSITION_TYPE &ptype, datetime &open_time)
  {
   ptype = POSITION_TYPE_BUY;
   open_time = 0;

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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_HasOpenPosition()
  {
   ENUM_POSITION_TYPE ptype;
   datetime open_time = 0;
   return Strategy_HasOpenPosition(ptype, open_time);
  }

bool Strategy_PriorLiquidity(const int lookback, double &upper_line, double &lower_line)
  {
   upper_line = -DBL_MAX;
   lower_line = DBL_MAX;
   if(lookback <= 0)
      return false;

   // Liquidity line is the extreme of the bars BEFORE the sweep bar (bar 2),
   // i.e. shifts 3..lookback+2, so bar 2 can be the bar that sweeps it.
   int samples = 0;
   for(int shift = 3; shift <= lookback + 2; ++shift)
     {
      const double h = iHigh(_Symbol, _Period, shift);
      const double l = iLow(_Symbol, _Period, shift);
      if(h <= 0.0 || l <= 0.0 || h < l)
         return false;
      if(h > upper_line)
         upper_line = h;
      if(l < lower_line)
         lower_line = l;
      samples++;
     }

   return (samples == lookback && upper_line > lower_line && lower_line > 0.0);
  }

bool Strategy_LineMatches(const double a, const double b)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return (MathAbs(a - b) <= 0.0);
   return (MathAbs(a - b) <= point * 0.5);
  }

bool Strategy_DirectionLocked(const int direction, const double line)
  {
   if(g_strategy_locked_direction != direction)
      return false;
   if(Strategy_LineMatches(g_strategy_locked_line, line))
      return true;

   g_strategy_locked_direction = 0;
   g_strategy_locked_line = 0.0;
   return false;
  }

void Strategy_LockDirection(const int direction, const double line)
  {
   g_strategy_locked_direction = direction;
   g_strategy_locked_line = line;
  }

bool Strategy_QualifiedSignal(int &direction,
                              double &liquidity_line,
                              double &signal_low,
                              double &signal_high,
                              double &atr)
  {
   direction = 0;
   liquidity_line = 0.0;
   signal_low = 0.0;
   signal_high = 0.0;
   atr = 0.0;

   if(strategy_liquidity_lookback <= 0 || strategy_atr_period <= 0 ||
      strategy_stop_buffer_atr < 0.0 || strategy_max_stop_atr_mult <= 0.0 ||
      strategy_tp_atr_mult <= 0.0 || strategy_max_engulf_range_atr_mult <= 0.0)
      return false;

   double upper_line = 0.0;
   double lower_line = 0.0;
   if(!Strategy_PriorLiquidity(strategy_liquidity_lookback, upper_line, lower_line))
      return false;

   const double open1 = iOpen(_Symbol, _Period, 1);
   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1 = iLow(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   const double open2 = iOpen(_Symbol, _Period, 2);
   const double high2 = iHigh(_Symbol, _Period, 2);
   const double low2 = iLow(_Symbol, _Period, 2);
   const double close2 = iClose(_Symbol, _Period, 2);
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 ||
      open2 <= 0.0 || high2 <= 0.0 || low2 <= 0.0 || close2 <= 0.0)
      return false;

   atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double signal_range = high1 - low1;
   if(signal_range <= 0.0 || signal_range > strategy_max_engulf_range_atr_mult * atr)
      return false;

   // Bar 2 is the liquidity-grab bar (sweeps the line); bar 1 is the engulfing
   // reversal that closes back through the line. Sweep + engulf are on adjacent
   // bars, not the same bar.
   const bool bullish_engulf = (strategy_allow_longs &&
                                low2 <= lower_line &&
                                close1 > open1 &&
                                close2 < open2 &&
                                open1 <= close2 &&
                                close1 > high2);
   const bool bearish_engulf = (strategy_allow_shorts &&
                                high2 >= upper_line &&
                                close1 < open1 &&
                                close2 > open2 &&
                                open1 >= close2 &&
                                close1 < low2);

   if(bullish_engulf == bearish_engulf)
      return false;

   signal_low = low1;
   signal_high = high1;
   if(bullish_engulf)
     {
      direction = 1;
      liquidity_line = lower_line;
     }
   else
     {
      direction = -1;
      liquidity_line = upper_line;
     }

   return true;
  }

bool Strategy_FillEntryRequest(QM_EntryRequest &req,
                               const int direction,
                               const double liquidity_line,
                               const double signal_low,
                               const double signal_high,
                               const double atr)
  {
   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = (direction > 0) ? "TV_LIQ_ENGULF_LONG" : "TV_LIQ_ENGULF_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const double cap_distance = strategy_max_stop_atr_mult * atr;
   double raw_sl = 0.0;
   if(direction > 0)
     {
      raw_sl = signal_low - strategy_stop_buffer_atr * atr;
      req.sl = MathMax(raw_sl, entry - cap_distance);
     }
   else
     {
      raw_sl = signal_high + strategy_stop_buffer_atr * atr;
      req.sl = MathMin(raw_sl, entry + cap_distance);
     }

   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   req.tp = QM_TakeATRFromValue(_Symbol, req.type, entry, atr, strategy_tp_atr_mult);
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;
   if(direction > 0 && req.sl >= entry)
      return false;
   if(direction < 0 && req.sl <= entry)
      return false;
   if(Strategy_DirectionLocked(direction, liquidity_line))
      return false;

   Strategy_LockDirection(direction, liquidity_line);
   return true;
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const bool have_position = Strategy_HasOpenPosition();

   if(strategy_max_spread_points > 0 && !have_position)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
         return true;
      if((ask - bid) / point > strategy_max_spread_points)
         return true;
     }

   if(!Strategy_IsWithinSession(TimeCurrent()) && !have_position)
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   int direction = 0;
   double liquidity_line = 0.0;
   double signal_low = 0.0;
   double signal_high = 0.0;
   double atr = 0.0;
   if(!Strategy_QualifiedSignal(direction, liquidity_line, signal_low, signal_high, atr))
      return false;

   ENUM_POSITION_TYPE ptype;
   datetime open_time = 0;
   if(Strategy_HasOpenPosition(ptype, open_time))
     {
      if((ptype == POSITION_TYPE_BUY && direction < 0) ||
         (ptype == POSITION_TYPE_SELL && direction > 0))
         g_strategy_exit_on_opposite = true;
      return false;
     }

   if(!Strategy_IsWithinSession(TimeCurrent()))
      return false;

   return Strategy_FillEntryRequest(req, direction, liquidity_line, signal_low, signal_high, atr);
  }

// Called every tick when an open position exists for this EA's magic.
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP only; no trailing, BE, partials, or adds.
  }

// Return TRUE to close the open position now (opposite signal or max hold).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   datetime open_time = 0;
   if(!Strategy_HasOpenPosition(ptype, open_time))
     {
      g_strategy_exit_on_opposite = false;
      return false;
     }

   if(g_strategy_exit_on_opposite)
      return true;

   const int seconds_per_bar = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(strategy_max_hold_bars > 0 && seconds_per_bar > 0 && open_time > 0)
     {
      const int held_seconds = (int)(TimeCurrent() - open_time);
      if(held_seconds >= strategy_max_hold_bars * seconds_per_bar)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework").
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10680_tv_liq_engulf\"}");
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
