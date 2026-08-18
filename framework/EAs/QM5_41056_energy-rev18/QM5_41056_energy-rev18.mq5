#property strict
#property version   "5.0"
#property description "QM5_41056 XTI XNG 18-Month Cross-Sectional Reversal"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_41056 - XTI/XNG 18-Month Cross-Sectional Reversal
// -----------------------------------------------------------------------------
// Monthly opposite-leg energy structural package:
//   - rank XTI and XNG on synchronized 18-completed-month log returns
//   - buy the long-horizon loser and short the winner
//   - consume the month flat inside the frozen numerical tie band
// Runtime is Darwinex-native D1 close data only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 41056;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = false;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_reversal_months        = 18;
input int    strategy_history_bars            = 520;
input int    strategy_max_boundary_gap_days   = 10;
input double strategy_signal_epsilon           = 1.0e-12;
input int    strategy_atr_period_d1            = 20;
input double strategy_atr_sl_mult              = 3.5;
input int    strategy_max_hold_days            = 35;
input int    strategy_xti_max_spread_pts       = 1500;
input int    strategy_xng_max_spread_pts       = 3000;
input int    strategy_deviation_points         = 20;

string g_leg_xti = "XTIUSD.DWX";
string g_leg_xng = "XNGUSD.DWX";

bool     g_monthly_rebalance_bar = false;
bool     g_cache_signal_valid = false;
int      g_cache_pair_direction = 0;
int      g_cache_month_key = 0;
int      g_cache_period_key = 0;
int      g_last_entry_period_key = 0;
datetime g_cache_decision_bar_time = 0;
datetime g_pair_entry_time = 0;
int      g_decision_label_offset = 0;
double   g_cache_xti_reversal = 0.0;
double   g_cache_xng_reversal = 0.0;
double   g_cache_reversal_difference = 0.0;

bool Strategy_NewsAllowsEntry(const datetime broker_time);

int Strategy_SlotForSymbol(const string symbol)
  {
   if(symbol == g_leg_xti)
      return 0;
   if(symbol == g_leg_xng)
      return 1;
   return -1;
  }

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_leg_xti && _Period == PERIOD_D1 && qm_magic_slot_offset == 0);
  }

bool Strategy_SpreadAllowed(const string symbol)
  {
   const long spread_points = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(spread_points < 0)
      return false;
   if(symbol == g_leg_xti && strategy_xti_max_spread_pts > 0)
      return (spread_points <= strategy_xti_max_spread_pts);
   if(symbol == g_leg_xng && strategy_xng_max_spread_pts > 0)
      return (spread_points <= strategy_xng_max_spread_pts);
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
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts) || parts.year <= 0 ||
      parts.mon < 1 || parts.mon > 12)
      return 0;
   return parts.year * 100 + parts.mon;
  }

int Strategy_PeriodKeyForTime(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts) || parts.year <= 0 ||
      parts.mon < 1 || parts.mon > 12)
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
      parts.mon < 1 || parts.mon > 12 || parts.day < 1 || parts.day > 31)
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

int Strategy_NextMonthKey(const int month_key)
  {
   int year = month_key / 100;
   int month = month_key % 100;
   if(year <= 0 || month < 1 || month > 12)
      return 0;
   ++month;
   if(month > 12)
     {
      month = 1;
      ++year;
     }
   return year * 100 + month;
  }

int Strategy_LabelOffsetSeconds(const datetime current_bar_time,
                                const datetime broker_now)
  {
   if(current_bar_time <= 0 || broker_now < current_bar_time)
      return -1;
   const long elapsed = (long)(broker_now - current_bar_time);
   if(elapsed < 86400L)
      return 0;
   if(elapsed < 172800L)
      return 86400;
   return -1;
  }

datetime Strategy_NormalizedLabel(const datetime raw_label,
                                  const int label_offset)
  {
   if(raw_label <= 0 || (label_offset != 0 && label_offset != 86400))
      return 0;
   return raw_label + (datetime)label_offset;
  }

