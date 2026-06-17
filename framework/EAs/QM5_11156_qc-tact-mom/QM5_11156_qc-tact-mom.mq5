#property strict
#property version   "5.0"
#property description "QM5_11156 qc-tact-mom — QuantConnect tactical momentum allocation (D1, basket)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11156 qc-tact-mom
// -----------------------------------------------------------------------------
// Source: QuantConnect Boot Camp "Momentum-Based Tactical Allocation"
// (Jared Broad), source_id 039cc5bd. Card:
// artifacts/cards_approved/QM5_11156_qc-tact-mom.md (g0_status APPROVED).
//
// BASKET EA — relative-momentum TACTICAL ALLOCATION. The source rotates 100%
// between a risk-on asset (SPY) and a defensive asset (BND), once weekly on
// Wednesday, into whichever has the higher 50-day momentum. There is no DWX
// bond CFD, so the card's R3 port maps:
//   risk-on  candidates : SP500.DWX, NDX.DWX, WS30.DWX (US large-cap indices)
//   defensive candidate : XAUUSD.DWX (gold proxy for the BND safe leg)
// Each weekly Wednesday close, the EA ranks all four candidates by 50-day
// momentum percent (cross-sectional) and selects the single strongest sleeve.
// The EA runs one instance per host symbol; the host opens / holds a long only
// when it is itself the selected sleeve. One position per magic on the host.
//
// This generalises the binary SPY-vs-BND switch to the 4-symbol DWX port while
// preserving the literal rule: "allocate 100% to the higher-momentum asset,
// liquidate the rest." Long-only (the source never shorts; it goes flat-into-
// the-safe-asset, here represented by rotating into the defensive sleeve).
//
// Mechanics (all on CLOSED D1 bars, advanced once per new D1 bar; weekly
// Wednesday cadence enforced by the broker-time weekday of the new bar):
//   Momentum  : per candidate, 50-day momentum percent via QM_Momentum
//               (iMomentum = close[1]/close[1+period]*100). Ordering is
//               identical to QuantConnect MOMP = (close/close[-50]-1)*100, so
//               the cross-sectional pick is faithful.
//   Select    : the candidate with the highest 50-day momentum is the active
//               sleeve for the week. Require >= min_candidates with valid data.
//   Entry(host): host == selected sleeve AND no open position for this magic.
//   Exit(host) : the weekly rebalance selects a DIFFERENT sleeve than the host.
//   Stop       : protective 2.5 * ATR(14, D1) from entry (card baseline; bounds
//               MT5 worst-case — the weekly rebalance reselection is the primary
//               close).
//   Filters    : require >= min_candidates active candidates; >= warmup D1 bars;
//               skip new entries only on a genuinely wide host spread.
//
// Only the five Strategy_* hooks + the OnInit basket wiring are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11156;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_momentum_period    = 50;    // 50-day momentum window (P3 sweep {30,50,70})
input int    strategy_min_candidates     = 2;     // min candidates with valid data for a valid rank
input int    strategy_atr_period         = 14;    // protective-stop ATR period (D1)
input double strategy_stop_atr_mult      = 2.5;   // protective stop = mult * ATR (P3 {2.0,2.5,3.0})
input int    strategy_min_warmup_bars    = 60;    // min D1 warmup bars per candidate (card: 60)
input int    strategy_rebalance_weekday  = 3;     // 0=Sun..6=Sat; 3 = Wednesday (broker time)
input double strategy_spread_pct_of_stop = 20.0;  // skip if host spread > this % of stop distance

// -----------------------------------------------------------------------------
// Fixed candidate basket (matrix-verified). Risk-on US large-cap indices plus
// the defensive gold proxy. The EA reads every candidate's D1 momentum to pick
// the single strongest; the host trades only when it is selected.
// -----------------------------------------------------------------------------
#define QM_MAX_CAND 8

string g_cand[QM_MAX_CAND];
int    g_ncand    = 0;
int    g_host_idx = -1;          // index of _Symbol in g_cand, or -1

// Cached selection state, advanced once per closed D1 bar (on rebalance weekday).
double g_mom[QM_MAX_CAND];       // 50-day momentum per candidate
bool   g_valid[QM_MAX_CAND];     // per-candidate valid-data flag
int    g_selected = -1;          // index of the selected sleeve, or -1
int    g_active_count = 0;       // candidates with valid momentum data this eval
bool   g_ready    = false;       // true when this eval produced a usable selection

void QM_BuildCandidates()
  {
   string u[] =
     {
      "SP500.DWX","NDX.DWX","WS30.DWX","XAUUSD.DWX"
     };
   g_ncand = ArraySize(u);
   if(g_ncand > QM_MAX_CAND) g_ncand = QM_MAX_CAND;
   for(int i = 0; i < g_ncand; ++i)
      g_cand[i] = u[i];
  }

