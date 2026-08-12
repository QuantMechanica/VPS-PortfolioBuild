#property strict
#property version   "5.0"
#property description "QM5_20054 XNG One-Month Unconditional Contrarian"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_20054 - XNG One-Month Unconditional Contrarian State
// -----------------------------------------------------------------------------
// Mishra-Smyth source carrier:
//   - fixed broker-calendar monthly periods
//   - latest completed month-end close versus the close one month earlier
//   - long after a one-month fall and short after a one-month rise
//   - exact equality retains the prior state; non-equality renews the package
//   - frozen ATR hard stop is the only signal-adjacent V5 risk addition
// Runtime is MT5-native: D1 OHLC, ATR, spread, calendar, deals and positions.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 20054;
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
input int    strategy_holding_months           = 1;
input int    strategy_history_bars             = 120;
input int    strategy_rebalance_month_parity   = 0;
input int    strategy_atr_period               = 20;
input double strategy_atr_sl_mult              = 4.0;
input int    strategy_max_hold_days            = 40;
input int    strategy_max_spread_points        = 3000;

int g_last_attempt_period_key = 0;

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
   return parts.year * 100 + parts.mon;
  }

int Strategy_PeriodKeyForTime(const datetime value)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   if(value <= 0 || !TimeToStruct(value, parts))
      return 0;
   return parts.year * 100 + parts.mon;
  }

int Strategy_CurrentPeriodKey()
  {
   const int month_key =
      QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   if(month_key <= 0)
      return 0;
   const int year = month_key / 100;
   const int month = month_key % 100;
   if(month < 1 || month > 12)
      return 0;
   return year * 100 + month;
  }

bool Strategy_IsMonthlyRebalanceBar()
  {
   const int current_month =
      QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const int previous_month =
      QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1);
   if(current_month <= 0 || previous_month <= 0 ||
      current_month == previous_month)
      return false;

   const int month_number = current_month % 100;
   return (month_number >= 1 && month_number <= 12 &&
           month_number % strategy_holding_months ==
              strategy_rebalance_month_parity);
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

bool Strategy_PeriodAlreadyEntered(const int period_key,
                                   const int decision_month_key)
  {
   if(period_key <= 0 || decision_month_key <= 0)
      return true;

   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsManagedPosition())
         continue;
      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      if(Strategy_PeriodKeyForTime(opened) == period_key)
         return true;
     }

   MqlDateTime start_parts;
   ZeroMemory(start_parts);
   start_parts.year = decision_month_key / 100;
   start_parts.mon = decision_month_key % 100;
   start_parts.day = 1;
   const datetime period_start = StructToTime(start_parts);
   if(period_start <= 0 || !HistorySelect(period_start, TimeCurrent()))
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
      if(Strategy_PeriodKeyForTime(deal_time) == period_key)
         return true;
     }
   return false;
  }

bool Strategy_LoadContrarianState(double &latest_close,
                                  double &one_month_close,
                                  int &target_state)
  {
   latest_close = 0.0;
   one_month_close = 0.0;
   target_state = 0;

   const int needed_closes = strategy_holding_months + 1;
   if(needed_closes != 2)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int requested = MathMax(strategy_history_bars, 90);
   const int copied =
      CopyRates(_Symbol, PERIOD_D1, 1, requested, rates); // perf-allowed: bounded month-end reconstruction once per D1 bar.
   if(copied <= 0)
      return false;

   double month_closes[];
   ArrayResize(month_closes, needed_closes);
   int close_count = 0;
   int previous_key = 0;

   for(int index = 0; index < copied && close_count < needed_closes; ++index)
     {
      const int month_key =
         QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, index + 1);
      const double close_value = rates[index].close;
      if(month_key <= 0 || close_value <= 0.0 ||
         !MathIsValidNumber(close_value))
         continue;
      if(month_key == previous_key)
         continue;
      month_closes[close_count] = close_value;
      ++close_count;
      previous_key = month_key;
     }

   if(close_count < needed_closes)
      return false;

   latest_close = month_closes[0];
   one_month_close = month_closes[1];
   if(latest_close <= 0.0 || one_month_close <= 0.0 ||
      !MathIsValidNumber(latest_close) ||
      !MathIsValidNumber(one_month_close))
      return false;

   if(latest_close < one_month_close)
      target_state = 1;
   else if(latest_close > one_month_close)
      target_state = -1;
   else
      target_state = 0;

   return true;
  }

void Strategy_CloseExpiredPositions()
  {
   const bool is_boundary = Strategy_IsMonthlyRebalanceBar();
   const int current_period = Strategy_CurrentPeriodKey();
   bool state_valid = false;
   int target_state = 0;
   if(is_boundary)
     {
      double latest_close = 0.0;
      double one_month_close = 0.0;
      state_valid = Strategy_LoadContrarianState(latest_close,
                                                 one_month_close,
                                                 target_state);
     }

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
      const int opened_period = Strategy_PeriodKeyForTime(opened);
      bool should_close = false;

      // At a valid exact-equality boundary the source carries the old state.
      // Invalid history fails closed by ending the expired package; otherwise
      // every non-equality decision renews the fixed one-month package.
      if(is_boundary && current_period > 0 &&
         opened_period != current_period &&
         (!state_valid || target_state != 0))
         should_close = true;
      if(opened <= 0 || (long)(now - opened) >= hold_seconds)
         should_close = true;

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXngD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_holding_months != 1)
      return true;
   if(strategy_history_bars != 120)
      return true;
   if(strategy_rebalance_month_parity != 0)
      return true;
   if(strategy_atr_period != 20)
      return true;
   if(strategy_atr_sl_mult != 4.0)
      return true;
   if(strategy_max_hold_days != 40)
      return true;
   if(strategy_max_spread_points != 3000)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_20054_XNG_1M_CONTR";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_IsMonthlyRebalanceBar())
      return false;

   const int decision_month =
      QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const int period_key = Strategy_CurrentPeriodKey();
   if(decision_month <= 0 || period_key <= 0 ||
      period_key == g_last_attempt_period_key)
      return false;
   g_last_attempt_period_key = period_key;

   if(Strategy_HasOpenPosition() ||
      Strategy_PeriodAlreadyEntered(period_key, decision_month))
      return false;

   const long spread_points =
      SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_points < 0 ||
      (strategy_max_spread_points > 0 &&
       spread_points > strategy_max_spread_points))
      return false;

   double latest_close = 0.0;
   double one_month_close = 0.0;
   int target_state = 0;
   if(!Strategy_LoadContrarianState(latest_close,
                                    one_month_close,
                                    target_state))
      return false;
   if(target_state == 0)
      return false;

   const double atr_last =
      QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_last <= 0.0 || !MathIsValidNumber(atr_last))
      return false;

   req.type = (target_state > 0) ? QM_BUY : QM_SELL;
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

   req.reason = (target_state > 0) ?
      "XNG_1M_CONTR_LONG" : "XNG_1M_CONTR_SHORT";
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

   if(!QM_FrameworkDeclareExecutionContract(
         PERIOD_D1,
         QM_FRIDAY_CLOSE_DISABLED,
         "Source rule requires an uninterrupted fixed one-month holding period"))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"QM5_20054\",\"ea\":\"xng-1m-contr\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT",
               StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;
   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   // Fixed-period and stale exits run before entry-news gating so an expired
   // package cannot be held merely because a new entry is temporarily blocked.
   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      for(int index = PositionsTotal() - 1; index >= 0; --index)
        {
         const ulong ticket = PositionGetTicket(index);
         if(ticket == 0 || !PositionSelectByTicket(ticket) ||
            !Strategy_IsManagedPosition())
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

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
