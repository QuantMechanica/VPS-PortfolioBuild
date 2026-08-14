#property strict
#property version   "5.0"
#property description "QM5_21524 WTI XCU Relative Momentum"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_21524 - WTI/Copper 12-Month Cross-Sectional Momentum
// -----------------------------------------------------------------------------
// Monthly energy/base-metal relative-value basket:
//   - reconstruct 13 synchronized completed broker month-end closes
//   - calculate 12 consecutive monthly simple returns per leg
//   - rank the arithmetic average of those monthly returns
//   - long the higher-return leg and short the lower-return leg
// Runtime is Darwinex-native D1 OHLC only; no external or futures-chain data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 21524;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = false;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_return_window_months    = 12;
input int    strategy_history_bars_d1         = 800;
input int    strategy_max_endpoint_gap_days   = 10;
input double strategy_rank_deadband           = 1.0e-10;
input int    strategy_atr_period_d1            = 20;
input double strategy_atr_sl_mult              = 3.5;
input int    strategy_max_hold_days            = 40;
input int    strategy_wti_max_spread_pts       = 1500;
input int    strategy_xcu_max_spread_pts       = 1200;
input int    strategy_deviation_points         = 20;

string g_leg_wti = "XTIUSD.DWX";
string g_leg_xcu = "XCUUSD.DWX";

bool     g_monthly_rebalance_bar = false;
bool     g_cache_signal_valid = false;
int      g_cache_pair_direction = 0;
int      g_cache_period_key = 0;
int      g_cache_decision_month_key = 0;
int      g_last_entry_period_key = 0;
datetime g_pair_entry_time = 0;
double   g_cache_wti_avg_return = 0.0;
double   g_cache_xcu_avg_return = 0.0;
double   g_cache_return_difference = 0.0;
int      g_cache_wti_observations = 0;
int      g_cache_xcu_observations = 0;

int Strategy_SlotForSymbol(const string symbol)
  {
   if(symbol == g_leg_wti)
      return 0;
   if(symbol == g_leg_xcu)
      return 1;
   return -1;
  }

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_leg_wti && _Period == PERIOD_D1 && qm_magic_slot_offset == 0);
  }

bool Strategy_SpreadAllowed(const string symbol)
  {
   const long spread_points = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(spread_points < 0)
      return false;
   if(symbol == g_leg_wti && strategy_wti_max_spread_pts > 0)
      return (spread_points <= strategy_wti_max_spread_pts);
   if(symbol == g_leg_xcu && strategy_xcu_max_spread_pts > 0)
      return (spread_points <= strategy_xcu_max_spread_pts);
   return true;
  }

bool Strategy_IsPairPosition()
  {
   const string symbol = PositionGetString(POSITION_SYMBOL);
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0)
      return false;
   return ((int)PositionGetInteger(POSITION_MAGIC) == QM_MagicChecked(qm_ea_id, slot, symbol));
  }

int Strategy_OpenPairLegCount()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsPairPosition())
         ++count;
     }
   return count;
  }

datetime Strategy_CurrentPairEntryTime()
  {
   datetime earliest = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsPairPosition())
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && (earliest == 0 || opened < earliest))
         earliest = opened;
     }
   return earliest;
  }

int Strategy_MonthKeyForTime(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime parts;
   TimeToStruct(value, parts);
   if(parts.year <= 0 || parts.mon < 1 || parts.mon > 12)
      return 0;
   return parts.year * 100 + parts.mon;
  }

int Strategy_PeriodKeyForTime(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime parts;
   TimeToStruct(value, parts);
   if(parts.year <= 0 || parts.mon < 1 || parts.mon > 12)
      return 0;
   return parts.year * 12 + parts.mon;
  }

int Strategy_PreviousMonthKey(const int month_key)
  {
   if(month_key <= 0)
      return 0;
   const int year = month_key / 100;
   const int month = month_key % 100;
   if(year <= 0 || month < 1 || month > 12)
      return 0;
   if(month == 1)
      return (year - 1) * 100 + 12;
   return year * 100 + month - 1;
  }

string Strategy_AttemptStateName()
  {
   return "QM5_21524_WTI_XCU_RELMOM_ATTEMPT";
  }

bool Strategy_ConsumePeriodAttempt(const int period_key)
  {
   if(period_key <= 0)
      return false;

   const string state_name = Strategy_AttemptStateName();
   if(GlobalVariableCheck(state_name))
     {
      const double stored_value = GlobalVariableGet(state_name);
      if(!MathIsValidNumber(stored_value))
         return false;
      const int stored_period_key = (int)MathRound(stored_value);
      if(stored_period_key >= period_key)
         return false;
     }

   if(GlobalVariableSet(state_name, (double)period_key) <= 0)
      return false;
   GlobalVariablesFlush();
   return true;
  }

