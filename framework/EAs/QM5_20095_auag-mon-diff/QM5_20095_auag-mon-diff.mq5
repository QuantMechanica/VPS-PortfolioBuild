#property strict
#property version   "5.0"
#property description "QM5_20095 XAU XAG Monday-session relative-value basket"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_20095 - XAU/XAG Monday-session relative-value basket
// -----------------------------------------------------------------------------
// At the first eligible broker-Monday D1 boundary, buy gold and sell silver.
// Both legs target equal absolute USD notionals and share one framework risk
// budget. The complete package closes at the next host D1 boundary.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 20095;
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
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input string strategy_xag_symbol             = "XAGUSD.DWX";
input int    strategy_entry_dow              = 1;
input int    strategy_entry_grace_minutes    = 15;
input int    strategy_atr_period_d1           = 20;
input double strategy_atr_sl_mult             = 3.0;
input double strategy_notional_ratio          = 1.0;
input double strategy_max_notional_error_pct  = 20.0;
input int    strategy_max_hold_days           = 3;
input int    strategy_xau_max_spread_pts      = 1500;
input int    strategy_xag_max_spread_pts      = 500;
input int    strategy_deviation_points        = 20;

string g_leg_xau = "XAUUSD.DWX";
string g_leg_xag = "XAGUSD.DWX";

bool     g_is_new_bar = false;
bool     g_entry_ready = false;
datetime g_current_host_bar = 0;
datetime g_pair_entry_time = 0;
int      g_signal_day_key = 0;
int      g_last_attempt_day_key = 0;
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
   return (qm_ea_id == 20095 && qm_magic_slot_offset == 0 &&
           strategy_xag_symbol == "XAGUSD.DWX" &&
           strategy_entry_dow == 1 &&
           strategy_entry_grace_minutes == 15 &&
           strategy_atr_period_d1 == 20 &&
           MathAbs(strategy_atr_sl_mult - 3.0) <= 1.0e-12 &&
           MathAbs(strategy_notional_ratio - 1.0) <= 1.0e-12 &&
           MathAbs(strategy_max_notional_error_pct - 20.0) <= 1.0e-12 &&
           strategy_max_hold_days == 3 &&
           strategy_xau_max_spread_pts == 1500 &&
           strategy_xag_max_spread_pts == 500 &&
           strategy_deviation_points == 20 &&
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
   if(symbol == g_leg_xau && trade_mode == SYMBOL_TRADE_MODE_SHORTONLY)
      return false;
   if(symbol == g_leg_xag && trade_mode == SYMBOL_TRADE_MODE_LONGONLY)
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
      if(magic == Strategy_HostMagic() && symbol == g_leg_xau &&
         type == POSITION_TYPE_BUY && stop > 0.0)
         ++xau_count;
      else if(magic == Strategy_ForeignMagic() && symbol == g_leg_xag &&
              type == POSITION_TYPE_SELL && stop > 0.0)
         ++xag_count;
     }
   return (owned_count == 2 && xau_count == 1 && xag_count == 1);
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
   return (entry_time > 0 && g_current_host_bar > entry_time);
  }

string Strategy_AttemptStateKey()
  {
   return StringFormat("QM5_%d_AUAG_MON_ATTEMPT_DAY", qm_ea_id);
  }

