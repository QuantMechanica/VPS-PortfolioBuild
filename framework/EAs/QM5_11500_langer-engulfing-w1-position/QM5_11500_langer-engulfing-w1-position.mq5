#property strict
#property version   "5.0"
#property description "QM5_11500 langer-engulfing-w1-position — Weekly engulfing position trade (W1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11500 langer-engulfing-w1-position
// -----------------------------------------------------------------------------
// Source: Paul Langer, "The Black Book of Forex Trading" (Alura/CreateSpace,
// 2015), position-trading strategy "Big Bulls and Bears".
// Card: artifacts/cards_approved/QM5_11500_langer-engulfing-w1-position.md
//       (g0_status APPROVED).
//
// Mechanics (W1 position trade, closed-bar reads at shifts 1 & 2):
//   Trigger EVENT : the LAST COMPLETED weekly bar (shift 1) is an engulfing bar
//                   that swallows the prior week (shift 2) on all four extremes
//                   AND the body engulfs the prior body in the same direction.
//                     Bullish: h1>h2 && l1<l2 && c1>o1 && o1<c2 && c1>o2
//                     Bearish: h1>h2 && l1<l2 && c1<o1 && o1>c2 && c1<o2
//   Trend STATE   : (optional) price vs a long SMA on W1 — only take longs when
//                   close1 >= SMA(trend), shorts when close1 <= SMA(trend).
//                   Disabled by default (qm_trend_filter_enabled=false) so the
//                   pure pattern is the P2 baseline; P3 can sweep it on.
//   Entry         : pending STOP order beyond the engulfing extreme —
//                     BuyStop  at h1 + entry_offset_pips  (bullish)
//                     SellStop at l1 - entry_offset_pips  (bearish)
//                   placed ONCE on the new W1 bar; expires after ~1 week so a
//                   stale signal self-cancels ("signal valid this week only").
//   Stop loss     : opposite extreme of the engulfing candle (long=l1, short=h1)
//                   capped to qm_sl_cap_pips (W1 candles can be huge).
//   Take profit   : entry +/- tp_candle_mult * candle_size  (candle_size=h1-l1).
//   Break-even    : once price has moved be_trigger_frac * candle_size in favour,
//                   move SL to entry (Langer 50%-of-candle BE rule).
//
// .DWX correctness notes:
//   - The engulfing pattern is bespoke structural price action; the QM indicator
//     readers do not cover it. The shift 1/2 OHLC reads below are documented
//     `perf-allowed` closed-bar reads, gated to one evaluation per closed W1 bar.
//   - CFDs are gapless (open[0]==close[1]); we reference the prior CLOSE/BODY via
//     o1/c1/o2/c2, never a true price gap.
//   - The engulfing bar is the SINGLE event; the stop fill is the broker's job —
//     no two-cross-same-bar trap.
//   - W1 is testable in the .DWX tester (MN1 is not).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11500;
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
// Position trade — holds span weeks, so Friday-close MUST stay OFF or it would
// flatten every open W1 position each Friday and destroy the edge. Flagged.
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input double strategy_entry_offset_pips  = 5.0;    // stop placed this far beyond the engulfing extreme
input double strategy_tp_candle_mult     = 1.5;    // TP = entry +/- mult * (h1-l1)
input double strategy_sl_cap_pips        = 200.0;  // P2 cap on the engulfing-extreme stop distance
input double strategy_be_trigger_frac    = 0.5;    // move SL to BE after this fraction of candle in favour
input bool   strategy_trend_filter_on    = false;  // require close vs long SMA agreement (P3 sweep)
input int    strategy_trend_sma_period   = 40;     // long W1 SMA for the trend STATE filter
input int    strategy_signal_expiry_weeks = 1;     // pending order lifetime in weeks (stale-signal cancel)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. No spread guard needed for a W1 pending-stop entry
// (broker fills at the stop price); nothing to block here.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// pip size (price distance of one pip), scale-correct on 5-digit / JPY symbols.
double LangerPipSize()
  {
   // One pip = 10 points on 3/5-digit symbols, 1 point otherwise.
   return QM_StopRulesPipsToPriceDistance(_Symbol, 1);
  }

// TRUE if this EA's magic already has an open position OR a live pending order on
// this symbol — so we never stack a second engulfing entry.
bool LangerHasWorkingExposure(const int magic)
  {
   if(QM_TM_OpenPositionCount(magic) > 0)
      return true;

   const int total = OrdersTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      return true; // a pending stop order from a prior week is still working
     }
   return false;
  }

