#property strict
#property version   "5.0"
#property description "QM5_11415 winning-pips-psar-ao-ac-h1 — PSAR flip + AO/AC confluence (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11415 winning-pips-psar-ao-ac-h1
// -----------------------------------------------------------------------------
// Source: "Winning Pips System" (fxmiracle.com, anonymous), local PDF.
// Card: artifacts/cards_approved/QM5_11415_winning-pips-psar-ao-ac-h1.md
//       (g0_status APPROVED).
//
// Triple-indicator confluence on H1. All reads on the closed bar (shift >= 1).
//
//   PSAR  : QM_SAR(step, max). Below price = bullish state, above = bearish.
//   AO    : Awesome Oscillator = SMA(fast, hl2) - SMA(slow, hl2), defaults 5/34.
//           Computed deterministically from QM_SMA on PRICE_MEDIAN (hl2).
//   AC    : Accelerator = AO - SMA(ac_smooth, AO), default ac_smooth = 5.
//           SMA(AO) is reconstructed by averaging AO over ac_smooth shifts.
//
//   The PSAR FLIP is the single EVENT (was-bearish->now-bullish for long, and
//   the mirror for short). AO and AC sign/alignment are STATES that must agree
//   with the flip direction on the same closed bar. Making the flip the lone
//   trigger (states, not two separate cross events) avoids the .DWX
//   two-cross-same-bar zero-trade trap (build prompt invariant #4).
//
//   "Green" per the card = the oscillator is RISING bar-to-bar:
//       AO green : AO[1] > AO[2]      AC green : AC[1] > AC[2]
//   We additionally require the oscillator SIGN to agree with the flip
//   direction (AO > 0 for long, AO < 0 for short) so the confluence is real
//   momentum confirmation, not a transient up-tick in a down move.
//
//   Stop  : signal-bar extreme (Low[1] long / High[1] short), capped at
//           sl_cap_pips (card P2 cap 40 pips).
//   Take  : tp_rr * stop distance (card: 2x SL distance).
//   Exit  : both AO and AC flip RED simultaneously (long) / GREEN (short).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11415;
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
input double strategy_sar_step          = 0.02;   // PSAR acceleration step
input double strategy_sar_max           = 0.20;   // PSAR acceleration maximum
input int    strategy_ao_fast           = 5;      // AO fast SMA on hl2
input int    strategy_ao_slow           = 34;     // AO slow SMA on hl2
input int    strategy_ac_smooth         = 5;      // AC = AO - SMA(ac_smooth, AO)
input double strategy_tp_rr             = 2.0;    // TP = tp_rr * stop distance
input double strategy_sl_cap_pips       = 40.0;   // P2 stop cap (H1 bars)
input double strategy_spread_cap_pips   = 20.0;   // skip only genuinely wide spread

// -----------------------------------------------------------------------------
// AO / AC deterministic helpers (computed from QM_SMA on hl2 = PRICE_MEDIAN).
// All reads on closed bars; shift is the bar index (1 = last closed bar).
// -----------------------------------------------------------------------------

// Awesome Oscillator at a given closed-bar shift: SMA(fast,hl2) - SMA(slow,hl2).
double AO_At(const int shift)
  {
   const double fast = QM_SMA(_Symbol, _Period, strategy_ao_fast, shift, PRICE_MEDIAN);
   const double slow = QM_SMA(_Symbol, _Period, strategy_ao_slow, shift, PRICE_MEDIAN);
   return fast - slow;
  }

// Accelerator at a given closed-bar shift: AO[shift] - mean(AO over the
// ac_smooth bars ending at `shift`). SMA(AO) is reconstructed by averaging AO
// across the smoothing window — there is no buffer-input MA helper, so we
// recompute AO at each shift. Window is small (default 5) and only evaluated
// on the closed-bar entry path, so this stays well within the perf budget.
double AC_At(const int shift)
  {
   const double ao_here = AO_At(shift);
   double sum = 0.0;
   for(int k = 0; k < strategy_ac_smooth; ++k)
      sum += AO_At(shift + k);
   const double ao_sma = sum / (double)strategy_ac_smooth;
   return ao_here - ao_sma;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread:
// only a genuinely wide spread (> cap) blocks; ask==bid (modeled 0) passes.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block

   const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   if(cap_dist <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > cap_dist)
      return true; // genuinely wide spread — block

   return false;
  }

