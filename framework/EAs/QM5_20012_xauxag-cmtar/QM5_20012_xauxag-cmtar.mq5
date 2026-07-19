#property strict
#property version   "5.0"
#property description "QM5_20012 XAU XAG consistent M-TAR convergence basket"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_20012 - XAU/XAG consistent momentum-threshold convergence basket
// -----------------------------------------------------------------------------
// Source-fixed monthly residual (the paper's tables are in base-10 logs):
//   e = log10(XAG) + 0.99823 - 0.71970 * log10(XAU)
// Only the published convergent C-MTAR branch, delta(e) < 0.021, is tradable.
// A signed residual fade opens opposite XAU/XAG legs with XAU:XAG target
// notionals 0.71970:1. Both legs share one framework risk budget.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 20012;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = false;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input double strategy_source_intercept       = -0.99823;
input double strategy_source_beta            = 0.71970;
input double strategy_mtar_delta_threshold   = 0.021;
input double strategy_entry_abs_residual     = 0.010;
input int    strategy_history_bars            = 120;
input int    strategy_max_endpoint_gap_days   = 10;
input int    strategy_atr_period_d1           = 20;
input double strategy_atr_sl_mult             = 4.0;
input int    strategy_max_hold_days           = 40;
input int    strategy_xau_max_spread_pts      = 1500;
input int    strategy_xag_max_spread_pts      = 500;
input double strategy_max_hedge_error_pct     = 20.0;
input int    strategy_deviation_points        = 20;

string g_leg_xau = "XAUUSD.DWX";
string g_leg_xag = "XAGUSD.DWX";

bool     g_month_boundary = false;
bool     g_signal_ready = false;
int      g_signal_month_key = 0;
int      g_signal_pair_direction = 0; // +1 long residual; -1 short residual.
double   g_signal_residual = 0.0;
double   g_signal_delta = 0.0;
datetime g_pair_entry_time = 0;
int      g_last_attempt_month_key = 0;
string   g_attempt_state_key = "";

struct StrategyMonthEnd
  {
   int      month_key;
   datetime time;
   double   close;
  };

int Strategy_MonthKey(const datetime value)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   if(value <= 0 || !TimeToStruct(value, parts))
      return 0;
   return parts.year * 100 + parts.mon;
  }

int Strategy_PreviousMonthKey(const int month_key)
  {
   int year = month_key / 100;
   int month = month_key % 100;
   if(year <= 0 || month < 1 || month > 12)
      return 0;
   --month;
   if(month <= 0)
     {
      month = 12;
      --year;
     }
   return year * 100 + month;
  }

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
   return (_Symbol == g_leg_xau && _Period == PERIOD_D1 &&
           qm_magic_slot_offset == 0);
  }

bool Strategy_IsMonthlyBoundary()
  {
   const datetime current_bar = iTime(g_leg_xau, PERIOD_D1, 0); // perf-allowed: one D1 cadence probe per new bar.
   const datetime previous_bar = iTime(g_leg_xau, PERIOD_D1, 1); // perf-allowed: one D1 cadence probe per new bar.
   const int current_month = Strategy_MonthKey(current_bar);
   const int previous_month = Strategy_MonthKey(previous_bar);
   return (current_month > 0 && previous_month > 0 &&
           current_month != previous_month);
  }

bool Strategy_SpreadAllowed(const string symbol)
  {
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;
   const double spread_points = (ask - bid) / point;
   if(symbol == g_leg_xau)
      return (spread_points <= (double)strategy_xau_max_spread_pts);
   if(symbol == g_leg_xag)
      return (spread_points <= (double)strategy_xag_max_spread_pts);
   return false;
  }

bool Strategy_SymbolReady(const string symbol)
  {
   const long trade_mode = SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
   if(trade_mode == SYMBOL_TRADE_MODE_DISABLED ||
      trade_mode == SYMBOL_TRADE_MODE_CLOSEONLY)
      return false;
   return (SymbolInfoDouble(symbol, SYMBOL_POINT) > 0.0 &&
           SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE) > 0.0 &&
           SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE) > 0.0 &&
           SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE) > 0.0 &&
           SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN) > 0.0 &&
           SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX) > 0.0 &&
           SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP) > 0.0 &&
           Strategy_SpreadAllowed(symbol));
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

