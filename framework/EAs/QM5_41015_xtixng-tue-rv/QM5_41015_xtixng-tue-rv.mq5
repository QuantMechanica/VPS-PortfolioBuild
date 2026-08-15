#property strict
#property version   "5.0"
#property description "QM5_41015 XTI XNG Tuesday-session relative-value basket"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_41015 - XTI/XNG Tuesday-session relative-value basket
// -----------------------------------------------------------------------------
// At the first eligible broker-Tuesday D1 boundary, sell WTI and buy Natural
// Gas. Both legs target equal absolute USD notionals and share one framework
// risk budget. The complete package closes at broker Tuesday hour 21.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 41015;
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
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input string strategy_xng_symbol             = "XNGUSD.DWX";
input int    strategy_entry_dow              = 2;
input int    strategy_entry_grace_minutes    = 5;
input int    strategy_exit_hour_broker       = 21;
input int    strategy_atr_period_d1           = 20;
input double strategy_atr_sl_mult             = 3.5;
input double strategy_notional_ratio          = 1.0;
input double strategy_max_notional_error_pct  = 15.0;
input int    strategy_max_hold_days           = 3;
input int    strategy_xti_max_spread_pts      = 1500;
input int    strategy_xng_max_spread_pts      = 3000;
input int    strategy_deviation_points        = 20;

string g_leg_xti = "XTIUSD.DWX";
string g_leg_xng = "XNGUSD.DWX";

bool     g_is_new_bar = false;
bool     g_entry_ready = false;
datetime g_current_host_bar = 0;
datetime g_pair_entry_time = 0;
int      g_signal_week_key = 0;
int      g_last_attempt_week_key = 0;
string   g_attempt_state_key = "";

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

bool Strategy_WithinEntryGrace(const datetime broker_now)
  {
   if(broker_now <= 0 || g_current_host_bar <= 0 ||
      strategy_entry_grace_minutes < 0)
      return false;
   const long elapsed = (long)(broker_now - g_current_host_bar);
   if(elapsed < 0)
      return false;
   // Darwinex energy D1 bars may carry the prior calendar date while keeping
   // the session-open time. Modulo one day handles either native or prior-day
   // labels without turning a late restart into an eligible first tick.
   const long session_elapsed = elapsed % 86400L;
   return (session_elapsed <= (long)strategy_entry_grace_minutes * 60L);
  }

bool Strategy_CompletedPredecessorIsMonday()
  {
   const datetime completed_bar =
      iTime(g_leg_xti, PERIOD_D1, 1); // perf-allowed: decision-clock predecessor.
   if(completed_bar <= 0)
      return false;
   // Energy D1 bars are labelled with the prior calendar date in the factory.
   return (Strategy_DayOfWeek(completed_bar + (datetime)86400) == 1);
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
   return (qm_ea_id == 41015 && qm_magic_slot_offset == 0 &&
           strategy_xng_symbol == "XNGUSD.DWX" &&
           strategy_entry_dow == 2 &&
           strategy_entry_grace_minutes == 5 &&
           strategy_exit_hour_broker == 21 &&
           strategy_atr_period_d1 == 20 &&
           MathAbs(strategy_atr_sl_mult - 3.5) <= 1.0e-12 &&
           MathAbs(strategy_notional_ratio - 1.0) <= 1.0e-12 &&
           MathAbs(strategy_max_notional_error_pct - 15.0) <= 1.0e-12 &&
           strategy_max_hold_days == 3 &&
           strategy_xti_max_spread_pts == 1500 &&
           strategy_xng_max_spread_pts == 3000 &&
           strategy_deviation_points == 20 &&
           qm_news_temporal == QM_NEWS_TEMPORAL_OFF &&
           qm_news_compliance == QM_NEWS_COMPLIANCE_NONE &&
           qm_news_mode_legacy == QM_NEWS_OFF &&
           qm_friday_close_enabled && qm_friday_close_hour_broker == 21);
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
      return (spread_points <= (double)strategy_xti_max_spread_pts);
   if(symbol == g_leg_xng)
      return (spread_points <= (double)strategy_xng_max_spread_pts);
   return false;
  }

bool Strategy_SymbolReady(const string symbol)
  {
   const long trade_mode = SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
   if(trade_mode == SYMBOL_TRADE_MODE_DISABLED ||
      trade_mode == SYMBOL_TRADE_MODE_CLOSEONLY)
      return false;
   if(symbol == g_leg_xti && trade_mode == SYMBOL_TRADE_MODE_LONGONLY)
      return false;
   if(symbol == g_leg_xng && trade_mode == SYMBOL_TRADE_MODE_SHORTONLY)
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
   return ((long)(current_bar - completed_bar) <= 3L * 86400L);
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
      if(magic == Strategy_HostMagic() && symbol == g_leg_xti &&
         type == POSITION_TYPE_SELL && stop > 0.0)
         ++xti_count;
      else if(magic == Strategy_ForeignMagic() && symbol == g_leg_xng &&
              type == POSITION_TYPE_BUY && stop > 0.0)
         ++xng_count;
     }
   return (owned_count == 2 && xti_count == 1 && xng_count == 1);
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
           error_pct <= strategy_max_notional_error_pct);
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

