#property strict
#property version   "5.0"
#property description "QM5_1268 as-baa-g12 — AllocateSmartly Bold Asset Allocation (BAA-G12), D1, basket"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1268 as-baa-g12
// -----------------------------------------------------------------------------
// Source: AllocateSmartly "Bold Asset Allocation" (Wouter Keller, SSRN 4166845;
// TuringTrader Keller_BAA_v2). Card:
// artifacts/cards_approved/QM5_1268_as-baa-g12.md (g0_status APPROVED),
// source_id 2df06de7-6a3a-5b06-9e6d-446d1a01fab9.
//
// BASKET EA — canary-gated cross-sectional tactical asset allocation.
//
//   1. CANARY GATE (crash protection): each canary asset's 13612W momentum is
//      computed; if ANY canary has 13612W < 0 the model goes fully RISK-OFF,
//      else RISK-ON (BAA breadth parameter B = 1).
//   2. RISK-ON  : rank the OFFENSIVE G12 universe by RANK_MOM = close/SMA(13)-1
//      and hold the top-6 equal-weighted.
//   3. RISK-OFF : rank the DEFENSIVE universe by RANK_MOM and hold the top-3
//      equal-weighted (BIL absolute-momentum replacement degrades to flat when
//      no defensive proxy clears zero momentum — no cash instrument on MT5).
//
// Rebalance is MONTHLY. MN1 is untestable in the .DWX tester (0 bars), so this
// EA is D1-native: rebalance fires on the first new D1 bar of a new broker-time
// MONTH, and the 1/3/6/12-month 13612W lookbacks use a 21-trading-day month
// proxy (252-day year). Each EA instance runs one HOST symbol and opens/holds a
// long ONLY when the host is a member of the currently-selected top-N set. One
// position per magic on the host.
//
// ETFs are NOT tradeable on DWX, so the three universes are ported to DWX
// proxies (indices / metals / energy / FX majors). Bond/credit/TIPS/cash legs
// have no clean DWX proxy and are APPROXIMATED + FLAGGED in basket_manifest.json.
//
// Momentum is computed in-EA from .DWX D1 closes. Foreign-symbol reads require
// QM_SymbolGuardInit + QM_BasketWarmupHistory or they return 0 in the tester.
// Only the five Strategy_* hooks + the OnInit basket wiring are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1268;
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
input int    strategy_sma_months         = 13;    // RANK_MOM SMA window in MONTHS (BAA: 13)
input int    strategy_top_offensive      = 6;     // top-N offensive held in risk-on (BAA: 6)
input int    strategy_top_defensive      = 3;     // top-N defensive held in risk-off (BAA: 3)
input int    strategy_days_per_month     = 21;    // D1 proxy: trading days per month (252/yr)
input int    strategy_atr_period         = 14;    // protective-stop ATR period (D1)
input double strategy_stop_atr_mult      = 3.0;   // protective stop = mult * ATR (monthly hold)
input double strategy_spread_pct_of_stop = 20.0;  // skip if host spread > this % of stop distance

// -----------------------------------------------------------------------------
// Universes (matrix-verified DWX proxies; ETF -> DWX port documented in manifest).
//   Offensive G12 : SPY,QQQ,IWM,VGK,EWJ,VWO,VNQ,DBC,GLD,TLT,HYG,LQD
//   Defensive     : TIP,DBC,BIL,IEF,TLT,LQD,BND  (approx; FLAGGED — no DWX bond CFD)
//   Canary        : SPY,VWO,VEA,BNDX             (approx; FLAGGED — no DWX bond CFD)
// -----------------------------------------------------------------------------
#define QM_MAX_UNIV 16

string g_off[QM_MAX_UNIV];   int g_noff = 0;   // offensive universe
string g_def[QM_MAX_UNIV];   int g_ndef = 0;   // defensive universe
string g_can[QM_MAX_UNIV];   int g_ncan = 0;   // canary universe

int    g_host_off_idx = -1;  // host index within offensive universe, or -1
int    g_host_def_idx = -1;  // host index within defensive universe, or -1

// Cached selection state, advanced once per monthly rebalance bar.
bool   g_risk_on       = true;   // canary regime
bool   g_host_selected = false;  // host is in the active top-N this month
bool   g_ready         = false;  // last eval produced a usable selection
int    g_last_month    = -1;     // broker-time month of last rebalance eval

