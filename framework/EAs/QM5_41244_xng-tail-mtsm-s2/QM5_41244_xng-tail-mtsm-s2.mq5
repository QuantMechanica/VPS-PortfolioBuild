#property strict
#property version   "5.0"
#property description "QM5_41244 XNG tail-managed time-series momentum S2"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_41244 - XNG Tail-Managed Time-Series Momentum S2
// -----------------------------------------------------------------------------
// Structural D1 natural-gas carrier port of Liu, Lu, and Wang (2021):
//   - base direction = sign of the latest 30 completed simple D1 returns
//   - tail state = five-return upper and lower partial moments
//   - references = separate nearest-rank 80th percentiles from 252 older
//     partial-moment observations, excluding the current observation
//   - S2 map = both tails flat; LPM-only long; UPM-only short; otherwise
//     follow base momentum (zero momentum maps short)
//   - one durable attempt per nonzero flat-position D1 decision
//   - no same-label reversal after an opposed-position close
// Native MT5 OHLC, ATR, quote, position, history, and terminal state only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 41244;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode       qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
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
input int    strategy_momentum_days        = 30;
input int    strategy_partial_moment_days  = 5;
input int    strategy_percentile_history   = 252;
input double strategy_tail_percentile      = 80.0;
input int    strategy_atr_period            = 20;
input double strategy_atr_sl_mult           = 3.0;
input int    strategy_max_hold_days         = 8;
input int    strategy_max_spread_points     = 1500;

const string g_symbol = "XNGUSD.DWX";

bool     g_strategy_new_d1_bar         = false;
bool     g_state_valid                 = false;
bool     g_entry_attempt_ready         = false;
bool     g_transition_closed_this_label = false;
int      g_target_state                = 0; // +1 long, -1 short, 0 flat.
datetime g_state_bar_time              = 0;
datetime g_last_attempt_bar_time       = 0;
double   g_momentum_return             = 0.0;
double   g_current_upm                 = 0.0;
double   g_current_lpm                 = 0.0;
double   g_up_reference                = 0.0;
double   g_low_reference               = 0.0;
string   g_attempt_state_key           = "";

// -----------------------------------------------------------------------------
// Host, parameter, and persistent-decision guards.
// -----------------------------------------------------------------------------

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_symbol && _Period == PERIOD_D1);
  }

bool Strategy_InputsValid()
  {
   return (qm_ea_id == 41244 &&
           qm_magic_slot_offset == 0 &&
           qm_rng_seed == 42 &&
           MathAbs(RISK_PERCENT) <= 1.0e-12 &&
           MathAbs(RISK_FIXED - 1000.0) <= 1.0e-12 &&
           MathAbs(PORTFOLIO_WEIGHT - 1.0) <= 1.0e-12 &&
           qm_news_temporal == QM_NEWS_TEMPORAL_PRE30_POST30 &&
           qm_news_compliance == QM_NEWS_COMPLIANCE_DXZ &&
           qm_news_stale_max_hours == 336 &&
           qm_news_min_impact == "high" &&
           qm_news_mode_legacy == QM_NEWS_OFF &&
           qm_friday_close_enabled &&
           qm_friday_close_hour_broker == 21 &&
           MathAbs(qm_stress_reject_probability) <= 1.0e-12 &&
           strategy_momentum_days == 30 &&
           strategy_partial_moment_days == 5 &&
           strategy_percentile_history == 252 &&
           MathAbs(strategy_tail_percentile - 80.0) <= 1.0e-12 &&
           strategy_atr_period == 20 &&
           MathAbs(strategy_atr_sl_mult - 3.0) <= 1.0e-12 &&
           strategy_max_hold_days == 8 &&
           strategy_max_spread_points == 1500);
  }

