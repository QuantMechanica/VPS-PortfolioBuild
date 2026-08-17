#property strict
#property version   "5.0"
#property description "QM5_32008 Euro triplet statistical arbitrage"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QuantMechanica V5 three-leg EUR triangular-residual basket.
//
// Approved card:
//   strategy-seeds/cards/approved/
//   QM5_32008_euro-triplet-statistical-arbitrage-eurostable.md
//
// Closed-M15 residual:
//   epsilon = ln(EURUSD.DWX) - ln(EURGBP.DWX) - ln(GBPUSD.DWX)
//
// The coefficients are fixed by the approved identity. No coefficient fitting,
// adaptive weighting, or ML state is permitted at runtime.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 32008;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

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
input int    strategy_lookback_bars       = 60;
input double strategy_entry_z             = 2.20;
input double strategy_exit_z              = 0.20;
input double strategy_stop_z              = 3.80;
input int    strategy_atr_period          = 14;
input double strategy_spread_atr_mult     = 1.80;
input int    strategy_deviation_points    = 3;

string g_symbols[3] = {"EURUSD.DWX", "EURGBP.DWX", "GBPUSD.DWX"};
int    g_slots[3]   = {0, 1, 2};

bool   g_basket_scope_ready = false;
bool   g_state_ready = false;
double g_residual_z = 0.0;
double g_residual_mean = 0.0;
double g_residual_sd = 0.0;
double g_atr[3] = {0.0, 0.0, 0.0};
double g_initial_equity = 0.0;

bool         g_companion_ready[2] = {false, false};
QM_OrderType g_companion_type[2] = {QM_BUY, QM_BUY};
double       g_companion_lots[2] = {0.0, 0.0};
double       g_companion_sl[2] = {0.0, 0.0};

int Strategy_SlotForSymbol(const string symbol)
  {
   for(int i = 0; i < 3; ++i)
      if(symbol == g_symbols[i])
         return g_slots[i];
   return -1;
  }

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_symbols[0] &&
           (ENUM_TIMEFRAMES)_Period == PERIOD_M15 &&
           qm_magic_slot_offset == 0);
  }

bool Strategy_InputsValid()
  {
   if(qm_ea_id != 32008 || !Strategy_IsHostChart())
      return false;
   if(RISK_FIXED <= 0.0 || RISK_PERCENT != 0.0)
      return false;
   if(PORTFOLIO_WEIGHT <= 0.0 || PORTFOLIO_WEIGHT > 1.0)
      return false;
   if(strategy_lookback_bars < 30 || strategy_lookback_bars > 120)
      return false;
   if(strategy_entry_z < 1.8 || strategy_entry_z > 2.8)
      return false;
   if(strategy_exit_z < 0.0 || strategy_exit_z > 0.5)
      return false;
   if(strategy_exit_z >= strategy_entry_z)
      return false;
   if(MathAbs(strategy_stop_z - 3.80) > 1e-9)
      return false;
   if(strategy_atr_period != 14 ||
      MathAbs(strategy_spread_atr_mult - 1.80) > 1e-9)
      return false;
   return (strategy_deviation_points == 3 &&
           qm_friday_close_enabled &&
           qm_friday_close_hour_broker == 21);
  }

void Strategy_ResetPendingPackage()
  {
   for(int i = 0; i < 2; ++i)
     {
      g_companion_ready[i] = false;
      g_companion_type[i] = QM_BUY;
      g_companion_lots[i] = 0.0;
      g_companion_sl[i] = 0.0;
     }
  }

bool Strategy_EnsureBasketScope()
  {
   if(g_basket_scope_ready)
      return true;

   for(int i = 0; i < 3; ++i)
      if(!SymbolSelect(g_symbols[i], true))
         return false;

   QM_SymbolGuardInit(g_symbols);
   QM_BasketWarmupHistory(g_symbols,
                          PERIOD_M15,
                          MathMax(200,
                                  strategy_lookback_bars +
                                  strategy_atr_period + 20));
   g_basket_scope_ready = true;
   return true;
  }

bool Strategy_IsOwnedPosition()
  {
   const string symbol = PositionGetString(POSITION_SYMBOL);
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0)
      return false;
   return ((int)PositionGetInteger(POSITION_MAGIC) ==
           QM_MagicChecked(qm_ea_id, slot, symbol));
  }

int Strategy_OpenLegCount()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsOwnedPosition())
         ++count;
     }
   return count;
  }

void Strategy_ClosePackage(const QM_ExitReason reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsOwnedPosition())
         QM_TM_ClosePosition(ticket, reason);
     }
  }