void Strategy_LoadAttemptState(const datetime reference_time)
  {
   g_attempt_state_key = Strategy_AttemptStateKey();
   g_last_attempt_day_key = 0;
   const int current_day = Strategy_DayKey(reference_time);
   if(current_day <= 0 || !GlobalVariableCheck(g_attempt_state_key))
      return;
   const int stored_day = (int)GlobalVariableGet(g_attempt_state_key);
   if(stored_day > 0 && stored_day <= current_day)
      g_last_attempt_day_key = stored_day;
   else
      GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordAttemptState(const int day_key)
  {
   if(day_key <= 0)
      return false;
   if(g_attempt_state_key == "")
      g_attempt_state_key = Strategy_AttemptStateKey();
   g_last_attempt_day_key = day_key;
   return (GlobalVariableSet(g_attempt_state_key, (double)day_key) > 0);
  }

bool Strategy_DayAlreadyEntered(const int day_key,
                                const datetime decision_time)
  {
   if(day_key <= 0 || decision_time <= 0)
      return true;
   if(g_last_attempt_day_key == day_key)
      return true;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsOwnedMagic(PositionGetInteger(POSITION_MAGIC)))
         continue;
      if(Strategy_DayKey((datetime)PositionGetInteger(POSITION_TIME)) == day_key)
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
      if(Strategy_DayKey((datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME)) ==
         day_key)
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

bool Strategy_PreparePackage(double &xau_lots,
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

   const double xau_entry = SymbolInfoDouble(g_leg_xau, SYMBOL_ASK);
   const double xag_entry = SymbolInfoDouble(g_leg_xag, SYMBOL_BID);
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
   xau_stop = QM_StopRulesNormalizePrice(g_leg_xau,
                                          xau_entry - xau_stop_distance);
   xag_stop = QM_StopRulesNormalizePrice(g_leg_xag,
                                          xag_entry + xag_stop_distance);
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
   request.reason = "QM5_20095_AUAG_MON";
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
   double xau_lots = 0.0;
   double xag_lots = 0.0;
   double xau_stop = 0.0;
   double xag_stop = 0.0;
   if(!Strategy_PreparePackage(xau_lots, xag_lots, xau_stop, xag_stop))
      return false;
   if(!Strategy_OpenLeg(g_leg_xau, QM_BUY, xau_lots, xau_stop))
      return false;
   if(Strategy_OpenLeg(g_leg_xag, QM_SELL, xag_lots, xag_stop) &&
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

bool Strategy_EntryWindowReady()
  {
   if(!g_is_new_bar || g_current_host_bar <= 0 ||
      Strategy_DayOfWeek(g_current_host_bar) != strategy_entry_dow ||
      Strategy_OpenOwnedPositionCount() > 0)
      return false;
   const long opening_delay = (long)(TimeCurrent() - g_current_host_bar);
   if(opening_delay < 0 ||
      opening_delay > (long)strategy_entry_grace_minutes * 60)
      return false;
   const datetime xag_bar =
      iTime(g_leg_xag, PERIOD_D1, 0); // perf-allowed: synchronized Monday boundary.
   if(xag_bar <= 0 || xag_bar != g_current_host_bar)
      return false;
   const int day_key = Strategy_DayKey(g_current_host_bar);
   if(day_key <= 0 || Strategy_DayAlreadyEntered(day_key, g_current_host_bar) ||
      !Strategy_SymbolReady(g_leg_xau) || !Strategy_SymbolReady(g_leg_xag))
      return false;
   g_signal_day_key = day_key;
   return true;
  }

bool Strategy_EntrySignal(QM_EntryRequest &request)
  {
   request.type = QM_BUY;
   request.price = 0.0;
   request.sl = 0.0;
   request.tp = 0.0;
   request.reason = "QM5_20095_AUAG_MON_HOST";
   request.symbol_slot = qm_magic_slot_offset;
   request.expiration_seconds = 0;
   if(!g_entry_ready || g_signal_day_key <= 0 ||
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

   const int host_magic = QM_MagicChecked(qm_ea_id, 0, g_leg_xau);
   const int foreign_magic = QM_MagicChecked(qm_ea_id, 1, g_leg_xag);
   if(host_magic <= 0 || foreign_magic <= 0 ||
      !QM_KillSwitchRegisterMagic((long)foreign_magic))
      return INIT_FAILED;

   string basket_symbols[2] = {g_leg_xau, g_leg_xag};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols, PERIOD_D1, 80);
   g_current_host_bar =
      iTime(g_leg_xau, PERIOD_D1, 0); // perf-allowed: restart state anchor.
   Strategy_LoadAttemptState(g_current_host_bar);
   g_pair_entry_time = Strategy_CurrentPairEntryTime();
   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"QM5_20095\",\"ea\":\"auag-mon-diff\"}");
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

   g_is_new_bar = QM_IsNewBar();
   g_entry_ready = false;
   g_signal_day_key = 0;
   if(g_is_new_bar)
     {
      QM_EquityStreamOnNewBar();
      g_current_host_bar =
         iTime(g_leg_xau, PERIOD_D1, 0); // perf-allowed: new-bar lifecycle and entry anchor.
     }

   // Repair and lifecycle exits always precede entry filters and news gates.
   Strategy_ManageOpenPosition();
   if(Strategy_OpenOwnedPositionCount() > 0 || Strategy_NoTradeFilter())
      return;
   if(!Strategy_EntryWindowReady())
      return;

   // Consume this broker Monday before news or order submission. A restart,
   // news block, rejection, or repaired partial package cannot retry today.
   if(!Strategy_RecordAttemptState(g_signal_day_key))
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
