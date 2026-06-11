#property strict
#property version   "5.0"
#property description "QM5_1601 Alpha Architect Double-Sorted Time-Series Reversal (aa-tsrev-double)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1601 — aa-tsrev-double
// -----------------------------------------------------------------------------
// Monthly rebalance on D1 (MN1 is untestable in MT5 tester).
// Classifies each symbol as "realized winner" (old_ret>0 && recent_ret>0) or
// "contrarian loser" (old_ret<0 && recent_ret>0) and holds long.
// Source: Liu & Papailias via Alpha Architect / Swedroe 2023-04-07.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1601;
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
input int    strategy_old_ret_start_months    = 24;  // old block start: months ago
input int    strategy_old_ret_end_months      = 13;  // old block end: months ago
input int    strategy_recent_ret_start_months = 12;  // recent block start: months ago
input int    strategy_recent_ret_end_months   = 1;   // recent block end: months ago
input int    strategy_trading_days_per_month  = 21;  // D1-bar approximation per month
input double strategy_sl_atr_mult             = 3.0; // SL = N * ATR(period, D1)
input int    strategy_atr_period              = 20;  // ATR period for stop sizing

// File-scope cached state — updated once per month through QM_IsNewBar().
bool   g_qualified          = false; // symbol in realized-winner or contrarian-loser group
bool   g_exit_requested     = false; // set when symbol leaves qualifying group

// ---------------------------------------------------------------------------
// No intraday session filter — monthly strategy trades at any point during
// the first bar of a new month.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// ---------------------------------------------------------------------------
// Monthly rebalance: compute 24-month double-sorted classification on each
// new D1 bar that crosses a month boundary.  Uses fixed D1-bar offsets as a
// proxy for monthly closes (MN1 bars are untestable in MT5 tester).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!QM_IsNewBar(_Symbol, PERIOD_MN1))
      return false; // same month — no rebalance

   // Bar offsets for monthly close proxies (21 trading days per month).
   int bar_recent_end   = strategy_trading_days_per_month * strategy_recent_ret_end_months;   // ~21
   int bar_recent_start = strategy_trading_days_per_month * strategy_recent_ret_start_months; // ~252
   int bar_old_end      = strategy_trading_days_per_month * strategy_old_ret_end_months;      // ~273
   int bar_old_start    = strategy_trading_days_per_month * strategy_old_ret_start_months;    // ~504

   // Warmup guard: need at least old_start + buffer bars of D1 history.
   if(Bars(_Symbol, PERIOD_D1) < bar_old_start + 20) // perf-allowed: single Bars call, gated by QM_IsNewBar
     {
      g_qualified = false;
      g_exit_requested = true;
      return false;
     }

   // Read D1 close prices at the four lookback offsets.
   // perf-allowed: bespoke structural lookback with fixed shifts — no QM_* equivalent.
   double c_recent_end   = iClose(_Symbol, PERIOD_D1, bar_recent_end);   // perf-allowed
   double c_recent_start = iClose(_Symbol, PERIOD_D1, bar_recent_start); // perf-allowed
   double c_old_end      = iClose(_Symbol, PERIOD_D1, bar_old_end);      // perf-allowed
   double c_old_start    = iClose(_Symbol, PERIOD_D1, bar_old_start);    // perf-allowed

   if(c_recent_start <= 0.0 || c_old_start <= 0.0)
     {
      g_qualified = false;
      g_exit_requested = true;
      return false;
     }

   // old block: return from t-24 to t-13 months.
   double old_ret    = (c_old_end    - c_old_start)    / c_old_start;
   // recent block: return from t-12 to t-1 months.
   double recent_ret = (c_recent_end - c_recent_start) / c_recent_start;

   bool realized_winner  = (old_ret > 0.0 && recent_ret > 0.0);
   bool contrarian_loser = (old_ret < 0.0 && recent_ret > 0.0);
   g_qualified      = realized_winner || contrarian_loser;
   g_exit_requested = !g_qualified;

   if(!g_qualified)
      return false;

   // Only one position per magic: skip if already positioned.
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   // Build long entry with ATR-based stop loss.
   double atr_val = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_val <= 0.0)
      return false;

   double ask     = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl_dist = strategy_sl_atr_mult * atr_val;

   req.type               = QM_BUY;
   req.price              = 0.0;              // market order
   req.sl                 = ask - sl_dist;
   req.tp                 = 0.0;              // monthly exit replaces TP
   req.reason             = "tsrev-double";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   return true;
  }

// ---------------------------------------------------------------------------
// No intra-month trailing or BE logic — hold until monthly rebalance.
void Strategy_ManageOpenPosition()
  {
  }

// ---------------------------------------------------------------------------
// Close when monthly re-evaluation finds symbol outside qualifying groups.
bool Strategy_ExitSignal()
  {
   return g_exit_requested;
  }

// ---------------------------------------------------------------------------
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to framework 2-axis news check
  }

// ---------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line.
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

   QM_LogEvent(QM_INFO, "INIT_OK", StringFormat("{\"card\":\"ede348b4\",\"ea\":\"QM5_1601_aa-tsrev-double\",\"ea_id\":%d}", qm_ea_id));
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
      g_exit_requested = false;
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
