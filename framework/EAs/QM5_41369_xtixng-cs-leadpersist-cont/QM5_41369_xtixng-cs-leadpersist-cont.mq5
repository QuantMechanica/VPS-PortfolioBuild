#property strict
#property version   "5.0"
#property description "QM5_41369 XTI/XNG Common-Shock Leader-Persistence Continuation"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_41369 - XTI/XNG Common-Shock Leader-Persistence Continuation
// -----------------------------------------------------------------------------
// Reconstruct three synchronized week-end XTI/XNG close pairs for the three
// immediately preceding completed broker weeks. Require same-sign individual
// returns in both intervals and the same strict relative winner in both, then
// follow the newest winner with an equal-notional opposite-leg package. Consume
// one attempt per week and flatten at the next week boundary.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 41369;
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
input int    strategy_history_bars_d1         = 40;
input int    strategy_min_sessions_per_week   = 3;
input int    strategy_max_sessions_per_week   = 5;
input double strategy_signal_epsilon          = 1.0e-10;
input int    strategy_entry_grace_minutes    = 180;
input int    strategy_atr_period_d1           = 20;
input double strategy_atr_sl_mult             = 3.5;
input double strategy_notional_ratio          = 1.0;
input double strategy_max_notional_mismatch_pct = 20.0;
input int    strategy_max_hold_days           = 10;
input int    strategy_xti_max_spread_points   = 1500;
input int    strategy_xng_max_spread_points   = 3000;
input int    strategy_deviation_points        = 20;

string g_leg_xti = "XTIUSD.DWX";
string g_leg_xng = "XNGUSD.DWX";
bool     g_is_new_bar = false;
bool     g_entry_ready = false;
bool     g_late_decision = false;
datetime g_current_host_bar = 0;
datetime g_pair_entry_time = 0;
int      g_signal_week_key = 0;
int      g_last_attempt_week_key = 0;
string   g_attempt_state_key = "";
double   g_wti_older_return = 0.0;
double   g_xng_older_return = 0.0;
double   g_wti_newer_return = 0.0;
double   g_xng_newer_return = 0.0;
double   g_older_relative_return = 0.0;
double   g_newer_relative_return = 0.0;
double   g_xti_week_close[3]; // newest, middle, oldest completed week.
double   g_xng_week_close[3];
int      g_week_key[3];
int      g_week_sessions[3];
string   g_signal_state = "idle";

int Strategy_DayKey(const datetime value)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   if(value <= 0 || !TimeToStruct(value, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

int Strategy_DayOfWeek(const datetime value)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   if(value <= 0 || !TimeToStruct(value, parts))
      return -1;
   return parts.day_of_week;
  }

int Strategy_WeekKey(const datetime value)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   if(value <= 0 || !TimeToStruct(value, parts))
      return 0;
   const int days_since_monday = (parts.day_of_week + 6) % 7;
   return Strategy_DayKey(value - (datetime)(days_since_monday * 86400));
  }

int Strategy_NextWeekKey(const int week_key)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   parts.year = week_key / 10000;
   parts.mon = (week_key / 100) % 100;
   parts.day = week_key % 100;
   if(parts.year < 1900 || parts.mon < 1 || parts.mon > 12 ||
      parts.day < 1 || parts.day > 31)
      return 0;
   const datetime anchor = StructToTime(parts);
   if(anchor <= 0 || Strategy_DayKey(anchor) != week_key ||
      Strategy_WeekKey(anchor) != week_key)
      return 0;
   return Strategy_WeekKey(anchor + (datetime)(7L * 86400L));
  }