void Strategy_LoadAttemptState(const datetime reference_time)
  {
   g_last_attempt_bar_time = 0;
   if(reference_time <= 0 || g_attempt_state_key == "" ||
      !GlobalVariableCheck(g_attempt_state_key))
      return;

   const double stored = GlobalVariableGet(g_attempt_state_key);
   const datetime stored_bar_time = (datetime)MathRound(stored);
   if(MathIsValidNumber(stored) && stored_bar_time > 0 &&
      stored_bar_time <= reference_time)
     {
      g_last_attempt_bar_time = stored_bar_time;
      return;
     }

   // Tester globals can outlive a later historical replay. A malformed or
   // future marker must not suppress the beginning of that deterministic run.
   GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordAttemptState(const datetime bar_time)
  {
   if(bar_time <= 0 || g_attempt_state_key == "")
      return false;

   // Fail closed in-process even if terminal persistence is unavailable.
   g_last_attempt_bar_time = bar_time;
   return (GlobalVariableSet(g_attempt_state_key, (double)bar_time) > 0);
  }

// -----------------------------------------------------------------------------
// Exact completed-D1 MTSM-S2 arithmetic.
// -----------------------------------------------------------------------------

bool Strategy_LoadClosedCloses(double &closes[])
  {
   const int momentum_required = strategy_momentum_days + 1;
   const int percentile_required = strategy_percentile_history +
                                   strategy_partial_moment_days + 1;
   const int required = MathMax(momentum_required, percentile_required);
   if(required <= 0 || ArrayResize(closes, required) != required)
      return false;

   ArraySetAsSeries(closes, true);
   const int copied =
      CopyClose(_Symbol,             // perf-allowed: one bounded history copy
                PERIOD_D1,           // on a newly labelled D1 decision only.
                1,
                required,
                closes);
   if(copied != required || ArraySize(closes) != required)
      return false;

   for(int index = 0; index < required; ++index)
     {
      if(closes[index] <= 0.0 || !MathIsValidNumber(closes[index]))
         return false;
     }
   return true;
  }

bool Strategy_PartialMoments(const double &closes[],
                             const int base_shift,
                             double &upm,
                             double &lpm)
  {
   upm = 0.0;
   lpm = 0.0;
   if(base_shift < 0 || strategy_partial_moment_days != 5)
      return false;

   for(int offset = 0; offset < strategy_partial_moment_days; ++offset)
     {
      const int current_index = base_shift + offset;
      const int prior_index = current_index + 1;
      if(current_index < 0 || prior_index >= ArraySize(closes))
         return false;

      const double current_close = closes[current_index];
      const double prior_close = closes[prior_index];
      if(current_close <= 0.0 || prior_close <= 0.0 ||
         !MathIsValidNumber(current_close) ||
         !MathIsValidNumber(prior_close))
         return false;

      const double daily_return = current_close / prior_close - 1.0;
      if(!MathIsValidNumber(daily_return))
         return false;
      const double squared_return = daily_return * daily_return;
      if(!MathIsValidNumber(squared_return))
         return false;
      if(daily_return > 0.0)
         upm += squared_return;
      else if(daily_return < 0.0)
         lpm += squared_return;
     }

   upm /= (double)strategy_partial_moment_days;
   lpm /= (double)strategy_partial_moment_days;
   return (upm >= 0.0 && lpm >= 0.0 &&
           MathIsValidNumber(upm) && MathIsValidNumber(lpm));
  }

bool Strategy_MomentumReturn(const double &closes[],
                             double &momentum_return)
  {
   momentum_return = 0.0;
   for(int offset = 0; offset < strategy_momentum_days; ++offset)
     {
      if(offset + 1 >= ArraySize(closes) ||
         closes[offset] <= 0.0 || closes[offset + 1] <= 0.0)
         return false;
      const double daily_return =
         closes[offset] / closes[offset + 1] - 1.0;
      if(!MathIsValidNumber(daily_return))
         return false;
      momentum_return += daily_return;
     }
   return MathIsValidNumber(momentum_return);
  }

double Strategy_NearestRankPercentile(double &values[],
                                      const double percentile)
  {
   const int count = ArraySize(values);
   if(count <= 0 || percentile <= 0.0 || percentile > 100.0)
      return -1.0;

   for(int index = 0; index < count; ++index)
     {
      if(values[index] < 0.0 || !MathIsValidNumber(values[index]))
         return -1.0;
     }
   ArraySort(values);
   int rank = (int)MathCeil(percentile * (double)count / 100.0) - 1;
   rank = MathMax(0, MathMin(count - 1, rank));
   return values[rank];
  }

bool Strategy_CalculateTarget(int &target_state)
  {
   target_state = 0;
   g_momentum_return = 0.0;
   g_current_upm = 0.0;
   g_current_lpm = 0.0;
   g_up_reference = 0.0;
   g_low_reference = 0.0;

   double closes[];
   if(!Strategy_LoadClosedCloses(closes) ||
      !Strategy_MomentumReturn(closes, g_momentum_return) ||
      !Strategy_PartialMoments(closes,
                               0,
                               g_current_upm,
                               g_current_lpm))
      return false;

   double historical_upm[];
   double historical_lpm[];
   if(ArrayResize(historical_upm, strategy_percentile_history) !=
         strategy_percentile_history ||
      ArrayResize(historical_lpm, strategy_percentile_history) !=
         strategy_percentile_history)
      return false;

   // base_shift=1 starts with the immediately older five-return observation.
   // The current observation at base_shift=0 is never in either reference.
   for(int observation = 0;
       observation < strategy_percentile_history;
       ++observation)
     {
      double observation_upm = 0.0;
      double observation_lpm = 0.0;
      if(!Strategy_PartialMoments(closes,
                                  observation + 1,
                                  observation_upm,
                                  observation_lpm))
         return false;
      historical_upm[observation] = observation_upm;
      historical_lpm[observation] = observation_lpm;
     }

   g_up_reference =
      Strategy_NearestRankPercentile(historical_upm,
                                     strategy_tail_percentile);
   g_low_reference =
      Strategy_NearestRankPercentile(historical_lpm,
                                     strategy_tail_percentile);
   if(g_up_reference <= 0.0 || g_low_reference <= 0.0 ||
      !MathIsValidNumber(g_up_reference) ||
      !MathIsValidNumber(g_low_reference))
      return false;

   const bool up_tail = (g_current_upm >= g_up_reference);
   const bool low_tail = (g_current_lpm >= g_low_reference);

   // Exact MTSM-S2 region map. Do not substitute S1 or a direction filter.
   if(up_tail && low_tail)
      target_state = 0;
   else if(!up_tail && low_tail)
      target_state = 1;
   else if(up_tail && !low_tail)
      target_state = -1;
   else
      target_state = (g_momentum_return > 0.0) ? 1 : -1;
   return true;
  }

void Strategy_RefreshState()
  {
   g_entry_attempt_ready = false;
   g_transition_closed_this_label = false;
   g_target_state = 0;
   g_state_valid = false;
   g_state_bar_time =
      iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: one new-D1 label read.
   if(g_state_bar_time > 0)
      g_state_valid = Strategy_CalculateTarget(g_target_state);

   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"bar\":%I64d,\"valid\":%s,\"momentum\":%.12g,\"upm\":%.12g,\"lpm\":%.12g,\"up_ref\":%.12g,\"low_ref\":%.12g,\"target\":%d}",
                            (long)g_state_bar_time,
                            g_state_valid ? "true" : "false",
                            g_momentum_return,
                            g_current_upm,
                            g_current_lpm,
                            g_up_reference,
                            g_low_reference,
                            g_target_state));
  }

