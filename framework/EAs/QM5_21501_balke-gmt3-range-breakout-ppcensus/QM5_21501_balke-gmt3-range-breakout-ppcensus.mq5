#property strict
#property version   "5.0"
#property description "QM5_21501 Balke GMT3 Range Breakout — pattern-permission CENSUS instrument"

#include <QM/QM_Common.mqh>
#include <QM/QM_PatternPermission.mqh>
#include <QM/QM_PatternPermissionStraddle.mqh>

// =============================================================================
// CENSUS INSTRUMENT — NOT A DEPLOYABLE STRATEGY
// -----------------------------------------------------------------------------
// This EA exists to MEASURE, one predicate at a time, what the pattern-
// permission filter does to QM5_13213's straddle. It is the executable subject
// of the P3 census (plan v2 finding A5: no trial without a lawful subject).
//
// Identity band: 21001-21499 = promotion challengers, 21500+ = census
// instruments. A census instrument must never reach a book: its parameter
// surface is deliberately open (one predicate id fed in per trial), which is
// exactly what a live EA must not have. Promotion (P4) compiles the surviving
// predicates into a FIXED profile under a fresh challenger identity.
//
// Mechanics are byte-for-byte the parent's, with one structural change:
//
//   A1 FIX. The parent places the BUY leg inside Strategy_EntrySignal
//   (QM5_13213:310-313) and returns only the SELL via `req` (:315-317). Any
//   veto applied to the returned request is therefore a no-op for longs — a
//   buy-blocking predicate would have measured as "no effect on longs" while
//   silently still trading them. Here signal generation is side-effect free:
//   Strategy_BuildStraddlePlan fills a plan, permission is applied to the
//   whole plan, and only then is anything placed.
//
//   A2. Day completion follows the decision, not the signal. The parent sets
//   g_strategy_orders_day_key before returning (:316); if permission blocks
//   both legs the day must stay OPEN, otherwise a data gap would be silently
//   recorded as a deliberate no-trade day.
//
// Everything else — window, range construction, ATR band, trailing, evening
// flat, news, risk — is unchanged from the parent so the census measures the
// filter and nothing else.
//
// Reference TF and closed shift are compile-time constants, not inputs. The
// census fixes 1,386 cells; every extra knob is another way to corrupt the
// whole grid from a setfile typo. A sleeve needing a different reference bar
// gets its own instrument.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 21501;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Identical to QM5_13213. Do not tune here: the census varies the predicate,
// never the strategy, so every cell is comparable to the same control.
input int    strategy_range_start_hour = 3;
input int    strategy_range_end_hour   = 6;
input int    strategy_exit_hour        = 18;
input int    strategy_atr_period            = 14;
input double strategy_min_range_atr_mult    = 0.4;
input double strategy_max_range_atr_mult    = 2.5;
input double strategy_trail_trigger_r       = 1.0;
input int    strategy_range_scan_bars       = 36;

// The census trial surface: exactly {predicate_id, direction}, matching the
// PREDICATE_ABLATION lever's planned_trials shape. `strategy_`-prefixed so
// gen_setfile.ps1 carries them into every generated set file.
#define QM_PPC_BUY   0
#define QM_PPC_SELL  1

input group "Filters"
input bool strategy_pp_enabled      = false;  // false = control cell
input int  strategy_pp_predicate_id = 0;      // QM_PatternId value
// Plain int with a LITERAL default, NOT an enum and not a macro, on purpose:
// gen_setfile.ps1 copies the input's source default verbatim into the .set, so
// `= QM_PPC_BUY` would emit `strategy_pp_direction=QM_PPC_BUY`, which MT5
// cannot parse back. Every SELL cell would have silently run as BUY and half
// the census would have been wrong with no error surfacing.
// 0 = gate LONG entries, 1 = gate SHORT entries. Anything else aborts OnInit.
input int  strategy_pp_direction    = 0;

