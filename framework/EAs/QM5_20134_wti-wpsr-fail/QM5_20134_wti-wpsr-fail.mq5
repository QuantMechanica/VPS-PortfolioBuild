#property strict
#property version   "5.0"
#property description "QM5_20134 EIA WTI WPSR M30 deep-reclaim failure fade"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_20134 - EIA WTI WPSR M30 Deep-Reclaim Failure Fade
// -----------------------------------------------------------------------------
// Standard Wednesdays only:
//   - require the completed 10:30-11:00 New York WPSR bar to break the
//     completed 09:30-10:30 pre-release range
//   - require the completed 11:00-11:30 bar to reverse through the midpoint
//     and close in the far half of that frozen pre-release range
//   - enter at 11:30 opposite the failed impulse and flatten in the same
//     New York session
// The New York date is consumed before fallible history, signal, news, spread,
// quote, gap, geometry, or order checks. Runtime uses native MT5 data only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 20134;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
// The scheduled WPSR release is the strategy event. Both generic news axes are
// locked OFF for the baseline; the EA has no external calendar dependency.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_release_hhmm_ny            = 1030;
input int    strategy_reclaim_hhmm_ny            = 1100;
input int    strategy_entry_hhmm_ny              = 1130;
input int    strategy_pre_release_bars           = 2;
input int    strategy_atr_period                 = 20;
input double strategy_min_release_range_atr      = 0.75;
input double strategy_min_release_body_ratio     = 0.50;
input double strategy_break_buffer_atr           = 0.05;
input double strategy_deep_reclaim_fraction      = 0.50;
input double strategy_max_entry_gap_atr          = 0.25;
input double strategy_stop_buffer_atr            = 0.10;
input double strategy_min_stop_atr               = 0.25;
input double strategy_max_stop_atr               = 3.00;
input double strategy_min_reward_risk            = 0.75;
input int    strategy_entry_grace_minutes        = 15;
input int    strategy_session_flat_hhmm_ny       = 1555;
input int    strategy_max_hold_hours             = 6;
input int    strategy_max_spread_points          = 1000;

bool         g_entry_ready = false;
QM_OrderType g_signal_type = QM_BUY;
int          g_signal_day_key = 0;
double       g_signal_stop_price = 0.0;
double       g_signal_target_price = 0.0;
double       g_signal_atr = 0.0;
double       g_signal_reference_price = 0.0;
int          g_last_attempt_day_key = 0;
string       g_attempt_state_key = "";

bool Strategy_IsHostChart()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_M30);
  }

datetime Strategy_BrokerToNY(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   return utc - (QM_IsUSDSTUTC(utc) ? 4 * 3600 : 5 * 3600);
  }

int Strategy_Hhmm(const datetime value)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   if(value <= 0 || !TimeToStruct(value, parts))
      return -1;
   return parts.hour * 100 + parts.min;
  }

int Strategy_NYDayKey(const datetime broker_time)
  {
   const datetime ny_time = Strategy_BrokerToNY(broker_time);
   MqlDateTime parts;
   ZeroMemory(parts);
   if(ny_time <= 0 || !TimeToStruct(ny_time, parts))
      return 0;
   if(parts.year <= 0 || parts.mon < 1 || parts.mon > 12 ||
      parts.day < 1 || parts.day > 31)
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

int Strategy_NYDayOfWeek(const datetime broker_time)
  {
   const datetime ny_time = Strategy_BrokerToNY(broker_time);
   MqlDateTime parts;
   ZeroMemory(parts);
   if(ny_time <= 0 || !TimeToStruct(ny_time, parts))
      return -1;
   return parts.day_of_week;
  }

int Strategy_NYHhmm(const datetime broker_time)
  {
   return Strategy_Hhmm(Strategy_BrokerToNY(broker_time));
  }

bool Strategy_IsManagedPosition()
  {
   return (PositionGetString(POSITION_SYMBOL) == _Symbol &&
           (int)PositionGetInteger(POSITION_MAGIC) == QM_FrameworkMagic());
  }

bool Strategy_HasOpenPosition()
  {
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsManagedPosition())
         return true;
     }
   return false;
  }