bool Strategy_WithinEntryGrace(const datetime broker_now)
  {
   if(broker_now <= 0 || g_current_host_bar <= 0 ||
      strategy_entry_grace_minutes < 0)
      return false;
   const long elapsed = (long)(broker_now - g_current_host_bar);
   if(elapsed < 0)
      return false;
   return (elapsed <= (long)strategy_entry_grace_minutes * 60L);
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
   return (qm_ea_id == 41369 && qm_magic_slot_offset == 0 &&
            strategy_xng_symbol == "XNGUSD.DWX" &&
            strategy_history_bars_d1 == 40 &&
            strategy_min_sessions_per_week == 3 &&
            strategy_max_sessions_per_week == 5 &&
            MathAbs(strategy_signal_epsilon - 1.0e-10) <= 1.0e-18 &&
            strategy_entry_grace_minutes == 180 &&
            strategy_atr_period_d1 == 20 &&
            MathAbs(strategy_atr_sl_mult - 3.5) <= 1.0e-12 &&
            MathAbs(strategy_notional_ratio - 1.0) <= 1.0e-12 &&
            MathAbs(strategy_max_notional_mismatch_pct - 20.0) <= 1.0e-12 &&
            strategy_max_hold_days == 10 &&
            strategy_xti_max_spread_points == 1500 &&
            strategy_xng_max_spread_points == 3000 &&
            strategy_deviation_points == 20 &&
            MathIsValidNumber(RISK_PERCENT) &&
            RISK_PERCENT == 0.0 &&
            MathIsValidNumber(RISK_FIXED) &&
            RISK_FIXED > 0.0 &&
            MathIsValidNumber(qm_stress_reject_probability) &&
            qm_stress_reject_probability >= 0.0 &&
            qm_stress_reject_probability <= 1.0);
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
      strategy_atr_period_d1 + 2)
      return false;
   const datetime current_bar =
      iTime(symbol, PERIOD_D1, 0); // perf-allowed: entry-only basket sync gate.
   const datetime completed_bar =
      iTime(symbol, PERIOD_D1, 1); // perf-allowed: entry-only stale-history gate.
   if(current_bar != expected_bar || completed_bar <= 0 ||
      current_bar <= completed_bar)
      return false;
   return ((long)(current_bar - completed_bar) <= 4L * 86400L);
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
      if(stop <= 0.0 || volume <= 0.0 || opened <= 0.0 || opened_at <= 0 ||
         (type == POSITION_TYPE_BUY && stop >= opened) ||
         (type == POSITION_TYPE_SELL && stop <= opened))
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
   const double error_pct =
      100.0 * MathAbs(actual_ratio - strategy_notional_ratio) /
      strategy_notional_ratio;
   return (MathIsValidNumber(error_pct) &&
            error_pct <= strategy_max_notional_mismatch_pct);
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

bool Strategy_LaterWeekReached()
  {
   datetime entry_time = g_pair_entry_time;
   if(entry_time <= 0)
      entry_time = Strategy_CurrentPairEntryTime();
   const datetime broker_now = TimeCurrent();
   const int entry_week = Strategy_WeekKey(entry_time);
   const int current_week = Strategy_WeekKey(broker_now);
   return (entry_time > 0 && broker_now > entry_time &&
           entry_week > 0 && current_week > 0 &&
           current_week != entry_week);
  }

string Strategy_AttemptStateKey()
  {
   return StringFormat("QM5_%d_XTIXNG_CS_LEADPERSIST_ATTEMPT_WEEK", qm_ea_id);
  }