bool Strategy_RefreshResidualState()
  {
   g_state_ready = false;
   const int history_count = strategy_lookback_bars + 1;

   if(!Strategy_EnsureBasketScope())
      return false;
   for(int i = 0; i < 3; ++i)
      if(!QM_SymbolAssertOrLog(g_symbols[i]))
         return false;

   double eurusd[];
   double eurgbp[];
   double gbpusd[];
   datetime eurusd_time[];
   datetime eurgbp_time[];
   datetime gbpusd_time[];
   ArraySetAsSeries(eurusd, true);
   ArraySetAsSeries(eurgbp, true);
   ArraySetAsSeries(gbpusd, true);
   ArraySetAsSeries(eurusd_time, true);
   ArraySetAsSeries(eurgbp_time, true);
   ArraySetAsSeries(gbpusd_time, true);

   if(CopyClose(g_symbols[0], PERIOD_M15, 1, history_count, eurusd) != history_count) // perf-allowed: closed-M15 basket refresh only.
      return false;
   if(CopyClose(g_symbols[1], PERIOD_M15, 1, history_count, eurgbp) != history_count) // perf-allowed: closed-M15 basket refresh only.
      return false;
   if(CopyClose(g_symbols[2], PERIOD_M15, 1, history_count, gbpusd) != history_count) // perf-allowed: closed-M15 basket refresh only.
      return false;
   if(CopyTime(g_symbols[0], PERIOD_M15, 1, history_count, eurusd_time) != history_count) // perf-allowed: closed-M15 basket alignment only.
      return false;
   if(CopyTime(g_symbols[1], PERIOD_M15, 1, history_count, eurgbp_time) != history_count) // perf-allowed: closed-M15 basket alignment only.
      return false;
   if(CopyTime(g_symbols[2], PERIOD_M15, 1, history_count, gbpusd_time) != history_count) // perf-allowed: closed-M15 basket alignment only.
      return false;

   double residuals[];
   ArrayResize(residuals, history_count);
   for(int i = 0; i < history_count; ++i)
     {
      if(eurusd_time[i] <= 0 ||
         eurusd_time[i] != eurgbp_time[i] ||
         eurusd_time[i] != gbpusd_time[i])
         return false;
      if(eurusd[i] <= 0.0 || eurgbp[i] <= 0.0 || gbpusd[i] <= 0.0)
         return false;

      residuals[i] = MathLog(eurusd[i]) -
                     MathLog(eurgbp[i]) -
                     MathLog(gbpusd[i]);
      if(!MathIsValidNumber(residuals[i]))
         return false;
     }

   // Score the most recent closed bar against strictly prior closed bars.
   double sum = 0.0;
   for(int i = 1; i < history_count; ++i)
      sum += residuals[i];
   g_residual_mean = sum / (double)strategy_lookback_bars;

   double variance_sum = 0.0;
   for(int i = 1; i < history_count; ++i)
     {
      const double delta = residuals[i] - g_residual_mean;
      variance_sum += delta * delta;
     }
   g_residual_sd = MathSqrt(variance_sum /
                            (double)MathMax(1,
                                            strategy_lookback_bars - 1));
   if(g_residual_sd <= 0.0 || !MathIsValidNumber(g_residual_sd))
      return false;

   g_residual_z = (residuals[0] - g_residual_mean) / g_residual_sd;
   if(!MathIsValidNumber(g_residual_z))
      return false;

   for(int i = 0; i < 3; ++i)
     {
      g_atr[i] = QM_ATR(g_symbols[i],
                         PERIOD_M15,
                         strategy_atr_period,
                         1);
      if(g_atr[i] <= 0.0 || !MathIsValidNumber(g_atr[i]))
         return false;
     }

   g_state_ready = true;
   return true;
  }

datetime Strategy_UTCNow(const datetime broker_now)
  {
   datetime utc_now = QM_BrokerToUTC(broker_now);
   if(utc_now <= 0)
      utc_now = TimeGMT();
   return utc_now;
  }

bool Strategy_InRolloverBlackout(const datetime broker_now)
  {
   MqlDateTime utc;
   TimeToStruct(Strategy_UTCNow(broker_now), utc);
   const int minute_of_day = utc.hour * 60 + utc.min;
   return (minute_of_day >= 1435 || minute_of_day <= 5);
  }

bool Strategy_WideSpread()
  {
   if(!g_state_ready)
      return true;
   for(int i = 0; i < 3; ++i)
     {
      const double ask = SymbolInfoDouble(g_symbols[i], SYMBOL_ASK);
      const double bid = SymbolInfoDouble(g_symbols[i], SYMBOL_BID);
      if(ask <= 0.0 || bid <= 0.0 || ask < bid || g_atr[i] <= 0.0)
         return true;
      if(ask > bid && (ask - bid) > strategy_spread_atr_mult * g_atr[i])
         return true;
     }
   return false;
  }

