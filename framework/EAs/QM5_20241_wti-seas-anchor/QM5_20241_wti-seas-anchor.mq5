#property strict
#property version   "5.0"
#property description "QM5_20241 WTI Seasonal 52-Week Anchor"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_20241 - WTI Seasonal 52-Week Anchor
// -----------------------------------------------------------------------------
// D1 structural crude-oil sleeve:
//   - one consumed attempt on the first tradable D1 bar of each broker month
//   - November-May long state; June-October short state
//   - completed 252-D1 closing-extreme location
//   - exact completed 63-D1 log-return confirmation
//   - trade only when season, anchor, and confirmation agree
//   - fixed-risk ATR stop and forty-day stale guard; Friday close disabled
// Runtime uses MT5-native OHLC/calendar/history only; no external data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                       = 20241;
input int    qm_magic_slot_offset           = 0;
input uint   qm_rng_seed                    = 42;

input group "Risk"
input double RISK_PERCENT                   = 0.0;
input double RISK_FIXED                     = 1000.0;
input double PORTFOLIO_WEIGHT               = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours        = 336;
input string qm_news_min_impact             = "high";
input QM_NewsMode qm_news_mode_legacy       = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled        = false;
input int    qm_friday_close_hour_broker    = 21;

input group "Stress"
input double qm_stress_reject_probability   = 0.0;

input group "Strategy"
input int    strategy_winter_first_month    = 11;
input int    strategy_winter_last_month     = 5;
input int    strategy_anchor_lookback_d1    = 252;
input int    strategy_confirm_lookback_d1   = 63;
input double strategy_anchor_long_min       = 0.94;
input double strategy_anchor_short_max      = 1.08;
input double strategy_confirm_min_return_pct = 2.0;
input int    strategy_atr_period            = 20;
input double strategy_atr_sl_mult           = 3.5;
input int    strategy_max_hold_days         = 40;
input int    strategy_max_spread_points     = 1500;

int    g_last_attempt_month_key = 0;
string g_attempt_state_key      = "";

// -----------------------------------------------------------------------------
// Strategy helpers.
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

bool Strategy_IsWinterMonth(const int month)
  {
   if(month < 1 || month > 12)
      return false;
   return (month >= strategy_winter_first_month ||
           month <= strategy_winter_last_month);
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

bool Strategy_IsOwnedMagic()
  {
   return ((int)PositionGetInteger(POSITION_MAGIC) ==
           QM_FrameworkMagic());
  }

bool Strategy_IsManagedPosition()
  {
   return (Strategy_IsOwnedMagic() &&
           PositionGetString(POSITION_SYMBOL) == _Symbol);
  }

bool Strategy_HasOwnedPosition()
  {
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsOwnedMagic())
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
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
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
   if(GlobalVariableSet(g_attempt_state_key, (double)month_key) <= 0)
      return false;
   g_last_attempt_month_key = month_key;
   return true;
  }

bool Strategy_LoadSignal(const int current_month_key,
                         double &high_location,
                         double &low_location,
                         double &confirm_return,
                         int &trade_direction)
  {
   high_location = 0.0;
   low_location = 0.0;
   confirm_return = 0.0;
   trade_direction = 0;

   if(current_month_key <= 0 ||
      strategy_anchor_lookback_d1 != 252 ||
      strategy_confirm_lookback_d1 != 63 ||
      strategy_confirm_lookback_d1 >= strategy_anchor_lookback_d1)
      return false;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied =
      CopyRates(_Symbol, // perf-allowed: bounded completed D1 anchor sample.
                PERIOD_D1,
                1,
                strategy_anchor_lookback_d1,
                bars);
   if(copied != strategy_anchor_lookback_d1)
      return false;

   double closing_high = 0.0;
   double closing_low = DBL_MAX;
   for(int index = 0; index < copied; ++index)
     {
      const double close_value = bars[index].close;
      if(close_value <= 0.0 || !MathIsValidNumber(close_value))
         return false;
      if(close_value > closing_high)
         closing_high = close_value;
      if(close_value < closing_low)
         closing_low = close_value;
     }

   const double newest_close = bars[0].close;
   const double confirm_close = bars[strategy_confirm_lookback_d1].close;
   if(closing_high <= 0.0 ||
      closing_low <= 0.0 ||
      confirm_close <= 0.0)
      return false;

   high_location = newest_close / closing_high;
   low_location = newest_close / closing_low;
   confirm_return = MathLog(newest_close / confirm_close);
   if(!MathIsValidNumber(high_location) ||
      !MathIsValidNumber(low_location) ||
      !MathIsValidNumber(confirm_return))
      return false;

   const int month = current_month_key % 100;
   if(month < 1 || month > 12)
      return false;
   const double confirm_threshold =
      strategy_confirm_min_return_pct / 100.0;

   if(Strategy_IsWinterMonth(month) &&
      high_location >= strategy_anchor_long_min &&
      confirm_return >= confirm_threshold)
      trade_direction = 1;
   else if(!Strategy_IsWinterMonth(month) &&
           low_location <= strategy_anchor_short_max &&
           confirm_return <= -confirm_threshold)
      trade_direction = -1;
   return true;
  }