string Strategy_AttemptStateName()
  {
   return "QM5_41056_XTIXNG_REV18_ATTEMPT";
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

bool Strategy_IsPairMagic(const long magic)
  {
   const int xti_magic = QM_MagicChecked(qm_ea_id, 0, g_leg_xti);
   const int xng_magic = QM_MagicChecked(qm_ea_id, 1, g_leg_xng);
   return (magic == xti_magic || magic == xng_magic);
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
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsPairPosition())
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
      return true;

   const int deal_count = HistoryDealsTotal();
   for(int i = deal_count - 1; i >= 0; --i)
     {
      const ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0)
         continue;
      const long magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
      if(!Strategy_IsPairMagic(magic))
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

bool Strategy_PairCompositionValid(const int expected_pair_direction = 0)
  {
   int xti_direction = 0;
   int xng_direction = 0;
   int xti_count = 0;
   int xng_count = 0;
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
      if(symbol == g_leg_xti)
        {
         xti_direction = direction;
         ++xti_count;
        }
      else if(symbol == g_leg_xng)
        {
         xng_direction = direction;
         ++xng_count;
        }
     }
   if(!stops_valid || xti_count != 1 || xng_count != 1 ||
      xti_direction != -xng_direction)
      return false;
   if(expected_pair_direction != 0 && xti_direction != expected_pair_direction)
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

void Strategy_ShiftMonths(const MqlDateTime &base,
                          const int months_back,
                          MqlDateTime &shifted)
  {
   shifted = base;
   const int absolute_month = base.year * 12 + (base.mon - 1) - months_back;
   shifted.year = absolute_month / 12;
   shifted.mon = absolute_month % 12 + 1;
   shifted.day = 1;
   shifted.hour = 0;
   shifted.min = 0;
   shifted.sec = 0;
  }

bool Strategy_ReversalReturn(const string symbol,
                             const datetime decision_bar_time,
                             const int label_offset,
                             double &reversal_return,
                             datetime &end_close_time,
                             datetime &reversal_close_time)
  {
   reversal_return = 0.0;
   end_close_time = 0;
   reversal_close_time = 0;

   const datetime normalized_decision_time =
      Strategy_NormalizedLabel(decision_bar_time, label_offset);
   if(normalized_decision_time <= 0)
      return false;

   MqlDateTime decision_dt;
   ZeroMemory(decision_dt);
   TimeToStruct(normalized_decision_time, decision_dt);
   if(decision_dt.year <= 0 || decision_dt.mon < 1 || decision_dt.mon > 12)
      return false;

   MqlDateTime end_dt;
   MqlDateTime reversal_dt;
   Strategy_ShiftMonths(decision_dt, 0, end_dt);
   Strategy_ShiftMonths(end_dt, strategy_reversal_months, reversal_dt);
   const datetime end_boundary = StructToTime(end_dt);
   const datetime reversal_boundary = StructToTime(reversal_dt);
   if(end_boundary <= 0 || reversal_boundary <= 0 ||
      end_boundary <= reversal_boundary)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int count = CopyRates(symbol, PERIOD_D1, 1, strategy_history_bars, rates); // perf-allowed: bounded monthly signal copy.
   if(count < 360)
      return false;

   double end_close = 0.0;
   double reversal_close = 0.0;
   for(int i = 0; i < count; ++i)
     {
      const datetime bar_time =
         Strategy_NormalizedLabel(rates[i].time, label_offset);
      const double close_price = rates[i].close;
      if(bar_time <= 0 || close_price <= 0.0 ||
         !MathIsValidNumber(close_price))
         continue;
      if(end_close_time == 0 && bar_time < end_boundary)
        {
         end_close_time = bar_time;
         end_close = close_price;
        }
      if(reversal_close_time == 0 && bar_time < reversal_boundary)
        {
         reversal_close_time = bar_time;
         reversal_close = close_price;
        }
      if(end_close_time > 0 && reversal_close_time > 0)
         break;
     }

   if(end_close_time <= 0 || reversal_close_time <= 0 ||
      end_close <= 0.0 || reversal_close <= 0.0 ||
      end_close_time <= reversal_close_time)
      return false;

   const long max_gap_seconds = (long)strategy_max_boundary_gap_days * 86400;
   const long end_gap = (long)(end_boundary - end_close_time);
   const long reversal_gap = (long)(reversal_boundary - reversal_close_time);
   if(end_gap <= 0 || reversal_gap <= 0 ||
      end_gap > max_gap_seconds || reversal_gap > max_gap_seconds)
      return false;

   reversal_return = MathLog(end_close / reversal_close);
   return MathIsValidNumber(reversal_return);
  }

bool Strategy_LoadSignalState(const datetime decision_bar_time,
                              int &pair_direction)
  {
   pair_direction = 0;
   g_cache_xti_reversal = 0.0;
   g_cache_xng_reversal = 0.0;
   g_cache_reversal_difference = 0.0;

   datetime xti_end_time = 0;
   datetime xti_start_time = 0;
   datetime xng_end_time = 0;
   datetime xng_start_time = 0;
   if(!Strategy_ReversalReturn(g_leg_xti,
                               decision_bar_time,
                               g_decision_label_offset,
                               g_cache_xti_reversal,
                               xti_end_time,
                               xti_start_time))
      return false;
   if(!Strategy_ReversalReturn(g_leg_xng,
                               decision_bar_time,
                               g_decision_label_offset,
                               g_cache_xng_reversal,
                               xng_end_time,
                               xng_start_time))
      return false;
   if(xti_end_time != xng_end_time || xti_start_time != xng_start_time)
      return false;

   g_cache_reversal_difference = g_cache_xti_reversal - g_cache_xng_reversal;
   if(!MathIsValidNumber(g_cache_reversal_difference))
      return false;

   // Negative difference means XTI is the 18-month loser: buy XTI/sell XNG.
   if(g_cache_reversal_difference < -strategy_signal_epsilon)
      pair_direction = 1;
   else if(g_cache_reversal_difference > strategy_signal_epsilon)
      pair_direction = -1;
   return true;
  }

void Strategy_AdvanceSignal_OnNewBar()
  {
   g_monthly_rebalance_bar = false;
   g_cache_signal_valid = false;
   g_cache_pair_direction = 0;
   g_cache_month_key = 0;
   g_cache_period_key = 0;
   g_cache_decision_bar_time = 0;
   g_decision_label_offset = 0;

   MqlRates decision_bar;
   MqlRates previous_bar;
   ZeroMemory(decision_bar);
   ZeroMemory(previous_bar);
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 0, decision_bar) ||
      !QM_ReadBar(_Symbol, PERIOD_D1, 1, previous_bar))
      return;

   const datetime broker_now = TimeCurrent();
   const int label_offset =
      Strategy_LabelOffsetSeconds(decision_bar.time, broker_now);
   if(label_offset < 0)
      return;

   const datetime current_session =
      Strategy_NormalizedLabel(decision_bar.time, label_offset);
   const datetime previous_session =
      Strategy_NormalizedLabel(previous_bar.time, label_offset);
   if(current_session <= previous_session ||
      Strategy_DateKeyForTime(current_session) !=
         Strategy_DateKeyForTime(broker_now))
      return;

   const int current_month_key = Strategy_MonthKeyForTime(current_session);
   const int prior_month_key = Strategy_MonthKeyForTime(previous_session);
   if(current_month_key <= 0 || prior_month_key <= 0 ||
      Strategy_NextMonthKey(prior_month_key) != current_month_key)
      return;

   g_monthly_rebalance_bar = true;
   g_cache_month_key = current_month_key;
   g_cache_period_key = Strategy_PeriodKeyForTime(current_session);
   g_cache_decision_bar_time = decision_bar.time;
   g_decision_label_offset = label_offset;
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
                           const double atr,
                           const double risk_weight,
                           const double risk_weight_sum)
  {
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(!MathIsValidNumber(atr) || atr <= 0.0 || point <= 0.0 ||
      risk_weight <= 0.0 || risk_weight_sum <= 0.0)
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

bool Strategy_BuildLegRequest(const string symbol,
                              const QM_OrderType type,
                              const double risk_weight,
                              const double risk_weight_sum,
                              const string reason,
                              QM_BasketOrderRequest &req)
  {
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0 || QM_MagicChecked(qm_ea_id, slot, symbol) <= 0 ||
      !Strategy_SpreadAllowed(symbol))
      return false;

   const double entry = QM_OrderTypeIsBuy(type) ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                                : SymbolInfoDouble(symbol, SYMBOL_BID);
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   const double stop_dist = strategy_atr_sl_mult * atr;
   const double lots = Strategy_LotsForLeg(symbol, atr, risk_weight, risk_weight_sum);
   if(!MathIsValidNumber(stop_dist) || stop_dist <= 0.0 || lots <= 0.0)
      return false;

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
   return (req.sl > 0.0);
  }

