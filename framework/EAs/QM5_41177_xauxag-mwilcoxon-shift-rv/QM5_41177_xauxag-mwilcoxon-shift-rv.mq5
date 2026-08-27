#property strict
#property version   "5.0"
#property description "QM5_41177 XAU/XAG Monthly Mann-Whitney Location-Shift Reversion"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_41177 - XAU/XAG Monthly Mann-Whitney Location-Shift Reversion
// -----------------------------------------------------------------------------
// At the first synchronized D1 boundary of a broker month, reconstruct the
// latest exactly matched XAU/XAG close pair in each of twelve consecutive
// completed broker months. Compare the six newer gold-minus-silver log ratios
// with the six older ratios through all 36 strict Mann-Whitney orderings, and
// fade only inclusive U_new tails 12/24 with an opposite equal-notional
// package held to the next month.
// Runtime is native, completed-price-only, deterministic, and one attempt per
// month.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 41177;
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
input bool   qm_friday_close_enabled      = false;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input string strategy_xag_symbol             = "XAGUSD.DWX";
input int    strategy_endpoint_count          = 12;
input int    strategy_block_size              = 6;
input int    strategy_u_lower                 = 12;
input int    strategy_u_upper                 = 24;
input int    strategy_history_bars_d1         = 900;
input int    strategy_entry_window_minutes    = 180;
input int    strategy_max_endpoint_gap_days   = 10;
input int    strategy_atr_period_d1           = 20;
input double strategy_atr_sl_mult             = 3.5;
input double strategy_notional_ratio          = 1.0;
input double strategy_max_notional_mismatch_fraction = 0.20;
input int    strategy_max_hold_days           = 40;
input int    strategy_xau_max_spread_points   = 1500;
input int    strategy_xag_max_spread_points   = 500;
input int    strategy_deviation_points        = 20;

string g_leg_xau = "XAUUSD.DWX";
string g_leg_xag = "XAGUSD.DWX";

bool     g_is_new_bar = false;
bool     g_entry_ready = false;
datetime g_current_host_bar = 0;
datetime g_pair_entry_time = 0;
int      g_signal_month_key = 0;
bool     g_signal_late = false;
int      g_last_attempt_month_key = 0;
string   g_attempt_state_key = "";

int Strategy_DayKey(const datetime value)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   if(value <= 0 || !TimeToStruct(value, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

int Strategy_MonthKey(const datetime value)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   if(value <= 0 || !TimeToStruct(value, parts))
      return 0;
   if(parts.year < 1900 || parts.mon < 1 || parts.mon > 12)
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

int Strategy_PreviousMonthKey(const int month_key)
  {
   int year = month_key / 100;
   int month = month_key % 100;
   if(year < 1900 || month < 1 || month > 12)
      return 0;

   --month;
   if(month < 1)
     {
      month = 12;
      --year;
     }
   if(year < 1900)
      return 0;
   return year * 100 + month;
  }

bool Strategy_WithinEntryWindow(const datetime broker_now)
  {
   if(broker_now <= 0 || g_current_host_bar <= 0 ||
      strategy_entry_window_minutes < 0)
      return false;
   const long elapsed = (long)(broker_now - g_current_host_bar);
   if(elapsed < 0)
      return false;
   return (elapsed <= (long)strategy_entry_window_minutes * 60L);
  }

bool Strategy_CurrentBarsSynchronized(const datetime broker_now)
  {
   if(broker_now <= 0 || g_current_host_bar <= 0 ||
      Strategy_DayKey(g_current_host_bar) != Strategy_DayKey(broker_now))
      return false;
   const datetime xag_current =
      iTime(g_leg_xag, PERIOD_D1, 0); // perf-allowed: monthly entry/lifecycle synchronization gate.
   return (xag_current == g_current_host_bar &&
           Strategy_DayKey(xag_current) == Strategy_DayKey(broker_now));
  }

int Strategy_SlotForSymbol(const string symbol)
  {
   if(symbol == g_leg_xau)
      return 0;
   if(symbol == g_leg_xag)
      return 1;
   return -1;
  }

long Strategy_HostMagic()
  {
   return (long)QM_MagicChecked(qm_ea_id, 0, g_leg_xau);
  }

long Strategy_ForeignMagic()
  {
   return (long)QM_MagicChecked(qm_ea_id, 1, g_leg_xag);
  }

bool Strategy_IsOwnedMagic(const long magic)
  {
   return (magic == Strategy_HostMagic() || magic == Strategy_ForeignMagic());
  }

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_leg_xau && _Period == PERIOD_D1 &&
           qm_magic_slot_offset == 0);
  }

