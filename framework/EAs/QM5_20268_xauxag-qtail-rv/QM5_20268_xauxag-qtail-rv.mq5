#property strict
#property version   "5.0"
#property description "QM5_20268 XAU XAG Empirical Quantile Tail Reversion"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_20268 - XAU/XAG Empirical-Quantile Two-Hit Tail Reversion
// -----------------------------------------------------------------------------
// A two-leg D1 relative-value package. A frozen 126-ratio empirical
// distribution excludes three ordered event bars. The package fades only a
// central observation followed by two closes beyond the same outer decile.
// Runtime data is Darwinex-native only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20268;
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
input int    strategy_reference_bars_d1    = 126;
input int    strategy_lower_index          = 12;
input int    strategy_upper_index          = 113;
input int    strategy_exit_median_bars_d1  = 21;
input double strategy_quantile_epsilon     = 0.000000000001;
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_sl_mult          = 3.5;
input int    strategy_max_hold_days        = 35;
input int    strategy_xau_max_spread_pts   = 1500;
input int    strategy_xag_max_spread_pts   = 3000;
input int    strategy_deviation_points     = 20;

string g_leg_xau = "XAUUSD.DWX";
string g_leg_xag = "XAGUSD.DWX";

bool     g_new_d1_bar = false;
datetime g_pair_entry_time = 0;
double   g_latest_ratio = 0.0;
double   g_prior_ratio = 0.0;
double   g_pre_event_ratio = 0.0;
double   g_q10 = 0.0;
double   g_q50 = 0.0;
double   g_q90 = 0.0;
double   g_exit_median = 0.0;
string   g_signal_diagnostic = "UNINITIALIZED";

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
   return (_Symbol == g_leg_xau &&
           _Period == PERIOD_D1 &&
           qm_magic_slot_offset == 0);
  }

bool Strategy_SpreadAllowed(const string symbol)
  {
   const long spread_points = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(spread_points < 0)
      return false;
   if(symbol == g_leg_xau)
      return (strategy_xau_max_spread_pts > 0 &&
              spread_points <= strategy_xau_max_spread_pts);
   if(symbol == g_leg_xag)
      return (strategy_xag_max_spread_pts > 0 &&
              spread_points <= strategy_xag_max_spread_pts);
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
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
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
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsPairPosition())
         continue;
      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && (earliest == 0 || opened < earliest))
         earliest = opened;
     }
   return earliest;
  }

bool Strategy_PairCompositionValid(const int expected_xau_direction = 0)
  {
   int xau_direction = 0;
   int xag_direction = 0;
   int xau_count = 0;
   int xag_count = 0;
   bool stops_valid = true;

   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsPairPosition())
         continue;

      const string symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const int direction =
         (position_type == POSITION_TYPE_BUY) ? 1 : -1;
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
   if(expected_xau_direction != 0 &&
      xau_direction != expected_xau_direction)
      return false;
   return true;
  }

int Strategy_CurrentXauDirection()
  {
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsPairPosition() ||
         PositionGetString(POSITION_SYMBOL) != g_leg_xau)
         continue;
      return ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) ==
              POSITION_TYPE_BUY) ? 1 : -1;
     }
   return 0;
  }

void Strategy_ClosePair(const QM_ExitReason reason)
  {
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsPairPosition())
         QM_TM_ClosePosition(ticket, reason);
     }
   g_pair_entry_time = 0;
  }

string Strategy_AttemptStateName()
  {
   return "QM5_20268_XAUXAG_QTAILRV_D1_ATTEMPT";
  }

bool Strategy_IsPairMagic(const long magic)
  {
   return (magic == (long)QM_MagicChecked(qm_ea_id, 0, g_leg_xau) ||
           magic == (long)QM_MagicChecked(qm_ea_id, 1, g_leg_xag));
  }

