#property strict
#property version   "5.0"
#property description "QM5_11419 144-lwma-5smma-proximity-crossover-m5 — LWMA144/SMMA5 cross + proximity (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11419 144-lwma-5smma-proximity-crossover-m5
// -----------------------------------------------------------------------------
// Source: "144 Trend Shift Scalping Forex Trading Strategy" (anonymous local PDF).
// Card: artifacts/cards_approved/QM5_11419_144-lwma-5smma-proximity-crossover-m5.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads; shift 1 = last closed bar, shift 2 = prior):
//   Trigger EVENT (single) : 5-SMMA crosses the 144-LWMA on the last closed bar.
//       LONG  : SMMA5[2] <= LWMA144[2] AND SMMA5[1] >  LWMA144[1]
//       SHORT : SMMA5[2] >= LWMA144[2] AND SMMA5[1] <  LWMA144[1]
//     This is the ONLY event. Per .DWX invariant #4 we never require two cross
//     events on the same bar — the proximity filter below is a STATE, not a 2nd
//     event, so the EA does not fall into the zero-trade two-cross trap.
//   Proximity STATE        : |Close[1] - LWMA144[1]| <= proximity_pips (in pips,
//       scale-correct via QM_StopRulesPipsToPriceDistance). Keeps entries near
//       the trend anchor instead of chasing extended moves.
//   Stop loss              : nearest confirmed fractal low (LONG) / high (SHORT)
//       within the lookback window, then clamped to [min_sl_pips, max_sl_pips].
//   Take profit            : 2:1 R:R off the realised stop distance (QM_TakeRR).
//   One position per magic; no new signal while a position is open.
//   Spread guard           : fail-OPEN on .DWX zero modeled spread; only a
//       genuinely wide spread above the cap blocks.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11419;
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
input int    strategy_lwma_period       = 144;    // slow trend anchor (LWMA)
input int    strategy_smma_period       = 5;      // fast signal line (SMMA)
input int    strategy_proximity_pips    = 10;     // max |Close - LWMA144| at the cross
input int    strategy_sl_lookback_bars  = 15;     // structural-low/high lookback for SL
input int    strategy_min_sl_pips       = 5;      // floor on SL distance (noise guard)
input int    strategy_max_sl_pips       = 20;     // cap on SL distance (card P2 cap)
input double strategy_tp_rr             = 2.0;    // take-profit R:R multiple
input int    strategy_spread_cap_pips   = 15;     // skip only if spread > this many pips

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool FindFractalStop(const QM_OrderType side,
                     const double entry,
                     const int lookback_bars,
                     double &out_stop)
  {
   out_stop = 0.0;
   if(entry <= 0.0 || lookback_bars < 2)
      return false;

   for(int shift = 2; shift <= lookback_bars; shift++)
     {
      const double fractal = QM_OrderTypeIsBuy(side)
                             ? QM_FractalLower(_Symbol, _Period, shift)
                             : QM_FractalUpper(_Symbol, _Period, shift);
      if(fractal <= 0.0)
         continue;
      if(QM_OrderTypeIsBuy(side) && fractal < entry)
        {
         out_stop = fractal;
         return true;
        }
      if(!QM_OrderTypeIsBuy(side) && fractal > entry)
        {
         out_stop = fractal;
         return true;
        }
     }

   return false;
  }

double ClampStopPrice(const QM_OrderType side, const double entry, const double fractal_stop)
  {
   const double min_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_min_sl_pips);
   const double max_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_sl_pips);
   if(entry <= 0.0 || fractal_stop <= 0.0 || min_dist <= 0.0 || max_dist <= 0.0)
      return 0.0;

   double stop_dist = MathAbs(entry - fractal_stop);
   if(stop_dist < min_dist)
      stop_dist = min_dist;
   if(stop_dist > max_dist)
      stop_dist = max_dist;

   const double stop = QM_OrderTypeIsBuy(side) ? (entry - stop_dist) : (entry + stop_dist);
   return QM_StopRulesNormalizePrice(_Symbol, stop);
  }

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread:
// only a genuinely wide spread above the cap blocks.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread = ask - bid;
   if(spread <= 0.0)
      return false; // .DWX zero modeled spread — fail open

   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(cap <= 0.0)
      return false;

   if(spread > cap)
      return true; // genuinely wide spread — block

   return false;
  }

// Closed-bar entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One open position per symbol/magic — no new signal while in a trade.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Indicators on closed bars (shift 1 = last closed, shift 2 = prior) ---
   const double lwma_1 = QM_LWMA(_Symbol, _Period, strategy_lwma_period, 1);  // LWMA144[1]
   const double lwma_2 = QM_LWMA(_Symbol, _Period, strategy_lwma_period, 2);  // LWMA144[2]
   const double smma_1 = QM_SMMA(_Symbol, _Period, strategy_smma_period, 1);  // SMMA5[1]
   const double smma_2 = QM_SMMA(_Symbol, _Period, strategy_smma_period, 2);  // SMMA5[2]
   if(lwma_1 <= 0.0 || lwma_2 <= 0.0 || smma_1 <= 0.0 || smma_2 <= 0.0)
      return false;

   // --- Trigger EVENT (single): SMMA crosses the LWMA on the last closed bar ---
   const bool cross_up   = (smma_2 <= lwma_2 && smma_1 > lwma_1);
   const bool cross_down = (smma_2 >= lwma_2 && smma_1 < lwma_1);
   if(!cross_up && !cross_down)
      return false;

   // --- Proximity STATE: price within proximity_pips of the 144-LWMA ---
   const double close_1 = QM_SMA(_Symbol, _Period, 1, 1, PRICE_CLOSE);
   if(close_1 <= 0.0)
      return false;
   const double prox_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_proximity_pips);
   if(prox_dist <= 0.0)
      return false;
   if(MathAbs(close_1 - lwma_1) > prox_dist)
      return false; // too far from the anchor — skip the late entry

   const QM_OrderType side = cross_up ? QM_BUY : QM_SELL;

   // --- Entry price (next-bar open ~= current market at send) ---
   const double entry = cross_up ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                 : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // --- Stop loss: confirmed fractal low/high, then clamp to [min, max] pips ---
   double fractal_stop = 0.0;
   if(!FindFractalStop(side, entry, strategy_sl_lookback_bars, fractal_stop))
      return false;

   const double sl = ClampStopPrice(side, entry, fractal_stop);
   if(sl <= 0.0)
      return false;

   // --- Take profit: 2:1 R:R off the realised stop distance ---
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = cross_up ? "lwma_smma_cross_long" : "lwma_smma_cross_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Fixed SL/TP only — no active trade management (no trailing per card).
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit — SL/TP handle the trade. (Opposite cross would be a
// new EVENT but the card closes only on SL/TP; one-position-per-magic prevents
// a re-entry while in a trade.)
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
