#property strict
#property version   "5.0"
#property description "QM5_41405 Balke clock audit — non-live measurement sibling"

// Recovery 2026-09-09: own the straddle veto once; preserve parent mechanics.
#define QM_PATTERN_PERMISSION_EA_MANAGED
#include <QM/QM_Common.mqh>
#include <QM/QM_PatternPermission.mqh>
#include <QM/QM_PatternPermissionStraddle.mqh>

// NON-LIVE measurement sibling of QM5_41398, approved card 2026-09-11.
// Six declared switches; defaults preserve the parent on s0_l8 / exit 18.
// Parent permission/day-consumption, risk, news, Friday close and trailing
// remain intact. Default trade-list identity requires governed measurements.

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 41405;
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
// Stage-A winning window; the remaining inherited parameters stay frozen.
input int    strategy_range_start_hour = 0;
input int    strategy_range_end_hour   = 8;
input int    strategy_exit_hour        = 18;
input int    strategy_atr_period            = 14;
input double strategy_min_range_atr_mult    = 0.4;
input double strategy_max_range_atr_mult    = 2.5;
input double strategy_trail_trigger_r       = 1.0;
input int    strategy_range_scan_bars       = 36;

enum StrategyClockMode { GMT3_FIXED=0, BROKER_DST=1, CET_LOCAL=2 };
enum StrategyOutsideRule { AS_IS=0, SKIP_DAY=1, MARKET_ENTRY_IN_BREAKOUT_DIRECTION=2, OPPOSITE_STOP_ONLY=3 };
enum StrategyRangePeriod { RANGE_H1=0, RANGE_M30=1, RANGE_M5=2 };
input StrategyClockMode strategy_clock_mode = GMT3_FIXED;
input StrategyOutsideRule strategy_outside_range_rule = AS_IS;
input int strategy_entry_buffer_points = 0;
input bool strategy_range_band_enabled = true;
input StrategyRangePeriod strategy_range_bar_period = RANGE_H1;
input int strategy_range_end_minute = 0;

// DL-089 phase-1 surface. Zero means no predicate in that slot. Non-zero
// values must name an implemented QM_PatternId or initialization fails closed.
input group "Optimization Pattern Profile"
input int opt_pp_buy1  = 0;
input int opt_pp_buy2  = 0;
input int opt_pp_buy3  = 0;
input int opt_pp_sell1 = 0;
input int opt_pp_sell2 = 0;
input int opt_pp_sell3 = 0;

// DL-089 stage S5 optimizes the parent's ALREADY-WIRED numeric levers
// (strategy_max_range_atr_mult, strategy_trail_trigger_r, strategy_range_end_hour;
// candidate ladders in opt_param_grid.json) — one lever per trial, parent value
// as the mandatory control cell. No inert placeholder inputs exist here: an
// input with no mechanical use site would violate the wired-input rule
// (QM5_1355) and could carry no S5 trial. There is deliberately no take-profit
// lever — the parent has no TP mechanic (req.tp is fixed 0.0).

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

// EU DST changes at 01:00 UTC on the last Sunday of March/October.
// This intentionally does not use the broker's US/NY-close DST calendar.
datetime Strategy_EuTransitionUtc(const int year, const int month)
  {
   MqlDateTime boundary;
   ZeroMemory(boundary);
   boundary.year = year;
   boundary.mon = month;
   boundary.day = 31;
   boundary.hour = 1;
   const datetime last_day = StructToTime(boundary);
   TimeToStruct(last_day, boundary);
   return last_day - boundary.day_of_week * 86400;
  }

datetime Strategy_ClockTime(const datetime broker_time)
  {
   if(strategy_clock_mode == BROKER_DST)
      return broker_time;
   const datetime utc = QM_BrokerToUTC(broker_time);
   if(strategy_clock_mode == GMT3_FIXED)
      return utc + 3 * 3600;
   MqlDateTime stamp;
   TimeToStruct(utc, stamp);
   const bool summer = (utc >= Strategy_EuTransitionUtc(stamp.year, 3) &&
                       utc < Strategy_EuTransitionUtc(stamp.year, 10));
   return utc + (summer ? 2 : 1) * 3600;
  }

int Strategy_ClockMinute(const datetime broker_time)
  {
   MqlDateTime stamp;
   TimeToStruct(Strategy_ClockTime(broker_time), stamp);
   return stamp.hour * 60 + stamp.min;
  }

ENUM_TIMEFRAMES Strategy_RangeTimeframe()
  {
   if(strategy_range_bar_period == RANGE_M30) return PERIOD_M30;
   if(strategy_range_bar_period == RANGE_M5) return PERIOD_M5;
   return PERIOD_H1;
  }

