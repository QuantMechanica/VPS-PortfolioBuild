#property strict
#property version   "5.0"
#property description "QM5_11725 tc-m5-s12-ema-laguerre — EMA(16/48) stack + Laguerre RSI threshold cross (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11725 tc-m5-s12-ema-laguerre
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)"
//         (367145560), Strategy #12, 2014.
// Card: artifacts/cards_approved/QM5_11725_tc-m5-s12-ema-laguerre.md (g0 APPROVED).
//
// Mechanics (closed-bar reads at shift 1; M5):
//   Trend STATE (long) : close[1] > EMA16[1]  AND  EMA16[1] > EMA48[1].
//   Trend STATE (short): close[1] < EMA16[1]  AND  EMA16[1] < EMA48[1].
//   Laguerre RSI       : Ehlers 4-stage Laguerre filter (L0..L3, gamma) feeding
//                        CU/(CU+CD). Computed in-EA (no built-in indicator),
//                        seeded from a bounded closed-bar warmup window
//                        (perf-allowed; one CopyClose under the new-bar gate).
//   Trigger EVENT (single, one per direction):
//     LONG : Laguerre crosses UP through the upper level
//            (lag[2] < up_level AND lag[1] >= up_level)  — momentum confirmation.
//     SHORT: Laguerre crosses DOWN through the lower level
//            (lag[2] >= dn_level AND lag[1] < dn_level).
//   The EMA stack is a STATE; the Laguerre cross is the ONLY fresh EVENT, so the
//   two-cross-same-bar zero-trade trap is avoided (single event per direction).
//   Stop  : 30 pips (pip-scale correct via QM_StopRulesPipsToPriceDistance).
//   Take  : 25 pips.
//   Exit  : SL or TP only (no discretionary exit).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11725;
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
input int    strategy_ema_fast_period   = 16;     // trend-stack fast EMA
input int    strategy_ema_slow_period   = 48;     // trend-stack slow EMA
input double strategy_lag_gamma         = 0.7;    // Laguerre damping factor (0..1)
input double strategy_lag_up_level      = 0.8;    // overbought / long-momentum cross level
input double strategy_lag_dn_level      = 0.2;    // oversold / short-momentum cross level
input int    strategy_lag_warmup_bars   = 200;    // bounded seed window for the recursion
input int    strategy_sl_pips           = 30;     // stop-loss distance in pips
input int    strategy_tp_pips           = 25;     // take-profit distance in pips
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Laguerre RSI (Ehlers) — computed in-EA.
//
// The 4-stage Laguerre filter is a recursion over the price series:
//   L0 = (1-g)*P  + g*L0_prev
//   L1 = -g*L0    + L0_prev + g*L1_prev
//   L2 = -g*L1    + L1_prev + g*L2_prev
//   L3 = -g*L2    + L2_prev + g*L3_prev
// Laguerre RSI = CU / (CU + CD), where CU/CD accumulate the up/down deltas
// across the L0..L3 ladder. Seeded from a bounded closed-bar window so the
// recursion is deterministic and perf-bounded (no growth with chart history).
//
// Returns Laguerre RSI at the requested closed-bar shift (>=1).
// Uses one CopyClose over the warmup window — caller MUST be under the new-bar
// gate (Strategy_EntrySignal is). g_lag_close is a file-scope reusable buffer.
// -----------------------------------------------------------------------------
double g_lag_close[];

