#property strict
#property version   "5.0"
#property description "SRC10 Index MAC(5) sign-only D1 reversal target"

#include <QM/QM_Common.mqh>
#include <QM/QM_FTMOGovernorClient.mqh>
#include "Strategy_MAC5Core.mqh"

// =============================================================================
// QM5_4007_index-mac5-rev
// Approved card: strategy-seeds/cards/index-mac5-rev_card.md (SRC10_S01)
// Research route: SP500.DWX only.  FTMO US500.cash deployment evidence is a
// separate, still-mandatory route qualification and is not transferred here.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 4007;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
// Source-replication baseline has no news filter.  OnInit freezes all axes OFF.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours       = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
// Card is FTMO 2-Step Swing-only and explicitly owns weekend holds.
input bool   qm_friday_close_enabled       = false;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
// All source/safety inputs below are locked in OnInit; no Q02 selection axis.
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_stop_mult        = 2.0;
input int    strategy_application_window_seconds = 900;
input int    strategy_exit_retry_seconds   = 5;
// 100 SP500.DWX points = 1.00 index-price unit at the two-digit FTMO contract.
input int    strategy_entry_spread_ceiling_points = 100;
// Non-tester identity comes only from the signed deploy manifest.  Empty
// defaults intentionally make a live attachment unable to open a position.
input string strategy_governor_policy_id   = "";
input string strategy_challenge_instance_id = "";
input int    strategy_governor_heartbeat_max_age_seconds = 5;

enum Strategy_MAC5ExitCause
  {
   STRATEGY_MAC5_EXIT_NONE = 0,
   STRATEGY_MAC5_EXIT_FLIP,
   STRATEGY_MAC5_EXIT_FLAT_TARGET,
   STRATEGY_MAC5_EXIT_INVALID_TARGET,
   STRATEGY_MAC5_EXIT_STALE_RESTART,
   STRATEGY_MAC5_EXIT_POSITION_CONTRACT,
   STRATEGY_MAC5_EXIT_RECOVERY_LATCH
  };

datetime              g_strategy_boundary = 0;
int                   g_strategy_target_direction = 0;
double                g_strategy_driver = 0.0;
bool                  g_strategy_target_valid = false;
bool                  g_strategy_event_finalized = false;
bool                  g_strategy_entry_attempted = false;
bool                  g_strategy_stop_hit = false;
bool                  g_strategy_exit_latched = false;
bool                  g_strategy_reverse_after_flat = false;
datetime              g_strategy_last_exit_attempt = 0;
Strategy_MAC5ExitCause g_strategy_exit_cause = STRATEGY_MAC5_EXIT_NONE;
double                g_strategy_governor_scale = 0.0;
string                g_strategy_last_governor_block = "";
datetime              g_strategy_last_governor_log = 0;

string Strategy_MAC5ExitCauseText(const Strategy_MAC5ExitCause cause)
  {
   switch(cause)
     {
      case STRATEGY_MAC5_EXIT_FLIP:              return "flip";
      case STRATEGY_MAC5_EXIT_FLAT_TARGET:       return "flat_target";
      case STRATEGY_MAC5_EXIT_INVALID_TARGET:    return "invalid_target";
      case STRATEGY_MAC5_EXIT_STALE_RESTART:     return "stale_restart";
      case STRATEGY_MAC5_EXIT_POSITION_CONTRACT: return "position_contract";
      case STRATEGY_MAC5_EXIT_RECOVERY_LATCH:    return "recovery_latch";
      default:                                   return "none";
     }
  }

string Strategy_MAC5ActionText(const Strategy_MAC5DeltaAction action)
  {
   switch(action)
     {
      case STRATEGY_MAC5_ACTION_RETAIN:        return "retain";
      case STRATEGY_MAC5_ACTION_FLATTEN:       return "flatten";
      case STRATEGY_MAC5_ACTION_ENTER_LONG:    return "enter_long";
      case STRATEGY_MAC5_ACTION_ENTER_SHORT:   return "enter_short";
      case STRATEGY_MAC5_ACTION_FLIP_TO_LONG:  return "flip_to_long";
      case STRATEGY_MAC5_ACTION_FLIP_TO_SHORT: return "flip_to_short";
      default:                                 return "skip";
     }
  }