bool Strategy_IsPairMagic(const long magic)
  {
   return (magic == QM_MagicChecked(qm_ea_id, 0, g_leg_xau) ||
           magic == QM_MagicChecked(qm_ea_id, 1, g_leg_xag));
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
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && (earliest <= 0 || opened < earliest))
         earliest = opened;
     }
   return earliest;
  }

bool Strategy_PairCompositionValid()
  {
   int xau_count = 0;
   int xag_count = 0;
   ENUM_POSITION_TYPE xau_type = (ENUM_POSITION_TYPE)-1;
   ENUM_POSITION_TYPE xag_type = (ENUM_POSITION_TYPE)-1;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsPairPosition())
         continue;
      const string symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(symbol == g_leg_xau)
        {
         ++xau_count;
         xau_type = type;
        }
      else if(symbol == g_leg_xag)
        {
         ++xag_count;
         xag_type = type;
        }
     }
   return (xau_count == 1 && xag_count == 1 && xau_type != xag_type &&
           (xau_type == POSITION_TYPE_BUY || xau_type == POSITION_TYPE_SELL) &&
           (xag_type == POSITION_TYPE_BUY || xag_type == POSITION_TYPE_SELL));
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

bool Strategy_MaxHoldExceeded()
  {
   datetime entry_time = g_pair_entry_time;
   if(entry_time <= 0)
      entry_time = Strategy_CurrentPairEntryTime();
   if(entry_time <= 0)
      return false;
   return ((long)(TimeCurrent() - entry_time) >=
           (long)MathMax(1, strategy_max_hold_days) * 86400);
  }

bool Strategy_PairMonthExpired()
  {
   datetime entry_time = g_pair_entry_time;
   if(entry_time <= 0)
      entry_time = Strategy_CurrentPairEntryTime();
   const int opened_month = Strategy_MonthKey(entry_time);
   const int current_month = Strategy_MonthKey(TimeCurrent());
   return (opened_month > 0 && current_month > 0 &&
           opened_month != current_month);
  }

string Strategy_AttemptStateKey()
  {
   return StringFormat("QM5_%d_XAUXAG_CMTAR_ATTEMPT_MONTH", qm_ea_id);
  }

void Strategy_LoadAttemptState(const datetime reference_time)
  {
   g_attempt_state_key = Strategy_AttemptStateKey();
   g_last_attempt_month_key = 0;
   const int current_month = Strategy_MonthKey(reference_time);
   if(current_month <= 0 || !GlobalVariableCheck(g_attempt_state_key))
      return;
   const int stored_month = (int)GlobalVariableGet(g_attempt_state_key);
   if(stored_month > 0 && stored_month <= current_month)
      g_last_attempt_month_key = stored_month;
   else
      GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordAttemptState(const int month_key)
  {
   if(month_key <= 0)
      return false;
   if(g_attempt_state_key == "")
      g_attempt_state_key = Strategy_AttemptStateKey();
   g_last_attempt_month_key = month_key;
   return (GlobalVariableSet(g_attempt_state_key, (double)month_key) > 0);
  }

bool Strategy_MonthAlreadyEntered(const int month_key,
                                  const datetime decision_time)
  {
   if(month_key <= 0 || decision_time <= 0)
      return true;
   if(g_last_attempt_month_key == month_key)
      return true;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsPairPosition())
         continue;
      if(Strategy_MonthKey((datetime)PositionGetInteger(POSITION_TIME)) == month_key)
         return true;
     }

   const datetime history_start = decision_time - (datetime)(62 * 86400);
   if(history_start <= 0 || !HistorySelect(history_start, TimeCurrent()))
      return true;
   for(int index = HistoryDealsTotal() - 1; index >= 0; --index)
     {
      const ulong deal_ticket = HistoryDealGetTicket(index);
      if(deal_ticket == 0 ||
         !Strategy_IsPairMagic(HistoryDealGetInteger(deal_ticket, DEAL_MAGIC)))
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      if(Strategy_MonthKey((datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME)) ==
         month_key)
         return true;
     }
   return false;
  }