// Entry: detect a completed W1 engulfing bar and arm a pending stop beyond its
// extreme. Caller guarantees QM_IsNewBar() == true (one call per new closed W1
// bar), so this evaluates the engulfing pattern exactly once per week.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   if(LangerHasWorkingExposure(magic))
      return false;

   // --- Closed-bar OHLC of the last two completed weekly bars (perf-allowed:
   //     bespoke structural pattern, single read per closed W1 bar). ---
   const double h1 = iHigh(_Symbol, PERIOD_W1, 1);  // perf-allowed
   const double l1 = iLow(_Symbol, PERIOD_W1, 1);   // perf-allowed
   const double o1 = iOpen(_Symbol, PERIOD_W1, 1);  // perf-allowed
   const double c1 = iClose(_Symbol, PERIOD_W1, 1); // perf-allowed
   const double h2 = iHigh(_Symbol, PERIOD_W1, 2);  // perf-allowed
   const double l2 = iLow(_Symbol, PERIOD_W1, 2);   // perf-allowed
   const double o2 = iOpen(_Symbol, PERIOD_W1, 2);  // perf-allowed
   const double c2 = iClose(_Symbol, PERIOD_W1, 2); // perf-allowed
   if(h1 <= 0.0 || l1 <= 0.0 || o1 <= 0.0 || c1 <= 0.0 ||
      h2 <= 0.0 || l2 <= 0.0 || o2 <= 0.0 || c2 <= 0.0)
      return false;

   // Outer engulf on all four extremes (range of prior week fully swallowed).
   const bool outer_engulf = (h1 > h2 && l1 < l2);
   if(!outer_engulf)
      return false;

   // Body-engulf in the bar's own direction.
   const bool bullish = (c1 > o1 && o1 < c2 && c1 > o2);
   const bool bearish = (c1 < o1 && o1 > c2 && c1 < o2);
   if(!bullish && !bearish)
      return false;

   const double candle_size = h1 - l1;
   if(candle_size <= 0.0)
      return false;

   const double pip = LangerPipSize();
   if(pip <= 0.0)
      return false;

   const double offset   = strategy_entry_offset_pips * pip;
   const double tp_dist  = strategy_tp_candle_mult * candle_size;
   const double sl_cap   = strategy_sl_cap_pips * pip;

   // Optional trend STATE filter: only trade in the SMA-agreeing direction.
   if(strategy_trend_filter_on)
     {
      const double sma = QM_SMA(_Symbol, PERIOD_W1, strategy_trend_sma_period, 1);
      if(sma <= 0.0)
         return false;
      if(bullish && !(c1 >= sma))
         return false;
      if(bearish && !(c1 <= sma))
         return false;
     }

   double entry = 0.0;
   double sl    = 0.0;
   double tp    = 0.0;

   if(bullish)
     {
      entry = h1 + offset;                 // BuyStop above the engulfing high
      sl    = l1;                          // engulfing low
      if((entry - sl) > sl_cap)            // cap a huge W1 stop
         sl = entry - sl_cap;
      tp    = entry + tp_dist;
      req.type = QM_BUY_STOP;
     }
   else // bearish
     {
      entry = l1 - offset;                 // SellStop below the engulfing low
      sl    = h1;                          // engulfing high
      if((sl - entry) > sl_cap)
         sl = entry + sl_cap;
      tp    = entry - tp_dist;
      req.type = QM_SELL_STOP;
     }

   if(entry <= 0.0 || sl <= 0.0 || tp <= 0.0)
      return false;

   // Stale-signal lifetime: pending order valid for this week only.
   int weeks = strategy_signal_expiry_weeks;
   if(weeks < 1)
      weeks = 1;

   req.price  = QM_TM_NormalizePrice(_Symbol, entry);
   req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
   req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
   req.reason = bullish ? "langer_w1_engulf_long" : "langer_w1_engulf_short";
   req.expiration_seconds = weeks * 7 * 24 * 60 * 60;
   return true;
  }

// Break-even management: once price has run be_trigger_frac * candle_size in our
// favour, move SL to entry. candle_size is re-derived from the engulfing bar
// that is still the last-but-one closed W1 bar relative to entry; we approximate
// it from the position's open price and the current SL/TP geometry instead, to
// avoid depending on a specific bar shift after the hold spans several weeks.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double tp         = PositionGetDouble(POSITION_TP);
      const double cur_sl     = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || tp <= 0.0)
         continue;

      // TP = entry +/- tp_candle_mult*candle_size  ⇒  candle_size implied below.
      const double tp_dist = MathAbs(tp - open_price);
      if(tp_dist <= 0.0 || strategy_tp_candle_mult <= 0.0)
         continue;
      const double candle_size = tp_dist / strategy_tp_candle_mult;
      const double be_move = strategy_be_trigger_frac * candle_size;
      if(be_move <= 0.0)
         continue;

      if(ptype == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0)
            continue;
         if(bid - open_price >= be_move && (cur_sl < open_price || cur_sl == 0.0))
            QM_TM_MoveSL(ticket, open_price, "langer_be");
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0)
            continue;
         if(open_price - ask >= be_move && (cur_sl > open_price || cur_sl == 0.0))
            QM_TM_MoveSL(ticket, open_price, "langer_be");
        }
     }
  }

// Fixed SL/TP carry the trade; no discretionary exit beyond break-even.
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
