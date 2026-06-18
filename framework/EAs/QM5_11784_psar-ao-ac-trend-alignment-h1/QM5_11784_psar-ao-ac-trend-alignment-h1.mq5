#property strict
#property version   "5.0"
#property description "QM5_11784 psar-ao-ac-trend-alignment-h1 — PSAR flip + AO/AC alignment (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11784 psar-ao-ac-trend-alignment-h1
// -----------------------------------------------------------------------------
// Source: Anonymous, "Winning Pips System 4" (~2015). Three Bill Williams
//   indicators aligned: Parabolic SAR (trend side), Awesome Oscillator (AO),
//   Accelerator Oscillator (AC).
// Card: artifacts/cards_approved/QM5_11784_psar-ao-ac-trend-alignment-h1.md
//   (g0_status APPROVED).
//
// AO / AC are computed IN-EA from median price ((H+L)/2 == PRICE_MEDIAN):
//   AO[s] = SMA(5, median, s) - SMA(34, median, s)
//   AC[s] = AO[s] - SMA(AO, 5)[s]   (5-period SMA of the AO series)
//
// Two-cross trap (codex_build_ea.md §4): requiring TWO fresh cross EVENTS on the
//   same bar (PSAR flip + AO zero-cross + AC zero-cross) almost never coincides
//   and produces 0 trades. We therefore pick ONE event as the trigger and treat
//   the rest as STATES:
//     Trigger EVENT : PSAR flips side (dot crosses from one side of price to the
//                     other) between the prior closed bar and the last closed bar.
//     Confirm STATE : AO colour aligned with the new PSAR side AND
//                     AC colour aligned with the new PSAR side, on the last
//                     closed bar. ("Green" = histogram rising: X[1] > X[2].)
//   Long  : PSAR flips to BELOW price, AO rising, AC rising.
//   Short : PSAR flips to ABOVE price, AO falling, AC falling.
//
//   Stop  : structural — low of the last closed bar (long) / high (short),
//           with an ATR-derived minimum floor so a too-tight entry-candle stop
//           is widened to a sane distance (card "factory fallback" rule).
//   Take  : 1:1 risk-reward off the actual stop distance (card baseline).
//   Exit  : trend-ride defensive — both AO and AC reverse colour against the
//           open position (card "trend-ride variant" exit).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11784;
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
input double strategy_sar_step          = 0.02;   // Parabolic SAR acceleration step
input double strategy_sar_maximum       = 0.20;   // Parabolic SAR acceleration max
input int    strategy_ao_fast_period    = 5;      // AO fast SMA (median price)
input int    strategy_ao_slow_period    = 34;     // AO slow SMA (median price)
input int    strategy_ac_sma_period     = 5;      // SMA-of-AO period for AC
input int    strategy_sl_struct_lookback = 1;     // bars back for structural SL (entry candle)
input int    strategy_sl_atr_period     = 14;     // ATR period for the SL floor
input double strategy_sl_atr_min_mult   = 1.0;    // min SL distance = mult * ATR (floor)
input double strategy_tp_rr             = 1.0;    // take-profit risk-reward multiple
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// AO / AC helpers — derived oscillators built from QM_SMA on median price.
// All reads are closed-bar (shift >= 1). No raw iX, no CopyBuffer.
// -----------------------------------------------------------------------------

// Awesome Oscillator at a given closed-bar shift.
double AO_At(const int shift)
  {
   const double fast = QM_SMA(_Symbol, _Period, strategy_ao_fast_period, shift, PRICE_MEDIAN);
   const double slow = QM_SMA(_Symbol, _Period, strategy_ao_slow_period, shift, PRICE_MEDIAN);
   return fast - slow;
  }

