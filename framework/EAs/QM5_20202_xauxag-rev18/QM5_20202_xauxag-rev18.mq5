#property strict
#property version   "5.0"
#property description "QM5_20202 XAU XAG 18-Month Cross-Sectional Reversal"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_20202 - XAU/XAG 18-Month Cross-Sectional Reversal
// -----------------------------------------------------------------------------
// Monthly opposite-leg precious-metal structural package:
//   - rank XAU and XAG on synchronized 18-completed-month log returns
//   - buy the long-horizon loser and short the winner
//   - remain flat only on an exact numerical tie
// Runtime is Darwinex-native D1 close data only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20202;
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
input int    strategy_atr_period_d1            = 20;
input double strategy_atr_sl_mult              = 3.5;
input int    strategy_max_hold_days            = 35;
input int    strategy_xau_max_spread_pts       = 1500;
input int    strategy_xag_max_spread_pts       = 3000;
input int    strategy_deviation_points         = 20;

string g_leg_xau = "XAUUSD.DWX";
string g_leg_xag = "XAGUSD.DWX";

bool     g_monthly_rebalance_bar = false;
bool     g_cache_signal_valid = false;
int      g_cache_pair_direction = 0;
int      g_cache_month_key = 0;
int      g_cache_period_key = 0;
int      g_last_entry_period_key = 0;
datetime g_cache_decision_bar_time = 0;
datetime g_pair_entry_time = 0;
double   g_cache_xau_reversal = 0.0;
double   g_cache_xag_reversal = 0.0;
double   g_cache_reversal_difference = 0.0;

bool Strategy_NewsAllowsEntry(const datetime broker_time);

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
   return parts.year * 12 + parts.mon;
  }

string Strategy_AttemptStateName()
  {
   return "QM5_20202_XAUXAG_REV18_ATTEMPT";
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
                             double &reversal_return)
  {
   reversal_return = 0.0;

   MqlDateTime decision_dt;
   ZeroMemory(decision_dt);
   TimeToStruct(decision_bar_time, decision_dt);
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
   datetime end_close_time = 0;
   datetime reversal_close_time = 0;
   for(int i = 0; i < count; ++i)
     {
      const datetime bar_time = rates[i].time;
      const double close_price = rates[i].close;
      if(close_price <= 0.0 || !MathIsValidNumber(close_price))
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
   g_cache_xau_reversal = 0.0;
   g_cache_xag_reversal = 0.0;
   g_cache_reversal_difference = 0.0;

   if(!Strategy_ReversalReturn(g_leg_xau, decision_bar_time,
                               g_cache_xau_reversal))
      return false;
   if(!Strategy_ReversalReturn(g_leg_xag, decision_bar_time,
                               g_cache_xag_reversal))
      return false;

   g_cache_reversal_difference = g_cache_xau_reversal - g_cache_xag_reversal;
   if(!MathIsValidNumber(g_cache_reversal_difference))
      return false;

   const double rank_epsilon = 1.0e-10;
   // Negative difference means XAU is the 18-month loser: buy XAU/sell XAG.
   if(g_cache_reversal_difference < -rank_epsilon)
      pair_direction = 1;
   else if(g_cache_reversal_difference > rank_epsilon)
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

   const datetime decision_bar_time =
      iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: cached timestamp on D1 new-bar path.
   const datetime prior_bar_time =
      iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: exact monthly D1 transition check.
   const int current_month_key = Strategy_MonthKeyForTime(decision_bar_time);
   const int prior_month_key = Strategy_MonthKeyForTime(prior_bar_time);
   if(current_month_key <= 0 || prior_month_key <= 0 ||
      current_month_key == prior_month_key)
      return;

   g_monthly_rebalance_bar = true;
   g_cache_month_key = current_month_key;
   g_cache_period_key = Strategy_PeriodKeyForTime(decision_bar_time);
   g_cache_decision_bar_time = decision_bar_time;
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
   if(!Strategy_SpreadAllowed(g_leg_xau) || !Strategy_SpreadAllowed(g_leg_xag))
      return false;

   const bool long_xau_short_xag = (pair_direction > 0);
   const QM_OrderType xau_type = long_xau_short_xag ? QM_BUY : QM_SELL;
   const QM_OrderType xag_type = long_xau_short_xag ? QM_SELL : QM_BUY;
   const string reason = long_xau_short_xag ? "QM5_20202_LONG_XAU_SHORT_XAG_REV18"
                                             : "QM5_20202_SHORT_XAU_LONG_XAG_REV18";
   const double weight_sum = 2.0;

   // The approved atomicity contract requires both frozen-stop requests and
   // both half-budget lot sizes to be valid before the first order is sent.
   QM_BasketOrderRequest xau_req;
   QM_BasketOrderRequest xag_req;
   if(!Strategy_BuildLegRequest(g_leg_xau, xau_type, 1.0, weight_sum, reason, xau_req) ||
      !Strategy_BuildLegRequest(g_leg_xag, xag_type, 1.0, weight_sum, reason, xag_req))
      return false;

   ulong xau_ticket = 0;
   const bool xau_ok = QM_BasketOpenPosition(qm_ea_id,
                                              qm_news_mode_legacy,
                                              strategy_deviation_points,
                                              xau_req,
                                              xau_ticket);
   if(!xau_ok)
      return false;

   ulong xag_ticket = 0;
   const bool xag_ok = QM_BasketOpenPosition(qm_ea_id,
                                              qm_news_mode_legacy,
                                              strategy_deviation_points,
                                              xag_req,
                                              xag_ticket);
   if(xau_ok && xag_ok &&
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
   if(qm_ea_id != 20202 || qm_magic_slot_offset != 0 || qm_rng_seed != 42)
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
   if(strategy_history_bars != 520 || strategy_max_boundary_gap_days != 10)
      return true;
   if(strategy_atr_period_d1 != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.5) > 1.0e-12 ||
      strategy_max_hold_days != 35)
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
   req.reason = "QM5_20202_XAU_XAG_REV18_HOST";
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
   const int xau_magic = QM_FrameworkRegisterMagicSymbol(qm_ea_id, 0, g_leg_xau);
   const int xag_magic = QM_FrameworkRegisterMagicSymbol(qm_ea_id, 1, g_leg_xag);
   if(xau_magic != 202020000 || xag_magic != 202020001)
     {
      QM_LogEvent(QM_ERROR,
                  "INIT_MAGIC_REGISTRATION_FAILED",
                  StringFormat("{\"xau_magic\":%d,\"xag_magic\":%d}",
                               xau_magic,
                               xag_magic));
      return INIT_FAILED;
     }
   QM_BasketWarmupHistory(basket_symbols, PERIOD_D1, MathMax(450, strategy_history_bars));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_20202\",\"ea\":\"xauxag-rev18\"}");
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