void Strategy_CloseExpiredPositions()
  {
   MqlRates current_d1;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 0, current_d1))
      return;
   const int current_month_key = Strategy_MonthKey(current_d1.time);
   if(current_month_key <= 0)
      return;

   const datetime now = TimeCurrent();
   const long hold_seconds =
      (long)MathMax(1, strategy_max_hold_days) * 86400;

   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsOwnedMagic())
         continue;

      bool should_close = false;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         should_close = true;

      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      if(Strategy_MonthKey(opened) != current_month_key)
         should_close = true;
      if(opened <= 0 || (long)(now - opened) >= hold_seconds)
         should_close = true;

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks - implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsWtiD1())
      return true;
   if(qm_ea_id != 20241 ||
      qm_magic_slot_offset != 0 ||
      qm_rng_seed != 42)
      return true;
   if(MathAbs(RISK_PERCENT) > 1.0e-12 ||
      MathAbs(RISK_FIXED - 1000.0) > 1.0e-12 ||
      MathAbs(PORTFOLIO_WEIGHT - 1.0) > 1.0e-12)
      return true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE ||
      qm_news_stale_max_hours != 336 ||
      qm_news_min_impact != "high" ||
      qm_news_mode_legacy != QM_NEWS_OFF)
      return true;
   if(qm_friday_close_enabled ||
      qm_friday_close_hour_broker != 21 ||
      MathAbs(qm_stress_reject_probability) > 1.0e-12)
      return true;
   if(strategy_winter_first_month != 11 ||
      strategy_winter_last_month != 5 ||
      strategy_anchor_lookback_d1 != 252 ||
      strategy_confirm_lookback_d1 != 63)
      return true;
   if(MathAbs(strategy_anchor_long_min - 0.94) > 1.0e-12 ||
      MathAbs(strategy_anchor_short_max - 1.08) > 1.0e-12 ||
      MathAbs(strategy_confirm_min_return_pct - 2.0) > 1.0e-12)
      return true;
   if(strategy_atr_period != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.5) > 1.0e-12 ||
      strategy_max_hold_days != 40 ||
      strategy_max_spread_points != 1500)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "WTI_SEAS_ANCHOR";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_IsMonthlyBoundaryBar())
      return false;

   MqlRates current_d1;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 0, current_d1))
      return false;
   const datetime current_bar = current_d1.time;
   const int month_key = Strategy_MonthKey(current_bar);
   if(month_key <= 0 || month_key == g_last_attempt_month_key)
      return false;

   // Consume before history, signal, spread, quote, news, stop, sizing, or
   // order gates. A blocked or flat month never retries after restart.
   if(!Strategy_RecordMonthAttempt(month_key))
      return false;

   if(Strategy_HasOwnedPosition() ||
      Strategy_MonthAlreadyEntered(month_key, current_bar))
      return false;

   double high_location = 0.0;
   double low_location = 0.0;
   double confirm_return = 0.0;
   int trade_direction = 0;
   if(!Strategy_LoadSignal(month_key,
                           high_location,
                           low_location,
                           confirm_return,
                           trade_direction) ||
      trade_direction == 0)
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

   req.type = (trade_direction > 0) ? QM_BUY : QM_SELL;
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
   if((req.type == QM_BUY && req.sl >= entry_price) ||
      (req.type == QM_SELL && req.sl <= entry_price))
      return false;

   req.reason = StringFormat("WTI_SA_%s_H%.3f_L%.3f_R%.3f",
                             trade_direction > 0 ? "L" : "S",
                             high_location,
                             low_location,
                             confirm_return);
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
      qm_ea_id != 20241 ||
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
      StringFormat("QM5_20241_MONTH_ATTEMPT_%d", QM_FrameworkMagic());
   Strategy_LoadAttemptState();

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_20241\",\"ea\":\"wti-seas-anchor\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
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

   // Lifecycle exits precede every entry-only gate.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int index = PositionsTotal() - 1; index >= 0; --index)
        {
         const ulong ticket = PositionGetTicket(index);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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

   // EntrySignal consumes the month before this entry-only news check. Both
   // news axes are locked OFF, but ordering remains restart-safe.
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