void QM_BuildUniverses()
  {
   // Offensive G12 (12 legs) — see basket_manifest.json for each ETF->DWX port.
   string off[] =
     {
      "SP500.DWX","NDX.DWX","WS30.DWX","GDAXI.DWX","UK100.DWX","AUDUSD.DWX",
      "XAGUSD.DWX","XTIUSD.DWX","XAUUSD.DWX","XNGUSD.DWX","EURUSD.DWX","USDJPY.DWX"
     };
   g_noff = ArraySize(off);
   if(g_noff > QM_MAX_UNIV) g_noff = QM_MAX_UNIV;
   for(int i = 0; i < g_noff; ++i) g_off[i] = off[i];

   // Defensive sleeve (approx — gold/defensive-FX/real-asset, FLAGGED).
   string def[] =
     {
      "XAUUSD.DWX","USDJPY.DWX","XTIUSD.DWX"
     };
   g_ndef = ArraySize(def);
   if(g_ndef > QM_MAX_UNIV) g_ndef = QM_MAX_UNIV;
   for(int i = 0; i < g_ndef; ++i) g_def[i] = def[i];

   // Canary (approx — SPY + EM/dev/bond FX proxies, FLAGGED).
   string can[] =
     {
      "SP500.DWX","AUDUSD.DWX","GDAXI.DWX","USDJPY.DWX"
     };
   g_ncan = ArraySize(can);
   if(g_ncan > QM_MAX_UNIV) g_ncan = QM_MAX_UNIV;
   for(int i = 0; i < g_ncan; ++i) g_can[i] = can[i];
  }

// Build the deduped warmup/guard list across all three universes + the host.
void QM_BuildWarmupList(string &out[])
  {
   ArrayResize(out, g_noff + g_ndef + g_ncan + 1);
   int n = 0;
   out[n++] = _Symbol;
   for(int i = 0; i < g_noff; ++i) { if(!QM_ListHas(out, n, g_off[i])) out[n++] = g_off[i]; }
   for(int i = 0; i < g_ndef; ++i) { if(!QM_ListHas(out, n, g_def[i])) out[n++] = g_def[i]; }
   for(int i = 0; i < g_ncan; ++i) { if(!QM_ListHas(out, n, g_can[i])) out[n++] = g_can[i]; }
   ArrayResize(out, n);
  }

bool QM_ListHas(const string &arr[], const int count, const string val)
  {
   for(int j = 0; j < count; ++j)
      if(arr[j] == val) return true;
   return false;
  }

// Minimum D1 bars needed for a 12-month 13612W lookback + SMA(13 months) window.
int QM_NeedBars()
  {
   const int need_13612 = 12 * strategy_days_per_month + 4;
   const int need_sma   = strategy_sma_months * strategy_days_per_month + 4;
   return MathMax(need_13612, need_sma);
  }

// 13612W momentum on CLOSED D1 bars: sum over m in {1,3,6,12} of
//   (12/m) * (close[1] / close[1 + m*days_per_month] - 1).
// Returns true + value, or false if the series is not warm enough.
bool QM_Mom13612W(const string sym, double &out_mom)
  {
   out_mom = 0.0;
   const int dpm = strategy_days_per_month;
   if(Bars(sym, PERIOD_D1) < 12 * dpm + 4)
      return false;
   const double c0 = iClose(sym, PERIOD_D1, 1);            // perf-allowed: monthly basket math
   if(c0 <= 0.0)
      return false;
   const int months[4] = {1, 3, 6, 12};
   const double wts[4]  = {12.0, 4.0, 2.0, 1.0};            // 12/m for m in {1,3,6,12}
   double acc = 0.0;
   for(int k = 0; k < 4; ++k)
     {
      const double cm = iClose(sym, PERIOD_D1, 1 + months[k] * dpm); // perf-allowed
      if(cm <= 0.0)
         return false;
      acc += wts[k] * (c0 / cm - 1.0);
     }
   out_mom = acc;
   return true;
  }

// RANK_MOM = close[1] / SMA(13 months of D1 closes)[1] - 1. The SMA window is
// strategy_sma_months * days_per_month D1 bars. Returns true + value or false
// if not warm enough.
bool QM_RankMom(const string sym, double &out_rm)
  {
   out_rm = 0.0;
   const int win = strategy_sma_months * strategy_days_per_month;
   if(Bars(sym, PERIOD_D1) < win + 4)
      return false;
   const double c0  = iClose(sym, PERIOD_D1, 1);           // perf-allowed
   const double sma = QM_SMA(sym, PERIOD_D1, win, 1);
   if(c0 <= 0.0 || sma <= 0.0)
      return false;
   out_rm = c0 / sma - 1.0;
   return true;
  }