bool Strategy_InputsValid()
  {
   return (qm_ea_id == 41177 && qm_magic_slot_offset == 0 &&
            qm_rng_seed == 42 &&
            strategy_xag_symbol == "XAGUSD.DWX" &&
            strategy_endpoint_count == 12 &&
            strategy_block_size == 6 &&
            strategy_u_lower == 12 &&
            strategy_u_upper == 24 &&
            strategy_endpoint_count == 2 * strategy_block_size &&
            strategy_history_bars_d1 == 900 &&
            strategy_entry_window_minutes == 180 &&
            strategy_max_endpoint_gap_days == 10 &&
            strategy_atr_period_d1 == 20 &&
            MathAbs(strategy_atr_sl_mult - 3.5) <= 1.0e-12 &&
            MathAbs(strategy_notional_ratio - 1.0) <= 1.0e-12 &&
            MathAbs(strategy_max_notional_mismatch_fraction - 0.20) <= 1.0e-12 &&
            strategy_max_hold_days == 40 &&
            strategy_xau_max_spread_points == 1500 &&
            strategy_xag_max_spread_points == 500 &&
            strategy_deviation_points == 20 &&
            MathAbs(RISK_PERCENT) <= 1.0e-12 &&
            MathAbs(RISK_FIXED - 1000.0) <= 1.0e-12 &&
            MathAbs(PORTFOLIO_WEIGHT - 1.0) <= 1.0e-12 &&
            qm_news_temporal == QM_NEWS_TEMPORAL_OFF &&
            qm_news_compliance == QM_NEWS_COMPLIANCE_NONE &&
            qm_news_mode_legacy == QM_NEWS_OFF &&
            qm_news_stale_max_hours == 336 &&
            qm_news_min_impact == "high" &&
            !qm_friday_close_enabled && qm_friday_close_hour_broker == 21 &&
            MathAbs(qm_stress_reject_probability) <= 1.0e-12);
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
      return (spread_points <= (double)strategy_xau_max_spread_points);
   if(symbol == g_leg_xag)
      return (spread_points <= (double)strategy_xag_max_spread_points);
   return false;
  }

bool Strategy_SymbolReady(const string symbol, const QM_OrderType order_type)
  {
   const long trade_mode = SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
   if(trade_mode == SYMBOL_TRADE_MODE_DISABLED ||
      trade_mode == SYMBOL_TRADE_MODE_CLOSEONLY)
      return false;
   if(order_type == QM_BUY && trade_mode == SYMBOL_TRADE_MODE_SHORTONLY)
      return false;
   if(order_type == QM_SELL && trade_mode == SYMBOL_TRADE_MODE_LONGONLY)
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

bool Strategy_D1HistoryReady(const string symbol,
                             const datetime expected_bar)
  {
   if(expected_bar <= 0 ||
      Bars(symbol, PERIOD_D1) < // perf-allowed: entry-only D1 history gate.
      strategy_history_bars_d1)
      return false;
   const datetime current_bar =
      iTime(symbol, PERIOD_D1, 0); // perf-allowed: entry-only basket sync gate.
   const datetime completed_bar =
      iTime(symbol, PERIOD_D1, 1); // perf-allowed: entry-only stale-history gate.
   if(current_bar != expected_bar || completed_bar <= 0 ||
      current_bar <= completed_bar)
      return false;
   return ((long)(current_bar - completed_bar) <=
           (long)strategy_max_endpoint_gap_days * 86400L);
  }

int Strategy_OpenOwnedPositionCount()
  {
   int count = 0;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsOwnedMagic(PositionGetInteger(POSITION_MAGIC)))
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
         !Strategy_IsOwnedMagic(PositionGetInteger(POSITION_MAGIC)))
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && (earliest <= 0 || opened < earliest))
         earliest = opened;
     }
   return earliest;
  }

bool Strategy_PairCompositionValid()
  {
   int owned_count = 0;
   int xau_count = 0;
   int xag_count = 0;
   ENUM_POSITION_TYPE xau_type = POSITION_TYPE_BUY;
   ENUM_POSITION_TYPE xag_type = POSITION_TYPE_BUY;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const long magic = PositionGetInteger(POSITION_MAGIC);
      if(!Strategy_IsOwnedMagic(magic))
         continue;
      ++owned_count;
      const string symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double stop = PositionGetDouble(POSITION_SL);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double opened = PositionGetDouble(POSITION_PRICE_OPEN);
      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      if(stop <= 0.0 || volume <= 0.0 || opened <= 0.0 || opened_at <= 0)
         continue;
      if(magic == Strategy_HostMagic() && symbol == g_leg_xau)
         {
          ++xau_count;
          xau_type = type;
         }
       else if(magic == Strategy_ForeignMagic() && symbol == g_leg_xag)
         {
          ++xag_count;
          xag_type = type;
         }
     }
   return (owned_count == 2 && xau_count == 1 && xag_count == 1 &&
           ((xau_type == POSITION_TYPE_BUY &&
             xag_type == POSITION_TYPE_SELL) ||
            (xau_type == POSITION_TYPE_SELL &&
             xag_type == POSITION_TYPE_BUY)));
  }