bool Strategy_LoadMonthEnds(const string symbol,
                            const datetime decision_time,
                            const int required_months,
                            StrategyMonthEnd &ends[])
  {
   ArrayResize(ends, 0);
   if(decision_time <= 0 || required_months < 2)
      return false;

   const int decision_shift = iBarShift(symbol, PERIOD_D1,
                                        decision_time, false); // perf-allowed: one strict monthly cutoff lookup.
   if(decision_shift < 0)
      return false;
   const datetime anchor_time = iTime(symbol, PERIOD_D1, // perf-allowed: validate strict monthly cutoff.
                                      decision_shift);
   if(anchor_time <= 0 || anchor_time > decision_time)
      return false;
   const int start_shift = decision_shift +
      (anchor_time == decision_time ? 1 : 0);

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(symbol, PERIOD_D1, start_shift, // perf-allowed: bounded reconstruction once per month.
                                strategy_history_bars, rates);
   if(copied <= 0)
      return false;

   int last_month_key = 0;
   int count = 0;
   for(int index = 0; index < copied && count < required_months; ++index)
     {
      const datetime bar_time = rates[index].time;
      const double close_value = rates[index].close;
      if(bar_time <= 0 || bar_time >= decision_time || close_value <= 0.0 ||
         !MathIsValidNumber(close_value))
         continue;
      const int month_key = Strategy_MonthKey(bar_time);
      if(month_key <= 0 || month_key == last_month_key)
         continue;
      if(ArrayResize(ends, count + 1) != count + 1)
         return false;
      ends[count].month_key = month_key;
      ends[count].time = bar_time;
      ends[count].close = close_value;
      last_month_key = month_key;
      ++count;
     }
   return (count >= required_months);
  }

bool Strategy_LoadMonthlyResiduals(const datetime decision_time,
                                   double &latest_residual,
                                   double &previous_residual)
  {
   latest_residual = 0.0;
   previous_residual = 0.0;
   StrategyMonthEnd xau_ends[];
   StrategyMonthEnd xag_ends[];
   if(!Strategy_LoadMonthEnds(g_leg_xau, decision_time, 6, xau_ends) ||
      !Strategy_LoadMonthEnds(g_leg_xag, decision_time, 6, xag_ends))
      return false;

   StrategyMonthEnd paired_xau[2];
   StrategyMonthEnd paired_xag[2];
   int pair_count = 0;
   const int xau_count = ArraySize(xau_ends);
   const int xag_count = ArraySize(xag_ends);
   for(int xau_index = 0; xau_index < xau_count && pair_count < 2; ++xau_index)
     {
      for(int xag_index = 0; xag_index < xag_count; ++xag_index)
        {
         if(xau_ends[xau_index].month_key != xag_ends[xag_index].month_key)
            continue;
         paired_xau[pair_count] = xau_ends[xau_index];
         paired_xag[pair_count] = xag_ends[xag_index];
         ++pair_count;
         break;
        }
     }
   if(pair_count != 2 ||
      paired_xau[1].month_key != Strategy_PreviousMonthKey(paired_xau[0].month_key))
      return false;

   const long max_gap = (long)strategy_max_endpoint_gap_days * 86400;
   for(int pair_index = 0; pair_index < 2; ++pair_index)
     {
      long cross_gap = (long)(paired_xau[pair_index].time -
                              paired_xag[pair_index].time);
      if(cross_gap < 0)
         cross_gap = -cross_gap;
      if(cross_gap > max_gap)
         return false;
     }
   const long xau_age = (long)(decision_time - paired_xau[0].time);
   const long xag_age = (long)(decision_time - paired_xag[0].time);
   if(xau_age < 0 || xag_age < 0 || xau_age > max_gap || xag_age > max_gap)
      return false;

   const double x0 = MathLog10(paired_xau[0].close);
   const double y0 = MathLog10(paired_xag[0].close);
   const double x1 = MathLog10(paired_xau[1].close);
   const double y1 = MathLog10(paired_xag[1].close);
   if(!MathIsValidNumber(x0) || !MathIsValidNumber(y0) ||
      !MathIsValidNumber(x1) || !MathIsValidNumber(y1))
      return false;
   latest_residual = y0 - strategy_source_intercept - strategy_source_beta * x0;
   previous_residual = y1 - strategy_source_intercept - strategy_source_beta * x1;
   return (MathIsValidNumber(latest_residual) &&
           MathIsValidNumber(previous_residual));
  }

