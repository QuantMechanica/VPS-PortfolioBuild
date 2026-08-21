#property strict
#property version   "5.0"
#property description "QM5_41086 XAU/XAG Weekly Common-Shock Dispersion Reversion"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_41086 - XAU/XAG Weekly Common-Shock Dispersion Reversion
// -----------------------------------------------------------------------------
// Reconstruct the synchronized week-end XAU/XAG close pairs for the two
// immediately preceding completed broker weeks. When the individual gold and
// silver log returns over that exact interval share a strict sign, fade the
// relative outperformer with an equal-notional opposite-leg package.
// Consume one attempt per week and flatten at the next week boundary.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 41086;
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
input int    strategy_history_bars_d1         = 30;
input int    strategy_min_sessions_per_week   = 3;
input int    strategy_max_sessions_per_week   = 5;
input double strategy_signal_epsilon          = 1.0e-10;
input int    strategy_entry_grace_minutes    = 180;
input int    strategy_atr_period_d1           = 20;
input double strategy_atr_sl_mult             = 3.5;
input double strategy_notional_ratio          = 1.0;
input double strategy_max_notional_mismatch_pct = 20.0;
input int    strategy_max_hold_days           = 10;
input int    strategy_xau_max_spread_points   = 1500;
input int    strategy_xag_max_spread_points   = 500;
input int    strategy_deviation_points        = 20;

