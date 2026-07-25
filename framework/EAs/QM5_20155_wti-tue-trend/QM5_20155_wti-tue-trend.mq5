#property strict
#property version   "5.0"
#property description "QM5_20155 WTI Tuesday Weakness Negative-Trend Agreement"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_20155 - WTI Tuesday Weakness / Slow-Trend Agreement
// -----------------------------------------------------------------------------
// D1 structural crude-oil sleeve:
//   - first observed tick of a genuine broker-calendar Tuesday D1 bar
//   - SELL only when the completed 252-D1 WTI log return is negative
//   - one consumed attempt per broker week, persisted before fallible gates
//   - next-D1 flatten, frozen ATR stop, and two-day stale repair
// Runtime uses MT5-native OHLC/calendar/history only; no external data or ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 20155;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = true;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_momentum_lookback_d1 = 252;
input double strategy_min_abs_return_pct   = 0.0;
input int    strategy_entry_grace_minutes  = 5;
input int    strategy_atr_period           = 20;
input double strategy_atr_sl_mult          = 3.0;
input int    strategy_max_hold_days        = 2;
input int    strategy_max_spread_points    = 1500;

int    g_last_attempt_week_key = 0;
string g_attempt_state_key     = "";

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

bool Strategy_IsWtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_WeekKey(const datetime value)
  {
   if(value <= 0)
      return 0;

   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts))
      return 0;

   const int days_since_monday =
      (parts.day_of_week + 6) % 7;
   parts.hour = 12;
   parts.min = 0;
   parts.sec = 0;
   const datetime monday_noon =
      (datetime)(StructToTime(parts) -
                 (long)days_since_monday * 86400);
   if(monday_noon <= 0)
      return 0;

   MqlDateTime monday;
   ZeroMemory(monday);
   if(!TimeToStruct(monday_noon, monday))
      return 0;
   return monday.year * 1000 + monday.day_of_year;
  }

bool Strategy_IsTuesdayBar(const datetime value)
  {
   if(value <= 0)
      return false;
   MqlDateTime parts;
   ZeroMemory(parts);
   return (TimeToStruct(value, parts) &&
           parts.day_of_week == 2);
  }

bool Strategy_IsMondayBar(const datetime value)
  {
   if(value <= 0)
      return false;
   MqlDateTime parts;
   ZeroMemory(parts);
   return (TimeToStruct(value, parts) &&
           parts.day_of_week == 1);
  }

bool Strategy_IsGenuineTuesdayBoundary(const datetime current_bar)
  {
   if(!Strategy_IsTuesdayBar(current_bar))
      return false;
   const datetime prior_bar =
      iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: prior completed D1 calendar gate.
   return Strategy_IsMondayBar(prior_bar);
  }

bool Strategy_EntryWithinGrace(const datetime current_bar)
  {
   if(current_bar <= 0)
      return false;
   const datetime now = TimeCurrent();
   if(now < current_bar)
      return false;
   const long elapsed_seconds =
      (long)(now - current_bar);
   return elapsed_seconds <=
          (long)strategy_entry_grace_minutes * 60;
  }

bool Strategy_IsManagedPosition()
  {
   return (PositionGetString(POSITION_SYMBOL) == _Symbol &&
           (int)PositionGetInteger(POSITION_MAGIC) ==
              QM_FrameworkMagic());
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

bool Strategy_WeekAlreadyEntered(const int week_key,
                                 const datetime current_bar)
  {
   if(week_key <= 0 || current_bar <= 0)
      return true;

   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsManagedPosition())
         continue;
      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      if(Strategy_WeekKey(opened) == week_key)
         return true;
     }

   const datetime history_start =
      current_bar - (long)14 * 86400;
   if(history_start <= 0 ||
      !HistorySelect(history_start, TimeCurrent()))
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
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket,
                                                DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN &&
         entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_time =
         (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      if(Strategy_WeekKey(deal_time) == week_key)
         return true;
     }
   return false;
  }