// Card-declared, deliberately not inputs — see header.
const ENUM_TIMEFRAMES QM_PPC_REFERENCE_TF = PERIOD_D1;
const int             QM_PPC_CLOSED_SHIFT = 1;

double g_strategy_range_high = 0.0;
double g_strategy_range_low = 0.0;
int    g_strategy_range_day_key = -1;
int    g_strategy_orders_day_key = -1;
int    g_strategy_skip_day_key = -1;

QM_PatternProfile g_pp_profile;
bool              g_pp_active = false;

// Census counters. fire_count is consumed by Q15's categorical eligibility
// gate: a predicate that almost never fires cannot be a credible winner, and
// the gate must be able to reject it BEFORE comparing objectives.
long g_pp_days_evaluated = 0;   // days a plan existed and permission was consulted
long g_pp_fire_count = 0;       // days the predicate blocked the tested direction
long g_pp_legs_suppressed = 0;  // entry legs actually withheld
long g_pp_invalid_days = 0;     // days permission was unavailable (fail-closed)

int Strategy_Gmt3DayKey(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   const datetime gmt3 = utc + 3 * 3600;
   MqlDateTime dt;
   TimeToStruct(gmt3, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int Strategy_Gmt3Hour(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   const datetime gmt3 = utc + 3 * 3600;
   MqlDateTime dt;
   TimeToStruct(gmt3, dt);
   return dt.hour;
  }

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = 8;
   return NormalizeDouble(price, digits);
  }

bool Strategy_IsOurPendingType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
  }

int Strategy_RemoveOurPendingOrders(const string reason)
  {
   int removed = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!Strategy_IsOurPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      if(QM_TM_RemovePendingOrder(ticket, reason))
         removed++;
     }
   return removed;
  }

bool Strategy_HasOurPendingOrders()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = 0; i < OrdersTotal(); ++i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(Strategy_IsOurPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

bool Strategy_HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = 0; i < PositionsTotal(); ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_BuildRangeForToday(const int day_key, double &range_high, double &range_low)
  {
   range_high = -DBL_MAX;
   range_low = DBL_MAX;
   int bars_in_range = 0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H1, 1, strategy_range_scan_bars, rates); // perf-allowed: closed-bar session range scan, bounded by input default 36.
   if(copied <= 0)
      return false;

   for(int i = 0; i < copied; ++i)
     {
      const datetime bar_time = rates[i].time;
      if(Strategy_Gmt3DayKey(bar_time) != day_key)
         continue;
      const int hour = Strategy_Gmt3Hour(bar_time);
      if(hour < strategy_range_start_hour || hour >= strategy_range_end_hour)
         continue;
      range_high = MathMax(range_high, rates[i].high);
      range_low = MathMin(range_low, rates[i].low);
      bars_in_range++;
     }

   return (bars_in_range >= (strategy_range_end_hour - strategy_range_start_hour) &&
           range_high > range_low && range_low > 0.0);
  }

void Strategy_ResetDailyState(const int day_key)
  {
   if(g_strategy_range_day_key == day_key || g_strategy_orders_day_key == day_key || g_strategy_skip_day_key == day_key)
      return;
   g_strategy_range_high = 0.0;
   g_strategy_range_low = 0.0;
  }

void Strategy_PopulateEntry(QM_EntryRequest &req,
                            const QM_OrderType type,
                            const double entry,
                            const double sl,
                            const string reason)
  {
   req.type = type;
   req.price = Strategy_NormalizePrice(entry);
   req.sl = Strategy_NormalizePrice(sl);
   req.tp = 0.0;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   const int day_key = Strategy_Gmt3DayKey(TimeCurrent());
   Strategy_ResetDailyState(day_key);
   return false;
  }

