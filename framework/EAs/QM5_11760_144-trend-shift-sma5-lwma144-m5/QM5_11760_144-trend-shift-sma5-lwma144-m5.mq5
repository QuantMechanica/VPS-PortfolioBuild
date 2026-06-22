#property strict
#property version   "5.0"
#property description "QM5_11760 144-trend-shift-sma5-lwma144-m5 — SMA5/LWMA144 trend-shift scalper (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11760 144-trend-shift-sma5-lwma144-m5
// -----------------------------------------------------------------------------
// Source: Anonymous, "144 Trend Shift Scalping Forex Trading Strategy", ~2019.
// Card: artifacts/cards_approved/QM5_11760_144-trend-shift-sma5-lwma144-m5.md
//       (g0_status: APPROVED). source_id 7977a977-69b4-5432-9af3-a8ebb04c0214.
//
// Mechanics (closed-bar reads at shift 1; one trigger event, no two-cross trap):
//   Trigger EVENT : SMA(5) crosses the LWMA(144) — the trend shift.
//                   Long  : sma5[2] <= lwma144[2] AND sma5[1] > lwma144[1].
//                   Short : sma5[2] >= lwma144[2] AND sma5[1] < lwma144[1].
//                   Exactly ONE cross is the trigger; everything else is a STATE.
//   Proximity STATE: |close[1] - lwma144[1]| <= proximity_pips (pip-scaled).
//                   Reject entries that already ran far from the trend MA.
//   Stop          : most recent confirmed Bill Williams fractal in the last
//                   fractal_lookback closed bars. If no valid fractal exists,
//                   use the card's factory fallback: lowest low / highest high
//                   of the last sl_lookback closed bars.
//   Take profit   : 2R from entry to the structural stop (tp_rr, default 2.0).
//
// One position per symbol/magic. No active management beyond the fixed SL/TP.
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific; the rest is
// framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11760;
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
input int    strategy_sma_period        = 5;     // fast SMA trigger period
input int    strategy_lwma_period       = 144;   // slow LWMA trend-state period
input int    strategy_proximity_pips    = 10;    // max distance of close from LWMA at the cross (pips)
input int    strategy_fractal_lookback  = 20;    // confirmed fractal scan depth for SL
input int    strategy_sl_lookback       = 5;     // bars for the structural stop (lowest low / highest high)
input double strategy_tp_rr             = 2.0;   // take-profit risk multiple (2R)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. No spread guard needed beyond a valid-quote check —
// .DWX quotes ask==bid (zero modeled spread), so any spread test would fail-open
// anyway. Fail-open: return false (allow) whenever quotes are valid.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true; // no valid quote yet — do not trade on it
   return false;
  }

double Strategy_FractalStop(const QM_OrderType side, const double entry)
  {
   if(entry <= 0.0 || strategy_fractal_lookback < 3)
      return 0.0;

   const int scan_to = MathMax(3, strategy_fractal_lookback);
   for(int shift = 3; shift <= scan_to; ++shift)
     {
      const double fractal = (side == QM_BUY)
                             ? QM_FractalLower(_Symbol, _Period, shift)
                             : QM_FractalUpper(_Symbol, _Period, shift);
      if(fractal <= 0.0 || fractal == EMPTY_VALUE)
         continue;
      if(side == QM_BUY && fractal < entry)
         return QM_StopRulesNormalizePrice(_Symbol, fractal);
      if(side == QM_SELL && fractal > entry)
         return QM_StopRulesNormalizePrice(_Symbol, fractal);
     }

   return 0.0;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Trend trigger inputs: SMA(5) and LWMA(144) at the two most recent
   //     closed bars (shift 1 = just-closed bar, shift 2 = bar before). ---
   const double sma_now   = QM_SMA(_Symbol, _Period, strategy_sma_period, 1);
   const double sma_prev  = QM_SMA(_Symbol, _Period, strategy_sma_period, 2);
   const double lwma_now  = QM_LWMA(_Symbol, _Period, strategy_lwma_period, 1);
   const double lwma_prev = QM_LWMA(_Symbol, _Period, strategy_lwma_period, 2);
   if(sma_now <= 0.0 || sma_prev <= 0.0 || lwma_now <= 0.0 || lwma_prev <= 0.0)
      return false;

   // Exactly ONE trigger event per direction — a fresh SMA(5) cross of LWMA(144).
   const bool cross_up   = (sma_prev <= lwma_prev && sma_now > lwma_now);
   const bool cross_down = (sma_prev >= lwma_prev && sma_now < lwma_now);
   if(!cross_up && !cross_down)
      return false;

   // --- Proximity STATE: the just-closed bar's close must be within
   //     proximity_pips of the LWMA(144). Pip-scaled so it is correct on
   //     5-digit FX. This is a state check on the trigger bar, not a 2nd event. ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;
   const double proximity_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_proximity_pips);
   if(proximity_dist <= 0.0)
      return false;
   if(MathAbs(close1 - lwma_now) > proximity_dist)
      return false; // price already ran too far from the trend MA — skip

   const QM_OrderType side = cross_up ? QM_BUY : QM_SELL;

   // --- Entry / stop / take ---
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // Primary stop: most recent confirmed fractal. Fallback: lowest low / highest
   // high of the last sl_lookback closed bars per card.
   double sl = Strategy_FractalStop(side, entry);
   if(sl <= 0.0)
      sl = QM_StopStructure(_Symbol, side, entry, strategy_sl_lookback);
   if(sl <= 0.0)
      return false;
   // Reject a degenerate stop on the wrong side of entry (no risk distance).
   if((side == QM_BUY  && sl >= entry) ||
      (side == QM_SELL && sl <= entry))
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = cross_up ? "trend_shift_long" : "trend_shift_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// No active management beyond the fixed structural stop / 2R target.
void Strategy_ManageOpenPosition()
  {
  }

// No defensive exit signal — exits are SL/TP only.
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
