#property strict
#property version   "5.0"
#property description "QM5_11412 wilder-volatility-system-atr-sar-d1 — Wilder Volatility System (ATR-SAR / ARC, always-in-market reversal, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11412 wilder-volatility-system-atr-sar-d1
// -----------------------------------------------------------------------------
// Source: J. Welles Wilder Jr., "New Concepts in Technical Trading Systems"
//         (Trend Research, 1978), Section III: Volatility Index and Volatility
//         System (the ATR-based trailing "SAR" / ARC stop-and-reverse).
// Card: artifacts/cards_approved/QM5_11412_wilder-volatility-system-atr-sar-d1.md
//       (g0_status: APPROVED).
//
// Mechanics (D1, always-in-market stop-and-reverse, closed-bar reads at shift 1):
//   ATR        : ATR(atr_period) Wilder-smoothed — QM_ATR pools iATR which uses
//                Wilder smoothing natively.
//   ARC        : ARC = ATR * arc_constant      (Average Range Constant, C ~ 3.0).
//   SIC        : Significant Close tracked since entry —
//                  long  : SIC = max(SIC, Close[1])
//                  short : SIC = min(SIC, Close[1])
//   SAR (stop) : long  SAR = SIC - ARC ; reverse to SHORT when Close[1] < SAR.
//                short SAR = SIC + ARC ; reverse to LONG  when Close[1] > SAR.
//   Reversal   : on a cross, CLOSE the current position and OPEN the opposite
//                on the same closed bar — single EVENT = close crossing the
//                ATR-trailing stop. Always in the market once seeded.
//   Stop loss  : the live SAR is also the broker SL on the position (P2 cap on
//                the initial SL distance via sl_cap_pips).
//
// .DWX invariants honoured:
//   * Spread guard fails OPEN on zero modeled spread (only a genuinely wide
//     spread blocks).
//   * No swap gate. No external-macro feed. All math is from closed bars on the
//     symbol itself — gapless CFD prior-close semantics (Close[1]) drive SIC.
//   * QM_IsNewBar() consumed ONCE per tick (only by OnTick's framework gate,
//     which then guards the closed-bar entry path — no strategy hook re-consumes it).
//   * The trailing stop is computed deterministically from closed-bar closes
//     and ATR — no per-tick recompute of history.
//
// State is file-scope, advanced once per closed bar inside Strategy_EntrySignal
// (the framework guarantees QM_IsNewBar()==true there). The reversal close is
// issued from the same hook so close-then-open is atomic on one bar.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11412;
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
input int    strategy_atr_period        = 7;      // Wilder ATR period (card: 7; P3 sweep 5/7/10)
input double strategy_arc_constant      = 3.0;    // ARC = ATR * C (card: 3.0; P3 sweep 2.5/3.0/3.5)
input int    strategy_sl_cap_pips       = 120;    // P2 cap on the INITIAL SL distance (pips)
input double strategy_spread_pct_of_stop = 15.0;  // skip only if spread > this % of the SAR stop distance

// -----------------------------------------------------------------------------
// File-scope strategy state (advanced once per closed bar; deterministic).
//   g_direction : +1 long in market, -1 short in market, 0 not yet seeded.
//   g_sic       : significant close (running max while long / min while short).
// -----------------------------------------------------------------------------
int    g_direction = 0;
double g_sic       = 0.0;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail OPEN on .DWX zero modeled
// spread; only a genuinely wide spread (relative to the SAR/ARC stop distance)
// blocks. All signal work is on the closed-bar path in Strategy_EntrySignal.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — never block on a missing quote

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   // ARC is the trailing-stop width; use it as the spread-cap reference so the
   // cap scales with the symbol's volatility.
   const double stop_distance = strategy_arc_constant * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true; // genuinely wide spread — block

   return false;
  }