bool Strategy_PairNotionalValid()
  {
   double xau_volume = 0.0;
   double xag_volume = 0.0;
   double xau_open = 0.0;
   double xag_open = 0.0;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const long magic = PositionGetInteger(POSITION_MAGIC);
      const string symbol = PositionGetString(POSITION_SYMBOL);
      if(magic == Strategy_HostMagic() && symbol == g_leg_xau)
        {
         xau_volume = PositionGetDouble(POSITION_VOLUME);
         xau_open = PositionGetDouble(POSITION_PRICE_OPEN);
        }
      else if(magic == Strategy_ForeignMagic() && symbol == g_leg_xag)
        {
         xag_volume = PositionGetDouble(POSITION_VOLUME);
         xag_open = PositionGetDouble(POSITION_PRICE_OPEN);
        }
     }
   const double xau_contract =
      SymbolInfoDouble(g_leg_xau, SYMBOL_TRADE_CONTRACT_SIZE);
   const double xag_contract =
      SymbolInfoDouble(g_leg_xag, SYMBOL_TRADE_CONTRACT_SIZE);
   if(xau_volume <= 0.0 || xag_volume <= 0.0 || xau_open <= 0.0 ||
      xag_open <= 0.0 || xau_contract <= 0.0 || xag_contract <= 0.0)
      return false;
   const double actual_ratio =
      xau_volume * xau_contract * xau_open /
      (xag_volume * xag_contract * xag_open);
   const double error_fraction =
      MathAbs(actual_ratio - strategy_notional_ratio) /
      strategy_notional_ratio;
   return (MathIsValidNumber(error_fraction) &&
           error_fraction <= strategy_max_notional_mismatch_fraction);
  }

void Strategy_CloseAllOwned(const QM_ExitReason reason)
  {
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsOwnedMagic(PositionGetInteger(POSITION_MAGIC)))
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
           (long)strategy_max_hold_days * 86400);
  }

bool Strategy_NextMonthReached()
  {
   datetime entry_time = g_pair_entry_time;
   if(entry_time <= 0)
      entry_time = Strategy_CurrentPairEntryTime();
   const datetime broker_now = TimeCurrent();
   if(entry_time <= 0 || broker_now <= entry_time ||
      !Strategy_CurrentBarsSynchronized(broker_now))
      return false;
   const int entry_month = Strategy_MonthKey(entry_time);
   const int current_month = Strategy_MonthKey(g_current_host_bar);
   return (entry_month > 0 && current_month > 0 &&
           current_month != entry_month);
  }

string Strategy_AttemptStateKey()
  {
   return StringFormat("QM5_%d_XAUXAG_MWILCOXON_SHIFT_RV_ATTEMPT_MONTH_%I64d",
                       qm_ea_id,
                       Strategy_HostMagic());
  }

void Strategy_LoadAttemptState(const datetime reference_time)
  {
   g_attempt_state_key = Strategy_AttemptStateKey();
   g_last_attempt_month_key = 0;
   const int current_month = Strategy_MonthKey(reference_time);
   if(current_month <= 0 || !GlobalVariableCheck(g_attempt_state_key))
      return;
   const double stored = GlobalVariableGet(g_attempt_state_key);
   const int stored_month = (int)MathRound(stored);
   if(MathIsValidNumber(stored) && stored_month >= 190001 &&
      stored_month <= current_month)
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
   // Stay fail-closed in-process even if terminal persistence fails.
   g_last_attempt_month_key = month_key;
   return (GlobalVariableSet(g_attempt_state_key, (double)month_key) > 0);
  }

bool Strategy_MonthHasOwnedEntry(const int month_key,
                                 const datetime decision_time)
  {
   if(month_key <= 0 || decision_time <= 0)
      return true;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsOwnedMagic(PositionGetInteger(POSITION_MAGIC)))
         continue;
      if(Strategy_MonthKey((datetime)PositionGetInteger(POSITION_TIME)) == month_key)
         return true;
     }
   const datetime history_start = decision_time - (datetime)(50 * 86400);
   if(history_start <= 0 || !HistorySelect(history_start, TimeCurrent()))
      return true;
   for(int index = HistoryDealsTotal() - 1; index >= 0; --index)
     {
      const ulong deal_ticket = HistoryDealGetTicket(index);
      if(deal_ticket == 0 ||
         !Strategy_IsOwnedMagic(HistoryDealGetInteger(deal_ticket, DEAL_MAGIC)))
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      if(Strategy_MonthKey((datetime)HistoryDealGetInteger(deal_ticket,
                                                           DEAL_TIME)) ==
          month_key)
         return true;
     }
   return false;
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