bool Strategy_NextBoundaryReached()
  {
   datetime entry_time = g_pair_entry_time;
   if(entry_time <= 0)
      entry_time = Strategy_CurrentPairEntryTime();
   const datetime broker_now = TimeCurrent();
   return (entry_time > 0 && broker_now > entry_time &&
           Strategy_DayKey(broker_now) != Strategy_DayKey(entry_time));
  }

bool Strategy_NormalExitReached()
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   const datetime broker_now = TimeCurrent();
   if(broker_now <= 0 || !TimeToStruct(broker_now, parts))
      return false;
   return (parts.day_of_week == strategy_entry_dow &&
           parts.hour >= strategy_exit_hour_broker);
  }

string Strategy_AttemptStateKey()
  {
   return StringFormat("QM5_%d_XTIXNG_TUE_ATTEMPT_WEEK", qm_ea_id);
  }

void Strategy_LoadAttemptState(const datetime reference_time)
  {
   g_attempt_state_key = Strategy_AttemptStateKey();
   g_last_attempt_week_key = 0;
   const int current_week = Strategy_WeekKey(reference_time);
   if(current_week <= 0 || !GlobalVariableCheck(g_attempt_state_key))
      return;
   const int stored_week = (int)GlobalVariableGet(g_attempt_state_key);
   if(stored_week > 0 && stored_week <= current_week)
      g_last_attempt_week_key = stored_week;
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
      if(Strategy_WeekKey((datetime)PositionGetInteger(POSITION_TIME)) == week_key)
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

bool Strategy_PreparePackage(double &xti_lots,
                             double &xng_lots,
                             double &xti_stop,
                             double &xng_stop)
  {
   xti_lots = 0.0;
   xng_lots = 0.0;
   xti_stop = 0.0;
   xng_stop = 0.0;
   if(!Strategy_SymbolReady(g_leg_xti) || !Strategy_SymbolReady(g_leg_xng))
      return false;

   const double xti_entry = SymbolInfoDouble(g_leg_xti, SYMBOL_BID);
   const double xng_entry = SymbolInfoDouble(g_leg_xng, SYMBOL_ASK);
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
   xti_stop = QM_StopRulesNormalizePrice(g_leg_xti,
                                          xti_entry + xti_stop_distance);
   xng_stop = QM_StopRulesNormalizePrice(g_leg_xng,
                                          xng_entry - xng_stop_distance);
   if(xti_stop <= 0.0 || xng_stop <= 0.0)
      return false;

   const double full_xti_lots =
      QM_LotsForRisk(g_leg_xti, xti_stop_distance / xti_point);
   const double full_xng_lots =
      QM_LotsForRisk(g_leg_xng, xng_stop_distance / xng_point);
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
           error_pct <= strategy_max_notional_error_pct);
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
   request.reason = "QM5_41015_XTIXNG_TUE_RV";
   request.symbol_slot = slot;
   request.expiration_seconds = 0;
   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy,
                                strategy_deviation_points, request, ticket);
  }

