#property strict
#property version   "5.0"
#property description "QM5_1305 camarilla-vwap-confluence-intraday — Camarilla L1/H1 + session-VWAP confluence fade (intraday M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1305 camarilla-vwap-confluence-intraday
// -----------------------------------------------------------------------------
// Source: forexfactory-trading-systems (Camarilla VWAP confluence cluster).
//   Lineage: Nick Stott 1989 "Camarilla Equation" + session-VWAP intraday praxis.
//   Card: artifacts/cards_approved/QM5_1305_camarilla-vwap-confluence-intraday.md
//         (g0_status APPROVED).
//
// Mechanics (intraday M15, closed-bar reads at shift 1; session in BROKER time):
//   Camarilla levels (STATE) from PRIOR D1 OHLC (D1 shift 1, intraday-static):
//     L1 = C - 1.1/12*(H-L)   H1 = C + 1.1/12*(H-L)
//     L2 = C - 1.1/6 *(H-L)   H2 = C + 1.1/6 *(H-L)
//     P  = (H+L+C)/3          (classic pivot midpoint, TP target)
//   Session VWAP (STATE) computed in-EA: cumulative(typ*tickvol)/cumulative(tickvol)
//     typ = (H+L+C)/3 of each closed bar; RESET at session open (broker time).
//     *** VWAP uses TICK-VOLUME as the weight proxy: .DWX has no real volume.
//         FLAGGED in setfile_flags as vwap_tickvolume_proxy. ***
//   Confluence (STATE): |L1 - VWAP| <= conf_atr_mult * ATR(14)  (resp. H1).
//   Bias (STATE): close vs EMA(200, M15).
//   Trigger EVENT (single, two-cross-trap-safe): the signal bar's low touches L1
//     (low<=L1) for BUY / high touches H1 (high>=H1) for SELL. The touch is the
//     ONE event; confluence/bias/zone/no-breach are all STATES gating it.
//   Stop  : BUY -> closer of (L2 - 0.1*ATR) and (entry - 1.2*ATR).
//   Take  : VWAP if it is a profitable target from entry, else P, else
//           entry +/- 1.5*ATR fallback (secondary TP per card).
//   Exits : EOD-flat at eod_flat_hour_broker; L2/H2 breach hard exit.
//   Session: only fire entries inside [session_start_h, session_end_h) broker time.
//
// Intraday cache discipline: ALL session state (VWAP accumulators, Camarilla
// levels, EMA/ATR snapshots) is advanced ONCE per closed bar in
// AdvanceState_OnNewBar(). The per-tick path reads cached doubles only.
//
// Only the 5 Strategy_* hooks + Strategy inputs + the cache advance are
// EA-specific. Everything else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1305;
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
input double strategy_cam_inner_mult    = 0.0916667; // 1.1/12 inner-pivot (L1/H1) multiplier
input double strategy_cam_outer_mult    = 0.1833333; // 1.1/6  outer-pivot (L2/H2) multiplier
input int    strategy_atr_period        = 14;        // ATR period (confluence / stop / target)
input double strategy_conf_atr_mult     = 0.3;       // confluence band: |pivot-VWAP| <= mult*ATR
input int    strategy_ema_bias_period   = 200;       // EMA bias filter period (M15)
input double strategy_sl_outer_buf_atr  = 0.1;       // SL buffer past L2/H2, in ATR
input double strategy_sl_cap_atr        = 1.2;       // SL cap distance from entry, in ATR
input double strategy_tp_fallback_atr   = 1.5;       // secondary TP distance, in ATR
input int    strategy_session_start_h   = 7;         // entry session start, BROKER hour (incl.)
input int    strategy_session_end_h     = 20;        // entry session end, BROKER hour (excl.)
input int    strategy_eod_flat_hour     = 21;        // close any open position at this BROKER hour
input int    strategy_session_reset_h   = 0;         // VWAP session reset, BROKER hour (00:00)

// -----------------------------------------------------------------------------
// File-scope cached session state (advanced once per closed bar).
// -----------------------------------------------------------------------------
double   g_vwap            = 0.0;   // current session VWAP (cumulative typ*tv / tv)
double   g_vwap_cum_pv     = 0.0;   // cumulative sum(typ * tickvolume) this session
double   g_vwap_cum_v      = 0.0;   // cumulative sum(tickvolume) this session
int      g_vwap_session_day = -1;   // broker calendar day of the active VWAP session

double   g_cam_L1 = 0.0, g_cam_H1 = 0.0;   // inner pivots
double   g_cam_L2 = 0.0, g_cam_H2 = 0.0;   // outer pivots
double   g_cam_P  = 0.0;                    // classic pivot midpoint
int      g_cam_day = -1;                     // broker day the Camarilla levels belong to
bool     g_cam_valid = false;

