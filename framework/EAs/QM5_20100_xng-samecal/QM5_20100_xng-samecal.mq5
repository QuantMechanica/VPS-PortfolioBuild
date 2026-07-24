#property strict
#property version   "5.0"
#property description "QM5_20100 XNG same-calendar-month seasonal sign"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_20100 - XNG Same-Calendar-Month Seasonal Sign
// -----------------------------------------------------------------------------
// At each broker-month boundary, average XNG's completed return for the same
// calendar month across prior years. Trade the sign for one month:
//   positive historical average -> BUY XNGUSD.DWX
//   negative historical average -> SELL XNGUSD.DWX
// The current month is excluded, at least five samples are required, and a
// consumed month is never retried after restart, rejection, stop, or news block.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 20100;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = false;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_history_years       = 10;
input int    strategy_min_history_years   = 5;
input int    strategy_history_bars        = 3000;
input int    strategy_atr_period          = 20;
input double strategy_atr_sl_mult         = 4.0;
input int    strategy_max_hold_days       = 35;
input int    strategy_max_spread_points   = 2500;

bool   g_monthly_boundary = false;
bool   g_signal_valid = false;
int    g_signal_direction = 0;
int    g_signal_month_key = 0;
int    g_signal_sample_count = 0;
double g_signal_score = 0.0;
int    g_last_attempt_month_key = 0;
string g_attempt_state_key = "";

bool Strategy_IsXngD1()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_MonthKeyForTime(const datetime value)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   if(value <= 0 || !TimeToStruct(value, parts))
      return 0;
   if(parts.year <= 0 || parts.mon < 1 || parts.mon > 12)
      return 0;
   return parts.year * 100 + parts.mon;
  }

bool Strategy_IsMonthlyBoundaryBar()
  {
   const int current_month =
      QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const int previous_month =
      QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1);
   if(current_month <= 0 || previous_month <= 0)
      return false;
   return current_month != previous_month;
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

bool Strategy_MonthAlreadyEntered(const int month_key)
  {
   if(month_key <= 0)
      return true;

   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsManagedPosition())
         continue;
      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      if(Strategy_MonthKeyForTime(opened) == month_key)
         return true;
     }

   MqlDateTime start_parts;
   ZeroMemory(start_parts);
   start_parts.year = month_key / 100;
   start_parts.mon = month_key % 100;
   start_parts.day = 1;
   const datetime month_start = StructToTime(start_parts);
   if(month_start <= 0 || !HistorySelect(month_start, TimeCurrent()))
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
      if(Strategy_MonthKeyForTime(deal_time) == month_key)
         return true;
     }
   return false;
  }

void Strategy_LoadAttemptState(const datetime reference_time)
  {
   g_last_attempt_month_key = 0;
   if(g_attempt_state_key == "" ||
      !GlobalVariableCheck(g_attempt_state_key))
      return;

   const int current_month_key =
      Strategy_MonthKeyForTime(reference_time);
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
   GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordMonthAttempt(const int month_key)
  {
   if(month_key <= 0 || g_attempt_state_key == "")
      return false;
   if(GlobalVariableSet(g_attempt_state_key, (double)month_key) <= 0)
      return false;
   g_last_attempt_month_key = month_key;
   return true;
  }

void Strategy_PreviousMonth(const int year,
                            const int month,
                            int &previous_year,
                            int &previous_month)
  {
   previous_year = year;
   previous_month = month - 1;
   if(previous_month < 1)
     {
      previous_month = 12;
      previous_year--;
     }
  }

bool Strategy_MonthEndClose(const MqlRates &rates[],
                            const int count,
                            const int target_year,
                            const int target_month,
                            double &month_end_close)
  {
   month_end_close = 0.0;
   for(int index = 0; index < count; ++index)
     {
      MqlDateTime parts;
      ZeroMemory(parts);
      if(!TimeToStruct(rates[index].time, parts))
         continue;
      if(parts.year != target_year || parts.mon != target_month)
         continue;
      month_end_close = rates[index].close;
      return (month_end_close > 0.0 &&
              MathIsValidNumber(month_end_close));
     }
   return false;
  }

bool Strategy_MonthReturn(const MqlRates &rates[],
                          const int count,
                          const int year,
                          const int month,
                          double &month_return)
  {
   month_return = 0.0;
   int previous_year = 0;
   int previous_month = 0;
   Strategy_PreviousMonth(year,
                          month,
                          previous_year,
                          previous_month);

   double month_close = 0.0;
   double previous_close = 0.0;
   if(!Strategy_MonthEndClose(rates,
                              count,
                              year,
                              month,
                              month_close))
      return false;
   if(!Strategy_MonthEndClose(rates,
                              count,
                              previous_year,
                              previous_month,
                              previous_close))
      return false;
   if(month_close <= 0.0 || previous_close <= 0.0)
      return false;

   month_return = MathLog(month_close / previous_close);
   return MathIsValidNumber(month_return);
  }

bool Strategy_LoadSeasonalSignal(const datetime decision_bar_time,
                                 double &seasonal_score,
                                 int &sample_count,
                                 int &direction)
  {
   seasonal_score = 0.0;
   sample_count = 0;
   direction = 0;

   MqlDateTime decision_parts;
   ZeroMemory(decision_parts);
   if(decision_bar_time <= 0 ||
      !TimeToStruct(decision_bar_time, decision_parts))
      return false;
   if(decision_parts.year <= 0 ||
      decision_parts.mon < 1 ||
      decision_parts.mon > 12)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied =
      CopyRates(_Symbol, PERIOD_D1, 1, strategy_history_bars, rates); // perf-allowed: bounded same-calendar return window, called only on the monthly boundary.
   if(copied <= 0)
      return false;

   double return_sum = 0.0;
   for(int offset = 1;
       offset <= strategy_history_years;
       ++offset)
     {
      const int sample_year = decision_parts.year - offset;
      double sample_return = 0.0;
      if(!Strategy_MonthReturn(rates,
                               copied,
                               sample_year,
                               decision_parts.mon,
                               sample_return))
         continue;
      return_sum += sample_return;
      sample_count++;
     }

   if(sample_count < strategy_min_history_years)
      return false;

   seasonal_score = return_sum / (double)sample_count;
   if(!MathIsValidNumber(seasonal_score))
      return false;
   if(seasonal_score > 1.0e-12)
      direction = 1;
   else if(seasonal_score < -1.0e-12)
      direction = -1;
   return true;
  }

void Strategy_AdvanceMonthlyState()
  {
   g_monthly_boundary = false;
   g_signal_valid = false;
   g_signal_direction = 0;
   g_signal_month_key = 0;
   g_signal_sample_count = 0;
   g_signal_score = 0.0;

   if(!Strategy_IsMonthlyBoundaryBar())
      return;

   const int month_key =
      QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   MqlRates decision_bar;
   ZeroMemory(decision_bar);
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 0, decision_bar))
      return;
   const datetime decision_bar_time = decision_bar.time;
   if(month_key <= 0 || decision_bar_time <= 0)
      return;

   g_monthly_boundary = true;
   g_signal_month_key = month_key;

   if(month_key == g_last_attempt_month_key ||
      Strategy_MonthAlreadyEntered(month_key))
      return;

   // Consume the month before history, news, spread, ATR, price, or order
   // checks. A restart or fallible gate can never create a later retry.
   if(!Strategy_RecordMonthAttempt(month_key))
      return;

   g_signal_valid =
      Strategy_LoadSeasonalSignal(decision_bar_time,
                                  g_signal_score,
                                  g_signal_sample_count,
                                  g_signal_direction);
  }

