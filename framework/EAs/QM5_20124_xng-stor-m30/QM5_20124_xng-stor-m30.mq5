#property strict
#property version   "5.0"
#property description "QM5_20124 EIA XNG storage-release M30 impulse continuation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_20124 - EIA XNG Storage-Release M30 Impulse Continuation
// -----------------------------------------------------------------------------
// Standard Thursdays only:
//   - wait for the 10:30-11:00 New York WNGSR M30 bar to complete
//   - require a directional close beyond the preceding 60-minute range
//   - enter in the completed bar's direction and flatten the same NY session
// The New York date is consumed before fallible history, signal, news, spread,
// ATR, price, or order checks. Runtime uses native MT5 OHLC only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 20124;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
// This EA trades the scheduled storage-release reaction itself. The baseline
// therefore has both generic news axes OFF and no external calendar dependency.
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
input int    strategy_release_hhmm_ny          = 1030;
input int    strategy_entry_hhmm_ny            = 1100;
input int    strategy_pre_release_bars         = 2;
input double strategy_min_release_range_atr    = 0.75;
input double strategy_min_body_ratio           = 0.50;
input int    strategy_atr_period               = 20;
input double strategy_atr_sl_mult              = 2.0;
input int    strategy_entry_grace_minutes      = 15;
input int    strategy_session_flat_hhmm_ny     = 1555;
input int    strategy_max_hold_hours           = 8;
input int    strategy_max_spread_points        = 2500;

bool         g_entry_ready = false;
QM_OrderType g_signal_type = QM_BUY;
int          g_signal_day_key = 0;
double       g_signal_atr = 0.0;
int          g_last_attempt_day_key = 0;
string       g_attempt_state_key = "";

bool Strategy_IsHostChart()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_M30);
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
   return (qm_ea_id == 20124 &&
           qm_magic_slot_offset == 0 &&
           strategy_release_hhmm_ny == 1030 &&
           strategy_entry_hhmm_ny == 1100 &&
           strategy_pre_release_bars == 2 &&
           MathAbs(strategy_min_release_range_atr - 0.75) <= 1.0e-12 &&
           MathAbs(strategy_min_body_ratio - 0.50) <= 1.0e-12 &&
           strategy_atr_period == 20 &&
           MathAbs(strategy_atr_sl_mult - 2.0) <= 1.0e-12 &&
           strategy_entry_grace_minutes == 15 &&
           strategy_session_flat_hhmm_ny == 1555 &&
           strategy_max_hold_hours == 8 &&
           strategy_max_spread_points == 2500 &&
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
      iTime(_Symbol, PERIOD_M30, shift); // perf-allowed: four-bar event check on a genuine new bar.
   if(bar_time <= 0)
      return false;
   return (Strategy_NYDayKey(bar_time) == day_key &&
           Strategy_NYHhmm(bar_time) == hhmm);
  }

