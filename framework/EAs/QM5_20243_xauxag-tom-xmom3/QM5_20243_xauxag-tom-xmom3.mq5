#property strict
#property version   "5.0"
#property description "QM5_20243 XAU XAG Turn-Of-Month 3-Month Momentum"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_20243 - XAU/XAG Turn-Of-Month 3-Month Cross-Sectional Momentum
// -----------------------------------------------------------------------------
// One opposite-direction precious-metals package per broker-calendar TOM cycle:
//   - cycle window is the last 2 calendar dates plus the next month's day 1
//   - formation is frozen before the cycle month
//   - rank exactly 3 synchronized completed monthly returns for XAU and XAG
//   - buy the higher-average-return leg and short the lower
// Runtime is native MT5 D1/calendar/execution state only; no external feed,
// futures chain, CTA holdings, trained output, ratio z-score, grid, or martingale.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 20243;
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
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = false;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_tom_pre_days            = 2;
input int    strategy_tom_post_days           = 1;
input int    strategy_return_window_months    = 3;
input int    strategy_history_bars            = 500;
input int    strategy_atr_period_d1            = 20;
input double strategy_atr_sl_mult              = 3.5;
input int    strategy_max_hold_days            = 6;
input int    strategy_xau_max_spread_pts       = 1500;
input int    strategy_xag_max_spread_pts       = 3000;
input int    strategy_deviation_points         = 20;

string g_leg_xau = "XAUUSD.DWX";
string g_leg_xag = "XAGUSD.DWX";

bool     g_tom_entry_bar = false;
bool     g_cache_signal_valid = false;
int      g_cache_pair_direction = 0;
int      g_cache_cycle_key = 0;
int      g_last_entry_cycle_key = 0;
int      g_pair_cycle_key = 0;
datetime g_pair_entry_time = 0;
double   g_cache_xau_avg_return = 0.0;
double   g_cache_xag_avg_return = 0.0;
double   g_cache_return_difference = 0.0;
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

int Strategy_DaysInMonth(const int year, const int month)
  {
   if(month == 2)
     {
      const bool leap = ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0));
      return leap ? 29 : 28;
     }
   if(month == 4 || month == 6 || month == 9 || month == 11)
      return 30;
   return 31;
  }

int Strategy_PreviousMonthKey(const int month_key)
  {
   const int year = month_key / 100;
   const int month = month_key % 100;
   if(year <= 0 || month < 1 || month > 12)
      return 0;
   if(month == 1)
      return (year - 1) * 100 + 12;
   return year * 100 + month - 1;
  }

int Strategy_ShiftMonthKeyBack(const int month_key, const int months_back)
  {
   if(months_back < 0)
      return 0;
   int shifted = month_key;
   for(int i = 0; i < months_back; ++i)
     {
      shifted = Strategy_PreviousMonthKey(shifted);
      if(shifted <= 0)
         return 0;
     }
   return shifted;
  }

bool Strategy_IsTomWindow(const datetime value, int &cycle_key)
  {
   cycle_key = 0;
   if(value <= 0)
      return false;

   MqlDateTime parts;
   TimeToStruct(value, parts);
   if(parts.year <= 0 || parts.mon < 1 || parts.mon > 12 || parts.day < 1)
      return false;

   const int current_month_key = parts.year * 100 + parts.mon;
   const int days_in_month = Strategy_DaysInMonth(parts.year, parts.mon);
   if(strategy_tom_pre_days > 0 &&
      parts.day >= days_in_month - strategy_tom_pre_days + 1)
     {
      cycle_key = current_month_key;
      return true;
     }

   if(strategy_tom_post_days > 0 && parts.day <= strategy_tom_post_days)
     {
      cycle_key = Strategy_PreviousMonthKey(current_month_key);
      return (cycle_key > 0);
     }
   return false;
  }

bool Strategy_SpreadAllowed(const string symbol)
  {
   const long spread_points = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(spread_points < 0)
      return false;
   if(symbol == g_leg_xau)
      return (spread_points <= strategy_xau_max_spread_pts);
   if(symbol == g_leg_xag)
      return (spread_points <= strategy_xag_max_spread_pts);
   return false;
  }