datetime Strategy_CurrentD1Boundary()
  {
   // perf-allowed: the approved card explicitly defines iTime(D1,0) as the
   // decision timestamp; this O(1) read is the per-tick boundary detector.
   return iTime(_Symbol, PERIOD_D1, 0); // perf-allowed
  }

bool Strategy_WithinApplicationWindow(const datetime now_broker)
  {
   if(g_strategy_boundary <= 0 || now_broker < g_strategy_boundary)
      return false;
   return ((long)(now_broker - g_strategy_boundary) <=
           (long)strategy_application_window_seconds);
  }

bool Strategy_ReadTarget(int &target_direction,double &driver)
  {
   double closes[];
   ArrayResize(closes, 6);
   for(int shift = 1; shift <= 6; ++shift)
     {
      MqlRates bar;
      ZeroMemory(bar);
      if(!QM_ReadBar(_Symbol, PERIOD_D1, shift, bar) ||
         !Strategy_MAC5ValidClose(bar.close))
        {
         target_direction = 0;
         driver = 0.0;
         return false;
        }
      closes[shift - 1] = bar.close;
     }

   bool valid = false;
   target_direction = Strategy_MAC5TargetFromCloses(closes, valid, driver);
   return valid;
  }

bool Strategy_QuoteSnapshot(MqlTick &tick,double &spread_points)
  {
   ZeroMemory(tick);
   spread_points = 0.0;
   if(!SymbolInfoTick(_Symbol, tick) || tick.ask <= 0.0 || tick.bid <= 0.0 ||
      tick.ask < tick.bid)
      return false;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   spread_points = (tick.ask - tick.bid) / point;
   return (MathIsValidNumber(spread_points) && spread_points >= 0.0);
  }

int Strategy_PositionSnapshot(ulong &first_ticket,
                              int &direction,
                              double &volume,
                              double &stop_price,
                              bool &contract_valid)
  {
   first_ticket = 0;
   direction = 0;
   volume = 0.0;
   stop_price = 0.0;
   contract_valid = true;
   int count = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ++count;
      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const int candidate_direction = (position_type == POSITION_TYPE_BUY) ? 1 :
                                      ((position_type == POSITION_TYPE_SELL) ? -1 : 0);
      const double candidate_volume = PositionGetDouble(POSITION_VOLUME);
      const double candidate_stop = PositionGetDouble(POSITION_SL);
      if(first_ticket == 0)
        {
         first_ticket = ticket;
         direction = candidate_direction;
         volume = candidate_volume;
         stop_price = candidate_stop;
        }
      if(candidate_direction == 0 || candidate_volume <= 0.0 || candidate_stop <= 0.0)
         contract_valid = false;
     }
   if(count > 1)
      contract_valid = false;
   return count;
  }

bool Strategy_HasOurPosition()
  {
   ulong ticket = 0;
   int direction = 0;
   double volume = 0.0;
   double stop_price = 0.0;
   bool contract_valid = false;
   return (Strategy_PositionSnapshot(ticket, direction, volume, stop_price,
                                     contract_valid) > 0);
  }

string Strategy_StateKey(const datetime boundary,const string suffix)
  {
   return StringFormat("QM5.4007.%I64d.%I64d.%s",
                       AccountInfoInteger(ACCOUNT_LOGIN),
                       (long)boundary,
                       suffix);
  }

bool Strategy_PersistedFlag(const datetime boundary,const string suffix)
  {
   if(MQLInfoInteger(MQL_TESTER) != 0)
      return false;
   const string key = Strategy_StateKey(boundary, suffix);
   return (GlobalVariableCheck(key) && GlobalVariableGet(key) >= 0.5);
  }

bool Strategy_RecordFlag(const datetime boundary,const string suffix)
  {
   if(MQLInfoInteger(MQL_TESTER) != 0)
      return true;
   const string key = Strategy_StateKey(boundary, suffix);
   return (GlobalVariableSet(key, 1.0) != 0);
  }

