#property strict
#property version   "5.0"
#property description "QM5_41283 AUDUSD dollar-stress trend continuation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Card: strategy-seeds/cards/approved/QM5_41283_audusd-dollar-stress-tr_card.md
// Source: AI-CODEX-AUDUSD-DOLLAR-STRESS-TREND-20260902
// =============================================================================

#define STRATEGY_EA_ID              41283
#define STRATEGY_SYMBOL             "AUDUSD.DWX"
#define STRATEGY_EURUSD             "EURUSD.DWX"
#define STRATEGY_GBPUSD             "GBPUSD.DWX"
#define STRATEGY_SP500              "SP500.DWX"
#define STRATEGY_AUD_BARS           21
#define STRATEGY_RETURN_BARS        6
#define STRATEGY_SP_BARS            51
#define STRATEGY_WARMUP_BARS        64

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = STRATEGY_EA_ID;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_OFF;
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
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_D1;
input int    strategy_sp_sma_days         = 50;
input int    strategy_sp_return_days      = 20;
input int    strategy_usd_return_days     = 5;
input double strategy_usd_threshold       = -0.010;
input int    strategy_breakout_days       = 20;
input int    strategy_atr_period          = 14;
input double strategy_stop_atr            = 2.0;
input double strategy_trail_atr           = 2.0;
input int    strategy_max_hold_bars       = 10;
input int    strategy_max_spread_points   = 50;
input int    strategy_deviation_points    = 20;

string g_dependency_symbols[4] =
  {
   STRATEGY_SYMBOL,
   STRATEGY_EURUSD,
   STRATEGY_GBPUSD,
   STRATEGY_SP500
  };

bool     g_strategy_state_ready = false;
bool     g_strategy_entry_ready = false;
bool     g_strategy_composite_gate = false;
bool     g_strategy_closed_bar_advanced = false;
bool     g_strategy_closed_this_tick = false;
bool     g_strategy_attempt_fresh = false;
bool     g_strategy_history_clear = false;
double   g_strategy_signal_atr = 0.0;
double   g_strategy_signal_close = 0.0;
double   g_strategy_prior_low = 0.0;
double   g_strategy_sp_mean = 0.0;
double   g_strategy_sp_return = 0.0;
double   g_strategy_eurusd_return = 0.0;
double   g_strategy_gbpusd_return = 0.0;
double   g_strategy_audusd_return = 0.0;
double   g_strategy_usd_mean = 0.0;
datetime g_strategy_signal_time = 0;
int      g_strategy_decision_day_key = 0;
int      g_strategy_attempt_day_key = 0;
string   g_strategy_attempt_state_key = "";

bool Strategy_DoubleEquals(const double lhs, const double rhs)
  {
   return (MathAbs(lhs - rhs) <= 1e-10);
  }

bool Strategy_ParametersValid()
  {
   return (qm_ea_id == STRATEGY_EA_ID &&
           qm_magic_slot_offset == 0 &&
           strategy_signal_tf == PERIOD_D1 &&
           strategy_sp_sma_days == 50 &&
           strategy_sp_return_days == 20 &&
           strategy_usd_return_days == 5 &&
           Strategy_DoubleEquals(strategy_usd_threshold, -0.010) &&
           strategy_breakout_days == 20 &&
           strategy_atr_period == 14 &&
           Strategy_DoubleEquals(strategy_stop_atr, 2.0) &&
           Strategy_DoubleEquals(strategy_trail_atr, 2.0) &&
           strategy_max_hold_bars == 10 &&
           strategy_max_spread_points == 50 &&
           strategy_deviation_points == 20 &&
           Strategy_DoubleEquals(RISK_PERCENT, 0.0) &&
           Strategy_DoubleEquals(RISK_FIXED, 1000.0) &&
           Strategy_DoubleEquals(PORTFOLIO_WEIGHT, 1.0) &&
           qm_news_temporal == QM_NEWS_TEMPORAL_OFF &&
           qm_news_compliance == QM_NEWS_COMPLIANCE_NONE &&
           qm_news_mode_legacy == QM_NEWS_OFF &&
           qm_news_stale_max_hours == 336 &&
           qm_news_min_impact == "high" &&
           !qm_friday_close_enabled &&
           qm_friday_close_hour_broker == 21 &&
           qm_stress_reject_probability >= 0.0 &&
           qm_stress_reject_probability <= 1.0);
  }