bool Strategy_IsPairPosition()
  {
   const string symbol = PositionGetString(POSITION_SYMBOL);
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0)
      return false;
   return ((int)PositionGetInteger(POSITION_MAGIC) ==
           QM_MagicChecked(qm_ea_id, slot, symbol));
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

string Strategy_AttemptStateName()
  {
   return "QM5_20243_XAUXAG_TOM_XMOM3_ATTEMPT";
  }

bool Strategy_ConsumeCycleAttempt(const int cycle_key)
  {
   if(cycle_key <= 0)
      return false;

   const string state_name = Strategy_AttemptStateName();
   if(GlobalVariableCheck(state_name))
     {
      const double stored_value = GlobalVariableGet(state_name);
      if(!MathIsValidNumber(stored_value))
         return false;
      const int stored_cycle_key = (int)MathRound(stored_value);
      if(stored_cycle_key >= cycle_key)
         return false;
     }

   if(GlobalVariableSet(state_name, (double)cycle_key) <= 0)
      return false;
   GlobalVariablesFlush();
   return true;
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
      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
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
   g_pair_cycle_key = 0;
  }

bool Strategy_CollectTargetMonthEnds(const string symbol,
                                     const int cycle_key,
                                     double &month_closes[],
                                     datetime &month_times[],
                                     int &month_keys[])
  {
   const int required_month_closes = strategy_return_window_months + 1;
   if(cycle_key <= 0 || required_month_closes != 4)
      return false;

   if(ArrayResize(month_closes, required_month_closes) != required_month_closes ||
      ArrayResize(month_times, required_month_closes) != required_month_closes ||
      ArrayResize(month_keys, required_month_closes) != required_month_closes)
      return false;

   const int newest_target_key = Strategy_PreviousMonthKey(cycle_key);
   if(newest_target_key <= 0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int count = CopyRates(symbol, PERIOD_D1, 1, strategy_history_bars, rates); // perf-allowed: bounded monthly endpoint scan only on a consumed TOM decision bar.
   if(count < required_month_closes)
      return false;

   for(int target_index = 0; target_index < required_month_closes; ++target_index)
     {
      const int target_key = Strategy_ShiftMonthKeyBack(newest_target_key,
                                                        target_index);
      if(target_key <= 0)
         return false;

      bool found = false;
      for(int rate_index = 0; rate_index < count; ++rate_index)
        {
         if(Strategy_MonthKeyForTime(rates[rate_index].time) != target_key)
            continue;
         if(rates[rate_index].close <= 0.0 ||
            !MathIsValidNumber(rates[rate_index].close))
            return false;
         month_closes[target_index] = rates[rate_index].close;
         month_times[target_index] = rates[rate_index].time;
         month_keys[target_index] = target_key;
         found = true;
         break;
        }
      if(!found)
         return false;
     }
   return true;
  }

bool Strategy_AverageReturnFromEnds(const double &month_closes[],
                                    const int &month_keys[],
                                    double &average_return,
                                    int &observation_count)
  {
   average_return = 0.0;
   observation_count = 0;

   const int required_month_closes = strategy_return_window_months + 1;
   if(ArraySize(month_closes) != required_month_closes ||
      ArraySize(month_keys) != required_month_closes)
      return false;

   double return_sum = 0.0;
   for(int i = 0; i < strategy_return_window_months; ++i)
     {
      if(month_keys[i + 1] != Strategy_PreviousMonthKey(month_keys[i]))
         return false;
      const double newer_close = month_closes[i];
      const double older_close = month_closes[i + 1];
      if(newer_close <= 0.0 || older_close <= 0.0)
         return false;
      const double value = newer_close / older_close - 1.0;
      if(!MathIsValidNumber(value))
         return false;
      return_sum += value;
      ++observation_count;
     }

   if(observation_count != strategy_return_window_months)
      return false;
   average_return = return_sum / (double)observation_count;
   return MathIsValidNumber(average_return);
  }

bool Strategy_LoadSignalState(const int cycle_key, int &pair_direction)
  {
   pair_direction = 0;
   g_cache_xau_avg_return = 0.0;
   g_cache_xag_avg_return = 0.0;
   g_cache_return_difference = 0.0;
   g_cache_xau_observations = 0;
   g_cache_xag_observations = 0;

   double xau_closes[];
   double xag_closes[];
   datetime xau_times[];
   datetime xag_times[];
   int xau_keys[];
   int xag_keys[];
   if(!Strategy_CollectTargetMonthEnds(g_leg_xau,
                                       cycle_key,
                                       xau_closes,
                                       xau_times,
                                       xau_keys) ||
      !Strategy_CollectTargetMonthEnds(g_leg_xag,
                                       cycle_key,
                                       xag_closes,
                                       xag_times,
                                       xag_keys))
      return false;

   const int required_month_closes = strategy_return_window_months + 1;
   for(int i = 0; i < required_month_closes; ++i)
     {
      if(xau_keys[i] != xag_keys[i] || xau_times[i] != xag_times[i])
         return false;
     }

   if(!Strategy_AverageReturnFromEnds(xau_closes,
                                      xau_keys,
                                      g_cache_xau_avg_return,
                                      g_cache_xau_observations) ||
      !Strategy_AverageReturnFromEnds(xag_closes,
                                      xag_keys,
                                      g_cache_xag_avg_return,
                                      g_cache_xag_observations))
      return false;

   g_cache_return_difference = g_cache_xau_avg_return - g_cache_xag_avg_return;
   if(!MathIsValidNumber(g_cache_return_difference))
      return false;
   if(g_cache_return_difference > 1.0e-10)
      pair_direction = 1;
   else if(g_cache_return_difference < -1.0e-10)
      pair_direction = -1;
   return true;
  }

bool Strategy_IsPairMagic(const long magic)
  {
   const int xau_magic = QM_MagicChecked(qm_ea_id, 0, g_leg_xau);
   const int xag_magic = QM_MagicChecked(qm_ea_id, 1, g_leg_xag);
   return (magic == xau_magic || magic == xag_magic);
  }

bool Strategy_CycleAlreadyEntered(const int cycle_key)
  {
   if(cycle_key <= 0)
      return true;
   if(g_last_entry_cycle_key == cycle_key)
      return true;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsPairPosition())
         continue;
      int opened_cycle_key = 0;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(Strategy_IsTomWindow(opened, opened_cycle_key) &&
         opened_cycle_key == cycle_key)
         return true;
     }

   const datetime history_start = TimeCurrent() - 60 * 86400;
   if(history_start <= 0 || !HistorySelect(history_start, TimeCurrent()))
      return true;

   const int deal_count = HistoryDealsTotal();
   for(int i = deal_count - 1; i >= 0; --i)
     {
      const ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0)
         continue;
      if(!Strategy_IsPairMagic(HistoryDealGetInteger(deal_ticket, DEAL_MAGIC)))
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      int deal_cycle_key = 0;
      const datetime deal_time =
         (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      if(Strategy_IsTomWindow(deal_time, deal_cycle_key) &&
         deal_cycle_key == cycle_key)
         return true;
     }
   return false;
  }

