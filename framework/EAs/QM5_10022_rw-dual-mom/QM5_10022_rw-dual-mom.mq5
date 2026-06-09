#property strict
#property version   "5.0"
#property description "QM5_10022 rw-dual-mom — Robot Wealth Dual Momentum Rotation (D1 monthly)"

#include <QM/QM_Common.mqh>

// ============================================================
// INPUT PARAMETERS
// ============================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 10022;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_formation_period    = 126;   // D1 bars for 6-month return (~6 months)
input int    strategy_max_held            = 3;     // max universe members held simultaneously
input int    strategy_atr_period          = 20;    // ATR period for catastrophic stop
input double strategy_atr_sl_mult         = 3.0;   // catastrophic SL = N * ATR(20,D1)

// ============================================================
// UNIVERSE — mirrors magic_numbers.csv slots 0..3 for QM5_10022
// ============================================================
string g_universe[4] = {"SP500.DWX", "NDX.DWX", "WS30.DWX", "XAUUSD.DWX"};
const int UNIVERSE_SIZE = 4;

// ============================================================
// FILE-SCOPE CACHED STATE
// Recomputed once per new calendar month inside QM_IsNewBar gate.
// Per-tick logic only reads g_is_selected — O(1), no cross-symbol reads.
// ============================================================
bool g_is_selected        = false;   // is _Symbol in the selected basket this month?
int  g_last_rebalance_mon = -1;      // calendar month of last rebalance (1-12; -1=never)
int  g_last_rebalance_yr  = -1;      // calendar year  of last rebalance

// ============================================================
// INTERNAL HELPERS
// ============================================================

// Returns true when the current broker timestamp belongs to a new calendar
// month relative to the last rebalance.  Called only inside QM_IsNewBar gate.
bool IsNewMonthBar()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.year != g_last_rebalance_yr || dt.mon != g_last_rebalance_mon);
  }

// Recomputes cross-symbol 6-month returns and updates g_is_selected.
// Called once per new calendar month — total 4 * 2 iClose reads, O(1) each.
// All raw series calls carry // perf-allowed because this is bespoke structural
// logic (cross-symbol 6-month return) that has no QM_Indicators equivalent.
void AdvanceState_OnNewMonth()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   g_last_rebalance_yr  = dt.year;
   g_last_rebalance_mon = dt.mon;

   const int fp = strategy_formation_period;
   double returns[4];
   bool   valid  [4];
   int    my_idx = -1;

   for(int i = 0; i < UNIVERSE_SIZE; i++)
     {
      returns[i] = -9999.0;
      valid[i]   = false;
      const string sym = g_universe[i];
      if(sym == _Symbol) my_idx = i;
      int nbars = Bars(sym, PERIOD_D1); // perf-allowed: single bar-count per symbol, monthly gate
      if(nbars < fp + 2) continue;
      double c_now = iClose(sym, PERIOD_D1, 1);  // perf-allowed: single-shift close read, monthly gate
      double c_ago = iClose(sym, PERIOD_D1, fp); // perf-allowed: single-shift close read, monthly gate
      if(c_now <= 0.0 || c_ago <= 0.0) continue;

      returns[i] = (c_now - c_ago) / c_ago;
      valid[i]   = true;
     }

   // Deselect when not in universe, data insufficient, or absolute momentum negative
   if(my_idx < 0 || !valid[my_idx] || returns[my_idx] <= 0.0)
     {
      const string reason = my_idx < 0 ? "not_in_universe"
                            : !valid[my_idx] ? "insufficient_bars"
                            : "neg_abs_mom";
      const double my_ret = (my_idx >= 0 && valid[my_idx]) ? returns[my_idx] : 0.0;
      g_is_selected = false;
      QM_LogEvent(QM_INFO, "REBALANCE",
                  StringFormat("{\"selected\":false,\"reason\":\"%s\",\"ret\":%.4f,\"month\":%d}",
                               reason, my_ret, dt.mon));
      return;
     }

   // Cross-sectional rank: number of valid universe members with strictly higher return
   int rank = 0;
   for(int i = 0; i < UNIVERSE_SIZE; i++)
     {
      if(i == my_idx) continue;
      if(valid[i] && returns[i] > returns[my_idx])
         rank++;
     }

   // Selected if rank is inside top-N AND absolute return is positive
   g_is_selected = (rank < strategy_max_held);
   QM_LogEvent(QM_INFO, "REBALANCE",
               StringFormat("{\"selected\":%s,\"rank\":%d,\"ret\":%.4f,\"max_held\":%d,\"month\":%d}",
                            g_is_selected ? "true" : "false",
                            rank, returns[my_idx], strategy_max_held, dt.mon));
  }

// ============================================================
// STRATEGY HOOKS — five required functions
// ============================================================

// No Trade Filter (time, spread, news)
// Monthly D1 rotation has no intra-month session or regime filter.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry
// Open a long when this symbol is monthly-selected and no position is held.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_is_selected)
      return false;

   // Framework duplicate guard (also in QM_Entry); early-exit avoids ATR compute
   if(QM_EntryHasOpenPosition((long)QM_FrameworkMagic(), _Symbol))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0) return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0) return false;

   req.type   = QM_BUY;
   req.price  = 0.0; // market order
   req.sl     = ask - atr * strategy_atr_sl_mult; // catastrophic SL; primary exit = monthly rotation
   req.tp     = 0.0; // no TP; exit at monthly rebalance
   req.reason = "rw-dual-mom-long";
   return true;
  }

// Trade Management
// Baseline uses only the catastrophic ATR SL set at entry; no intra-month management.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close
// Close when g_is_selected flipped to false at the last monthly rebalance.
// g_is_selected is updated in AdvanceState_OnNewMonth (QM_IsNewBar gate) so
// ExitSignal() reads a stable per-bar flag — no cross-symbol logic on the exit path.
bool Strategy_ExitSignal()
  {
   if(g_is_selected)
      return false; // still selected — keep position

   // Check if we actually hold a position before returning true
   const long magic = (long)QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      return true;
     }
   return false;
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade2 via framework
  }

// ============================================================
// FRAMEWORK WIRING
// ============================================================

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

   // Register the full universe so the symbol guard permits cross-symbol reads.
   // Without this, QM_FrameworkInit defaults to single-symbol guard and every
   // iClose/Bars call on a non-_Symbol emits SYMBOL_GUARD_VIOLATION.
   QM_SymbolGuardInit(g_universe);

   // Pre-load D1 history for all universe symbols so the MT5 tester has bar data
   // for the cross-symbol iClose calls in AdvanceState_OnNewMonth.
   // Without this, iClose returns 0 in the tester (QM5_10717 pattern) → no trades.
   QM_BasketWarmupHistory(g_universe, PERIOD_D1, strategy_formation_period + 10);

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

   // Per-tick: adjust open positions (no-op for this baseline strategy)
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit when not selected (reads cached g_is_selected only)
   if(Strategy_ExitSignal())
     {
      const long magic = (long)QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   // Per-closed-bar: rebalance and entry check
   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   // Monthly rebalance: update g_is_selected on the first D1 bar of each new month.
   // All cross-symbol iClose reads are confined to this branch.
   if(IsNewMonthBar())
      AdvanceState_OnNewMonth();

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
