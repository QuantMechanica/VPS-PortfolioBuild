#property strict
#property version   "5.0"
#property description "QM5_20234 XAU XAG Relative Signed Jump Rank"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_20234 - XAU/XAG Relative-Signed-Jump Rank
// -----------------------------------------------------------------------------
// Monthly market-neutral precious-metal basket:
//   - calculate synchronized XAU/XAG relative signed jump (RSJ) from simple
//     D1 returns in the immediately preceding complete broker month
//   - long the lower-RSJ precious-metal leg and short the higher-RSJ leg
// Runtime is Darwinex-native D1 OHLC only; no external or futures-chain data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20234;
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
input int    strategy_lookback_months        = 1;
input int    strategy_history_bars           = 80;
input int    strategy_min_return_observations = 15;
input int    strategy_atr_period_d1          = 20;
input double strategy_atr_sl_mult            = 3.5;
input int    strategy_max_hold_days          = 35;
input int    strategy_xau_max_spread_pts     = 1500;
input int    strategy_xag_max_spread_pts     = 3000;
input int    strategy_deviation_points       = 20;

string g_leg_xau = "XAUUSD.DWX";
string g_leg_xag = "XAGUSD.DWX";

bool     g_monthly_rebalance_bar = false;
bool     g_cache_signal_valid = false;
int      g_cache_pair_direction = 0;
int      g_cache_month_key = 0;
int      g_last_attempt_month_key = 0;
datetime g_decision_bar_time = 0;
datetime g_pair_entry_time = 0;
string   g_attempt_state_key = "";
double   g_cache_xau_rsj = 0.0;
double   g_cache_xag_rsj = 0.0;
double   g_cache_rsj_difference = 0.0;
int      g_cache_xau_observations = 0;
int      g_cache_xag_observations = 0;

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