bool Strategy_LoadSignal(const datetime decision_time)
  {
   g_signal_ready = false;
   g_signal_month_key = Strategy_MonthKey(decision_time);
   g_signal_pair_direction = 0;
   g_signal_residual = 0.0;
   g_signal_delta = 0.0;
   if(g_signal_month_key <= 0)
      return false;

   double latest_residual = 0.0;
   double previous_residual = 0.0;
   if(!Strategy_LoadMonthlyResiduals(decision_time,
                                     latest_residual,
                                     previous_residual))
      return false;
   const double delta_residual = latest_residual - previous_residual;
   if(!MathIsValidNumber(delta_residual) ||
      !(delta_residual < strategy_mtar_delta_threshold))
      return false;
   if(MathAbs(latest_residual) < strategy_entry_abs_residual)
      return false;

   g_signal_residual = latest_residual;
   g_signal_delta = delta_residual;
   g_signal_pair_direction = (latest_residual < 0.0 ? 1 : -1);
   g_signal_ready = true;
   return true;
  }

double Strategy_RoundLotsDown(const string symbol, const double raw_lots)
  {
   const double minimum = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   const double maximum = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   const double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(raw_lots <= 0.0 || minimum <= 0.0 || maximum <= 0.0 || step <= 0.0)
      return 0.0;
   double lots = MathFloor((raw_lots + 1.0e-12) / step) * step;
   lots = MathMin(lots, maximum);
   if(lots < minimum)
      return 0.0;
   return NormalizeDouble(lots, 8);
  }

bool Strategy_PreparePackage(const QM_OrderType xau_type,
                             const QM_OrderType xag_type,
                             double &xau_lots,
                             double &xag_lots,
                             double &xau_stop,
                             double &xag_stop)
  {
   xau_lots = 0.0;
   xag_lots = 0.0;
   xau_stop = 0.0;
   xag_stop = 0.0;
   if(!Strategy_SymbolReady(g_leg_xau) || !Strategy_SymbolReady(g_leg_xag))
      return false;

   const double xau_entry = QM_OrderTypeIsBuy(xau_type)
      ? SymbolInfoDouble(g_leg_xau, SYMBOL_ASK)
      : SymbolInfoDouble(g_leg_xau, SYMBOL_BID);
   const double xag_entry = QM_OrderTypeIsBuy(xag_type)
      ? SymbolInfoDouble(g_leg_xag, SYMBOL_ASK)
      : SymbolInfoDouble(g_leg_xag, SYMBOL_BID);
   const double xau_atr = QM_ATR(g_leg_xau, PERIOD_D1,
                                 strategy_atr_period_d1, 1);
   const double xag_atr = QM_ATR(g_leg_xag, PERIOD_D1,
                                 strategy_atr_period_d1, 1);
   const double xau_point = SymbolInfoDouble(g_leg_xau, SYMBOL_POINT);
   const double xag_point = SymbolInfoDouble(g_leg_xag, SYMBOL_POINT);
   if(xau_entry <= 0.0 || xag_entry <= 0.0 || xau_atr <= 0.0 ||
      xag_atr <= 0.0 || xau_point <= 0.0 || xag_point <= 0.0)
      return false;

   const double xau_stop_distance = strategy_atr_sl_mult * xau_atr;
   const double xag_stop_distance = strategy_atr_sl_mult * xag_atr;
   xau_stop = QM_StopRulesNormalizePrice(g_leg_xau,
      QM_OrderTypeIsBuy(xau_type) ? xau_entry - xau_stop_distance
                                  : xau_entry + xau_stop_distance);
   xag_stop = QM_StopRulesNormalizePrice(g_leg_xag,
      QM_OrderTypeIsBuy(xag_type) ? xag_entry - xag_stop_distance
                                  : xag_entry + xag_stop_distance);
   if(xau_stop <= 0.0 || xag_stop <= 0.0)
      return false;

   const double full_xau_lots =
      QM_LotsForRisk(g_leg_xau, xau_stop_distance / xau_point);
   const double full_xag_lots =
      QM_LotsForRisk(g_leg_xag, xag_stop_distance / xag_point);
   const double xau_contract =
      SymbolInfoDouble(g_leg_xau, SYMBOL_TRADE_CONTRACT_SIZE);
   const double xag_contract =
      SymbolInfoDouble(g_leg_xag, SYMBOL_TRADE_CONTRACT_SIZE);
   if(full_xau_lots <= 0.0 || full_xag_lots <= 0.0 ||
      xau_contract <= 0.0 || xag_contract <= 0.0)
      return false;

   const double xau_notional_per_lot = xau_contract * xau_entry;
   const double xag_notional_per_lot = xag_contract * xag_entry;
   if(xau_notional_per_lot <= 0.0 || xag_notional_per_lot <= 0.0)
      return false;
   const double lot_ratio_xau_to_xag =
      strategy_source_beta * xag_notional_per_lot / xau_notional_per_lot;
   const double normalized_risk_per_xag_lot =
      lot_ratio_xau_to_xag / full_xau_lots + 1.0 / full_xag_lots;
   if(lot_ratio_xau_to_xag <= 0.0 || normalized_risk_per_xag_lot <= 0.0 ||
      !MathIsValidNumber(normalized_risk_per_xag_lot))
      return false;

   const double raw_xag_lots = 1.0 / normalized_risk_per_xag_lot;
   const double raw_xau_lots = lot_ratio_xau_to_xag * raw_xag_lots;
   xau_lots = Strategy_RoundLotsDown(g_leg_xau, raw_xau_lots);
   xag_lots = Strategy_RoundLotsDown(g_leg_xag, raw_xag_lots);
   if(xau_lots <= 0.0 || xag_lots <= 0.0)
      return false;

   const double normalized_stop_risk =
      xau_lots / full_xau_lots + xag_lots / full_xag_lots;
   const double actual_beta =
      xau_lots * xau_notional_per_lot /
      (xag_lots * xag_notional_per_lot);
   const double hedge_error_pct =
      100.0 * MathAbs(actual_beta - strategy_source_beta) /
      strategy_source_beta;
   return (MathIsValidNumber(normalized_stop_risk) &&
           normalized_stop_risk <= 1.0 + 1.0e-8 &&
           MathIsValidNumber(hedge_error_pct) &&
           hedge_error_pct <= strategy_max_hedge_error_pct);
  }

