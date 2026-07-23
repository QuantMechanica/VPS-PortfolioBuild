#property strict
#property version   "5.0"
#property description "QM5_11482 singh-m-good-morning-asia-d1 — Good Morning Asia prior-candle continuation (D1, USDJPY)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11482 singh-m-good-morning-asia-d1
// -----------------------------------------------------------------------------
// Source: Mario Singh, "17 Proven Currency Trading Strategies" (Wiley, 2013),
//         Strategy 17 "Good Morning Asia". Card:
//         artifacts/cards_approved/QM5_11482_singh-m-good-morning-asia-d1.md
//         (g0_status APPROVED).
//
// Concept: The Asian session opens after the US close. When the prior daily
// (NY-Close DWX D1) candle closed bullish, the Asian session tends to continue
// the bullish sentiment; bearish prior candle -> bearish continuation. USDJPY
// is the canonical pair (Japan is the first major Asian market). The entry is a
// fixed-time market order at the open of the new D1 bar — which, on the DWX
// NY-Close calendar, IS the start of the new trading day / the Asian-session
// open. The D1 bar boundary is therefore the broker-time session boundary; no
// intraday window is needed.
//
// Mechanics (D1-native, closed-bar reads at shift 1):
//   Direction STATE  : sign of the prior daily candle body, close[1] vs open[1].
//                      bullish (close>open) -> LONG ; bearish (close<open) -> SHORT.
//                      A doji (close==open) is skipped (no continuation signal).
//   Trigger EVENT    : a new D1 bar opened (the framework QM_IsNewBar gate) and
//                      no position is currently open for this magic. This is the
//                      SINGLE event — the direction is a pre-existing state, so
//                      there is no two-cross-same-bar trap.
//   Stop distance    : long  : open[0] - low[1]   (prior day's Low)
//                      short : high[1] - open[0]   (prior day's High)
//                      clamped to [min_sl_pips, max_sl_pips]; if the RAW (pre-clamp)
//                      stop distance exceeds skip_above_pips the setup is skipped
//                      (prior range too wide for the asymmetric 2:1 target).
//   Take profit      : tp_ratio * stop_distance (default 0.5 = 2:1 risk:reward,
//                      Singh's intentionally asymmetric high-win-rate target).
//   Time stop        : if a position survives to the NEXT new D1 bar (it did not
//                      hit TP or SL within ~24h), close it at that bar's open.
//   Spread guard     : block only a genuinely wide spread (fail-open on the .DWX
//                      zero-modeled-spread tester).
//
// Pip scaling: USDJPY is a JPY pair (1 pip = 0.01) on a 5-digit broker
// (point = 0.001), so 1 pip = 10 points. All pip thresholds are converted to a
// price distance via QM_StopRulesPipsToPriceDistance (scale-correct), never raw
// points.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11482;
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
input double strategy_tp_ratio          = 0.5;    // TP distance = ratio * stop distance (0.5 => 2:1 RR)
input double strategy_min_sl_pips       = 30.0;   // minimum stop distance (Singh: 30 pips floor)
input double strategy_max_sl_pips       = 80.0;   // P2 cap on stop distance (clamp)
input double strategy_skip_above_pips   = 160.0;  // skip setup if RAW prior-range stop > this (too wide for 2:1)
input bool   strategy_skip_doji         = true;   // skip when prior candle body is flat (close==open)
input double strategy_spread_cap_pips   = 25.0;   // block only a genuinely wider spread (fail-open on .DWX)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — defer, do not block

   const double spread = ask - bid;
   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread_cap > 0.0 && spread > spread_cap)
      return true;

   return false;
  }

// D1 prior-candle continuation entry. Caller guarantees QM_IsNewBar() == true on
// the current (D1) timeframe, so this fires once at the open of each new D1 bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Current/prior D1 OHLC. perf-allowed: bespoke candle-direction and
   //     prior-extreme stop logic the QM readers do not cover; one bounded
   //     two-bar read inside the framework's closed-bar entry hook.
   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied = CopyRates(_Symbol, _Period, 0, 2, bars); // perf-allowed: bounded two-bar OHLC read after QM_IsNewBar gate
   if(copied != 2)
      return false;

   const double open0  = bars[0].open;
   const double open1  = bars[1].open;
   const double close1 = bars[1].close;
   const double high1  = bars[1].high;
   const double low1   = bars[1].low;
   if(open0 <= 0.0)
      return false;
   if(open1 <= 0.0 || close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;

   // --- Direction STATE: sign of the prior candle body ---
   QM_OrderType dir;
   if(close1 > open1)
      dir = QM_BUY;        // bullish prior candle -> continuation long
   else if(close1 < open1)
      dir = QM_SELL;       // bearish prior candle -> continuation short
   else
     {
      if(strategy_skip_doji)
         return false;     // flat body -> no continuation signal
      return false;
     }

   // --- Entry price: market at the new D1 bar open. ---
   const double entry = (dir == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // --- Raw stop distance from prior-day structure (Low for long / High for short). ---
   double raw_sl_dist = (dir == QM_BUY) ? (open0 - low1) : (high1 - open0);
   if(raw_sl_dist <= 0.0)
      return false; // entry already beyond the prior extreme — no valid stop

   // Convert pip thresholds to price distances (scale-correct for JPY 5-digit).
   const double min_sl_dist  = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_min_sl_pips);
   const double max_sl_dist  = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_max_sl_pips);
   const double skip_sl_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_skip_above_pips);
   if(min_sl_dist <= 0.0 || max_sl_dist <= 0.0 || skip_sl_dist <= 0.0)
      return false;

   // Skip setups whose RAW prior-range stop is too wide for the asymmetric target.
   if(raw_sl_dist > skip_sl_dist)
      return false;

   // Clamp the stop distance into [min, max].
   double sl_dist = raw_sl_dist;
   if(sl_dist < min_sl_dist)
      sl_dist = min_sl_dist;
   if(sl_dist > max_sl_dist)
      sl_dist = max_sl_dist;

   const double tp_dist = strategy_tp_ratio * sl_dist;
   if(tp_dist <= 0.0)
      return false;

   double sl_price, tp_price;
   if(dir == QM_BUY)
     {
      sl_price = open0 - sl_dist;
      tp_price = open0 + tp_dist;
     }
   else
     {
      sl_price = open0 + sl_dist;
      tp_price = open0 - tp_dist;
     }

   sl_price = QM_StopRulesNormalizePrice(_Symbol, sl_price);
   tp_price = QM_StopRulesNormalizePrice(_Symbol, tp_price);
   if(sl_price <= 0.0 || tp_price <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;       // framework fills market price at send
   req.sl     = sl_price;
   req.tp     = tp_price;
   req.reason = (dir == QM_BUY) ? "gm_asia_cont_long" : "gm_asia_cont_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// No active trade management; the fixed SL/TP and the time stop carry the trade.
void Strategy_ManageOpenPosition()
  {
  }

// Time stop: called only after OnTick latches a NEW D1 bar with QM_IsNewBar().
// Any still-open position for this magic has survived the prior D1 bar without
// hitting TP or SL, so close it at the new bar open.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return (2026-07-02 audit rule; must be the first statement in OnTick).
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

   const bool new_bar = QM_IsNewBar();

   // Management, the time-stop exit and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order).
   Strategy_ManageOpenPosition();

   if(new_bar && Strategy_ExitSignal())
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

   if(!new_bar)
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