bool Strategy_IsRebalanceMonth(const int month_key)
  {
   if(month_key <= 0)
      return false;
   const int month = month_key % 100;
   return (month >= 1 && month <= 12);
  }

bool Strategy_PairCompositionValid(const int expected_pair_direction = 0)
  {
   int wti_direction = 0;
   int xcu_direction = 0;
   int wti_count = 0;
   int xcu_count = 0;
   bool stops_valid = true;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsPairPosition())
         continue;
      const string symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const int direction = (position_type == POSITION_TYPE_BUY) ? 1 : -1;
      const double stop_loss = PositionGetDouble(POSITION_SL);
      if(stop_loss <= 0.0 || !MathIsValidNumber(stop_loss))
         stops_valid = false;
      if(symbol == g_leg_wti)
        {
         wti_direction = direction;
         ++wti_count;
        }
      else if(symbol == g_leg_xcu)
        {
         xcu_direction = direction;
         ++xcu_count;
        }
     }
   if(!stops_valid || wti_count != 1 || xcu_count != 1 ||
      wti_direction != -xcu_direction)
      return false;
   if(expected_pair_direction != 0 && wti_direction != expected_pair_direction)
      return false;
   return true;
  }

void Strategy_ClosePair(const QM_ExitReason reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsPairPosition())
         QM_TM_ClosePosition(ticket, reason);
     }
   g_pair_entry_time = 0;
  }

bool Strategy_LoadMonthEndpoints(const string symbol,
                                 double &month_closes[],
                                 datetime &month_times[],
                                 int &month_keys[])
  {
   const int required_month_closes = strategy_return_window_months + 1;
   if(ArrayResize(month_closes, required_month_closes) != required_month_closes ||
      ArrayResize(month_times, required_month_closes) != required_month_closes ||
      ArrayResize(month_keys, required_month_closes) != required_month_closes)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int count =
       CopyRates(symbol, // perf-allowed: bounded copy only after the monthly attempt is consumed.
                 PERIOD_D1,
                 1,
                 strategy_history_bars_d1,
                 rates);
   if(count < required_month_closes)
      return false;

   int month_count = 0;
   int last_month_key = 0;
   for(int i = 0; i < count && month_count < required_month_closes; ++i)
     {
      const int month_key = Strategy_MonthKeyForTime(rates[i].time);
      if(month_key <= 0)
         return false;
      if(month_key == last_month_key)
         continue;
      if(rates[i].time <= 0 || rates[i].close <= 0.0 ||
         !MathIsValidNumber(rates[i].close))
         return false;

      month_closes[month_count] = rates[i].close;
      month_times[month_count] = rates[i].time;
      month_keys[month_count] = month_key;
      last_month_key = month_key;
      ++month_count;
     }

   if(month_count != required_month_closes)
      return false;

   for(int i = 0; i < required_month_closes - 1; ++i)
     {
      if(month_keys[i + 1] != Strategy_PreviousMonthKey(month_keys[i]))
         return false;
      if(month_times[i] <= month_times[i + 1])
         return false;
     }
   return true;
  }