bool Strategy_ReconstructBoundaryHistory(const datetime boundary,
                                         bool &entry_seen,
                                         bool &exit_seen,
                                         bool &stop_seen)
  {
   entry_seen = false;
   exit_seen = false;
   stop_seen = false;
   datetime to_time = TimeCurrent();
   if(to_time < boundary)
      to_time = boundary;
   if(!HistorySelect(boundary, to_time))
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = 0; i < HistoryDealsTotal(); ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 ||
         (int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;

      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry_kind == DEAL_ENTRY_IN || entry_kind == DEAL_ENTRY_INOUT)
         entry_seen = true;
      if(entry_kind == DEAL_ENTRY_OUT || entry_kind == DEAL_ENTRY_OUT_BY ||
         entry_kind == DEAL_ENTRY_INOUT)
        {
         exit_seen = true;
         if((ENUM_DEAL_REASON)HistoryDealGetInteger(deal, DEAL_REASON) == DEAL_REASON_SL)
            stop_seen = true;
        }
     }
   return true;
  }

bool Strategy_LiveRiskMatchesPolicy(const string policy_id)
  {
   if(RISK_FIXED > 0.0 || RISK_PERCENT <= 0.0)
      return false;
   if(policy_id == "FTMO_2S_P1_100K_V2")
      return (MathAbs(RISK_PERCENT - 0.15) <= 0.000000001);
   if(policy_id == "FTMO_2S_P2_100K_V2")
      return (MathAbs(RISK_PERCENT - 0.105) <= 0.000000001);
   if(policy_id == "FTMO_2S_FUNDED_100K_V2")
      return (RISK_PERCENT <= 0.10 + 0.000000001);
   return false;
  }

bool Strategy_NonTesterGovernorConfigValid()
  {
   if(MQLInfoInteger(MQL_TESTER) != 0)
      return true;

   QM_FTMO_GovernorPolicy policy;
   if(!QM_FTMO_SelectPolicy(strategy_governor_policy_id, policy) ||
      !QM_FTMO_IsExactPolicy(policy) ||
      !QM_FTMO_IdentifierValid(strategy_challenge_instance_id) ||
      strategy_governor_heartbeat_max_age_seconds != 5 ||
      !Strategy_LiveRiskMatchesPolicy(strategy_governor_policy_id))
      return false;
   if(AccountInfoString(ACCOUNT_CURRENCY) != "USD" ||
      (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) !=
      ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      return false;
   return true;
  }

bool Strategy_GovernorAllowsEntry()
  {
   if(MQLInfoInteger(MQL_TESTER) != 0)
     {
      g_strategy_governor_scale = 1.0;
      return true;
     }

   double scale = 0.0;
   string block_reason = "GOVERNOR_UNKNOWN";
   const bool allowed = QM_FTMO_ReadGovernorScale(
      strategy_governor_policy_id,
      strategy_challenge_instance_id,
      strategy_governor_heartbeat_max_age_seconds,
      scale,
      block_reason);
   if(!allowed)
     {
      g_strategy_governor_scale = 0.0;
      const datetime now_broker = TimeCurrent();
      if(block_reason != g_strategy_last_governor_block ||
         now_broker - g_strategy_last_governor_log >= 60)
        {
         g_strategy_last_governor_block = block_reason;
         g_strategy_last_governor_log = now_broker;
         QM_LogEvent(QM_WARN,
                     "MAC5_GOVERNOR_ENTRY_BLOCK",
                     StringFormat("{\"reason\":\"%s\",\"policy_id\":\"%s\"}",
                                  QM_LoggerEscapeJson(block_reason),
                                  QM_LoggerEscapeJson(strategy_governor_policy_id)));
        }
      return false;
     }

   g_strategy_governor_scale = scale;
   g_strategy_last_governor_block = "";
   return true;
  }

// No-Trade module: entry-only quote/spread and exact governor snapshot gate.
// Mandatory target exits deliberately never call this function.
bool Strategy_NoTradeFilter()
  {
   MqlTick tick;
   double spread_points = 0.0;
   if(!Strategy_QuoteSnapshot(tick, spread_points))
      return true;
   if(spread_points > (double)strategy_entry_spread_ceiling_points + 1e-9)
     {
      QM_LogEvent(QM_WARN,
                  "MAC5_ENTRY_SPREAD_BLOCK",
                  StringFormat("{\"spread_points\":%.2f,\"ceiling_points\":%d}",
                               spread_points,
                               strategy_entry_spread_ceiling_points));
      return true;
     }
   return !Strategy_GovernorAllowsEntry();
  }

// Entry module: cached D1 target plus frozen prior-D1 ATR(20) x 2 stop.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_strategy_target_valid || g_strategy_target_direction == 0 ||
      !Strategy_WithinApplicationWindow(TimeCurrent()) || Strategy_NoTradeFilter())
      return false;

   const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(!MathIsValidNumber(atr_value) || atr_value <= 0.0)
      return false;

   MqlTick tick;
   double spread_points = 0.0;
   if(!Strategy_QuoteSnapshot(tick, spread_points))
      return false;
   const QM_OrderType side = (g_strategy_target_direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = (side == QM_BUY) ? tick.ask : tick.bid;
   const double stop = QM_StopATRFromValue(_Symbol,
                                           side,
                                           entry_price,
                                           atr_value,
                                           strategy_atr_stop_mult);
   if(entry_price <= 0.0 || stop <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = stop;
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "MAC5_D1_LONG" : "MAC5_D1_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   QM_LogEvent(QM_INFO,
               "MAC5_ENTRY_ARMED",
               StringFormat("{\"boundary\":%I64d,\"target\":%d,\"driver\":%.12f,\"atr20\":%.8f,\"stop_mult\":%.2f,\"spread_points\":%.2f,\"governor_scale\":%.6f}",
                            (long)g_strategy_boundary,
                            g_strategy_target_direction,
                            g_strategy_driver,
                            atr_value,
                            strategy_atr_stop_mult,
                            spread_points,
                            g_strategy_governor_scale));
   return true;
  }

