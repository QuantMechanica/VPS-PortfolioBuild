#property strict
#property version   "5.0"
#property description "QM5_41189 XTI/XNG Thirteen-Month LAD Ratio Reversion"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_41189 - XTI/XNG Thirteen-Month LAD Ratio Reversion
// -----------------------------------------------------------------------------
// At the first synchronized D1 boundary of a broker month, reconstruct the
// latest exactly matched XTI/XNG close pair in each of thirteen consecutive
// completed broker months. Form all 78 forward oil-minus-gas log-ratio
// slope breakpoints. At every slope, profile the median residual intercept and
// absolute-error objective; take the median of every minimum-loss slope and
// fade its strict sign. The opposite, equal-notional package is held to the
// next month. Runtime is native, completed-price-only, deterministic, and one
// attempt per month.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 41189;
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
input string strategy_xng_symbol             = "XNGUSD.DWX";
input int    strategy_month_end_count         = 13;
input int    strategy_history_bars_d1         = 900;
input int    strategy_entry_window_minutes    = 180;
input int    strategy_max_endpoint_gap_days   = 10;
input double strategy_loss_tie_epsilon         = 1.0e-12;
input int    strategy_atr_period_d1           = 20;
input double strategy_atr_sl_mult             = 3.5;
input double strategy_notional_ratio          = 1.0;
input double strategy_max_notional_mismatch_fraction = 0.20;
input int    strategy_max_hold_days           = 40;
input int    strategy_xti_max_spread_points   = 1500;
input int    strategy_xng_max_spread_points   = 3000;
input int    strategy_deviation_points        = 20;

string g_leg_xti = "XTIUSD.DWX";
string g_leg_xng = "XNGUSD.DWX";

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
   const datetime xng_current =
      iTime(g_leg_xng, PERIOD_D1, 0); // perf-allowed: monthly entry/lifecycle synchronization gate.
   return (xng_current == g_current_host_bar &&
           Strategy_DayKey(xng_current) == Strategy_DayKey(broker_now));
  }

int Strategy_SlotForSymbol(const string symbol)
  {
   if(symbol == g_leg_xti)
      return 0;
   if(symbol == g_leg_xng)
      return 1;
   return -1;
  }

long Strategy_HostMagic()
  {
   return (long)QM_MagicChecked(qm_ea_id, 0, g_leg_xti);
  }

long Strategy_ForeignMagic()
  {
   return (long)QM_MagicChecked(qm_ea_id, 1, g_leg_xng);
  }

bool Strategy_IsOwnedMagic(const long magic)
  {
   return (magic == Strategy_HostMagic() || magic == Strategy_ForeignMagic());
  }

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_leg_xti && _Period == PERIOD_D1 &&
           qm_magic_slot_offset == 0);
  }

bool Strategy_InputsValid()
  {
   return (qm_ea_id == 41189 && qm_magic_slot_offset == 0 &&
            qm_rng_seed == 42 &&
            strategy_xng_symbol == "XNGUSD.DWX" &&
            strategy_month_end_count == 13 &&
            strategy_history_bars_d1 == 900 &&
            strategy_entry_window_minutes == 180 &&
            strategy_max_endpoint_gap_days == 10 &&
            strategy_loss_tie_epsilon == 1.0e-12 &&
            strategy_atr_period_d1 == 20 &&
            MathAbs(strategy_atr_sl_mult - 3.5) <= 1.0e-12 &&
            MathAbs(strategy_notional_ratio - 1.0) <= 1.0e-12 &&
            MathAbs(strategy_max_notional_mismatch_fraction - 0.20) <= 1.0e-12 &&
            strategy_max_hold_days == 40 &&
            strategy_xti_max_spread_points == 1500 &&
            strategy_xng_max_spread_points == 3000 &&
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
   if(symbol == g_leg_xti)
      return (spread_points <= (double)strategy_xti_max_spread_points);
   if(symbol == g_leg_xng)
      return (spread_points <= (double)strategy_xng_max_spread_points);
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
   int xti_count = 0;
   int xng_count = 0;
   ENUM_POSITION_TYPE xti_type = POSITION_TYPE_BUY;
   ENUM_POSITION_TYPE xng_type = POSITION_TYPE_BUY;
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
      if(magic == Strategy_HostMagic() && symbol == g_leg_xti)
         {
          ++xti_count;
          xti_type = type;
         }
       else if(magic == Strategy_ForeignMagic() && symbol == g_leg_xng)
         {
          ++xng_count;
          xng_type = type;
         }
     }
   return (owned_count == 2 && xti_count == 1 && xng_count == 1 &&
           ((xti_type == POSITION_TYPE_BUY &&
             xng_type == POSITION_TYPE_SELL) ||
            (xti_type == POSITION_TYPE_SELL &&
             xng_type == POSITION_TYPE_BUY)));
  }

