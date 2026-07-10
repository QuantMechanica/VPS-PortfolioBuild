#property strict
#property version   "5.0"
#property description "QM5_13114 WTI monthly ROC-14 extreme-crossing reversal"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13114 - WTI 14-Month ROC Extreme-Crossing Reversal
// -----------------------------------------------------------------------------
// Source state:
//   - reconstruct completed WTI month-end closes from D1 history
//   - 14-month ROC crossing outward through +40% establishes a short state
//   - 14-month ROC crossing outward through -40% establishes a long state
//   - retain the latest non-zero state until the opposite extreme crossing
// V5 expression: one non-overlapping fixed-risk package per active-state month.
// Runtime is Darwinex-native only: MT5 OHLC, ATR, spread, calendar, positions.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 13114;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours       = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = false;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_roc_months            = 14;
input double strategy_extreme_pct           = 40.0;
input int    strategy_state_history_months  = 360;
input int    strategy_atr_period            = 20;
input double strategy_atr_sl_mult           = 4.0;
input int    strategy_max_hold_days         = 35;
input int    strategy_max_spread_points     = 1500;

bool   g_monthly_rebalance_bar = false;
bool   g_cache_signal_valid = false;
int    g_cache_month_key = 0;
int    g_cache_target_state = 0;
double g_cache_latest_roc = 0.0;
double g_cache_prior_roc = 0.0;
int    g_last_entry_month_key = 0;
int    g_candidate_month_key = 0;

bool Strategy_IsHostChart()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

int Strategy_PositionState(const ulong ticket)
  {
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return 0;
   const long position_type = PositionGetInteger(POSITION_TYPE);
   if(position_type == POSITION_TYPE_BUY)
      return 1;
   if(position_type == POSITION_TYPE_SELL)
      return -1;
   return 0;
  }

bool Strategy_LoadTargetState(int &target_state,
                              double &latest_roc,
                              double &prior_roc)
  {
   target_state = 0;
   latest_roc = 0.0;
   prior_roc = 0.0;

   const int roc_months = strategy_roc_months;
   const int target_months = MathMax(strategy_state_history_months,
                                     roc_months + 2);
   const int scan_bars = target_months * 24 + 80;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // perf-allowed: one bounded D1 history copy on the first bar of each month;
   // the framework new-bar/calendar gates prevent per-tick recomputation.
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, scan_bars, rates); // perf-allowed: monthly-only bounded structural history reconstruction.
   if(copied <= 0)
      return false;

   double month_closes[];
   ArrayResize(month_closes, target_months);
   int collected = 0;
   int last_month_key = 0;

   for(int i = 0; i < copied && collected < target_months; ++i)
     {
      MqlDateTime d;
      TimeToStruct(rates[i].time, d);
      const int month_key = d.year * 100 + d.mon;
      if(month_key <= 0 || month_key == last_month_key)
         continue;
      if(rates[i].close <= 0.0 || !MathIsValidNumber(rates[i].close))
         return false;

      month_closes[collected] = rates[i].close;
      ++collected;
      last_month_key = month_key;
     }

   if(collected < roc_months + 2)
      return false;

   const double threshold = strategy_extreme_pct / 100.0;
   if(threshold <= 0.0)
      return false;

   for(int i = collected - roc_months - 2; i >= 0; --i)
     {
      const double current_base = month_closes[i + roc_months];
      const double previous_base = month_closes[i + roc_months + 1];
      if(current_base <= 0.0 || previous_base <= 0.0)
         return false;

      const double roc_now = month_closes[i] / current_base - 1.0;
      const double roc_before = month_closes[i + 1] / previous_base - 1.0;
      if(!MathIsValidNumber(roc_now) || !MathIsValidNumber(roc_before))
         return false;

      if(roc_before < threshold && roc_now >= threshold)
         target_state = -1;
      else if(roc_before > -threshold && roc_now <= -threshold)
         target_state = 1;
     }

   const double latest_base = month_closes[roc_months];
   const double prior_base = month_closes[roc_months + 1];
   if(latest_base <= 0.0 || prior_base <= 0.0)
      return false;
   latest_roc = month_closes[0] / latest_base - 1.0;
   prior_roc = month_closes[1] / prior_base - 1.0;
   return MathIsValidNumber(latest_roc) && MathIsValidNumber(prior_roc);
  }