bool Strategy_LoadSignalState(const datetime decision_bar_time,
                              int &pair_direction)
  {
   pair_direction = 0;
   g_cache_wti_avg_return = 0.0;
   g_cache_xcu_avg_return = 0.0;
   g_cache_return_difference = 0.0;
   g_cache_wti_observations = 0;
   g_cache_xcu_observations = 0;

   if(decision_bar_time <= 0)
      return false;

   const int decision_month_key = Strategy_MonthKeyForTime(decision_bar_time);
   const int expected_latest_month_key = Strategy_PreviousMonthKey(decision_month_key);
   if(expected_latest_month_key <= 0)
      return false;

   double wti_closes[];
   datetime wti_times[];
   int wti_month_keys[];
   double xcu_closes[];
   datetime xcu_times[];
   int xcu_month_keys[];
   if(!Strategy_LoadMonthEndpoints(g_leg_wti,
                                   wti_closes,
                                   wti_times,
                                   wti_month_keys) ||
      !Strategy_LoadMonthEndpoints(g_leg_xcu,
                                   xcu_closes,
                                   xcu_times,
                                   xcu_month_keys))
      return false;

   const int required_month_closes = strategy_return_window_months + 1;
   if(ArraySize(wti_closes) != required_month_closes ||
      ArraySize(xcu_closes) != required_month_closes ||
      wti_month_keys[0] != expected_latest_month_key ||
      xcu_month_keys[0] != expected_latest_month_key)
      return false;

   for(int i = 0; i < required_month_closes; ++i)
     {
      if(wti_month_keys[i] != xcu_month_keys[i] ||
         wti_times[i] != xcu_times[i] ||
         wti_times[i] >= decision_bar_time)
         return false;
     }

   const long endpoint_age_seconds =
      (long)(decision_bar_time - wti_times[0]);
   const long max_endpoint_age_seconds =
      (long)strategy_max_endpoint_gap_days * 86400L;
   if(endpoint_age_seconds < 0 ||
      endpoint_age_seconds > max_endpoint_age_seconds)
      return false;

   double wti_return_sum = 0.0;
   double xcu_return_sum = 0.0;
   for(int i = 0; i < strategy_return_window_months; ++i)
     {
      const double wti_return = wti_closes[i] / wti_closes[i + 1] - 1.0;
      const double xcu_return = xcu_closes[i] / xcu_closes[i + 1] - 1.0;
      if(!MathIsValidNumber(wti_return) || !MathIsValidNumber(xcu_return))
         return false;
      wti_return_sum += wti_return;
      xcu_return_sum += xcu_return;
      ++g_cache_wti_observations;
      ++g_cache_xcu_observations;
     }

   if(g_cache_wti_observations != strategy_return_window_months ||
      g_cache_xcu_observations != strategy_return_window_months)
      return false;

   g_cache_wti_avg_return =
      wti_return_sum / (double)g_cache_wti_observations;
   g_cache_xcu_avg_return =
      xcu_return_sum / (double)g_cache_xcu_observations;

   g_cache_return_difference = g_cache_wti_avg_return - g_cache_xcu_avg_return;
   if(!MathIsValidNumber(g_cache_wti_avg_return) ||
      !MathIsValidNumber(g_cache_xcu_avg_return) ||
      !MathIsValidNumber(g_cache_return_difference))
      return false;
   if(g_cache_return_difference > strategy_rank_deadband)
      pair_direction = 1;
   else if(g_cache_return_difference < -strategy_rank_deadband)
      pair_direction = -1;
   return true;
  }

bool Strategy_IsPairMagic(const long magic)
  {
   const int wti_magic = QM_MagicChecked(qm_ea_id, 0, g_leg_wti);
   const int xcu_magic = QM_MagicChecked(qm_ea_id, 1, g_leg_xcu);
   return (magic == wti_magic || magic == xcu_magic);
  }

bool Strategy_PeriodAlreadyEntered(const int period_key,
                                   const int decision_month_key)
  {
   if(period_key <= 0 || decision_month_key <= 0)
      return true;
   if(g_last_entry_period_key == period_key)
      return true;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsPairPosition())
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
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
      return true; // Fail closed: a restart must not bypass the one-package-per-period guard.

   const int deal_count = HistoryDealsTotal();
   for(int i = deal_count - 1; i >= 0; --i)
     {
      const ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0)
         continue;
      const long magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
      if(!Strategy_IsPairMagic(magic))
         continue;
      const ENUM_DEAL_ENTRY entry_kind = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      if(Strategy_PeriodKeyForTime(deal_time) == period_key)
         return true;
     }
   return false;
  }

void Strategy_AdvanceSignal_OnNewBar()
  {
   g_monthly_rebalance_bar = false;
   g_cache_signal_valid = false;
   g_cache_pair_direction = 0;
   g_cache_period_key = 0;
   g_cache_decision_month_key = 0;
   const datetime decision_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: cached timestamp on the D1 new-bar path.
   const datetime prior_bar_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: exact first-tradable-bar monthly transition check.
   const int current_month_key = Strategy_MonthKeyForTime(decision_bar_time);
   const int prior_month_key = Strategy_MonthKeyForTime(prior_bar_time);
   if(current_month_key <= 0 || prior_month_key <= 0 ||
      current_month_key == prior_month_key ||
      !Strategy_IsRebalanceMonth(current_month_key))
      return;

   g_monthly_rebalance_bar = true;
   g_cache_period_key = Strategy_PeriodKeyForTime(decision_bar_time);
   g_cache_decision_month_key = current_month_key;
  }

