#property strict
#property version   "5.0"
#property description "QM5_1269 as-haa-balanced — AllocateSmartly Hybrid Asset Allocation (Balanced), D1 basket"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1269 as-haa-balanced
// -----------------------------------------------------------------------------
// Source: AllocateSmartly "Hybrid Asset Allocation - Balanced" (Keller & Keuning,
// SSRN 4346906; TuringTrader Keller_HAA_v2.cs). source_id 2df06de7. Card:
// artifacts/cards_approved/QM5_1269_as-haa-balanced.md (g0_status APPROVED).
//
// HYBRID ASSET ALLOCATION (HAA) — canary-gated cross-sectional dual-momentum
// rotation. A canary asset's absolute momentum decides risk-on vs risk-off; in
// risk-on the portfolio rotates equal-weight into the top-N offensive assets by
// 13612 momentum (provided each has positive momentum, else it is replaced by the
// defensive sleeve); in risk-off the whole book moves to the defensive sleeve.
//
//   13612 momentum (the strategy's ranking score):
//     MOM = (c/c_1m - 1) + (c/c_3m - 1) + (c/c_6m - 1) + (c/c_12m - 1)
//   Source cadence is MONTHLY (month-end close). The .DWX tester yields 0 bars on
//   MN1 (build rule #10), so this is built D1-NATIVE with a 21-trading-day/month
//   (252-day/year) proxy: the m-month lookback is m*21 D1 bars. Rebalance is
//   gated on a broker-time MONTH change of the newly-closed D1 bar (so it fires
//   once per month, on the first new D1 bar of a new calendar month), matching the
//   monthly source rebalance without ever touching MN1.
//
// -----------------------------------------------------------------------------
// DWX PORT (ETFs are not tradeable on DWX; ported to nearest DWX proxy and FLAGGED
// in basket_manifest.json):
//   Offensive (8 ETFs -> 6 DWX proxies; emerging/REIT have no clean CFD analog):
//     SPY  (US large)        -> SP500.DWX   (backtest-only read; live uses NDX/WS30)
//     IWM  (US small)        -> WS30.DWX     APPROX (no Russell-2000 CFD)
//     VEA  (dev. ex-US)      -> GDAXI.DWX    APPROX (DAX as developed-intl equity proxy)
//     VWO  (emerging)        -> (no clean DWX proxy) DROPPED — flagged
//     VNQ  (US REIT)         -> (no clean DWX proxy) DROPPED — flagged
//     DBC  (broad commodity) -> XTIUSD.DWX   APPROX (WTI crude as commodity proxy)
//     IEF  (7-10y Treasury)  -> XAUUSD.DWX   APPROX (gold as the safe/defensive leg)
//     TLT  (20y+ Treasury)   -> XAGUSD.DWX   APPROX (silver as a 2nd safe-haven metal)
//     (+ NDX.DWX added as a live-tradable US large-cap companion to SP500's BT-only read)
//   Defensive (IEF, BIL / cash) -> XAUUSD.DWX (gold), with cash = flat/no-position.
//   Canary (TIP) -> no DWX bond/TIPS CFD. APPROXIMATED by the absolute 13612
//     momentum of the gold safe-haven proxy XAUUSD.DWX as the risk-on/off gate
//     (gold strength as a defensive-demand/inflation signal). FLAGGED in manifest;
//     this is the least-faithful port and a candidate for a custom TIP symbol later.
//
// The EA runs ONE instance per host symbol. Each instance reads the FULL universe's
// D1 closes (foreign reads warmed via QM_SymbolGuardInit + QM_BasketWarmupHistory),
// computes every leg's 13612 momentum, decides the monthly allocation, and goes long
// ONLY when the host symbol is one of the selected slots. Long-only (the source goes
// flat-into-the-safe-asset, here = rotate into the defensive proxy, never shorts).
// One position per magic on the host.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1269;
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
input int    strategy_bars_per_month     = 21;    // D1 proxy: trading days / month (252/yr)
input int    strategy_top_n              = 4;     // top-half of 8-leg offensive universe
input int    strategy_min_valid          = 3;     // min offensive legs with valid data to rank
input int    strategy_atr_period         = 14;    // protective-stop ATR period (D1)
input double strategy_stop_atr_mult      = 3.0;   // protective stop = mult * ATR (P3 {2.5,3.0,3.5})
input int    strategy_min_warmup_bars    = 270;   // >= 12-month proxy (252) + slack

// -----------------------------------------------------------------------------
// Fixed universes (matrix-verified DWX proxies). See port table in the header.
// Offensive = rotation candidates. Defensive = the safe sleeve held in risk-off and
// substituted for any offensive leg with non-positive momentum. Canary = risk gate.
// -----------------------------------------------------------------------------
#define QM_MAX_OFF 8

string g_off[QM_MAX_OFF];          // offensive universe (DWX proxies)
int    g_noff      = 0;
string g_defensive = "XAUUSD.DWX"; // defensive / safe sleeve (gold proxy)
string g_canary    = "XAUUSD.DWX"; // canary risk gate proxy (FLAGGED approximation)