// Triple-confluence entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Closed-bar references (shift 1 = last closed signal bar) ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   const double low1   = iLow(_Symbol, _Period, 1);   // perf-allowed: signal-bar low (stop)
   const double high1  = iHigh(_Symbol, _Period, 1);  // perf-allowed: signal-bar high (stop)
   if(close1 <= 0.0 || close2 <= 0.0 || low1 <= 0.0 || high1 <= 0.0)
      return false;

   // --- PSAR: the FLIP is the single trigger EVENT ---
   const double sar1 = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double sar2 = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 2);
   if(sar1 <= 0.0 || sar2 <= 0.0)
      return false;

   const bool sar_bull_now  = (sar1 < close1); // PSAR below price = bullish
   const bool sar_bear_prev = (sar2 > close2); // was bearish on the prior bar
   const bool sar_bear_now  = (sar1 > close1); // PSAR above price = bearish
   const bool sar_bull_prev = (sar2 < close2); // was bullish on the prior bar

   const bool flip_long  = (sar_bull_now && sar_bear_prev); // bearish -> bullish flip
   const bool flip_short = (sar_bear_now && sar_bull_prev); // bullish -> bearish flip
   if(!flip_long && !flip_short)
      return false;

   // --- AO / AC STATES (must agree with the flip direction) ---
   const double ao1 = AO_At(1);
   const double ao2 = AO_At(2);
   const double ac1 = AC_At(1);
   const double ac2 = AC_At(2);

   const bool ao_green = (ao1 > ao2) && (ao1 > 0.0); // rising AND positive momentum
   const bool ao_red   = (ao1 < ao2) && (ao1 < 0.0); // falling AND negative momentum
   const bool ac_green = (ac1 > ac2) && (ac1 > 0.0);
   const bool ac_red   = (ac1 < ac2) && (ac1 < 0.0);

   QM_OrderType side;
   double sl_price;
   if(flip_long && ao_green && ac_green)
     {
      side = QM_BUY;
      sl_price = low1; // signal-bar low
     }
   else if(flip_short && ao_red && ac_red)
     {
      side = QM_SELL;
      sl_price = high1; // signal-bar high
     }
   else
      return false;

   // --- Entry price + stop distance (with P2 pip cap) ---
   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double stop_dist = MathAbs(entry - sl_price);
   const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_cap_pips);
   if(cap_dist > 0.0 && stop_dist > cap_dist)
      stop_dist = cap_dist; // cap the stop at sl_cap_pips
   if(stop_dist <= 0.0)
      return false;

   const double sl = (side == QM_BUY) ? (entry - stop_dist) : (entry + stop_dist);
   const double tp = (side == QM_BUY) ? (entry + strategy_tp_rr * stop_dist)
                                      : (entry - strategy_tp_rr * stop_dist);

   req.type   = side;
   req.price  = 0.0; // framework fills market price at send
   req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
   req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
   req.reason = (side == QM_BUY) ? "wp_psar_ao_ac_long" : "wp_psar_ao_ac_short";
   return true;
  }

// Fixed stop/target after entry — no active trail. Discretionary exit lives in
// Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Early exit: both AO and AC flip to the opposite colour on the same bar,
// against the open position's direction.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ao1 = AO_At(1);
   const double ao2 = AO_At(2);
   const double ac1 = AC_At(1);
   const double ac2 = AC_At(2);

   const bool ao_red   = (ao1 < ao2);
   const bool ac_red   = (ac1 < ac2);
   const bool ao_green = (ao1 > ao2);
   const bool ac_green = (ac1 > ac2);

   // Determine the side of the open position for this magic.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && ao_red && ac_red)
         return true;  // long: both flipped red
      if(ptype == POSITION_TYPE_SELL && ao_green && ac_green)
         return true;  // short: both flipped green
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