int Strategy_DateKey(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime parts;
   TimeToStruct(value, parts);
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

string Strategy_AttemptStateKey()
  {
   return StringFormat("QM5_%d_D1_ATTEMPT_%d",
                       qm_ea_id,
                       QM_FrameworkMagic());
  }

void Strategy_LoadAttemptState()
  {
   g_strategy_attempt_state_key = Strategy_AttemptStateKey();
   g_strategy_attempt_day_key = 0;
   if(g_strategy_attempt_state_key == "" ||
      !GlobalVariableCheck(g_strategy_attempt_state_key))
      return;

   const double stored = GlobalVariableGet(g_strategy_attempt_state_key);
   if(MathIsValidNumber(stored) && stored > 0.0)
      g_strategy_attempt_day_key = (int)stored;
  }

bool Strategy_ConsumeDecisionDay(const int decision_day_key)
  {
   if(decision_day_key <= 0 || g_strategy_attempt_state_key == "")
      return false;

   // Tester restarts can expose a terminal-global marker from a later run.
   // Delete only that impossible future marker; ordinary restart persistence
   // is retained so a failed order path cannot retry within the same D1 day.
   if(g_strategy_attempt_day_key > decision_day_key)
     {
      if(GlobalVariableCheck(g_strategy_attempt_state_key))
         GlobalVariableDel(g_strategy_attempt_state_key);
      g_strategy_attempt_day_key = 0;
     }

   if(g_strategy_attempt_day_key == decision_day_key)
      return false;

   if(GlobalVariableSet(g_strategy_attempt_state_key,
                        (double)decision_day_key) == 0)
      return false;
   GlobalVariablesFlush();
   g_strategy_attempt_day_key = decision_day_key;
   return true;
  }

bool Strategy_HistoryEntryOnDecisionDay(const int decision_day_key,
                                        bool &history_ok)
  {
   history_ok = false;
   const datetime now = TimeCurrent();
   if(decision_day_key <= 0 || now <= 0)
      return false;

   const datetime from_time = now - 3 * 86400;
   if(!HistorySelect(from_time, now))
      return false;
   history_ok = true;

   const int magic = QM_FrameworkMagic();
   const int total = HistoryDealsTotal();
   for(int index = total - 1; index >= 0; --index)
     {
      const ulong deal_ticket = HistoryDealGetTicket(index);
      if(deal_ticket == 0)
        {
         history_ok = false;
         return false;
        }
      if((int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != STRATEGY_SYMBOL)
         continue;

      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;

      const datetime deal_time =
         (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      if(Strategy_DateKey(deal_time) == decision_day_key)
         return true;
     }
   return false;
  }

bool Strategy_RatesValid(const MqlRates &rates[],
                         const int expected_count,
                         const bool require_low)
  {
   const int size = ArraySize(rates);
   if(size != expected_count || size <= 0)
      return false;

   datetime previous_time = 0;
   for(int index = 0; index < size; ++index)
     {
      if(index < 0 || index >= ArraySize(rates))
         return false;
      if(rates[index].time <= previous_time ||
         !MathIsValidNumber(rates[index].close) ||
         rates[index].close <= 0.0)
         return false;
      if(require_low &&
         (!MathIsValidNumber(rates[index].low) || rates[index].low <= 0.0))
         return false;
      previous_time = rates[index].time;
     }
   return true;
  }

bool Strategy_LoadFiveDayReturn(const string symbol,
                                const datetime signal_time,
                                double &return_value)
  {
   return_value = 0.0;
   if(!QM_SymbolAssertOrLog(symbol))
      return false;

   MqlRates rates[STRATEGY_RETURN_BARS];
   const int capacity = ArraySize(rates);
   const int copied = CopyRates(symbol,
                                strategy_signal_tf,
                                1,
                                STRATEGY_RETURN_BARS,
                                rates); // perf-allowed: one bounded synchronized five-session return read behind the sole D1 new-bar gate.
   if(copied != capacity ||
      !Strategy_RatesValid(rates, STRATEGY_RETURN_BARS, false))
      return false;

   const int latest = capacity - 1;
   const int older = latest - strategy_usd_return_days;
   if(latest < 0 || latest >= ArraySize(rates) ||
      older < 0 || older >= ArraySize(rates) ||
      rates[latest].time != signal_time)
      return false;

   return_value = rates[latest].close / rates[older].close - 1.0;
   return MathIsValidNumber(return_value);
  }

bool Strategy_LoadSp500State(const datetime signal_time,
                             double &completed_close,
                             double &mean50,
                             double &return20)
  {
   completed_close = 0.0;
   mean50 = 0.0;
   return20 = 0.0;
   if(!QM_SymbolAssertOrLog(STRATEGY_SP500))
      return false;

   MqlRates rates[STRATEGY_SP_BARS];
   const int capacity = ArraySize(rates);
   const int copied = CopyRates(STRATEGY_SP500,
                                strategy_signal_tf,
                                1,
                                STRATEGY_SP_BARS,
                                rates); // perf-allowed: one bounded synchronized SP500 D1 stress read behind the sole D1 new-bar gate.
   if(copied != capacity ||
      !Strategy_RatesValid(rates, STRATEGY_SP_BARS, false))
      return false;

   const int latest = capacity - 1;
   if(latest < 0 || latest >= ArraySize(rates) ||
      latest != strategy_sp_sma_days ||
      rates[latest].time != signal_time)
      return false;

   double sum = 0.0;
   for(int index = 0; index < latest; ++index)
     {
      if(index < 0 || index >= ArraySize(rates))
         return false;
      sum += rates[index].close;
     }
   mean50 = sum / (double)strategy_sp_sma_days;

   const int return_index = latest - strategy_sp_return_days;
   if(return_index < 0 || return_index >= ArraySize(rates))
      return false;
   completed_close = rates[latest].close;
   return20 = completed_close / rates[return_index].close - 1.0;
   return (MathIsValidNumber(completed_close) && completed_close > 0.0 &&
           MathIsValidNumber(mean50) && mean50 > 0.0 &&
           MathIsValidNumber(return20));
  }

void Strategy_ResetClosedBarState()
  {
   g_strategy_state_ready = false;
   g_strategy_entry_ready = false;
   g_strategy_composite_gate = false;
   g_strategy_attempt_fresh = false;
   g_strategy_history_clear = false;
   g_strategy_signal_atr = 0.0;
   g_strategy_signal_close = 0.0;
   g_strategy_prior_low = 0.0;
   g_strategy_sp_mean = 0.0;
   g_strategy_sp_return = 0.0;
   g_strategy_eurusd_return = 0.0;
   g_strategy_gbpusd_return = 0.0;
   g_strategy_audusd_return = 0.0;
   g_strategy_usd_mean = 0.0;
   g_strategy_signal_time = 0;
   g_strategy_decision_day_key = 0;
  }

// One bounded advance computes every entry, exit, and trail input. CopyRates
// writes the oldest requested bar at physical index zero, so the newest
// completed AUDUSD bar is index 20 and its prior twenty lows are indices 0..19.
bool Strategy_AdvanceClosedBarState()
  {
   Strategy_ResetClosedBarState();

   const int decision_day_key =
      QM_CalendarPeriodKey(PERIOD_D1, STRATEGY_SYMBOL, 0);
   g_strategy_decision_day_key = decision_day_key;
   g_strategy_attempt_fresh = Strategy_ConsumeDecisionDay(decision_day_key);
   if(decision_day_key <= 0)
      return false;

   MqlRates audusd_rates[STRATEGY_AUD_BARS];
   const int aud_capacity = ArraySize(audusd_rates);
   const int aud_copied = CopyRates(STRATEGY_SYMBOL,
                                    strategy_signal_tf,
                                    1,
                                    STRATEGY_AUD_BARS,
                                    audusd_rates); // perf-allowed: one bounded AUDUSD channel/return read behind the sole D1 new-bar gate.
   if(aud_copied != aud_capacity ||
      !Strategy_RatesValid(audusd_rates, STRATEGY_AUD_BARS, true))
      return false;

   const int signal_index = aud_capacity - 1;
   const int return_index = signal_index - strategy_usd_return_days;
   if(signal_index < 0 || signal_index >= ArraySize(audusd_rates) ||
      return_index < 0 || return_index >= ArraySize(audusd_rates))
      return false;

   const MqlRates signal_bar = audusd_rates[signal_index];
   double prior_low = DBL_MAX;
   for(int index = 0; index < signal_index; ++index)
     {
      if(index < 0 || index >= ArraySize(audusd_rates))
         return false;
      prior_low = MathMin(prior_low, audusd_rates[index].low);
     }
   if(signal_index != strategy_breakout_days ||
      !MathIsValidNumber(prior_low) || prior_low <= 0.0)
      return false;

   const double audusd_return =
      signal_bar.close / audusd_rates[return_index].close - 1.0;
   double eurusd_return = 0.0;
   double gbpusd_return = 0.0;
   double sp500_close = 0.0;
   double sp500_mean = 0.0;
   double sp500_return = 0.0;
   if(!MathIsValidNumber(audusd_return) ||
      !Strategy_LoadFiveDayReturn(STRATEGY_EURUSD,
                                  signal_bar.time,
                                  eurusd_return) ||
      !Strategy_LoadFiveDayReturn(STRATEGY_GBPUSD,
                                  signal_bar.time,
                                  gbpusd_return) ||
      !Strategy_LoadSp500State(signal_bar.time,
                               sp500_close,
                               sp500_mean,
                               sp500_return))
      return false;

   const double signal_atr = QM_ATR(STRATEGY_SYMBOL,
                                    strategy_signal_tf,
                                    strategy_atr_period,
                                    1);
   const double usd_mean =
      (eurusd_return + gbpusd_return + audusd_return) / 3.0;
   if(!MathIsValidNumber(signal_atr) || signal_atr <= 0.0 ||
      !MathIsValidNumber(usd_mean))
      return false;

   bool history_ok = false;
   const bool entry_deal_today =
      Strategy_HistoryEntryOnDecisionDay(decision_day_key, history_ok);

   const bool sp_below = (sp500_close < sp500_mean);
   const bool sp_weak = (sp500_return < 0.0);
   const bool usd_broad = (usd_mean <= strategy_usd_threshold);
   const bool breakout = (signal_bar.close < prior_low);

   g_strategy_signal_atr = signal_atr;
   g_strategy_signal_close = signal_bar.close;
   g_strategy_prior_low = prior_low;
   g_strategy_sp_mean = sp500_mean;
   g_strategy_sp_return = sp500_return;
   g_strategy_eurusd_return = eurusd_return;
   g_strategy_gbpusd_return = gbpusd_return;
   g_strategy_audusd_return = audusd_return;
   g_strategy_usd_mean = usd_mean;
   g_strategy_signal_time = signal_bar.time;
   g_strategy_history_clear = (history_ok && !entry_deal_today);
   g_strategy_composite_gate = (sp_below && sp_weak && usd_broad);
   g_strategy_entry_ready = (g_strategy_attempt_fresh &&
                             g_strategy_history_clear &&
                             g_strategy_composite_gate &&
                             breakout);
   g_strategy_state_ready = true;

   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"decision_day_key\":%d,\"signal_time\":%I64d,\"sp_close\":%.8f,\"sp_mean50\":%.8f,\"sp_ret20\":%.12e,\"eurusd_ret5\":%.12e,\"gbpusd_ret5\":%.12e,\"audusd_ret5\":%.12e,\"usd_mean5\":%.12e,\"usd_threshold\":%.12e,\"aud_close\":%.8f,\"prior_low20\":%.8f,\"atr14\":%.8f,\"sp_below\":%s,\"sp_weak\":%s,\"usd_broad\":%s,\"breakout\":%s,\"attempt_fresh\":%s,\"history_clear\":%s,\"entry_ready\":%s}",
                            decision_day_key,
                            (long)signal_bar.time,
                            sp500_close,
                            sp500_mean,
                            sp500_return,
                            eurusd_return,
                            gbpusd_return,
                            audusd_return,
                            usd_mean,
                            strategy_usd_threshold,
                            signal_bar.close,
                            prior_low,
                            signal_atr,
                            sp_below ? "true" : "false",
                            sp_weak ? "true" : "false",
                            usd_broad ? "true" : "false",
                            breakout ? "true" : "false",
                            g_strategy_attempt_fresh ? "true" : "false",
                            g_strategy_history_clear ? "true" : "false",
                            g_strategy_entry_ready ? "true" : "false"));
   return true;
  }

bool Strategy_GetOwnedPosition(datetime &opened_at,
                               ulong &ticket_out,
                               double &stop_out,
                               bool &integrity_ok)
  {
   opened_at = 0;
   ticket_out = 0;
   stop_out = 0.0;
   integrity_ok = false;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   int count = 0;
   bool valid = true;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ++count;
      const string symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double stop = PositionGetDouble(POSITION_SL);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      if(symbol != STRATEGY_SYMBOL || position_type != POSITION_TYPE_SELL ||
         opened <= 0 || !MathIsValidNumber(open_price) || open_price <= 0.0 ||
         !MathIsValidNumber(stop) || stop <= 0.0 ||
         !MathIsValidNumber(volume) || volume <= 0.0)
         valid = false;

      if(ticket_out == 0 || opened < opened_at)
        {
         opened_at = opened;
         ticket_out = ticket;
         stop_out = stop;
        }
     }

   integrity_ok = (count == 1 && valid);
   return (count > 0);
  }

