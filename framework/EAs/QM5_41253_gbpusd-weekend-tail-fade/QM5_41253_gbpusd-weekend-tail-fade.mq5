#property strict
#property version   "5.0"
#property description "QM5_41253 GBPUSD Weekend Empirical-Tail Fade"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_41253 - GBPUSD Weekend Empirical-Tail Fade
// -----------------------------------------------------------------------------
// D1 structural FX sleeve:
//   - consume each broker-Monday week before every fallible strategy gate
//   - compare the current Friday-close/Monday-open log gap with exactly 52
//     earlier completed weekend gaps
//   - fade only strict sixth-from-either-tail observations
//   - hold through the week under a frozen ATR stop and framework Friday close
// Runtime uses MT5-native GBPUSD.DWX price, calendar, ATR, and execution state.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                      = 41253;
input int    qm_magic_slot_offset          = 0;
input uint   qm_rng_seed                    = 42;

input group "Risk"
input double RISK_PERCENT                  = 0.0;
input double RISK_FIXED                    = 1000.0;
input double PORTFOLIO_WEIGHT              = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours       = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = true;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_prior_gap_count      = 52;
input int    strategy_lower_index          = 5;
input int    strategy_upper_index          = 46;
input int    strategy_history_bars         = 900;
input int    strategy_entry_grace_minutes  = 180;
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_sl_mult          = 3.5;
input int    strategy_max_hold_days        = 7;
input int    strategy_max_spread_points    = 50;
input int    strategy_deviation_points     = 20;

const string g_symbol = "GBPUSD.DWX";

int      g_last_attempt_week_key = 0;
string   g_attempt_state_key     = "";
bool     g_decision_bar          = false;
bool     g_attempt_recorded_now  = false;
bool     g_late_decision         = false;
int      g_decision_week_key     = 0;
datetime g_decision_bar_time     = 0;
bool     g_signal_valid          = false;
int      g_signal_direction      = 0;
double   g_current_gap           = 0.0;
double   g_lower_gap             = 0.0;
double   g_upper_gap             = 0.0;
datetime g_oldest_gap_monday     = 0;
datetime g_newest_gap_monday     = 0;
string   g_signal_state          = "idle";

// -----------------------------------------------------------------------------
// Structural helpers.
// -----------------------------------------------------------------------------

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_symbol && _Period == PERIOD_D1);
  }

int Strategy_DateKeyForTime(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts) ||
      parts.year < 1900 || parts.mon < 1 || parts.mon > 12 ||
      parts.day < 1 || parts.day > 31)
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

int Strategy_DayOfWeek(const datetime value)
  {
   if(value <= 0)
      return -1;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts))
      return -1;
   return parts.day_of_week;
  }

int Strategy_WeekKeyForTime(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts))
      return 0;
   const int days_since_monday = (parts.day_of_week + 6) % 7;
   parts.hour = 0;
   parts.min = 0;
   parts.sec = 0;
   const datetime monday =
      StructToTime(parts) - (datetime)days_since_monday * 86400;
   return Strategy_DateKeyForTime(monday);
  }

bool Strategy_IsOwnedPosition()
  {
   return ((int)PositionGetInteger(POSITION_MAGIC) ==
           QM_FrameworkMagic());
  }

int Strategy_OwnedPositionCount()
  {
   int count = 0;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsOwnedPosition())
         ++count;
     }
   return count;
  }

bool Strategy_OwnedPositionStateValid()
  {
   if(Strategy_OwnedPositionCount() != 1)
      return false;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsOwnedPosition())
         continue;
      if(PositionGetString(POSITION_SYMBOL) != g_symbol)
         return false;
      const ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double stop_price = PositionGetDouble(POSITION_SL);
      const double take_profit = PositionGetDouble(POSITION_TP);
      if((type != POSITION_TYPE_BUY && type != POSITION_TYPE_SELL) ||
         opened <= 0 || opened > TimeCurrent() ||
         Strategy_DayOfWeek(opened) != 1 ||
         volume <= 0.0 || !MathIsValidNumber(volume) ||
         open_price <= 0.0 || !MathIsValidNumber(open_price) ||
         stop_price <= 0.0 || !MathIsValidNumber(stop_price) ||
         take_profit != 0.0 || !MathIsValidNumber(take_profit))
         return false;
      if(type == POSITION_TYPE_BUY && stop_price >= open_price)
         return false;
      if(type == POSITION_TYPE_SELL && stop_price <= open_price)
         return false;
      return true;
     }
   return false;
  }