double   g_atr  = 0.0;   // ATR(period) snapshot, closed bar
double   g_ema  = 0.0;   // EMA(bias) snapshot, closed bar

double   g_sig_high = 0.0, g_sig_low = 0.0, g_sig_close = 0.0;  // signal-bar OHLC (shift 1)

bool     g_long_fired_today  = false;   // one BUY  per session per magic
bool     g_short_fired_today = false;   // one SELL per session per magic
int      g_entry_session_day = -1;       // day for which the fired-flags apply

// Returns the broker-time calendar day index (days since epoch) for session keys.
int BrokerDayIndex(const datetime broker_t)
  {
   return (int)(broker_t / 86400);
  }

// Advance ALL cached state by exactly one closed bar. Called once per new bar.
void AdvanceState_OnNewBar()
  {
   const datetime bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: closed-bar timestamp
   if(bar_time <= 0)
      return;

   MqlDateTime bt;
   TimeToStruct(bar_time, bt);
   const int bar_day = BrokerDayIndex(bar_time);

   // --- Session VWAP reset at/after the session-reset hour on a NEW broker day ---
   if(g_vwap_session_day != bar_day)
     {
      g_vwap_cum_pv = 0.0;
      g_vwap_cum_v  = 0.0;
      g_vwap        = 0.0;
      g_vwap_session_day = bar_day;
     }

   // Accumulate the just-closed bar (shift 1) into the session VWAP.
   const double h1 = iHigh(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   const double l1 = iLow(_Symbol, _Period, 1);    // perf-allowed
   const double c1 = iClose(_Symbol, _Period, 1);  // perf-allowed
   const double tv = (double)iTickVolume(_Symbol, _Period, 1); // perf-allowed: tick-vol proxy
   if(h1 > 0.0 && l1 > 0.0 && c1 > 0.0 && tv > 0.0)
     {
      const double typ = (h1 + l1 + c1) / 3.0;
      g_vwap_cum_pv += typ * tv;
      g_vwap_cum_v  += tv;
      if(g_vwap_cum_v > 0.0)
         g_vwap = g_vwap_cum_pv / g_vwap_cum_v;
     }

   // Cache the signal-bar OHLC (shift 1) for the per-tick entry gate.
   g_sig_high  = h1;
   g_sig_low   = l1;
   g_sig_close = c1;

   // --- Camarilla levels from PRIOR D1 OHLC (D1 shift 1). Recompute once/day. ---
   if(g_cam_day != bar_day)
     {
      const double dH = iHigh(_Symbol, PERIOD_D1, 1);  // perf-allowed: prior-day high
      const double dL = iLow(_Symbol, PERIOD_D1, 1);   // perf-allowed: prior-day low
      const double dC = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: prior-day close
      if(dH > 0.0 && dL > 0.0 && dC > 0.0 && dH >= dL)
        {
         const double rng = dH - dL;
         g_cam_L1 = dC - strategy_cam_inner_mult * rng;
         g_cam_H1 = dC + strategy_cam_inner_mult * rng;
         g_cam_L2 = dC - strategy_cam_outer_mult * rng;
         g_cam_H2 = dC + strategy_cam_outer_mult * rng;
         g_cam_P  = (dH + dL + dC) / 3.0;
         g_cam_day   = bar_day;
         g_cam_valid = true;
        }
      else
        {
         g_cam_valid = false;
        }
     }

   // --- One-entry-per-session flags reset on a new broker day ---
   if(g_entry_session_day != bar_day)
     {
      g_long_fired_today   = false;
      g_short_fired_today  = false;
      g_entry_session_day  = bar_day;
     }

   // --- Indicator snapshots (handle-pooled QM readers, closed bar) ---
   g_atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   g_ema = QM_EMA(_Symbol, _Period, strategy_ema_bias_period, 1);
  }

// True if the just-closed signal bar is inside the entry session (broker time).
bool InEntrySession()
  {
   const datetime bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: closed-bar timestamp
   if(bar_time <= 0)
      return false;
   MqlDateTime bt;
   TimeToStruct(bar_time, bt);
   const int h = bt.hour;
   if(strategy_session_start_h <= strategy_session_end_h)
      return (h >= strategy_session_start_h && h < strategy_session_end_h);
   // wrap-safe (not expected here, but correct if start>end)
   return (h >= strategy_session_start_h || h < strategy_session_end_h);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. No spread guard fails-closed on .DWX zero spread.
// Block entries outside the broker-time entry session.
bool Strategy_NoTradeFilter()
  {
   return !InEntrySession();
  }

// Intraday entry. Caller guarantees QM_IsNewBar()==true (closed-bar gate) and
// that AdvanceState_OnNewBar() already ran this bar. Reads cached state only.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_cam_valid)
      return false;
   if(g_atr <= 0.0 || g_ema <= 0.0 || g_vwap <= 0.0)
      return false;
   if(g_sig_high <= 0.0 || g_sig_low <= 0.0 || g_sig_close <= 0.0)
      return false;

   const double conf_band = strategy_conf_atr_mult * g_atr;

   // ===================== BUY: L1 + VWAP confluence fade =====================
   if(!g_long_fired_today)
     {
      const bool l1_touch    = (g_sig_low <= g_cam_L1);                       // EVENT (single trigger)
      const bool confluence  = (MathAbs(g_cam_L1 - g_vwap) <= conf_band);     // STATE
      const bool below_vwap  = (g_sig_close <= g_vwap);                       // STATE (fade toward VWAP)
      const bool bias_up     = (g_sig_close > g_ema);                         // STATE (uptrend)
      const bool no_l2_break = (g_sig_low > g_cam_L2);                        // STATE (inner fade, not break)

      if(l1_touch && confluence && below_vwap && bias_up && no_l2_break)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(entry <= 0.0)
            return false;

         // SL: closer of (L2 - buf*ATR) and (entry - cap*ATR).
         const double sl_outer = g_cam_L2 - strategy_sl_outer_buf_atr * g_atr;
         const double sl_cap   = entry    - strategy_sl_cap_atr       * g_atr;
         double sl = MathMax(sl_outer, sl_cap); // "closer to entry" = the higher of the two for a BUY
         if(sl >= entry)
            return false;

         // TP: prefer VWAP if it sits above entry (the fade target). Else P if
         // above entry. Else fixed ATR fallback.
         double tp = 0.0;
         if(g_vwap > entry)            tp = g_vwap;
         else if(g_cam_P > entry)      tp = g_cam_P;
         else                          tp = entry + strategy_tp_fallback_atr * g_atr;
         if(tp <= entry)
            return false;

         req.type   = QM_BUY;
         req.price  = 0.0;
         req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
         req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
         req.reason = "cam_l1_vwap_fade_long";
         g_long_fired_today = true;
         return true;
        }
     }

   // ===================== SELL: H1 + VWAP confluence fade ====================
   if(!g_short_fired_today)
     {
      const bool h1_touch    = (g_sig_high >= g_cam_H1);                      // EVENT (single trigger)
      const bool confluence  = (MathAbs(g_cam_H1 - g_vwap) <= conf_band);     // STATE
      const bool above_vwap  = (g_sig_close >= g_vwap);                       // STATE (fade toward VWAP)
      const bool bias_dn     = (g_sig_close < g_ema);                         // STATE (downtrend)
      const bool no_h2_break = (g_sig_high < g_cam_H2);                       // STATE (inner fade, not break)

      if(h1_touch && confluence && above_vwap && bias_dn && no_h2_break)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(entry <= 0.0)
            return false;

         const double sl_outer = g_cam_H2 + strategy_sl_outer_buf_atr * g_atr;
         const double sl_cap   = entry    + strategy_sl_cap_atr       * g_atr;
         double sl = MathMin(sl_outer, sl_cap); // "closer to entry" = the lower of the two for a SELL
         if(sl <= entry)
            return false;

         double tp = 0.0;
         if(g_vwap < entry)            tp = g_vwap;
         else if(g_cam_P < entry)      tp = g_cam_P;
         else                          tp = entry - strategy_tp_fallback_atr * g_atr;
         if(tp >= entry)
            return false;

         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
         req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
         req.reason = "cam_h1_vwap_fade_short";
         g_short_fired_today = true;
         return true;
        }
     }

   return false;
  }

// No active trailing; fixed SL/TP plus the structural exits in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Structural exits: EOD-flat at the configured broker hour, and L2/H2 breach
// (the inner-pivot fade is invalidated once the outer pivot is broken).
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   // EOD-flat: close any open position at/after the configured broker hour.
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   if(now.hour >= strategy_eod_flat_hour)
      return true;

   if(!g_cam_valid)
      return false;

   // L2/H2 breach hard exit, evaluated on the closed signal bar.
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY  && g_sig_low  <= g_cam_L2)
         return true;  // L2 broken under a long fade -> trend break, exit
      if(ptype == POSITION_TYPE_SELL && g_sig_high >= g_cam_H2)
         return true;  // H2 broken over a short fade -> trend break, exit
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

   // FIRST: advance closed-bar session state exactly once per new bar.
   const bool new_bar = QM_IsNewBar();
   if(new_bar)
      AdvanceState_OnNewBar();

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

   if(!new_bar)
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