double Strategy_StopPrice(const int leg,
                          const QM_OrderType type,
                          const double entry)
  {
   if(leg < 0 || leg >= 3 || entry <= 0.0 || g_residual_sd <= 0.0)
      return 0.0;

   // The card defines a package z-stop but no leg-level broker-stop mapping.
   // Give every leg the full remaining residual log-distance. This is a
   // conservative catastrophe rail: correlated moves are handled by the
   // closed-bar package z-stop, while no individual leg can consume more than
   // its one-third fixed-risk allocation.
   const double remaining_z = strategy_stop_z - MathAbs(g_residual_z);
   if(remaining_z <= 0.0)
      return 0.0;
   const double log_distance = remaining_z * g_residual_sd;
   if(log_distance <= 0.0 || !MathIsValidNumber(log_distance))
      return 0.0;

   const double raw_stop = QM_OrderTypeIsBuy(type)
                           ? entry * MathExp(-log_distance)
                           : entry * MathExp(log_distance);
   return QM_StopRulesNormalizePrice(g_symbols[leg], raw_stop);
  }

double Strategy_LotsForLeg(const int leg,
                           const double entry,
                           const double stop)
  {
   if(leg < 0 || leg >= 3 || entry <= 0.0 || stop <= 0.0)
      return 0.0;
   const double point = SymbolInfoDouble(g_symbols[leg], SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   const double sl_points = MathAbs(entry - stop) / point;
   if(sl_points <= 0.0)
      return 0.0;
   return QM_LotsForRisk(g_symbols[leg], sl_points);
  }

bool Strategy_PreparePackage(const int residual_direction,
                             QM_EntryRequest &host_req)
  {
   Strategy_ResetPendingPackage();
   if(residual_direction == 0 ||
      Strategy_OpenLegCount() > 0 ||
      !g_state_ready ||
      MathAbs(g_residual_z) >= strategy_stop_z)
      return false;

   QM_OrderType leg_types[3];
   if(residual_direction > 0)
     {
      // Long residual: BUY EURUSD, SELL EURGBP, SELL GBPUSD.
      leg_types[0] = QM_BUY;
      leg_types[1] = QM_SELL;
      leg_types[2] = QM_SELL;
     }
   else
     {
      // Short residual: SELL EURUSD, BUY EURGBP, BUY GBPUSD.
      leg_types[0] = QM_SELL;
      leg_types[1] = QM_BUY;
      leg_types[2] = QM_BUY;
     }

   double entries[3];
   double stops[3];
   double lots[3];
   for(int i = 0; i < 3; ++i)
     {
      entries[i] = QM_OrderTypeIsBuy(leg_types[i])
                   ? SymbolInfoDouble(g_symbols[i], SYMBOL_ASK)
                   : SymbolInfoDouble(g_symbols[i], SYMBOL_BID);
      stops[i] = Strategy_StopPrice(i, leg_types[i], entries[i]);
      lots[i] = Strategy_LotsForLeg(i, entries[i], stops[i]);
      if(entries[i] <= 0.0 || stops[i] <= 0.0 || lots[i] <= 0.0)
         return false;
      if((QM_OrderTypeIsBuy(leg_types[i]) && stops[i] >= entries[i]) ||
         (!QM_OrderTypeIsBuy(leg_types[i]) && stops[i] <= entries[i]))
         return false;
     }

   const string reason = residual_direction > 0
                         ? "QM5_32008_LONG_RESIDUAL_Z_LE_NEG_ENTRY"
                         : "QM5_32008_SHORT_RESIDUAL_Z_GE_POS_ENTRY";

   host_req.type = leg_types[0];
   host_req.price = 0.0;
   host_req.sl = stops[0];
   host_req.tp = 0.0;
   host_req.reason = reason;
   host_req.symbol_slot = qm_magic_slot_offset;
   host_req.expiration_seconds = 0;

   for(int i = 0; i < 2; ++i)
     {
      g_companion_type[i] = leg_types[i + 1];
      g_companion_lots[i] = lots[i + 1];
      g_companion_sl[i] = stops[i + 1];
      g_companion_ready[i] = true;
     }
   return true;
  }

bool Strategy_OpenCompanion(const int companion_index,
                            const string reason)
  {
   if(companion_index < 0 || companion_index >= 2 ||
      !g_companion_ready[companion_index])
      return false;

   const int leg = companion_index + 1;
   QM_BasketOrderRequest req;
   req.symbol = g_symbols[leg];
   req.type = g_companion_type[companion_index];
   req.price = 0.0;
   req.sl = g_companion_sl[companion_index];
   req.tp = 0.0;
   req.lots = g_companion_lots[companion_index];
   req.reason = reason;
   req.symbol_slot = g_slots[leg];
   req.expiration_seconds = 0;

   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id,
                                qm_news_mode_legacy,
                                strategy_deviation_points,
                                req,
                                ticket);
  }