datetime Strategy_CurrentEntryTime()
  {
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsOwnedPosition())
         continue;
      return (datetime)PositionGetInteger(POSITION_TIME);
     }
   return 0;
  }

void Strategy_CloseOwnedPositions(const QM_ExitReason reason)
  {
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsOwnedPosition())
         continue;
      QM_TM_ClosePosition(ticket, reason);
     }
  }

bool Strategy_SpreadAllowed()
  {
   MqlTick tick;
   ZeroMemory(tick);
   if(!SymbolInfoTick(_Symbol, tick) ||
      tick.bid <= 0.0 || tick.ask <= 0.0 ||
      !MathIsValidNumber(tick.bid) || !MathIsValidNumber(tick.ask) ||
      tick.ask < tick.bid)
      return false;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || !MathIsValidNumber(point))
      return false;
   const double spread_points = (tick.ask - tick.bid) / point;
   return (MathIsValidNumber(spread_points) &&
           spread_points >= 0.0 &&
           spread_points <= (double)strategy_max_spread_points);
  }

void Strategy_LoadAttemptState(const datetime reference_time)
  {
   g_last_attempt_week_key = 0;
   if(g_attempt_state_key == "" ||
      !GlobalVariableCheck(g_attempt_state_key))
      return;
   const int current_week_key =
      Strategy_WeekKeyForTime(reference_time);
   const double stored = GlobalVariableGet(g_attempt_state_key);
   const int stored_week_key = (int)MathRound(stored);
   if(current_week_key > 0 && MathIsValidNumber(stored) &&
      stored_week_key >= 19000101 &&
      stored_week_key <= current_week_key)
     {
      g_last_attempt_week_key = stored_week_key;
      return;
     }
   // Tester globals can outlive a later historical run.
   GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordWeekAttempt(const int week_key)
  {
   if(week_key <= 0 || g_attempt_state_key == "")
      return false;
   // Stay fail-closed in-process even if terminal persistence fails.
   g_last_attempt_week_key = week_key;
   return (GlobalVariableSet(g_attempt_state_key,
                             (double)week_key) > 0);
  }

bool Strategy_WeekAlreadyEntered(const int week_key)
  {
   if(week_key <= 0)
      return true;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsOwnedPosition())
         continue;
      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      if(Strategy_WeekKeyForTime(opened) == week_key)
         return true;
     }

   const datetime now = TimeCurrent();
   const datetime history_start = now - (datetime)14 * 86400;
   if(now <= 0 || history_start <= 0 ||
      !HistorySelect(history_start, now))
      return true;
   const int magic = QM_FrameworkMagic();
   const int deal_count = HistoryDealsTotal();
   for(int index = deal_count - 1; index >= 0; --index)
     {
      const ulong deal_ticket = HistoryDealGetTicket(index);
      if(deal_ticket == 0 ||
         (int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != g_symbol)
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_time =
         (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      if(Strategy_WeekKeyForTime(deal_time) == week_key)
         return true;
     }
   return false;
  }

bool Strategy_BarValid(const MqlRates &bar)
  {
   return (bar.time > 0 &&
           bar.open > 0.0 && MathIsValidNumber(bar.open) &&
           bar.high > 0.0 && MathIsValidNumber(bar.high) &&
           bar.low > 0.0 && MathIsValidNumber(bar.low) &&
           bar.close > 0.0 && MathIsValidNumber(bar.close) &&
           bar.high >= bar.low &&
           bar.high >= bar.open && bar.high >= bar.close &&
           bar.low <= bar.open && bar.low <= bar.close);
  }

void Strategy_ResetDecisionState()
  {
   g_decision_bar = false;
   g_attempt_recorded_now = false;
   g_late_decision = false;
   g_decision_week_key = 0;
   g_decision_bar_time = 0;
   g_signal_valid = false;
   g_signal_direction = 0;
   g_current_gap = 0.0;
   g_lower_gap = 0.0;
   g_upper_gap = 0.0;
   g_oldest_gap_monday = 0;
   g_newest_gap_monday = 0;
   g_signal_state = "idle";
  }

void Strategy_CaptureMondayAttempt_OnNewBar(const datetime broker_now)
  {
   if(Strategy_DayOfWeek(broker_now) != 1)
      return;
   const int week_key = Strategy_WeekKeyForTime(broker_now);
   if(week_key <= 0)
      return;

   g_decision_bar = true;
   g_decision_week_key = week_key;
   if(week_key == g_last_attempt_week_key)
     {
      g_signal_state = "week_already_consumed";
      return;
     }

   // The broker-week clock is the sole prerequisite. Persist before history,
   // arithmetic, news, spread, quote, ATR, sizing, margin, or order gates.
   g_attempt_recorded_now = Strategy_RecordWeekAttempt(week_key);
   if(!g_attempt_recorded_now)
      g_signal_state = "attempt_persist_failed";
  }

bool Strategy_LoadWeekendGaps(const datetime broker_now,
                              double &current_gap,
                              double &lower_gap,
                              double &upper_gap,
                              datetime &current_bar_time,
                              datetime &oldest_monday,
                              datetime &newest_monday)
  {
   current_gap = 0.0;
   lower_gap = 0.0;
   upper_gap = 0.0;
   current_bar_time = 0;
   oldest_monday = 0;
   newest_monday = 0;
   if(strategy_prior_gap_count != 52 ||
      strategy_lower_index != 5 ||
      strategy_upper_index != 46 ||
      strategy_history_bars != 900 ||
      strategy_entry_grace_minutes != 180)
      return false;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied =
      CopyRates(_Symbol, // perf-allowed: one bounded weekend-gap reconstruction behind the sole QM_IsNewBar branch.
                PERIOD_D1,
                0,
                strategy_history_bars,
                bars);
   const int bar_count = ArraySize(bars);
   if(copied < 2 || copied != bar_count || bar_count < 2 ||
      bar_count > strategy_history_bars)
      return false;

   // CopyRates is series-ordered here. Prove every read and require strict
   // descending timestamps plus positive finite OHLC throughout the buffer.
   for(int index = 0; index < ArraySize(bars); ++index)
     {
      if(!Strategy_BarValid(bars[index]))
         return false;
      if(index > 0 && bars[index].time >= bars[index - 1].time)
         return false;
     }

   const int current_index = 0;
   const int previous_index = 1;
   if(current_index < 0 || current_index >= ArraySize(bars) ||
      previous_index < 0 || previous_index >= ArraySize(bars))
      return false;
   if(Strategy_DayOfWeek(bars[current_index].time) != 1 ||
      Strategy_DayOfWeek(bars[previous_index].time) != 5 ||
      Strategy_WeekKeyForTime(bars[current_index].time) !=
         g_decision_week_key)
      return false;

   current_bar_time = bars[current_index].time;
   if(broker_now <= 0 || current_bar_time <= 0 ||
      broker_now < current_bar_time)
      return false;
   const long elapsed = (long)(broker_now - current_bar_time);
   if(elapsed > (long)strategy_entry_grace_minutes * 60L)
     {
      g_late_decision = true;
      return false;
     }

   const double current_ratio =
      bars[current_index].open / bars[previous_index].close;
   if(current_ratio <= 0.0 || !MathIsValidNumber(current_ratio))
      return false;
   current_gap = MathLog(current_ratio);
   if(!MathIsValidNumber(current_gap))
      return false;

   double newest_first[];
   if(ArrayResize(newest_first, strategy_prior_gap_count) !=
      strategy_prior_gap_count)
      return false;

   int gap_count = 0;
   for(int index = 1;
       index < ArraySize(bars) &&
       gap_count < strategy_prior_gap_count;
       ++index)
     {
      if(Strategy_DayOfWeek(bars[index].time) != 1)
         continue;
      const int friday_index = index + 1;
      if(friday_index < 0 || friday_index >= ArraySize(bars))
         return false;
      if(Strategy_DayOfWeek(bars[friday_index].time) != 5)
         return false;
      const double ratio =
         bars[index].open / bars[friday_index].close;
      if(ratio <= 0.0 || !MathIsValidNumber(ratio))
         return false;
      const double gap = MathLog(ratio);
      if(!MathIsValidNumber(gap))
         return false;
      if(gap_count < 0 || gap_count >= strategy_prior_gap_count)
         return false;
      if(gap_count >= ArraySize(newest_first))
         return false;
      newest_first[gap_count] = gap;
      if(gap_count == 0)
         newest_monday = bars[index].time;
      oldest_monday = bars[index].time;
      ++gap_count;
     }
   if(gap_count != strategy_prior_gap_count ||
      gap_count != ArraySize(newest_first))
      return false;

   // Materialize the required oldest-to-newest observation order before sort.
   double chronological[];
   double sorted[];
   if(ArrayResize(chronological, gap_count) != gap_count ||
      ArrayResize(sorted, gap_count) != gap_count)
      return false;
   for(int index = 0; index < gap_count; ++index)
     {
      if(index < 0 || index >= ArraySize(chronological))
         return false;
      if(index >= ArraySize(sorted))
         return false;
      const int reverse_index = gap_count - 1 - index;
      if(reverse_index < 0 ||
         reverse_index >= strategy_prior_gap_count)
         return false;
      if(reverse_index >= ArraySize(newest_first))
         return false;
      chronological[index] = newest_first[reverse_index];
      sorted[index] = chronological[index];
      if(!MathIsValidNumber(chronological[index]))
         return false;
     }
   if(!ArraySort(sorted))
      return false;
   for(int index = 0; index < ArraySize(sorted); ++index)
     {
      if(!MathIsValidNumber(sorted[index]))
         return false;
      if(index > 0 && sorted[index] < sorted[index - 1])
         return false;
     }

   if(strategy_lower_index < 0 || strategy_lower_index >= gap_count ||
      strategy_upper_index < 0 || strategy_upper_index >= gap_count ||
      strategy_lower_index >= strategy_upper_index)
      return false;
   if(strategy_lower_index >= ArraySize(sorted) ||
      strategy_upper_index >= ArraySize(sorted))
      return false;
   lower_gap = sorted[strategy_lower_index];
   upper_gap = sorted[strategy_upper_index];
   return (MathIsValidNumber(lower_gap) &&
           MathIsValidNumber(upper_gap) &&
           lower_gap <= upper_gap &&
           oldest_monday > 0 && newest_monday > 0 &&
           oldest_monday < newest_monday);
  }

void Strategy_PrepareDecisionSignal(const datetime broker_now)
  {
   if(!g_decision_bar || !g_attempt_recorded_now ||
      g_decision_week_key <= 0)
      return;
   if(Strategy_WeekAlreadyEntered(g_decision_week_key))
     {
      g_signal_state = "entry_deal_already_exists";
      return;
     }

   const bool history_valid =
      Strategy_LoadWeekendGaps(broker_now,
                               g_current_gap,
                               g_lower_gap,
                               g_upper_gap,
                               g_decision_bar_time,
                               g_oldest_gap_monday,
                               g_newest_gap_monday);
   if(!history_valid)
     {
      g_signal_state = g_late_decision
         ? "late_monday_restart_consumed_flat"
         : "weekend_gap_history_invalid";
     }
   else
     {
      g_signal_valid = true;
      if(g_current_gap < g_lower_gap)
        {
         g_signal_direction = 1;
         g_signal_state = "lower_tail_buy";
        }
      else if(g_current_gap > g_upper_gap)
        {
         g_signal_direction = -1;
         g_signal_state = "upper_tail_sell";
        }
      else if(g_current_gap == g_lower_gap ||
              g_current_gap == g_upper_gap)
         g_signal_state = "strict_threshold_tie_flat";
      else
         g_signal_state = "inside_empirical_tail_flat";
     }

   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"week\":%d,\"decision_bar\":%I64d,\"late\":%s,\"valid\":%s,\"signal\":%d,\"current_gap\":%.12f,\"lower_gap\":%.12f,\"upper_gap\":%.12f,\"oldest_monday\":%I64d,\"newest_monday\":%I64d,\"state\":\"%s\"}",
                            g_decision_week_key,
                            (long)g_decision_bar_time,
                            g_late_decision ? "true" : "false",
                            g_signal_valid ? "true" : "false",
                            g_signal_direction,
                            g_current_gap,
                            g_lower_gap,
                            g_upper_gap,
                            (long)g_oldest_gap_monday,
                            (long)g_newest_gap_monday,
                            g_signal_state));
  }