void Strategy_AdvanceEventState()
  {
   g_entry_ready = false;
   g_signal_day_key = 0;
   g_signal_atr = 0.0;

   const datetime entry_bar_time =
      iTime(_Symbol, PERIOD_M30, 0); // perf-allowed: new-bar event anchor.
   if(entry_bar_time <= 0 ||
      Strategy_NYDayOfWeek(entry_bar_time) != 4 ||
      Strategy_NYHhmm(entry_bar_time) != strategy_entry_hhmm_ny)
      return;

   const int day_key = Strategy_NYDayKey(entry_bar_time);
   if(day_key <= 0 || day_key == g_last_attempt_day_key)
      return;

   // Consume the standard Thursday before history, signal, news, spread, ATR,
   // price, risk, or order checks. Rejection, stop, restart, or a blocked gate
   // cannot retry this New York date.
   if(!Strategy_RecordAttemptState(day_key))
      return;
   if(Strategy_DayAlreadyEntered(day_key))
      return;

   const long opening_delay = (long)(TimeCurrent() - entry_bar_time);
   if(opening_delay < 0 ||
      opening_delay > (long)strategy_entry_grace_minutes * 60)
      return;

   if(!Strategy_BarMatches(1, day_key, strategy_release_hhmm_ny) ||
      !Strategy_BarMatches(2, day_key, 1000) ||
      !Strategy_BarMatches(3, day_key, 930))
      return;

   const double release_open =
      iOpen(_Symbol, PERIOD_M30, 1); // perf-allowed: bounded event bar on a genuine new bar.
   const double release_high =
      iHigh(_Symbol, PERIOD_M30, 1); // perf-allowed: bounded event bar on a genuine new bar.
   const double release_low =
      iLow(_Symbol, PERIOD_M30, 1); // perf-allowed: bounded event bar on a genuine new bar.
   const double release_close =
      iClose(_Symbol, PERIOD_M30, 1); // perf-allowed: bounded event bar on a genuine new bar.
   const double pre_high_first =
      iHigh(_Symbol, PERIOD_M30, 2); // perf-allowed: fixed two-bar source range on a genuine new bar.
   const double pre_high_second =
      iHigh(_Symbol, PERIOD_M30, 3); // perf-allowed: fixed two-bar source range on a genuine new bar.
   const double pre_low_first =
      iLow(_Symbol, PERIOD_M30, 2); // perf-allowed: fixed two-bar source range on a genuine new bar.
   const double pre_low_second =
      iLow(_Symbol, PERIOD_M30, 3); // perf-allowed: fixed two-bar source range on a genuine new bar.
   const double pre_high = MathMax(pre_high_first, pre_high_second);
   const double pre_low = MathMin(pre_low_first, pre_low_second);

   if(release_open <= 0.0 || release_high <= 0.0 ||
      release_low <= 0.0 || release_close <= 0.0 ||
      pre_high <= 0.0 || pre_low <= 0.0 ||
      !MathIsValidNumber(release_open) ||
      !MathIsValidNumber(release_high) ||
      !MathIsValidNumber(release_low) ||
      !MathIsValidNumber(release_close) ||
      !MathIsValidNumber(pre_high) ||
      !MathIsValidNumber(pre_low) ||
      release_high <= release_low || pre_high <= pre_low)
      return;

   const double atr =
      QM_ATR(_Symbol, PERIOD_M30, strategy_atr_period, 1);
   if(atr <= 0.0 || !MathIsValidNumber(atr))
      return;

   const double release_range = release_high - release_low;
   const double release_body = MathAbs(release_close - release_open);
   if(release_range + 1.0e-12 <
         strategy_min_release_range_atr * atr ||
      release_body / release_range + 1.0e-12 <
         strategy_min_body_ratio)
      return;

   if(release_close > release_open && release_close > pre_high)
      g_signal_type = QM_BUY;
   else if(release_close < release_open && release_close < pre_low)
      g_signal_type = QM_SELL;
   else
      return;

   g_signal_day_key = day_key;
   g_signal_atr = atr;
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
   request.reason = "QM5_20124_XNG_STORAGE_M30";
   request.symbol_slot = qm_magic_slot_offset;
   request.expiration_seconds = 0;

   if(!g_entry_ready ||
      g_signal_day_key <= 0 ||
      g_signal_day_key != g_last_attempt_day_key ||
      g_signal_atr <= 0.0 ||
      !MathIsValidNumber(g_signal_atr) ||
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

   request.sl = QM_StopATRFromValue(_Symbol,
                                    request.type,
                                    entry_price,
                                    g_signal_atr,
                                    strategy_atr_sl_mult);
   request.sl = QM_StopRulesNormalizePrice(_Symbol, request.sl);
   if(request.sl <= 0.0 || !MathIsValidNumber(request.sl))
      return false;
   if(request.type == QM_BUY && request.sl >= entry_price)
      return false;
   if(request.type == QM_SELL && request.sl <= entry_price)
      return false;

   request.reason =
      (request.type == QM_BUY) ?
      "XNG_WNGSR_M30_IMPULSE_LONG" :
      "XNG_WNGSR_M30_IMPULSE_SHORT";
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
      StringFormat("QM5_20124_XNG_STOR_M30_ATTEMPT_%d",
                   QM_FrameworkMagic());
   const datetime reference_time =
      iTime(_Symbol, PERIOD_M30, 0); // perf-allowed: one-time restart-state reference.
   Strategy_LoadAttemptState(
      (reference_time > 0) ? reference_time : TimeCurrent());

   string symbols[1] = {"XNGUSD.DWX"};
   QM_SymbolGuardInit(symbols);
   QM_BasketWarmupHistory(symbols, PERIOD_M30, 64);

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_20124\",\"ea\":\"xng-stor-m30\"}");
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
   g_entry_ready = false;
   if(new_bar)
     {
      QM_EquityStreamOnNewBar();
      // Consume and derive the standard-Thursday state before fallible
      // entry-only news and order gates.
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