void Strategy_CloseExpiredPositions()
  {
   const int current_month_key =
      QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
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
      const int opened_month_key =
         Strategy_MonthKeyForTime(opened);
      bool should_close =
         (current_month_key > 0 &&
          opened_month_key != current_month_key);
      if(opened <= 0 ||
         (long)(now - opened) >= hold_seconds)
         should_close = true;

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_InputsValid()
  {
   return (qm_ea_id == 20100 &&
           qm_magic_slot_offset == 0 &&
           strategy_history_years == 10 &&
           strategy_min_history_years == 5 &&
           strategy_history_bars == 3000 &&
           strategy_atr_period == 20 &&
           MathAbs(strategy_atr_sl_mult - 4.0) <= 1.0e-12 &&
           strategy_max_hold_days == 35 &&
           strategy_max_spread_points == 2500 &&
           !qm_friday_close_enabled &&
           qm_friday_close_hour_broker == 21);
  }

bool Strategy_NoTradeFilter()
  {
   return (!Strategy_IsXngD1() || !Strategy_InputsValid());
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_20100_XNG_SAMECAL";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_monthly_boundary ||
      g_signal_month_key <= 0 ||
      g_signal_month_key != g_last_attempt_month_key ||
      !g_signal_valid ||
      g_signal_direction == 0 ||
      Strategy_HasOpenPosition())
      return false;

   const long spread_points =
      SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_points < 0 ||
      spread_points > strategy_max_spread_points)
      return false;

   const double atr_last =
      QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_last <= 0.0 || !MathIsValidNumber(atr_last))
      return false;

   req.type = (g_signal_direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0 || !MathIsValidNumber(entry_price))
      return false;

   req.sl = QM_StopATRFromValue(_Symbol,
                                req.type,
                                entry_price,
                                atr_last,
                                strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0 || !MathIsValidNumber(req.sl))
      return false;
   if(req.type == QM_BUY && req.sl >= entry_price)
      return false;
   if(req.type == QM_SELL && req.sl <= entry_price)
      return false;

   req.reason =
      (g_signal_direction > 0) ?
      "XNG_SAMECAL_LONG" :
      "XNG_SAMECAL_SHORT";
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
   if(!Strategy_IsXngD1() || !Strategy_InputsValid())
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
      StringFormat("QM5_20100_MONTH_ATTEMPT_%d",
                   QM_FrameworkMagic());
   Strategy_LoadAttemptState(TimeCurrent());

   string symbols[1] = {"XNGUSD.DWX"};
   QM_SymbolGuardInit(symbols);
   QM_BasketWarmupHistory(symbols,
                          PERIOD_D1,
                          strategy_history_bars);

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_20100\",\"ea\":\"xng-samecal\"}");
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
   g_monthly_boundary = false;
   if(new_bar)
     {
      QM_EquityStreamOnNewBar();
      Strategy_AdvanceMonthlyState();
     }

   // Monthly and stale exits always precede entry news and spread gates.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
      return;

   if(!new_bar || !g_monthly_boundary)
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

   QM_EntryRequest req;
   ZeroMemory(req);
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