//+------------------------------------------------------------------+
//| A1 FIX — side-effect-free straddle signal.                        |
//|                                                                    |
//| Places NO order and never marks the day complete. It does cache    |
//| the resolved range (the exit hook reads it) and the skip flag (a   |
//| range outside the ATR band is a strategy decision, independent of  |
//| any permission verdict) — both idempotent per day and neither able |
//| to create an order. Everything that can put risk on the book       |
//| happens in OnTick, after QM_PPS_Decide.                            |
//+------------------------------------------------------------------+
bool Strategy_BuildStraddlePlan(QM_StraddlePlan &plan)
  {
   QM_PPS_InitPlan(plan);

   const datetime now = TimeCurrent();
   const int day_key = Strategy_Gmt3DayKey(now);
   const int hour = Strategy_Gmt3Hour(now);
   if(hour != strategy_range_end_hour)
      return false;
   if(g_strategy_orders_day_key == day_key || g_strategy_skip_day_key == day_key)
      return false;
   if(Strategy_HasOurOpenPosition() || Strategy_HasOurPendingOrders())
      return false;

   double range_high = 0.0;
   double range_low = 0.0;
   if(!Strategy_BuildRangeForToday(day_key, range_high, range_low))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double range_height = range_high - range_low;
   if(atr <= 0.0 || range_height <= 0.0)
      return false;
   if(range_height < strategy_min_range_atr_mult * atr ||
      range_height > strategy_max_range_atr_mult * atr)
     {
      g_strategy_skip_day_key = day_key;
      return false;
     }

   g_strategy_range_high = range_high;
   g_strategy_range_low = range_low;
   g_strategy_range_day_key = day_key;

   Strategy_PopulateEntry(plan.buy_req, QM_BUY_STOP, range_high, range_low, "BALKE_RANGE_BUY_STOP");
   Strategy_PopulateEntry(plan.sell_req, QM_SELL_STOP, range_low, range_high, "BALKE_RANGE_SELL_STOP");
   plan.want_buy = true;
   plan.want_sell = true;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const datetime now = TimeCurrent();
   const int hour = Strategy_Gmt3Hour(now);
   if(hour >= strategy_exit_hour)
      Strategy_RemoveOurPendingOrders("BALKE_RANGE_EOD_CANCEL");

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      Strategy_RemoveOurPendingOrders("BALKE_RANGE_OPPOSITE_TRIGGERED");

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const double risk_dist = MathAbs(open_price - current_sl);
      if(risk_dist <= 0.0)
         continue;

      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;

      const double moved = is_buy ? (market - open_price) : (open_price - market);
      if(moved < strategy_trail_trigger_r * risk_dist)
         continue;

      const double low1 = iLow(_Symbol, PERIOD_H1, 1);  // perf-allowed: constant two-bar structural trailing read.
      const double low2 = iLow(_Symbol, PERIOD_H1, 2);  // perf-allowed: constant two-bar structural trailing read.
      const double high1 = iHigh(_Symbol, PERIOD_H1, 1); // perf-allowed: constant two-bar structural trailing read.
      const double high2 = iHigh(_Symbol, PERIOD_H1, 2); // perf-allowed: constant two-bar structural trailing read.
      if(low1 <= 0.0 || low2 <= 0.0 || high1 <= 0.0 || high2 <= 0.0)
         continue;

      const double target_sl = is_buy ? MathMin(low1, low2) : MathMax(high1, high2);
      const double normalized_sl = Strategy_NormalizePrice(target_sl);
      if(normalized_sl <= 0.0)
         continue;

      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const bool improves = is_buy ? (normalized_sl > current_sl + point * 0.5)
                                   : (normalized_sl < current_sl - point * 0.5);
      if(improves)
         QM_TM_MoveSL(ticket, normalized_sl, "BALKE_RANGE_2BAR_SWING_TRAIL");
     }
  }

