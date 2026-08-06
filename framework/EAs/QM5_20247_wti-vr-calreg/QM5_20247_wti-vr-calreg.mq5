#property strict
#property version   "5.0"
#property description "QM5_20247 WTI Variance-Ratio Calendar Regime"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_20247 - WTI Variance-Ratio Calendar Regime
// -----------------------------------------------------------------------------
// D1 structural crude-oil sleeve:
//   - first tradable D1 bar of each broker-calendar month
//   - q=2 robust variance-ratio state over 32 completed monthly returns
//   - November-May long / June-October short physical-season direction
//   - persistence follows the season; anti-persistence reverses the season
//   - one consumed attempt per month, persisted before fallible gates
//   - fixed-risk ATR stop and forty-day stale guard; Friday close disabled
// Runtime uses MT5-native OHLC/calendar/history only; no external data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 20247;
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
input int    strategy_vr_window_months     = 32;
input int    strategy_vr_q                 = 2;
input double strategy_significance_z       = 1.64485362695147;
input int    strategy_winter_start_month   = 11;
input int    strategy_winter_end_month     = 5;
input int    strategy_history_bars         = 1200;
input int    strategy_atr_period           = 20;
input double strategy_atr_sl_mult          = 3.0;
input int    strategy_max_hold_days        = 40;
input int    strategy_max_spread_points    = 1500;

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