bool Strategy_PreparePackage(const int direction,
                             double &xau_lots,
                             double &xag_lots,
                             double &xau_stop,
                             double &xag_stop)
  {
   xau_lots = 0.0;
   xag_lots = 0.0;
   xau_stop = 0.0;
   xag_stop = 0.0;
   if(direction != 1 && direction != -1)
      return false;

   const QM_OrderType xau_type = (direction > 0) ? QM_BUY : QM_SELL;
   const QM_OrderType xag_type = (direction > 0) ? QM_SELL : QM_BUY;
   if(!Strategy_SymbolReady(g_leg_xau, xau_type) ||
      !Strategy_SymbolReady(g_leg_xag, xag_type))
      return false;

   const double xau_entry = SymbolInfoDouble(g_leg_xau,
                                              xau_type == QM_BUY
                                              ? SYMBOL_ASK : SYMBOL_BID);
   const double xag_entry = SymbolInfoDouble(g_leg_xag,
                                              xag_type == QM_BUY
                                              ? SYMBOL_ASK : SYMBOL_BID);
   const double xau_atr =
      QM_ATR(g_leg_xau, PERIOD_D1, strategy_atr_period_d1, 1);
   const double xag_atr =
      QM_ATR(g_leg_xag, PERIOD_D1, strategy_atr_period_d1, 1);
   const double xau_point = SymbolInfoDouble(g_leg_xau, SYMBOL_POINT);
   const double xag_point = SymbolInfoDouble(g_leg_xag, SYMBOL_POINT);
   if(xau_entry <= 0.0 || xag_entry <= 0.0 || xau_atr <= 0.0 ||
      xag_atr <= 0.0 || xau_point <= 0.0 || xag_point <= 0.0)
      return false;

   const double xau_stop_distance = strategy_atr_sl_mult * xau_atr;
   const double xag_stop_distance = strategy_atr_sl_mult * xag_atr;
   xau_stop = QM_StopRulesNormalizePrice(
      g_leg_xau,
      xau_entry + ((xau_type == QM_BUY) ? -xau_stop_distance
                                        :  xau_stop_distance));
   xag_stop = QM_StopRulesNormalizePrice(
      g_leg_xag,
      xag_entry + ((xag_type == QM_BUY) ? -xag_stop_distance
                                        :  xag_stop_distance));
   if(xau_stop <= 0.0 || xag_stop <= 0.0 ||
      (xau_type == QM_BUY && xau_stop >= xau_entry) ||
      (xau_type == QM_SELL && xau_stop <= xau_entry) ||
      (xag_type == QM_BUY && xag_stop >= xag_entry) ||
      (xag_type == QM_SELL && xag_stop <= xag_entry))
      return false;

   // Size from the final broker-normalized stop distances. Tick-size and
   // minimum-distance normalization must never enlarge the package beyond
   // its one fixed-dollar stop budget.
   const double xau_actual_stop_distance = MathAbs(xau_entry - xau_stop);
   const double xag_actual_stop_distance = MathAbs(xag_entry - xag_stop);
   if(xau_actual_stop_distance <= 0.0 || xag_actual_stop_distance <= 0.0 ||
      !MathIsValidNumber(xau_actual_stop_distance) ||
      !MathIsValidNumber(xag_actual_stop_distance))
      return false;
   const double full_xau_lots =
      QM_LotsForRisk(g_leg_xau, xau_actual_stop_distance / xau_point);
   const double full_xag_lots =
      QM_LotsForRisk(g_leg_xag, xag_actual_stop_distance / xag_point);
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

   // Begin with one half of the aggregate fixed-dollar stop-risk budget per
   // leg. Equal-notional balancing may only reduce the larger notional leg;
   // it can never enlarge either risk-sized volume.
   double raw_xau_lots = 0.5 * full_xau_lots;
   double raw_xag_lots = 0.5 * full_xag_lots;
   if(raw_xau_lots <= 0.0 || raw_xag_lots <= 0.0 ||
      !MathIsValidNumber(raw_xau_lots) ||
      !MathIsValidNumber(raw_xag_lots))
      return false;
   const double initial_xau_notional = raw_xau_lots * xau_notional_per_lot;
   const double initial_xag_notional = raw_xag_lots * xag_notional_per_lot;
   if(initial_xau_notional <= 0.0 || initial_xag_notional <= 0.0 ||
      !MathIsValidNumber(initial_xau_notional) ||
      !MathIsValidNumber(initial_xag_notional))
      return false;
   if(initial_xau_notional >
      strategy_notional_ratio * initial_xag_notional)
      raw_xau_lots =
         strategy_notional_ratio * initial_xag_notional /
         xau_notional_per_lot;
   else
      raw_xag_lots =
         initial_xau_notional /
         (strategy_notional_ratio * xag_notional_per_lot);

   xau_lots = Strategy_RoundLotsDown(g_leg_xau, raw_xau_lots);
   xag_lots = Strategy_RoundLotsDown(g_leg_xag, raw_xag_lots);
   if(xau_lots <= 0.0 || xag_lots <= 0.0)
      return false;

   const double normalized_stop_risk =
      xau_lots / full_xau_lots + xag_lots / full_xag_lots;
   const double actual_ratio =
      xau_lots * xau_notional_per_lot /
      (xag_lots * xag_notional_per_lot);
   const double error_fraction =
      MathAbs(actual_ratio - strategy_notional_ratio) /
      strategy_notional_ratio;
   return (MathIsValidNumber(normalized_stop_risk) &&
           normalized_stop_risk <= 1.0 + 1.0e-8 &&
           MathIsValidNumber(error_fraction) &&
           error_fraction <= strategy_max_notional_mismatch_fraction);
  }