bool Strategy_HasEntryDealForDecisionBar(const datetime decision_bar_time)
  {
   if(decision_bar_time <= 0)
      return true;

   const datetime current_bar_time =
      iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: cached current host D1 timestamp on new-bar path.
   const datetime current_decision_bar =
      iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: cached completed host D1 timestamp on new-bar path.
   if(current_bar_time <= 0 ||
      current_decision_bar != decision_bar_time ||
      !HistorySelect(current_bar_time, TimeCurrent()))
      return true; // Fail closed: a restart must not repeat this decision-bar package.

   const int deal_count = HistoryDealsTotal();
   for(int index = deal_count - 1; index >= 0; --index)
     {
      const ulong deal_ticket = HistoryDealGetTicket(index);
      if(deal_ticket == 0)
         continue;
      const long magic =
         HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
      if(!Strategy_IsPairMagic(magic))
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_time =
         (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      if(deal_time >= current_bar_time)
         return true;
     }
   return false;
  }

bool Strategy_ConsumeBarAttempt(const datetime decision_bar_time)
  {
   if(decision_bar_time <= 0)
      return false;

   const string state_name = Strategy_AttemptStateName();
   if(GlobalVariableCheck(state_name))
     {
      const double stored_value = GlobalVariableGet(state_name);
      if(!MathIsValidNumber(stored_value))
         return false;
      const datetime stored_bar =
         (datetime)MathRound(stored_value);
      if(stored_bar >= decision_bar_time)
         return false;
     }

   if(GlobalVariableSet(state_name, (double)decision_bar_time) <= 0)
      return false;
   GlobalVariablesFlush();
   return true;
  }

bool Strategy_LoadRatioState()
  {
   g_latest_ratio = 0.0;
   g_prior_ratio = 0.0;
   g_pre_event_ratio = 0.0;
   g_q10 = 0.0;
   g_q50 = 0.0;
   g_q90 = 0.0;
   g_exit_median = 0.0;
   g_signal_diagnostic = "UNSET";

   const int event_bars = 3;
   const int needed_bars = strategy_reference_bars_d1 + event_bars;
   if(strategy_reference_bars_d1 != 126 ||
      strategy_lower_index != 12 ||
      strategy_upper_index != 113 ||
      strategy_exit_median_bars_d1 != 21 ||
      needed_bars != 129 ||
      strategy_lower_index < 0 ||
      strategy_upper_index >= strategy_reference_bars_d1 ||
      strategy_lower_index >= strategy_upper_index ||
      strategy_exit_median_bars_d1 > needed_bars ||
      (strategy_exit_median_bars_d1 % 2) != 1)
     {
      g_signal_diagnostic = "WINDOW_INVALID";
      return false;
     }

   MqlRates xau_bars[];
   MqlRates xag_bars[];
   ArraySetAsSeries(xau_bars, true);
   ArraySetAsSeries(xag_bars, true);
   const int xau_copied =
      CopyRates(g_leg_xau, // perf-allowed: bounded completed-D1 sample on new-bar path.
                PERIOD_D1,
                1,
                needed_bars,
                xau_bars);
   const int xag_copied =
      CopyRates(g_leg_xag, // perf-allowed: bounded completed-D1 sample on new-bar path.
                PERIOD_D1,
                1,
                needed_bars,
                xag_bars);
   if(xau_copied != needed_bars || xag_copied != needed_bars)
     {
      g_signal_diagnostic = "INSUFFICIENT_D1_HISTORY";
      return false;
     }

   double ratios[];
   ArrayResize(ratios, needed_bars);
   for(int index = 0; index < needed_bars; ++index)
     {
      if(xau_bars[index].time <= 0 ||
         xau_bars[index].time != xag_bars[index].time)
        {
         g_signal_diagnostic = "UNSYNCHRONIZED_D1_ENDPOINTS";
         return false;
        }
      if(xau_bars[index].close <= 0.0 ||
         xag_bars[index].close <= 0.0 ||
         !MathIsValidNumber(xau_bars[index].close) ||
         !MathIsValidNumber(xag_bars[index].close))
        {
         g_signal_diagnostic = "INVALID_D1_CLOSE";
         return false;
        }

      ratios[index] = MathLog(xau_bars[index].close) -
                      MathLog(xag_bars[index].close);
      if(!MathIsValidNumber(ratios[index]))
        {
         g_signal_diagnostic = "INVALID_LOG_RATIO";
         return false;
        }
     }

   double reference[];
   ArrayResize(reference, strategy_reference_bars_d1);
   for(int index = 0; index < strategy_reference_bars_d1; ++index)
      reference[index] = ratios[index + event_bars];
   ArraySort(reference);

   g_latest_ratio = ratios[0];
   g_prior_ratio = ratios[1];
   g_pre_event_ratio = ratios[2];
   g_q10 = reference[strategy_lower_index];
   g_q50 = (reference[62] + reference[63]) / 2.0;
   g_q90 = reference[strategy_upper_index];

   if(!MathIsValidNumber(g_q10) ||
      !MathIsValidNumber(g_q50) ||
      !MathIsValidNumber(g_q90) ||
      g_q50 - g_q10 <= strategy_quantile_epsilon ||
      g_q90 - g_q50 <= strategy_quantile_epsilon)
     {
      g_signal_diagnostic = "EMPIRICAL_QUANTILES_INVALID";
      return false;
     }

   double exit_ratios[];
   ArrayResize(exit_ratios, strategy_exit_median_bars_d1);
   for(int index = 0; index < strategy_exit_median_bars_d1; ++index)
      exit_ratios[index] = ratios[index];
   ArraySort(exit_ratios);
   g_exit_median =
      exit_ratios[strategy_exit_median_bars_d1 / 2];
   if(!MathIsValidNumber(g_exit_median))
     {
      g_signal_diagnostic = "EXIT_MEDIAN_INVALID";
      return false;
     }

   g_signal_diagnostic = "RATIO_STATE_READY";
   return true;
  }

bool Strategy_MaxHoldExceeded()
  {
   datetime entry_time = g_pair_entry_time;
   if(entry_time <= 0)
      entry_time = Strategy_CurrentPairEntryTime();
   if(entry_time <= 0)
      return false;
   const long hold_seconds =
      (long)MathMax(1, strategy_max_hold_days) * 86400;
   return ((long)(TimeCurrent() - entry_time) >= hold_seconds);
  }

double Strategy_LotsForLeg(const string symbol,
                           const double risk_weight,
                           const double risk_weight_sum)
  {
   const double atr =
      QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0 ||
      risk_weight <= 0.0 || risk_weight_sum <= 0.0)
      return 0.0;

   const double sl_points = strategy_atr_sl_mult * atr / point;
   double lots = QM_LotsForRisk(symbol, sl_points) *
                 risk_weight / risk_weight_sum;
   const double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   const double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   const double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(lots <= 0.0 || min_lot <= 0.0 ||
      max_lot <= 0.0 || step <= 0.0)
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

   const double entry = QM_OrderTypeIsBuy(type)
                        ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(symbol, SYMBOL_BID);
   const double atr =
      QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0 ||
      !MathIsValidNumber(entry) || !MathIsValidNumber(atr))
      return false;

   const int digits =
      (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   const double stop_dist = strategy_atr_sl_mult * atr;
   const double lots =
      Strategy_LotsForLeg(symbol, risk_weight, risk_weight_sum);
   if(digits < 0 || stop_dist <= 0.0 || lots <= 0.0)
      return false;

   QM_BasketOrderRequest req;
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

   if(req.sl <= 0.0 || !MathIsValidNumber(req.sl))
      return false;

   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id,
                                qm_news_mode_legacy,
                                strategy_deviation_points,
                                req,
                                ticket);
  }

