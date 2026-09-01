#property strict
#property version   "5.0"
#property description "QM5_41272 Turn-of-Month Equity-Index Long-Only Overlay (restart-safe)"
// Strategy Card: QM5_41272_turn-of-month-index-long-restart-r1.md, G0 APPROVED 2026-09-01.
// Faithful new-identity recovery of QM5_20004; authority task 2e0bc944-0f47-47e2-b6c2-e7b83db89147.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 41272;
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
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_exit_day_n           = 3;
input bool   strategy_trend_filter_enabled = true;
input int    strategy_trend_sma_period     = 50;
input int    strategy_atr_period           = 20;
input double strategy_sl_atr_mult          = 3.0;

// Completed D1 transitions since the owned position's actual open time.
int g_days_elapsed      = 0;
int g_last_seen_day_key = 0;

bool Strategy_RehydrateHeldDays()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return true;

   // The framework helper reads POSITION_TIME for the longest-held owned
   // position and reconstructs completed D1 transitions from actual bars.
   const int held_periods =
      QM_TM_HeldPeriodsForMagic(QM_FrameworkMagic(), _Symbol, PERIOD_D1);
   if(held_periods < 0)
      return false;

   g_days_elapsed = held_periods;
   g_last_seen_day_key = QM_CalendarPeriodKey(PERIOD_D1);
   return (g_last_seen_day_key != 0);
  }

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(!QM_IsNewCalendarPeriod(PERIOD_MN1))
      return false;

   if(strategy_trend_filter_enabled)
     {
      const double prior_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: one structural prior-close read on the monthly decision edge; faithful to reviewed QM5_20004.
      const double sma50 = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_sma_period, 1);
      if(prior_close <= 0.0 || sma50 <= 0.0 || prior_close < sma50)
         return false;
     }

   const double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry_price <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = QM_StopATR(_Symbol, QM_BUY, entry_price, strategy_atr_period, strategy_sl_atr_mult);
   req.tp = 0.0;
   req.reason = "turn_of_month_index_long";

   g_days_elapsed = 0;
   g_last_seen_day_key = QM_CalendarPeriodKey(PERIOD_D1);
   return (req.sl > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return;

   const int today_key = QM_CalendarPeriodKey(PERIOD_D1);
   if(today_key == 0)
      return;

   // OnInit must reconstruct inherited state from POSITION_TIME. This branch
   // is retained as a fail-closed repair path, never as a "position opened
   // today" assumption.
   if(g_last_seen_day_key == 0)
     {
      if(!Strategy_RehydrateHeldDays())
         return;
     }

   if(today_key != g_last_seen_day_key)
     {
      ++g_days_elapsed;
      g_last_seen_day_key = today_key;
     }
  }

bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;
   return (g_days_elapsed >= strategy_exit_day_n);
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

   g_days_elapsed = 0;
   g_last_seen_day_key = 0;
   if(!Strategy_RehydrateHeldDays())
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               StringFormat("{\"card\":\"QM5_41272\",\"ea\":\"turn-of-month-index-long-restart-r1\",\"days_elapsed\":%d}",
                            g_days_elapsed));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
        }
     }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;
   if(!QM_IsNewBar())
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