void Strategy_AdvanceSignal_OnNewBar()
  {
   g_monthly_rebalance_bar = false;
   g_cache_signal_valid = false;
   g_cache_month_key = 0;
   g_cache_target_state = 0;
   g_cache_latest_roc = 0.0;
   g_cache_prior_roc = 0.0;

   const int current_month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const int prior_month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1);
   if(current_month_key <= 0 || prior_month_key <= 0 ||
      current_month_key == prior_month_key)
      return;

   g_monthly_rebalance_bar = true;
   g_cache_month_key = current_month_key;
   g_cache_signal_valid = Strategy_LoadTargetState(g_cache_target_state,
                                                    g_cache_latest_roc,
                                                    g_cache_prior_roc);
  }

bool Strategy_MaxHoldExceeded(const ulong ticket)
  {
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return false;
   const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
   if(opened_at <= 0)
      return false;
   const long max_hold_seconds = (long)MathMax(1, strategy_max_hold_days) * 86400;
   return ((long)(TimeCurrent() - opened_at) >= max_hold_seconds);
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_roc_months != 14)
      return true;
   if(MathAbs(strategy_extreme_pct - 40.0) > 0.000001)
      return true;
   if(strategy_state_history_months < 240 || strategy_state_history_months > 360)
      return true;
   if(strategy_atr_period <= 1 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_days != 35)
      return true;
   if(strategy_max_spread_points < 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_13114_WTI_ROC14_XTRM";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   g_candidate_month_key = 0;

   if(!g_monthly_rebalance_bar || !g_cache_signal_valid)
      return false;
   if(g_cache_month_key <= 0 || g_cache_month_key == g_last_entry_month_key)
      return false;
   if(g_cache_target_state == 0 || Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   const double atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_last <= 0.0 || !MathIsValidNumber(atr_last))
      return false;

   req.type = (g_cache_target_state > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0 || !MathIsValidNumber(entry_price))
      return false;

   req.sl = QM_StopATRFromValue(_Symbol,
                                req.type,
                                entry_price,
                                atr_last,
                                strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry_price)
      return false;
   if(req.type == QM_SELL && req.sl <= entry_price)
      return false;

   req.reason = (g_cache_target_state > 0) ? "WTI_ROC14_EXTREME_LONG" :
                                             "WTI_ROC14_EXTREME_SHORT";
   g_candidate_month_key = g_cache_month_key;
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
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(g_monthly_rebalance_bar)
        {
         const int position_state = Strategy_PositionState(ticket);
         const QM_ExitReason reason =
            (g_cache_signal_valid && g_cache_target_state != 0 &&
             position_state != g_cache_target_state)
            ? QM_EXIT_OPPOSITE_SIGNAL
            : QM_EXIT_TIME_STOP;
         QM_TM_ClosePosition(ticket, reason);
         continue;
        }

      if(Strategy_MaxHoldExceeded(ticket))
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13114\",\"ea\":\"wti-roc14-xtrm\"}");
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

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   const bool new_bar = QM_IsNewBar();
   g_monthly_rebalance_bar = false;
   if(new_bar)
      Strategy_AdvanceSignal_OnNewBar();

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
   if(!news_allows || Strategy_NewsFilterHook(broker_now))
      return;
   if(!new_bar)
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      if(QM_TM_OpenPosition(req, out_ticket) && out_ticket > 0)
         g_last_entry_month_key = g_candidate_month_key;
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