bool Strategy_DayAlreadyEntered(const int day_key)
  {
   if(day_key <= 0)
      return true;

   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsManagedPosition())
         continue;
      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      if(Strategy_NYDayKey(opened) == day_key)
         return true;
     }

   const datetime now = TimeCurrent();
   const datetime history_start = now - 10 * 86400;
   if(now <= 0 || !HistorySelect(history_start, now))
      return true;

   const int magic = QM_FrameworkMagic();
   const int deal_count = HistoryDealsTotal();
   for(int index = deal_count - 1; index >= 0; --index)
     {
      const ulong deal_ticket = HistoryDealGetTicket(index);
      if(deal_ticket == 0)
         continue;
      if((int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != magic)
         continue;
      if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_time =
         (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      if(Strategy_NYDayKey(deal_time) == day_key)
         return true;
     }
   return false;
  }

void Strategy_LoadAttemptState(const datetime reference_time)
  {
   g_last_attempt_day_key = 0;
   if(g_attempt_state_key == "" ||
      !GlobalVariableCheck(g_attempt_state_key))
      return;

   const int current_day_key = Strategy_NYDayKey(reference_time);
   const double stored = GlobalVariableGet(g_attempt_state_key);
   const int stored_day_key = (int)MathRound(stored);
   if(current_day_key > 0 &&
      MathIsValidNumber(stored) &&
      stored_day_key >= 19000101 &&
      stored_day_key <= current_day_key)
     {
      g_last_attempt_day_key = stored_day_key;
      return;
     }
   GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordAttemptState(const int day_key)
  {
   if(day_key <= 0 || g_attempt_state_key == "")
      return false;
   if(GlobalVariableSet(g_attempt_state_key, (double)day_key) <= 0)
      return false;
   g_last_attempt_day_key = day_key;
   return true;
  }

bool Strategy_InputsValid()
  {
   return (qm_ea_id == 20134 &&
           qm_magic_slot_offset == 0 &&
           strategy_release_hhmm_ny == 1030 &&
           strategy_reclaim_hhmm_ny == 1100 &&
           strategy_entry_hhmm_ny == 1130 &&
           strategy_pre_release_bars == 2 &&
           strategy_atr_period == 20 &&
           MathAbs(strategy_min_release_range_atr - 0.75) <= 1.0e-12 &&
           MathAbs(strategy_min_release_body_ratio - 0.50) <= 1.0e-12 &&
           MathAbs(strategy_break_buffer_atr - 0.05) <= 1.0e-12 &&
           MathAbs(strategy_deep_reclaim_fraction - 0.50) <= 1.0e-12 &&
           MathAbs(strategy_max_entry_gap_atr - 0.25) <= 1.0e-12 &&
           MathAbs(strategy_stop_buffer_atr - 0.10) <= 1.0e-12 &&
           MathAbs(strategy_min_stop_atr - 0.25) <= 1.0e-12 &&
           MathAbs(strategy_max_stop_atr - 3.00) <= 1.0e-12 &&
           MathAbs(strategy_min_reward_risk - 0.75) <= 1.0e-12 &&
           strategy_entry_grace_minutes == 15 &&
           strategy_session_flat_hhmm_ny == 1555 &&
           strategy_max_hold_hours == 6 &&
           strategy_max_spread_points == 1000 &&
           qm_friday_close_enabled &&
           qm_friday_close_hour_broker == 21);
  }

bool Strategy_NoTradeFilter()
  {
   return (!Strategy_IsHostChart() || !Strategy_InputsValid());
  }

bool Strategy_BarMatches(const int shift,
                         const int day_key,
                         const int hhmm)
  {
   const datetime bar_time =
      iTime(_Symbol, PERIOD_M30, shift); // perf-allowed: fixed event-sequence check on one genuine new bar.
   if(bar_time <= 0)
      return false;
   return (Strategy_NYDayKey(bar_time) == day_key &&
           Strategy_NYHhmm(bar_time) == hhmm);
  }

void Strategy_ClearSignal()
  {
   g_entry_ready = false;
   g_signal_day_key = 0;
   g_signal_stop_price = 0.0;
   g_signal_target_price = 0.0;
   g_signal_atr = 0.0;
   g_signal_reference_price = 0.0;
  }

void Strategy_AdvanceEventState()
  {
   Strategy_ClearSignal();

   const datetime entry_bar_time =
      iTime(_Symbol, PERIOD_M30, 0); // perf-allowed: one new-bar event anchor.
   if(entry_bar_time <= 0 ||
      Strategy_NYDayOfWeek(entry_bar_time) != 3 ||
      Strategy_NYHhmm(entry_bar_time) != strategy_entry_hhmm_ny)
      return;

   const int day_key = Strategy_NYDayKey(entry_bar_time);
   if(day_key <= 0 || day_key == g_last_attempt_day_key)
      return;

   // Consume the standard Wednesday before history, signal, news, spread, ATR,
   // quote, gap, geometry, risk, or order checks. Rejection, stop, restart, or
   // a blocked gate cannot retry this New York date.
   if(!Strategy_RecordAttemptState(day_key))
      return;
   if(Strategy_DayAlreadyEntered(day_key))
      return;

   const long opening_delay = (long)(TimeCurrent() - entry_bar_time);
   if(opening_delay < 0 ||
      opening_delay > (long)strategy_entry_grace_minutes * 60)
      return;

   if(!Strategy_BarMatches(1, day_key, strategy_reclaim_hhmm_ny) ||
      !Strategy_BarMatches(2, day_key, strategy_release_hhmm_ny) ||
      !Strategy_BarMatches(3, day_key, 1000) ||
      !Strategy_BarMatches(4, day_key, 930))
      return;

   const double release_open =
      iOpen(_Symbol, PERIOD_M30, 2); // perf-allowed: bounded event bar on one genuine new bar.
   const double release_high =
      iHigh(_Symbol, PERIOD_M30, 2); // perf-allowed: bounded event bar on one genuine new bar.
   const double release_low =
      iLow(_Symbol, PERIOD_M30, 2); // perf-allowed: bounded event bar on one genuine new bar.
   const double release_close =
      iClose(_Symbol, PERIOD_M30, 2); // perf-allowed: bounded event bar on one genuine new bar.
   const double reclaim_open =
      iOpen(_Symbol, PERIOD_M30, 1); // perf-allowed: bounded reclaim bar on one genuine new bar.
   const double reclaim_high =
      iHigh(_Symbol, PERIOD_M30, 1); // perf-allowed: bounded reclaim bar on one genuine new bar.
   const double reclaim_low =
      iLow(_Symbol, PERIOD_M30, 1); // perf-allowed: bounded reclaim bar on one genuine new bar.
   const double reclaim_close =
      iClose(_Symbol, PERIOD_M30, 1); // perf-allowed: bounded reclaim bar on one genuine new bar.
   const double pre_high_first =
      iHigh(_Symbol, PERIOD_M30, 3); // perf-allowed: fixed two-bar source range on one genuine new bar.
   const double pre_high_second =
      iHigh(_Symbol, PERIOD_M30, 4); // perf-allowed: fixed two-bar source range on one genuine new bar.
   const double pre_low_first =
      iLow(_Symbol, PERIOD_M30, 3); // perf-allowed: fixed two-bar source range on one genuine new bar.
   const double pre_low_second =
      iLow(_Symbol, PERIOD_M30, 4); // perf-allowed: fixed two-bar source range on one genuine new bar.
   const double pre_high = MathMax(pre_high_first, pre_high_second);
   const double pre_low = MathMin(pre_low_first, pre_low_second);

   if(release_open <= 0.0 || release_high <= 0.0 ||
      release_low <= 0.0 || release_close <= 0.0 ||
      reclaim_open <= 0.0 || reclaim_high <= 0.0 ||
      reclaim_low <= 0.0 || reclaim_close <= 0.0 ||
      pre_high <= 0.0 || pre_low <= 0.0 ||
      !MathIsValidNumber(release_open) ||
      !MathIsValidNumber(release_high) ||
      !MathIsValidNumber(release_low) ||
      !MathIsValidNumber(release_close) ||
      !MathIsValidNumber(reclaim_open) ||
      !MathIsValidNumber(reclaim_high) ||
      !MathIsValidNumber(reclaim_low) ||
      !MathIsValidNumber(reclaim_close) ||
      !MathIsValidNumber(pre_high) ||
      !MathIsValidNumber(pre_low) ||
      release_high <= release_low ||
      reclaim_high <= reclaim_low ||
      pre_high <= pre_low)
      return;

   const double atr =
      QM_ATR(_Symbol, PERIOD_M30, strategy_atr_period, 2);
   if(atr <= 0.0 || !MathIsValidNumber(atr))
      return;

   const double release_range = release_high - release_low;
   const double release_body = MathAbs(release_close - release_open);
   if(release_range + 1.0e-12 <
         strategy_min_release_range_atr * atr ||
      release_body / release_range + 1.0e-12 <
         strategy_min_release_body_ratio)
      return;

   const double break_buffer = strategy_break_buffer_atr * atr;
   const double pre_midpoint =
      pre_low +
      strategy_deep_reclaim_fraction * (pre_high - pre_low);
   const bool bullish_impulse =
      (release_close > release_open &&
       release_close + 1.0e-12 >= pre_high + break_buffer);
   const bool bearish_impulse =
      (release_close < release_open &&
       release_close - 1.0e-12 <= pre_low - break_buffer);

   if(bullish_impulse)
     {
      if(reclaim_close >= reclaim_open ||
         reclaim_close >= pre_midpoint ||
         reclaim_close <= pre_low)
         return;

      g_signal_type = QM_SELL;
      g_signal_stop_price =
         MathMax(release_high, reclaim_high) +
         strategy_stop_buffer_atr * atr;
      g_signal_target_price = pre_low;
     }
   else if(bearish_impulse)
     {
      if(reclaim_close <= reclaim_open ||
         reclaim_close <= pre_midpoint ||
         reclaim_close >= pre_high)
         return;

      g_signal_type = QM_BUY;
      g_signal_stop_price =
         MathMin(release_low, reclaim_low) -
         strategy_stop_buffer_atr * atr;
      g_signal_target_price = pre_high;
     }
   else
      return;

   if(g_signal_stop_price <= 0.0 ||
      g_signal_target_price <= 0.0 ||
      !MathIsValidNumber(g_signal_stop_price) ||
      !MathIsValidNumber(g_signal_target_price))
      return;

   g_signal_day_key = day_key;
   g_signal_atr = atr;
   g_signal_reference_price = reclaim_close;
   g_entry_ready = true;
  }

void Strategy_CloseExpiredPositions()
  {
   const datetime now = TimeCurrent();
   const int now_day_key = Strategy_NYDayKey(now);
   const int now_hhmm = Strategy_NYHhmm(now);
   const long max_hold_seconds =
      (long)MathMax(1, strategy_max_hold_hours) * 3600;

   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsManagedPosition())
         continue;

      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      const int opened_day_key = Strategy_NYDayKey(opened);
      bool should_close =
         (opened_day_key <= 0 ||
          now_day_key <= 0 ||
          opened_day_key != now_day_key);
      if(opened_day_key == now_day_key &&
         now_hhmm >= strategy_session_flat_hhmm_ny)
         should_close = true;
      if(opened <= 0 || (long)(now - opened) >= max_hold_seconds)
         should_close = true;
      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_EntrySignal(QM_EntryRequest &request)
  {
   request.type = g_signal_type;
   request.price = 0.0;
   request.sl = 0.0;
   request.tp = 0.0;
   request.reason = "QM5_20134_WTI_WPSR_FAIL_M30";
   request.symbol_slot = qm_magic_slot_offset;
   request.expiration_seconds = 0;

   if(!g_entry_ready ||
      g_signal_day_key <= 0 ||
      g_signal_day_key != g_last_attempt_day_key ||
      g_signal_stop_price <= 0.0 ||
      g_signal_target_price <= 0.0 ||
      g_signal_atr <= 0.0 ||
      g_signal_reference_price <= 0.0 ||
      !MathIsValidNumber(g_signal_stop_price) ||
      !MathIsValidNumber(g_signal_target_price) ||
      !MathIsValidNumber(g_signal_atr) ||
      !MathIsValidNumber(g_signal_reference_price) ||
      Strategy_HasOpenPosition())
      return false;

   const long spread_points =
      SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_points < 0 ||
      spread_points > strategy_max_spread_points)
      return false;

   const double entry_price = QM_EntryMarketPrice(request.type);
   if(entry_price <= 0.0 || !MathIsValidNumber(entry_price))
      return false;
   if(MathAbs(entry_price - g_signal_reference_price) - 1.0e-12 >
      strategy_max_entry_gap_atr * g_signal_atr)
      return false;

   request.sl =
      QM_StopRulesNormalizePrice(_Symbol, g_signal_stop_price);
   request.tp =
      QM_StopRulesNormalizePrice(_Symbol, g_signal_target_price);
   if(request.sl <= 0.0 || request.tp <= 0.0 ||
      !MathIsValidNumber(request.sl) ||
      !MathIsValidNumber(request.tp))
      return false;
   if(request.type == QM_BUY &&
      (request.sl >= entry_price || request.tp <= entry_price))
      return false;
   if(request.type == QM_SELL &&
      (request.sl <= entry_price || request.tp >= entry_price))
      return false;

   const double risk_distance = MathAbs(entry_price - request.sl);
   const double reward_distance = MathAbs(request.tp - entry_price);
   if(risk_distance <= 0.0 ||
      reward_distance <= 0.0 ||
      !MathIsValidNumber(risk_distance) ||
      !MathIsValidNumber(reward_distance) ||
      risk_distance + 1.0e-12 <
         strategy_min_stop_atr * g_signal_atr ||
      risk_distance - 1.0e-12 >
         strategy_max_stop_atr * g_signal_atr ||
      reward_distance / risk_distance + 1.0e-12 <
         strategy_min_reward_risk)
      return false;

   request.reason =
      (request.type == QM_BUY) ?
      "WTI_WPSR_M30_DEEP_RECLAIM_LONG" :
      "WTI_WPSR_M30_DEEP_RECLAIM_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseExpiredPositions();
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(!Strategy_IsHostChart() || !Strategy_InputsValid())
      return INIT_PARAMETERS_INCORRECT;

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

   g_attempt_state_key =
      StringFormat("QM5_20134_WTI_WPSR_FAIL_ATTEMPT_%d",
                   QM_FrameworkMagic());
   const datetime reference_time =
      iTime(_Symbol, PERIOD_M30, 0); // perf-allowed: one-time restart-state reference.
   Strategy_LoadAttemptState(
      (reference_time > 0) ? reference_time : TimeCurrent());

   string symbols[1] = {"XTIUSD.DWX"};
   QM_SymbolGuardInit(symbols);
   QM_BasketWarmupHistory(symbols, PERIOD_M30, 64);

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_20134\",\"ea\":\"wti-wpsr-fail\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO,
               "DEINIT",
               StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   const bool new_bar = QM_IsNewBar();
   Strategy_ClearSignal();
   if(new_bar)
     {
      QM_EquityStreamOnNewBar();
      // Consume and derive the completed impulse/reclaim state before
      // fallible entry-only news and order gates.
      Strategy_AdvanceEventState();
     }

   // Lifecycle exits always precede entry-only news checks.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
      return;
   if(!new_bar || !g_entry_ready)
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows =
         QM_NewsAllowsTrade2(_Symbol,
                             broker_now,
                             qm_news_temporal,
                             qm_news_compliance);
   else
      news_allows =
         QM_NewsAllowsTrade(_Symbol,
                            broker_now,
                            qm_news_mode_legacy);
   if(!news_allows)
      return;

   QM_EntryRequest request;
   ZeroMemory(request);
   if(Strategy_EntrySignal(request))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(request, out_ticket);
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
