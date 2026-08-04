#property strict
#property version   "5.0"
#property description "QM5_20214 WTI Summer-Regime / One-Month Reversal"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_20214 - WTI Summer-Regime / One-Month Reversal
// -----------------------------------------------------------------------------
// D1 structural crude-oil sleeve:
//   - first tradable D1 bar of each broker-calendar month
//   - active only June through October; forced flat November through May
//   - exact just-completed calendar-month WTI log return
//   - SELL positive / BUY negative, held until the next month boundary
//   - one consumed attempt per active month, persisted before fallible gates
//   - fixed-risk ATR stop and forty-day stale guard; Friday close disabled
// Runtime uses MT5-native OHLC/calendar/history only; no external data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 20214;
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
input bool   qm_friday_close_enabled       = false;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_first_active_month    = 6;
input int    strategy_last_active_month     = 10;
input int    strategy_history_bars          = 80;
input int    strategy_atr_period            = 20;
input double strategy_atr_sl_mult           = 3.5;
input int    strategy_max_hold_days         = 40;
input int    strategy_max_spread_points     = 1500;

int    g_last_attempt_month_key = 0;
string g_attempt_state_key      = "";

// -----------------------------------------------------------------------------
// Strategy hooks - implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

bool Strategy_IsWtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_MonthKey(const datetime value)
  {
   if(value <= 0)
      return 0;

   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts))
      return 0;
   return parts.year * 100 + parts.mon;
  }

int Strategy_NextMonthKey(const int month_key)
  {
   int year = month_key / 100;
   int month = month_key % 100;
   if(year < 1900 || month < 1 || month > 12)
      return 0;
   ++month;
   if(month > 12)
     {
      month = 1;
      ++year;
     }
   return year * 100 + month;
  }

bool Strategy_IsActiveMonth(const int month_number)
  {
   if(month_number < 1 || month_number > 12)
      return false;
   if(strategy_first_active_month <= strategy_last_active_month)
      return (month_number >= strategy_first_active_month &&
              month_number <= strategy_last_active_month);
   return (month_number >= strategy_first_active_month ||
           month_number <= strategy_last_active_month);
  }

bool Strategy_IsMonthlyBoundaryBar()
  {
   const int current_month_key =
      QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const int prior_month_key =
      QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1);
   if(current_month_key <= 0 || prior_month_key <= 0)
      return false;
   return current_month_key != prior_month_key;
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

bool Strategy_MonthAlreadyEntered(const int month_key,
                                  const datetime current_bar)
  {
   if(month_key <= 0 || current_bar <= 0)
      return true;

   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsManagedPosition())
         continue;
      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      if(Strategy_MonthKey(opened) == month_key)
         return true;
     }

   const datetime history_start =
      current_bar - (long)45 * 86400;
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
      if(Strategy_MonthKey(deal_time) == month_key)
         return true;
     }
   return false;
  }

