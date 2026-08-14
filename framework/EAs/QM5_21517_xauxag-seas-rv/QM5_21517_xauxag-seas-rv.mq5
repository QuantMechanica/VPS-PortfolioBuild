#property strict
#property version   "5.0"
#property description "QM5_21517 XAU XAG Seasonal Surprise Reversion"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_21517 - XAU/XAG Seasonal Surprise Reversion
// -----------------------------------------------------------------------------
// Monthly precious-metals relative-value basket:
//   - reconstruct the just-completed synchronized XAU-minus-XAG monthly return
//   - estimate its prior-ten-year same-calendar relative-return mean and scale
//   - fade a standardized positive/negative seasonal surprise beyond +/-0.50
//   - hold one opposite-leg package until the next broker-month transition
//   - consume one attempt per broker month before every fallible entry gate
// Runtime is Darwinex-native D1 OHLC only; no external or futures-chain data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 21517;
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
input int    strategy_history_years          = 10;
input int    strategy_min_history_years      = 5;
input int    strategy_history_bars           = 4000;
input int    strategy_completed_months       = 1;
input double strategy_surprise_entry_z       = 0.5;
input double strategy_signal_epsilon         = 1.0e-10;
input double strategy_variance_epsilon       = 1.0e-16;
input int    strategy_atr_period_d1           = 20;
input double strategy_atr_sl_mult             = 3.5;
input int    strategy_max_hold_days           = 40;
input int    strategy_xau_max_spread_pts      = 1500;
input int    strategy_xag_max_spread_pts      = 3000;
input int    strategy_deviation_points        = 20;

string g_leg_xau = "XAUUSD.DWX";
string g_leg_xag = "XAGUSD.DWX";

bool     g_monthly_rebalance_bar = false;
bool     g_cache_signal_valid = false;
int      g_cache_pair_direction = 0;
int      g_cache_period_key = 0;
int      g_cache_decision_month_key = 0;
int      g_last_entry_period_key = 0;
datetime g_pair_entry_time = 0;
double   g_cache_xau_completed_return = 0.0;
double   g_cache_xag_completed_return = 0.0;
double   g_cache_realized_relative_return = 0.0;
double   g_cache_historical_relative_mean = 0.0;
double   g_cache_historical_relative_sd = 0.0;
double   g_cache_surprise_z = 0.0;
int      g_cache_sample_count = 0;

int Strategy_SlotForSymbol(const string symbol)
  {
   if(symbol == g_leg_xau)
      return 0;
   if(symbol == g_leg_xag)
      return 1;
   return -1;
  }

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_leg_xau && _Period == PERIOD_D1 && qm_magic_slot_offset == 0);
  }