bool Strategy_AccountRiskStopHit()
  {
   const double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity_now <= 0.0)
      return true;
   if(g_qm_ks_day_start_equity > 0.0 &&
      equity_now <= g_qm_ks_day_start_equity * 0.975)
      return true;
   return (g_initial_equity > 0.0 && equity_now <= g_initial_equity * 0.95);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart() || !g_state_ready)
      return true;
   if(PositionsTotal() >= 1)
      return true;
   if(Strategy_InRolloverBlackout(TimeCurrent()) || Strategy_WideSpread())
      return true;

   // With no external cash flows in qualification, balance drawdown from the
   // persisted framework day anchor is the card's realized-loss entry gate.
   const double balance_now = AccountInfoDouble(ACCOUNT_BALANCE);
   if(g_qm_ks_day_start_equity > 0.0 &&
      balance_now <= g_qm_ks_day_start_equity * 0.98)
      return true;
   return Strategy_AccountRiskStopHit();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_32008_TRIPLET_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_state_ready || Strategy_OpenLegCount() > 0)
      return false;
   if(g_residual_z <= -strategy_entry_z)
      return Strategy_PreparePackage(1, req);
   if(g_residual_z >= strategy_entry_z)
      return Strategy_PreparePackage(-1, req);
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // No trailing, break-even, partial close, averaging, grid, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   const int open_legs = Strategy_OpenLegCount();
   if(open_legs <= 0)
      return false;

   if(open_legs != 3 || Strategy_AccountRiskStopHit())
     {
      Strategy_ClosePackage(QM_EXIT_STRATEGY);
      return false;
     }

   if(g_state_ready &&
      (MathAbs(g_residual_z) <= strategy_exit_z ||
       MathAbs(g_residual_z) >= strategy_stop_z))
     {
      Strategy_ClosePackage(QM_EXIT_STRATEGY);
      return false;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   for(int i = 0; i < 3; ++i)
     {
      bool allowed = true;
      if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
         qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
         allowed = QM_NewsAllowsTrade2(g_symbols[i],
                                       broker_time,
                                       qm_news_temporal,
                                       qm_news_compliance);
      else
         allowed = QM_NewsAllowsTrade(g_symbols[i],
                                      broker_time,
                                      qm_news_mode_legacy);
      if(!allowed)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!Strategy_InputsValid())
      return INIT_PARAMETERS_INCORRECT;
   for(int i = 0; i < 3; ++i)
      if(!SymbolSelect(g_symbols[i], true))
         return INIT_FAILED;

   // Equal fixed coefficients receive equal thirds of the package risk budget.
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT / 3.0,
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
         PERIOD_M15,
         QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
         "V5 qualification safety override: flatten the complete triplet Friday 21 broker"))
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

   if(!Strategy_EnsureBasketScope())
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }
   for(int i = 1; i < 3; ++i)
     {
      const int magic = QM_MagicChecked(qm_ea_id, g_slots[i], g_symbols[i]);
      if(magic <= 0 || !QM_KillSwitchRegisterMagic((long)magic))
        {
         QM_FrameworkShutdown();
         return INIT_FAILED;
        }
     }

   g_initial_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   Strategy_ResetPendingPackage();
   Strategy_RefreshResidualState();
   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_32008_euro-triplet-statistical-arbitrage-eurostable\",\"basket_legs\":3}");
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
   // Q08 lifecycle sampling must precede every early-return guard.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkFridayCloseNow(broker_now))
     {
      Strategy_ClosePackage(QM_EXIT_FRIDAY_CLOSE);
      QM_FrameworkHandleFridayClose();
      return;
     }
   if(QM_FrameworkHandleFridayClose())
      return;

   // Consume the host new-bar gate once. Management and exits run before all
   // entry-only spread, rollover, and news suppression.
   const bool is_new_signal_bar =
      QM_IsNewBar(g_symbols[0], PERIOD_M15);
   if(is_new_signal_bar)
     {
      Strategy_RefreshResidualState();
      QM_EquityStreamOnNewBar();
     }

   Strategy_ManageOpenPosition();
   Strategy_ExitSignal();

   if(Strategy_NoTradeFilter())
      return;
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(!is_new_signal_bar)
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
     {
      ulong host_ticket = 0;
      const bool host_opened = QM_TM_OpenPosition(req, host_ticket);
      bool package_opened = host_opened;
      if(package_opened)
         package_opened = Strategy_OpenCompanion(0, req.reason);
      if(package_opened)
         package_opened = Strategy_OpenCompanion(1, req.reason);
      if(!package_opened && Strategy_OpenLegCount() > 0)
         Strategy_ClosePackage(QM_EXIT_STRATEGY);
      Strategy_ResetPendingPackage();
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