void Strategy_LoadAttemptState(const datetime reference_time)
  {
   g_last_attempt_week_key = 0;
   if(g_attempt_state_key == "" ||
      !GlobalVariableCheck(g_attempt_state_key))
      return;

   const int current_week_key =
      Strategy_WeekKey(reference_time);
   const double stored =
      GlobalVariableGet(g_attempt_state_key);
   const int stored_week_key =
      (int)MathRound(stored);
   if(current_week_key > 0 &&
      MathIsValidNumber(stored) &&
      stored_week_key >= 1900000 &&
      stored_week_key <= current_week_key)
     {
      g_last_attempt_week_key = stored_week_key;
      return;
     }

   // Tester globals can outlive a later historical run. A future marker must
   // not suppress the beginning of a deterministic rerun.
   GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordWeekAttempt(const int week_key)
  {
   if(week_key <= 0 || g_attempt_state_key == "")
      return false;
   if(GlobalVariableSet(g_attempt_state_key,
                        (double)week_key) <= 0)
      return false;
   g_last_attempt_week_key = week_key;
   return true;
  }

bool Strategy_LoadMomentum(double &momentum,
                           int &direction)
  {
   momentum = 0.0;
   direction = 0;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int required =
      strategy_momentum_lookback_d1 + 1;
   const int copied =
      CopyClose(_Symbol, // perf-allowed: bounded Tuesday D1 momentum sample.
                PERIOD_D1,
                1,
                required,
                closes);
   if(copied < required)
      return false;

   const double close_recent = closes[0];
   const double close_past =
      closes[strategy_momentum_lookback_d1];
   if(close_recent <= 0.0 || close_past <= 0.0 ||
      !MathIsValidNumber(close_recent) ||
      !MathIsValidNumber(close_past))
      return false;

   momentum = MathLog(close_recent / close_past);
   if(!MathIsValidNumber(momentum))
      return false;

   const double threshold =
      MathMax(0.0, strategy_min_abs_return_pct) / 100.0;
   if(momentum > threshold)
      direction = 1;
   else if(momentum < -threshold)
      direction = -1;
   return true;
  }

void Strategy_CloseExpiredPositions()
  {
   const datetime current_bar =
      iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: Tuesday D1 lifecycle gate.
   if(current_bar <= 0)
      return;

   const bool current_bar_is_monday =
      Strategy_IsTuesdayBar(current_bar);
   const datetime now = TimeCurrent();
   const long hold_seconds =
      (long)MathMax(1, strategy_max_hold_days) * 86400;

   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsManagedPosition())
         continue;

      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      const long position_type =
         PositionGetInteger(POSITION_TYPE);
      bool should_close =
         !current_bar_is_monday ||
         position_type != POSITION_TYPE_SELL;
      if(opened <= 0 ||
         (long)(now - opened) >= hold_seconds)
         should_close = true;

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsWtiD1())
      return true;
   if(qm_ea_id != 20155 ||
      qm_magic_slot_offset != 0)
      return true;
   if(strategy_momentum_lookback_d1 != 252 ||
      MathAbs(strategy_min_abs_return_pct) > 1.0e-12)
      return true;
   if(strategy_entry_grace_minutes != 5 ||
      strategy_atr_period != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.0) > 1.0e-12)
      return true;
   if(strategy_max_hold_days != 2 ||
      strategy_max_spread_points != 1500)
      return true;
   if(!qm_friday_close_enabled ||
      qm_friday_close_hour_broker != 21)
      return true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE ||
      qm_news_mode_legacy != QM_NEWS_OFF)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "WTI_TUE_TREND";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime current_bar =
      iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: Tuesday D1 entry calendar.
   if(!Strategy_IsGenuineTuesdayBoundary(current_bar) ||
      !Strategy_EntryWithinGrace(current_bar))
      return false;

   const int week_key =
      Strategy_WeekKey(current_bar);
   if(week_key <= 0 ||
      week_key == g_last_attempt_week_key)
      return false;

   // Consume before history, trend, spread, quote, news, stop, or order gates.
   if(!Strategy_RecordWeekAttempt(week_key))
      return false;

   if(Strategy_HasOpenPosition() ||
      Strategy_WeekAlreadyEntered(week_key, current_bar))
      return false;

   double momentum = 0.0;
   int direction = 0;
   if(!Strategy_LoadMomentum(momentum, direction) ||
      direction != -1)
      return false;

   const long spread_points =
      SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_points < 0 ||
      spread_points > strategy_max_spread_points)
      return false;

   const double atr_last =
      QM_ATR(_Symbol,
             PERIOD_D1,
             strategy_atr_period,
             1);
   if(atr_last <= 0.0 ||
      !MathIsValidNumber(atr_last))
      return false;

   const double entry_price =
      QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0 ||
      !MathIsValidNumber(entry_price))
      return false;

   req.sl = QM_StopATRFromValue(_Symbol,
                                req.type,
                                entry_price,
                                atr_last,
                                strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= entry_price ||
      !MathIsValidNumber(req.sl))
      return false;

   req.reason = "WTI_TUE_NEG252_SHORT";
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

// -----------------------------------------------------------------------------
// Framework wiring — canonical V5 lifecycle.
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

   g_attempt_state_key =
      StringFormat("QM5_20155_WEEK_ATTEMPT_%d",
                   QM_FrameworkMagic());
   Strategy_LoadAttemptState(TimeCurrent());

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_20155\",\"ea\":\"wti-tue-trend\"}");
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

   if(!Strategy_IsWtiD1())
      return;
   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   // Lifecycle exits precede all entry-only gates.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int index = PositionsTotal() - 1; index >= 0; --index)
        {
         const ulong ticket = PositionGetTicket(index);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(Strategy_NoTradeFilter())
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
   if(!Strategy_EntrySignal(req))
      return;

   // EntrySignal deliberately consumes the week before this entry-only news
   // check. The baseline locks both axes OFF, but ordering stays restart-safe.
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol,
                                        broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol,
                                       broker_now,
                                       qm_news_mode_legacy);
   if(!news_allows)
      return;

   ulong out_ticket = 0;
   QM_TM_OpenPosition(req, out_ticket);
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
