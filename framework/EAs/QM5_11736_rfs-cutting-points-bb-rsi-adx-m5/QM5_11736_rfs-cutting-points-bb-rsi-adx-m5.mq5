#property strict
#property version   "5.0"
#property description "QM5_11736 rfs-cutting-points-bb-rsi-adx-m5 — BB+RSI+ADX mean-reversion scalp (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11736 rfs-cutting-points-bb-rsi-adx-m5
// -----------------------------------------------------------------------------
// Source: Anonymous, "Cutting Points", Robo-forex Strategy Compilation,
//   robofx.com ~2015 (PDF 362359657-Robo-forex-strategy.pdf pp.17-18).
// Card: artifacts/cards_approved/QM5_11736_rfs-cutting-points-bb-rsi-adx-m5.md
//   (g0_status APPROVED).
//
// Concept: mean-reversion scalp in calm/ranging markets on M5. Price over-
//   extends to a Bollinger outer band, RSI confirms the extreme, ADX confirms
//   a non-trending (flat) regime, and the position is taken when price RETURNS
//   back inside the band (the "cutting point").
//
// Mechanics (closed-bar reads; shift 1 = last closed bar, shift 2 = bar before):
//   Trigger EVENT (the ONE event):
//     LONG : close[2] <= BB_lower[2]  AND  close[1] > BB_lower[1]
//            (price was at/below the lower band, then closed back inside).
//     SHORT: close[2] >= BB_upper[2]  AND  close[1] < BB_upper[1].
//   Confirming STATES (read on the over-extension bar shift 2, regime on shift 1):
//     LONG : RSI[2] < rsi_oversold   AND  ADX[1] < adx_cap.
//     SHORT: RSI[2] > rsi_overbought AND  ADX[1] < adx_cap.
//   Stop  : LONG  = BB_lower[1] - sl_buffer_pips  (below the band).
//           SHORT = BB_upper[1] + sl_buffer_pips  (above the band).
//   Take  : BB_middle[1] (mean-reversion target = SMA20 mid band).
//   Exit  : managed by SL/TP only; no separate discretionary exit.
//
// Two-cross trap avoided: the band re-entry is the single EVENT; RSI side and
// ADX regime are STATES (a level read, not a fresh cross). SL/TP are PRICES.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11736;
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
input int    strategy_bb_period          = 20;     // Bollinger Band period (SMA basis)
input double strategy_bb_deviation       = 2.0;    // Bollinger Band std-dev multiple
input int    strategy_rsi_period         = 7;      // RSI lookback period
input double strategy_rsi_oversold       = 30.0;   // long: RSI on over-extension bar below this
input double strategy_rsi_overbought     = 70.0;   // short: RSI on over-extension bar above this
input int    strategy_adx_period         = 14;     // ADX period (regime filter)
input double strategy_adx_cap            = 30.0;   // only trade when ADX below this (flat/ranging)
input int    strategy_sl_buffer_pips     = 3;      // SL buffer beyond the BB band, in pips

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. No spread guard required on .DWX (zero modeled
// spread); regime/signal work lives on the closed-bar path in EntrySignal.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Mean-reversion entry. Caller guarantees QM_IsNewBar() == true (closed-bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Bollinger bands at the just-closed bar (shift 1) and prior (shift 2) ---
   const double bb_lo_1  = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_up_1  = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_mid_1 = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_lo_2  = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2);
   const double bb_up_2  = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2);
   if(bb_lo_1 <= 0.0 || bb_up_1 <= 0.0 || bb_mid_1 <= 0.0 || bb_lo_2 <= 0.0 || bb_up_2 <= 0.0)
      return false;

   // --- Closed-bar closes (single closed-bar reads) ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   // --- Regime STATE: ADX below cap => flat / non-trending ---
   const double adx1 = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(adx1 <= 0.0)
      return false;
   if(!(adx1 < strategy_adx_cap))
      return false;

   // --- RSI STATE on the over-extension bar (shift 2) ---
   const double rsi2 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   if(rsi2 <= 0.0)
      return false;

   const double sl_buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);

   // --- LONG: over-extended below lower band, RSI oversold, return inside ---
   //     EVENT  : close[2] <= lower[2]  (outside)  AND  close[1] > lower[1] (returned)
   //     STATES : RSI[2] < oversold     AND  ADX[1] < cap
   const bool long_outside = (close2 <= bb_lo_2);
   const bool long_return  = (close1 >  bb_lo_1);
   if(long_outside && long_return && rsi2 < strategy_rsi_oversold)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, bb_lo_1 - sl_buffer);
      const double tp = QM_StopRulesNormalizePrice(_Symbol, bb_mid_1);
      // Sanity: TP above entry above SL for a long.
      if(!(sl > 0.0 && sl < entry && tp > entry))
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "cutting_points_long";
      return true;
     }

   // --- SHORT: over-extended above upper band, RSI overbought, return inside ---
   const bool short_outside = (close2 >= bb_up_2);
   const bool short_return  = (close1 <  bb_up_1);
   if(short_outside && short_return && rsi2 > strategy_rsi_overbought)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, bb_up_1 + sl_buffer);
      const double tp = QM_StopRulesNormalizePrice(_Symbol, bb_mid_1);
      // Sanity: TP below entry below SL for a short.
      if(!(sl > entry && tp > 0.0 && tp < entry))
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "cutting_points_short";
      return true;
     }

   return false;
  }

// No active management beyond the fixed band-anchored SL / mid-band TP.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit; SL/TP carry the trade (TP = BB mid band).
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