bool Strategy_MaxHoldExceeded()
  {
   datetime entry_time = g_pair_entry_time;
   if(entry_time <= 0)
      entry_time = Strategy_CurrentPairEntryTime();
   if(entry_time <= 0)
      return false;
   const long hold_seconds = (long)MathMax(1, strategy_max_hold_days) * 86400;
   return ((long)(TimeCurrent() - entry_time) >= hold_seconds);
  }

double Strategy_LotsForLeg(const string symbol,
                           const double risk_weight,
                           const double risk_weight_sum)
  {
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0 || risk_weight <= 0.0 || risk_weight_sum <= 0.0)
      return 0.0;

   const double sl_points = strategy_atr_sl_mult * atr / point;
   double lots = QM_LotsForRisk(symbol, sl_points) * risk_weight / risk_weight_sum;
   const double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   const double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   const double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(lots <= 0.0 || min_lot <= 0.0 || max_lot <= 0.0 || step <= 0.0)
      return 0.0;

   lots = MathFloor(lots / step) * step;
   if(lots < min_lot)
      return 0.0;
   return MathMin(max_lot, NormalizeDouble(lots, 8));
  }

bool Strategy_OpenLeg(const string symbol,
                      const QM_OrderType type,
                      const double risk_weight,
                      const double risk_weight_sum,
                      const string reason)
  {
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0 || !Strategy_SpreadAllowed(symbol) ||
      QM_MagicChecked(qm_ea_id, slot, symbol) <= 0)
      return false;

   const double entry = QM_OrderTypeIsBuy(type) ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                                : SymbolInfoDouble(symbol, SYMBOL_BID);
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   const long stops_level_points = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double stop_dist = strategy_atr_sl_mult * atr;
   if(point <= 0.0 || stops_level_points < 0 ||
      stop_dist <= (double)stops_level_points * point)
      return false;
   const double lots = Strategy_LotsForLeg(symbol, risk_weight, risk_weight_sum);
   if(lots <= 0.0)
      return false;

   QM_BasketOrderRequest req;
   req.symbol = symbol;
   req.type = type;
   req.price = 0.0;
   req.sl = QM_OrderTypeIsBuy(type) ? NormalizeDouble(entry - stop_dist, digits)
                                    : NormalizeDouble(entry + stop_dist, digits);
   if(req.sl <= 0.0 || !MathIsValidNumber(req.sl))
      return false;
   req.tp = 0.0;
   req.lots = lots;
   req.reason = reason;
   req.symbol_slot = slot;
   req.expiration_seconds = 0;

   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id,
                                qm_news_mode_legacy,
                                strategy_deviation_points,
                                req,
                                ticket);
  }