bool Strategy_MonthAlreadyEntered(const int month_key,
                                  const datetime decision_bar_time)
  {
   if(month_key <= 0 || decision_bar_time <= 0)
      return true;

   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsPairPosition())
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(Strategy_MonthKey(opened) == month_key)
         return true;
     }

   const datetime history_start = decision_bar_time - (long)45 * 86400;
   if(history_start <= 0 || !HistorySelect(history_start, TimeCurrent()))
      return true;

   const int deal_count = HistoryDealsTotal();
   for(int index = deal_count - 1; index >= 0; --index)
     {
      const ulong deal_ticket = HistoryDealGetTicket(index);
      if(deal_ticket == 0)
         continue;
      const string symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
      const int slot = Strategy_SlotForSymbol(symbol);
      if(slot < 0 ||
         (int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) !=
            QM_MagicChecked(qm_ea_id, slot, symbol))
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
   if(g_attempt_state_key == "" || !GlobalVariableCheck(g_attempt_state_key))
      return;

   const int current_month_key =
      QM_CalendarPeriodKey(PERIOD_MN1, g_leg_xau, 0);
   const double stored = GlobalVariableGet(g_attempt_state_key);
   const int stored_month_key = (int)MathRound(stored);
   if(current_month_key > 0 && MathIsValidNumber(stored) &&
      stored_month_key >= 190001 && stored_month_key <= current_month_key)
     {
      g_last_attempt_month_key = stored_month_key;
      return;
     }

   // Tester globals can outlive a later historical rerun. A future marker
   // must not suppress a deterministic rerun from its earlier start date.
   GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordMonthAttempt(const int month_key)
  {
   if(month_key <= 0 || g_attempt_state_key == "")
      return false;
   if(GlobalVariableSet(g_attempt_state_key, (double)month_key) <= 0)
      return false;
   GlobalVariablesFlush();
   g_last_attempt_month_key = month_key;
   return true;
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

bool Strategy_PairCompositionValid()
  {
   int xau_direction = 0;
   int xag_direction = 0;
   int xau_count = 0;
   int xag_count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsPairPosition())
         continue;
      const string symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const int direction = (position_type == POSITION_TYPE_BUY) ? 1 : -1;
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
   return (xau_count == 1 && xag_count == 1 && xau_direction == -xag_direction);
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

bool Strategy_FormationWindow(const datetime decision_bar_time,
                              datetime &window_start,
                              datetime &window_end)
  {
   window_start = 0;
   window_end = 0;
   MqlDateTime decision_dt;
   TimeToStruct(decision_bar_time, decision_dt);
   if(decision_dt.year <= 0 || decision_dt.mon < 1 || decision_dt.mon > 12)
      return false;

   MqlDateTime end_dt;
   Strategy_ShiftMonths(decision_dt, 0, end_dt);
   MqlDateTime start_dt;
   Strategy_ShiftMonths(end_dt, strategy_lookback_months, start_dt);
   window_start = StructToTime(start_dt);
   window_end = StructToTime(end_dt);
   return (window_start > 0 && window_end > window_start);
  }

int Strategy_FindRateByTime(const MqlRates &rates[],
                            const int count,
                            const datetime target)
  {
   for(int index = 0; index < count; ++index)
     {
      if(rates[index].time == target)
         return index;
     }
   return -1;
  }

bool Strategy_RelativeSignedJumpPair(const datetime window_start,
                                     const datetime window_end,
                                     double &xau_rsj,
                                     double &xag_rsj,
                                     int &observation_count)
  {
   xau_rsj = 0.0;
   xag_rsj = 0.0;
   observation_count = 0;

   const int requested =
      MathMax(strategy_history_bars, strategy_min_return_observations + 40);
   MqlRates xau_rates[];
   MqlRates xag_rates[];
   ArraySetAsSeries(xau_rates, true);
   ArraySetAsSeries(xag_rates, true);
   const int xau_count =
      CopyRates(g_leg_xau, PERIOD_D1, 1, requested, xau_rates); // perf-allowed: bounded copy only on the monthly decision bar.
   const int xag_count =
      CopyRates(g_leg_xag, PERIOD_D1, 1, requested, xag_rates); // perf-allowed: bounded copy only on the monthly decision bar.
   if(xau_count <= strategy_min_return_observations ||
      xag_count <= strategy_min_return_observations)
      return false;

   double previous_xau_close = 0.0;
   double previous_xag_close = 0.0;
   double xau_rv_plus = 0.0;
   double xau_rv_minus = 0.0;
   double xag_rv_plus = 0.0;
   double xag_rv_minus = 0.0;

   // Walk XAU chronologically and accept only timestamps common to both legs.
   // The prior common close can precede the formation month, preserving the
   // first synchronized return whose ending timestamp is inside that month.
   for(int xau_index = xau_count - 1; xau_index >= 0; --xau_index)
     {
      const datetime bar_time = xau_rates[xau_index].time;
      const int xag_index =
         Strategy_FindRateByTime(xag_rates, xag_count, bar_time);
      if(xag_index < 0)
         continue;

      const double xau_close = xau_rates[xau_index].close;
      const double xag_close = xag_rates[xag_index].close;
      if(xau_close <= 0.0 || xag_close <= 0.0 ||
         !MathIsValidNumber(xau_close) || !MathIsValidNumber(xag_close))
         return false;

      if(previous_xau_close > 0.0 && previous_xag_close > 0.0 &&
         bar_time >= window_start && bar_time < window_end)
        {
         const double xau_return = xau_close / previous_xau_close - 1.0;
         const double xag_return = xag_close / previous_xag_close - 1.0;
         if(!MathIsValidNumber(xau_return) ||
            !MathIsValidNumber(xag_return))
            return false;

         const double xau_squared = xau_return * xau_return;
         const double xag_squared = xag_return * xag_return;
         if(xau_return > 0.0)
            xau_rv_plus += xau_squared;
         else if(xau_return < 0.0)
            xau_rv_minus += xau_squared;
         if(xag_return > 0.0)
            xag_rv_plus += xag_squared;
         else if(xag_return < 0.0)
            xag_rv_minus += xag_squared;
         ++observation_count;
        }

      previous_xau_close = xau_close;
      previous_xag_close = xag_close;
     }

   if(observation_count < strategy_min_return_observations)
      return false;

   const double xau_total_variance = xau_rv_plus + xau_rv_minus;
   const double xag_total_variance = xag_rv_plus + xag_rv_minus;
   if(xau_total_variance <= 1.0e-16 ||
      xag_total_variance <= 1.0e-16 ||
      !MathIsValidNumber(xau_total_variance) ||
      !MathIsValidNumber(xag_total_variance))
      return false;

   xau_rsj = (xau_rv_plus - xau_rv_minus) / xau_total_variance;
   xag_rsj = (xag_rv_plus - xag_rv_minus) / xag_total_variance;
   if(!MathIsValidNumber(xau_rsj) || !MathIsValidNumber(xag_rsj) ||
      xau_rsj < -1.000000001 || xau_rsj > 1.000000001 ||
      xag_rsj < -1.000000001 || xag_rsj > 1.000000001)
      return false;

   xau_rsj = MathMax(-1.0, MathMin(1.0, xau_rsj));
   xag_rsj = MathMax(-1.0, MathMin(1.0, xag_rsj));
   return true;
  }

bool Strategy_LoadSignalState(const datetime decision_bar_time,
                              int &pair_direction)
  {
   pair_direction = 0;
   g_cache_xau_rsj = 0.0;
   g_cache_xag_rsj = 0.0;
   g_cache_rsj_difference = 0.0;
   g_cache_xau_observations = 0;
   g_cache_xag_observations = 0;

   datetime window_start = 0;
   datetime window_end = 0;
   if(!Strategy_FormationWindow(decision_bar_time, window_start, window_end))
      return false;

   int synchronized_observations = 0;
   if(!Strategy_RelativeSignedJumpPair(window_start,
                                       window_end,
                                       g_cache_xau_rsj,
                                       g_cache_xag_rsj,
                                       synchronized_observations))
      return false;
   g_cache_xau_observations = synchronized_observations;
   g_cache_xag_observations = synchronized_observations;

   g_cache_rsj_difference = g_cache_xau_rsj - g_cache_xag_rsj;
   if(!MathIsValidNumber(g_cache_rsj_difference))
      return false;
   if(g_cache_rsj_difference < -1.0e-12)
      pair_direction = 1;
   else if(g_cache_rsj_difference > 1.0e-12)
      pair_direction = -1;
   return true;
  }

void Strategy_AdvanceSignal_OnNewBar()
  {
   g_monthly_rebalance_bar = false;
   g_cache_signal_valid = false;
   g_cache_pair_direction = 0;
   g_decision_bar_time = 0;
   const int current_month_key =
      QM_CalendarPeriodKey(PERIOD_MN1, g_leg_xau, 0);
   const int prior_month_key =
      QM_CalendarPeriodKey(PERIOD_MN1, g_leg_xau, 1);
   if(current_month_key <= 0 || prior_month_key <= 0 || current_month_key == prior_month_key)
      return;

   MqlRates decision_bar;
   if(!QM_ReadBar(g_leg_xau, PERIOD_D1, 0, decision_bar) ||
      decision_bar.time <= 0)
      return;

   g_monthly_rebalance_bar = true;
   g_cache_month_key = current_month_key;
   g_decision_bar_time = decision_bar.time;
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

   QM_BasketOrderRequest req;
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

   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, strategy_deviation_points, req, ticket);
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
   const string reason = long_xau_short_xag ? "QM5_20234_LONG_XAU_SHORT_XAG_LOW_RSJ"
                                            : "QM5_20234_SHORT_XAU_LONG_XAG_LOW_RSJ";
   const double weight_sum = 2.0;

   const bool xau_ok = Strategy_OpenLeg(g_leg_xau, xau_type, 1.0, weight_sum, reason);
   const bool xag_ok = Strategy_OpenLeg(g_leg_xag, xag_type, 1.0, weight_sum, reason);
   if(xau_ok && xag_ok)
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
   if(qm_ea_id != 20234 || qm_magic_slot_offset != 0 || qm_rng_seed != 42)
      return true;
   if(MathAbs(RISK_PERCENT) > 1.0e-12 ||
      MathAbs(RISK_FIXED - 1000.0) > 1.0e-12 ||
      MathAbs(PORTFOLIO_WEIGHT - 1.0) > 1.0e-12)
      return true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE ||
      qm_news_mode_legacy != QM_NEWS_OFF ||
      qm_news_stale_max_hours != 336 ||
      qm_news_min_impact != "high")
      return true;
   if(qm_friday_close_enabled || qm_friday_close_hour_broker != 21 ||
      MathAbs(qm_stress_reject_probability) > 1.0e-12)
      return true;
   if(strategy_lookback_months != 1 || strategy_history_bars != 80 ||
      strategy_min_return_observations != 15 ||
      strategy_atr_period_d1 != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.5) > 1.0e-12 ||
      strategy_max_hold_days != 35 ||
      strategy_xau_max_spread_pts != 1500 ||
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
   req.reason = "QM5_20234_XAU_XAG_RSJ_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_monthly_rebalance_bar || g_cache_month_key <= 0 ||
      g_decision_bar_time <= 0)
      return false;
   if(g_cache_month_key == g_last_attempt_month_key)
      return false;

   // Consume the monthly opportunity before any history, signal, spread,
   // news, quote, stop, or order gate. This ordering is restart-safe.
   if(!Strategy_RecordMonthAttempt(g_cache_month_key))
      return false;
   if(Strategy_OpenPairLegCount() > 0 ||
      Strategy_MonthAlreadyEntered(g_cache_month_key, g_decision_bar_time))
      return false;

   g_cache_signal_valid =
      Strategy_LoadSignalState(g_decision_bar_time, g_cache_pair_direction);
   if(!g_cache_signal_valid || g_cache_pair_direction == 0)
      return false;
   if(Strategy_NewsFilterHook(TimeCurrent()))
      return false;

   Strategy_OpenPair(g_cache_pair_direction);
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
      if(!QM_NewsAllowsTrade2(g_leg_xau, broker_time, qm_news_temporal, qm_news_compliance))
         return false;
      if(!QM_NewsAllowsTrade2(g_leg_xag, broker_time, qm_news_temporal, qm_news_compliance))
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
   if(!Strategy_IsHostChart() || qm_ea_id != 20234 ||
      qm_magic_slot_offset != 0)
      return INIT_PARAMETERS_INCORRECT;
   if(!SymbolSelect(g_leg_xau, true) || !SymbolSelect(g_leg_xag, true))
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

   if(Strategy_NoTradeFilter())
     {
      QM_FrameworkShutdown();
      return INIT_PARAMETERS_INCORRECT;
     }

   g_attempt_state_key =
      StringFormat("QM5_20234_MONTH_ATTEMPT_%d",
                   QM_MagicChecked(qm_ea_id, 0, g_leg_xau));
   Strategy_LoadAttemptState();

   string basket_symbols[2] = {g_leg_xau, g_leg_xag};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols,
                          PERIOD_D1,
                          MathMax(80, strategy_history_bars));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_20234\",\"ea\":\"xauxag-rsj\"}");
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
   if(Strategy_NoTradeFilter())
      return;

   const bool new_bar = QM_IsNewBar();
   g_monthly_rebalance_bar = false;
   if(new_bar)
     {
      QM_EquityStreamOnNewBar();
      Strategy_AdvanceSignal_OnNewBar();
     }

   // Package lifecycle and orphan repair always precede entry-only gates.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return;
     }

   if(!new_bar)
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