bool Strategy_ExitSignal()
  {
   const datetime now = TimeCurrent();
   if(Strategy_Gmt3Hour(now) >= strategy_exit_hour)
      return true;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || g_strategy_range_high <= 0.0 || g_strategy_range_low <= 0.0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && SymbolInfoDouble(_Symbol, SYMBOL_BID) <= g_strategy_range_low)
         return true;
      if(pos_type == POSITION_TYPE_SELL && SymbolInfoDouble(_Symbol, SYMBOL_ASK) >= g_strategy_range_high)
         return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
  }

//+------------------------------------------------------------------+
//| Census permission. When disabled, returns a valid all-allow       |
//| verdict so the control cell runs the parent's exact mechanics     |
//| through the identical code path — the control must differ from a  |
//| trial in the predicate only, not in the plumbing it traverses.    |
//+------------------------------------------------------------------+
QM_PermissionResult Census_Permission()
  {
   QM_PermissionResult perm;
   if(!g_pp_active)
     {
      perm.allow_buy = true;
      perm.allow_sell = true;
      perm.valid = true;
      // Control cell only, once per new bar. It exists so the control's verdict
      // carries the SAME reference-bar stamp a trial would, keeping the two
      // comparable in the ledger; QM_PatternPermissionEvaluate reads that bar.
      perm.reference_bar_time = iTime(_Symbol, QM_PPC_REFERENCE_TF, QM_PPC_CLOSED_SHIFT); // perf-allowed: single closed-bar timestamp read on the control path.
      perm.reason = "census_control";
      return perm;
     }
   return QM_PatternPermissionEvaluate(_Symbol, QM_PPC_REFERENCE_TF,
                                       QM_PPC_CLOSED_SHIFT, g_pp_profile);
  }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

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

   g_pp_active = false;

   if(!strategy_pp_enabled)
     {
      // A setfile that names a predicate but forgets to enable the filter
      // would run as a control cell while the ledger recorded it as a trial:
      // a silently wrong measurement. Refuse instead.
      if(strategy_pp_predicate_id != 0)
        {
         QM_LogEvent(QM_ERROR, "PP_CENSUS_CONFIG_INVALID",
                     StringFormat("{\"reason\":\"predicate_named_but_filter_disabled\",\"predicate_id\":%d}",
                                  strategy_pp_predicate_id));
         return INIT_FAILED;
        }
     }
   else
     {
      if(strategy_pp_predicate_id <= 0)
        {
         QM_LogEvent(QM_ERROR, "PP_CENSUS_CONFIG_INVALID",
                     "{\"reason\":\"filter_enabled_without_predicate\"}");
         return INIT_FAILED;
        }
      // A direction outside {0,1} would otherwise fall through to the SELL
      // branch below and mislabel the cell in the ledger.
      if(strategy_pp_direction != QM_PPC_BUY && strategy_pp_direction != QM_PPC_SELL)
        {
         QM_LogEvent(QM_ERROR, "PP_CENSUS_CONFIG_INVALID",
                     StringFormat("{\"reason\":\"invalid_direction\",\"direction\":%d}",
                                  strategy_pp_direction));
         return INIT_FAILED;
        }

      QM_PP_ProfileInit(g_pp_profile,
                        StringFormat("CENSUS_%d_%s", strategy_pp_predicate_id,
                                     (strategy_pp_direction == QM_PPC_BUY ? "BUY" : "SELL")),
                        QM_PPC_REFERENCE_TF, QM_PPC_CLOSED_SHIFT);

      const QM_PatternId pid = (QM_PatternId)strategy_pp_predicate_id;
      // Fail closed on an id this binary cannot evaluate. Without this the
      // predicate would never fire, the cell would come out identical to the
      // control, and the ledger would record "no effect" for a predicate that
      // was never actually tested.
      const bool added = (strategy_pp_direction == QM_PPC_BUY)
                         ? QM_PP_ProfileAddBuy(g_pp_profile, pid)
                         : QM_PP_ProfileAddSell(g_pp_profile, pid);
      if(!added)
        {
         QM_LogEvent(QM_ERROR, "PP_CENSUS_CONFIG_INVALID",
                     StringFormat("{\"reason\":\"predicate_not_implemented\",\"predicate_id\":%d}",
                                  strategy_pp_predicate_id));
         return INIT_FAILED;
        }
      g_pp_active = true;
     }

   QM_LogEvent(QM_INFO, "PP_CENSUS_INIT",
               StringFormat("{\"enabled\":%s,\"predicate_id\":%d,\"direction\":\"%s\",\"reference_tf\":%d,\"closed_shift\":%d,\"profile_key\":\"%s\"}",
                            (g_pp_active ? "true" : "false"),
                            strategy_pp_predicate_id,
                            (strategy_pp_direction == QM_PPC_BUY ? "BUY" : "SELL"),
                            (int)QM_PPC_REFERENCE_TF,
                            QM_PPC_CLOSED_SHIFT,
                            (g_pp_active ? QM_PP_ProfileKey(g_pp_profile) : "control")));

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   // The census summary. emit_dev_sweep.py binds fire_count per trial from
   // here; a trial whose summary is missing is a hard error there, never a
   // defaulted zero.
   QM_LogEvent(QM_INFO, "PP_CENSUS_SUMMARY",
               StringFormat("{\"predicate_id\":%d,\"direction\":\"%s\",\"enabled\":%s,\"days_evaluated\":%I64d,\"fire_count\":%I64d,\"legs_suppressed\":%I64d,\"invalid_days\":%I64d}",
                            strategy_pp_predicate_id,
                            (strategy_pp_direction == QM_PPC_BUY ? "BUY" : "SELL"),
                            (g_pp_active ? "true" : "false"),
                            g_pp_days_evaluated, g_pp_fire_count,
                            g_pp_legs_suppressed, g_pp_invalid_days));
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;
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
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   // --- A1/A2: plan -> permission -> decision -> placement ------------------
   QM_StraddlePlan plan;
   if(!Strategy_BuildStraddlePlan(plan))
      return;

   const QM_PermissionResult perm = Census_Permission();
   const QM_StraddleDecision decision = QM_PPS_Decide(plan, perm);

   g_pp_days_evaluated++;
   if(!decision.permission_valid)
      g_pp_invalid_days++;
   else if(g_pp_active)
     {
      const bool tested_side_blocked = (strategy_pp_direction == QM_PPC_BUY)
                                       ? !perm.allow_buy : !perm.allow_sell;
      if(tested_side_blocked)
         g_pp_fire_count++;
     }

   if(plan.want_buy && !decision.place_buy)
      g_pp_legs_suppressed++;
   if(plan.want_sell && !decision.place_sell)
      g_pp_legs_suppressed++;

   if(plan.want_buy != decision.place_buy || plan.want_sell != decision.place_sell)
      QM_LogEvent(QM_INFO, "PP_CENSUS_BLOCK",
                  StringFormat("{\"bar\":\"%s\",\"predicate_id\":%d,\"place_buy\":%s,\"place_sell\":%s,\"reason\":\"%s\"}",
                               TimeToString(decision.reference_bar_time),
                               strategy_pp_predicate_id,
                               (decision.place_buy ? "true" : "false"),
                               (decision.place_sell ? "true" : "false"),
                               decision.reason));

   if(decision.place_buy)
     {
      ulong buy_ticket = 0;
      QM_TM_OpenPosition(plan.buy_req, buy_ticket);
     }
   if(decision.place_sell)
     {
      ulong sell_ticket = 0;
      QM_TM_OpenPosition(plan.sell_req, sell_ticket);
     }

   // A2: the day closes only when the decision actually let something through.
   // An invalid-permission day stays open so a later bar with sound history
   // can still act, instead of a data gap masquerading as a no-trade day.
   if(decision.mark_day_complete)
      g_strategy_orders_day_key = Strategy_Gmt3DayKey(TimeCurrent());
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
