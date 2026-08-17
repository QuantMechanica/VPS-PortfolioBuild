#property strict
#property version   "5.0"
#property description "QM5_21502 XAUUSD Weekly Time-Series Momentum (Short-Horizon Price Proxy)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_21502 - XAUUSD Weekly Time-Series Momentum (Short-Horizon Price Proxy)
// -----------------------------------------------------------------------------
// Structural D1 gold sleeve:
//   - evaluate once when the framework broker-week bucket changes
//   - compute trailing 5 completed D1 return: (Close[1] - Close[6]) / Close[6]
//   - sign(return) determines direction (+1 BUY, -1 SELL); hold-until-flip logic
//   - persist the attempted week before fallible gates so there is no retry
//   - ATR hard stop, 15-bar max hold time exit, atomic signal-flip exit
// Runtime uses native MT5 XAU D1 bars only; no external signal feed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 21502;
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
input int    strategy_lookback_bars       = 5;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 2.5;
input int    strategy_max_hold_bars       = 15;
input int    strategy_max_spread_points   = 300;

int    g_last_attempt_week_key = 0;
string g_attempt_state_key     = "";
bool   g_weekly_evaluation_bar = false;
bool   g_cached_signal_valid   = false;
int    g_cached_direction      = 0;
int    g_cached_week_key       = 0;
double g_cached_week_return    = 0.0;
double g_cached_atr            = 0.0;
string g_cached_state_reason   = "not_evaluated";

void Strategy_ResetCachedSignal()
  {
   g_cached_signal_valid = false;
   g_cached_direction    = 0;
   g_cached_week_key     = 0;
   g_cached_week_return  = 0.0;
   g_cached_atr          = 0.0;
   g_cached_state_reason = "not_evaluated";
  }

bool Strategy_IsExpectedHost()
  {
   return (_Symbol == "XAUUSD.DWX" && _Period == PERIOD_D1);
  }

bool Strategy_HasOwnedPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

void Strategy_LoadAttemptState()
  {
   g_last_attempt_week_key = 0;
   if(g_attempt_state_key == "" || !GlobalVariableCheck(g_attempt_state_key))
      return;

   const int current_week_key = QM_CalendarPeriodKey(PERIOD_W1, _Symbol, 0);
   const double stored = GlobalVariableGet(g_attempt_state_key);
   const int stored_week_key = (int)MathRound(stored);
   if(current_week_key > 0 &&
      MathIsValidNumber(stored) &&
      stored_week_key >= 1900000 &&
      stored_week_key <= current_week_key)
     {
      g_last_attempt_week_key = stored_week_key;
      return;
     }

   GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordWeekAttempt(const int week_key)
  {
   if(week_key <= 0 || g_attempt_state_key == "")
      return false;
   if(GlobalVariableSet(g_attempt_state_key, (double)week_key) <= 0)
      return false;
   GlobalVariablesFlush();
   g_last_attempt_week_key = week_key;
   return true;
  }

bool Strategy_CopyClosedD1Closes(double &closes[], const int bars_needed)
  {
   if(bars_needed < 2)
      return false;

   ArrayResize(closes, bars_needed);
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, bars_needed, closes); // perf-allowed: bounded D1 vector behind QM_IsNewBar for structural weekly momentum.
   return (copied >= bars_needed);
  }

bool Strategy_LoadWeeklyState(int &direction,
                              double &week_return,
                              double &atr_last)
  {
   direction = 0;
   week_return = 0.0;
   atr_last = 0.0;

   const int lookback = MathMax(1, strategy_lookback_bars);
   const int bars_needed = lookback + 1;
   double closes[];
   if(!Strategy_CopyClosedD1Closes(closes, bars_needed))
     {
      g_cached_state_reason = "history_invalid";
      return false;
     }

   const double latest_close = closes[0];
   const double formation_close = closes[lookback];
   if(latest_close <= 0.0 || formation_close <= 0.0)
     {
      g_cached_state_reason = "close_invalid";
      return false;
     }

   week_return = (latest_close / formation_close) - 1.0;
   if(!MathIsValidNumber(week_return))
     {
      g_cached_state_reason = "return_invalid";
      return false;
     }

   if(week_return > 0.0)
      direction = 1;
   else if(week_return < 0.0)
      direction = -1;
   else
     {
      g_cached_state_reason = "zero_return";
      return false;
     }

   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_last <= 0.0 || !MathIsValidNumber(atr_last))
     {
      g_cached_state_reason = "atr_invalid";
      return false;
     }

   g_cached_state_reason = "signal_ready";
   return true;
  }