// -----------------------------------------------------------------------------
// Exact-magic ownership and lifecycle repair.
// -----------------------------------------------------------------------------

bool Strategy_IsMagicPosition()
  {
   return ((int)PositionGetInteger(POSITION_MAGIC) == QM_FrameworkMagic());
  }

int Strategy_MagicPositionCount()
  {
   int count = 0;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsMagicPosition())
         ++count;
     }
   return count;
  }

void Strategy_CloseAllMagicPositions(const QM_ExitReason reason)
  {
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsMagicPosition())
         continue;
      QM_TM_ClosePosition(ticket, reason);
     }
  }

void Strategy_ManageOwnedPositions()
  {
   const int magic_count = Strategy_MagicPositionCount();
   if(magic_count <= 0)
      return;

   // Any nonzero target evaluated while exposure exists consumes this label.
   // This makes same-side retention and opposed/malformed repair restart-safe:
   // a later stop or successful close cannot become a same-label fresh entry.
   if(g_strategy_new_d1_bar && g_state_valid && g_target_state != 0 &&
      g_state_bar_time > 0 &&
      g_last_attempt_bar_time != g_state_bar_time)
     {
      if(!Strategy_RecordAttemptState(g_state_bar_time))
         QM_LogEvent(QM_ERROR,
                     "ATTEMPT_PERSIST_FAILED",
                     StringFormat("{\"bar\":%I64d,\"context\":\"owned_position\"}",
                                  (long)g_state_bar_time));
     }

   const datetime now = TimeCurrent();
   const long hold_seconds =
      (long)MathMax(1, strategy_max_hold_days) * 86400L;

   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsMagicPosition())
         continue;

      const string symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double stop_price = PositionGetDouble(POSITION_SL);

      int position_state = 0;
      if(position_type == POSITION_TYPE_BUY)
         position_state = 1;
      else if(position_type == POSITION_TYPE_SELL)
         position_state = -1;

      bool should_close =
         (magic_count != 1 || symbol != g_symbol ||
          position_state == 0 || opened <= 0 || opened > now ||
          volume <= 0.0 || !MathIsValidNumber(volume) ||
          open_price <= 0.0 || !MathIsValidNumber(open_price) ||
          stop_price <= 0.0 || !MathIsValidNumber(stop_price));

      if(!should_close && (long)(now - opened) >= hold_seconds)
         should_close = true;

      if(!should_close && g_strategy_new_d1_bar)
        {
         if(!g_state_valid || g_target_state == 0)
            should_close = true;
         else if(position_state != g_target_state)
           {
            should_close = true;
            g_transition_closed_this_label = true;
           }
        }

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

