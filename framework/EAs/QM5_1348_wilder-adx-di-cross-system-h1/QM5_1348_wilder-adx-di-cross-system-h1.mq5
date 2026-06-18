#property strict
#property version   "5.0"
#property description "QM5_1348 Wilder Directional Movement System: +DI/-DI cross + ADX(14)>25 trend gate, H1"
// Build from card QM5_1348_wilder-adx-di-cross-system-h1.md (build target ea_id=1348).
// NOTE: card frontmatter ea_id=QM5_12141 (stale); build target / qm_ea_id = 1348 per
// orchestrator instruction. Flagged as frontmatter_mismatch in the build report.
//
// Welles Wilder 1978 "New Concepts in Technical Trading Systems" chapter 4 Directional
// Movement System. All math on closed H1 bars; after QM_IsNewBar() the card's "bar[0]"
// signal bar is the just-closed H1 bar = shift 1, and the card's "bar[1]" prior bar =
// shift 2. The card's ADX[3] look-back maps to shift 4 (3 bars before the signal bar).
//
//   EVENT (the single trigger, fired once per qualifying closed bar):
//     +DI / -DI CROSS on the just-closed signal bar.
//       long  : +DI[2] <= -DI[2]  AND  +DI[1] >  -DI[1]   (bullish first-cross)
//       short : +DI[2] >= -DI[2]  AND  +DI[1] <  -DI[1]   (bearish first-cross)
//     Modelling ONE cross as the event (not "two crosses on the same bar") avoids the
//     .DWX zero-trade trap (#4). ADX/DI-separation are STATE filters, not second events.
//   STATES (regime confirmation on the signal bar, shift 1):
//     ADX gate       : ADX[1] > ADX_threshold (25)            — directional trend present.
//     ADX not decaying: ADX[1] >= ADX[4]                       — kills post-trend crosses.
//     DI separation  : |+DI[1] - -DI[1]| > DI_separation_min (2) — kills low-conviction crosses.
//   ENTRY: market BUY/SELL at the close of the signal bar (gapless .DWX => next-tick fill
//          == prior close). One position per magic (HR14).
//   EXITS (Wilder ch.4 + FF community amendments, checked per new H1 bar):
//     1. DI counter-cross (primary): opposite first-cross since entry.
//     2. DI extension-exit ("diminishing returns"): winning DI > DI_extension_exit (40)
//        AND winning DI turned down (DI[1] < DI[2]).
//     3. ADX collapse: ADX[1] < ADX_collapse (20) AND held >= adx_collapse_min_bars (6).
//     4. Time-stop: held >= time_stop_bars (96 H1 bars ~4 trading days).
//     No fixed take-profit by design (Wilder ch.4).
//   STOP LOSS (catastrophic floor only; DI exits manage normal risk):
//     long  : entry - sl_atr_mult(2.0)*ATR(14), floored to a per-asset minimum.
//     short : entry + sl_atr_mult(2.0)*ATR(14), floored likewise. No trail, no widen.
//   RE-ARM: after any close, require >= 1 H1 bar where |+DI - -DI| <= di_reconverge_max (1)
//     (DI re-convergence) before the next cross is valid. Prevents back-and-forth re-entry.
//
// .DWX invariants honoured: fail-OPEN spread guard (#1); no swap gate (#2); single
// QM_IsNewBar consume per OnTick (#3); ONE cross EVENT, ADX/DI/extension are STATES (#4);
// prior CLOSE of a *closed* bar, never a live range (#6); pip-correct SL floor via
// QM_StopRulesPipsToPriceDistance (#14). All indicators in-EA via QM_* readers (no ML).

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1348;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_dmi_period          = 14;     // +DI / -DI / ADX period (Wilder)
input int    strategy_atr_period          = 14;     // ATR period for catastrophic SL
input double strategy_adx_threshold        = 25.0;   // entry gate: ADX must exceed this (P3-sweep 20-30)
input double strategy_di_separation_min    = 2.0;    // |+DI - -DI| min at the cross (low-conviction filter)
input double strategy_di_extension_exit    = 40.0;   // winning-DI overextension exit level (Wilder "diminishing returns")
input double strategy_adx_collapse         = 20.0;   // ADX-collapse exit threshold
input int    strategy_adx_collapse_min_bars = 6;     // min H1 bars held before ADX-collapse exit may fire
input int    strategy_time_stop_bars       = 96;     // hard time-stop: close after N H1 bars held
input double strategy_di_reconverge_max    = 1.0;    // re-arm: |+DI - -DI| must fall within this once after a close
input double strategy_sl_atr_mult          = 2.0;    // catastrophic SL = N x ATR (P3-sweep 1.5-3.0)
input int    strategy_sl_floor_pips        = 50;     // SL distance floor (pips), scale-correct per symbol