void Strategy_LoadAttemptState(const datetime reference_time)
  {
   g_attempt_state_key = Strategy_AttemptStateKey();
   g_last_attempt_week_key = 0;
   const int current_date = Strategy_DayKey(reference_time);
   if(current_date <= 0 || !GlobalVariableCheck(g_attempt_state_key))
      return;
   const double stored = GlobalVariableGet(g_attempt_state_key);
   const int stored_date = (int)MathRound(stored);
   if(MathIsValidNumber(stored) && stored_date >= 19000101 &&
      stored_date <= current_date)
      g_last_attempt_week_key = stored_date;
   else
      GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordAttemptState(const int week_key)
  {
   if(week_key <= 0)
      return false;
   if(g_attempt_state_key == "")
      g_attempt_state_key = Strategy_AttemptStateKey();
   g_last_attempt_week_key = week_key;
   return (GlobalVariableSet(g_attempt_state_key, (double)week_key) > 0);
  }

bool Strategy_WeekHasOwnedEntry(const int week_key,
                                 const datetime decision_time)
  {
   if(week_key <= 0 || decision_time <= 0)
      return true;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsOwnedMagic(PositionGetInteger(POSITION_MAGIC)))
         continue;
      if(Strategy_WeekKey((datetime)PositionGetInteger(POSITION_TIME)) ==
         week_key)
         return true;
     }
   const datetime history_start = decision_time - (datetime)(10 * 86400);
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
      if(Strategy_WeekKey((datetime)HistoryDealGetInteger(deal_ticket,
                                                          DEAL_TIME)) ==
          week_key)
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
   const double lot_ratio_xti_to_xng =
      strategy_notional_ratio * xng_notional_per_lot /
      xti_notional_per_lot;
   const double normalized_risk_per_xng_lot =
       lot_ratio_xti_to_xng / full_xti_lots + 1.0 / full_xng_lots;
   if(lot_ratio_xti_to_xng <= 0.0 ||
      normalized_risk_per_xng_lot <= 0.0 ||
      !MathIsValidNumber(normalized_risk_per_xng_lot))
      return false;

   const double raw_xng_lots = 1.0 / normalized_risk_per_xng_lot;
   const double raw_xti_lots = lot_ratio_xti_to_xng * raw_xng_lots;
   xti_lots = Strategy_RoundLotsDown(g_leg_xti, raw_xti_lots);
   xng_lots = Strategy_RoundLotsDown(g_leg_xng, raw_xng_lots);
   if(xti_lots <= 0.0 || xng_lots <= 0.0)
      return false;

   const double normalized_stop_risk =
      xti_lots / full_xti_lots + xng_lots / full_xng_lots;
   const double actual_ratio =
      xti_lots * xti_notional_per_lot /
      (xng_lots * xng_notional_per_lot);
   const double error_pct =
      100.0 * MathAbs(actual_ratio - strategy_notional_ratio) /
      strategy_notional_ratio;
   return (MathIsValidNumber(normalized_stop_risk) &&
           normalized_stop_risk <= 1.0 + 1.0e-8 &&
           MathIsValidNumber(error_pct) &&
            error_pct <= strategy_max_notional_mismatch_pct);
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
   request.reason = "QM5_41369_XTIXNG_CS_LEADPERSIST_CONT";
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