bool Strategy_OpenPair(const int xau_direction)
  {
   if((xau_direction != 1 && xau_direction != -1) ||
      Strategy_OpenPairLegCount() > 0)
      return false;
   if(!Strategy_SpreadAllowed(g_leg_xau) ||
      !Strategy_SpreadAllowed(g_leg_xag))
      return false;

   const bool long_xau_short_xag = (xau_direction > 0);
   const QM_OrderType xau_type =
      long_xau_short_xag ? QM_BUY : QM_SELL;
   const QM_OrderType xag_type =
      long_xau_short_xag ? QM_SELL : QM_BUY;
   const string reason = long_xau_short_xag
                          ? "QM5_20268_LONG_XAU_SHORT_XAG_QTAILRV"
                          : "QM5_20268_SHORT_XAU_LONG_XAG_QTAILRV";
   const double weight_sum = 2.0;

   const bool xau_ok =
      Strategy_OpenLeg(g_leg_xau, xau_type, 1.0, weight_sum, reason);
   const bool xag_ok =
      Strategy_OpenLeg(g_leg_xag, xag_type, 1.0, weight_sum, reason);
   if(xau_ok && xag_ok &&
      Strategy_OpenPairLegCount() == 2 &&
      Strategy_PairCompositionValid(xau_direction))
     {
      g_pair_entry_time = TimeCurrent();
      return true;
     }

   Strategy_ClosePair(QM_EXIT_STRATEGY);
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart())
      return true;
   if(qm_ea_id != 20268 ||
      qm_magic_slot_offset != 0 ||
      qm_rng_seed != 42)
      return true;
   if(RISK_PERCENT != 0.0 ||
      RISK_FIXED != 1000.0 ||
      PORTFOLIO_WEIGHT != 1.0)
      return true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE ||
      qm_news_mode_legacy != QM_NEWS_OFF ||
      qm_news_stale_max_hours != 336 ||
      qm_news_min_impact != "high")
      return true;
   if(qm_friday_close_enabled ||
      qm_friday_close_hour_broker != 21 ||
      qm_stress_reject_probability != 0.0)
      return true;
   if(strategy_reference_bars_d1 != 126 ||
      strategy_lower_index != 12 ||
      strategy_upper_index != 113 ||
      strategy_exit_median_bars_d1 != 21 ||
      MathAbs(strategy_quantile_epsilon -
              0.000000000001) > 1.0e-18)
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
   req.reason = "QM5_20268_XAU_XAG_QTAILRV_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_new_d1_bar || Strategy_OpenPairLegCount() > 0)
      return false;
   if(!Strategy_LoadRatioState())
     {
      QM_LogEvent(QM_WARN,
                  "ENTRY_REJECTED",
                  StringFormat("{\"result\":\"RATIO_STATE_REJECTED\",\"detail\":\"%s\"}",
                               QM_LoggerEscapeJson(g_signal_diagnostic)));
      return false;
     }

   const bool central_pre_event =
      (g_pre_event_ratio >= g_q10 &&
       g_pre_event_ratio <= g_q90);
   int xau_direction = 0;
   if(central_pre_event &&
      g_prior_ratio > g_q90 &&
      g_latest_ratio > g_q90)
      xau_direction = -1;
   else if(central_pre_event &&
           g_prior_ratio < g_q10 &&
           g_latest_ratio < g_q10)
      xau_direction = 1;
   else
      return false;

   const datetime decision_bar_time =
      iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: cached completed host D1 timestamp on new-bar path.
   if(Strategy_HasEntryDealForDecisionBar(decision_bar_time))
     {
      QM_LogEvent(QM_WARN,
                  "ENTRY_REJECTED",
                  "{\"result\":\"DECISION_BAR_ENTRY_HISTORY_PRESENT_OR_UNAVAILABLE\"}");
      return false;
     }
   if(!Strategy_ConsumeBarAttempt(decision_bar_time))
      return false;

   QM_LogEvent(QM_INFO,
               "ENTRY_ATTEMPT",
               StringFormat("{\"reason\":\"XAU_XAG_QTAILRV\",\"decision_bar\":%I64d,\"latest_ratio\":%.10f,\"prior_ratio\":%.10f,\"pre_event_ratio\":%.10f,\"q10\":%.10f,\"q50\":%.10f,\"q90\":%.10f,\"xau_direction\":%d}",
                            (long)decision_bar_time,
                            g_latest_ratio,
                            g_prior_ratio,
                            g_pre_event_ratio,
                            g_q10,
                            g_q50,
                            g_q90,
                            xau_direction));

   if(!Strategy_NewsAllowsEntry(TimeCurrent()))
      return false;
   if(!Strategy_OpenPair(xau_direction))
     {
      QM_LogEvent(QM_WARN,
                  "ENTRY_REJECTED",
                  "{\"result\":\"BASKET_OPEN_FAILED\",\"reason\":\"XAU_XAG_QTAILRV\"}");
     }
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

   const int xau_direction = Strategy_CurrentXauDirection();
   if(xau_direction == 0)
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return;
     }

   if(g_new_d1_bar)
     {
      if(!Strategy_LoadRatioState())
        {
         QM_LogEvent(QM_WARN,
                     "STRATEGY_EXIT",
                     StringFormat("{\"reason\":\"RATIO_STATE_INVALID\",\"detail\":\"%s\"}",
                                  QM_LoggerEscapeJson(g_signal_diagnostic)));
         Strategy_ClosePair(QM_EXIT_STRATEGY);
         return;
        }

      const bool converged =
         (xau_direction < 0 &&
          g_latest_ratio <= g_exit_median) ||
         (xau_direction > 0 &&
          g_latest_ratio >= g_exit_median);
      if(converged)
        {
         QM_LogEvent(QM_INFO,
                     "STRATEGY_EXIT",
                     StringFormat("{\"reason\":\"XAU_XAG_QTAILRV_CONVERGED\",\"latest_ratio\":%.10f,\"exit_median\":%.10f,\"xau_direction\":%d}",
                                  g_latest_ratio,
                                  g_exit_median,
                                  xau_direction));
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
      if(!QM_NewsAllowsTrade(g_leg_xau,
                             broker_time,
                             qm_news_mode_legacy))
         return false;
      if(!QM_NewsAllowsTrade(g_leg_xag,
                             broker_time,
                             qm_news_mode_legacy))
         return false;
     }
   return true;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return !Strategy_NewsAllowsEntry(broker_time);
  }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
  {
   SymbolSelect(g_leg_xau, true);
   SymbolSelect(g_leg_xag, true);

   const datetime current_broker_time = TimeCurrent();
   const string attempt_state_name = Strategy_AttemptStateName();
   if(current_broker_time > 0 && GlobalVariableCheck(attempt_state_name))
     {
      const double stored_value = GlobalVariableGet(attempt_state_name);
      if(MathIsValidNumber(stored_value) &&
         (datetime)MathRound(stored_value) > current_broker_time)
         GlobalVariableDel(attempt_state_name);
     }

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
   QM_BasketWarmupHistory(basket_symbols, PERIOD_D1, 300);

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_20268\",\"ea\":\"xauxag-qtail-rv\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO,
               "DEINIT",
               StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   g_new_d1_bar = QM_IsNewBar();

   // Lifecycle repair and exits remain active even when entry-only filters
   // reject the current environment.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return;
     }

   if(Strategy_NoTradeFilter() || !g_new_d1_bar)
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
