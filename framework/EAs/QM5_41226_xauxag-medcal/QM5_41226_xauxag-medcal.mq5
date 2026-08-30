#property strict
#property version   "5.0"
#property description "QM5_41226 XAU XAG Median Same-Calendar Relative Seasonality"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_41226 - XAU/XAG Median Same-Calendar Relative Seasonality
// -----------------------------------------------------------------------------
// Monthly precious-metals relative-value basket:
//   - reconstruct up to ten synchronized prior-year returns for this month
//   - sort XAU-minus-XAG returns and compute the ordinary sample median
//   - trade opposite metal legs only outside the locked epsilon band
//   - consume one attempt per broker month before every fallible entry gate
// Runtime is Darwinex-native D1 OHLC only; no external or futures-chain data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 41226;
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
input string strategy_xag_symbol            = "XAGUSD.DWX";
input int    strategy_history_years          = 10;
input int    strategy_min_observations      = 5;
input double strategy_signal_epsilon           = 1.0e-12;
input int    strategy_history_bars_d1        = 3000;
input int    strategy_atr_period_d1           = 20;
input double strategy_atr_sl_mult             = 3.5;
input int    strategy_max_hold_days           = 40;
input int    strategy_xau_max_spread_points   = 1500;
input int    strategy_xag_max_spread_points   = 3000;
input int    strategy_deviation_points        = 20;

string g_leg_xau = "XAUUSD.DWX";
string g_leg_xag = "XAGUSD.DWX";

bool     g_monthly_rebalance_bar = false;
bool     g_cache_signal_valid = false;
int      g_cache_pair_direction = 0;
int      g_cache_period_key = 0;
int      g_cache_decision_month_key = 0;
int      g_cache_label_offset_days = -1;
int      g_last_entry_period_key = 0;
datetime g_pair_entry_time = 0;
int      g_cache_sample_count = 0;
double   g_cache_seasonal_median = 0.0;

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

bool Strategy_LoadAllowedQuote(const string symbol,
                               double &bid,
                               double &ask)
  {
   bid = 0.0;
   ask = 0.0;
   MqlTick tick;
   ZeroMemory(tick);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(!SymbolInfoTick(symbol, tick) || point <= 0.0 ||
      !MathIsValidNumber(point) ||
      tick.bid <= 0.0 || tick.ask <= 0.0 ||
      !MathIsValidNumber(tick.bid) || !MathIsValidNumber(tick.ask) ||
      tick.ask < tick.bid)
      return false;

   const double modeled_spread_points = (tick.ask - tick.bid) / point;
   if(!MathIsValidNumber(modeled_spread_points) ||
      modeled_spread_points < 0.0)
      return false;
   if(symbol == g_leg_xau && strategy_xau_max_spread_points > 0 &&
      modeled_spread_points > (double)strategy_xau_max_spread_points)
      return false;
   if(symbol == g_leg_xag && strategy_xag_max_spread_points > 0 &&
      modeled_spread_points > (double)strategy_xag_max_spread_points)
      return false;

   bid = tick.bid;
   ask = tick.ask;
   return true;
  }

bool Strategy_SpreadAllowed(const string symbol)
  {
   double bid = 0.0;
   double ask = 0.0;
   return Strategy_LoadAllowedQuote(symbol, bid, ask);
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

int Strategy_DateKeyForTime(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts) || parts.year <= 0 ||
      parts.mon < 1 || parts.mon > 12 ||
      parts.day < 1 || parts.day > 31)
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