bool Strategy_OpenLeg(const string symbol,
                      const QM_OrderType type,
                      const double lots,
                      const double stop)
  {
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0 || lots <= 0.0 || stop <= 0.0)
      return false;
   QM_BasketOrderRequest request;
   request.symbol = symbol;
   request.type = type;
   request.price = 0.0;
   request.sl = stop;
   request.tp = 0.0;
   request.lots = lots;
   request.reason = "QM5_41177_XAUXAG_MWILCOXON_SHIFT_RV";
   request.symbol_slot = slot;
   request.expiration_seconds = 0;
   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy,
                                 strategy_deviation_points, request, ticket);
  }

bool Strategy_OpenPair(const int direction)
  {
   if(Strategy_OpenOwnedPositionCount() > 0)
      return false;
   double xau_lots = 0.0;
   double xag_lots = 0.0;
   double xau_stop = 0.0;
   double xag_stop = 0.0;
   if(!Strategy_PreparePackage(direction,
                               xau_lots, xag_lots,
                               xau_stop, xag_stop))
      return false;
   const QM_OrderType xau_type = (direction > 0) ? QM_BUY : QM_SELL;
   const QM_OrderType xag_type = (direction > 0) ? QM_SELL : QM_BUY;
   if(!Strategy_OpenLeg(g_leg_xau, xau_type, xau_lots, xau_stop))
      return false;
   if(Strategy_OpenLeg(g_leg_xag, xag_type, xag_lots, xag_stop) &&
       Strategy_PairCompositionValid() && Strategy_PairNotionalValid())
     {
      g_pair_entry_time = Strategy_CurrentPairEntryTime();
      return (g_pair_entry_time > 0);
     }
   Strategy_CloseAllOwned(QM_EXIT_STRATEGY);
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   return (!Strategy_IsHostChart() || !Strategy_InputsValid());
  }

bool Strategy_LogRatio(const double xau_close,
                       const double xag_close,
                       double &ratio)
  {
   ratio = 0.0;
   if(xau_close <= 0.0 || xag_close <= 0.0 ||
      !MathIsValidNumber(xau_close) || !MathIsValidNumber(xag_close))
      return false;
   ratio = MathLog(xau_close) - MathLog(xag_close);
   return MathIsValidNumber(ratio);
  }

bool Strategy_RatesSeriesValid(MqlRates &bars[], const int count)
  {
   if(count <= 0 || count > ArraySize(bars))
      return false;
   for(int index = 0; index < count; ++index)
     {
      if(bars[index].time <= 0 || bars[index].close <= 0.0 ||
         !MathIsValidNumber(bars[index].close) ||
         (index > 0 && bars[index - 1].time <= bars[index].time))
         return false;
     }
   return true;
  }