// Management module: no trail, BE, partial close, add, or stop replacement.
void Strategy_ManageOpenPosition()
  {
  }

// Close module: the state machine owns repeated-until-flat exits.
bool Strategy_ExitSignal()
  {
   return (g_strategy_exit_latched && Strategy_HasOurPosition());
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

void Strategy_LatchExit(const Strategy_MAC5ExitCause cause,
                        const bool reverse_after_flat)
  {
   g_strategy_exit_latched = true;
   g_strategy_reverse_after_flat = reverse_after_flat;
   g_strategy_exit_cause = cause;
   g_strategy_event_finalized = false;
   g_strategy_last_exit_attempt = 0;
  }

void Strategy_AttemptEntry(const datetime now_broker)
  {
   if(g_strategy_event_finalized || g_strategy_entry_attempted ||
      g_strategy_stop_hit || !g_strategy_target_valid ||
      g_strategy_target_direction == 0 ||
      !Strategy_WithinApplicationWindow(now_broker))
     {
      g_strategy_event_finalized = true;
      return;
     }

   // Mark before every possible send: broker/no-trade rejection is one-shot.
   g_strategy_entry_attempted = true;
   if(!Strategy_RecordFlag(g_strategy_boundary, "attempt"))
     {
      QM_LogEvent(QM_ERROR,
                  "MAC5_ATTEMPT_PERSIST_FAILED",
                  StringFormat("{\"boundary\":%I64d}", (long)g_strategy_boundary));
      g_strategy_event_finalized = true;
      return;
     }

   QM_EntryRequest req;
   ZeroMemory(req);
   if(!Strategy_EntrySignal(req))
     {
      QM_LogEvent(QM_WARN,
                  "MAC5_ENTRY_SKIPPED",
                  StringFormat("{\"boundary\":%I64d,\"target\":%d,\"reason\":\"entry_gate_or_data\"}",
                               (long)g_strategy_boundary,
                               g_strategy_target_direction));
      g_strategy_event_finalized = true;
      return;
     }

   const QM_RiskMode risk_mode = (RISK_FIXED > 0.0) ? QM_RISK_MODE_FIXED
                                                     : QM_RISK_MODE_PERCENT;
   const double base_risk_value = (risk_mode == QM_RISK_MODE_FIXED) ? RISK_FIXED
                                                                    : RISK_PERCENT;
   const double scaled_risk_value = base_risk_value * g_strategy_governor_scale;
   ulong out_ticket = 0;
   const bool opened = (scaled_risk_value > 0.0) &&
      QM_TM_OpenPosition(req,
                         out_ticket,
                         0,
                         risk_mode,
                         scaled_risk_value);
   QM_LogEvent(opened ? QM_INFO : QM_WARN,
               "MAC5_ENTRY_ATTEMPT_RESULT",
               StringFormat("{\"boundary\":%I64d,\"opened\":%s,\"ticket\":%I64u,\"risk_mode\":%d,\"base_risk\":%.8f,\"governor_scale\":%.8f,\"scaled_risk\":%.8f}",
                            (long)g_strategy_boundary,
                            opened ? "true" : "false",
                            out_ticket,
                            (int)risk_mode,
                            base_risk_value,
                            g_strategy_governor_scale,
                            scaled_risk_value));
   g_strategy_event_finalized = true;
  }

void Strategy_ProcessMandatoryExit(const datetime now_broker)
  {
   if(!g_strategy_exit_latched)
      return;

   if(!Strategy_HasOurPosition())
     {
      const bool reverse = g_strategy_reverse_after_flat &&
                           Strategy_WithinApplicationWindow(now_broker) &&
                           !g_strategy_entry_attempted && !g_strategy_stop_hit;
      const Strategy_MAC5ExitCause completed_cause = g_strategy_exit_cause;
      g_strategy_exit_latched = false;
      g_strategy_reverse_after_flat = false;
      g_strategy_exit_cause = STRATEGY_MAC5_EXIT_NONE;
      g_strategy_last_exit_attempt = 0;
      QM_LogEvent(QM_INFO,
                  "MAC5_FLAT_CONFIRMED",
                  StringFormat("{\"boundary\":%I64d,\"cause\":\"%s\",\"reverse_allowed\":%s}",
                               (long)g_strategy_boundary,
                               QM_LoggerEscapeJson(Strategy_MAC5ExitCauseText(completed_cause)),
                               reverse ? "true" : "false"));
      if(reverse)
         Strategy_AttemptEntry(now_broker);
      else
         g_strategy_event_finalized = true;
      return;
     }

   if(g_strategy_last_exit_attempt > 0 &&
      now_broker - g_strategy_last_exit_attempt < strategy_exit_retry_seconds)
      return;
   g_strategy_last_exit_attempt = now_broker;

   const int magic = QM_FrameworkMagic();
   int attempts = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ++attempts;
      const QM_ExitReason reason =
         (g_strategy_exit_cause == STRATEGY_MAC5_EXIT_FLIP)
         ? QM_EXIT_OPPOSITE_SIGNAL : QM_EXIT_STRATEGY;
      QM_TM_ClosePosition(ticket, reason);
     }
   QM_LogEvent(QM_INFO,
               "MAC5_EXIT_RETRY",
               StringFormat("{\"boundary\":%I64d,\"cause\":\"%s\",\"attempts\":%d}",
                            (long)g_strategy_boundary,
                            QM_LoggerEscapeJson(Strategy_MAC5ExitCauseText(g_strategy_exit_cause)),
                            attempts));

   // Order sends are synchronous; confirm flat immediately when possible.
   if(!Strategy_HasOurPosition())
      Strategy_ProcessMandatoryExit(now_broker);
  }