int Strategy_ClockDayKey(const datetime broker_time)
  {
   const datetime gmt3 = Strategy_ClockTime(broker_time);
   MqlDateTime dt;
   TimeToStruct(gmt3, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int Strategy_ClockHour(const datetime broker_time)
  {
   const datetime gmt3 = Strategy_ClockTime(broker_time);
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
   const ENUM_TIMEFRAMES range_tf = Strategy_RangeTimeframe();
   const int bar_minutes = PeriodSeconds(range_tf) / 60;
   const int scan_bars = strategy_range_scan_bars * (60 / bar_minutes);
   const int copied = CopyRates(_Symbol, range_tf, 1, scan_bars, rates); // perf-allowed: bounded closed-bar range scan; 36 H1-equivalent hours.
   if(copied <= 0)
      return false;

   for(int i = 0; i < copied; ++i)
     {
      const datetime bar_time = rates[i].time;
      if(Strategy_ClockDayKey(bar_time) != day_key)
         continue;
      const int minute = Strategy_ClockMinute(bar_time);
      if(minute < strategy_range_start_hour * 60 ||
         minute + bar_minutes > strategy_range_end_hour * 60 + strategy_range_end_minute)
         continue;
      range_high = MathMax(range_high, rates[i].high);
      range_low = MathMin(range_low, rates[i].low);
      bars_in_range++;
     }

   return (bars_in_range >= ((strategy_range_end_hour - strategy_range_start_hour) * 60 + strategy_range_end_minute) / bar_minutes &&
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
   const int day_key = Strategy_ClockDayKey(TimeCurrent());
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
   const int day_key = Strategy_ClockDayKey(now);
   const int hour = Strategy_ClockHour(now);
   if(hour != strategy_range_end_hour ||
      Strategy_ClockMinute(now) < strategy_range_end_hour * 60 + strategy_range_end_minute)
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
   if((strategy_range_band_enabled && atr <= 0.0) || range_height <= 0.0)
      return false;
   if(strategy_range_band_enabled &&
      (range_height < strategy_min_range_atr_mult * atr ||
       range_height > strategy_max_range_atr_mult * atr))
     {
      g_strategy_skip_day_key = day_key;
      return false;
     }

   g_strategy_range_high = range_high;
   g_strategy_range_low = range_low;
   g_strategy_range_day_key = day_key;

   const double buffer = strategy_entry_buffer_points * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double buy_trigger = Strategy_NormalizePrice(range_high + buffer);
   const double sell_trigger = Strategy_NormalizePrice(range_low - buffer);
   Strategy_PopulateEntry(plan.buy_req, QM_BUY_STOP, buy_trigger, range_low, "BALKE_RANGE_BUY_STOP");
   Strategy_PopulateEntry(plan.sell_req, QM_SELL_STOP, sell_trigger, range_high, "BALKE_RANGE_SELL_STOP");
   plan.want_buy = true;
   plan.want_sell = true;
   // AS_IS keeps both parent stop attempts, including the known rejected-price
   // and intent-based day-completion behavior; do not silently repair it.
   if(strategy_outside_range_rule == AS_IS)
      return true;
   MqlTick quote;
   if(!SymbolInfoTick(_Symbol, quote) || quote.bid <= 0.0 || quote.ask <= 0.0 || quote.ask < quote.bid)
     {
      g_strategy_skip_day_key = day_key;
      return false;
     }
   const bool above = quote.ask > buy_trigger;
   const bool below = quote.bid < sell_trigger;
   if((above && below) || ((above || below) && strategy_outside_range_rule == SKIP_DAY))
     {
      g_strategy_skip_day_key = day_key;
      return false;
     }
   if(above || below)
     {
      const bool market_entry = strategy_outside_range_rule == MARKET_ENTRY_IN_BREAKOUT_DIRECTION;
      plan.want_buy = market_entry ? above : below;
      plan.want_sell = market_entry ? below : above;
      if(market_entry && above)
         Strategy_PopulateEntry(plan.buy_req, QM_BUY, quote.ask, range_low, "BALKE_OUTSIDE_MARKET_BUY");
      if(market_entry && below)
         Strategy_PopulateEntry(plan.sell_req, QM_SELL, quote.bid, range_high, "BALKE_OUTSIDE_MARKET_SELL");
     }
   // Minimum-distance acceptance remains owned and logged by trade management.
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const datetime now = TimeCurrent();
   const int hour = Strategy_ClockHour(now);
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
   if(Strategy_ClockHour(now) >= strategy_exit_hour)
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

bool Opt_AddPattern(const int predicate_id, const bool buy_side, const string input_name)
  {
   if(predicate_id == 0)
      return true;
   if(predicate_id < 0)
     {
      QM_LogEvent(QM_ERROR, "PP_CENSUS_CONFIG_INVALID",
                  StringFormat("{\"reason\":\"invalid_predicate_id\",\"input\":\"%s\",\"predicate_id\":%d}",
                               input_name, predicate_id));
      return false;
     }

   const QM_PatternId pid = (QM_PatternId)predicate_id;
   const bool added = buy_side
                      ? QM_PP_ProfileAddBuy(g_pp_profile, pid)
                      : QM_PP_ProfileAddSell(g_pp_profile, pid);
   if(!added)
     {
      QM_LogEvent(QM_ERROR, "PP_CENSUS_CONFIG_INVALID",
                  StringFormat("{\"reason\":\"predicate_not_implemented\",\"input\":\"%s\",\"predicate_id\":%d}",
                               input_name, predicate_id));
      return false;
     }
   g_pp_active = true;
   return true;
  }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
  {
   const int bar_minutes = PeriodSeconds(Strategy_RangeTimeframe()) / 60;
   if((int)strategy_clock_mode < 0 || (int)strategy_clock_mode > 2 ||
      (int)strategy_outside_range_rule < 0 || (int)strategy_outside_range_rule > 3 ||
      (int)strategy_range_bar_period < 0 || (int)strategy_range_bar_period > 2 ||
      (strategy_entry_buffer_points != 0 && strategy_entry_buffer_points != 20) ||
      (strategy_range_end_minute != 0 && strategy_range_end_minute != 30) ||
      strategy_range_end_minute % bar_minutes != 0 ||
      strategy_range_start_hour < 0 || strategy_range_start_hour > 23 ||
      strategy_range_end_hour <= strategy_range_start_hour || strategy_range_end_hour > 23 ||
      strategy_exit_hour <= strategy_range_end_hour || strategy_exit_hour > 23 ||
      strategy_atr_period < 1 || strategy_range_scan_bars < 24 || strategy_range_scan_bars > 168 ||
      strategy_min_range_atr_mult < 0.0 || strategy_max_range_atr_mult < strategy_min_range_atr_mult ||
      strategy_trail_trigger_r <= 0.0 || qm_news_stale_max_hours > 336 || qm_news_stale_max_hours <= 0)
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

   g_pp_active = false;
   QM_PP_ProfileInit(g_pp_profile, "DL089_OPT",
                     QM_PPC_REFERENCE_TF, QM_PPC_CLOSED_SHIFT);
   if(!Opt_AddPattern(opt_pp_buy1,  true,  "opt_pp_buy1")  ||
      !Opt_AddPattern(opt_pp_buy2,  true,  "opt_pp_buy2")  ||
      !Opt_AddPattern(opt_pp_buy3,  true,  "opt_pp_buy3")  ||
      !Opt_AddPattern(opt_pp_sell1, false, "opt_pp_sell1") ||
      !Opt_AddPattern(opt_pp_sell2, false, "opt_pp_sell2") ||
      !Opt_AddPattern(opt_pp_sell3, false, "opt_pp_sell3"))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "PP_CENSUS_INIT",
               StringFormat("{\"enabled\":%s,\"buy\":[%d,%d,%d],\"sell\":[%d,%d,%d],\"reference_tf\":%d,\"closed_shift\":%d,\"profile_key\":\"%s\"}",
                            (g_pp_active ? "true" : "false"),
                            opt_pp_buy1, opt_pp_buy2, opt_pp_buy3,
                            opt_pp_sell1, opt_pp_sell2, opt_pp_sell3,
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
               StringFormat("{\"profile_key\":\"%s\",\"enabled\":%s,\"days_evaluated\":%I64d,\"fire_count\":%I64d,\"legs_suppressed\":%I64d,\"invalid_days\":%I64d}",
                            (g_pp_active ? QM_PP_ProfileKey(g_pp_profile) : "control"),
                            (g_pp_active ? "true" : "false"),
                            g_pp_days_evaluated, g_pp_fire_count,
                            g_pp_legs_suppressed, g_pp_invalid_days));
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();

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

   const bool new_bar = QM_IsNewBar();
   if(new_bar)
      QM_EquityStreamOnNewBar();
   // Preserve parent H1 placement for minute-zero configurations. The declared
   // half-hour configuration is admitted on its first eligible tick after :30.
   if(strategy_range_end_minute == 0 && !new_bar)
      return;

   // --- A1/A2: plan -> permission -> decision -> placement ------------------
   QM_StraddlePlan plan;
   if(!Strategy_BuildStraddlePlan(plan))
      return;

   const QM_PermissionResult perm = Census_Permission();
   const QM_StraddleDecision decision = QM_PPS_Decide(plan, perm);

   g_pp_days_evaluated++;
   if(!decision.permission_valid)
      g_pp_invalid_days++;
   else if(g_pp_active && (!perm.allow_buy || !perm.allow_sell))
      g_pp_fire_count++;

   if(plan.want_buy && !decision.place_buy)
      g_pp_legs_suppressed++;
   if(plan.want_sell && !decision.place_sell)
      g_pp_legs_suppressed++;

   if(plan.want_buy != decision.place_buy || plan.want_sell != decision.place_sell)
      QM_LogEvent(QM_INFO, "PP_CENSUS_BLOCK",
                  StringFormat("{\"bar\":\"%s\",\"profile_key\":\"%s\",\"place_buy\":%s,\"place_sell\":%s,\"reason\":\"%s\"}",
                               TimeToString(decision.reference_bar_time),
                               QM_PP_ProfileKey(g_pp_profile),
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
      g_strategy_orders_day_key = Strategy_ClockDayKey(TimeCurrent());
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