bool Strategy_LoadMonthlyMannWhitney(
      const int current_month_key,
      int &month_count,
      datetime &newest_endpoint_time,
      double &endpoint_displacement,
      int &tie_count,
      int &u_new,
      int &u_old,
      int &newer_rank_sum,
      string &older_ratio_csv,
      string &newer_ratio_csv,
      int &direction)
  {
   month_count = 0;
   newest_endpoint_time = 0;
   endpoint_displacement = 0.0;
   tie_count = 0;
   u_new = 0;
   u_old = 0;
   newer_rank_sum = 0;
   older_ratio_csv = "";
   newer_ratio_csv = "";
   direction = 0;

   if(current_month_key <= 0 ||
      strategy_endpoint_count != 12 ||
      strategy_block_size != 6 ||
      strategy_u_lower != 12 ||
      strategy_u_upper != 24 ||
      strategy_endpoint_count != 2 * strategy_block_size ||
      strategy_history_bars_d1 != 900 ||
      strategy_max_endpoint_gap_days != 10 ||
      g_current_host_bar <= 0 ||
      Strategy_MonthKey(g_current_host_bar) != current_month_key)
      return false;

   MqlRates xau_bars[];
   MqlRates xag_bars[];
   double newest_first_ratios[];
   datetime newest_first_times[];
   double chronological_ratios[];
   datetime chronological_times[];
   ArraySetAsSeries(xau_bars, true);
   ArraySetAsSeries(xag_bars, true);

   if(ArrayResize(newest_first_ratios, strategy_endpoint_count) !=
         strategy_endpoint_count ||
      ArrayResize(newest_first_times, strategy_endpoint_count) !=
         strategy_endpoint_count ||
      ArrayResize(chronological_ratios, strategy_endpoint_count) !=
         strategy_endpoint_count ||
      ArrayResize(chronological_times, strategy_endpoint_count) !=
         strategy_endpoint_count)
      return false;

   const int xau_copied =
      CopyRates(g_leg_xau, // perf-allowed: one bounded twelve-month scan behind a consumed monthly attempt.
                PERIOD_D1, 1, strategy_history_bars_d1, xau_bars);
   const int xag_copied =
      CopyRates(g_leg_xag, // perf-allowed: one bounded twelve-month scan behind a consumed monthly attempt.
                PERIOD_D1, 1, strategy_history_bars_d1, xag_bars);
   if(xau_copied != strategy_history_bars_d1 ||
      xag_copied != strategy_history_bars_d1 ||
      !Strategy_RatesSeriesValid(xau_bars, xau_copied) ||
      !Strategy_RatesSeriesValid(xag_bars, xag_copied))
      return false;

   int xau_index = 0;
   int xag_index = 0;
   int expected_month = Strategy_PreviousMonthKey(current_month_key);
   while(month_count < strategy_endpoint_count)
     {
      if(expected_month <= 0)
         return false;
      bool found = false;
      while(xau_index < xau_copied && xag_index < xag_copied)
        {
         const datetime xau_time = xau_bars[xau_index].time;
         const datetime xag_time = xag_bars[xag_index].time;
         if(xau_time > xag_time)
           {
            ++xau_index;
            continue;
           }
         if(xag_time > xau_time)
           {
            ++xag_index;
            continue;
           }

         const int matched_month = Strategy_MonthKey(xau_time);
         if(matched_month <= 0 || xau_time >= g_current_host_bar)
            return false;
         if(matched_month > expected_month)
           {
            ++xau_index;
            ++xag_index;
            continue;
           }
         if(matched_month < expected_month)
            return false;

         double ratio = 0.0;
         if(!Strategy_LogRatio(xau_bars[xau_index].close,
                               xag_bars[xag_index].close,
                               ratio))
            return false;
         if(month_count < 0 ||
            month_count >= ArraySize(newest_first_ratios))
            return false;
         if(month_count >= ArraySize(newest_first_times))
            return false;
         newest_first_ratios[month_count] = ratio;
         newest_first_times[month_count] = xau_time;
         if(month_count == 0)
            newest_endpoint_time = xau_time;
         ++month_count;
         ++xau_index;
         ++xag_index;
         found = true;
         break;
        }
      if(!found)
         return false;
      expected_month = Strategy_PreviousMonthKey(expected_month);
     }

   if(month_count != strategy_endpoint_count ||
      newest_endpoint_time <= 0 ||
      (long)(g_current_host_bar - newest_endpoint_time) < 0L ||
      (long)(g_current_host_bar - newest_endpoint_time) >
         (long)strategy_max_endpoint_gap_days * 86400L)
      return false;

   for(int index = 0; index < strategy_endpoint_count; ++index)
     {
      const int reverse_index = strategy_endpoint_count - 1 - index;
      if(reverse_index < 0 ||
         reverse_index >= ArraySize(newest_first_ratios))
         return false;
      if(reverse_index >= ArraySize(newest_first_times))
         return false;
      chronological_ratios[index] = newest_first_ratios[reverse_index];
      chronological_times[index] = newest_first_times[reverse_index];
      if(!MathIsValidNumber(chronological_ratios[index]) ||
         chronological_times[index] <= 0 ||
         (index > 0 && chronological_times[index] <=
                       chronological_times[index - 1]))
         return false;
     }

   endpoint_displacement =
      chronological_ratios[strategy_endpoint_count - 1] -
      chronological_ratios[0];
   if(!MathIsValidNumber(endpoint_displacement))
      return false;

   // Exact ties are consumed flat. Do not average ranks or delete an
   // observation: all 36 fixed cross-block comparisons must be strict.
   for(int left = 0; left < strategy_endpoint_count; ++left)
     {
      for(int right = left + 1; right < strategy_endpoint_count; ++right)
        {
         if(chronological_ratios[left] == chronological_ratios[right])
            ++tie_count;
        }
     }
   if(tie_count > 0)
      return true;

   for(int older = 0; older < strategy_block_size; ++older)
     {
      if(older >= ArraySize(chronological_ratios))
         return false;
      if(older > 0)
         older_ratio_csv += ",";
      older_ratio_csv += DoubleToString(chronological_ratios[older], 12);
     }

   for(int newer = strategy_block_size;
       newer < strategy_endpoint_count;
       ++newer)
     {
      if(newer > strategy_block_size)
         newer_ratio_csv += ",";
      newer_ratio_csv += DoubleToString(chronological_ratios[newer], 12);

      int combined_rank = 1;
      for(int other = 0; other < strategy_endpoint_count; ++other)
        {
         if(chronological_ratios[other] < chronological_ratios[newer])
            ++combined_rank;
        }
      if(combined_rank < 1 || combined_rank > strategy_endpoint_count)
         return false;
      newer_rank_sum += combined_rank;

      for(int older = 0; older < strategy_block_size; ++older)
        {
         if(older >= ArraySize(chronological_ratios))
            return false;
         if(chronological_ratios[newer] > chronological_ratios[older])
            ++u_new;
         else if(chronological_ratios[older] > chronological_ratios[newer])
            ++u_old;
         else
            return false;
        }
     }

   const int pair_count = strategy_block_size * strategy_block_size;
   const int minimum_rank_sum =
      strategy_block_size * (strategy_block_size + 1) / 2;
   if(pair_count != 36 || minimum_rank_sum != 21 ||
      u_new < 0 || u_new > pair_count ||
      u_old < 0 || u_old > pair_count ||
      u_new + u_old != pair_count ||
      newer_rank_sum < minimum_rank_sum ||
      newer_rank_sum > minimum_rank_sum + pair_count ||
      newer_rank_sum - minimum_rank_sum != u_new)
      return false;

   // direction > 0 means BUY XAU / SELL XAG. Fade the fixed-block ratio
   // location shift; U magnitude above an inclusive boundary never scales risk.
   if(u_new >= strategy_u_upper)
      direction = -1;
   else if(u_new <= strategy_u_lower)
      direction = 1;
   return true;
  }