void Strategy_StartBoundary(const datetime boundary,const datetime now_broker)
  {
   const bool carry_exit = (g_strategy_exit_latched && Strategy_HasOurPosition());
   g_strategy_boundary = boundary;
   g_strategy_target_direction = 0;
   g_strategy_driver = 0.0;
   g_strategy_target_valid = Strategy_ReadTarget(g_strategy_target_direction,
                                                 g_strategy_driver);
   g_strategy_event_finalized = false;
   g_strategy_entry_attempted = false;
   g_strategy_stop_hit = false;
   g_strategy_last_exit_attempt = 0;

   bool entry_seen = false;
   bool exit_seen = false;
   bool stop_seen = false;
   const bool history_ok = Strategy_ReconstructBoundaryHistory(boundary,
                                                               entry_seen,
                                                               exit_seen,
                                                               stop_seen);
   if(!history_ok)
      g_strategy_target_valid = false;
   g_strategy_entry_attempted = entry_seen || exit_seen ||
                                Strategy_PersistedFlag(boundary, "attempt");
   g_strategy_stop_hit = stop_seen || Strategy_PersistedFlag(boundary, "stop");
   if(g_strategy_stop_hit)
      g_strategy_entry_attempted = true;

   MqlTick tick;
   double spread_points = 0.0;
   const bool quote_valid = Strategy_QuoteSnapshot(tick, spread_points);
   const bool within_window = Strategy_WithinApplicationWindow(now_broker);

   ulong ticket = 0;
   int current_direction = 0;
   double current_volume = 0.0;
   double current_stop = 0.0;
   bool position_contract_valid = true;
   const int position_count = Strategy_PositionSnapshot(ticket,
                                                        current_direction,
                                                        current_volume,
                                                        current_stop,
                                                        position_contract_valid);

   QM_EquityStreamOnNewBar();
   QM_LogEvent(QM_INFO,
               "MAC5_D1_TARGET",
               StringFormat("{\"boundary\":%I64d,\"fill_delay_seconds\":%I64d,\"target_valid\":%s,\"target\":%d,\"driver\":%.12f,\"quote_valid\":%s,\"spread_points\":%.2f,\"positions\":%d,\"entry_seen\":%s,\"exit_seen\":%s,\"stop_seen\":%s,\"history_ok\":%s}",
                            (long)boundary,
                            (long)(now_broker - boundary),
                            g_strategy_target_valid ? "true" : "false",
                            g_strategy_target_direction,
                            g_strategy_driver,
                            quote_valid ? "true" : "false",
                            spread_points,
                            position_count,
                            entry_seen ? "true" : "false",
                            exit_seen ? "true" : "false",
                            g_strategy_stop_hit ? "true" : "false",
                            history_ok ? "true" : "false"));

   if(carry_exit && position_count > 0)
     {
      Strategy_LatchExit(STRATEGY_MAC5_EXIT_RECOVERY_LATCH, false);
      return;
     }

   g_strategy_exit_latched = false;
   g_strategy_reverse_after_flat = false;
   g_strategy_exit_cause = STRATEGY_MAC5_EXIT_NONE;

   if(position_count > 0 && !position_contract_valid)
     {
      Strategy_LatchExit(STRATEGY_MAC5_EXIT_POSITION_CONTRACT, false);
      return;
     }

   const bool effective_target_valid = g_strategy_target_valid && quote_valid;
   const bool entry_blocked = g_strategy_entry_attempted || g_strategy_stop_hit;
   const Strategy_MAC5DeltaAction action = Strategy_MAC5PlanDelta(
      current_direction,
      g_strategy_target_direction,
      effective_target_valid,
      within_window,
      entry_blocked);

   QM_LogEvent(QM_INFO,
               "MAC5_TARGET_DELTA_PLAN",
               StringFormat("{\"boundary\":%I64d,\"action\":\"%s\",\"current_direction\":%d,\"target_direction\":%d,\"within_window\":%s,\"entry_blocked\":%s}",
                            (long)boundary,
                            QM_LoggerEscapeJson(Strategy_MAC5ActionText(action)),
                            current_direction,
                            g_strategy_target_direction,
                            within_window ? "true" : "false",
                            entry_blocked ? "true" : "false"));

   if(action == STRATEGY_MAC5_ACTION_RETAIN)
     {
      // Audit the exact fields that must remain frozen.  No modify function is
      // called anywhere in this EA.
      QM_LogEvent(QM_INFO,
                  "MAC5_TARGET_RETAINED",
                  StringFormat("{\"boundary\":%I64d,\"ticket\":%I64u,\"volume_unchanged\":%.8f,\"sl_unchanged\":%.8f}",
                               (long)boundary,
                               ticket,
                               current_volume,
                               current_stop));
      g_strategy_event_finalized = true;
      return;
     }

   if(action == STRATEGY_MAC5_ACTION_FLIP_TO_LONG ||
      action == STRATEGY_MAC5_ACTION_FLIP_TO_SHORT)
     {
      Strategy_LatchExit(STRATEGY_MAC5_EXIT_FLIP, true);
      return;
     }

   if(action == STRATEGY_MAC5_ACTION_FLATTEN)
     {
      Strategy_MAC5ExitCause cause = STRATEGY_MAC5_EXIT_INVALID_TARGET;
      if(!within_window)
         cause = STRATEGY_MAC5_EXIT_STALE_RESTART;
      else if(g_strategy_target_valid && g_strategy_target_direction == 0)
         cause = STRATEGY_MAC5_EXIT_FLAT_TARGET;
      else if(g_strategy_target_valid && current_direction != 0 &&
              current_direction != g_strategy_target_direction)
         cause = STRATEGY_MAC5_EXIT_FLIP;
      Strategy_LatchExit(cause, false);
      return;
     }

   if(action == STRATEGY_MAC5_ACTION_ENTER_LONG ||
      action == STRATEGY_MAC5_ACTION_ENTER_SHORT)
      return; // OnTick invokes the single entry attempt after this setup.

   g_strategy_event_finalized = true;
  }