bool Strategy_SpreadAllowed(const string symbol)
  {
   const long spread_points = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(spread_points < 0)
      return false;
   if(symbol == g_leg_xau && strategy_xau_max_spread_pts > 0)
      return (spread_points <= strategy_xau_max_spread_pts);
   if(symbol == g_leg_xag && strategy_xag_max_spread_pts > 0)
      return (spread_points <= strategy_xag_max_spread_pts);
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

string Strategy_AttemptStateName()
  {
   return "QM5_21517_XAUXAG_SEASRV_ATTEMPT";
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
   int xau_direction = 0;
   int xag_direction = 0;
   int xau_count = 0;
   int xag_count = 0;
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
      if(symbol == g_leg_xau)
        {
         xau_direction = direction;
         ++xau_count;
        }
      else if(symbol == g_leg_xag)
        {
         xag_direction = direction;
         ++xag_count;
        }
     }
   if(!stops_valid || xau_count != 1 || xag_count != 1 ||
      xau_direction != -xag_direction)
      return false;
   if(expected_pair_direction != 0 && xau_direction != expected_pair_direction)
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

bool Strategy_MonthEndPoint(const MqlRates &rates[],
                            const int count,
                            const int target_year,
                            const int target_month,
                            double &month_end_close,
                            datetime &month_end_time)
  {
   month_end_close = 0.0;
   month_end_time = 0;
   for(int i = 0; i < count; ++i)
     {
      MqlDateTime parts;
      ZeroMemory(parts);
      if(!TimeToStruct(rates[i].time, parts))
         return false;
      if(parts.year != target_year || parts.mon != target_month)
         continue;
      if(rates[i].close <= 0.0 || !MathIsValidNumber(rates[i].close))
         return false;
      month_end_close = rates[i].close;
      month_end_time = rates[i].time;
      return (month_end_time > 0);
     }
   return false;
  }

bool Strategy_MonthReturn(const MqlRates &rates[],
                          const int count,
                          const int year,
                          const int month,
                          double &month_return,
                          datetime &month_end_time,
                          datetime &previous_end_time)
  {
   month_return = 0.0;
   month_end_time = 0;
   previous_end_time = 0;

   int previous_year = 0;
   int previous_month = 0;
   Strategy_PreviousMonth(year,
                          month,
                          previous_year,
                          previous_month);

   double month_close = 0.0;
   double previous_close = 0.0;
   if(!Strategy_MonthEndPoint(rates,
                              count,
                              year,
                              month,
                              month_close,
                              month_end_time) ||
      !Strategy_MonthEndPoint(rates,
                              count,
                              previous_year,
                              previous_month,
                              previous_close,
                              previous_end_time))
      return false;

   month_return = MathLog(month_close / previous_close);
   return MathIsValidNumber(month_return);
  }

bool Strategy_LoadSignalState(const datetime decision_bar_time,
                              int &pair_direction)
  {
   pair_direction = 0;
   g_cache_xau_completed_return = 0.0;
   g_cache_xag_completed_return = 0.0;
   g_cache_realized_relative_return = 0.0;
   g_cache_historical_relative_mean = 0.0;
   g_cache_historical_relative_sd = 0.0;
   g_cache_surprise_z = 0.0;
   g_cache_sample_count = 0;

   MqlDateTime decision_parts;
   ZeroMemory(decision_parts);
   if(decision_bar_time <= 0 ||
      !TimeToStruct(decision_bar_time, decision_parts) ||
      decision_parts.year <= 0 ||
      decision_parts.mon < 1 ||
      decision_parts.mon > 12)
      return false;

   MqlRates xau_rates[];
   MqlRates xag_rates[];
   ArraySetAsSeries(xau_rates, true);
   ArraySetAsSeries(xag_rates, true);
   const int xau_count =
      CopyRates(g_leg_xau, PERIOD_D1, 1, strategy_history_bars, xau_rates); // perf-allowed: bounded copy only on the consumed monthly D1 decision.
   const int xag_count =
      CopyRates(g_leg_xag, PERIOD_D1, 1, strategy_history_bars, xag_rates); // perf-allowed: bounded copy only on the consumed monthly D1 decision.
   if(xau_count <= 0 || xag_count <= 0)
      return false;

   int completed_year = 0;
   int completed_month = 0;
   Strategy_PreviousMonth(decision_parts.year,
                          decision_parts.mon,
                          completed_year,
                          completed_month);

   datetime xau_completed_end = 0;
   datetime xau_completed_start = 0;
   datetime xag_completed_end = 0;
   datetime xag_completed_start = 0;
   if(!Strategy_MonthReturn(xau_rates,
                            xau_count,
                            completed_year,
                            completed_month,
                            g_cache_xau_completed_return,
                            xau_completed_end,
                            xau_completed_start) ||
      !Strategy_MonthReturn(xag_rates,
                            xag_count,
                            completed_year,
                            completed_month,
                            g_cache_xag_completed_return,
                            xag_completed_end,
                            xag_completed_start))
      return false;
   if(xau_completed_end != xag_completed_end ||
      xau_completed_start != xag_completed_start ||
      xau_completed_end >= decision_bar_time)
      return false;

   g_cache_realized_relative_return =
      g_cache_xau_completed_return - g_cache_xag_completed_return;
   if(!MathIsValidNumber(g_cache_xau_completed_return) ||
      !MathIsValidNumber(g_cache_xag_completed_return) ||
      !MathIsValidNumber(g_cache_realized_relative_return))
      return false;

   double relative_samples[];
   ArrayResize(relative_samples, strategy_history_years);
   ArrayInitialize(relative_samples, 0.0);
   double relative_sum = 0.0;
   for(int offset = 1; offset <= strategy_history_years; ++offset)
     {
      const int sample_year = completed_year - offset;
      double xau_return = 0.0;
      double xag_return = 0.0;
      datetime xau_month_time = 0;
      datetime xau_previous_time = 0;
      datetime xag_month_time = 0;
      datetime xag_previous_time = 0;

      if(!Strategy_MonthReturn(xau_rates,
                               xau_count,
                               sample_year,
                               completed_month,
                               xau_return,
                               xau_month_time,
                               xau_previous_time) ||
         !Strategy_MonthReturn(xag_rates,
                               xag_count,
                               sample_year,
                               completed_month,
                               xag_return,
                               xag_month_time,
                               xag_previous_time))
         continue;

      if(xau_month_time != xag_month_time ||
         xau_previous_time != xag_previous_time)
         continue;

      const double relative_return = xau_return - xag_return;
      if(!MathIsValidNumber(relative_return))
         return false;
      relative_samples[g_cache_sample_count] = relative_return;
      relative_sum += relative_return;
      ++g_cache_sample_count;
     }

   if(g_cache_sample_count < strategy_min_history_years)
      return false;

   g_cache_historical_relative_mean =
      relative_sum / (double)g_cache_sample_count;
   double squared_deviation_sum = 0.0;
   for(int i = 0; i < g_cache_sample_count; ++i)
     {
      const double deviation =
         relative_samples[i] - g_cache_historical_relative_mean;
      squared_deviation_sum += deviation * deviation;
     }
   const double sample_variance =
      squared_deviation_sum / (double)(g_cache_sample_count - 1);
   if(!MathIsValidNumber(g_cache_historical_relative_mean) ||
      !MathIsValidNumber(sample_variance) ||
      sample_variance <= strategy_variance_epsilon)
      return false;
   g_cache_historical_relative_sd = MathSqrt(sample_variance);
   if(!MathIsValidNumber(g_cache_historical_relative_sd) ||
      g_cache_historical_relative_sd <= 0.0)
      return false;

   g_cache_surprise_z =
      (g_cache_realized_relative_return -
       g_cache_historical_relative_mean) /
      g_cache_historical_relative_sd;
   if(!MathIsValidNumber(g_cache_surprise_z))
      return false;

   // Contrarian map: fade a positive XAU-minus-XAG seasonal surprise.
   if(g_cache_surprise_z > strategy_surprise_entry_z + strategy_signal_epsilon)
      pair_direction = -1;
   else if(g_cache_surprise_z < -strategy_surprise_entry_z - strategy_signal_epsilon)
      pair_direction = 1;
   return true;
  }

bool Strategy_IsPairMagic(const long magic)
  {
   const int xau_magic = QM_MagicChecked(qm_ea_id, 0, g_leg_xau);
   const int xag_magic = QM_MagicChecked(qm_ea_id, 1, g_leg_xag);
   return (magic == xau_magic || magic == xag_magic);
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

bool Strategy_PrepareLeg(const string symbol,
                         const QM_OrderType type,
                         const double risk_weight,
                         const double risk_weight_sum,
                         const string reason,
                         QM_BasketOrderRequest &req)
  {
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0 || !Strategy_SpreadAllowed(symbol))
      return false;

   const double entry = QM_OrderTypeIsBuy(type) ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                                : SymbolInfoDouble(symbol, SYMBOL_BID);
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   const double stop_dist = strategy_atr_sl_mult * atr;
   const double lots = Strategy_LotsForLeg(symbol, risk_weight, risk_weight_sum);
   if(lots <= 0.0)
      return false;

   ZeroMemory(req);
   req.symbol = symbol;
   req.type = type;
   req.price = 0.0;
   req.sl = QM_OrderTypeIsBuy(type) ? NormalizeDouble(entry - stop_dist, digits)
                                    : NormalizeDouble(entry + stop_dist, digits);
   req.tp = 0.0;
   req.lots = lots;
   req.reason = reason;
   req.symbol_slot = slot;
   req.expiration_seconds = 0;
   return true;
  }

bool Strategy_SubmitLeg(QM_BasketOrderRequest &req)
  {
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
   if(!Strategy_SpreadAllowed(g_leg_xau) || !Strategy_SpreadAllowed(g_leg_xag))
      return false;

   const bool long_xau_short_xag = (pair_direction > 0);
   const QM_OrderType xau_type = long_xau_short_xag ? QM_BUY : QM_SELL;
   const QM_OrderType xag_type = long_xau_short_xag ? QM_SELL : QM_BUY;
   const string reason = long_xau_short_xag ? "QM5_21517_LONG_XAU_SHORT_XAG_SEASRV"
                                            : "QM5_21517_SHORT_XAU_LONG_XAG_SEASRV";
   const double weight_sum = 2.0;

   QM_BasketOrderRequest xau_req;
   QM_BasketOrderRequest xag_req;
   if(!Strategy_PrepareLeg(g_leg_xau,
                           xau_type,
                           1.0,
                           weight_sum,
                           reason,
                           xau_req) ||
      !Strategy_PrepareLeg(g_leg_xag,
                           xag_type,
                           1.0,
                           weight_sum,
                           reason,
                           xag_req))
      return false;

   if(!Strategy_SubmitLeg(xau_req))
      return false;
   if(Strategy_SubmitLeg(xag_req) &&
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
   if(qm_ea_id != 21517 || qm_magic_slot_offset != 0 || qm_rng_seed != 42)
      return true;
   if(RISK_PERCENT != 0.0 || RISK_FIXED != 1000.0 ||
      PORTFOLIO_WEIGHT != 1.0)
      return true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE ||
      qm_news_mode_legacy != QM_NEWS_OFF)
      return true;
   if(qm_friday_close_enabled || qm_friday_close_hour_broker != 21 ||
      qm_stress_reject_probability != 0.0)
      return true;
   if(strategy_history_years != 10 ||
      strategy_min_history_years != 5 ||
      strategy_history_bars != 4000 ||
      strategy_completed_months != 1 ||
      MathAbs(strategy_surprise_entry_z - 0.5) > 1.0e-12 ||
      MathAbs(strategy_signal_epsilon - 1.0e-10) > 1.0e-16 ||
      MathAbs(strategy_variance_epsilon - 1.0e-16) > 1.0e-22)
      return true;
   if(strategy_atr_period_d1 != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.5) > 1.0e-12 ||
      strategy_max_hold_days != 40)
      return true;
   if(strategy_xau_max_spread_pts != 1500 ||
      strategy_xag_max_spread_pts != 3000 ||
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
   req.reason = "QM5_21517_XAU_XAG_SEASRV_HOST";
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
      if(!QM_NewsAllowsTrade2(g_leg_xau,
                              broker_time,
                              qm_news_temporal,
                              qm_news_compliance))
         return false;
      if(!QM_NewsAllowsTrade2(g_leg_xag,
                              broker_time,
                              qm_news_temporal,
                              qm_news_compliance))
         return false;
     }
   else
     {
      if(!QM_NewsAllowsTrade(g_leg_xau, broker_time, qm_news_mode_legacy))
         return false;
      if(!QM_NewsAllowsTrade(g_leg_xag, broker_time, qm_news_mode_legacy))
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

   SymbolSelect(g_leg_xau, true);
   SymbolSelect(g_leg_xag, true);

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

   string basket_symbols[2] = {g_leg_xau, g_leg_xag};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols,
                          PERIOD_D1,
                          MathMax(4000, strategy_history_bars));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_21517\",\"ea\":\"xauxag-seas-rv\"}");
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