bool Strategy_HasOwnedPosition()
  {
   datetime opened_at = 0;
   ulong ticket = 0;
   double stop = 0.0;
   bool integrity_ok = false;
   return Strategy_GetOwnedPosition(opened_at,
                                    ticket,
                                    stop,
                                    integrity_ok);
  }

void Strategy_CloseAllOwned(const QM_ExitReason reason)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(QM_TM_ClosePosition(ticket, reason))
         g_strategy_closed_this_tick = true;
     }
  }

bool Strategy_ExecutionMetadataValid(const string symbol,
                                     const MqlTick &tick)
  {
   if(!MathIsValidNumber(tick.bid) || !MathIsValidNumber(tick.ask) ||
      tick.bid <= 0.0 || tick.ask <= 0.0 || tick.ask < tick.bid)
      return false;

   long trade_mode = 0;
   if(!SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE, trade_mode) ||
      trade_mode == SYMBOL_TRADE_MODE_DISABLED ||
      trade_mode == SYMBOL_TRADE_MODE_CLOSEONLY ||
      trade_mode == SYMBOL_TRADE_MODE_LONGONLY)
      return false;

   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   const double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   const double contract_size =
      SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   const double volume_min = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   const double volume_max = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   const double volume_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   return (MathIsValidNumber(point) && point > 0.0 &&
           MathIsValidNumber(tick_size) && tick_size > 0.0 &&
           MathIsValidNumber(tick_value) && tick_value > 0.0 &&
           MathIsValidNumber(contract_size) && contract_size > 0.0 &&
           MathIsValidNumber(volume_min) && volume_min > 0.0 &&
           MathIsValidNumber(volume_max) && volume_max >= volume_min &&
           MathIsValidNumber(volume_step) && volume_step > 0.0);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap identity guard only. Entry quote, spread, history, and signal gates
