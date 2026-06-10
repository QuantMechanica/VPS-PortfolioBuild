#property strict
#property version   "5.0"
#property description "QM5_9218 MQL5 Aroon Up/Down Crossover (ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9218 — MQL5 Aroon Up/Down Crossover
// Source: Mohamed Abdelmaaboud, MQL5 Articles 2024-01-19
// Card: cards_approved/QM5_9218_mql5-aroon-cross.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9218;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours              = 336;
input string qm_news_min_impact                   = "high";
input QM_NewsMode qm_news_mode_legacy             = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_aroon_period       = 25;    // Aroon Up/Down lookback period
input int    strategy_atr_period         = 14;    // ATR period for stop sizing
input double strategy_sl_atr_mult        = 1.8;   // SL = ATR * multiplier
input double strategy_tp_rr              = 2.3;   // TP = SL * R:R ratio
input double strategy_min_aroon_spread   = 5.0;   // min (|Up−Down|) at entry to filter churn
input int    strategy_max_hold_bars      = 60;    // failsafe time-exit in H1 bars

// -----------------------------------------------------------------------------
// File-scope cached state — updated once per new H1 bar inside
// Strategy_EntrySignal(), which is called only after QM_IsNewBar() == true.
// No timestamp gate here; QM_IsNewBar() IS the gate (framework-provided).
// -----------------------------------------------------------------------------

double g_spread_last  = 0.0;   // Aroon(Up−Down) on last closed bar; updated in EntrySignal
double g_spread_prev  = 0.0;   // Aroon(Up−Down) on bar before last; updated in EntrySignal
int    g_bars_held    = 0;     // bars elapsed with open position; reset on new entry

// -----------------------------------------------------------------------------
// Aroon calculation — O(period) per call; tagged // perf-allowed because it is
// bespoke indicator math with no QM_ equivalent.
// MUST only be called from within Strategy_EntrySignal() (after QM_IsNewBar gate).
// -----------------------------------------------------------------------------

void CalcAroon(const int period, const int ref_shift, double &up, double &dn)
  {
   // perf-allowed: O(period) iHigh/iLow; bespoke Aroon; gated by QM_IsNewBar
   int    hi_idx = ref_shift;
   int    lo_idx = ref_shift;
   double hi_val = iHigh(_Symbol, PERIOD_H1, ref_shift); // perf-allowed
   double lo_val = iLow(_Symbol, PERIOD_H1, ref_shift);  // perf-allowed
   for(int i = ref_shift + 1; i <= ref_shift + period; ++i)
     {
      double h = iHigh(_Symbol, PERIOD_H1, i); // perf-allowed
      double l = iLow(_Symbol, PERIOD_H1, i);  // perf-allowed
      if(h >= hi_val) { hi_val = h; hi_idx = i; }
      if(l <= lo_val) { lo_val = l; lo_idx = i; }
     }
   up = (double)(period - (hi_idx - ref_shift)) / period * 100.0;
   dn = (double)(period - (lo_idx - ref_shift)) / period * 100.0;
  }

// -----------------------------------------------------------------------------
// Strategy helpers
// -----------------------------------------------------------------------------

bool HasOwnPosition(ENUM_POSITION_TYPE &ptype)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)magic)
         continue;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Called only after QM_IsNewBar() == true.
// Updates g_spread_last, g_spread_prev, and g_bars_held (all O(1) reads from cache).
// The O(period) CalcAroon calls are gated here — never reach the per-tick path.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Refresh Aroon state for this closed bar (O(period) but gated by QM_IsNewBar).
   double up1, dn1, up2, dn2;
   CalcAroon(strategy_aroon_period, 1, up1, dn1);
   CalcAroon(strategy_aroon_period, 2, up2, dn2);
   g_spread_last = up1 - dn1;
   g_spread_prev = up2 - dn2;

   // Advance hold-bar counter or reset depending on whether a position is open.
   ENUM_POSITION_TYPE existing_type;
   if(HasOwnPosition(existing_type))
     {
      g_bars_held++;
      return false; // one position per magic — no new entry
     }
   g_bars_held = 0; // no open position → reset counter

   // Require valid data (CalcAroon returns 0.0 when bars are unavailable during warmup).
   if(up1 <= 0.0 && dn1 <= 0.0)
      return false;

   // Cross detection: shift-1 vs shift-2 (last closed bar vs bar before)
   // Long: Aroon Up crosses above Aroon Down with spread >= min filter
   const bool long_cross  = (g_spread_last >=  strategy_min_aroon_spread) &&
                             (g_spread_prev <=  0.0);
   // Short: Aroon Down crosses above Aroon Up with |spread| >= min filter
   const bool short_cross = (-g_spread_last >=  strategy_min_aroon_spread) &&
                             (-g_spread_prev <= 0.0);

   if(!long_cross && !short_cross)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double sl_dist = strategy_sl_atr_mult * atr;
   const double tp_dist = sl_dist * strategy_tp_rr;

   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(long_cross)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = ask - sl_dist;
      req.tp     = ask + tp_dist;
      req.reason = "AROON_LONG_CROSS";
     }
   else
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = bid + sl_dist;
      req.tp     = bid - tp_dist;
      req.reason = "AROON_SHORT_CROSS";
     }

   return true;
  }

// No active trade management — SL/TP set at entry handles per-trade risk.
void Strategy_ManageOpenPosition()
  {
  }

// O(1): reads cached file-scope spread values; no indicator recomputation per tick.
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   if(!HasOwnPosition(ptype))
      return false;

   // Failsafe time-exit: g_bars_held incremented in Strategy_EntrySignal (per new bar)
   if(g_bars_held >= strategy_max_hold_bars)
      return true;

   // Aroon reverse-cross exit: g_spread_last / g_spread_prev set in Strategy_EntrySignal
   if(ptype == POSITION_TYPE_BUY)
      return (g_spread_last <= 0.0) && (g_spread_prev > 0.0); // Down crossed above Up
   else
      return (g_spread_last >= 0.0) && (g_spread_prev < 0.0); // Up crossed above Down
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to framework QM_NewsAllowsTrade
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

   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"ea\":\"QM5_9218\",\"slug\":\"mql5-aroon-cross\"}");
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
