#property strict
#property version   "5.0"
#property description "QM5_21521 WTI weekly flow-regime switch"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_21521 - WTI Weekly Flow-Regime Switch
// -----------------------------------------------------------------------------
// Structural D1 crude-oil sleeve:
//   - evaluate once when the framework broker-week bucket changes
//   - rank the latest five completed bars' tick-volume sum against 40 prior,
//     non-overlapping five-bar windows
//   - follow the five-bar return in the low-volume tail
//   - fade the five-bar return in the high-volume tail
//   - consume the middle half flat and persist the attempt before fallible gates
// Runtime uses native MT5 WTI D1 bars only; no external signal feed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 21521;
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
input int    strategy_vol_lookback        = 40;
input double strategy_low_rank_cap        = 25.0;
input double strategy_high_rank_floor     = 75.0;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 2.75;
input int    strategy_max_hold_bars       = 5;
input int    strategy_max_spread_points   = 400;

#define STRATEGY_WEEK_BARS 5
#define STRATEGY_REGIME_LOW  -1
#define STRATEGY_REGIME_HIGH  1

int    g_last_attempt_week_key = 0;
string g_attempt_state_key      = "";
bool   g_weekly_evaluation_bar  = false;
bool   g_cached_signal_valid    = false;
int    g_cached_direction       = 0;
int    g_cached_volume_regime   = 0;
int    g_cached_week_key        = 0;
double g_cached_week_return     = 0.0;
double g_cached_current_volume  = 0.0;
double g_cached_volume_rank     = 0.0;
double g_cached_atr             = 0.0;
string g_cached_state_reason    = "not_evaluated";

void Strategy_ResetCachedSignal()
  {
   g_cached_signal_valid = false;
   g_cached_direction = 0;
   g_cached_volume_regime = 0;
   g_cached_week_key = 0;
   g_cached_week_return = 0.0;
   g_cached_current_volume = 0.0;
   g_cached_volume_rank = 0.0;
   g_cached_atr = 0.0;
   g_cached_state_reason = "not_evaluated";
  }

bool Strategy_IsExpectedHost()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
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

bool Strategy_CopyClosedD1Bars(MqlRates &rates[], const int bars_needed)
  {
   if(bars_needed < (STRATEGY_WEEK_BARS * 2))
      return false;

   ArrayResize(rates, bars_needed);
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, bars_needed, rates); // perf-allowed: one bounded completed-D1 price/tick-volume vector on the weekly transition path.
   if(copied != bars_needed)
      return false;

   for(int i = 0; i < bars_needed; ++i)
     {
      if(rates[i].time <= 0 ||
         rates[i].close <= 0.0 ||
         !MathIsValidNumber(rates[i].close) ||
         rates[i].tick_volume <= 0)
         return false;
      if(i > 0 && rates[i].time >= rates[i - 1].time)
         return false;
     }
   return true;
  }

bool Strategy_TickVolumeSum(const MqlRates &rates[],
                            const int start_index,
                            const int count,
                            double &volume_sum)
  {
   volume_sum = 0.0;
   if(start_index < 0 || count <= 0 ||
      start_index + count > ArraySize(rates))
      return false;

   for(int i = start_index; i < start_index + count; ++i)
     {
      if(rates[i].tick_volume <= 0)
         return false;
      volume_sum += (double)rates[i].tick_volume;
      if(!MathIsValidNumber(volume_sum))
         return false;
     }
   return (volume_sum > 0.0);
  }

