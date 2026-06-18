#property strict
#property version   "5.0"
#property description "QM5_11525 ciurea-stoch1435-bounce-h4 — Stoch(14,3,5) OB/OS bounce (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11525 ciurea-stoch1435-bounce-h4
// -----------------------------------------------------------------------------
// Source: Cristina Ciurea, "The Truth Behind Commonly Used Indicators",
//         ScientificForex.com, ~2012.
// Card: artifacts/cards_approved/QM5_11525_ciurea-stoch1435-bounce-h4.md
//       (g0_status APPROVED).
//
// Mechanics (H4, closed-bar reads at shift 1; %K = MODE_MAIN = buffer 0):
//   Stochastic params : K=14, D=3, slowing=5 (card "Stochastic(14,3,5)" →
//                       iStochastic(...,14,3,5,...) = Kperiod,Dperiod,slowing).
//   Trigger EVENT LONG : %K crosses UP through the oversold level (was <= OS on
//                        the prior closed bar, now > OS). One fresh cross/bar.
//   Trigger EVENT SHORT: %K crosses DOWN through the overbought level (was >= OB
//                        on the prior closed bar, now < OB). One fresh cross/bar.
//   The cross IS the single entry event — there is no second cross requirement,
//   so the two-cross-same-bar zero-trade trap does not apply here.
//   Stop  LONG : (3-bar low extreme) - 3 pips.
//   Stop  SHORT: (3-bar high extreme) + 3 pips.
//   Take       : 2R (TP distance = 2 × SL distance) via QM_TakeRR.
//   No-trade   : Friday entries blocked; only a genuinely wide spread blocks
//                (fail-open on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11525;
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
input int    strategy_stoch_k_period    = 14;    // Stochastic %K period
input int    strategy_stoch_d_period    = 3;     // Stochastic %D (signal) period
input int    strategy_stoch_slowing     = 5;     // Stochastic slowing
input double strategy_oversold_level    = 20.0;  // oversold threshold (long cross-up)
input double strategy_overbought_level  = 80.0;  // overbought threshold (short cross-down)
input int    strategy_sl_lookback_bars  = 3;     // bars for the structural SL extreme
input int    strategy_sl_buffer_pips    = 3;     // pips beyond the 3-bar extreme
input double strategy_tp_rr             = 2.0;   // TP distance = rr × SL distance
input bool   strategy_block_friday      = true;  // no new entries on Friday
input double strategy_spread_cap_pips   = 15.0;  // skip if real spread > this many pips

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Friday block + spread guard only. Fail-open on the
// .DWX zero modeled spread; only a genuinely wide spread blocks.
bool Strategy_NoTradeFilter()
  {
   // No new entries on Friday (card: "No Friday entry").
   if(strategy_block_friday)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday
         return true;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   // Zero/invalid price → do not block; zero spread on .DWX must NOT fail-closed.
   if(ask > 0.0 && bid > 0.0 && ask > bid)
     {
      const double spread     = ask - bid;
      const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
      if(spread_cap > 0.0 && spread > spread_cap)
         return true; // genuinely wide spread — block
     }

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate). The %K cross
// out of the OB/OS zone is the single trigger EVENT.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // %K (MODE_MAIN) on the two most-recent closed bars.
   const double k_now  = QM_Stoch_K(_Symbol, _Period,
                                    strategy_stoch_k_period, strategy_stoch_d_period,
                                    strategy_stoch_slowing, 1);
   const double k_prev = QM_Stoch_K(_Symbol, _Period,
                                    strategy_stoch_k_period, strategy_stoch_d_period,
                                    strategy_stoch_slowing, 2);
   if(k_now <= 0.0 || k_prev <= 0.0)
      return false;

   // Fresh cross UP through the oversold level → LONG (oversold bounce).
   const bool cross_up_os   = (k_prev <= strategy_oversold_level &&
                               k_now  >  strategy_oversold_level);
   // Fresh cross DOWN through the overbought level → SHORT (overbought drop).
   const bool cross_down_ob = (k_prev >= strategy_overbought_level &&
                               k_now  <  strategy_overbought_level);

   if(!cross_up_os && !cross_down_ob)
      return false;

   const QM_OrderType side = cross_up_os ? QM_BUY : QM_SELL;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // Structural stop: 3-bar extreme, then nudge buffer pips beyond it.
   double sl = QM_StopStructure(_Symbol, side, entry, strategy_sl_lookback_bars);
   if(sl <= 0.0)
      return false;

   const double buffer_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
   if(buffer_dist > 0.0)
     {
      // LONG stop sits below the low → push it further down; SHORT above → up.
      sl = (side == QM_BUY) ? (sl - buffer_dist) : (sl + buffer_dist);
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
     }
   if(sl <= 0.0)
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0; // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "stoch_os_bounce_long" : "stoch_ob_bounce_short";
   return true;
  }

// Fixed SL/TP only — no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit; SL/TP (2R) handle the trade.
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
