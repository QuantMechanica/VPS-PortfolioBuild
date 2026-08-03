#property strict
#property version   "5.0"
#property description "QM5_20162 XNG Winter Dual-Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_20162 - XNG Winter Dual-Trend
// -----------------------------------------------------------------------------
// D1 structural natural-gas sleeve:
//   - long only during broker-calendar November through March
//   - completed close > SMA(21) > SMA(84)
//   - both SMAs above their values five completed D1 bars earlier
//   - one restart-safe consumed attempt per broker D1 bar
//   - frozen 3.5 * ATR(20) hard stop, trend/season/stale exits
//   - framework Friday close retained at 21:00 broker time
// Runtime uses native MT5 OHLC/calendar/history only; no external data or ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 20162;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

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
input int    strategy_fast_period          = 21;
input int    strategy_slow_period          = 84;
input int    strategy_slope_bars           = 5;
input int    strategy_atr_period            = 20;
input double strategy_atr_sl_mult           = 3.5;
input int    strategy_max_hold_days         = 35;
input int    strategy_max_spread_points     = 1000;

datetime g_last_attempt_bar_time = 0;
string   g_attempt_state_key     = "";

// -----------------------------------------------------------------------------
// Strategy state helpers.
// -----------------------------------------------------------------------------

bool Strategy_IsXngD1()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_D1);
  }

bool Strategy_IsWinterMonth(const int month)
  {
   return (month == 11 || month == 12 ||
           month == 1 || month == 2 || month == 3);
  }

int Strategy_MonthForTime(const datetime value)
  {
   if(value <= 0)
      return 0;

   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts))
      return 0;
   return parts.mon;
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

bool Strategy_GetTrendState(double &close_last,
                            double &fast_now,
                            double &slow_now,
                            double &fast_prior,
                            double &slow_prior)
  {
   close_last = 0.0;
   fast_now = 0.0;
   slow_now = 0.0;
   fast_prior = 0.0;
   slow_prior = 0.0;

   MqlRates completed_bar;
   ZeroMemory(completed_bar);
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, completed_bar))
      return false;

   close_last = completed_bar.close;
   fast_now = QM_SMA(_Symbol,
                     PERIOD_D1,
                     strategy_fast_period,
                     1,
                     PRICE_CLOSE);
   slow_now = QM_SMA(_Symbol,
                     PERIOD_D1,
                     strategy_slow_period,
                     1,
                     PRICE_CLOSE);
   const int prior_shift = 1 + strategy_slope_bars;
   fast_prior = QM_SMA(_Symbol,
                       PERIOD_D1,
                       strategy_fast_period,
                       prior_shift,
                       PRICE_CLOSE);
   slow_prior = QM_SMA(_Symbol,
                       PERIOD_D1,
                       strategy_slow_period,
                       prior_shift,
                       PRICE_CLOSE);

   return (close_last > 0.0 &&
           fast_now > 0.0 &&
           slow_now > 0.0 &&
           fast_prior > 0.0 &&
           slow_prior > 0.0 &&
           MathIsValidNumber(close_last) &&
           MathIsValidNumber(fast_now) &&
           MathIsValidNumber(slow_now) &&
           MathIsValidNumber(fast_prior) &&
           MathIsValidNumber(slow_prior));
  }

bool Strategy_TrendIsLong(const double close_last,
                          const double fast_now,
                          const double slow_now,
                          const double fast_prior,
                          const double slow_prior)
  {
   return (close_last > fast_now &&
           fast_now > slow_now &&
           fast_now > fast_prior &&
           slow_now > slow_prior);
  }

// -----------------------------------------------------------------------------
// Restart-safe one-attempt-per-D1-bar state.
// -----------------------------------------------------------------------------