// File-scope state ---------------------------------------------------------
datetime g_entry_bar       = 0;      // H1 bar-open time when the current position entered
int      g_pos_dir         = 0;      // +1 long / -1 short for the open position (0 = flat)

// Re-arm gate: false right after a close until DI re-convergence is observed, then true.
bool     g_armed           = true;   // start armed so the first signal can fire

// --- helpers --------------------------------------------------------------
int CurrentDir()
  {
   // +1 long, -1 short, 0 flat (for THIS EA's magic on THIS symbol).
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
     }
   return 0;
  }

// --- No-Trade Filter (time, spread, news) --------------------------------
// Fail-OPEN spread guard per .DWX invariant #1: block only a genuinely WIDE spread;
// never block on zero spread (DWX quotes ask==bid in the tester). 24/5 H1 system,
// no session window per the card.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
     {
      const double spread = ask - bid;
      const double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point > 0.0 && (spread / point) > 100.0)   // wide-spread guard; zero-spread (tester) passes
         return true;
     }
   return false;
  }

// --- Trade Entry ----------------------------------------------------------
// Called once per closed H1 bar (caller guarantees QM_IsNewBar()==true). Detects the
// single +DI/-DI cross EVENT on the just-closed signal bar, confirms ADX/separation
// STATES, and on a qualifying signal opens ONE market position. Also advances the
// re-arm gate when DI has re-converged since the last close.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const double plus1  = QM_ADX_PlusDI(_Symbol, PERIOD_H1, strategy_dmi_period, 1);   // signal bar
   const double minus1 = QM_ADX_MinusDI(_Symbol, PERIOD_H1, strategy_dmi_period, 1);
   const double plus2  = QM_ADX_PlusDI(_Symbol, PERIOD_H1, strategy_dmi_period, 2);   // prior bar
   const double minus2 = QM_ADX_MinusDI(_Symbol, PERIOD_H1, strategy_dmi_period, 2);

   if(plus1 <= 0.0 && minus1 <= 0.0)
      return false;                          // DI not warmed up yet

   // Re-arm gate: once the DIs re-converge after a close, a fresh cross becomes valid.
   if(!g_armed && MathAbs(plus1 - minus1) <= strategy_di_reconverge_max)
      g_armed = true;

   if(CurrentDir() != 0)
      return false;                          // one position per magic
   if(!g_armed)
      return false;                          // wait for DI re-convergence after last close

   // ADX state filters (signal bar = shift 1; decay check uses shift 4 == card ADX[3]).
   const double adx1 = QM_ADX(_Symbol, PERIOD_H1, strategy_dmi_period, 1);
   const double adx4 = QM_ADX(_Symbol, PERIOD_H1, strategy_dmi_period, 4);
   if(adx1 <= 0.0)
      return false;
   if(adx1 <= strategy_adx_threshold)        // ADX gate: directional trend present
      return false;
   if(adx4 > 0.0 && adx1 < adx4)             // ADX not decaying vs 3 bars ago
      return false;

   // ATR for catastrophic SL floor.
   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   const double floor_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_floor_pips);
   double sl_dist = strategy_sl_atr_mult * atr;
   if(floor_dist > 0.0 && floor_dist > sl_dist)
      sl_dist = floor_dist;
   if(sl_dist <= 0.0)
      return false;

   // --- the single cross EVENT ---
   const bool bull_cross = (plus2 <= minus2) && (plus1 > minus1);
   const bool bear_cross = (plus2 >= minus2) && (plus1 < minus1);

   if(bull_cross)
     {
      // separation conviction filter (signal bar)
      if((plus1 - minus1) <= strategy_di_separation_min)
         return false;
      const double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double entry = (ask > 0.0) ? ask : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, entry - sl_dist);
      if(sl <= 0.0 || sl >= entry)
         return false;

      req.type               = QM_BUY;
      req.price              = 0.0;          // framework fills market at send
      req.sl                 = sl;
      req.tp                 = 0.0;          // no fixed TP by design (Wilder ch.4)
      req.reason             = "wilder_di_bull_cross";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      g_armed                = false;        // disarm until DI re-converges after this trade
      return true;
     }
   else if(bear_cross)
     {
      if((minus1 - plus1) <= strategy_di_separation_min)
         return false;
      const double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double entry = (bid > 0.0) ? bid : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, entry + sl_dist);
      if(sl <= entry)
         return false;

      req.type               = QM_SELL;
      req.price              = 0.0;
      req.sl                 = sl;
      req.tp                 = 0.0;
      req.reason             = "wilder_di_bear_cross";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      g_armed                = false;
      return true;
     }

   return false;
  }