// Accelerator Oscillator at a given closed-bar shift: AO - SMA(AO, period).
// SMA(AO) is computed by averaging AO over [shift .. shift+period-1].
double AC_At(const int shift)
  {
   const double ao_now = AO_At(shift);
   double sum = 0.0;
   for(int i = 0; i < strategy_ac_sma_period; ++i)
      sum += AO_At(shift + i);
   const double ao_sma = sum / (double)strategy_ac_sma_period;
   return ao_now - ao_sma;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — alignment work is on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_sl_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_min_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// Trigger EVENT = PSAR flip; confirm STATE = AO & AC aligned to the new side.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- PSAR side on the last two closed bars (shift 1 = last, shift 2 = prior) ---
   const double sar_now  = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_maximum, 1);
   const double sar_prev = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_maximum, 2);
   if(sar_now <= 0.0 || sar_prev <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   // PSAR side: below price = bullish, above price = bearish.
   const bool sar_below_now  = (sar_now  < close1);
   const bool sar_below_prev = (sar_prev < close2);

   // Trigger EVENT: a fresh flip between the prior and the last closed bar.
   const bool flip_to_below = (sar_below_now && !sar_below_prev); // bearish -> bullish
   const bool flip_to_above = (!sar_below_now && sar_below_prev); // bullish -> bearish
   if(!flip_to_below && !flip_to_above)
      return false;

   // --- Confirm STATE: AO & AC colour on the last closed bar (rising = green) ---
   const double ao1 = AO_At(1);
   const double ao2 = AO_At(2);
   const double ac1 = AC_At(1);
   const double ac2 = AC_At(2);

   const bool ao_green = (ao1 > ao2); // AO histogram rising
   const bool ao_red   = (ao1 < ao2);
   const bool ac_green = (ac1 > ac2); // AC histogram rising
   const bool ac_red   = (ac1 < ac2);

   bool go_long  = false;
   bool go_short = false;
   if(flip_to_below && ao_green && ac_green)
      go_long = true;
   else if(flip_to_above && ao_red && ac_red)
      go_short = true;

   if(!go_long && !go_short)
      return false;

   const QM_OrderType otype = go_long ? QM_BUY : QM_SELL;

   // --- Structural SL: entry-candle low (long) / high (short), ATR-floored ---
   const double entry = SymbolInfoDouble(_Symbol, otype == QM_BUY ? SYMBOL_ASK : SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_sl_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   double sl = QM_StopStructure(_Symbol, otype, entry, strategy_sl_struct_lookback);
   if(sl <= 0.0)
      return false;

   // Enforce an ATR-based minimum stop distance (card "too tight" fallback).
   const double atr_floor   = strategy_sl_atr_min_mult * atr_value;
   const double struct_dist = MathAbs(entry - sl);
   if(struct_dist < atr_floor)
      sl = QM_StopATRFromValue(_Symbol, otype, entry, atr_value, strategy_sl_atr_min_mult);
   if(sl <= 0.0)
      return false;

   // --- 1:1 TP off the actual stop distance ---
   const double tp = QM_TakeRR(_Symbol, otype, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = go_long ? "psar_ao_ac_long" : "psar_ao_ac_short";
   return true;
  }

// No active management beyond the fixed structural stop / 1:1 target.
// Trend-ride defensive exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Trend-ride defensive exit: BOTH AO and AC reverse colour against the open
// position (per the card trend-ride variant).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine the side of the open position for this magic.
   bool is_long  = false;
   bool is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         is_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         is_short = true;
      break;
     }
   if(!is_long && !is_short)
      return false;

   const double ao1 = AO_At(1);
   const double ao2 = AO_At(2);
   const double ac1 = AC_At(1);
   const double ac2 = AC_At(2);

   const bool ao_red   = (ao1 < ao2);
   const bool ac_red   = (ac1 < ac2);
   const bool ao_green = (ao1 > ao2);
   const bool ac_green = (ac1 > ac2);

   if(is_long  && ao_red   && ac_red)
      return true;  // both oscillators turned against the long
   if(is_short && ao_green && ac_green)
      return true;  // both oscillators turned against the short
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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