double LaguerreRSI(const int shift)
  {
   const double g = strategy_lag_gamma;
   if(g <= 0.0 || g >= 1.0)
      return -1.0; // invalid gamma -> signal "no value"

   int warm = strategy_lag_warmup_bars;
   if(warm < 50)
      warm = 50;

   // Need `warm` closed bars ending at `shift`. Oldest first for the recursion.
   const int bars_available = Bars(_Symbol, _Period); // perf-allowed: warmup sizing
   if(bars_available <= shift + 2)
      return -1.0;

   int want = warm;
   if(want > bars_available - shift - 1)
      want = bars_available - shift - 1;
   if(want < 30)
      return -1.0;

   // CopyClose pulls [start_pos .. start_pos+count-1] indexed as series.
   // We want bars from shift+want-1 (oldest) down to shift (newest). Pull a
   // contiguous block starting at `shift`, length `want`. perf-allowed: one
   // bounded copy under the new-bar gate, reused buffer.
   if(ArraySize(g_lag_close) < want)
      ArrayResize(g_lag_close, want);
   const int copied = CopyClose(_Symbol, _Period, shift, want, g_lag_close); // perf-allowed: bounded Laguerre seed window; Strategy_EntrySignal is called only after the framework QM_IsNewBar gate.
   if(copied < want)
      return -1.0;

   // CopyClose with as-series default = false here gives chronological order
   // (index 0 = oldest of the block). Make ordering explicit.
   ArraySetAsSeries(g_lag_close, false);

   double l0 = g_lag_close[0], l1 = g_lag_close[0];
   double l2 = g_lag_close[0], l3 = g_lag_close[0];
   double l0p = l0, l1p = l1, l2p = l2, l3p = l3;

   double lag_rsi = 0.5;
   for(int i = 0; i < want; ++i)
     {
      const double p = g_lag_close[i];
      l0p = l0; l1p = l1; l2p = l2; l3p = l3;

      l0 = (1.0 - g) * p + g * l0p;
      l1 = -g * l0 + l0p + g * l1p;
      l2 = -g * l1 + l1p + g * l2p;
      l3 = -g * l2 + l2p + g * l3p;

      double cu = 0.0, cd = 0.0;
      if(l0 >= l1) cu += (l0 - l1); else cd += (l1 - l0);
      if(l1 >= l2) cu += (l1 - l2); else cd += (l2 - l1);
      if(l2 >= l3) cu += (l2 - l3); else cd += (l3 - l2);

      const double denom = cu + cd;
      if(denom > 0.0)
         lag_rsi = cu / denom;
      // else: keep previous lag_rsi (flat ladder) — bounded in [0,1].
     }

   return lag_rsi; // value at the most-recent bar of the block == `shift`
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Trend STATE: EMA(16/48) stack + price vs fast EMA (closed bar) ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const bool trend_up   = (close1 > ema_fast && ema_fast > ema_slow);
   const bool trend_down = (close1 < ema_fast && ema_fast < ema_slow);
   if(!trend_up && !trend_down)
      return false;

   // --- Trigger EVENT: Laguerre RSI threshold cross (single event/direction) ---
   const double lag_now  = LaguerreRSI(1); // last closed bar
   const double lag_prev = LaguerreRSI(2); // prior closed bar
   if(lag_now < 0.0 || lag_prev < 0.0)
      return false;

   // LONG: trend up AND Laguerre crosses UP through the upper level.
   if(trend_up)
     {
      const bool crossed_up = (lag_prev < strategy_lag_up_level &&
                               lag_now  >= strategy_lag_up_level);
      if(!crossed_up)
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_sl_pips);
      const double tp_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_pips);
      const double tp = QM_StopRulesTakeFromDistance(_Symbol, QM_BUY, entry, tp_dist);
      if(sl <= 0.0 || tp <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ema_laguerre_long";
      return true;
     }

   // SHORT: trend down AND Laguerre crosses DOWN through the lower level.
   if(trend_down)
     {
      const bool crossed_dn = (lag_prev >= strategy_lag_dn_level &&
                               lag_now  <  strategy_lag_dn_level);
      if(!crossed_dn)
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_sl_pips);
      const double tp_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_pips);
      const double tp = QM_StopRulesTakeFromDistance(_Symbol, QM_SELL, entry, tp_dist);
      if(sl <= 0.0 || tp <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ema_laguerre_short";
      return true;
     }

   return false;
  }

// Fixed SL/TP only — no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit; SL/TP handle the close.
bool Strategy_ExitSignal()
  {
   return false;
  }

// Defer to the central news filter.
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
