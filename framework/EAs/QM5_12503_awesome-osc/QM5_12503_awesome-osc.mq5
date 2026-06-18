#property strict
#property version   "5.0"
#property description "QM5_12503 awesome-osc — Awesome Oscillator zero-line cross momentum (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12503 awesome-osc
// -----------------------------------------------------------------------------
// Source: je-suis-tm, quant-trading, "Awesome Oscillator backtest.py" (GitHub).
//   https://github.com/je-suis-tm/quant-trading/blob/master/Awesome%20Oscillator%20backtest.py
// Card: artifacts/cards_approved/QM5_12503_awesome-osc.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; default D1):
//   AO definition: AO = SMA(fast=5, median price) - SMA(slow=34, median price),
//                  median price = (High+Low)/2 == PRICE_MEDIAN. Computed in-EA
//                  via QM_SMA(..., PRICE_MEDIAN) (no QM_AO helper exists).
//   Base rule    : long when AO_fast > AO_slow (AO > 0), short when AO_fast <
//                  AO_slow (AO < 0). The sign change is the EVENT — a fresh
//                  zero-line cross (ao_prev<=0 -> ao_now>0 for long, and the
//                  mirror for short). One cross EVENT per bar; we never require
//                  two cross events on the same bar (zero-trade trap avoided).
//   Saucer mode  : optional early trigger from the source (saucer_mode input).
//                  LONG saucer: two prior bearish AO bars then a bullish AO bar,
//                  AO positive, and the prior AO bar lower than the one before.
//                  SHORT saucer: two prior bullish AO bars then a bearish bar,
//                  AO negative, prior AO bar higher than the one before. When
//                  saucer mode is on the saucer is the trigger EVENT (still one
//                  per bar); the zero-cross remains available as a fallback.
//   Exit/reverse : close when the opposite AO state appears (sign flips against
//                  the open position). One event per bar; reversal happens on
//                  the next bar's fresh entry signal.
//   Stop         : emergency stop = atr_stop_mult * ATR(atr_period) from entry
//                  (the source defines no price stop; swept in Q03).
//   Take profit  : RR multiple of the stop distance (tp_rr; 0 disables).
//   Spread guard : block only a genuinely wide spread (fail-open on .DWX zero).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12503;
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
input int    strategy_ao_fast_period    = 5;      // Awesome Oscillator fast SMA (median price)
input int    strategy_ao_slow_period    = 34;     // Awesome Oscillator slow SMA (median price)
input bool   strategy_saucer_mode       = false;  // enable early saucer trigger (else pure zero-cross)
input int    strategy_atr_period        = 20;     // ATR period for the emergency stop
input double strategy_atr_stop_mult     = 3.0;    // emergency stop = mult * ATR from entry
input double strategy_tp_rr             = 0.0;    // take-profit RR multiple of stop (0 = no TP)
input double strategy_spread_cap_pips   = 3.0;    // skip genuinely wide spread (cap in pips)

// -----------------------------------------------------------------------------
// AO helper — Awesome Oscillator on the median price at a given closed-bar shift.
// AO = SMA(fast, median) - SMA(slow, median). PRICE_MEDIAN == (High+Low)/2.
// -----------------------------------------------------------------------------
double AO_Value(const int shift)
  {
   const double fast = QM_SMA(_Symbol, _Period, strategy_ao_fast_period, shift, PRICE_MEDIAN);
   const double slow = QM_SMA(_Symbol, _Period, strategy_ao_slow_period, shift, PRICE_MEDIAN);
   return fast - slow;
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

   const double spread = ask - bid;
   const double cap    = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && cap > 0.0 && spread > cap)
      return true;

   return false;
  }

// Long saucer per the source: AO positive, current AO bar bullish (rising) after
// two prior bearish (falling) AO bars, and the prior AO bar lower than the one
// before it. Reads closed AO bars at shifts 1..4.
bool AO_SaucerLong(const double ao1, const double ao2, const double ao3, const double ao4)
  {
   const bool bull_now   = (ao1 > ao2);   // current AO bar rising
   const bool bear_prev1 = (ao2 < ao3);   // prior AO bar falling
   const bool bear_prev2 = (ao3 < ao4);   // bar before that falling
   const bool ao_pos     = (ao1 > 0.0);
   const bool prior_lower = (ao2 < ao3);  // prior AO bar lower than the one before
   return (ao_pos && bull_now && bear_prev1 && bear_prev2 && prior_lower);
  }

// Short saucer: mirror of the long saucer.
bool AO_SaucerShort(const double ao1, const double ao2, const double ao3, const double ao4)
  {
   const bool bear_now   = (ao1 < ao2);   // current AO bar falling
   const bool bull_prev1 = (ao2 > ao3);   // prior AO bar rising
   const bool bull_prev2 = (ao3 > ao4);   // bar before that rising
   const bool ao_neg     = (ao1 < 0.0);
   const bool prior_higher = (ao2 > ao3); // prior AO bar higher than the one before
   return (ao_neg && bear_now && bull_prev1 && bull_prev2 && prior_higher);
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Awesome Oscillator at the last closed bars ---
   const double ao1 = AO_Value(1);
   const double ao2 = AO_Value(2);
   const double ao3 = AO_Value(3);
   const double ao4 = AO_Value(4);

   // --- Base trigger EVENT: fresh AO zero-line cross. One event per bar; the
   //     opposite sign is the STATE, so we never require two cross events. ---
   const bool ao_cross_up   = (ao2 <= 0.0 && ao1 > 0.0);
   const bool ao_cross_down = (ao2 >= 0.0 && ao1 < 0.0);

   bool long_signal  = ao_cross_up;
   bool short_signal = ao_cross_down;

   // --- Optional saucer EVENT (still one per bar). When enabled it augments the
   //     zero-cross trigger; either may fire on a given closed bar. ---
   if(strategy_saucer_mode)
     {
      if(AO_SaucerLong(ao1, ao2, ao3, ao4))
         long_signal = true;
      if(AO_SaucerShort(ao1, ao2, ao3, ao4))
         short_signal = true;
     }

   QM_OrderType side;
   if(long_signal && !short_signal)
      side = QM_BUY;
   else if(short_signal && !long_signal)
      side = QM_SELL;
   else
      return false; // no signal, or conflicting signals on the same bar

   // --- Entry price ---
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // --- Emergency stop: atr_stop_mult * ATR from entry (source has no price stop). ---
   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_stop_mult);
   if(sl <= 0.0)
      return false;
   // Stop must sit on the correct side of entry.
   if(side == QM_BUY && !(sl < entry))
      return false;
   if(side == QM_SELL && !(sl > entry))
      return false;

   // --- Optional take profit: RR multiple of the stop distance (0 disables). ---
   double tp = 0.0;
   if(strategy_tp_rr > 0.0)
     {
      tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;
     }

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "ao_long" : "ao_short";
   return true;
  }

// No active trade management beyond the fixed ATR stop / optional RR target.
// The AO reversal exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Reversal exit: close when the opposite AO state appears against the open
// position (AO sign flipped). One state read per bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ao1 = AO_Value(1);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && ao1 < 0.0)
         return true;   // long but AO turned negative
      if(ptype == POSITION_TYPE_SELL && ao1 > 0.0)
         return true;   // short but AO turned positive
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