// Fill `out` with the candidate basket plus the host (host is normally already a
// member; dedup keeps the warmup list clean).
void QM_BuildWarmupList(string &out[])
  {
   ArrayResize(out, g_ncand + 1);
   int n = 0;
   out[n++] = _Symbol;
   for(int i = 0; i < g_ncand; ++i)
     {
      bool dup = false;
      for(int j = 0; j < n; ++j)
         if(out[j] == g_cand[i]) { dup = true; break; }
      if(!dup) out[n++] = g_cand[i];
     }
   ArrayResize(out, n);
  }

// -----------------------------------------------------------------------------
// Advance the cross-sectional selection ONCE per closed D1 rebalance bar.
// -----------------------------------------------------------------------------
void QM_AdvanceSelection()
  {
   g_ready = false;
   g_selected = -1;
   g_active_count = 0;

   for(int i = 0; i < g_ncand; ++i)
     {
      g_mom[i] = 0.0;
      g_valid[i] = false;
      const string sym = g_cand[i];
      // Need both the card warmup floor and enough bars for the momentum window.
      const int need = MathMax(strategy_min_warmup_bars, strategy_momentum_period + 2);
      if(Bars(sym, PERIOD_D1) < need)
         continue;
      // 50-day momentum percent on the last closed D1 bar (shift 1). iMomentum
      // returns close[1]/close[1+period]*100; a non-positive read means the
      // foreign series is not yet warm in the tester — treat as invalid.
      const double m = QM_Momentum(sym, PERIOD_D1, strategy_momentum_period, 1);
      if(m <= 0.0)
         continue;
      g_mom[i] = m;
      g_valid[i] = true;
      ++g_active_count;
     }

   if(g_active_count < strategy_min_candidates)
      return;                                   // too thin for a valid selection

   // Select the candidate with the highest 50-day momentum among valid members.
   int best = -1;
   double best_mom = 0.0;
   for(int i = 0; i < g_ncand; ++i)
     {
      if(!g_valid[i]) continue;
      if(best < 0 || g_mom[i] > best_mom)
        { best = i; best_mom = g_mom[i]; }
     }

   g_selected = best;
   g_ready = (best >= 0);
  }

// Is "now" a rebalance evaluation bar? True only on the configured broker-time
// weekday of the newly-closed D1 bar.
bool QM_IsRebalanceBar()
  {
   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   return (dt.day_of_week == strategy_rebalance_weekday);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick spread guard. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;                             // no valid quote — defer, don't block

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   const double stop_distance = strategy_stop_atr_mult * atr;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;                              // genuinely wide spread — block
   return false;                                // zero/normal modeled spread — pass
  }

// D1 entry. Caller guarantees QM_IsNewBar()==true. Selection is advanced in
// OnTick before this call (g_selected / g_ready).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(!g_ready || g_host_idx < 0)
      return false;

   // Host must be the selected sleeve this week.
   if(g_selected != g_host_idx)
      return false;

   // Long-only allocation into the strongest sleeve.
   const QM_OrderType ot = QM_BUY;
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, ot, entry, strategy_atr_period, strategy_stop_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = ot;
   req.price  = 0.0;        // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;        // no TP — weekly reselection is the primary exit
   req.reason = "tact_mom_allocate_long";
   return true;
  }

// No active management beyond the static protective ATR stop.
void Strategy_ManageOpenPosition()
  {
  }

// Rebalance exit: close the host long when the weekly reselection chooses a
// DIFFERENT sleeve than the host (or the selection became unusable).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;
   if(!g_ready || g_host_idx < 0)
      return false;

   // Only act on a long position on this host (long-only EA, one per magic).
   bool have_long = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         have_long = true;
      break;
     }
   if(!have_long)
      return false;

   // Exit when the host is no longer the selected sleeve.
   if(g_selected != g_host_idx)
      return true;

   return false;
  }

// Defer to the central two-axis news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
      return INIT_FAILED;

   // Build the fixed candidate basket and locate the host within it.
   QM_BuildCandidates();
   g_host_idx = -1;
   for(int i = 0; i < g_ncand; ++i)
      if(g_cand[i] == _Symbol) { g_host_idx = i; break; }

   // BASKET wiring: register the host + every candidate and warm their D1
   // history so foreign-symbol reads return real tester data.
   string warmlist[];
   QM_BuildWarmupList(warmlist);
   QM_SymbolGuardInit(warmlist);
   const int warm = strategy_momentum_period + strategy_min_warmup_bars + 16;
   QM_BasketWarmupHistory(warmlist, PERIOD_D1, warm);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"candidates\":%d,\"host\":\"%s\",\"host_idx\":%d}",
                            g_ncand, _Symbol, g_host_idx));
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

   // Latch the closed-bar event ONCE (single-consume). On a fresh D1 bar that is
   // also the weekly rebalance weekday, refresh the cross-sectional selection
   // BEFORE the rule-based exit so the signal-exit sees the current pick.
   const bool nb = QM_IsNewBar();
   if(nb && QM_IsRebalanceBar())
      QM_AdvanceSelection();

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

   if(!nb)
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
