#property strict
#property version   "5.0"
#property description "QM5_20004 Turn-of-Month Equity-Index Long-Only Overlay"
// Strategy Card: QM5_20004_turn-of-month-index-long.md, G0 APPROVED 2026-07-17.
// Source: McConnell & Xu 2008 FAJ 64(2):49-64 (DOI 10.2469/faj.v64.n2.11);
// Lakonishok & Smidt 1988 RFS 1(4):403-425.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20004;
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
input int    strategy_exit_day_n           = 3;    // Card §timeframe/exit: flatten after N trading days of the new month.
input bool   strategy_trend_filter_enabled = true; // Card §entry: optional skip if the index closed the month below its SMA.
input int    strategy_trend_sma_period     = 50;   // Card §entry: "e.g. below its 50-day SMA".
input int    strategy_atr_period           = 20;   // Card §stop: protective SL at k*ATR(20).
input double strategy_sl_atr_mult          = 3.0;  // Card §stop: wide flow-trade stop (no numeric k given in the card -- see open_questions).

// -----------------------------------------------------------------------------
// Strategy state
// -----------------------------------------------------------------------------
// Trading-day-held counter since entry. Advanced via QM_CalendarPeriodKey(D1)
// comparisons against our own stored key (the framework-sanctioned
// once-per-period pattern) -- NEVER via QM_IsNewBar(), which is already
// single-consumed by OnTick's own entry gate below (DWX invariant #3).
int g_days_elapsed      = 0;
int g_last_seen_day_key = 0;

bool Strategy_NoTradeFilter()
  {
   return false; // Card: no session/day-of-week gate beyond the calendar entry itself.
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Card §entry/§timeframe: "on the last D1 bar of the month, open LONG".
   // Mechanically this is the QM_IsNewCalendarPeriod(MN1) edge: the D1 bar that
   // just opened is the new month's first trading day, i.e. the prior closed D1
   // bar WAS the last trading day of the old month. The framework fills market
   // orders at the current tick price (req.price=0.0), so the position opens at
   // the new month's first available price rather than the exact prior close --
   // the standard close-decision -> next-open-fill translation for a
   // bar-close-driven system (documented in SPEC.md / open_questions).
   if(!QM_IsNewCalendarPeriod(PERIOD_MN1))
      return false;

   if(strategy_trend_filter_enabled)
     {
      const double prior_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: last-month close read once at the monthly calendar edge above.
      const double sma50 = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_sma_period, 1);
      if(prior_close <= 0.0 || sma50 <= 0.0)
         return false;
      if(prior_close < sma50)
         return false; // Card §entry: skip a hard downtrend close.
     }

   const double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry_price <= 0.0)
      return false;

   req.type = QM_BUY; // Card §market_universe: long-only overlay.
   req.price = 0.0;
   req.sl = QM_StopATR(_Symbol, QM_BUY, entry_price, strategy_atr_period, strategy_sl_atr_mult); // Card §stop.
   req.tp = 0.0; // Card §exit: no fixed price target -- the edge is the calendar window.
   req.reason = "turn_of_month_index_long";

   g_days_elapsed = 0;
   g_last_seen_day_key = QM_CalendarPeriodKey(PERIOD_D1);
   return (req.sl > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   // Card §exit: advance the trading-day-held counter once per new D1 period
   // while a position is open. Uses QM_CalendarPeriodKey (a pure query, not a
   // single-consume latch) so it never competes with OnTick's own
   // QM_IsNewBar() consumption for the entry gate.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return;

   const int today_key = QM_CalendarPeriodKey(PERIOD_D1);
   if(today_key == 0)
      return;

   if(g_last_seen_day_key == 0)
     {
      g_last_seen_day_key = today_key; // restart-safety: position existed before an EA reload.
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
   // Card §exit: "flat at the close of the N-th trading day of the new month".
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;
   return (g_days_elapsed >= strategy_exit_day_n);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // Card §filters: framework news filter stays ON (flatten-before-news default ordering), no override requested.
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
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

   g_days_elapsed = 0;
   g_last_seen_day_key = 0;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_20004\",\"ea\":\"turn-of-month-index-long\"}");
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
