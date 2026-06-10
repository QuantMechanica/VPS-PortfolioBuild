#property strict
#property version   "5.0"
#property description "QM5_9161 Alpha Architect Equal-Weight Core 6 with 12-Month MA"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9161 aa-ew6-ma12
// Source: Alpha Architect — Wesley Gray, "Tactical Asset Allocation Part 3", 2012-11-25
// Card: QM5_9161_aa-ew6-ma12.md
//
// Monthly trend rule: go long if the last completed month-end D1 close is above
// its 252-bar SMA (12-month proxy; MN1 untestable in MT5 tester).  Flat otherwise.
// Catastrophic ATR(20,D1) × 3 stop per active sleeve.
// Rebalance gate: signal evaluated once per calendar month.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9161;
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
input int    strategy_sma_period        = 252;   // 12-month SMA proxy: 252 D1 bars ≈ 12 months
input int    strategy_atr_period        = 20;    // ATR period for catastrophic stop
input double strategy_atr_stop_mult     = 3.0;   // Catastrophic ATR multiplier

// ---------------------------------------------------------------------------
// File-scope monthly signal state
// ---------------------------------------------------------------------------

// Unique monthly counter (year*12 + month) for the last evaluated bar[1] month.
// Prevents re-evaluation on the same calendar month.
int  g_last_advance_month = -1;
int  g_monthly_signal     = -1;  // -1=uninitialized, 0=flat, 1=long

// Advance the monthly signal state. Idempotent for the same calendar month.
// Reads last-completed-D1-bar close (shift=1) vs SMA(strategy_sma_period, shift=1).
// Called from both ExitSignal and EntrySignal — only the first call per new
// D1-bar-month is effective; subsequent calls are no-ops.
bool AdvanceMonthlySignalIfNeeded()
  {
   const datetime t0 = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: month-boundary detection
   if(t0 <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(t0, dt);
   const int month_id = dt.year * 12 + dt.mon;

   if(month_id == g_last_advance_month)
      return false;  // same month already evaluated

   const double close1 = iClose(_Symbol, PERIOD_D1, 1);  // perf-allowed: month-boundary detection
   const double sma252 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1);

   if(close1 <= 0.0 || sma252 <= 0.0)
      return false;

   g_monthly_signal = (close1 > sma252) ? 1 : 0;
   g_last_advance_month = month_id;
   return true;
  }

bool HasOurPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   return QM_TM_OpenPositionCount(magic) > 0;
  }

// ---------------------------------------------------------------------------
// Strategy hooks
// ---------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type          = QM_BUY;
   req.price         = 0.0;
   req.sl            = 0.0;
   req.tp            = 0.0;
   req.reason        = "";
   req.symbol_slot   = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   AdvanceMonthlySignalIfNeeded();

   if(g_monthly_signal != 1)
      return false;

   if(HasOurPosition())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   const double sl_price = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_atr_stop_mult);
   if(sl_price <= 0.0 || sl_price >= ask)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;
   req.sl     = sl_price;
   req.tp     = 0.0;
   req.reason = "AA_EW6_MA12_LONG";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies catastrophic stop only (set at entry); no trailing.
  }

bool Strategy_ExitSignal()
  {
   static datetime s_last_exit_bar = 0;
   static bool     s_cached_exit   = false;

   if(!HasOurPosition())
     {
      s_cached_exit = false;
      return false;
     }

   const datetime t0 = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: month-boundary detection
   if(t0 <= 0)
      return false;

   if(t0 == s_last_exit_bar)
      return s_cached_exit;

   s_last_exit_bar = t0;
   s_cached_exit   = false;

   AdvanceMonthlySignalIfNeeded();

   if(g_monthly_signal == 0)
     {
      s_cached_exit = true;
      return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// ---------------------------------------------------------------------------
// Framework wiring
// ---------------------------------------------------------------------------

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
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

   QM_EntryRequest req;
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