void Strategy_AdvanceSignal_OnNewBar()
  {
   g_tom_entry_bar = false;
   g_cache_signal_valid = false;
   g_cache_pair_direction = 0;
   g_cache_cycle_key = 0;

   const datetime current_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: one D1 calendar lookup behind new-bar.
   int cycle_key = 0;
   if(!Strategy_IsTomWindow(current_bar_time, cycle_key) || cycle_key <= 0)
      return;

   g_tom_entry_bar = true;
   g_cache_cycle_key = cycle_key;
  }

bool Strategy_MaxHoldExceeded()
  {
   datetime entry_time = g_pair_entry_time;
   if(entry_time <= 0)
      entry_time = Strategy_CurrentPairEntryTime();
   if(entry_time <= 0)
      return false;
   const long hold_seconds = (long)strategy_max_hold_days * 86400;
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

   const double entry = QM_OrderTypeIsBuy(type)
                        ? SymbolInfoDouble(symbol, SYMBOL_ASK)
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
   req.sl = QM_OrderTypeIsBuy(type)
            ? NormalizeDouble(entry - stop_dist, digits)
            : NormalizeDouble(entry + stop_dist, digits);
   req.tp = 0.0;
   req.lots = lots;
   req.reason = reason;
   req.symbol_slot = slot;
   req.expiration_seconds = 0;
   return (req.sl > 0.0 && MathIsValidNumber(req.sl));
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

bool Strategy_OpenPair(const int pair_direction, const int cycle_key)
  {
   if(pair_direction == 0 || cycle_key <= 0 || Strategy_OpenPairLegCount() > 0)
      return false;
   if(!Strategy_SpreadAllowed(g_leg_xau) || !Strategy_SpreadAllowed(g_leg_xag))
      return false;

   const bool long_xau_short_xag = (pair_direction > 0);
   const QM_OrderType xau_type = long_xau_short_xag ? QM_BUY : QM_SELL;
   const QM_OrderType xag_type = long_xau_short_xag ? QM_SELL : QM_BUY;
   const string reason = long_xau_short_xag
                         ? "QM5_20243_TOM_LONG_XAU_SHORT_XAG_XMOM3"
                         : "QM5_20243_TOM_SHORT_XAU_LONG_XAG_XMOM3";
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
      g_pair_cycle_key = cycle_key;
      return true;
     }

   Strategy_ClosePair(QM_EXIT_STRATEGY);
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart())
      return true;
   if(qm_ea_id != 20243 || qm_magic_slot_offset != 0)
      return true;
   if(strategy_tom_pre_days != 2 || strategy_tom_post_days != 1 ||
      strategy_return_window_months != 3 || strategy_history_bars != 500)
      return true;
   if(strategy_atr_period_d1 != 20 || strategy_atr_sl_mult != 3.5 ||
      strategy_max_hold_days != 6)
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
   req.reason = "QM5_20243_XAU_XAG_TOM_XMOM3_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_tom_entry_bar || g_cache_cycle_key <= 0)
      return false;
   if(!Strategy_ConsumeCycleAttempt(g_cache_cycle_key))
      return false;
   if(Strategy_CycleAlreadyEntered(g_cache_cycle_key))
      return false;
   if(Strategy_OpenPairLegCount() > 0)
      return false;
   if(!Strategy_NewsAllowsEntry(TimeCurrent()))
      return false;

   g_cache_signal_valid = Strategy_LoadSignalState(g_cache_cycle_key,
                                                    g_cache_pair_direction);
   if(!g_cache_signal_valid || g_cache_pair_direction == 0)
      return false;

   if(Strategy_OpenPair(g_cache_pair_direction, g_cache_cycle_key))
      g_last_entry_cycle_key = g_cache_cycle_key;
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int open_legs = Strategy_OpenPairLegCount();
   if(open_legs <= 0)
     {
      g_pair_entry_time = 0;
      g_pair_cycle_key = 0;
      return;
     }

   if(open_legs != 2 || !Strategy_PairCompositionValid())
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return;
     }

   const datetime current_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: package lifecycle calendar check.
   int current_cycle_key = 0;
   if(!Strategy_IsTomWindow(current_bar_time, current_cycle_key))
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return;
     }

   int entry_cycle_key = g_pair_cycle_key;
   if(entry_cycle_key <= 0)
     {
      const datetime entry_time = Strategy_CurrentPairEntryTime();
      if(!Strategy_IsTomWindow(entry_time, entry_cycle_key))
        {
         Strategy_ClosePair(QM_EXIT_STRATEGY);
         return;
        }
      g_pair_cycle_key = entry_cycle_key;
     }

   if(current_cycle_key != entry_cycle_key)
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
   // Tester time rewinds between passes. Isolate the persistent attempt ledger
   // while retaining terminal-restart persistence outside the tester.
   if((bool)MQLInfoInteger(MQL_TESTER))
      GlobalVariableDel(Strategy_AttemptStateName());

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
                          MathMax(1200, strategy_history_bars));

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_20243\",\"ea\":\"xauxag-tom-xmom3\"}");
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
   g_tom_entry_bar = false;
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