// stay below management so they cannot suspend protective exits.
bool Strategy_NoTradeFilter()
  {
   return (_Symbol != STRATEGY_SYMBOL ||
           (ENUM_TIMEFRAMES)_Period != strategy_signal_tf);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_strategy_state_ready || !g_strategy_entry_ready ||
      g_strategy_closed_this_tick || Strategy_HasOwnedPosition())
      return false;

   MqlTick tick;
   ZeroMemory(tick);
   if(!SymbolInfoTick(STRATEGY_SYMBOL, tick) ||
      !Strategy_ExecutionMetadataValid(STRATEGY_SYMBOL, tick))
      return false;

   const double point = SymbolInfoDouble(STRATEGY_SYMBOL, SYMBOL_POINT);
   const double spread_points = (tick.ask - tick.bid) / point;
   if(!MathIsValidNumber(spread_points) || spread_points < 0.0 ||
      (spread_points > 0.0 &&
       spread_points > strategy_max_spread_points))
      return false;

   const double stop = QM_StopATRFromValue(STRATEGY_SYMBOL,
                                           QM_SELL,
                                           tick.bid,
                                           g_strategy_signal_atr,
                                           strategy_stop_atr);
   if(!MathIsValidNumber(stop) || stop <= tick.bid || stop <= tick.ask)
      return false;

   const double stop_points = (stop - tick.bid) / point;
   const int broker_stops_level =
      (int)SymbolInfoInteger(STRATEGY_SYMBOL, SYMBOL_TRADE_STOPS_LEVEL);
   if(!MathIsValidNumber(stop_points) || stop_points <= 0.0 ||
      (broker_stops_level > 0 && stop_points < broker_stops_level))
      return false;

   const double risk_lots = QM_LotsForRisk(STRATEGY_SYMBOL, stop_points);
   if(!MathIsValidNumber(risk_lots) || risk_lots <= 0.0)
      return false;

   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = stop;
   req.tp = 0.0;
   req.reason = "AUDUSD_GLOBAL_DOLLAR_STRESS_SHORT";
   req.symbol_slot = 0;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   datetime opened_at = 0;
   ulong ticket = 0;
   double current_stop = 0.0;
   bool integrity_ok = false;
   if(!Strategy_GetOwnedPosition(opened_at,
                                 ticket,
                                 current_stop,
                                 integrity_ok))
      return;

   if(!integrity_ok)
     {
      Strategy_CloseAllOwned(QM_EXIT_STRATEGY);
      return;
     }
   if(!g_strategy_closed_bar_advanced || g_strategy_closed_this_tick)
      return;

   // The approved lifecycle gives invalid/composite-gate clear precedence
   // over the time stop. Strategy_ExitSignal owns that close immediately
   // after this hook, so leave the position untouched here.
   if(!g_strategy_state_ready || !g_strategy_composite_gate)
      return;

   const int entry_shift =
      iBarShift(STRATEGY_SYMBOL,
                strategy_signal_tf,
                opened_at,
                false); // perf-allowed: one bounded D1 holding-period lookup on the sole new-bar edge.
   if(entry_shift < 0 || entry_shift >= strategy_max_hold_bars)
     {
      if(QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP))
         g_strategy_closed_this_tick = true;
      return;
     }

   MqlTick tick;
   ZeroMemory(tick);
   if(!SymbolInfoTick(STRATEGY_SYMBOL, tick) ||
      tick.ask <= 0.0 || tick.bid <= 0.0 || tick.ask < tick.bid)
      return;

   const double point = SymbolInfoDouble(STRATEGY_SYMBOL, SYMBOL_POINT);
   const double raw_candidate = g_strategy_signal_close +
                                strategy_trail_atr * g_strategy_signal_atr;
   const double candidate =
      QM_StopRulesNormalizePrice(STRATEGY_SYMBOL, raw_candidate);
   if(!MathIsValidNumber(point) || point <= 0.0 ||
      !MathIsValidNumber(candidate) || candidate <= tick.ask ||
      candidate >= current_stop - 0.5 * point)
      return;

   const double distance_points = (candidate - tick.ask) / point;
   const int broker_stops_level =
      (int)SymbolInfoInteger(STRATEGY_SYMBOL, SYMBOL_TRADE_STOPS_LEVEL);
   if(!MathIsValidNumber(distance_points) || distance_points <= 0.0 ||
      (broker_stops_level > 0 && distance_points < broker_stops_level))
      return;

   QM_TM_MoveSL(ticket,
                candidate,
                "AUDUSD_DOLLAR_STRESS_D1_ATR_TRAIL");
  }