bool Strategy_NormalizedHostSessions(datetime &current_session,
                                     datetime &previous_session,
                                     int &label_offset_days)
  {
   current_session = 0;
   previous_session = 0;
   label_offset_days = -1;

   MqlRates host_rates[];
   ArraySetAsSeries(host_rates, true);
   const int copied = CopyRates(g_leg_xau, PERIOD_D1, 0, 2, host_rates);
   if(copied != 2 || ArraySize(host_rates) < 2 ||
      host_rates[0].time <= host_rates[1].time)
      return false;

   const int broker_date_key = Strategy_DateKeyForTime(TimeCurrent());
   if(broker_date_key <= 0)
      return false;
   if(Strategy_DateKeyForTime(host_rates[0].time) == broker_date_key)
      label_offset_days = 0;
   else if(Strategy_DateKeyForTime(host_rates[0].time + 86400) ==
           broker_date_key)
      label_offset_days = 1;
   else
      return false;

   current_session = host_rates[0].time + label_offset_days * 86400;
   previous_session = host_rates[1].time + label_offset_days * 86400;
   return (current_session > previous_session &&
           Strategy_DateKeyForTime(current_session) == broker_date_key);
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
   return "QM5_41226_XAUXAG_MEDCAL_ATTEMPT";
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

int Strategy_CalendarMonthOrdinal(const int year,
                                  const int month)
  {
   if(year <= 0 || month < 1 || month > 12)
      return 0;
   return year * 12 + month;
  }

bool Strategy_CompletedMonthReturn(const MqlRates &rates[],
                                   const int count,
                                   const int target_year,
                                   const int target_month,
                                   const int label_offset_days,
                                   double &month_return,
                                   datetime &month_end_time,
                                   datetime &previous_end_time,
                                   datetime &following_time)
  {
   month_return = 0.0;
   month_end_time = 0;
   previous_end_time = 0;
   following_time = 0;

   const int target_ordinal =
      Strategy_CalendarMonthOrdinal(target_year, target_month);
   if(target_ordinal <= 0 || count < 3 ||
      (label_offset_days != 0 && label_offset_days != 1))
      return false;

   if(ArraySize(rates) < count)
      return false;

   int first_index = -1;
   int last_index = -1;
   for(int i = 0; i < count; ++i)
     {
      MqlDateTime target_parts;
      ZeroMemory(target_parts);
      const datetime normalized_time =
         rates[i].time + label_offset_days * 86400;
      if(!TimeToStruct(normalized_time, target_parts))
         return false;
      if(target_parts.year != target_year || target_parts.mon != target_month)
         continue;
      if(first_index < 0)
         first_index = i;
      last_index = i;
     }

   if(first_index <= 0 || last_index < first_index ||
      last_index + 1 >= count)
      return false;

   MqlDateTime previous_parts;
   MqlDateTime following_parts;
   ZeroMemory(previous_parts);
   ZeroMemory(following_parts);
   const datetime normalized_previous =
      rates[first_index - 1].time + label_offset_days * 86400;
   const datetime normalized_following =
      rates[last_index + 1].time + label_offset_days * 86400;
   if(!TimeToStruct(normalized_previous, previous_parts) ||
      !TimeToStruct(normalized_following, following_parts))
      return false;

   const int previous_ordinal =
      Strategy_CalendarMonthOrdinal(previous_parts.year, previous_parts.mon);
   const int following_ordinal =
      Strategy_CalendarMonthOrdinal(following_parts.year, following_parts.mon);
   if(previous_ordinal != target_ordinal - 1 ||
      following_ordinal != target_ordinal + 1)
      return false;
   if(rates[first_index - 1].time >= rates[first_index].time ||
      rates[last_index].time >= rates[last_index + 1].time)
      return false;

   for(int i = first_index; i <= last_index; ++i)
     {
      MqlDateTime target_parts;
      ZeroMemory(target_parts);
      const datetime normalized_time =
         rates[i].time + label_offset_days * 86400;
      if(!TimeToStruct(normalized_time, target_parts) ||
         target_parts.year != target_year ||
         target_parts.mon != target_month)
         return false;
      if(i > first_index && rates[i].time <= rates[i - 1].time)
         return false;
     }

   const double prior_close = rates[first_index - 1].close;
   const double month_end_close = rates[last_index].close;
   if(prior_close <= 0.0 || month_end_close <= 0.0 ||
      !MathIsValidNumber(prior_close) ||
      !MathIsValidNumber(month_end_close))
      return false;

   month_return = MathLog(month_end_close / prior_close);
   month_end_time =
      rates[last_index].time + label_offset_days * 86400;
   previous_end_time = normalized_previous;
   following_time = normalized_following;
   return (MathIsValidNumber(month_return) &&
           month_end_time > 0 && previous_end_time > 0 &&
           following_time > 0);
  }

void Strategy_SortAscending(double &values[], const int count)
  {
   for(int index = 1; index < count; ++index)
     {
      const double value = values[index];
      int cursor = index - 1;
      while(cursor >= 0 && values[cursor] > value)
        {
         values[cursor + 1] = values[cursor];
         --cursor;
        }
      values[cursor + 1] = value;
     }
  }

bool Strategy_MedianSignal(double &observations[],
                           const int sample_count,
                           double &seasonal_median,
                           int &direction)
  {
   seasonal_median = 0.0;
   direction = 0;
   if(strategy_history_years != 10 ||
      strategy_min_observations != 5 ||
      MathAbs(strategy_signal_epsilon - 1.0e-12) > 1.0e-18 ||
      sample_count < strategy_min_observations ||
      sample_count > strategy_history_years ||
      ArraySize(observations) < sample_count)
      return false;

   for(int index = 0; index < sample_count; ++index)
     {
      if(index >= ArraySize(observations) ||
         !MathIsValidNumber(observations[index]))
         return false;
     }

   Strategy_SortAscending(observations, sample_count);
   if((sample_count % 2) == 1)
      seasonal_median = observations[sample_count / 2];
   else
      seasonal_median =
         (observations[sample_count / 2 - 1] +
          observations[sample_count / 2]) / 2.0;

   if(!MathIsValidNumber(seasonal_median))
      return false;
   if(seasonal_median > strategy_signal_epsilon)
      direction = 1;
   else if(seasonal_median < -strategy_signal_epsilon)
      direction = -1;
   return true;
  }

bool Strategy_LoadSignalState(const int decision_month_key,
                               int &pair_direction)
  {
   pair_direction = 0;
   g_cache_sample_count = 0;
   g_cache_seasonal_median = 0.0;

   MqlDateTime decision_parts;
   ZeroMemory(decision_parts);
   decision_parts.year = decision_month_key / 100;
   decision_parts.mon = decision_month_key % 100;
   if(decision_month_key <= 0 ||
      decision_parts.year <= 0 ||
      decision_parts.mon < 1 ||
      decision_parts.mon > 12)
      return false;

   MqlRates xau_rates[];
   MqlRates xag_rates[];
   ArraySetAsSeries(xau_rates, false);
   ArraySetAsSeries(xag_rates, false);
   const int xau_count =
      CopyRates(g_leg_xau, PERIOD_D1, 1, strategy_history_bars_d1, xau_rates); // perf-allowed: bounded copy only on the consumed monthly D1 decision.
   const int xag_count =
      CopyRates(g_leg_xag, PERIOD_D1, 1, strategy_history_bars_d1, xag_rates); // perf-allowed: bounded copy only on the consumed monthly D1 decision.
   if(xau_count < 3 || xag_count < 3 ||
      xau_count > strategy_history_bars_d1 ||
      xag_count > strategy_history_bars_d1 ||
      ArraySize(xau_rates) < xau_count ||
      ArraySize(xag_rates) < xag_count)
      return false;
   for(int index = 1; index < xau_count; ++index)
     {
      if(xau_rates[index].time <= xau_rates[index - 1].time)
         return false;
     }
   for(int index = 1; index < xag_count; ++index)
     {
      if(xag_rates[index].time <= xag_rates[index - 1].time)
         return false;
     }

   double relative_returns[];
   if(ArrayResize(relative_returns, strategy_history_years) !=
         strategy_history_years ||
      ArraySize(relative_returns) < strategy_history_years)
      return false;

   for(int offset = 1; offset <= strategy_history_years; ++offset)
     {
      const int sample_year = decision_parts.year - offset;
      double xau_return = 0.0;
      double xag_return = 0.0;
      datetime xau_month_time = 0;
      datetime xau_previous_time = 0;
      datetime xau_following_time = 0;
      datetime xag_month_time = 0;
      datetime xag_previous_time = 0;
      datetime xag_following_time = 0;

      if(!Strategy_CompletedMonthReturn(xau_rates,
                                        xau_count,
                                        sample_year,
                                        decision_parts.mon,
                                        g_cache_label_offset_days,
                                        xau_return,
                                        xau_month_time,
                                        xau_previous_time,
                                        xau_following_time) ||
         !Strategy_CompletedMonthReturn(xag_rates,
                                        xag_count,
                                        sample_year,
                                        decision_parts.mon,
                                        g_cache_label_offset_days,
                                        xag_return,
                                        xag_month_time,
                                        xag_previous_time,
                                        xag_following_time))
         continue;

      if(xau_month_time != xag_month_time ||
         xau_previous_time != xag_previous_time ||
         xau_following_time != xag_following_time)
         continue;

      const double relative_return = xau_return - xag_return;
      if(!MathIsValidNumber(relative_return))
         continue;
      if(g_cache_sample_count < 0 ||
         g_cache_sample_count >= ArraySize(relative_returns))
         return false;
      relative_returns[g_cache_sample_count] = relative_return;
      ++g_cache_sample_count;
     }

   if(g_cache_sample_count < strategy_min_observations)
      return false;

   return Strategy_MedianSignal(relative_returns,
                                g_cache_sample_count,
                                g_cache_seasonal_median,
                                pair_direction);
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
   g_cache_label_offset_days = -1;

   datetime current_session = 0;
   datetime previous_session = 0;
   int label_offset_days = -1;
   if(!Strategy_NormalizedHostSessions(current_session,
                                       previous_session,
                                       label_offset_days))
      return;

   const int current_month_key = Strategy_MonthKeyForTime(current_session);
   const int prior_month_key = Strategy_MonthKeyForTime(previous_session);
   MqlDateTime current_parts;
   MqlDateTime prior_parts;
   ZeroMemory(current_parts);
   ZeroMemory(prior_parts);
   if(!TimeToStruct(current_session, current_parts) ||
      !TimeToStruct(previous_session, prior_parts))
      return;
   const int current_ordinal =
      Strategy_CalendarMonthOrdinal(current_parts.year, current_parts.mon);
   const int prior_ordinal =
      Strategy_CalendarMonthOrdinal(prior_parts.year, prior_parts.mon);
   if(current_month_key <= 0 || prior_month_key <= 0 ||
      prior_ordinal != current_ordinal - 1 ||
      !Strategy_IsRebalanceMonth(current_month_key))
      return;

   g_monthly_rebalance_bar = true;
   g_cache_label_offset_days = label_offset_days;
   g_cache_period_key = (current_month_key / 100) * 12 +
                        (current_month_key % 100);
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
   double bid = 0.0;
   double ask = 0.0;
   if(slot < 0 || !Strategy_LoadAllowedQuote(symbol, bid, ask))
      return false;

   const double entry = QM_OrderTypeIsBuy(type) ? ask : bid;
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

bool Strategy_SubmitHostLeg(const QM_BasketOrderRequest &req)
  {
   if(req.symbol != _Symbol || req.symbol_slot != qm_magic_slot_offset)
      return false;

   QM_EntryRequest host_req;
   ZeroMemory(host_req);
   host_req.type = req.type;
   host_req.price = req.price;
   host_req.sl = req.sl;
   host_req.tp = req.tp;
   host_req.reason = req.reason;
   host_req.symbol_slot = req.symbol_slot;
   host_req.expiration_seconds = req.expiration_seconds;

   ulong ticket = 0;
   return QM_TM_OpenPosition(host_req,
                             ticket,
                             0,
                             QM_RISK_MODE_FIXED,
                             RISK_FIXED / 2.0,
                             QM_TRADE_SEND_RETRY_TRANSIENT);
  }

bool Strategy_SubmitOffChartLeg(const QM_BasketOrderRequest &req)
  {
   if(req.symbol == _Symbol)
      return false;
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
   const string reason = long_xau_short_xag ? "QM5_41226_LONG_XAU_SHORT_XAG_MEDCAL"
                                            : "QM5_41226_SHORT_XAU_LONG_XAG_MEDCAL";
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

   if(!Strategy_SubmitHostLeg(xau_req))
      return false;
   if(Strategy_SubmitOffChartLeg(xag_req) &&
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
   if(qm_ea_id != 41226 || qm_magic_slot_offset != 0 || qm_rng_seed != 42)
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
   if(strategy_xag_symbol != "XAGUSD.DWX" ||
      strategy_history_years != 10 ||
      strategy_min_observations != 5 ||
      MathAbs(strategy_signal_epsilon - 1.0e-12) > 1.0e-18 ||
      strategy_history_bars_d1 != 3000)
      return true;
   if(strategy_atr_period_d1 != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.5) > 1.0e-12 ||
      strategy_max_hold_days != 40)
      return true;
   if(strategy_xau_max_spread_points != 1500 ||
      strategy_xag_max_spread_points != 3000 ||
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
   req.reason = "QM5_41226_XAU_XAG_MEDCAL_HOST";
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
   g_cache_signal_valid = Strategy_LoadSignalState(g_cache_decision_month_key,
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

   g_leg_xag = strategy_xag_symbol;
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
                           MathMax(3000, strategy_history_bars_d1));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_41226\",\"ea\":\"xauxag-medcal\"}");
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