bool Strategy_LoadLeaderPersistence(const int current_week,
                                    int &direction)
  {
   direction = 0;
   g_wti_older_return = 0.0;
   g_xng_older_return = 0.0;
   g_wti_newer_return = 0.0;
   g_xng_newer_return = 0.0;
   g_older_relative_return = 0.0;
   g_newer_relative_return = 0.0;
   for(int slot = 0; slot < 3; ++slot)
     {
      g_xti_week_close[slot] = 0.0;
      g_xng_week_close[slot] = 0.0;
      g_week_key[slot] = 0;
      g_week_sessions[slot] = 0;
     }
   if(current_week <= 0 || g_current_host_bar <= 0 ||
      Strategy_WeekKey(g_current_host_bar) != current_week ||
      iTime(g_leg_xng, PERIOD_D1, 0) != // perf-allowed: decision-only companion current-bar synchronization.
         g_current_host_bar)
      return false;

   MqlRates xti_bars[];
   MqlRates xng_bars[];
   ArraySetAsSeries(xti_bars, true);
   ArraySetAsSeries(xng_bars, true);
   const int xti_copied =
      CopyRates(g_leg_xti, // perf-allowed: decision-only bounded completed-week endpoint scan.
                PERIOD_D1, 1, strategy_history_bars_d1, xti_bars);
   const int xng_copied =
      CopyRates(g_leg_xng, // perf-allowed: decision-only bounded completed-week endpoint scan.
                PERIOD_D1, 1, strategy_history_bars_d1, xng_bars);
   if(xti_copied != strategy_history_bars_d1 ||
      xng_copied != strategy_history_bars_d1)
      return false;

   for(int index = 0; index < strategy_history_bars_d1; ++index)
     {
      if(xti_bars[index].time <= 0 ||
         xti_bars[index].time != xng_bars[index].time ||
         (index > 0 && xti_bars[index - 1].time <= xti_bars[index].time))
         return false;

      const int week_key = Strategy_WeekKey(xti_bars[index].time);
      if(week_key <= 0 || week_key == current_week)
         return false;

      int slot = -1;
      for(int known = 0; known < 3; ++known)
        {
         if(g_week_key[known] == week_key)
           {
            slot = known;
            break;
           }
        }

      if(slot < 0 && g_week_key[0] == 0)
        {
         if(Strategy_NextWeekKey(week_key) != current_week)
            return false;
         g_week_key[0] = week_key;
         slot = 0;
        }
      else if(slot < 0 && g_week_key[1] == 0)
        {
         if(Strategy_NextWeekKey(week_key) != g_week_key[0])
            return false;
         g_week_key[1] = week_key;
         slot = 1;
        }
      else if(slot < 0 && g_week_key[2] == 0)
        {
         if(Strategy_NextWeekKey(week_key) != g_week_key[1])
            return false;
         g_week_key[2] = week_key;
         slot = 2;
        }
      else if(slot < 0)
         break;

      if(xti_bars[index].close <= 0.0 || xng_bars[index].close <= 0.0 ||
         !MathIsValidNumber(xti_bars[index].close) ||
         !MathIsValidNumber(xng_bars[index].close))
         return false;

      if(slot >= 0 && slot < 3)
        {
         if(g_week_sessions[slot] == 0)
           {
            g_xti_week_close[slot] = xti_bars[index].close;
            g_xng_week_close[slot] = xng_bars[index].close;
           }
         ++g_week_sessions[slot];
        }
     }

   if(g_week_key[0] <= 0 || g_week_key[1] <= 0 || g_week_key[2] <= 0 ||
      Strategy_NextWeekKey(g_week_key[0]) != current_week ||
      Strategy_NextWeekKey(g_week_key[1]) != g_week_key[0] ||
      Strategy_NextWeekKey(g_week_key[2]) != g_week_key[1])
      return false;
   for(int slot = 0; slot < 3; ++slot)
     {
      if(g_week_sessions[slot] < strategy_min_sessions_per_week ||
         g_week_sessions[slot] > strategy_max_sessions_per_week ||
         g_xti_week_close[slot] <= 0.0 ||
         g_xng_week_close[slot] <= 0.0)
         return false;
     }

   g_wti_older_return =
      MathLog(g_xti_week_close[1] / g_xti_week_close[2]);
   g_xng_older_return =
      MathLog(g_xng_week_close[1] / g_xng_week_close[2]);
   g_wti_newer_return =
      MathLog(g_xti_week_close[0] / g_xti_week_close[1]);
   g_xng_newer_return =
      MathLog(g_xng_week_close[0] / g_xng_week_close[1]);
   if(!MathIsValidNumber(g_wti_older_return) ||
      !MathIsValidNumber(g_xng_older_return) ||
      !MathIsValidNumber(g_wti_newer_return) ||
      !MathIsValidNumber(g_xng_newer_return))
      return false;

   const bool older_same_sign =
      ((g_wti_older_return > 0.0 && g_xng_older_return > 0.0) ||
       (g_wti_older_return < 0.0 && g_xng_older_return < 0.0));
   const bool newer_same_sign =
      ((g_wti_newer_return > 0.0 && g_xng_newer_return > 0.0) ||
       (g_wti_newer_return < 0.0 && g_xng_newer_return < 0.0));
   g_older_relative_return = g_wti_older_return - g_xng_older_return;
   g_newer_relative_return = g_wti_newer_return - g_xng_newer_return;
   if(older_same_sign && newer_same_sign &&
      g_older_relative_return > strategy_signal_epsilon &&
      g_newer_relative_return > strategy_signal_epsilon)
      direction = 1; // WTI remained the winner: buy XTI, sell XNG.
   else if(older_same_sign && newer_same_sign &&
           g_older_relative_return < -strategy_signal_epsilon &&
           g_newer_relative_return < -strategy_signal_epsilon)
      direction = -1; // natural gas remained the winner: sell XTI, buy XNG.
   return true;
  }