bool Strategy_OpenPair(const int pair_direction)
  {
   if(pair_direction == 0 || Strategy_OpenPairLegCount() > 0)
      return false;
   if(!Strategy_SpreadAllowed(g_leg_wti) || !Strategy_SpreadAllowed(g_leg_xcu))
      return false;

   const bool long_wti_short_xcu = (pair_direction > 0);
   const QM_OrderType wti_type = long_wti_short_xcu ? QM_BUY : QM_SELL;
   const QM_OrderType xcu_type = long_wti_short_xcu ? QM_SELL : QM_BUY;
   const string reason = long_wti_short_xcu ? "QM5_21524_LONG_WTI_SHORT_XCU_HIGH_12M_RETURN"
                                            : "QM5_21524_SHORT_WTI_LONG_XCU_HIGH_12M_RETURN";
   const double weight_sum = 2.0;

   if(!Strategy_OpenLeg(g_leg_wti, wti_type, 1.0, weight_sum, reason))
      return false;
   if(Strategy_OpenLeg(g_leg_xcu, xcu_type, 1.0, weight_sum, reason) &&
      Strategy_OpenPairLegCount() == 2 &&
      Strategy_PairCompositionValid(pair_direction))
     {
      g_pair_entry_time = TimeCurrent();
      return true;
     }

   Strategy_ClosePair(QM_EXIT_STRATEGY);
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart())
      return true;
   if(qm_ea_id != 21524 || qm_magic_slot_offset != 0 || qm_rng_seed != 42)
      return true;
   if(RISK_PERCENT != 0.0 || RISK_FIXED != 1000.0 ||
      PORTFOLIO_WEIGHT != 1.0)
      return true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE ||
      qm_news_mode_legacy != QM_NEWS_OFF ||
      qm_news_stale_max_hours != 336 || qm_news_min_impact != "high")
      return true;
   if(qm_friday_close_enabled || qm_friday_close_hour_broker != 21 ||
      qm_stress_reject_probability != 0.0)
      return true;
   if(strategy_return_window_months != 12 ||
      strategy_history_bars_d1 != 800 ||
      strategy_max_endpoint_gap_days != 10 ||
      MathAbs(strategy_rank_deadband - 1.0e-10) > 1.0e-16)
      return true;
   if(strategy_atr_period_d1 != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.5) > 1.0e-12 ||
      strategy_max_hold_days != 40)
      return true;
   if(strategy_wti_max_spread_pts != 1500 ||
      strategy_xcu_max_spread_pts != 1200 ||
      strategy_deviation_points != 20)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_21524_WTI_XCU_RELMOM_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_monthly_rebalance_bar || g_cache_period_key <= 0 ||
      g_cache_decision_month_key <= 0)
      return false;
   if(!Strategy_ConsumePeriodAttempt(g_cache_period_key))
      return false;
   if(Strategy_PeriodAlreadyEntered(g_cache_period_key,
                                    g_cache_decision_month_key))
      return false;
   if(Strategy_OpenPairLegCount() > 0)
      return false;
   if(!Strategy_NewsAllowsEntry(TimeCurrent()))
      return false;
   const datetime decision_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: monthly D1 decision path only.
   g_cache_signal_valid = Strategy_LoadSignalState(decision_bar_time,
                                                   g_cache_pair_direction);
   if(!g_cache_signal_valid || g_cache_pair_direction == 0)
      return false;

   if(Strategy_OpenPair(g_cache_pair_direction))
      g_last_entry_period_key = g_cache_period_key;
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int open_legs = Strategy_OpenPairLegCount();
   if(open_legs <= 0)
      return;
   if(open_legs != 2 || !Strategy_PairCompositionValid())
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return;
     }

   if(g_monthly_rebalance_bar)
     {
      datetime entry_time = g_pair_entry_time;
      if(entry_time <= 0)
         entry_time = Strategy_CurrentPairEntryTime();
      if(Strategy_PeriodKeyForTime(entry_time) != g_cache_period_key)
        {
         Strategy_ClosePair(QM_EXIT_STRATEGY);
         return;
        }
     }

   if(Strategy_MaxHoldExceeded())
      Strategy_ClosePair(QM_EXIT_TIME_STOP);
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsAllowsEntry(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
     {
      if(!QM_NewsAllowsTrade2(g_leg_wti,
                              broker_time,
                              qm_news_temporal,
                              qm_news_compliance))
         return false;
      if(!QM_NewsAllowsTrade2(g_leg_xcu,
                              broker_time,
                              qm_news_temporal,
                              qm_news_compliance))
         return false;
     }
   else
     {
      if(!QM_NewsAllowsTrade(g_leg_wti, broker_time, qm_news_mode_legacy))
         return false;
      if(!QM_NewsAllowsTrade(g_leg_xcu, broker_time, qm_news_mode_legacy))
         return false;
     }
   return true;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return !Strategy_NewsAllowsEntry(broker_time);
  }

int OnInit()
  {
   // A repeated tester run starts earlier than its prior terminal-global
   // marker. Clear only future state, retaining same-period restart safety.
   const string attempt_state_name = Strategy_AttemptStateName();
   const int current_period_key = Strategy_PeriodKeyForTime(TimeCurrent());
   if(current_period_key > 0 && GlobalVariableCheck(attempt_state_name))
     {
      const double stored_value = GlobalVariableGet(attempt_state_name);
      if(MathIsValidNumber(stored_value) &&
         (int)MathRound(stored_value) > current_period_key)
         GlobalVariableDel(attempt_state_name);
     }

   if(!SymbolSelect(g_leg_wti, true) || !SymbolSelect(g_leg_xcu, true))
      return INIT_FAILED;

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

   if(QM_MagicChecked(qm_ea_id, 0, g_leg_wti) != 215240000 ||
      QM_MagicChecked(qm_ea_id, 1, g_leg_xcu) != 215240001)
      return INIT_FAILED;

   string basket_symbols[2] = {g_leg_wti, g_leg_xcu};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols,
                          PERIOD_D1,
                          MathMax(1200, strategy_history_bars_d1));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_21524\",\"ea\":\"wti-xcu-relmom\"}");
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

   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   const bool new_bar = QM_IsNewBar();
   g_monthly_rebalance_bar = false;
   if(new_bar)
      Strategy_AdvanceSignal_OnNewBar();

   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return;
     }

   if(!new_bar)
      return;

   QM_EquityStreamOnNewBar();

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