void Strategy_LoadAttemptState()
  {
   g_last_attempt_month_key = 0;
   if(g_attempt_state_key == "" ||
      !GlobalVariableCheck(g_attempt_state_key))
      return;

   const int current_month_key =
      QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const double stored = GlobalVariableGet(g_attempt_state_key);
   const int stored_month_key = (int)MathRound(stored);
   if(current_month_key > 0 &&
      MathIsValidNumber(stored) &&
      stored_month_key >= 190001 &&
      stored_month_key <= current_month_key)
     {
      g_last_attempt_month_key = stored_month_key;
      return;
     }

   // Tester globals can outlive a later historical run. A future marker must
   // not suppress the beginning of a deterministic rerun.
   GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordMonthAttempt(const int month_key)
  {
   if(month_key <= 0 || g_attempt_state_key == "")
      return false;
   if(GlobalVariableSet(g_attempt_state_key,
                        (double)month_key) <= 0)
      return false;
   g_last_attempt_month_key = month_key;
   return true;
  }

bool Strategy_LoadCompletedMonthSignal(const int current_month_key,
                                       double &prior_return,
                                       int &trade_direction)
  {
   prior_return = 0.0;
   trade_direction = 0;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied =
      CopyRates(_Symbol, // perf-allowed: bounded monthly D1 endpoint sample.
                PERIOD_D1,
                1,
                strategy_history_bars,
                bars);
   if(copied < 2)
      return false;

   int month_keys[2] = {0, 0};
   double month_closes[2] = {0.0, 0.0};
   int found = 0;
   int last_key = 0;
   for(int index = 0; index < copied && found < 2; ++index)
     {
      const int month_key = Strategy_MonthKey(bars[index].time);
      if(month_key <= 0 || month_key == last_key)
         continue;
      if(bars[index].close <= 0.0 ||
         !MathIsValidNumber(bars[index].close))
         return false;
      month_keys[found] = month_key;
      month_closes[found] = bars[index].close;
      last_key = month_key;
      ++found;
     }

   if(found != 2 ||
      Strategy_NextMonthKey(month_keys[0]) != current_month_key ||
      Strategy_NextMonthKey(month_keys[1]) != month_keys[0])
      return false;

   prior_return = MathLog(month_closes[0] / month_closes[1]);
   if(!MathIsValidNumber(prior_return))
      return false;

   // Reversal is load-bearing: trade opposite the completed month.
   if(prior_return > 0.0)
      trade_direction = -1;
   else if(prior_return < 0.0)
      trade_direction = 1;
   return true;
  }

void Strategy_CloseExpiredPositions()
  {
   MqlRates current_d1;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 0, current_d1))
      return;
   const int current_month_key = Strategy_MonthKey(current_d1.time);
   const int current_month_number = current_month_key % 100;
   const bool in_active_season =
      Strategy_IsActiveMonth(current_month_number);
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
      const int opened_month_key = Strategy_MonthKey(opened);
      bool should_close = !in_active_season;
      if(current_month_key > 0 &&
         opened_month_key != current_month_key)
         should_close = true;
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
   if(qm_ea_id != 20214 ||
      qm_magic_slot_offset != 0)
      return true;
   if(strategy_first_active_month != 6 ||
      strategy_last_active_month != 10)
      return true;
   if(strategy_history_bars != 80 ||
      strategy_atr_period != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.5) > 1.0e-12)
      return true;
   if(strategy_max_hold_days != 40 ||
      strategy_max_spread_points != 1500)
      return true;
   if(qm_friday_close_enabled ||
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
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "WTI_SUM_REV1";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_IsMonthlyBoundaryBar())
      return false;

   MqlRates current_d1;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 0, current_d1))
      return false;
   const datetime current_bar = current_d1.time;
   const int month_key = Strategy_MonthKey(current_bar);
   const int month_number = month_key % 100;
   if(month_key <= 0 ||
      !Strategy_IsActiveMonth(month_number) ||
      month_key == g_last_attempt_month_key)
      return false;

   // Consume before history, signal, spread, quote, news, stop, or order gates.
   if(!Strategy_RecordMonthAttempt(month_key))
      return false;

   if(Strategy_HasOpenPosition() ||
      Strategy_MonthAlreadyEntered(month_key, current_bar))
      return false;

   double prior_return = 0.0;
   int trade_direction = 0;
   if(!Strategy_LoadCompletedMonthSignal(month_key,
                                         prior_return,
                                         trade_direction) ||
      trade_direction == 0)
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

   req.type = (trade_direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0 ||
      !MathIsValidNumber(entry_price))
      return false;

   req.sl = QM_StopATRFromValue(_Symbol,
                                req.type,
                                entry_price,
                                atr_last,
                                strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0 ||
      !MathIsValidNumber(req.sl))
      return false;
   if((req.type == QM_BUY && req.sl >= entry_price) ||
      (req.type == QM_SELL && req.sl <= entry_price))
      return false;

   req.reason = (trade_direction > 0)
      ? "WTI_SUM_REV1_LONG"
      : "WTI_SUM_REV1_SHORT";
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
// Framework wiring.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!Strategy_IsWtiD1() ||
      qm_ea_id != 20214 ||
      qm_magic_slot_offset != 0)
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

   if(Strategy_NoTradeFilter())
     {
      QM_FrameworkShutdown();
      return INIT_PARAMETERS_INCORRECT;
     }

   g_attempt_state_key =
      StringFormat("QM5_20214_MONTH_ATTEMPT_%d",
                   QM_FrameworkMagic());
   Strategy_LoadAttemptState();

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_20214\",\"ea\":\"wti-sum-rev1\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   // Q08 evidence lifecycle: sample floating P&L before per-tick guards.
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
            PositionGetString(POSITION_SYMBOL) != _Symbol)
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

   // EntrySignal deliberately consumes the month before this entry-only news
   // check. Both axes are locked OFF, but ordering stays restart-safe.
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
