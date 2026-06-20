#property strict
#property version   "5.0"
#property description "QM5_11524 ciurea-ema200-price-cross-m30 - EMA(200) price cross (M30)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_11524 ciurea-ema200-price-cross-m30
// -----------------------------------------------------------------------------
// Source: Cristina Ciurea, "The Truth Behind Commonly Used Indicators",
//   ScientificForex.com, ~2012. Card:
//   artifacts/cards_approved/QM5_11524_ciurea-ema200-price-cross-m30.md
//   (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; M30; one position per magic):
//   Trigger EVENT (LONG) : close[1] > EMA200[1]  AND  close[2] <= EMA200[2]
//                          (price just closed above the EMA200 - a single
//                          fresh cross EVENT; the prior-bar side is a STATE,
//                          not a second cross, so no two-cross zero-trade trap).
//   Trigger EVENT (SHORT): close[1] < EMA200[1]  AND  close[2] >= EMA200[2].
//   Direction filter STATE: no new entry on a Friday (card "No Friday entry").
//   Stop  LONG  : (lowest LOW over last 3 closed bars)  - sl_buffer_pips.
//   Stop  SHORT : (highest HIGH over last 3 closed bars) + sl_buffer_pips.
//                 SL distance capped at sl_max_pips (card P2 cap 30 pips).
//   Take profit : 2R from entry (tp_rr * SL distance) via QM_TakeRR.
//   Spread guard: skip only a genuinely wide spread > spread_cap_pips
//                 (fail-open on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11524;
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
input int    strategy_ema_period        = 200;   // EMA(200) cross level on M30
input int    strategy_sl_lookback_bars  = 3;     // 3-bar extreme window for the SL
input int    strategy_sl_buffer_pips    = 3;     // pips beyond the 3-bar extreme
input int    strategy_sl_max_pips       = 30;    // P2 cap on SL distance (pips)
input double strategy_tp_rr             = 2.0;   // TP = 2R (2x SL distance)
input int    strategy_spread_cap_pips   = 12;    // skip only if spread wider than this
input bool   strategy_no_friday_entry   = true;  // card: no Friday entry

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-open on .DWX zero spread
// (ask == bid in the tester) — only a genuinely WIDE spread blocks.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread = ask - bid;
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(cap <= 0.0)
      return false;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > cap)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- No Friday entry (STATE filter, broker-time bar-open of the new bar) ---
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday
         return false;
     }

   // --- EMA(200) price side on the two most recent closed bars. ---
   const int side1 = QM_Sig_Price_Above_MA(_Symbol, _Period, strategy_ema_period, 0.0, 1);
   const int side2 = QM_Sig_Price_Above_MA(_Symbol, _Period, strategy_ema_period, 0.0, 2);
   if(side1 == 0)
      return false;

   // --- Single cross EVENT: price closed across the EMA200 on bar 1. ---
   const bool cross_up   = (side1 > 0 && side2 <= 0);
   const bool cross_down = (side1 < 0 && side2 >= 0);
   if(!cross_up && !cross_down)
      return false;

   const QM_OrderType side = cross_up ? QM_BUY : QM_SELL;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // --- 3-bar extreme for the structural stop (closed bars 1..lookback). ---
   const int lookback = (strategy_sl_lookback_bars > 0) ? strategy_sl_lookback_bars : 3;
   const double structure_stop = QM_StopStructure(_Symbol, side, entry, lookback);
   if(structure_stop <= 0.0)
      return false;

   // SL = extreme +/- buffer pips beyond it (scale-correct pip conversion).
   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
   double sl = (side == QM_BUY) ? (structure_stop - buffer) : (structure_stop + buffer);
   sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   if(sl <= 0.0)
      return false;

   // SL must sit on the protective side of entry, and have positive distance.
   double sl_dist = MathAbs(entry - sl);
   if(sl_dist <= 0.0)
      return false;
   if((side == QM_BUY && sl >= entry) || (side == QM_SELL && sl <= entry))
      return false;

   // --- P2 cap: clamp SL distance to sl_max_pips. ---
   const double max_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_max_pips);
   if(max_dist > 0.0 && sl_dist > max_dist)
     {
      sl = (side == QM_BUY) ? (entry - max_dist) : (entry + max_dist);
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      sl_dist = MathAbs(entry - sl);
     }

   // --- TP = 2R (tp_rr * SL distance) from entry. ---
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = cross_up ? "ema200_cross_up" : "ema200_cross_down";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Fixed SL/TP only — no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the structural SL / 2R TP.
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