bool Strategy_OpenPair(const int pair_direction)
  {
   if(pair_direction == 0 || Strategy_OpenPairLegCount() > 0)
      return false;
   if(!Strategy_SpreadAllowed(g_leg_xti) || !Strategy_SpreadAllowed(g_leg_xng))
      return false;

   const bool long_xti_short_xng = (pair_direction > 0);
   const QM_OrderType xti_type = long_xti_short_xng ? QM_BUY : QM_SELL;
   const QM_OrderType xng_type = long_xti_short_xng ? QM_SELL : QM_BUY;
   const string reason = long_xti_short_xng ? "QM5_41056_LONG_XTI_SHORT_XNG_REV18"
                                             : "QM5_41056_SHORT_XTI_LONG_XNG_REV18";
   const double weight_sum = 2.0;

   // The approved atomicity contract requires both frozen-stop requests and
   // both half-budget lot sizes to be valid before the first order is sent.
   QM_BasketOrderRequest xti_req;
   QM_BasketOrderRequest xng_req;
   if(!Strategy_BuildLegRequest(g_leg_xti, xti_type, 1.0, weight_sum, reason, xti_req) ||
      !Strategy_BuildLegRequest(g_leg_xng, xng_type, 1.0, weight_sum, reason, xng_req))
      return false;

   ulong xti_ticket = 0;
   const bool xti_ok = QM_BasketOpenPosition(qm_ea_id,
                                              qm_news_mode_legacy,
                                              strategy_deviation_points,
                                              xti_req,
                                              xti_ticket);
   if(!xti_ok)
      return false;

   ulong xng_ticket = 0;
   const bool xng_ok = QM_BasketOpenPosition(qm_ea_id,
                                              qm_news_mode_legacy,
                                              strategy_deviation_points,
                                              xng_req,
                                              xng_ticket);
   if(xti_ok && xng_ok &&
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
   if(qm_ea_id != 41056 || qm_magic_slot_offset != 0 || qm_rng_seed != 42)
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
   if(strategy_reversal_months != 18)
      return true;
   if(strategy_history_bars != 520 || strategy_max_boundary_gap_days != 10 ||
      MathAbs(strategy_signal_epsilon - 1.0e-12) > 1.0e-18)
      return true;
   if(strategy_atr_period_d1 != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.5) > 1.0e-12 ||
      strategy_max_hold_days != 35)
      return true;
   if(strategy_xti_max_spread_pts != 1500 ||
      strategy_xng_max_spread_pts != 3000 ||
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
   req.reason = "QM5_41056_XTI_XNG_REV18_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_monthly_rebalance_bar || g_cache_month_key <= 0 ||
      g_cache_period_key <= 0 || g_cache_decision_bar_time <= 0)
      return false;
   if(!Strategy_ConsumePeriodAttempt(g_cache_period_key))
      return false;
   if(Strategy_PeriodAlreadyEntered(g_cache_period_key, g_cache_month_key))
      return false;
   if(Strategy_OpenPairLegCount() > 0)
      return false;
   if(!Strategy_NewsAllowsEntry(TimeCurrent()))
      return false;

   g_cache_signal_valid =
      Strategy_LoadSignalState(g_cache_decision_bar_time,
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
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return;
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
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
     {
      if(!QM_NewsAllowsTrade2(g_leg_xti, broker_time, qm_news_temporal, qm_news_compliance))
         return false;
      if(!QM_NewsAllowsTrade2(g_leg_xng, broker_time, qm_news_temporal, qm_news_compliance))
         return false;
     }
   else
     {
      if(!QM_NewsAllowsTrade(g_leg_xti, broker_time, qm_news_mode_legacy))
         return false;
      if(!QM_NewsAllowsTrade(g_leg_xng, broker_time, qm_news_mode_legacy))
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
   const string attempt_state_name = Strategy_AttemptStateName();
   const int current_period_key = Strategy_PeriodKeyForTime(TimeCurrent());
   if(current_period_key > 0 && GlobalVariableCheck(attempt_state_name))
     {
      const double stored_value = GlobalVariableGet(attempt_state_name);
      if(MathIsValidNumber(stored_value) &&
         (int)MathRound(stored_value) > current_period_key)
         GlobalVariableDel(attempt_state_name);
     }

   SymbolSelect(g_leg_xti, true);
   SymbolSelect(g_leg_xng, true);

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

   string basket_symbols[2] = {g_leg_xti, g_leg_xng};
   QM_SymbolGuardInit(basket_symbols);
   const int xti_magic = QM_FrameworkRegisterMagicSymbol(qm_ea_id, 0, g_leg_xti);
   const int xng_magic = QM_FrameworkRegisterMagicSymbol(qm_ea_id, 1, g_leg_xng);
   if(xti_magic <= 0 || xng_magic <= 0 || xti_magic == xng_magic)
     {
      QM_LogEvent(QM_ERROR,
                  "BASKET_MAGIC_REGISTRATION_FAILED",
                  StringFormat("{\"xti_magic\":%d,\"xng_magic\":%d}",
                               xti_magic,
                               xng_magic));
      return INIT_FAILED;
     }
   QM_BasketWarmupHistory(basket_symbols, PERIOD_D1, MathMax(450, strategy_history_bars));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_41056\",\"ea\":\"energy-rev18\"}");
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

   if(Strategy_NoTradeFilter() || !new_bar)
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