// Always-in-market stop-and-reverse driver. Caller guarantees
// QM_IsNewBar()==true (closed-bar gate). This single hook advances SIC, detects
// the close-crosses-SAR reversal EVENT, closes any opposite position, and emits
// the new entry. Strategy_ExitSignal stays inert so the new-bar event is
// consumed exactly once and close-then-open is atomic on the same closed bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Closed-bar close drives SIC and the SAR comparison (gapless CFD: the prior
   // CLOSE, not range). perf-allowed: single closed-bar read.
   const double close1 = iClose(_Symbol, _Period, 1);
   if(close1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // warmup — wait for a valid Wilder ATR

   const double arc = strategy_arc_constant * atr_value;
   if(arc <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   const bool have_position = (QM_TM_OpenPositionCount(magic) > 0);

   // --- Seed: not yet in the market (start of test, or position lost). Pick the
   //     initial direction from the bar's own close-vs-previous-close move so the
   //     system becomes always-in-market deterministically. ---
   if(g_direction == 0 || !have_position)
     {
      const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
      if(close2 <= 0.0)
         return false;

      const int dir = (close1 >= close2) ? +1 : -1;
      g_direction = dir;
      g_sic       = close1; // significant close seeded at the reversal/seed bar

      return BuildReversalEntry(req, dir, close1, arc);
     }

   // --- In the market: advance SIC on the closed bar, then test the SAR cross. ---
   if(g_direction > 0)
     {
      g_sic = MathMax(g_sic, close1);
      const double sar_long = g_sic - arc;
      if(close1 < sar_long)
        {
         // Reverse LONG -> SHORT: close current long, seed short, open short.
         CloseAllForMagic(magic);
         g_direction = -1;
         g_sic       = close1;
         return BuildReversalEntry(req, -1, close1, arc);
        }
      // No cross — trail the broker SL up to the advancing SAR.
      TrailStopToSAR(magic, +1, QM_StopRulesNormalizePrice(_Symbol, sar_long));
     }
   else // g_direction < 0
     {
      g_sic = MathMin(g_sic, close1);
      const double sar_short = g_sic + arc;
      if(close1 > sar_short)
        {
         // Reverse SHORT -> LONG: close current short, seed long, open long.
         CloseAllForMagic(magic);
         g_direction = +1;
         g_sic       = close1;
         return BuildReversalEntry(req, +1, close1, arc);
        }
      // No cross — trail the broker SL down to the advancing SAR.
      TrailStopToSAR(magic, -1, QM_StopRulesNormalizePrice(_Symbol, sar_short));
     }

   return false; // no cross — stay in the current direction
  }

// Build a market entry in `dir` (+1 long / -1 short). The SL is the live SAR
// (= SIC -/+ ARC at the seed bar), capped at strategy_sl_cap_pips. The framework
// sizes lots from the SL distance via QM_LotsForRisk (no lots field on req).
bool BuildReversalEntry(QM_EntryRequest &req, const int dir,
                        const double seed_close, const double arc)
  {
   const QM_OrderType otype = (dir > 0) ? QM_BUY : QM_SELL;

   const double entry = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // Raw SAR stop from the seed bar: long = SIC - ARC, short = SIC + ARC.
   double sar = (dir > 0) ? (seed_close - arc) : (seed_close + arc);

   // P2 cap: clamp the INITIAL stop distance to sl_cap_pips so a wide D1 ARC
   // cannot push the SL beyond the risk cap. Scale-correct pips->price.
   const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(cap_dist > 0.0)
     {
      if(dir > 0)
        {
         const double min_sl = entry - cap_dist;
         if(sar < min_sl)
            sar = min_sl;       // never risk more than the cap on a long
        }
      else
        {
         const double max_sl = entry + cap_dist;
         if(sar > max_sl)
            sar = max_sl;       // never risk more than the cap on a short
        }
     }

   sar = QM_StopRulesNormalizePrice(_Symbol, sar);

   // Sanity: SL must be on the correct side of entry.
   if(dir > 0 && !(sar < entry))
      return false;
   if(dir < 0 && !(sar > entry))
      return false;

   req.type   = otype;
   req.price  = 0.0;                 // framework fills market price at send
   req.sl     = sar;                 // live SAR == broker stop
   req.tp     = 0.0;                 // no fixed target — reversal-on-cross exits
   req.reason = (dir > 0) ? "wilder_vol_sar_reverse_long"
                          : "wilder_vol_sar_reverse_short";
   return true;
  }

// Close every open position carrying this EA's magic (used on a reversal).
void CloseAllForMagic(const int magic)
  {
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

// Ratchet the broker SL of the open position toward `sar` (the advancing SAR)
// without ever widening it or moving it to the wrong side of the open price.
// dir: +1 long / -1 short. Called once per closed bar from Strategy_EntrySignal.
void TrailStopToSAR(const int magic, const int dir, const double sar)
  {
   if(sar <= 0.0)
      return;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const double cur_sl = PositionGetDouble(POSITION_SL);
      const double open_p = PositionGetDouble(POSITION_PRICE_OPEN);

      if(dir > 0)
        {
         if(sar < open_p && (cur_sl <= 0.0 || sar > cur_sl))
            QM_TM_MoveSL(ticket, sar, "wilder_sar_trail");
        }
      else
        {
         if(sar > open_p && (cur_sl <= 0.0 || sar < cur_sl))
            QM_TM_MoveSL(ticket, sar, "wilder_sar_trail");
        }
     }
  }

// No per-tick management. The Volatility System's SAR advance + reversal are
// driven entirely on the closed-bar path inside Strategy_EntrySignal (which the
// framework guarantees runs once per new bar). Doing nothing here avoids a
// second QM_IsNewBar() consume that would starve the entry gate.
void Strategy_ManageOpenPosition()
  {
  }

// Reversal close is issued from Strategy_EntrySignal (atomic close-then-open on
// the same closed bar). Keep this inert so the new-bar event is consumed exactly
// once. (The framework calls QM_IsNewBar() AFTER this hook; returning false here
// guarantees no double-consume of the bar event for entry.)
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

   g_direction = 0;
   g_sic       = 0.0;

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