string g_leg_xau = "XAUUSD.DWX";
string g_leg_xag = "XAGUSD.DWX";
bool     g_is_new_bar = false;
bool     g_entry_ready = false;
bool     g_late_decision = false;
datetime g_current_host_bar = 0;
datetime g_pair_entry_time = 0;
int      g_signal_week_key = 0;
int      g_last_attempt_week_key = 0;
string   g_attempt_state_key = "";
double   g_gold_week_return = 0.0;
double   g_silver_week_return = 0.0;
double   g_xau_older_close = 0.0;
double   g_xau_newer_close = 0.0;
double   g_xag_older_close = 0.0;
double   g_xag_newer_close = 0.0;
int      g_older_week_sessions = 0;
int      g_newer_week_sessions = 0;
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
   return (qm_ea_id == 41086 && qm_magic_slot_offset == 0 &&
            qm_rng_seed == 42 &&
            strategy_xag_symbol == "XAGUSD.DWX" &&
            strategy_history_bars_d1 == 30 &&
            strategy_min_sessions_per_week == 3 &&
            strategy_max_sessions_per_week == 5 &&
            MathAbs(strategy_signal_epsilon - 1.0e-10) <= 1.0e-18 &&
            strategy_entry_grace_minutes == 180 &&
            strategy_atr_period_d1 == 20 &&
            MathAbs(strategy_atr_sl_mult - 3.5) <= 1.0e-12 &&
            MathAbs(strategy_notional_ratio - 1.0) <= 1.0e-12 &&
            MathAbs(strategy_max_notional_mismatch_pct - 20.0) <= 1.0e-12 &&
            strategy_max_hold_days == 10 &&
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
      if(stop <= 0.0 || volume <= 0.0 || opened <= 0.0 || opened_at <= 0 ||
         (type == POSITION_TYPE_BUY && stop >= opened) ||
         (type == POSITION_TYPE_SELL && stop <= opened))
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
   return StringFormat("QM5_%d_XAUXAG_COMMONSHOCK_ATTEMPT_WEEK", qm_ea_id);
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
   const double lot_ratio_xau_to_xag =
      strategy_notional_ratio * xag_notional_per_lot /
      xau_notional_per_lot;
   const double normalized_risk_per_xag_lot =
       lot_ratio_xau_to_xag / full_xau_lots + 1.0 / full_xag_lots;
   if(lot_ratio_xau_to_xag <= 0.0 ||
      normalized_risk_per_xag_lot <= 0.0 ||
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
   const double actual_ratio =
      xau_lots * xau_notional_per_lot /
      (xag_lots * xag_notional_per_lot);
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
   request.reason = "QM5_41086_XAUXAG_COMMONSHOCK_RV";
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

bool Strategy_LoadWeeklyCommonShock(const int current_week,
                                    int &direction)
  {
   direction = 0;
   g_gold_week_return = 0.0;
   g_silver_week_return = 0.0;
   g_xau_older_close = 0.0;
   g_xau_newer_close = 0.0;
   g_xag_older_close = 0.0;
   g_xag_newer_close = 0.0;
   g_older_week_sessions = 0;
   g_newer_week_sessions = 0;
   if(current_week <= 0 || g_current_host_bar <= 0 ||
      Strategy_WeekKey(g_current_host_bar) != current_week ||
      iTime(g_leg_xag, PERIOD_D1, 0) != // perf-allowed: decision-only companion current-bar synchronization.
         g_current_host_bar)
      return false;

   MqlRates xau_bars[];
   MqlRates xag_bars[];
   ArraySetAsSeries(xau_bars, true);
   ArraySetAsSeries(xag_bars, true);
   const int xau_copied =
      CopyRates(g_leg_xau, // perf-allowed: decision-only bounded completed-week endpoint scan.
                PERIOD_D1, 1, strategy_history_bars_d1, xau_bars);
   const int xag_copied =
      CopyRates(g_leg_xag, // perf-allowed: decision-only bounded completed-week endpoint scan.
                PERIOD_D1, 1, strategy_history_bars_d1, xag_bars);
   if(xau_copied != strategy_history_bars_d1 ||
      xag_copied != strategy_history_bars_d1)
      return false;

   int newer_week = 0;
   int older_week = 0;
   for(int index = 0; index < strategy_history_bars_d1; ++index)
     {
      if(xau_bars[index].time <= 0 ||
         xau_bars[index].time != xag_bars[index].time ||
         (index > 0 && xau_bars[index - 1].time <= xau_bars[index].time))
         return false;

      const int week_key = Strategy_WeekKey(xau_bars[index].time);
      if(week_key <= 0 || week_key == current_week)
         return false;

      if(newer_week == 0)
        {
         if(Strategy_NextWeekKey(week_key) != current_week)
            return false;
         newer_week = week_key;
        }
      else if(week_key != newer_week && older_week == 0)
        {
         if(Strategy_NextWeekKey(week_key) != newer_week)
            return false;
         older_week = week_key;
        }
      else if(week_key != newer_week && week_key != older_week)
         break;

      if(xau_bars[index].close <= 0.0 || xag_bars[index].close <= 0.0 ||
         !MathIsValidNumber(xau_bars[index].close) ||
         !MathIsValidNumber(xag_bars[index].close))
         return false;

      if(week_key == newer_week)
        {
         if(g_newer_week_sessions == 0)
           {
            g_xau_newer_close = xau_bars[index].close;
            g_xag_newer_close = xag_bars[index].close;
           }
         ++g_newer_week_sessions;
        }
      else if(week_key == older_week)
        {
         if(g_older_week_sessions == 0)
           {
            g_xau_older_close = xau_bars[index].close;
            g_xag_older_close = xag_bars[index].close;
           }
         ++g_older_week_sessions;
        }
     }

   if(newer_week <= 0 || older_week <= 0 ||
      Strategy_NextWeekKey(newer_week) != current_week ||
      Strategy_NextWeekKey(older_week) != newer_week ||
      g_newer_week_sessions < strategy_min_sessions_per_week ||
      g_newer_week_sessions > strategy_max_sessions_per_week ||
      g_older_week_sessions < strategy_min_sessions_per_week ||
      g_older_week_sessions > strategy_max_sessions_per_week ||
      g_xau_older_close <= 0.0 || g_xau_newer_close <= 0.0 ||
      g_xag_older_close <= 0.0 || g_xag_newer_close <= 0.0)
      return false;

   g_gold_week_return = MathLog(g_xau_newer_close / g_xau_older_close);
   g_silver_week_return = MathLog(g_xag_newer_close / g_xag_older_close);
   if(!MathIsValidNumber(g_gold_week_return) ||
      !MathIsValidNumber(g_silver_week_return))
      return false;

   const bool same_positive =
      (g_gold_week_return > 0.0 && g_silver_week_return > 0.0);
   const bool same_negative =
      (g_gold_week_return < 0.0 && g_silver_week_return < 0.0);
   const double relative_return =
      g_gold_week_return - g_silver_week_return;
   if((same_positive || same_negative) &&
      relative_return > strategy_signal_epsilon)
      direction = -1; // Gold outperformed: sell XAU, buy XAG.
   else if((same_positive || same_negative) &&
           relative_return < -strategy_signal_epsilon)
      direction = 1; // Silver outperformed: buy XAU, sell XAG.
   return true;
  }

bool Strategy_DecisionClockReady(int &week_key)
  {
   week_key = 0;
   g_late_decision = false;
   if(!g_is_new_bar || g_current_host_bar <= 0)
      return false;

   const datetime broker_now = TimeCurrent();
   const datetime xag_current =
      iTime(g_leg_xag, PERIOD_D1, 0); // perf-allowed: new-bar basket clock synchronization.
   const int current_week = Strategy_WeekKey(g_current_host_bar);
   if(broker_now <= 0 || xag_current != g_current_host_bar ||
      Strategy_DayKey(g_current_host_bar) != Strategy_DayKey(broker_now) ||
      current_week <= 0 || current_week != Strategy_WeekKey(broker_now))
      return false;

   const int clock_scan_bars = 10;
   MqlRates xau_bars[];
   MqlRates xag_bars[];
   ArraySetAsSeries(xau_bars, true);
   ArraySetAsSeries(xag_bars, true);
   const int xau_copied =
      CopyRates(g_leg_xau, // perf-allowed: new-bar-only bounded broker-week clock.
                PERIOD_D1, 1, clock_scan_bars, xau_bars);
   const int xag_copied =
      CopyRates(g_leg_xag, // perf-allowed: new-bar-only bounded basket clock synchronization.
                PERIOD_D1, 1, clock_scan_bars, xag_bars);
   if(xau_copied != clock_scan_bars || xag_copied != clock_scan_bars)
      return false;

   int completed_current_week_bars = 0;
   for(int index = 0; index < clock_scan_bars; ++index)
     {
      if(xau_bars[index].time <= 0 ||
         xau_bars[index].time != xag_bars[index].time ||
         (index > 0 && xau_bars[index - 1].time <= xau_bars[index].time))
         return false;
      if(Strategy_WeekKey(xau_bars[index].time) != current_week)
         break;
      ++completed_current_week_bars;
     }
   if(completed_current_week_bars >= clock_scan_bars)
      return false;
   const int prior_week =
      Strategy_WeekKey(xau_bars[completed_current_week_bars].time);
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
   request.reason = "QM5_41086_XAUXAG_COMMONSHOCK_RV_HOST";
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

   g_gold_week_return = 0.0;
   g_silver_week_return = 0.0;
   g_xau_older_close = 0.0;
   g_xau_newer_close = 0.0;
   g_xag_older_close = 0.0;
   g_xag_newer_close = 0.0;
   g_older_week_sessions = 0;
   g_newer_week_sessions = 0;
   g_signal_state = "decision_consumed";
   int direction = 0;
   bool signal_valid = false;
   if(Strategy_OpenOwnedPositionCount() > 0 ||
      Strategy_WeekHasOwnedEntry(g_signal_week_key, TimeCurrent()))
      g_signal_state = "entry_deal_already_exists";
   else if(g_late_decision)
      g_signal_state = "late_restart_consumed_flat";
   else if(!Strategy_D1HistoryReady(g_leg_xau, g_current_host_bar) ||
           !Strategy_D1HistoryReady(g_leg_xag, g_current_host_bar))
      g_signal_state = "history_not_ready";
   else
     {
      signal_valid =
         Strategy_LoadWeeklyCommonShock(g_signal_week_key, direction);
      if(!signal_valid)
         g_signal_state = "endpoint_validation_failed";
      else if(direction < 0)
         g_signal_state = "gold_relative_outperformer_fade_short_xau";
      else if(direction > 0)
         g_signal_state = "silver_relative_outperformer_fade_long_xau";
      else if(g_gold_week_return == 0.0 ||
              g_silver_week_return == 0.0)
         g_signal_state = "exact_zero_flat";
      else if((g_gold_week_return > 0.0) !=
              (g_silver_week_return > 0.0))
         g_signal_state = "mixed_sign_flat";
      else
         g_signal_state = "relative_equality_flat";
     }

   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"week\":%d,\"decision_bar\":%I64d,\"late\":%s,\"valid\":%s,\"direction\":%d,\"gold_return\":%.12e,\"silver_return\":%.12e,\"xau_older\":%.10f,\"xau_newer\":%.10f,\"xag_older\":%.10f,\"xag_newer\":%.10f,\"older_sessions\":%d,\"newer_sessions\":%d,\"state\":\"%s\"}",
                            g_signal_week_key,
                            (long)g_current_host_bar,
                            g_late_decision ? "true" : "false",
                            signal_valid ? "true" : "false",
                            direction,
                            g_gold_week_return,
                            g_silver_week_return,
                            g_xau_older_close,
                            g_xau_newer_close,
                            g_xag_older_close,
                            g_xag_newer_close,
                            g_older_week_sessions,
                            g_newer_week_sessions,
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
         "Approved XAU/XAG weekly common-shock package exits at the next broker week"))
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
   QM_BasketWarmupHistory(basket_symbols, PERIOD_D1,
                          strategy_history_bars_d1 +
                          strategy_atr_period_d1 + 10);
   g_current_host_bar =
      iTime(g_leg_xau, PERIOD_D1, 0); // perf-allowed: restart state anchor.
   Strategy_LoadAttemptState(TimeCurrent());
   g_pair_entry_time = Strategy_CurrentPairEntryTime();
   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"QM5_41086\",\"ea\":\"xauxag-commonshock-rv\"}");
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

   g_is_new_bar = QM_IsNewBar(g_leg_xau, PERIOD_D1);
   g_entry_ready = false;
   g_signal_week_key = 0;
   if(g_is_new_bar || g_current_host_bar <= 0)
     {
      g_current_host_bar =
         iTime(g_leg_xau, PERIOD_D1, 0); // perf-allowed: new-bar lifecycle and entry anchor.
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