bool Strategy_LoadWeeklyState(int &direction,
                              int &volume_regime,
                              double &week_return,
                              double &current_volume,
                              double &volume_rank,
                              double &atr_last)
  {
   direction = 0;
   volume_regime = 0;
   week_return = 0.0;
   current_volume = 0.0;
   volume_rank = 0.0;
   atr_last = 0.0;

   const int bars_needed = strategy_vol_lookback * STRATEGY_WEEK_BARS +
                           STRATEGY_WEEK_BARS;
   MqlRates rates[];
   if(!Strategy_CopyClosedD1Bars(rates, bars_needed))
     {
      g_cached_state_reason = "history_invalid";
      return false;
     }

   const double latest_close = rates[0].close;
   const double formation_close = rates[STRATEGY_WEEK_BARS].close;
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
   int return_sign = 0;
   if(week_return > 0.0)
      return_sign = 1;
   else if(week_return < 0.0)
      return_sign = -1;
   else
     {
      g_cached_state_reason = "zero_return";
      return false;
     }

   if(!Strategy_TickVolumeSum(rates, 0, STRATEGY_WEEK_BARS, current_volume))
     {
      g_cached_state_reason = "current_volume_invalid";
      return false;
     }

   int less_or_equal = 0;
   for(int window = 0; window < strategy_vol_lookback; ++window)
     {
      const int start_index = STRATEGY_WEEK_BARS +
                              window * STRATEGY_WEEK_BARS;
      double baseline_volume = 0.0;
      if(!Strategy_TickVolumeSum(rates,
                                 start_index,
                                 STRATEGY_WEEK_BARS,
                                 baseline_volume))
        {
         g_cached_state_reason = "baseline_volume_invalid";
         return false;
        }
      if(baseline_volume <= current_volume)
         ++less_or_equal;
     }

   volume_rank = 100.0 * (double)less_or_equal /
                 (double)strategy_vol_lookback;
   if(!MathIsValidNumber(volume_rank))
     {
      g_cached_state_reason = "volume_rank_invalid";
      return false;
     }

   if(volume_rank <= strategy_low_rank_cap)
     {
      volume_regime = STRATEGY_REGIME_LOW;
      direction = return_sign;
      g_cached_state_reason = "low_volume_momentum_ready";
     }
   else if(volume_rank >= strategy_high_rank_floor)
     {
      volume_regime = STRATEGY_REGIME_HIGH;
      direction = -return_sign;
      g_cached_state_reason = "high_volume_reversal_ready";
     }
   else
     {
      g_cached_state_reason = "middle_volume_flat";
      return false;
     }

   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_last <= 0.0 || !MathIsValidNumber(atr_last))
     {
      direction = 0;
      volume_regime = 0;
      g_cached_state_reason = "atr_invalid";
      return false;
     }

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

   // Persist before history, signal, news, spread, quote, sizing, and order
   // gates. A failed gate or stop cannot create a same-week retry.
   if(!Strategy_RecordWeekAttempt(current_week_key))
     {
      g_cached_state_reason = "attempt_persist_failed";
      return;
     }

   g_weekly_evaluation_bar = true;
   g_cached_week_key = current_week_key;
   if(Strategy_HasOwnedPosition())
     {
      g_cached_state_reason = "position_already_open";
      return;
     }

   g_cached_signal_valid =
      Strategy_LoadWeeklyState(g_cached_direction,
                               g_cached_volume_regime,
                               g_cached_week_return,
                               g_cached_current_volume,
                               g_cached_volume_rank,
                               g_cached_atr);

   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"week_key\":%d,\"valid\":%s,\"direction\":%d,\"volume_regime\":%d,\"return\":%.10f,\"tick_volume\":%.0f,\"volume_rank\":%.2f,\"reason\":\"%s\"}",
                            g_cached_week_key,
                            g_cached_signal_valid ? "true" : "false",
                            g_cached_direction,
                            g_cached_volume_regime,
                            g_cached_week_return,
                            g_cached_current_volume,
                            g_cached_volume_rank,
                            g_cached_state_reason));
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsExpectedHost())
      return true;
   if(qm_ea_id != 21521 || qm_magic_slot_offset != 0)
      return true;
   if(strategy_vol_lookback < 4 || strategy_vol_lookback > 260)
      return true;
   if(strategy_low_rank_cap <= 0.0 || strategy_low_rank_cap >= 50.0)
      return true;
   if(strategy_high_rank_floor <= 50.0 || strategy_high_rank_floor >= 100.0)
      return true;
   if(strategy_low_rank_cap >= strategy_high_rank_floor)
      return true;
   if(strategy_atr_period <= 1 || strategy_atr_period > 100)
      return true;
   if(strategy_atr_sl_mult <= 0.0 || strategy_atr_sl_mult > 20.0)
      return true;
   if(strategy_max_hold_bars <= 0 || strategy_max_hold_bars > 30)
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
   req.reason = "QM5_21521_WTI_FLOW_SWITCH";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_weekly_evaluation_bar ||
      !g_cached_signal_valid ||
      g_cached_week_key != g_last_attempt_week_key ||
      (g_cached_direction != 1 && g_cached_direction != -1) ||
      (g_cached_volume_regime != STRATEGY_REGIME_LOW &&
       g_cached_volume_regime != STRATEGY_REGIME_HIGH))
      return false;
   if(Strategy_HasOwnedPosition())
      return false;

   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   // DWX tester history may report a degenerate zero spread; block only an
   // invalid negative value or a genuinely wide live/test spread.
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
   if(g_cached_volume_regime == STRATEGY_REGIME_LOW)
      req.reason = (g_cached_direction > 0)
                   ? "WTI_LOW_TICKVOL_WEEK_MOM_LONG"
                   : "WTI_LOW_TICKVOL_WEEK_MOM_SHORT";
   else
      req.reason = (g_cached_direction > 0)
                   ? "WTI_HIGH_TICKVOL_WEEK_REV_LONG"
                   : "WTI_HIGH_TICKVOL_WEEK_REV_SHORT";
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
      if(position_symbol != "XTIUSD.DWX")
         should_close = true;
      if(position_type != POSITION_TYPE_BUY &&
         position_type != POSITION_TYPE_SELL)
         should_close = true;
      if(opened <= 0 || completed_bars < 0)
         should_close = true;
      if(completed_bars >= strategy_max_hold_bars)
         should_close = true;

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
      StringFormat("QM5_21521_WEEK_ATTEMPT_%d", QM_FrameworkMagic());
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
               "{\"card\":\"QM5_21521\",\"ea\":\"wti-flow-switch\",\"signal\":\"weekly_two_tail_tick_volume_direction_switch\"}");
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
   if(!g_weekly_evaluation_bar || !g_cached_signal_valid)
      return;

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
