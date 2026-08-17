#property strict
#property version   "5.0"
#property description "QM5_21503 WTI Exact-Week Low-Volatility Momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_21503 - WTI Exact-Week Low-Volatility Momentum
// -----------------------------------------------------------------------------
// Structural D1 crude-oil sleeve:
//   - require one exact completed Monday-through-Friday broker week
//   - follow its five-return sign only in a fixed low-realized-volatility tail
//   - rank against forty older non-overlapping five-return blocks
//   - consume one exact-Monday attempt before every fallible entry gate
//   - flatten through the framework Friday-close contract
//   - repair malformed or stale carry behind one frozen ATR hard stop
// Native MT5 calendar/OHLC/history only; no external runtime data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 21503;
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
input int    strategy_entry_grace_minutes = 180;
input int    strategy_baseline_blocks      = 40;
input int    strategy_rank_max_count       = 13;
input int    strategy_atr_period           = 20;
input double strategy_atr_sl_mult          = 3.0;
input int    strategy_max_hold_days        = 8;
input int    strategy_max_spread_points    = 1500;

int      g_last_attempt_date_key = 0;
string   g_attempt_state_key     = "";
bool     g_strategy_new_d1_bar   = false;
datetime g_strategy_d1_bar_time  = 0;

// -----------------------------------------------------------------------------
// Strategy hooks - mechanically frozen from the approved card.
// -----------------------------------------------------------------------------

bool Strategy_IsWtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_DateKey(const datetime value)
  {
   if(value <= 0)
      return 0;

   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts))
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

bool Strategy_IsMonday(const datetime value)
  {
   return (Strategy_DayOfWeek(value) == 1);
  }

int Strategy_WeekStartKey(const datetime value)
  {
   if(value <= 0)
      return 0;

   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts))
      return 0;
   const int day_offset =
      (parts.day_of_week == 0) ? 6 : parts.day_of_week - 1;
   parts.hour = 12;
   parts.min = 0;
   parts.sec = 0;
   const datetime day_anchor = StructToTime(parts);
   if(day_anchor <= 0)
      return 0;
   return Strategy_DateKey(day_anchor - (long)day_offset * 86400);
  }

bool Strategy_EntryWithinGrace(const datetime current_bar)
  {
   if(current_bar <= 0)
      return false;
   const datetime now = TimeCurrent();
   if(now < current_bar)
      return false;
   const long elapsed = (long)(now - current_bar);
   // Factory energy D1 bars may be labelled with the preceding calendar
   // date. Modulo one day measures time since the executable session open for
   // either that convention or a native same-day label.
   const long session_elapsed = elapsed % 86400L;
   return (session_elapsed <=
           (long)strategy_entry_grace_minutes * 60);
  }

bool Strategy_IsManagedPosition()
  {
   return (PositionGetString(POSITION_SYMBOL) == _Symbol &&
           (int)PositionGetInteger(POSITION_MAGIC) ==
              QM_FrameworkMagic());
  }

bool Strategy_HasOpenPosition()
  {
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsManagedPosition())
         return true;
     }
   return false;
  }

int Strategy_ManagedPositionCount()
  {
   int count = 0;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsManagedPosition())
         ++count;
     }
   return count;
  }