bool Strategy_DecisionClockReady(int &month_key,
                                 bool &late)
  {
   month_key = 0;
   late = false;
   const datetime broker_now = TimeCurrent();
   if(!g_is_new_bar || g_current_host_bar <= 0 ||
      broker_now < g_current_host_bar ||
      Strategy_DayKey(g_current_host_bar) != Strategy_DayKey(broker_now))
      return false;

   month_key = Strategy_MonthKey(broker_now);
   if(month_key <= 0 ||
      Strategy_MonthKey(g_current_host_bar) != month_key ||
      month_key == g_last_attempt_month_key)
      return false;

   const datetime newest_completed =
      iTime(g_leg_xau, PERIOD_D1, 1); // perf-allowed: one monthly decision-clock endpoint.
   late = (!Strategy_WithinEntryWindow(broker_now) ||
           Strategy_MonthKey(newest_completed) == month_key);
   return true;
  }

bool Strategy_EntryWindowReady(const int month_key,
                               const bool late)
  {
   const datetime broker_now = TimeCurrent();
   if(month_key <= 0 || g_current_host_bar <= 0 || late ||
      Strategy_OpenOwnedPositionCount() > 0 ||
      !Strategy_WithinEntryWindow(broker_now) ||
      !Strategy_CurrentBarsSynchronized(broker_now))
      return false;
   if(!Strategy_D1HistoryReady(g_leg_xau, g_current_host_bar) ||
      !Strategy_D1HistoryReady(g_leg_xag, g_current_host_bar))
      return false;
   if(Strategy_MonthKey(g_current_host_bar) != month_key ||
      Strategy_MonthHasOwnedEntry(month_key, broker_now))
      return false;
   return true;
  }

bool Strategy_EntrySignal(QM_EntryRequest &request)
  {
   request.type = QM_BUY;
   request.price = 0.0;
   request.sl = 0.0;
   request.tp = 0.0;
   request.reason = "QM5_41177_XAUXAG_MWILCOXON_SHIFT_RV_HOST";
   request.symbol_slot = qm_magic_slot_offset;
   request.expiration_seconds = 0;
   if(!g_entry_ready || g_signal_month_key <= 0 ||
      g_signal_month_key != g_last_attempt_month_key ||
      Strategy_OpenOwnedPositionCount() > 0)
      return false;

   int month_count = 0;
   int tie_count = 0;
   int u_new = 0;
   int u_old = 0;
   int newer_rank_sum = 0;
   int direction = 0;
   datetime newest_endpoint_time = 0;
   double endpoint_displacement = 0.0;
   string older_ratio_csv = "";
   string newer_ratio_csv = "";
   const bool valid =
      Strategy_LoadMonthlyMannWhitney(
         g_signal_month_key,
         month_count,
         newest_endpoint_time,
         endpoint_displacement,
         tie_count,
         u_new,
         u_old,
         newer_rank_sum,
         older_ratio_csv,
         newer_ratio_csv,
         direction);

   string state = "monthly_mann_whitney_failed";
   if(valid && direction > 0)
      state = "lower_newer_ratio_location_fade_long_xau";
   else if(valid && direction < 0)
      state = "higher_newer_ratio_location_fade_short_xau";
   else if(valid && tie_count > 0)
      state = "ratio_tie_flat";
   else if(valid)
      state = "mann_whitney_u_interior_flat";

   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"month\":%d,\"month_count\":%d,\"newest_endpoint_time\":%I64d,\"endpoint_displacement\":%.12e,\"block_size\":%d,\"u_new\":%d,\"u_old\":%d,\"u_complement\":%d,\"newer_rank_sum\":%d,\"older_ratios\":\"%s\",\"newer_ratios\":\"%s\",\"tie_count\":%d,\"direction\":%d,\"state\":\"%s\"}",
                            g_signal_month_key,
                            month_count,
                            (long)newest_endpoint_time,
                            endpoint_displacement,
                            strategy_block_size,
                            u_new,
                            u_old,
                            u_new + u_old,
                            newer_rank_sum,
                            older_ratio_csv,
                            newer_ratio_csv,
                            tie_count,
                            direction,
                            state));
   if(!valid || direction == 0)
      return false;

   Strategy_OpenPair(direction);
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int open_positions = Strategy_OpenOwnedPositionCount();
   if(open_positions <= 0)
      return;
   if(open_positions != 2 || !Strategy_PairCompositionValid() ||
      !Strategy_PairNotionalValid())
     {
      Strategy_CloseAllOwned(QM_EXIT_STRATEGY);
      return;
     }
   if(Strategy_NextMonthReached())
     {
      Strategy_CloseAllOwned(QM_EXIT_STRATEGY);
      return;
     }
   if(Strategy_MaxHoldExceeded())
      Strategy_CloseAllOwned(QM_EXIT_TIME_STOP);
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