int OnInit()
  {
   if(qm_ea_id != 4007 || qm_magic_slot_offset != 0 || _Symbol != "SP500.DWX" ||
      strategy_atr_period_d1 != 20 ||
      MathAbs(strategy_atr_stop_mult - 2.0) > 0.000000001 ||
      strategy_application_window_seconds != 900 ||
      strategy_exit_retry_seconds != 5 ||
      strategy_entry_spread_ceiling_points != 100 ||
      qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE ||
      qm_news_mode_legacy != QM_NEWS_OFF ||
      qm_friday_close_enabled ||
      qm_stress_reject_probability < 0.0 ||
      qm_stress_reject_probability > 1.0 ||
      !Strategy_MAC5CoreSelfTest() ||
      !Strategy_NonTesterGovernorConfigValid())
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

   if(QM_FrameworkMagic() != 40070000 ||
      !QM_FrameworkDeclareExecutionContract(
         PERIOD_D1,
         QM_FRIDAY_CLOSE_DISABLED,
         "SRC10_S01 FTMO 2-Step Swing-only; weekend holds are source-valid"))
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

   if(MQLInfoInteger(MQL_TESTER) != 0)
     {
      QM_LogEvent(QM_INFO,
                  "MAC5_GOVERNOR_TESTER_BYPASS",
                  "{\"guard\":\"MQL_TESTER_only\",\"risk_scale\":1.0}");
     }
   else
     {
      // Snapshot failure blocks entries but does not abort initialization: a
      // restarted EA must remain alive to execute mandatory target flattening.
      Strategy_GovernorAllowsEntry();
     }

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"strategy_id\":\"SRC10_S01\",\"route\":\"SP500.DWX_research_only\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;

   if(QM_FrameworkHandleFridayClose())
      return;
   Strategy_ManageOpenPosition();

   const datetime now_broker = TimeCurrent();
   const datetime boundary = Strategy_CurrentD1Boundary();
   if(boundary <= 0)
     {
      if(Strategy_HasOurPosition() && !g_strategy_exit_latched)
         Strategy_LatchExit(STRATEGY_MAC5_EXIT_INVALID_TARGET, false);
      Strategy_ProcessMandatoryExit(now_broker);
      return;
     }

   if(boundary != g_strategy_boundary)
      Strategy_StartBoundary(boundary, now_broker);

   if(Strategy_ExitSignal() || g_strategy_exit_latched)
     {
      Strategy_ProcessMandatoryExit(now_broker);
      if(g_strategy_exit_latched)
         return;
     }

   if(!g_strategy_event_finalized)
      Strategy_AttemptEntry(now_broker);
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
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0 ||
      !HistoryDealSelect(trans.deal))
      return;
   if((int)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != QM_FrameworkMagic() ||
      HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol ||
      (ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON) != DEAL_REASON_SL)
      return;

   const ENUM_DEAL_ENTRY entry_kind =
      (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry_kind != DEAL_ENTRY_OUT && entry_kind != DEAL_ENTRY_OUT_BY &&
      entry_kind != DEAL_ENTRY_INOUT)
      return;

   const datetime current_boundary = Strategy_CurrentD1Boundary();
   const datetime deal_time = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
   if(current_boundary <= 0 || deal_time < current_boundary)
      return;

   g_strategy_stop_hit = true;
   g_strategy_entry_attempted = true;
   g_strategy_reverse_after_flat = false;
   g_strategy_event_finalized = true;
   if(!Strategy_RecordFlag(current_boundary, "stop"))
      QM_LogEvent(QM_ERROR,
                  "MAC5_STOP_STATE_PERSIST_FAILED",
                  StringFormat("{\"boundary\":%I64d,\"deal\":%I64u}",
                               (long)current_boundary,
                               trans.deal));
   QM_LogEvent(QM_WARN,
               "MAC5_STOP_HIT_DAY_LOCK",
               StringFormat("{\"boundary\":%I64d,\"deal\":%I64u,\"reentry\":false}",
                            (long)current_boundary,
                            trans.deal));
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