bool Strategy_OpenPair()
  {
   if(Strategy_OpenOwnedPositionCount() > 0)
      return false;
   double xti_lots = 0.0;
   double xng_lots = 0.0;
   double xti_stop = 0.0;
   double xng_stop = 0.0;
   if(!Strategy_PreparePackage(xti_lots, xng_lots, xti_stop, xng_stop))
      return false;
   if(!Strategy_OpenLeg(g_leg_xti, QM_SELL, xti_lots, xti_stop))
      return false;
   if(Strategy_OpenLeg(g_leg_xng, QM_BUY, xng_lots, xng_stop) &&
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

bool Strategy_DecisionClockReady(int &week_key)
  {
   week_key = 0;
   const datetime broker_now = TimeCurrent();
   if(!g_is_new_bar || g_current_host_bar <= 0 ||
      Strategy_DayOfWeek(broker_now) != strategy_entry_dow ||
      !Strategy_CompletedPredecessorIsMonday())
      return false;
   week_key = Strategy_WeekKey(broker_now);
   return (week_key > 0 && g_last_attempt_week_key != week_key);
  }

bool Strategy_EntryWindowReady(const int week_key)
  {
   const datetime broker_now = TimeCurrent();
   if(week_key <= 0 || g_current_host_bar <= 0 ||
      Strategy_OpenOwnedPositionCount() > 0 ||
      !Strategy_WithinEntryGrace(broker_now))
      return false;
   if(!Strategy_D1HistoryReady(g_leg_xti, g_current_host_bar) ||
      !Strategy_D1HistoryReady(g_leg_xng, g_current_host_bar))
      return false;
   // Darwinex energy D1 bars are session-labelled with the prior calendar
   // date.  The genuine QM_IsNewBar() tick is the executable session open;
   // use its broker date for the card's Tuesday decision and week key.
   if(Strategy_WeekHasOwnedEntry(week_key, broker_now) ||
      !Strategy_SymbolReady(g_leg_xti) || !Strategy_SymbolReady(g_leg_xng))
      return false;
   return true;
  }

bool Strategy_EntrySignal(QM_EntryRequest &request)
  {
   request.type = QM_SELL;
   request.price = 0.0;
   request.sl = 0.0;
   request.tp = 0.0;
   request.reason = "QM5_41015_XTIXNG_TUE_RV_HOST";
   request.symbol_slot = qm_magic_slot_offset;
   request.expiration_seconds = 0;
   if(!g_entry_ready || g_signal_week_key <= 0 ||
      Strategy_OpenOwnedPositionCount() > 0)
      return false;
   Strategy_OpenPair();
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
   if(Strategy_NormalExitReached())
     {
      Strategy_CloseAllOwned(QM_EXIT_STRATEGY);
      return;
     }
   if(Strategy_NextBoundaryReached())
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

bool Strategy_NewsAllowsEntry(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
     {
      return (QM_NewsAllowsTrade2(g_leg_xti, broker_time,
                                  qm_news_temporal, qm_news_compliance) &&
              QM_NewsAllowsTrade2(g_leg_xng, broker_time,
                                  qm_news_temporal, qm_news_compliance));
     }
   return (QM_NewsAllowsTrade(g_leg_xti, broker_time, qm_news_mode_legacy) &&
           QM_NewsAllowsTrade(g_leg_xng, broker_time, qm_news_mode_legacy));
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return !Strategy_NewsAllowsEntry(broker_time);
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

   const int host_magic = QM_MagicChecked(qm_ea_id, 0, g_leg_xti);
   const int foreign_magic = QM_MagicChecked(qm_ea_id, 1, g_leg_xng);
   if(host_magic <= 0 || foreign_magic <= 0 ||
      !QM_KillSwitchRegisterMagic((long)foreign_magic))
      return INIT_FAILED;

   string basket_symbols[2] = {g_leg_xti, g_leg_xng};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols, PERIOD_D1, 80);
   g_current_host_bar =
      iTime(g_leg_xti, PERIOD_D1, 0); // perf-allowed: restart state anchor.
   // Prime the shared tracker so attaching after the session open cannot turn
   // the current bar into a synthetic "new" bar and bypass the grace contract.
   QM_IsNewBar();
   Strategy_LoadAttemptState(TimeCurrent());
   g_pair_entry_time = Strategy_CurrentPairEntryTime();
   // Any Tuesday attachment consumes the week flat. The shared new-bar
   // tracker is already primed, so restarts never synthesize an entry signal.
   const datetime init_now = TimeCurrent();
   const int init_week = Strategy_WeekKey(init_now);
   if(Strategy_DayOfWeek(init_now) == strategy_entry_dow &&
      init_week > 0 && g_last_attempt_week_key != init_week)
      Strategy_RecordAttemptState(init_week);
   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"QM5_41015\",\"ea\":\"xtixng-tue-rv\"}");
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
   if(QM_FrameworkFridayCloseNow(broker_now))
     {
      // Explicit pair flatten, then framework sweep as a redundant retry.
      Strategy_CloseAllOwned(QM_EXIT_FRIDAY_CLOSE);
      QM_FrameworkHandleFridayClose();
      return;
     }

   g_is_new_bar = QM_IsNewBar();
   g_entry_ready = false;
   g_signal_week_key = 0;
   if(g_is_new_bar)
     {
      QM_EquityStreamOnNewBar();
      g_current_host_bar =
         iTime(g_leg_xti, PERIOD_D1, 0); // perf-allowed: new-bar lifecycle and entry anchor.
     }

   // Repair and lifecycle exits always precede entry filters and news gates.
   Strategy_ManageOpenPosition();
   if(Strategy_OpenOwnedPositionCount() > 0 || Strategy_NoTradeFilter())
      return;
   if(!Strategy_DecisionClockReady(g_signal_week_key))
      return;

   // Consume this broker week before history, news, sizing, or order
   // submission. A restart, block, reject, stop, or repair cannot retry.
   if(!Strategy_RecordAttemptState(g_signal_week_key))
      return;
   if(!Strategy_EntryWindowReady(g_signal_week_key))
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