int    g_host_idx  = -1;           // index of host in g_off, or -1
bool   g_host_is_def = false;      // true if host == defensive sleeve

// Cached monthly allocation state, advanced once per closed D1 bar on a month change.
double g_mom[QM_MAX_OFF];          // 13612 momentum per offensive leg
bool   g_valid[QM_MAX_OFF];        // per-leg valid-data flag
bool   g_slot_off[QM_MAX_OFF];     // true if this offensive leg is an allocated slot
int    g_def_slots = 0;            // number of slots filled by the defensive sleeve
bool   g_risk_on   = false;        // canary gate: true = risk-on
bool   g_ready     = false;        // true when this eval produced a usable allocation
int    g_last_eval_month = -1;     // broker-time month of the last evaluation

void QM_BuildUniverse()
  {
   // Offensive proxies for the 8-leg HAA-Balanced universe (2 emerging/REIT legs
   // have no clean DWX analog and are dropped — see header / manifest flags).
   string u[] =
     {
      "SP500.DWX",   // SPY  (US large cap)         — backtest-only read
      "NDX.DWX",     // (US large-cap growth, live-tradable companion to SPY proxy)
      "WS30.DWX",    // IWM  (US small) APPROX
      "GDAXI.DWX",   // VEA  (developed ex-US) APPROX
      "XTIUSD.DWX",  // DBC  (broad commodity) APPROX
      "XAUUSD.DWX",  // IEF  (intermediate Treasury / safe) APPROX
      "XAGUSD.DWX"   // TLT  (long Treasury / 2nd safe metal) APPROX
     };
   g_noff = ArraySize(u);
   if(g_noff > QM_MAX_OFF) g_noff = QM_MAX_OFF;
   for(int i = 0; i < g_noff; ++i)
      g_off[i] = u[i];
  }

// Build the dedup warmup list: host + every offensive leg + defensive + canary.
void QM_BuildWarmupList(string &out[])
  {
   ArrayResize(out, g_noff + 3);
   int n = 0;
   out[n++] = _Symbol;
   for(int i = 0; i < g_noff; ++i)
     {
      bool dup = false;
      for(int j = 0; j < n; ++j)
         if(out[j] == g_off[i]) { dup = true; break; }
      if(!dup) out[n++] = g_off[i];
     }
   bool ddup = false;
   for(int j = 0; j < n; ++j) if(out[j] == g_defensive) { ddup = true; break; }
   if(!ddup) out[n++] = g_defensive;
   bool cdup = false;
   for(int j = 0; j < n; ++j) if(out[j] == g_canary) { cdup = true; break; }
   if(!cdup) out[n++] = g_canary;
   ArrayResize(out, n);
  }

// 13612 momentum on CLOSED D1 bars, D1-native proxy (m months = m*bars_per_month).
// MOM = sum over m in {1,3,6,12} of (close[1] / close[1 + m*bpm] - 1).
// Returns true with `mom` set when all four lookback closes are available & > 0.
// perf-allowed: bespoke multi-window momentum; only the four needed closes are read,
// once per month, gated by the new-bar month-change in OnTick. No per-tick scan.
bool QM_Compute13612(const string sym, const int bpm, double &mom)
  {
   mom = 0.0;
   const int need = 12 * bpm + 2;
   if(Bars(sym, PERIOD_D1) < need)
      return false;
   const double c1 = iClose(sym, PERIOD_D1, 1);   // perf-allowed: last closed D1 close
   if(c1 <= 0.0)
      return false;
   const int months[4] = {1, 3, 6, 12};
   for(int k = 0; k < 4; ++k)
     {
      const int shift = 1 + months[k] * bpm;
      const double cm = iClose(sym, PERIOD_D1, shift);  // perf-allowed: m-month-ago close
      if(cm <= 0.0)
         return false;
      mom += (c1 / cm) - 1.0;
     }
   return true;
  }