int Strategy_CalendarDirection(const int current_month_key)
  {
   const int month = current_month_key % 100;
   if(month < 1 || month > 12)
      return 0;
   if(month >= strategy_winter_start_month ||
      month <= strategy_winter_end_month)
      return 1;
   return -1;
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

bool Strategy_LoadMemoryCalendarSignal(const int current_month_key,
                                       double &variance_ratio,
                                       double &z_value,
                                       int &season_direction,
                                       int &trade_direction)
  {
   variance_ratio = 0.0;
   z_value = 0.0;
   season_direction = 0;
   trade_direction = 0;

   const int needed_closes = strategy_vr_window_months + 1;
   if(strategy_vr_window_months != 32 ||
      strategy_vr_q != 2 ||
      needed_closes != 33)
      return false;

   season_direction = Strategy_CalendarDirection(current_month_key);
   if(season_direction == 0)
      return false;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied =
      CopyRates(_Symbol, // perf-allowed: bounded monthly D1 endpoint sample.
                PERIOD_D1,
                1,
                strategy_history_bars,
                bars);
   if(copied < needed_closes)
      return false;

   int month_keys[];
   double month_closes[];
   ArrayResize(month_keys, needed_closes);
   ArrayResize(month_closes, needed_closes);
   ArrayInitialize(month_keys, 0);
   ArrayInitialize(month_closes, 0.0);
   int found = 0;
   int last_key = 0;
   for(int index = 0; index < copied && found < needed_closes; ++index)
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

   if(found != needed_closes ||
      Strategy_NextMonthKey(month_keys[0]) != current_month_key)
      return false;

   for(int index = 0; index < strategy_vr_window_months; ++index)
     {
      if(Strategy_NextMonthKey(month_keys[index + 1]) != month_keys[index])
         return false;
     }

   // month_closes[] is reverse chronological. Build thirty-two returns in
   // chronological order so lag-one products match the approved formula.
   double monthly_returns[];
   ArrayResize(monthly_returns, strategy_vr_window_months);
   ArrayInitialize(monthly_returns, 0.0);
   for(int index = 0; index < strategy_vr_window_months; ++index)
     {
      const int older_index = strategy_vr_window_months - index;
      const int newer_index = older_index - 1;
      const double monthly_return =
         MathLog(month_closes[newer_index] / month_closes[older_index]);
      if(!MathIsValidNumber(monthly_return))
         return false;
      monthly_returns[index] = monthly_return;
     }

   double sum = 0.0;
   for(int index = 0; index < strategy_vr_window_months; ++index)
      sum += monthly_returns[index];
   const double mean = sum / (double)strategy_vr_window_months;
   if(!MathIsValidNumber(mean))
      return false;

   double squared_sum = 0.0;
   for(int index = 0; index < strategy_vr_window_months; ++index)
     {
      const double delta = monthly_returns[index] - mean;
      squared_sum += delta * delta;
     }
   if(squared_sum <= 0.0 || !MathIsValidNumber(squared_sum))
      return false;

   double lag_cross_sum = 0.0;
   double robust_numerator = 0.0;
   for(int index = 1; index < strategy_vr_window_months; ++index)
     {
      const double current_delta = monthly_returns[index] - mean;
      const double prior_delta = monthly_returns[index - 1] - mean;
      lag_cross_sum += current_delta * prior_delta;
      robust_numerator += current_delta * current_delta *
                          prior_delta * prior_delta;
     }

   const double rho_one = lag_cross_sum / squared_sum;
   variance_ratio = 1.0 + rho_one;
   const double robust_se =
      MathSqrt(robust_numerator / (squared_sum * squared_sum));
   if(robust_se <= 0.0 ||
      !MathIsValidNumber(robust_se) ||
      !MathIsValidNumber(variance_ratio))
      return false;

   z_value = (variance_ratio - 1.0) / robust_se;
   if(!MathIsValidNumber(z_value))
      return false;

   // Insignificant memory is a valid flat monthly decision.
   if(MathAbs(z_value) <= strategy_significance_z)
      return true;

   const int memory_direction = (z_value > 0.0) ? 1 : -1;
   trade_direction = season_direction * memory_direction;
   return true;
  }

void Strategy_CloseExpiredPositions()
  {
   MqlRates current_d1;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 0, current_d1))
      return;
   const int current_month_key = Strategy_MonthKey(current_d1.time);
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
      bool should_close = false;
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
   if(qm_ea_id != 20247 ||
      qm_magic_slot_offset != 0)
      return true;
   if(strategy_vr_window_months != 32 ||
      strategy_vr_q != 2 ||
      MathAbs(strategy_significance_z - 1.64485362695147) > 1.0e-12 ||
      strategy_winter_start_month != 11 ||
      strategy_winter_end_month != 5)
      return true;
   if(strategy_history_bars != 1200 ||
      strategy_atr_period != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.0) > 1.0e-12 ||
      strategy_max_hold_days != 40 ||
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
   req.reason = "WTI_VR_CALREG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_IsMonthlyBoundaryBar())
      return false;

   MqlRates current_d1;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 0, current_d1))
      return false;
   const datetime current_bar = current_d1.time;
   const int month_key = Strategy_MonthKey(current_bar);
   if(month_key <= 0 ||
      month_key == g_last_attempt_month_key)
      return false;

   // Consume before history, signal, spread, quote, news, stop, or order gates.
   if(!Strategy_RecordMonthAttempt(month_key))
      return false;

   if(Strategy_HasOpenPosition() ||
      Strategy_MonthAlreadyEntered(month_key, current_bar))
      return false;

   double variance_ratio = 0.0;
   double z_value = 0.0;
   int season_direction = 0;
   int trade_direction = 0;
   if(!Strategy_LoadMemoryCalendarSignal(month_key,
                                         variance_ratio,
                                         z_value,
                                         season_direction,
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

   req.reason = StringFormat("WTI_VR_CAL_%s_SEAS_%s_Z%.4f_VR%.4f",
                             trade_direction > 0 ? "LONG" : "SHORT",
                             season_direction > 0 ? "WINTER" : "SUMMER",
                             z_value,
                             variance_ratio);
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
      qm_ea_id != 20247 ||
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
      StringFormat("QM5_20247_MONTH_ATTEMPT_%d",
                   QM_FrameworkMagic());
   Strategy_LoadAttemptState();

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_20247\",\"ea\":\"wti-vr-calreg\"}");
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

   // EntrySignal consumes the month before this entry-only news check. Both
   // axes are locked OFF, but ordering remains restart-safe.
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