bool Strategy_OpenLeg(const string symbol,
                      const QM_OrderType type,
                      const double lots,
                      const double stop,
                      const string reason)
  {
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0 || lots <= 0.0 || stop <= 0.0)
      return false;
   QM_BasketOrderRequest req;
   req.symbol = symbol;
   req.type = type;
   req.price = 0.0;
   req.sl = stop;
   req.tp = 0.0;
   req.lots = lots;
   req.reason = reason;
   req.symbol_slot = slot;
   req.expiration_seconds = 0;
   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy,
                                strategy_deviation_points, req, ticket);
  }

bool Strategy_OpenPair(const int pair_direction)
  {
   if(pair_direction == 0 || Strategy_OpenPairLegCount() > 0 ||
      !Strategy_SymbolReady(g_leg_xau) || !Strategy_SymbolReady(g_leg_xag))
      return false;
   const bool long_residual = (pair_direction > 0);
   const QM_OrderType xau_type = long_residual ? QM_SELL : QM_BUY;
   const QM_OrderType xag_type = long_residual ? QM_BUY : QM_SELL;
   const string reason = long_residual
      ? "QM5_20012_LONG_CMTAR_RESIDUAL"
      : "QM5_20012_SHORT_CMTAR_RESIDUAL";

   double xau_lots = 0.0;
   double xag_lots = 0.0;
   double xau_stop = 0.0;
   double xag_stop = 0.0;
   if(!Strategy_PreparePackage(xau_type, xag_type,
                               xau_lots, xag_lots, xau_stop, xag_stop))
      return false;
   if(!Strategy_OpenLeg(g_leg_xau, xau_type, xau_lots, xau_stop, reason))
      return false;
   if(Strategy_OpenLeg(g_leg_xag, xag_type, xag_lots, xag_stop, reason))
     {
      g_pair_entry_time = TimeCurrent();
      return true;
     }
   Strategy_ClosePair(QM_EXIT_STRATEGY);
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart() || qm_friday_close_enabled)
      return true;
   if(MathAbs(strategy_source_intercept + 0.99823) > 1.0e-12 ||
      MathAbs(strategy_source_beta - 0.71970) > 1.0e-12 ||
      MathAbs(strategy_mtar_delta_threshold - 0.021) > 1.0e-12)
      return true;
   if(MathAbs(strategy_entry_abs_residual - 0.000) > 1.0e-12 &&
      MathAbs(strategy_entry_abs_residual - 0.010) > 1.0e-12 &&
      MathAbs(strategy_entry_abs_residual - 0.020) > 1.0e-12)
      return true;
   if(strategy_history_bars != 120 || strategy_max_endpoint_gap_days != 10)
      return true;
   if((strategy_atr_period_d1 != 14 && strategy_atr_period_d1 != 20 &&
       strategy_atr_period_d1 != 30) ||
      (MathAbs(strategy_atr_sl_mult - 3.0) > 1.0e-12 &&
       MathAbs(strategy_atr_sl_mult - 4.0) > 1.0e-12 &&
       MathAbs(strategy_atr_sl_mult - 5.0) > 1.0e-12) ||
      (strategy_max_hold_days != 35 && strategy_max_hold_days != 40))
      return true;
   if((strategy_xau_max_spread_pts != 1000 &&
       strategy_xau_max_spread_pts != 1500 &&
       strategy_xau_max_spread_pts != 2500) ||
      (strategy_xag_max_spread_pts != 300 &&
       strategy_xag_max_spread_pts != 500 &&
       strategy_xag_max_spread_pts != 800) ||
      (MathAbs(strategy_max_hedge_error_pct - 10.0) > 1.0e-12 &&
       MathAbs(strategy_max_hedge_error_pct - 20.0) > 1.0e-12 &&
       MathAbs(strategy_max_hedge_error_pct - 30.0) > 1.0e-12) ||
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
   req.reason = "QM5_20012_XAUXAG_CMTAR_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_month_boundary || !g_signal_ready ||
      g_signal_month_key <= 0 || g_signal_pair_direction == 0 ||
      Strategy_OpenPairLegCount() > 0)
      return false;
   const datetime decision_time = iTime(g_leg_xau, PERIOD_D1, 0); // perf-allowed: current monthly decision anchor.
   if(decision_time <= 0 ||
      Strategy_MonthAlreadyEntered(g_signal_month_key, decision_time))
      return false;

   // Persist before the first order. A rejection or repaired orphan consumes
   // the current source-period attempt and cannot create a same-month retry.
   if(!Strategy_RecordAttemptState(g_signal_month_key))
      return false;
   Strategy_OpenPair(g_signal_pair_direction);
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
   // Compare the owned entry month on every tick. If a transient broker
   // rejection prevents the first boundary close, lifecycle repair keeps
   // retrying instead of silently carrying the old source-period package.
   if(Strategy_PairMonthExpired())
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
      return (QM_NewsAllowsTrade2(g_leg_xau, broker_time,
                                  qm_news_temporal, qm_news_compliance) &&
              QM_NewsAllowsTrade2(g_leg_xag, broker_time,
                                  qm_news_temporal, qm_news_compliance));
     }
   return (QM_NewsAllowsTrade(g_leg_xau, broker_time, qm_news_mode_legacy) &&
           QM_NewsAllowsTrade(g_leg_xag, broker_time, qm_news_mode_legacy));
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return !Strategy_NewsAllowsEntry(broker_time);
  }