bool Strategy_DecisionClockReady(int &week_key)
  {
   week_key = 0;
   g_late_decision = false;
   if(!g_is_new_bar || g_current_host_bar <= 0)
      return false;

   const datetime broker_now = TimeCurrent();
   const datetime xng_current =
      iTime(g_leg_xng, PERIOD_D1, 0); // perf-allowed: new-bar basket clock synchronization.
   const int current_week = Strategy_WeekKey(g_current_host_bar);
   if(broker_now <= 0 || xng_current != g_current_host_bar ||
      Strategy_DayKey(g_current_host_bar) != Strategy_DayKey(broker_now) ||
      current_week <= 0 || current_week != Strategy_WeekKey(broker_now))
      return false;

   const int clock_scan_bars = 10;
   MqlRates xti_bars[];
   MqlRates xng_bars[];
   ArraySetAsSeries(xti_bars, true);
   ArraySetAsSeries(xng_bars, true);
   const int xti_copied =
      CopyRates(g_leg_xti, // perf-allowed: new-bar-only bounded broker-week clock.
                PERIOD_D1, 1, clock_scan_bars, xti_bars);
   const int xng_copied =
      CopyRates(g_leg_xng, // perf-allowed: new-bar-only bounded basket clock synchronization.
                PERIOD_D1, 1, clock_scan_bars, xng_bars);
   if(xti_copied != clock_scan_bars || xng_copied != clock_scan_bars)
      return false;

   int completed_current_week_bars = 0;
   for(int index = 0; index < clock_scan_bars; ++index)
     {
      if(xti_bars[index].time <= 0 ||
         xti_bars[index].time != xng_bars[index].time ||
         (index > 0 && xti_bars[index - 1].time <= xti_bars[index].time))
         return false;
      if(Strategy_WeekKey(xti_bars[index].time) != current_week)
         break;
      ++completed_current_week_bars;
     }
   if(completed_current_week_bars >= clock_scan_bars)
      return false;
   const int prior_week =
      Strategy_WeekKey(xti_bars[completed_current_week_bars].time);
   if(prior_week <= 0 || Strategy_NextWeekKey(prior_week) != current_week)
      return false;

   week_key = current_week;
   g_late_decision =
      (completed_current_week_bars > 0 ||
       !Strategy_WithinEntryGrace(broker_now));
   return (week_key != g_last_attempt_week_key);
  }