bool Strategy_ExitSignal()
  {
   if(!g_strategy_closed_bar_advanced || g_strategy_closed_this_tick ||
      !Strategy_HasOwnedPosition())
      return false;
   return (!g_strategy_state_ready || !g_strategy_composite_gate);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(_Symbol != STRATEGY_SYMBOL ||
      (ENUM_TIMEFRAMES)_Period != PERIOD_D1 ||
      !Strategy_ParametersValid())
      return INIT_PARAMETERS_INCORRECT;

   for(int index = 0; index < ArraySize(g_dependency_symbols); ++index)
      if(!SymbolSelect(g_dependency_symbols[index], true))
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
         "Approved D1 dollar-stress hold uses hard stop, monotone ATR trail, composite-gate clear, and ten-bar time exit"))
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

   if(QM_MagicChecked(qm_ea_id, 0, STRATEGY_SYMBOL) <= 0)
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

   QM_EntryConfigure(qm_ea_id,
                     qm_news_mode_legacy,
                     strategy_deviation_points,
                     qm_stress_reject_probability,
                     qm_news_temporal,
                     qm_news_compliance,
                     QM_FrameworkMagic());
   QM_SymbolGuardInit(g_dependency_symbols);
   QM_BasketWarmupHistory(g_dependency_symbols,
                          PERIOD_D1,
                          STRATEGY_WARMUP_BARS);
   Strategy_LoadAttemptState();
   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_41283\",\"strategy\":\"audusd_dollar_stress_trend\",\"execution_symbol\":\"AUDUSD.DWX\"}");
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
   g_strategy_closed_this_tick = false;
   g_strategy_closed_bar_advanced = false;

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   const bool strategy_new_bar =
      QM_IsNewBar(STRATEGY_SYMBOL, strategy_signal_tf);
   if(strategy_new_bar)
     {
      g_strategy_closed_bar_advanced = true;
      Strategy_AdvanceClosedBarState();
     }

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
      Strategy_CloseAllOwned(QM_EXIT_STRATEGY);

   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(STRATEGY_SYMBOL,
                                        broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(STRATEGY_SYMBOL,
                                       broker_now,
                                       qm_news_mode_legacy);
   if(!news_allows || !strategy_new_bar)
      return;

   QM_EquityStreamOnNewBar();

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