bool Strategy_DateAlreadyEntered(const int date_key,
                                 const datetime current_bar)
  {
   if(date_key <= 0 || current_bar <= 0)
      return true;
   if(Strategy_HasOpenPosition())
      return true;

   const datetime history_start =
      current_bar - (long)10 * 86400;
   if(history_start <= 0 ||
      !HistorySelect(history_start, TimeCurrent()))
      return true;

   const int magic = QM_FrameworkMagic();
   for(int index = HistoryDealsTotal() - 1; index >= 0; --index)
     {
      const ulong deal_ticket = HistoryDealGetTicket(index);
      if(deal_ticket == 0)
         continue;
      if((int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != magic)
         continue;
      if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket,
                                                DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN &&
         entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_time =
         (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      if(Strategy_DateKey(deal_time) == date_key)
         return true;
     }
   return false;
  }

void Strategy_LoadAttemptState(const datetime reference_time)
  {
   g_last_attempt_date_key = 0;
   if(g_attempt_state_key == "" ||
      !GlobalVariableCheck(g_attempt_state_key))
      return;

   const int current_date_key =
      Strategy_DateKey(reference_time);
   const double stored =
      GlobalVariableGet(g_attempt_state_key);
   const int stored_date_key =
      (int)MathRound(stored);
   if(current_date_key > 0 &&
      MathIsValidNumber(stored) &&
      stored_date_key >= 19000101 &&
      stored_date_key <= current_date_key)
     {
      g_last_attempt_date_key = stored_date_key;
      return;
     }

   // Tester globals can survive a later historical run. A future marker must
   // not suppress the beginning of a deterministic replay.
   GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordDateAttempt(const int date_key)
  {
   if(date_key <= 0 || g_attempt_state_key == "")
      return false;

   // Remain fail-closed in-process even when terminal persistence fails.
   g_last_attempt_date_key = date_key;
   return (GlobalVariableSet(g_attempt_state_key,
                             (double)date_key) > 0);
  }

bool Strategy_PrimeLateSignalAttach()
  {
   MqlRates current_bar;
   ZeroMemory(current_bar);
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 0, current_bar))
      return true;
   const datetime broker_now = TimeCurrent();
   if(!Strategy_IsMonday(broker_now) ||
      Strategy_EntryWithinGrace(current_bar.time))
      return true;

   // Consume the initialization edge and persist the missed Monday
   // decision. Attaching late may not create a same-week retry.
   QM_IsNewBar(_Symbol, PERIOD_D1);
   const int date_key =
      Strategy_DateKey(broker_now);
   if(date_key == g_last_attempt_date_key)
      return true;
   return Strategy_RecordDateAttempt(date_key);
  }

bool Strategy_LoadWeeklyLowVol(const datetime current_bar_time,
                               const datetime broker_now,
                               double &weekly_return,
                               double &current_rv,
                               int &rank_count,
                               int &direction)
  {
   weekly_return = 0.0;
   current_rv = 0.0;
   rank_count = 0;
   direction = 0;
   if(!Strategy_IsMonday(broker_now) ||
      current_bar_time <= 0 || broker_now < current_bar_time)
      return false;

   const long current_elapsed =
      (long)(broker_now - current_bar_time);
   const datetime label_offset =
      (current_elapsed >= 86400L && current_elapsed <= 172800L)
      ? (datetime)86400
      : (datetime)0;
   const datetime current_session_time =
      current_bar_time + label_offset;
   if(Strategy_DateKey(current_session_time) !=
      Strategy_DateKey(broker_now))
      return false;

   const int returns_per_week = 5;
   const int signal_closes = 6;
   const int bars_needed =
      signal_closes +
      strategy_baseline_blocks * returns_per_week;
   if(bars_needed != 206)
      return false;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied =
      CopyRates(_Symbol, PERIOD_D1, 1, bars_needed, bars); // perf-allowed: one bounded 206-bar completed-D1 vector on the Monday new-bar edge.
   if(copied != bars_needed)
      return false;

   datetime normalized_times[];
   if(ArrayResize(normalized_times, bars_needed) != bars_needed)
      return false;

   for(int index = 0; index < bars_needed; ++index)
     {
      if(bars[index].time <= 0 ||
         bars[index].close <= 0.0 ||
         !MathIsValidNumber(bars[index].close))
         return false;

      normalized_times[index] =
         bars[index].time + label_offset;
      if(Strategy_DateKey(normalized_times[index]) <= 0)
         return false;

      if(index > 0)
        {
         if(bars[index - 1].time <= bars[index].time)
            return false;
         if(Strategy_DateKey(normalized_times[index - 1]) ==
            Strategy_DateKey(normalized_times[index]))
            return false;
        }
     }

   // Newest first, the six signal closes must be prior Friday through the
   // preceding Friday anchor at exact broker-calendar offsets.
   const int expected_days[6] = {5, 4, 3, 2, 1, 5};
   const int expected_offsets[6] = {3, 4, 5, 6, 7, 10};
   for(int index = 0; index < signal_closes; ++index)
     {
      const datetime expected_time =
         (datetime)(current_session_time -
                    (long)expected_offsets[index] * 86400);
      if(Strategy_DayOfWeek(normalized_times[index]) !=
            expected_days[index] ||
         Strategy_DateKey(normalized_times[index]) !=
            Strategy_DateKey(expected_time))
         return false;
     }

   double current_variance_sum = 0.0;
   for(int k = 0; k < returns_per_week; ++k)
     {
      const int newer_index = 4 - k;
      const int older_index = newer_index + 1;
      const double daily_return =
         MathLog(bars[newer_index].close /
                 bars[older_index].close);
      if(!MathIsValidNumber(daily_return))
         return false;
      weekly_return += daily_return;
      current_variance_sum += daily_return * daily_return;
     }

   const double endpoint_return =
      MathLog(bars[0].close / bars[5].close);
   if(!MathIsValidNumber(weekly_return) ||
      !MathIsValidNumber(endpoint_return) ||
      !MathIsValidNumber(current_variance_sum) ||
      MathAbs(weekly_return - endpoint_return) > 1.0e-10)
      return false;

   current_rv = MathSqrt(current_variance_sum);
   if(current_rv <= 0.0 ||
      !MathIsValidNumber(current_rv))
      return false;

   for(int block = 0;
       block < strategy_baseline_blocks;
       ++block)
     {
      double baseline_variance_sum = 0.0;
      for(int k = 0; k < returns_per_week; ++k)
        {
         const int newer_index =
            5 + block * returns_per_week + k;
         const int older_index = newer_index + 1;
         const double baseline_return =
            MathLog(bars[newer_index].close /
                    bars[older_index].close);
         if(!MathIsValidNumber(baseline_return))
            return false;
         baseline_variance_sum +=
            baseline_return * baseline_return;
        }

      const double baseline_rv =
         MathSqrt(baseline_variance_sum);
      if(baseline_rv < 0.0 ||
         !MathIsValidNumber(baseline_rv))
         return false;
      if(baseline_rv <= current_rv)
         ++rank_count;
     }

   if(rank_count <= strategy_rank_max_count)
     {
      if(weekly_return > 0.0)
         direction = 1;
      else if(weekly_return < 0.0)
         direction = -1;
     }
   return true;
  }

bool Strategy_PositionDirectionIsValid(const datetime opened,
                                       const long position_type)
  {
   return (opened > 0 &&
           Strategy_DayOfWeek(opened) == 1 &&
           (position_type == POSITION_TYPE_BUY ||
            position_type == POSITION_TYPE_SELL));
  }

void Strategy_CloseExpiredPositions()
  {
   const datetime now = TimeCurrent();
   const long hold_seconds =
      (long)MathMax(1, strategy_max_hold_days) * 86400;
   const int owned_count = Strategy_ManagedPositionCount();
   const int current_week_key = Strategy_WeekStartKey(now);

   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsManagedPosition())
         continue;

      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      const long position_type =
         PositionGetInteger(POSITION_TYPE);
      const double volume =
         PositionGetDouble(POSITION_VOLUME);
      const double open_price =
         PositionGetDouble(POSITION_PRICE_OPEN);
      const double stop_price =
         PositionGetDouble(POSITION_SL);
      const int opened_week_key =
         Strategy_WeekStartKey(opened);
      bool should_close =
         (owned_count != 1 ||
          opened <= 0 || opened > now ||
          !Strategy_PositionDirectionIsValid(opened,
                                             position_type) ||
          volume <= 0.0 || !MathIsValidNumber(volume) ||
          open_price <= 0.0 || !MathIsValidNumber(open_price) ||
          stop_price <= 0.0 || !MathIsValidNumber(stop_price) ||
          opened_week_key <= 0 || current_week_key <= 0);

      // Friday close is the ordinary framework path. If it was unavailable,
      // repair on the first observable tick assigned to a later broker week.
      if(!should_close &&
         now > opened &&
         current_week_key != opened_week_key)
         should_close = true;

      if(!should_close &&
         now >= opened &&
         (long)(now - opened) >= hold_seconds)
         should_close = true;

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsWtiD1())
      return true;
   if(qm_ea_id != 21503 ||
      qm_magic_slot_offset != 0)
      return true;
   if(MathAbs(RISK_PERCENT) > 1.0e-12 ||
      MathAbs(RISK_FIXED - 1000.0) > 1.0e-12 ||
      MathAbs(PORTFOLIO_WEIGHT - 1.0) > 1.0e-12)
      return true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE ||
      qm_news_mode_legacy != QM_NEWS_OFF ||
      qm_news_stale_max_hours != 336 ||
      qm_news_min_impact != "high")
      return true;
   if(!qm_friday_close_enabled ||
      qm_friday_close_hour_broker != 21)
      return true;
   if(strategy_entry_grace_minutes != 180 ||
      strategy_baseline_blocks != 40 ||
      strategy_rank_max_count != 13 ||
      strategy_atr_period != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.0) > 1.0e-12)
      return true;
   if(strategy_max_hold_days != 8 ||
      strategy_max_spread_points != 1500)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "WTI_WEEK_LOWRV_MOM";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime broker_now = TimeCurrent();
   if(!g_strategy_new_d1_bar ||
      g_strategy_d1_bar_time <= 0 ||
      !Strategy_IsMonday(broker_now))
      return false;

   const int date_key =
      Strategy_DateKey(broker_now);
   if(date_key <= 0 ||
      date_key == g_last_attempt_date_key)
      return false;

   // Consume before history, signal, spread, quote, news, stop, sizing, or
   // order gates. A blocked Monday attempt cannot retry after restart.
   if(!Strategy_RecordDateAttempt(date_key))
      return false;

   if(!Strategy_EntryWithinGrace(g_strategy_d1_bar_time))
      return false;

   if(Strategy_DateAlreadyEntered(date_key,
                                  broker_now))
      return false;

   double weekly_return = 0.0;
   double current_rv = 0.0;
   int rank_count = 0;
   int direction = 0;
   if(!Strategy_LoadWeeklyLowVol(g_strategy_d1_bar_time,
                                 broker_now,
                                 weekly_return,
                                 current_rv,
                                 rank_count,
                                 direction))
      return false;

   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"date\":%d,\"weekly_return\":%.12e,\"current_rv\":%.12e,\"rank_count\":%d,\"direction\":%d}",
                            date_key,
                            weekly_return,
                            current_rv,
                            rank_count,
                            direction));

   if(direction > 0)
     {
      req.type = QM_BUY;
      req.reason = "WTI_WEEK_LOWRV_MOM_LONG";
     }
   else if(direction < 0)
     {
      req.type = QM_SELL;
      req.reason = "WTI_WEEK_LOWRV_MOM_SHORT";
     }
   else
      return false;

   const long spread_points =
      SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_points < 0 ||
      spread_points > strategy_max_spread_points)
      return false;

   const double atr_last =
      QM_ATR(_Symbol,
             PERIOD_D1,
             strategy_atr_period,
             1);
   if(atr_last <= 0.0 ||
      !MathIsValidNumber(atr_last))
      return false;

   const double entry_price =
      QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0 ||
      !MathIsValidNumber(entry_price))
      return false;

   req.sl = QM_StopATRFromValue(_Symbol,
                                req.type,
                                entry_price,
                                atr_last,
                                strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0 ||
      !MathIsValidNumber(req.sl))
      return false;
   if(req.type == QM_BUY && req.sl >= entry_price)
      return false;
   if(req.type == QM_SELL && req.sl <= entry_price)
      return false;

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseExpiredPositions();
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
// Framework wiring - canonical V5 lifecycle.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!SymbolSelect("XTIUSD.DWX", true) ||
      !Strategy_IsWtiD1() ||
      qm_ea_id != 21503 ||
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
         "Approved WTI exact-week low-vol card uses Friday 21 as ordinary exit"))
      return INIT_FAILED;

   if(Strategy_NoTradeFilter())
     {
      QM_FrameworkShutdown();
      return INIT_PARAMETERS_INCORRECT;
     }

   g_attempt_state_key =
      StringFormat("QM5_21503_WEEK_ATTEMPT_%d",
                   QM_FrameworkMagic());
   Strategy_LoadAttemptState(TimeCurrent());
   if(!Strategy_PrimeLateSignalAttach())
      return INIT_FAILED;

   string warmup_symbols[1];
   warmup_symbols[0] = "XTIUSD.DWX";
   QM_SymbolGuardInit(warmup_symbols);
   QM_BasketWarmupHistory(warmup_symbols,
                          PERIOD_D1,
                          256);

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_21503\",\"ea\":\"xti-weekly-tsmom-lowvol\",\"signal\":\"exact_week_lowvol_momentum\"}");
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
   if(!Strategy_IsWtiD1())
      return;

   g_strategy_new_d1_bar =
      QM_IsNewBar(_Symbol, PERIOD_D1);
   if(g_strategy_new_d1_bar ||
      g_strategy_d1_bar_time <= 0)
     {
      MqlRates current_bar;
      ZeroMemory(current_bar);
      if(QM_ReadBar(_Symbol, PERIOD_D1, 0, current_bar))
         g_strategy_d1_bar_time = current_bar.time;
      else if(g_strategy_new_d1_bar)
         g_strategy_d1_bar_time = 0;
     }

   if(g_strategy_new_d1_bar)
      QM_EquityStreamOnNewBar();

   // Lifecycle repairs precede all entry-only gates and run on every tick so
   // a rejected close remains retryable.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      for(int index = PositionsTotal() - 1; index >= 0; --index)
        {
         const ulong ticket = PositionGetTicket(index);
         if(ticket == 0 || !PositionSelectByTicket(ticket) ||
            !Strategy_IsManagedPosition())
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!g_strategy_new_d1_bar ||
      Strategy_NoTradeFilter())
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
   if(!Strategy_EntrySignal(req))
      return;

   // EntrySignal deliberately consumes the exact Monday before this entry-
   // only news gate. Both news axes are locked OFF in the baseline.
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
   QM_TM_OpenPosition(req, out_ticket);
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