bool Strategy_PairNotionalValid()
  {
   double xti_volume = 0.0;
   double xng_volume = 0.0;
   double xti_open = 0.0;
   double xng_open = 0.0;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const long magic = PositionGetInteger(POSITION_MAGIC);
      const string symbol = PositionGetString(POSITION_SYMBOL);
      if(magic == Strategy_HostMagic() && symbol == g_leg_xti)
        {
         xti_volume = PositionGetDouble(POSITION_VOLUME);
         xti_open = PositionGetDouble(POSITION_PRICE_OPEN);
        }
      else if(magic == Strategy_ForeignMagic() && symbol == g_leg_xng)
        {
         xng_volume = PositionGetDouble(POSITION_VOLUME);
         xng_open = PositionGetDouble(POSITION_PRICE_OPEN);
        }
     }
   const double xti_contract =
      SymbolInfoDouble(g_leg_xti, SYMBOL_TRADE_CONTRACT_SIZE);
   const double xng_contract =
      SymbolInfoDouble(g_leg_xng, SYMBOL_TRADE_CONTRACT_SIZE);
   if(xti_volume <= 0.0 || xng_volume <= 0.0 || xti_open <= 0.0 ||
      xng_open <= 0.0 || xti_contract <= 0.0 || xng_contract <= 0.0)
      return false;
   const double actual_ratio =
      xti_volume * xti_contract * xti_open /
      (xng_volume * xng_contract * xng_open);
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
   return StringFormat("QM5_%d_XTI_XNG_MLAD_RV_ATTEMPT_MONTH_%I64d",
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
                             double &xti_lots,
                             double &xng_lots,
                             double &xti_stop,
                             double &xng_stop)
  {
   xti_lots = 0.0;
   xng_lots = 0.0;
   xti_stop = 0.0;
   xng_stop = 0.0;
   if(direction != 1 && direction != -1)
      return false;

   const QM_OrderType xti_type = (direction > 0) ? QM_BUY : QM_SELL;
   const QM_OrderType xng_type = (direction > 0) ? QM_SELL : QM_BUY;
   if(!Strategy_SymbolReady(g_leg_xti, xti_type) ||
      !Strategy_SymbolReady(g_leg_xng, xng_type))
      return false;

   const double xti_entry = SymbolInfoDouble(g_leg_xti,
                                              xti_type == QM_BUY
                                              ? SYMBOL_ASK : SYMBOL_BID);
   const double xng_entry = SymbolInfoDouble(g_leg_xng,
                                              xng_type == QM_BUY
                                              ? SYMBOL_ASK : SYMBOL_BID);
   const double xti_atr =
      QM_ATR(g_leg_xti, PERIOD_D1, strategy_atr_period_d1, 1);
   const double xng_atr =
      QM_ATR(g_leg_xng, PERIOD_D1, strategy_atr_period_d1, 1);
   const double xti_point = SymbolInfoDouble(g_leg_xti, SYMBOL_POINT);
   const double xng_point = SymbolInfoDouble(g_leg_xng, SYMBOL_POINT);
   if(xti_entry <= 0.0 || xng_entry <= 0.0 || xti_atr <= 0.0 ||
      xng_atr <= 0.0 || xti_point <= 0.0 || xng_point <= 0.0)
      return false;

   const double xti_stop_distance = strategy_atr_sl_mult * xti_atr;
   const double xng_stop_distance = strategy_atr_sl_mult * xng_atr;
   xti_stop = QM_StopRulesNormalizePrice(
      g_leg_xti,
      xti_entry + ((xti_type == QM_BUY) ? -xti_stop_distance
                                        :  xti_stop_distance));
   xng_stop = QM_StopRulesNormalizePrice(
      g_leg_xng,
      xng_entry + ((xng_type == QM_BUY) ? -xng_stop_distance
                                        :  xng_stop_distance));
   if(xti_stop <= 0.0 || xng_stop <= 0.0 ||
      (xti_type == QM_BUY && xti_stop >= xti_entry) ||
      (xti_type == QM_SELL && xti_stop <= xti_entry) ||
      (xng_type == QM_BUY && xng_stop >= xng_entry) ||
      (xng_type == QM_SELL && xng_stop <= xng_entry))
      return false;

   // Size from the final broker-normalized stop distances. Tick-size and
   // minimum-distance normalization must never enlarge the package beyond
   // its one fixed-dollar stop budget.
   const double xti_actual_stop_distance = MathAbs(xti_entry - xti_stop);
   const double xng_actual_stop_distance = MathAbs(xng_entry - xng_stop);
   if(xti_actual_stop_distance <= 0.0 || xng_actual_stop_distance <= 0.0 ||
      !MathIsValidNumber(xti_actual_stop_distance) ||
      !MathIsValidNumber(xng_actual_stop_distance))
      return false;
   const double full_xti_lots =
      QM_LotsForRisk(g_leg_xti, xti_actual_stop_distance / xti_point);
   const double full_xng_lots =
      QM_LotsForRisk(g_leg_xng, xng_actual_stop_distance / xng_point);
   const double xti_contract =
      SymbolInfoDouble(g_leg_xti, SYMBOL_TRADE_CONTRACT_SIZE);
   const double xng_contract =
      SymbolInfoDouble(g_leg_xng, SYMBOL_TRADE_CONTRACT_SIZE);
   if(full_xti_lots <= 0.0 || full_xng_lots <= 0.0 ||
      xti_contract <= 0.0 || xng_contract <= 0.0)
      return false;

   const double xti_notional_per_lot = xti_contract * xti_entry;
   const double xng_notional_per_lot = xng_contract * xng_entry;
   if(xti_notional_per_lot <= 0.0 || xng_notional_per_lot <= 0.0)
      return false;

   // Begin with one half of the aggregate fixed-dollar stop-risk budget per
   // leg. Equal-notional balancing may only reduce the larger notional leg;
   // it can never enlarge either risk-sized volume.
   double raw_xti_lots = 0.5 * full_xti_lots;
   double raw_xng_lots = 0.5 * full_xng_lots;
   if(raw_xti_lots <= 0.0 || raw_xng_lots <= 0.0 ||
      !MathIsValidNumber(raw_xti_lots) ||
      !MathIsValidNumber(raw_xng_lots))
      return false;
   const double initial_xti_notional = raw_xti_lots * xti_notional_per_lot;
   const double initial_xng_notional = raw_xng_lots * xng_notional_per_lot;
   if(initial_xti_notional <= 0.0 || initial_xng_notional <= 0.0 ||
      !MathIsValidNumber(initial_xti_notional) ||
      !MathIsValidNumber(initial_xng_notional))
      return false;
   if(initial_xti_notional >
      strategy_notional_ratio * initial_xng_notional)
      raw_xti_lots =
         strategy_notional_ratio * initial_xng_notional /
         xti_notional_per_lot;
   else
      raw_xng_lots =
         initial_xti_notional /
         (strategy_notional_ratio * xng_notional_per_lot);

   xti_lots = Strategy_RoundLotsDown(g_leg_xti, raw_xti_lots);
   xng_lots = Strategy_RoundLotsDown(g_leg_xng, raw_xng_lots);
   if(xti_lots <= 0.0 || xng_lots <= 0.0)
      return false;

   const double normalized_stop_risk =
      xti_lots / full_xti_lots + xng_lots / full_xng_lots;
   const double actual_ratio =
      xti_lots * xti_notional_per_lot /
      (xng_lots * xng_notional_per_lot);
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
   request.reason = "QM5_41189_XTI_XNG_MLAD_RV";
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
   double xti_lots = 0.0;
   double xng_lots = 0.0;
   double xti_stop = 0.0;
   double xng_stop = 0.0;
   if(!Strategy_PreparePackage(direction,
                               xti_lots, xng_lots,
                               xti_stop, xng_stop))
      return false;
   const QM_OrderType xti_type = (direction > 0) ? QM_BUY : QM_SELL;
   const QM_OrderType xng_type = (direction > 0) ? QM_SELL : QM_BUY;
   if(!Strategy_OpenLeg(g_leg_xti, xti_type, xti_lots, xti_stop))
      return false;
   if(Strategy_OpenLeg(g_leg_xng, xng_type, xng_lots, xng_stop) &&
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

bool Strategy_LogRatio(const double xti_close,
                       const double xng_close,
                       double &ratio)
  {
   ratio = 0.0;
   if(xti_close <= 0.0 || xng_close <= 0.0 ||
      !MathIsValidNumber(xti_close) || !MathIsValidNumber(xng_close))
      return false;
   ratio = MathLog(xti_close) - MathLog(xng_close);
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

bool Strategy_LoadMonthlyLad(
      const int current_month_key,
      int &month_count,
      datetime &newest_endpoint_time,
      double &endpoint_displacement,
      int &candidate_slope_count,
      int &objective_count,
      int &minimizer_count,
      double &lad_intercept,
      double &minimum_loss,
      double &lad_slope,
      int &direction)
  {
   month_count = 0;
   newest_endpoint_time = 0;
   endpoint_displacement = 0.0;
   candidate_slope_count = 0;
   objective_count = 0;
   minimizer_count = 0;
   lad_intercept = 0.0;
   minimum_loss = 0.0;
   lad_slope = 0.0;
   direction = 0;

   const int expected_candidate_count =
      strategy_month_end_count * (strategy_month_end_count - 1) / 2;
   if(current_month_key <= 0 || strategy_month_end_count != 13 ||
      strategy_history_bars_d1 != 900 ||
      strategy_max_endpoint_gap_days != 10 ||
      strategy_loss_tie_epsilon != 1.0e-12 ||
      expected_candidate_count != 78 || g_current_host_bar <= 0 ||
      Strategy_MonthKey(g_current_host_bar) != current_month_key)
      return false;

   MqlRates xti_bars[];
   MqlRates xng_bars[];
   double newest_first_ratios[];
   datetime newest_first_times[];
   double chronological_ratios[];
   datetime chronological_times[];
   double candidate_slopes[];
   double candidate_losses[];
   ArraySetAsSeries(xti_bars, true);
   ArraySetAsSeries(xng_bars, true);
   if(ArrayResize(newest_first_ratios, strategy_month_end_count) !=
         strategy_month_end_count ||
      ArrayResize(newest_first_times, strategy_month_end_count) !=
         strategy_month_end_count ||
      ArrayResize(chronological_ratios, strategy_month_end_count) !=
         strategy_month_end_count ||
      ArrayResize(chronological_times, strategy_month_end_count) !=
         strategy_month_end_count ||
      ArrayResize(candidate_slopes, expected_candidate_count) !=
         expected_candidate_count ||
      ArrayResize(candidate_losses, expected_candidate_count) !=
         expected_candidate_count)
      return false;

   const int xti_copied =
      CopyRates(g_leg_xti, // perf-allowed: one bounded thirteen-month scan behind a consumed monthly attempt.
                PERIOD_D1, 1, strategy_history_bars_d1, xti_bars);
   const int xng_copied =
      CopyRates(g_leg_xng, // perf-allowed: one bounded thirteen-month scan behind a consumed monthly attempt.
                PERIOD_D1, 1, strategy_history_bars_d1, xng_bars);
   if(xti_copied != strategy_history_bars_d1 ||
      xng_copied != strategy_history_bars_d1 ||
      !Strategy_RatesSeriesValid(xti_bars, xti_copied) ||
      !Strategy_RatesSeriesValid(xng_bars, xng_copied))
      return false;

   int xti_index = 0;
   int xng_index = 0;
   int expected_month = Strategy_PreviousMonthKey(current_month_key);
   while(month_count < strategy_month_end_count)
     {
      if(expected_month <= 0)
         return false;
      bool found = false;
      while(xti_index < xti_copied && xng_index < xng_copied)
        {
         const datetime xti_time = xti_bars[xti_index].time;
         const datetime xng_time = xng_bars[xng_index].time;
         if(xti_time > xng_time)
           {
            ++xti_index;
            continue;
           }
         if(xng_time > xti_time)
           {
            ++xng_index;
            continue;
           }

         const int matched_month = Strategy_MonthKey(xti_time);
         if(matched_month <= 0 || xti_time >= g_current_host_bar)
            return false;
         if(matched_month > expected_month)
           {
            ++xti_index;
            ++xng_index;
            continue;
           }
         if(matched_month < expected_month)
            return false;

         double ratio = 0.0;
         if(!Strategy_LogRatio(xti_bars[xti_index].close,
                               xng_bars[xng_index].close,
                               ratio))
            return false;
         newest_first_ratios[month_count] = ratio;
         newest_first_times[month_count] = xti_time;
         if(month_count == 0)
            newest_endpoint_time = xti_time;
         ++month_count;
         ++xti_index;
         ++xng_index;
         found = true;
         break;
        }
      if(!found)
         return false;
      expected_month = Strategy_PreviousMonthKey(expected_month);
     }

   if(month_count != strategy_month_end_count ||
      newest_endpoint_time <= 0 ||
      (long)(g_current_host_bar - newest_endpoint_time) < 0L ||
      (long)(g_current_host_bar - newest_endpoint_time) >
         (long)strategy_max_endpoint_gap_days * 86400L)
      return false;

   for(int index = 0; index < strategy_month_end_count; ++index)
     {
      const int reverse_index = strategy_month_end_count - 1 - index;
      chronological_ratios[index] = newest_first_ratios[reverse_index];
      chronological_times[index] = newest_first_times[reverse_index];
      if(!MathIsValidNumber(chronological_ratios[index]) ||
         chronological_times[index] <= 0 ||
         (index > 0 && chronological_times[index] <=
                       chronological_times[index - 1]))
         return false;
     }

   endpoint_displacement =
      chronological_ratios[strategy_month_end_count - 1] -
      chronological_ratios[0];
   if(!MathIsValidNumber(endpoint_displacement))
      return false;

   // Candidate order is locked lexicographically by older then newer month.
   for(int older = 0; older < strategy_month_end_count - 1; ++older)
     {
      for(int newer = older + 1;
          newer < strategy_month_end_count;
          ++newer)
        {
         const int month_distance = newer - older;
         if(month_distance <= 0 || candidate_slope_count < 0 ||
            candidate_slope_count >= expected_candidate_count)
            return false;
         const double slope =
            (chronological_ratios[newer] -
             chronological_ratios[older]) /
            (double)month_distance;
         if(!MathIsValidNumber(slope))
            return false;
         candidate_slopes[candidate_slope_count] = slope;
         ++candidate_slope_count;
        }
     }
   if(candidate_slope_count != expected_candidate_count)
      return false;

   // For each breakpoint slope, profile the LAD intercept as the residual
   // median at chronological index six, then evaluate the absolute objective
   // in chronological order. No iterative estimator or fallback is permitted.
   for(int candidate = 0;
       candidate < candidate_slope_count;
       ++candidate)
     {
      const double slope = candidate_slopes[candidate];
      double residuals[];
      if(ArrayResize(residuals, strategy_month_end_count) !=
         strategy_month_end_count)
         return false;
      for(int index = 0; index < strategy_month_end_count; ++index)
        {
         residuals[index] =
            chronological_ratios[index] - slope * (double)index;
         if(!MathIsValidNumber(residuals[index]))
            return false;
        }
      if(!ArraySort(residuals))
         return false;
      for(int index = 0; index < strategy_month_end_count; ++index)
        {
         if(!MathIsValidNumber(residuals[index]) ||
            (index > 0 && residuals[index] < residuals[index - 1]))
            return false;
        }

      const int intercept_index = strategy_month_end_count / 2;
      if(intercept_index != 6)
         return false;
      const double intercept = residuals[intercept_index];
      if(!MathIsValidNumber(intercept))
         return false;

      double loss = 0.0;
      for(int index = 0; index < strategy_month_end_count; ++index)
        {
         const double error =
            chronological_ratios[index] - intercept -
            slope * (double)index;
         const double term = MathAbs(error);
         if(!MathIsValidNumber(error) ||
            !MathIsValidNumber(term) || term < 0.0)
            return false;
         loss += term;
         if(!MathIsValidNumber(loss) || loss < 0.0)
            return false;
        }

      candidate_losses[candidate] = loss;
      if(objective_count == 0 || loss < minimum_loss)
         minimum_loss = loss;
      ++objective_count;
     }
   if(objective_count != expected_candidate_count ||
      !MathIsValidNumber(minimum_loss) || minimum_loss < 0.0)
      return false;

   double minimizers[];
   if(ArrayResize(minimizers, expected_candidate_count) !=
      expected_candidate_count)
      return false;
   for(int candidate = 0;
       candidate < candidate_slope_count;
       ++candidate)
     {
      if(MathAbs(candidate_losses[candidate] - minimum_loss) <=
         strategy_loss_tie_epsilon)
        {
         if(minimizer_count < 0 ||
            minimizer_count >= expected_candidate_count)
            return false;
         minimizers[minimizer_count] = candidate_slopes[candidate];
         ++minimizer_count;
        }
     }
   if(minimizer_count <= 0 ||
      ArrayResize(minimizers, minimizer_count) != minimizer_count ||
      !ArraySort(minimizers))
      return false;
   for(int index = 0; index < minimizer_count; ++index)
     {
      if(!MathIsValidNumber(minimizers[index]) ||
         (index > 0 && minimizers[index] < minimizers[index - 1]))
         return false;
     }

   const int center = minimizer_count / 2;
   if((minimizer_count % 2) == 1)
      lad_slope = minimizers[center];
   else
     {
      if(center <= 0 || center >= minimizer_count)
         return false;
      lad_slope =
         minimizers[center - 1] / 2.0 + minimizers[center] / 2.0;
     }
   if(!MathIsValidNumber(lad_slope))
      return false;

   // Profile the reporting intercept at the final minimizer median and prove
   // that it still lies on the card-locked minimum-loss face.
   double final_residuals[];
   if(ArrayResize(final_residuals, strategy_month_end_count) !=
      strategy_month_end_count)
      return false;
   for(int index = 0; index < strategy_month_end_count; ++index)
     {
      final_residuals[index] =
         chronological_ratios[index] - lad_slope * (double)index;
      if(!MathIsValidNumber(final_residuals[index]))
         return false;
     }
   if(!ArraySort(final_residuals))
      return false;
   lad_intercept = final_residuals[6];
   if(!MathIsValidNumber(lad_intercept))
      return false;

   double final_loss = 0.0;
   for(int index = 0; index < strategy_month_end_count; ++index)
     {
      const double term =
         MathAbs(chronological_ratios[index] - lad_intercept -
                 lad_slope * (double)index);
      if(!MathIsValidNumber(term) || term < 0.0)
         return false;
      final_loss += term;
      if(!MathIsValidNumber(final_loss) || final_loss < 0.0)
         return false;
     }
   if(MathAbs(final_loss - minimum_loss) >
      strategy_loss_tie_epsilon)
      return false;

   // direction > 0 means BUY XTI / SELL XNG. Fade only the strict LAD
   // ratio-slope sign; endpoint displacement remains diagnostic only.
   if(lad_slope < 0.0)
      direction = 1;
   else if(lad_slope > 0.0)
      direction = -1;
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
      iTime(g_leg_xti, PERIOD_D1, 1); // perf-allowed: one monthly decision-clock endpoint.
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
   if(!Strategy_D1HistoryReady(g_leg_xti, g_current_host_bar) ||
      !Strategy_D1HistoryReady(g_leg_xng, g_current_host_bar))
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
   request.reason = "QM5_41189_XTI_XNG_MLAD_RV_HOST";
   request.symbol_slot = qm_magic_slot_offset;
   request.expiration_seconds = 0;
   if(!g_entry_ready || g_signal_month_key <= 0 ||
      g_signal_month_key != g_last_attempt_month_key ||
      Strategy_OpenOwnedPositionCount() > 0)
      return false;

   int month_count = 0;
   int candidate_slope_count = 0;
   int objective_count = 0;
   int minimizer_count = 0;
   int direction = 0;
   datetime newest_endpoint_time = 0;
   double endpoint_displacement = 0.0;
   double lad_intercept = 0.0;
   double minimum_loss = 0.0;
   double lad_slope = 0.0;
   const bool valid =
      Strategy_LoadMonthlyLad(
         g_signal_month_key,
         month_count,
         newest_endpoint_time,
         endpoint_displacement,
         candidate_slope_count,
         objective_count,
         minimizer_count,
         lad_intercept,
         minimum_loss,
         lad_slope,
         direction);
   string state = "monthly_lad_failed";
   if(valid && direction > 0)
      state = "negative_lad_fade_long_xti";
   else if(valid && direction < 0)
      state = "positive_lad_fade_short_xti";
   else if(valid && lad_slope == 0.0)
      state = "zero_lad_flat";
   else if(valid)
      state = "lad_sign_flat";

   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"month\":%d,\"month_count\":%d,\"newest_endpoint_time\":%I64d,\"endpoint_displacement\":%.12e,\"candidate_slope_count\":%d,\"objective_count\":%d,\"minimizer_count\":%d,\"lad_intercept\":%.12e,\"minimum_loss\":%.12e,\"lad_slope\":%.12e,\"direction\":%d,\"state\":\"%s\"}",
                            g_signal_month_key,
                            month_count,
                            (long)newest_endpoint_time,
                            endpoint_displacement,
                            candidate_slope_count,
                            objective_count,
                            minimizer_count,
                            lad_intercept,
                            minimum_loss,
                            lad_slope,
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
      iTime(g_leg_xti, PERIOD_D1, 1); // perf-allowed: restart month-boundary classification.
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
   QM_IsNewBar(g_leg_xti, PERIOD_D1);
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
   g_leg_xng = strategy_xng_symbol;
   if(!Strategy_IsHostChart() || !Strategy_InputsValid())
      return INIT_PARAMETERS_INCORRECT;
   if(!SymbolSelect(g_leg_xti, true) || !SymbolSelect(g_leg_xng, true))
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
         "Approved XTI/XNG thirteen-month LAD ratio reversion package holds through Fridays until next broker month"))
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

   if(Strategy_NoTradeFilter())
     {
      QM_FrameworkShutdown();
      return INIT_PARAMETERS_INCORRECT;
     }

   const int host_magic = QM_MagicChecked(qm_ea_id, 0, g_leg_xti);
   const int foreign_magic = QM_MagicChecked(qm_ea_id, 1, g_leg_xng);
   if(host_magic <= 0 || foreign_magic <= 0 ||
      !QM_KillSwitchRegisterMagic((long)foreign_magic))
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

   string basket_symbols[2] = {g_leg_xti, g_leg_xng};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols,
                          PERIOD_D1,
                          strategy_history_bars_d1);
   g_current_host_bar =
      iTime(g_leg_xti, PERIOD_D1, 0); // perf-allowed: restart state anchor.
   Strategy_LoadAttemptState(TimeCurrent());
   g_pair_entry_time = Strategy_CurrentPairEntryTime();
   if(!Strategy_PrimeLateSignalAttach())
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }
   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"QM5_41189\",\"ea\":\"xtixng-mlad-rv\"}");
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

   g_is_new_bar = QM_IsNewBar(g_leg_xti, PERIOD_D1);
   g_entry_ready = false;
   g_signal_month_key = 0;
   g_signal_late = false;
   if(g_is_new_bar || g_current_host_bar <= 0)
     {
      g_current_host_bar =
         iTime(g_leg_xti, PERIOD_D1, 0); // perf-allowed: new-bar lifecycle and entry anchor.
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