int OnInit()
  {
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

   const int host_magic = QM_MagicChecked(qm_ea_id, 0, g_leg_xau);
   const int foreign_magic = QM_MagicChecked(qm_ea_id, 1, g_leg_xag);
   if(host_magic <= 0 || foreign_magic <= 0 ||
      !QM_KillSwitchRegisterMagic((long)foreign_magic))
      return INIT_FAILED;

   string basket_symbols[2] = {g_leg_xau, g_leg_xag};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols, PERIOD_D1,
                          MathMax(160, strategy_history_bars));
   const datetime current_bar_time = iTime(g_leg_xau, PERIOD_D1, 0); // perf-allowed: restart state anchor.
   Strategy_LoadAttemptState(current_bar_time);
   g_pair_entry_time = Strategy_CurrentPairEntryTime();
   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"QM5_20012\",\"ea\":\"xauxag-cmtar\"}");
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
   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose())
      return;

   const bool new_bar = QM_IsNewBar();
   const bool entry_blocked = Strategy_NoTradeFilter();
   g_month_boundary = false;
   g_signal_ready = false;
   if(new_bar)
     {
      QM_EquityStreamOnNewBar();
      g_month_boundary = Strategy_IsMonthlyBoundary();
      if(g_month_boundary && !entry_blocked)
        {
         const datetime decision_time = iTime(g_leg_xau, PERIOD_D1, 0); // perf-allowed: monthly signal anchor.
         Strategy_LoadSignal(decision_time);
        }
     }

   // Composition, month-renewal and time-stop management precede every entry
   // filter so invalid inputs or news cannot strand an owned foreign leg.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return;
     }
   if(entry_blocked || !new_bar || !g_month_boundary ||
      Strategy_NewsFilterHook(broker_now))
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