// -----------------------------------------------------------------------------
// Monthly rebalance: compute the canary regime, then rank the active universe
// by RANK_MOM and mark whether the host is in the top-N. Cached state only.
// -----------------------------------------------------------------------------
void QM_AdvanceSelection()
  {
   g_ready = false;
   g_host_selected = false;

   // --- Canary gate: any canary with 13612W < 0 forces RISK-OFF (B = 1). ---
   bool risk_on = true;
   int  canary_seen = 0;
   for(int i = 0; i < g_ncan; ++i)
     {
      double m;
      if(!QM_Mom13612W(g_can[i], m))
         continue;
      ++canary_seen;
      if(m < 0.0)
         risk_on = false;
     }
   // If no canary warmed up yet, we cannot judge the regime — defer.
   if(canary_seen == 0)
      return;
   g_risk_on = risk_on;

   // --- Active universe + host membership index for this regime. ---
   int    n;
   int    host_idx;
   int    top_n;
   string uni[QM_MAX_UNIV];
   if(risk_on)
     {
      n = g_noff; host_idx = g_host_off_idx; top_n = strategy_top_offensive;
      for(int i = 0; i < n; ++i) uni[i] = g_off[i];
     }
   else
     {
      n = g_ndef; host_idx = g_host_def_idx; top_n = strategy_top_defensive;
      for(int i = 0; i < n; ++i) uni[i] = g_def[i];
     }

   if(host_idx < 0)
     {
      // Host is not a member of the active universe this regime — hold flat.
      g_ready = true;
      g_host_selected = false;
      return;
     }

   // --- Rank the active universe by RANK_MOM; collect valid members. ---
   double rm[QM_MAX_UNIV];
   bool   valid[QM_MAX_UNIV];
   int    nvalid = 0;
   for(int i = 0; i < n; ++i)
     {
      double v;
      valid[i] = QM_RankMom(uni[i], v);
      rm[i] = valid[i] ? v : 0.0;
      if(valid[i]) ++nvalid;
     }
   if(nvalid == 0)
      return;                       // nothing warm — defer

   // BIL absolute-momentum floor: in risk-off, a defensive proxy with negative
   // RANK_MOM is treated as below-cash and dropped (degrades to flat when none
   // clears zero — no cash instrument on MT5).
   if(!risk_on)
     {
      for(int i = 0; i < n; ++i)
         if(valid[i] && rm[i] < 0.0)
           { valid[i] = false; --nvalid; }
      if(nvalid == 0)
        {
         g_ready = true;
         g_host_selected = false;   // fully flat (cash) — no defensive leg qualifies
         return;
        }
     }

   // Host must itself be valid to be selectable.
   if(!valid[host_idx])
     {
      g_ready = true;
      g_host_selected = false;
      return;
     }

   // Count how many VALID members rank strictly above the host. If fewer than
   // top_n, the host is in the selected set.
   int better = 0;
   for(int i = 0; i < n; ++i)
     {
      if(i == host_idx || !valid[i]) continue;
      if(rm[i] > rm[host_idx])
         ++better;
     }

   const int effective_top = MathMin(top_n, nvalid);
   g_host_selected = (better < effective_top);
   g_ready = true;
  }

// Is this the first new D1 bar of a new broker-time MONTH? (monthly rebalance)
bool QM_IsRebalanceBar()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.mon != g_last_month)
     {
      g_last_month = dt.mon;
      return true;
     }
   return false;
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
      return false;                              // no valid quote — defer, don't block

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   const double stop_distance = strategy_stop_atr_mult * atr;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;                               // genuinely wide spread — block
   return false;                                 // zero/normal modeled spread — pass
  }

// D1 entry. Caller guarantees QM_IsNewBar()==true. Selection advanced in OnTick.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(!g_ready || !g_host_selected)
      return false;

   // Long-only allocation into a selected sleeve.
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
   req.tp     = 0.0;        // no TP — monthly reselection is the primary exit
   req.reason = "baa_allocate_long";
   return true;
  }

// No active management beyond the static protective ATR stop.
void Strategy_ManageOpenPosition()
  {
  }

// Rebalance exit: close the host long when the monthly reselection drops the
// host from the active top-N (regime flip or rank drop).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;
   if(!g_ready)
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

   // Exit when the host is no longer in the selected set this month.
   if(!g_host_selected)
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

   // Build the three universes and locate the host within offensive/defensive.
   QM_BuildUniverses();
   g_host_off_idx = -1;
   for(int i = 0; i < g_noff; ++i)
      if(g_off[i] == _Symbol) { g_host_off_idx = i; break; }
   g_host_def_idx = -1;
   for(int i = 0; i < g_ndef; ++i)
      if(g_def[i] == _Symbol) { g_host_def_idx = i; break; }

   // BASKET wiring: register the host + every universe member and warm their D1
   // history so foreign-symbol reads return real tester data.
   string warmlist[];
   QM_BuildWarmupList(warmlist);
   QM_SymbolGuardInit(warmlist);
   const int warm = QM_NeedBars() + 16;
   QM_BasketWarmupHistory(warmlist, PERIOD_D1, warm);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"off\":%d,\"def\":%d,\"can\":%d,\"host\":\"%s\",\"host_off\":%d,\"host_def\":%d}",
                            g_noff, g_ndef, g_ncan, _Symbol, g_host_off_idx, g_host_def_idx));
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

   // Latch the closed-bar event ONCE (single-consume). On the first new D1 bar
   // of a new broker-time month, refresh the canary regime + cross-sectional
   // selection BEFORE the rule-based exit so the signal-exit sees the new pick.
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