void Strategy_LoadAttemptState(const datetime current_bar_time)
  {
   g_last_attempt_bar_time = 0;
   if(g_attempt_state_key == "" ||
      !GlobalVariableCheck(g_attempt_state_key))
      return;

   const double stored = GlobalVariableGet(g_attempt_state_key);
   const datetime stored_bar_time =
      (datetime)MathRound(stored);
   if(current_bar_time > 0 &&
      MathIsValidNumber(stored) &&
      stored_bar_time > 0 &&
      stored_bar_time <= current_bar_time)
     {
      g_last_attempt_bar_time = stored_bar_time;
      return;
     }

   // Tester agents can retain terminal globals from a later historical run.
   // A future marker must not suppress an earlier deterministic replay.
   GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordBarAttempt(const datetime bar_time)
  {
   if(bar_time <= 0 || g_attempt_state_key == "")
      return false;

   // Keep this process fail-closed even if terminal-global persistence fails.
   g_last_attempt_bar_time = bar_time;
   return (GlobalVariableSet(g_attempt_state_key,
                             (double)bar_time) > 0);
  }

bool Strategy_BarAlreadyEntered(const datetime bar_time)
  {
   if(bar_time <= 0 || Strategy_HasOpenPosition())
      return true;
   if(!HistorySelect(bar_time, TimeCurrent()))
      return true;

   const int magic = QM_FrameworkMagic();
   for(int index = HistoryDealsTotal() - 1; index >= 0; --index)
     {
      const ulong deal_ticket = HistoryDealGetTicket(index);
      if(deal_ticket == 0)
         continue;
      if((int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket,
                                                DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN &&
         entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_time =
         (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      if(deal_time >= bar_time)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXngD1())
      return true;
   if(qm_ea_id != 20162 || qm_magic_slot_offset != 0)
      return true;
   if(strategy_fast_period != 21 ||
      strategy_slow_period != 84 ||
      strategy_slope_bars != 5 ||
      strategy_atr_period != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.5) > 1.0e-12 ||
      strategy_max_hold_days != 35 ||
      strategy_max_spread_points != 1000)
      return true;
   if(!qm_friday_close_enabled ||
      qm_friday_close_hour_broker != 21)
      return true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE ||
      qm_news_mode_legacy != QM_NEWS_OFF)
      return true;
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(!Strategy_HasOpenPosition())
      return;

   MqlRates current_bar;
   ZeroMemory(current_bar);
   const bool current_bar_valid =
      QM_ReadBar(_Symbol, PERIOD_D1, 0, current_bar);

   double close_last = 0.0;
   double fast_now = 0.0;
   double slow_now = 0.0;
   double fast_prior = 0.0;
   double slow_prior = 0.0;
   const bool trend_available =
      Strategy_GetTrendState(close_last,
                             fast_now,
                             slow_now,
                             fast_prior,
                             slow_prior);
   const bool valid_state =
      current_bar_valid &&
      Strategy_IsWinterMonth(Strategy_MonthForTime(current_bar.time)) &&
      trend_available &&
      Strategy_TrendIsLong(close_last,
                           fast_now,
                           slow_now,
                           fast_prior,
                           slow_prior);

   const datetime now = TimeCurrent();
   const long hold_seconds =
      (long)MathMax(1, strategy_max_hold_days) * 86400;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsManagedPosition())
         continue;

      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      const bool wrong_side =
         ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) !=
            POSITION_TYPE_BUY);
      const bool stale =
         (opened <= 0 || opened > now ||
          (long)(now - opened) >= hold_seconds);
      if(wrong_side || !valid_state || stale)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "XNG_WINTER_DUALTREND";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   MqlRates current_bar;
   ZeroMemory(current_bar);
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 0, current_bar) ||
      current_bar.time <= 0 ||
      current_bar.time == g_last_attempt_bar_time)
      return false;

   // Consume before position, season, history, signal, spread, quote, news,
   // stop, or order gates. A blocked/rejected bar cannot retry after restart.
   if(!Strategy_RecordBarAttempt(current_bar.time))
      return false;

   if(Strategy_BarAlreadyEntered(current_bar.time))
      return false;
   if(!Strategy_IsWinterMonth(Strategy_MonthForTime(current_bar.time)))
      return false;

   double close_last = 0.0;
   double fast_now = 0.0;
   double slow_now = 0.0;
   double fast_prior = 0.0;
   double slow_prior = 0.0;
   if(!Strategy_GetTrendState(close_last,
                              fast_now,
                              slow_now,
                              fast_prior,
                              slow_prior) ||
      !Strategy_TrendIsLong(close_last,
                            fast_now,
                            slow_now,
                            fast_prior,
                            slow_prior))
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
   if(atr_last <= 0.0 || !MathIsValidNumber(atr_last))
      return false;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0 || !MathIsValidNumber(entry_price))
      return false;

   req.sl = QM_StopATRFromValue(_Symbol,
                                req.type,
                                entry_price,
                                atr_last,
                                strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0 ||
      !MathIsValidNumber(req.sl) ||
      req.sl >= entry_price)
      return false;
   return true;
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
// Framework wiring.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!Strategy_IsXngD1() ||
      qm_ea_id != 20162 ||
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
         "Approved winter D1 card retains Friday 21 broker-time flattening"))
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
      StringFormat("QM5_20162_D1_ATTEMPT_%d",
                   QM_FrameworkMagic());
   MqlRates current_bar;
   ZeroMemory(current_bar);
   const datetime current_bar_time =
      QM_ReadBar(_Symbol, PERIOD_D1, 0, current_bar)
         ? current_bar.time
         : 0;
   Strategy_LoadAttemptState(current_bar_time);

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_20162\",\"ea\":\"xng-winter-dualtrend\"}");
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
   // Q08 evidence lifecycle: sample floating P&L before per-tick guards.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   // Lifecycle exits run on every tick and before entry-only news handling.
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

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
   if(!Strategy_EntrySignal(req))
      return;

   // EntrySignal consumes the bar before this entry-only gate. Both axes are
   // frozen OFF, but the lifecycle ordering stays deterministic.
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