bool Strategy_EntrySignal(QM_EntryRequest &request)
  {
   request.type = QM_BUY;
   request.price = 0.0;
   request.sl = 0.0;
   request.tp = 0.0;
   request.reason = "QM5_41369_XTIXNG_CS_LEADPERSIST_CONT_HOST";
   request.symbol_slot = qm_magic_slot_offset;
   request.expiration_seconds = 0;
   if(!g_entry_ready || g_signal_week_key <= 0 ||
      g_signal_week_key == g_last_attempt_week_key)
      return false;

   // The valid broker-week clock is enough to consume the attempt. Persist
   // before history, endpoint, signal, news, spread, quote, ATR, sizing, or
   // either order gate so restarts and transient failures cannot backfill.
   if(!Strategy_RecordAttemptState(g_signal_week_key))
     {
      g_signal_state = "attempt_persist_failed";
      return false;
     }

   g_wti_older_return = 0.0;
   g_xng_older_return = 0.0;
   g_wti_newer_return = 0.0;
   g_xng_newer_return = 0.0;
   g_older_relative_return = 0.0;
   g_newer_relative_return = 0.0;
   g_signal_state = "decision_consumed";
   int direction = 0;
   bool signal_valid = false;
   if(Strategy_OpenOwnedPositionCount() > 0 ||
      Strategy_WeekHasOwnedEntry(g_signal_week_key, TimeCurrent()))
      g_signal_state = "entry_deal_already_exists";
   else if(g_late_decision)
      g_signal_state = "late_restart_consumed_flat";
   else if(!Strategy_D1HistoryReady(g_leg_xti, g_current_host_bar) ||
           !Strategy_D1HistoryReady(g_leg_xng, g_current_host_bar))
      g_signal_state = "history_not_ready";
   else
     {
      signal_valid =
         Strategy_LoadLeaderPersistence(g_signal_week_key, direction);
      if(!signal_valid)
         g_signal_state = "endpoint_validation_failed";
      else if(direction > 0)
         g_signal_state = "wti_relative_leader_persisted_long_xti";
      else if(direction < 0)
         g_signal_state = "xng_relative_leader_persisted_short_xti";
      else if(g_wti_older_return == 0.0 ||
              g_xng_older_return == 0.0 ||
              g_wti_newer_return == 0.0 ||
              g_xng_newer_return == 0.0)
         g_signal_state = "exact_zero_flat";
      else if((g_wti_older_return > 0.0) !=
              (g_xng_older_return > 0.0) ||
              (g_wti_newer_return > 0.0) !=
              (g_xng_newer_return > 0.0))
         g_signal_state = "mixed_sign_week_flat";
      else
         g_signal_state = "no_strict_same_leader_persistence_flat";
     }

   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"week\":%d,\"decision_bar\":%I64d,\"late\":%s,\"valid\":%s,\"direction\":%d,\"wti_older_return\":%.12e,\"xng_older_return\":%.12e,\"wti_newer_return\":%.12e,\"xng_newer_return\":%.12e,\"older_relative\":%.12e,\"newer_relative\":%.12e,\"oldest_week\":%d,\"middle_week\":%d,\"newest_week\":%d,\"oldest_sessions\":%d,\"middle_sessions\":%d,\"newest_sessions\":%d,\"state\":\"%s\"}",
                            g_signal_week_key,
                            (long)g_current_host_bar,
                            g_late_decision ? "true" : "false",
                            signal_valid ? "true" : "false",
                            direction,
                            g_wti_older_return,
                            g_xng_older_return,
                            g_wti_newer_return,
                            g_xng_newer_return,
                            g_older_relative_return,
                            g_newer_relative_return,
                            g_week_key[2],
                            g_week_key[1],
                            g_week_key[0],
                            g_week_sessions[2],
                            g_week_sessions[1],
                            g_week_sessions[0],
                            g_signal_state));
   if(signal_valid && direction != 0)
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
   if(Strategy_LaterWeekReached())
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
         "Approved XTI/XNG common-shock leader-persistence package exits at the next broker week"))
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
   QM_BasketWarmupHistory(basket_symbols, PERIOD_D1,
                          strategy_history_bars_d1 +
                          strategy_atr_period_d1 + 10);
   g_current_host_bar =
      iTime(g_leg_xti, PERIOD_D1, 0); // perf-allowed: restart state anchor.
   Strategy_LoadAttemptState(TimeCurrent());
   g_pair_entry_time = Strategy_CurrentPairEntryTime();
   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"QM5_41369\",\"ea\":\"xtixng-cs-leadpersist-cont\"}");
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

   g_is_new_bar = QM_IsNewBar(g_leg_xti, PERIOD_D1);
   g_entry_ready = false;
   g_signal_week_key = 0;
   if(g_is_new_bar || g_current_host_bar <= 0)
     {
      g_current_host_bar =
         iTime(g_leg_xti, PERIOD_D1, 0); // perf-allowed: new-bar lifecycle and entry anchor.
      if(g_is_new_bar)
         QM_EquityStreamOnNewBar();
     }

   // Repair and lifecycle exits always precede entry filters and news gates.
   Strategy_ManageOpenPosition();
   if(Strategy_OpenOwnedPositionCount() > 0 || Strategy_NoTradeFilter())
      return;
   if(!Strategy_DecisionClockReady(g_signal_week_key))
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