// -----------------------------------------------------------------------------
// Advance the monthly allocation ONCE per closed D1 bar on a broker-time month
// change. Implements the full HAA rule set on the DWX-ported universes.
// -----------------------------------------------------------------------------
void QM_AdvanceAllocation()
  {
   g_ready    = false;
   g_risk_on  = false;
   g_def_slots = 0;
   for(int i = 0; i < g_noff; ++i)
     {
      g_mom[i]      = 0.0;
      g_valid[i]    = false;
      g_slot_off[i] = false;
     }

   const int bpm = (strategy_bars_per_month > 0 ? strategy_bars_per_month : 21);

   // (1) Canary gate: risk-on iff the canary's absolute 13612 momentum is positive.
   double canary_mom = 0.0;
   const bool canary_ok = QM_Compute13612(g_canary, bpm, canary_mom);
   if(!canary_ok)
      return;                                   // canary series not warm — defer
   g_risk_on = (canary_mom > 0.0);

   // (2) Offensive momentum for every leg with valid data.
   int valid_count = 0;
   for(int i = 0; i < g_noff; ++i)
     {
      double m = 0.0;
      if(QM_Compute13612(g_off[i], bpm, m))
        {
         g_mom[i]   = m;
         g_valid[i] = true;
         ++valid_count;
        }
     }
   if(valid_count < strategy_min_valid)
      return;                                   // too thin for a valid ranking

   if(!g_risk_on)
     {
      // (3a) Risk-off: the entire book holds the defensive sleeve in all N slots.
      g_def_slots = strategy_top_n;
      g_ready = true;
      return;
     }

   // (3b) Risk-on: rank offensive legs by 13612 momentum, take the top-N. Each
   // selected leg with POSITIVE momentum is held; any selected leg with non-positive
   // momentum is replaced by the defensive sleeve (absolute-momentum replacement).
   int take = strategy_top_n;
   if(take > valid_count) take = valid_count;

   for(int s = 0; s < take; ++s)
     {
      int best = -1;
      double best_mom = 0.0;
      for(int i = 0; i < g_noff; ++i)
        {
         if(!g_valid[i] || g_slot_off[i]) continue;
         if(best < 0 || g_mom[i] > best_mom)
           { best = i; best_mom = g_mom[i]; }
        }
      if(best < 0)
         break;
      g_slot_off[best] = true;                  // mark as picked (used or replaced)
      if(g_mom[best] <= 0.0)
        {
         g_slot_off[best] = false;              // not actually held offensively
         ++g_def_slots;                          // replaced by defensive sleeve
        }
     }

   g_ready = true;
  }

// Month-change detector on the newly-closed D1 bar (broker time). True once per month.
bool QM_IsNewMonth()
  {
   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   if(dt.mon != g_last_eval_month)
     {
      g_last_eval_month = dt.mon;
      return true;
     }
   return false;
  }

// True when the host is currently an allocated slot under the cached allocation.
bool QM_HostIsAllocated()
  {
   if(!g_ready)
      return false;
   // Defensive sleeve host: allocated whenever any slot is defensive.
   if(g_host_is_def)
      return (g_def_slots > 0);
   // Offensive host: allocated when its leg is a selected (held) offensive slot.
   if(g_host_idx >= 0)
      return g_slot_off[g_host_idx];
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick spread guard. Fail-open on .DWX zero modeled spread (rule #1).
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
   if(spread > 0.0 && spread > 0.20 * stop_distance)
      return true;                              // genuinely wide spread — block
   return false;                                // zero/normal modeled spread — pass
  }

// D1 entry. Caller guarantees QM_IsNewBar()==true. Allocation advanced in OnTick
// before this call. Host goes long iff it is an allocated slot this month.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(!g_ready)
      return false;
   if(!QM_HostIsAllocated())
      return false;

   const QM_OrderType ot = QM_BUY;             // long-only allocation
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, ot, entry, strategy_atr_period, strategy_stop_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = ot;
   req.price  = 0.0;        // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;        // no TP — monthly reallocation is the primary exit
   req.reason = "haa_allocate_long";
   return true;
  }

// No active management beyond the static protective ATR stop.
void Strategy_ManageOpenPosition()
  {
  }

// Monthly reallocation exit: close the host long when the new allocation no longer
// holds the host (deselected, replaced by defensive, or risk-off moved off it).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;
   if(!g_ready)
      return false;

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

   // Exit when the host is no longer an allocated slot under the current allocation.
   if(!QM_HostIsAllocated())
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

   // Build the fixed universe and locate the host.
   QM_BuildUniverse();
   g_host_idx = -1;
   for(int i = 0; i < g_noff; ++i)
      if(g_off[i] == _Symbol) { g_host_idx = i; break; }
   g_host_is_def = (_Symbol == g_defensive);

   // BASKET wiring: register the host + every universe leg and warm their D1 history
   // so foreign-symbol reads return real tester data.
   string warmlist[];
   QM_BuildWarmupList(warmlist);
   QM_SymbolGuardInit(warmlist);
   const int bpm  = (strategy_bars_per_month > 0 ? strategy_bars_per_month : 21);
   const int warm = MathMax(strategy_min_warmup_bars, 12 * bpm + 16);
   QM_BasketWarmupHistory(warmlist, PERIOD_D1, warm);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"offensive\":%d,\"host\":\"%s\",\"host_idx\":%d,\"host_is_def\":%s}",
                            g_noff, _Symbol, g_host_idx, (g_host_is_def ? "true" : "false")));
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

   // Latch the closed-bar event ONCE (single-consume, rule #3). On the first new D1
   // bar of a new broker-time month, refresh the monthly allocation BEFORE the
   // rule-based exit so the signal-exit sees the current allocation.
   const bool nb = QM_IsNewBar();
   if(nb && QM_IsNewMonth())
      QM_AdvanceAllocation();

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