// -----------------------------------------------------------------------------
// No Trade Filter.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart() || qm_ea_id != 41253 ||
      qm_magic_slot_offset != 0 || qm_rng_seed != 42)
      return true;
   if(RISK_PERCENT != 0.0 || RISK_FIXED != 1000.0 ||
      PORTFOLIO_WEIGHT != 1.0)
      return true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE ||
      qm_news_mode_legacy != QM_NEWS_OFF ||
      qm_news_stale_max_hours != 336 ||
      qm_news_min_impact != "high")
      return true;
   if(!qm_friday_close_enabled ||
      qm_friday_close_hour_broker != 21 ||
      MathAbs(qm_stress_reject_probability) > 0.000000000001)
      return true;
   if(strategy_prior_gap_count != 52 ||
      strategy_lower_index != 5 ||
      strategy_upper_index != 46 ||
      strategy_history_bars != 900 ||
      strategy_entry_grace_minutes != 180 ||
      strategy_atr_period_d1 != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.5) > 0.000000000001 ||
      strategy_max_hold_days != 7 ||
      strategy_max_spread_points != 50 ||
      strategy_deviation_points != 20)
      return true;
   return false;
  }

// -----------------------------------------------------------------------------
// Trade Entry.
// -----------------------------------------------------------------------------

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "GBP_WGAP_TAIL_FADE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_decision_bar || !g_attempt_recorded_now ||
      g_late_decision ||
      g_decision_week_key <= 0 ||
      g_decision_week_key != g_last_attempt_week_key ||
      !g_signal_valid || g_signal_direction == 0)
      return false;
   if(Strategy_OwnedPositionCount() > 0 ||
      !Strategy_SpreadAllowed())
      return false;

   const double atr_value =
      QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(atr_value <= 0.0 || !MathIsValidNumber(atr_value))
      return false;

   req.type = (g_signal_direction > 0) ? QM_BUY : QM_SELL;
   req.reason = (g_signal_direction > 0)
      ? "GBP_WGAP_LOWER_TAIL_BUY"
      : "GBP_WGAP_UPPER_TAIL_SELL";
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0 || !MathIsValidNumber(entry_price))
      return false;

   req.sl = QM_StopATRFromValue(_Symbol,
                                req.type,
                                entry_price,
                                atr_value,
                                strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0 || !MathIsValidNumber(req.sl))
      return false;
   if((req.type == QM_BUY && req.sl >= entry_price) ||
      (req.type == QM_SELL && req.sl <= entry_price))
      return false;
   return true;
  }