// --- Trade Management -----------------------------------------------------
// Wilder's directional system has no in-trade SL adjustment — the DI-cross exits
// manage risk and the ATR-SL is a static catastrophic floor. Nothing to trail.
// We only latch entry-bar context so the time-stop and exits can measure hold time.
void Strategy_ManageOpenPosition()
  {
   const int dir = CurrentDir();
   if(dir == 0)
      return;
   if(g_entry_bar == 0 || g_pos_dir != dir)
     {
      g_pos_dir   = dir;
      g_entry_bar = iTime(_Symbol, PERIOD_H1, 0);   // perf-allowed: current bar-open time, one read/new-bar path
     }
  }

// --- Trade Close ----------------------------------------------------------
// Per-new-bar exit evaluation (caller routes the close through the framework when this
// returns true). Arms: DI counter-cross, DI extension-exit, ADX collapse, time-stop.
bool Strategy_ExitSignal()
  {
   const int dir = CurrentDir();
   if(dir == 0)
     {
      // Flat: reset per-position state so the next fill latches cleanly.
      g_entry_bar = 0;
      g_pos_dir   = 0;
      return false;
     }

   const double plus1  = QM_ADX_PlusDI(_Symbol, PERIOD_H1, strategy_dmi_period, 1);
   const double minus1 = QM_ADX_MinusDI(_Symbol, PERIOD_H1, strategy_dmi_period, 1);
   const double plus2  = QM_ADX_PlusDI(_Symbol, PERIOD_H1, strategy_dmi_period, 2);
   const double minus2 = QM_ADX_MinusDI(_Symbol, PERIOD_H1, strategy_dmi_period, 2);
   const double adx1   = QM_ADX(_Symbol, PERIOD_H1, strategy_dmi_period, 1);

   // hold time in H1 bars
   int held = 0;
   if(g_entry_bar > 0)
     {
      const datetime now_bar = iTime(_Symbol, PERIOD_H1, 0);   // perf-allowed: current bar-open time
      if(now_bar > 0)
         held = (int)((now_bar - g_entry_bar) / 3600);
     }

   if(dir > 0)   // long
     {
      // 1. DI counter-cross (bearish first-cross)
      if((plus2 >= minus2) && (plus1 < minus1))
         return true;
      // 2. DI extension-exit: +DI overextended and turning down
      if(plus1 > strategy_di_extension_exit && plus1 < plus2)
         return true;
     }
   else          // short
     {
      // 1. DI counter-cross (bullish first-cross)
      if((plus2 <= minus2) && (plus1 > minus1))
         return true;
      // 2. DI extension-exit: -DI overextended and turning down
      if(minus1 > strategy_di_extension_exit && minus1 < minus2)
         return true;
     }

   // 3. ADX collapse: directional regime ended, after a minimum hold.
   if(adx1 > 0.0 && adx1 < strategy_adx_collapse && held >= strategy_adx_collapse_min_bars)
      return true;

   // 4. Time-stop.
   if(held >= strategy_time_stop_bars)
      return true;

   return false;
  }

// --- News Filter Hook (callable for Q09 News Impact phase) ----------------
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to central QM_NewsAllowsTrade
  }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------
int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1348\",\"strategy\":\"wilder-adx-di-cross-system-h1\"}");
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
      g_entry_bar = 0;
      g_pos_dir   = 0;
      g_armed     = false;   // require DI re-convergence before the next entry
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