void Strategy_PrepareFlatPositionAttempt()
  {
   g_entry_attempt_ready = false;
   if(!g_strategy_new_d1_bar || !g_state_valid ||
      g_target_state == 0 || g_state_bar_time <= 0 ||
      g_transition_closed_this_label ||
      Strategy_MagicPositionCount() != 0 ||
      g_last_attempt_bar_time == g_state_bar_time)
      return;

   // The valid nonzero flat-position decision is durable before quote,
   // spread, ATR, sizing, news, or submission checks. Never retry this label.
   if(!Strategy_RecordAttemptState(g_state_bar_time))
     {
      QM_LogEvent(QM_ERROR,
                  "ATTEMPT_PERSIST_FAILED",
                  StringFormat("{\"bar\":%I64d,\"context\":\"flat_target\"}",
                               (long)g_state_bar_time));
      return;
     }
   g_entry_attempt_ready = true;
  }

// -----------------------------------------------------------------------------
// Five V5 strategy hooks.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return (!Strategy_IsHostChart() || !Strategy_InputsValid());
  }

bool Strategy_EntrySignal(QM_EntryRequest &request)
  {
   ZeroMemory(request);
   request.type = (g_target_state > 0) ? QM_BUY : QM_SELL;
   request.price = 0.0;
   request.sl = 0.0;
   request.tp = 0.0;
   request.reason = (g_target_state > 0)
                    ? "XNG_TAIL_MTSM_S2_LONG"
                    : "XNG_TAIL_MTSM_S2_SHORT";
   request.symbol_slot = qm_magic_slot_offset;
   request.expiration_seconds = 0;

   if(!g_strategy_new_d1_bar || !g_entry_attempt_ready ||
      !g_state_valid || g_state_bar_time <= 0 ||
      g_state_bar_time != g_last_attempt_bar_time ||
      (g_target_state != 1 && g_target_state != -1) ||
      g_transition_closed_this_label ||
      Strategy_MagicPositionCount() != 0)
      return false;

   MqlTick tick;
   ZeroMemory(tick);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(!SymbolInfoTick(_Symbol, tick) ||
      tick.bid <= 0.0 || tick.ask <= 0.0 || point <= 0.0 ||
      !MathIsValidNumber(tick.bid) || !MathIsValidNumber(tick.ask) ||
      !MathIsValidNumber(point) || tick.ask < tick.bid)
      return false;

   const double spread_points = (tick.ask - tick.bid) / point;
   if(!MathIsValidNumber(spread_points) || spread_points < 0.0 ||
      spread_points > (double)strategy_max_spread_points)
      return false;

   const double atr_last =
      QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_last <= 0.0 || !MathIsValidNumber(atr_last))
      return false;

   const double entry_price =
      (request.type == QM_BUY) ? tick.ask : tick.bid;
   request.sl = QM_StopATRFromValue(_Symbol,
                                    request.type,
                                    entry_price,
                                    atr_last,
                                    strategy_atr_sl_mult);
   request.sl = QM_StopRulesNormalizePrice(_Symbol, request.sl);
   if(request.sl <= 0.0 || !MathIsValidNumber(request.sl))
      return false;
   if(request.type == QM_BUY && request.sl >= entry_price)
      return false;
   if(request.type == QM_SELL && request.sl <= entry_price)
      return false;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_ManageOwnedPositions();
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Canonical V5 lifecycle.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!SymbolSelect(g_symbol, true) ||
      !Strategy_IsHostChart() || !Strategy_InputsValid())
      return INIT_PARAMETERS_INCORRECT;

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
         QM_FRIDAY_CLOSE_CARD_RULE,
         "Approved XNG Tail-MTSM S2 card uses completed D1 state and Friday close at broker hour 21"))
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

   g_attempt_state_key =
      StringFormat("QM5_41244_XNG_TAIL_MTSM_S2_D1_ATTEMPT_%d",
                   QM_FrameworkMagic());
   const datetime current_bar =
      iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: one initialization label.
   const datetime state_reference =
      (current_bar > 0) ? current_bar : TimeCurrent();
   Strategy_LoadAttemptState(state_reference);

   string warmup_symbols[1];
   warmup_symbols[0] = g_symbol;
   QM_SymbolGuardInit(warmup_symbols);
   QM_BasketWarmupHistory(warmup_symbols, PERIOD_D1, 300);

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_41244\",\"ea\":\"xng-tail-mtsm-s2\"}");
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
   if(QM_FrameworkHandleFridayClose())
      return;
   if(!Strategy_IsHostChart())
      return;

   g_strategy_new_d1_bar = QM_IsNewBar(_Symbol, PERIOD_D1);
   if(g_strategy_new_d1_bar)
     {
      QM_EquityStreamOnNewBar();
      Strategy_RefreshState();
     }

   // Malformed/stale repair runs every tick; state transitions run only on a
   // new D1 decision and therefore cannot use an unrefreshed target.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      Strategy_CloseAllMagicPositions(QM_EXIT_STRATEGY);
      return;
     }

   if(!g_strategy_new_d1_bar || Strategy_NoTradeFilter())
      return;

   Strategy_PrepareFlatPositionAttempt();

   QM_EntryRequest request;
   ZeroMemory(request);
   if(!Strategy_EntrySignal(request))
      return;

   const datetime broker_now = TimeCurrent();
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

   ulong out_ticket = 0;
   QM_TM_OpenPosition(request, out_ticket);
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