// -----------------------------------------------------------------------------
// Trade Management.
// -----------------------------------------------------------------------------

void Strategy_ManageOpenPosition()
  {
   const int owned_count = Strategy_OwnedPositionCount();
   if(owned_count <= 0)
      return;
   if(owned_count != 1 || !Strategy_OwnedPositionStateValid())
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }

   const datetime now = TimeCurrent();
   const datetime opened = Strategy_CurrentEntryTime();
   const int current_week_key = Strategy_WeekKeyForTime(now);
   const int opened_week_key = Strategy_WeekKeyForTime(opened);
   if(now <= 0 || opened <= 0 || opened > now ||
      current_week_key <= 0 || opened_week_key <= 0)
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }

   // A later-week survivor is flattened before the new week's entry path.
   if(current_week_key != opened_week_key)
     {
      Strategy_CloseOwnedPositions(QM_EXIT_TIME_STOP);
      return;
     }
   const long hold_seconds =
      (long)strategy_max_hold_days * 86400L;
   if((long)(now - opened) >= hold_seconds)
      Strategy_CloseOwnedPositions(QM_EXIT_TIME_STOP);
  }

// -----------------------------------------------------------------------------
// Trade Close and news hooks.
// -----------------------------------------------------------------------------

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // The approved baseline locks both news axes and the legacy axis OFF.
   // Keep the hook callable for P8; the central entry-only gate remains wired.
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!SymbolSelect(g_symbol, true) ||
      !Strategy_IsHostChart() || qm_ea_id != 41253 ||
      qm_magic_slot_offset != 0)
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
         "Approved GBPUSD weekend-tail card requires the framework Friday close"))
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }
   if(Strategy_NoTradeFilter())
     {
      QM_FrameworkShutdown();
      return INIT_PARAMETERS_INCORRECT;
     }

   g_attempt_state_key =
      StringFormat("QM5_41253_WEEK_ATTEMPT_%d", QM_FrameworkMagic());
   Strategy_LoadAttemptState(TimeCurrent());

   string warmup_symbols[1];
   warmup_symbols[0] = g_symbol;
   QM_SymbolGuardInit(warmup_symbols);
   QM_BasketWarmupHistory(warmup_symbols,
                          PERIOD_D1,
                          strategy_history_bars);

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_41253\",\"ea\":\"gbpusd-weekend-tail-fade\"}");
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

   // QM_IsNewBar is consumed exactly once. A genuine Monday is persisted
   // immediately, before every fallible strategy-specific gate.
   const bool new_bar = QM_IsNewBar();
   Strategy_ResetDecisionState();
   if(new_bar)
      Strategy_CaptureMondayAttempt_OnNewBar(broker_now);

   // Risk management and later-week repair stay live through entry filters.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }

   if(Strategy_NoTradeFilter())
      return;
   if(!new_bar)
      return;

   QM_EquityStreamOnNewBar();
   if(!g_decision_bar || !g_attempt_recorded_now)
      return;
   Strategy_PrepareDecisionSignal(broker_now);

   // Attempt persistence and lifecycle handling precede entry-only news.
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
      news_allows =
         QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
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