void Strategy_PrepareWeeklySignal()
  {
   Strategy_ResetCachedSignal();
   g_weekly_evaluation_bar = false;

   const int current_week_key =
      QM_CalendarPeriodKey(PERIOD_W1, _Symbol, 0);
   const int preceding_bar_week_key =
      QM_CalendarPeriodKey(PERIOD_W1, _Symbol, 1);
   if(current_week_key <= 0 || preceding_bar_week_key <= 0)
     {
      g_cached_state_reason = "week_key_invalid";
      return;
     }
   if(current_week_key == preceding_bar_week_key)
     {
      g_cached_state_reason = "not_week_transition";
      return;
     }
   if(current_week_key == g_last_attempt_week_key)
     {
      g_cached_state_reason = "week_already_attempted";
      return;
     }

   if(!Strategy_RecordWeekAttempt(current_week_key))
     {
      g_cached_state_reason = "attempt_persist_failed";
      return;
     }

   g_weekly_evaluation_bar = true;
   g_cached_week_key = current_week_key;

   g_cached_signal_valid =
      Strategy_LoadWeeklyState(g_cached_direction,
                               g_cached_week_return,
                               g_cached_atr);

   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"week_key\":%d,\"valid\":%s,\"direction\":%d,\"return\":%.10f,\"reason\":\"%s\"}",
                            g_cached_week_key,
                            g_cached_signal_valid ? "true" : "false",
                            g_cached_direction,
                            g_cached_week_return,
                            g_cached_state_reason));
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsExpectedHost())
      return true;
   if(qm_ea_id != 21502 || qm_magic_slot_offset != 0)
      return true;
   if(strategy_lookback_bars < 1 || strategy_lookback_bars > 60)
      return true;
   if(strategy_atr_period <= 1 || strategy_atr_period > 100)
      return true;
   if(strategy_atr_sl_mult <= 0.0 || strategy_atr_sl_mult > 20.0)
      return true;
   if(strategy_max_hold_bars <= 0 || strategy_max_hold_bars > 60)
      return true;
   if(strategy_max_spread_points <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_21502_XAU_WEEKLY_TSMOM";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_weekly_evaluation_bar ||
      !g_cached_signal_valid ||
      g_cached_week_key != g_last_attempt_week_key ||
      (g_cached_direction != 1 && g_cached_direction != -1))
      return false;

   // Atomic-reverse fail-closed guard: fresh-state management must have
   // closed an opposite position before entry, while a same-direction
   // position means hold. Any owned position that remains blocks entry.
   if(Strategy_HasOwnedPosition())
      return false;

   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_points < 0 || spread_points > strategy_max_spread_points)
      return false;

   req.type = (g_cached_direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0 || !MathIsValidNumber(entry_price))
      return false;

   req.sl = QM_StopATRFromValue(_Symbol,
                                req.type,
                                entry_price,
                                g_cached_atr,
                                strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0 || !MathIsValidNumber(req.sl))
      return false;
   if(req.type == QM_BUY && req.sl >= entry_price)
      return false;
   if(req.type == QM_SELL && req.sl <= entry_price)
      return false;

   req.tp = 0.0;
   req.reason = (g_cached_direction > 0)
                ? "XAU_WEEKLY_TSMOM_LONG"
                : "XAU_WEEKLY_TSMOM_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const string position_symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      const int completed_bars =
         (opened > 0) ? iBarShift(_Symbol, PERIOD_D1, opened, false) : -1;

      bool should_close = false;
      if(position_symbol != "XAUUSD.DWX")
         should_close = true;
      if(position_type != POSITION_TYPE_BUY &&
         position_type != POSITION_TYPE_SELL)
         should_close = true;
      if(opened <= 0 || completed_bars < 0)
         should_close = true;
      if(completed_bars >= strategy_max_hold_bars)
         should_close = true;

      // Signal-flip exit: if re-evaluation produces opposite direction, close held position
      if(g_weekly_evaluation_bar && g_cached_signal_valid)
        {
         if(position_type == POSITION_TYPE_BUY && g_cached_direction == -1)
            should_close = true;
         else if(position_type == POSITION_TYPE_SELL && g_cached_direction == 1)
            should_close = true;
        }

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
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

   g_attempt_state_key =
      StringFormat("QM5_21502_WEEK_ATTEMPT_%d", QM_FrameworkMagic());
   if((bool)MQLInfoInteger(MQL_TESTER))
     {
      if(GlobalVariableCheck(g_attempt_state_key))
         GlobalVariableDel(g_attempt_state_key);
      g_last_attempt_week_key = 0;
     }
   else
      Strategy_LoadAttemptState();

   Strategy_ResetCachedSignal();
   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_21502\",\"ea\":\"xau-weekly-tsmom\",\"signal\":\"weekly_return_sign_tsmom\"}");
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

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   g_weekly_evaluation_bar = false;
   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
   Strategy_PrepareWeeklySignal();

   // Re-run management against the freshly prepared weekly state. On a
   // signal flip this closes the owned opposite side before entry. If the
   // close fails or remains unsettled, Strategy_EntrySignal's all-owned
   // guard blocks the replacement order instead of hedging or flattening.
   Strategy_ManageOpenPosition();

   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol,
                                        broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol,
                                       broker_now,
                                       qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!g_weekly_evaluation_bar || !g_cached_signal_valid)
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