bool Strategy_PrimeLateSignalAttach()
  {
   const datetime broker_now = TimeCurrent();
   const int month_key = Strategy_MonthKey(broker_now);
   if(month_key <= 0 || g_current_host_bar <= 0)
      return false;

   const datetime newest_completed =
      iTime(g_leg_xau, PERIOD_D1, 1); // perf-allowed: restart month-boundary classification.
   const int completed_month = Strategy_MonthKey(newest_completed);
   const bool on_time_boundary =
      (Strategy_DayKey(g_current_host_bar) == Strategy_DayKey(broker_now) &&
       Strategy_MonthKey(g_current_host_bar) == month_key &&
       Strategy_WithinEntryWindow(broker_now) &&
       completed_month > 0 &&
       Strategy_NextMonthKey(completed_month) == month_key);
   if(on_time_boundary)
      return true;

   // A late or non-boundary attachment consumes and primes the broker month
   // so the first OnTick cannot become a synthetic historical entry.
   QM_IsNewBar(g_leg_xau, PERIOD_D1);
   if(month_key == g_last_attempt_month_key)
      return true;
   if(!Strategy_RecordAttemptState(month_key))
      return false;
   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"month\":%d,\"state\":\"late_init_consumed_flat\"}",
                            month_key));
   return true;
  }

int OnInit()
  {
   g_leg_xag = strategy_xag_symbol;
   if(!Strategy_IsHostChart() || !Strategy_InputsValid())
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

   if(!QM_FrameworkDeclareExecutionContract(
         PERIOD_D1,
         QM_FRIDAY_CLOSE_DISABLED,
         "Approved XAU/XAG fixed-block Mann-Whitney location-shift reversion package holds through Fridays until next broker month"))
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

   if(Strategy_NoTradeFilter())
     {
      QM_FrameworkShutdown();
      return INIT_PARAMETERS_INCORRECT;
     }

   const int host_magic = QM_MagicChecked(qm_ea_id, 0, g_leg_xau);
   const int foreign_magic = QM_MagicChecked(qm_ea_id, 1, g_leg_xag);
   if(host_magic <= 0 || foreign_magic <= 0 ||
      !QM_KillSwitchRegisterMagic((long)foreign_magic))
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

   string basket_symbols[2] = {g_leg_xau, g_leg_xag};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols,
                          PERIOD_D1,
                          strategy_history_bars_d1);
   g_current_host_bar =
      iTime(g_leg_xau, PERIOD_D1, 0); // perf-allowed: restart state anchor.
   Strategy_LoadAttemptState(TimeCurrent());
   g_pair_entry_time = Strategy_CurrentPairEntryTime();
   if(!Strategy_PrimeLateSignalAttach())
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }
   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"QM5_41177\",\"ea\":\"xauxag-mwilcoxon-shift-rv\"}");
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
   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose())
      return;

   g_is_new_bar = QM_IsNewBar(g_leg_xau, PERIOD_D1);
   g_entry_ready = false;
   g_signal_month_key = 0;
   g_signal_late = false;
   if(g_is_new_bar || g_current_host_bar <= 0)
     {
      g_current_host_bar =
         iTime(g_leg_xau, PERIOD_D1, 0); // perf-allowed: new-bar lifecycle and entry anchor.
      if(g_is_new_bar)
         QM_EquityStreamOnNewBar();
     }

   // Repair and lifecycle exits always precede entry filters and news gates.
   Strategy_ManageOpenPosition();
   if(Strategy_NoTradeFilter())
      return;
   if(!Strategy_DecisionClockReady(g_signal_month_key,
                                   g_signal_late))
      return;

   // Consume this broker month before history, signal, news, spread, quote,
   // ATR, sizing, or order submission. Nothing downstream may retry it.
   if(!Strategy_RecordAttemptState(g_signal_month_key))
      return;
   if(g_signal_late)
     {
      QM_LogEvent(QM_INFO,
                  "STRATEGY_STATE",
                  StringFormat("{\"month\":%d,\"state\":\"late_month_consumed_flat\"}",
                               g_signal_month_key));
      return;
     }
   if(Strategy_OpenOwnedPositionCount() > 0 ||
      !Strategy_EntryWindowReady(g_signal_month_key,
                                 g_signal_late))
      return;
   if(Strategy_NewsFilterHook(broker_now))
      return;

   g_entry_ready = true;
   QM_EntryRequest request;
   ZeroMemory(request);
   if(Strategy_EntrySignal(request))
     {
      ulong ticket = 0;
      QM_TM_OpenPosition(request, ticket);
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
