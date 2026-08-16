#property strict
#property version   "5.0"
#property description "QM5_20176 hopwood-ts5-standalone-h4-r1-recovery — H4 DMI/MACD/Donchian fresh-cross confluence"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_20176 Hopwood TS5 standalone (H4)
// -----------------------------------------------------------------------------
// Fresh-cross-introduction iteration of the Hopwood TS-series trend stack.
// Long/short confluence on the last CLOSED H4 bar (shift=1):
//   DMI(14) +DI/-DI directional lead
//   AND fresh +DI/-DI cross within the last N closed bars (TS5 primitive)
//   AND MACD(12,26,9) histogram sign
//   AND Donchian(20) prior-bar channel breach
//   AND D1 EMA(200) slope + D1 close vs EMA regime.
// Exit: opposite full-stack flip closes immediately; otherwise a 2-stage trail
//   (ATR before +1.5 ATR profit, PSAR after).
// Everything outside the five Strategy_* hooks is framework boilerplate and
// MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20176;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    dmi_period                 = 14;    // DMI/ADX period for +DI/-DI
input int    fresh_cross_window          = 3;     // fresh +DI/-DI cross must be within N closed bars
input int    macd_fast                  = 12;    // MACD fast EMA period
input int    macd_slow                  = 26;    // MACD slow EMA period
input int    macd_signal                = 9;     // MACD signal EMA period
input int    donchian_period            = 20;    // Donchian HHV/LLV channel length
input int    d1_ema_period              = 200;   // D1 regime EMA period
input int    d1_slope_lookback          = 5;     // D1 bars back for EMA slope sign
input int    atr_period                 = 14;    // ATR period for stop + trail
input double sl_atr_mult                = 2.5;   // initial stop = entry +/- this * ATR
input double trail_activate_atr_mult     = 1.5;   // profit (in ATR) to switch to PSAR trail
input double psar_step                  = 0.02;  // Parabolic SAR acceleration step
input double psar_max                   = 0.2;   // Parabolic SAR max acceleration
input double spread_atr_mult_cap         = 0.3;   // skip entry if spread > this * ATR
input int    cooldown_bars              = 4;     // no same-direction re-entry within N bars

// File-scope entry-time state for the per-direction cooldown counter.
datetime g_last_long_entry_time  = 0;
datetime g_last_short_entry_time = 0;

// -----------------------------------------------------------------------------
// Bespoke bounded structural helpers (no QM_* reader exists for Donchian /
// fresh-cross-age). Called only from the new-bar-gated entry path and the
// management path.
// -----------------------------------------------------------------------------

// HHV(period)[1]: highest high of the `period`-bar window as of the PRIOR
// closed bar (shifts 2..period+1).
double DonchianHHV_priorRef(const string sym, const int period)
  {
   double hh = 0.0;
   MqlRates cj;
   for(int i = 2; i <= period + 1; ++i) // perf-allowed structural channel lookup
     {
      if(!QM_ReadBar(sym, PERIOD_CURRENT, i, cj))
         continue;
      if(cj.high > hh)
         hh = cj.high;
     }
   return hh;
  }

// LLV(period)[1]: lowest low of the `period`-bar window as of the PRIOR
// closed bar (shifts 2..period+1).
double DonchianLLV_priorRef(const string sym, const int period)
  {
   double ll = 0.0;
   bool   have = false;
   MqlRates cj;
   for(int i = 2; i <= period + 1; ++i) // perf-allowed structural channel lookup
     {
      if(!QM_ReadBar(sym, PERIOD_CURRENT, i, cj))
         continue;
      if(!have || cj.low < ll)
        {
         ll   = cj.low;
         have = true;
        }
     }
   return ll;
  }

// True if a +DI/-DI up-cross (+DI leads, having been at/below -DI one bar
// earlier) occurred within the last `window` closed bars.
bool FreshCrossUp(const string sym, const int window)
  {
   for(int w = 1; w <= window; ++w)
     {
      const double p_w  = QM_ADX_PlusDI(sym, PERIOD_CURRENT, dmi_period, w);
      const double m_w  = QM_ADX_MinusDI(sym, PERIOD_CURRENT, dmi_period, w);
      const double p_w1 = QM_ADX_PlusDI(sym, PERIOD_CURRENT, dmi_period, w + 1);
      const double m_w1 = QM_ADX_MinusDI(sym, PERIOD_CURRENT, dmi_period, w + 1);
      if(p_w > m_w && p_w1 <= m_w1)
         return true;
     }
   return false;
  }

// Mirror of FreshCrossUp: -DI up-cross over +DI within the last `window` bars.
bool FreshCrossDown(const string sym, const int window)
  {
   for(int w = 1; w <= window; ++w)
     {
      const double p_w  = QM_ADX_PlusDI(sym, PERIOD_CURRENT, dmi_period, w);
      const double m_w  = QM_ADX_MinusDI(sym, PERIOD_CURRENT, dmi_period, w);
      const double p_w1 = QM_ADX_PlusDI(sym, PERIOD_CURRENT, dmi_period, w + 1);
      const double m_w1 = QM_ADX_MinusDI(sym, PERIOD_CURRENT, dmi_period, w + 1);
      if(m_w > p_w && m_w1 <= p_w1)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick. TS5 has no session/regime O(1) gate.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Populate `req` and return TRUE if a NEW entry should fire on this closed bar.
// Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.symbol_slot = qm_magic_slot_offset;

   const double plusDI1  = QM_ADX_PlusDI(_Symbol, PERIOD_CURRENT, dmi_period, 1);
   const double minusDI1 = QM_ADX_MinusDI(_Symbol, PERIOD_CURRENT, dmi_period, 1);

   const double macd_hist1 = QM_MACD_Main(_Symbol, PERIOD_CURRENT, macd_fast, macd_slow, macd_signal, 1)
                             - QM_MACD_Signal(_Symbol, PERIOD_CURRENT, macd_fast, macd_slow, macd_signal, 1);

   MqlRates c1;
   if(!QM_ReadBar(_Symbol, PERIOD_CURRENT, 1, c1))
      return false;
   const double hhv_prior = DonchianHHV_priorRef(_Symbol, donchian_period);
   const double llv_prior = DonchianLLV_priorRef(_Symbol, donchian_period);

   const double d1_ema_1   = QM_EMA(_Symbol, PERIOD_D1, d1_ema_period, 1);
   const double d1_ema_lag = QM_EMA(_Symbol, PERIOD_D1, d1_ema_period, 1 + d1_slope_lookback);
   MqlRates d1c1;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, d1c1))
      return false;

   const double atr14_1 = QM_ATR(_Symbol, PERIOD_CURRENT, atr_period, 1);
   if(atr14_1 <= 0.0 || hhv_prior <= 0.0 || llv_prior <= 0.0)
      return false;

   // Spread filter — never fail-closed on a zero/undefined spread.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double spread = ask - bid;
   if(spread > 0.0 && spread > spread_atr_mult_cap * atr14_1)
      return false;

   const int bars_since_long  = (g_last_long_entry_time > 0)
                                ? iBarShift(_Symbol, PERIOD_CURRENT, g_last_long_entry_time, false) // perf-allowed structural bar-index lookup
                                : 999999;
   const int bars_since_short = (g_last_short_entry_time > 0)
                                ? iBarShift(_Symbol, PERIOD_CURRENT, g_last_short_entry_time, false) // perf-allowed structural bar-index lookup
                                : 999999;

   const bool long_ok = (plusDI1 > minusDI1)
                        && FreshCrossUp(_Symbol, fresh_cross_window)
                        && macd_hist1 > 0.0
                        && c1.close > hhv_prior
                        && d1_ema_1 > d1_ema_lag
                        && d1c1.close > d1_ema_1
                        && bars_since_long > cooldown_bars;

   const bool short_ok = (minusDI1 > plusDI1)
                         && FreshCrossDown(_Symbol, fresh_cross_window)
                         && macd_hist1 < 0.0
                         && c1.close < llv_prior
                         && d1_ema_1 < d1_ema_lag
                         && d1c1.close < d1_ema_1
                         && bars_since_short > cooldown_bars;

   if(long_ok)
     {
      req.type   = QM_BUY;
      req.price  = ask;
      req.sl     = QM_StopATR(_Symbol, QM_BUY, req.price, atr_period, sl_atr_mult);
      req.tp     = 0.0;
      req.reason = "hopwood_ts5_long";
      g_last_long_entry_time = c1.time;
      return true;
     }

   if(short_ok)
     {
      req.type   = QM_SELL;
      req.price  = bid;
      req.sl     = QM_StopATR(_Symbol, QM_SELL, req.price, atr_period, sl_atr_mult);
      req.tp     = 0.0;
      req.reason = "hopwood_ts5_short";
      g_last_short_entry_time = c1.time;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Opposite full-stack flip → close; else 2-stage ATR/PSAR trail.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();

   // Recompute the full stack once per call (same formulas as entry).
   const double plusDI1  = QM_ADX_PlusDI(_Symbol, PERIOD_CURRENT, dmi_period, 1);
   const double minusDI1 = QM_ADX_MinusDI(_Symbol, PERIOD_CURRENT, dmi_period, 1);
   const double macd_hist1 = QM_MACD_Main(_Symbol, PERIOD_CURRENT, macd_fast, macd_slow, macd_signal, 1)
                             - QM_MACD_Signal(_Symbol, PERIOD_CURRENT, macd_fast, macd_slow, macd_signal, 1);

   MqlRates c1;
   if(!QM_ReadBar(_Symbol, PERIOD_CURRENT, 1, c1))
      return;
   const double hhv_prior = DonchianHHV_priorRef(_Symbol, donchian_period);
   const double llv_prior = DonchianLLV_priorRef(_Symbol, donchian_period);

   const double d1_ema_1   = QM_EMA(_Symbol, PERIOD_D1, d1_ema_period, 1);
   const double d1_ema_lag = QM_EMA(_Symbol, PERIOD_D1, d1_ema_period, 1 + d1_slope_lookback);
   MqlRates d1c1;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, d1c1))
      return;

   const double atr14_1 = QM_ATR(_Symbol, PERIOD_CURRENT, atr_period, 1);
   if(atr14_1 <= 0.0)
      return;

   const bool short_stack_full = (minusDI1 > plusDI1)
                                 && FreshCrossDown(_Symbol, fresh_cross_window)
                                 && macd_hist1 < 0.0
                                 && c1.close < llv_prior
                                 && d1_ema_1 < d1_ema_lag
                                 && d1c1.close < d1_ema_1;

   const bool long_stack_full = (plusDI1 > minusDI1)
                                && FreshCrossUp(_Symbol, fresh_cross_window)
                                && macd_hist1 > 0.0
                                && c1.close > hhv_prior
                                && d1_ema_1 > d1_ema_lag
                                && d1c1.close > d1_ema_1;

   const double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double sar_1 = QM_SAR(_Symbol, PERIOD_CURRENT, psar_step, psar_max, 1);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double cur_sl     = PositionGetDouble(POSITION_SL);

      // Opposite full-stack flip → immediate close.
      if(ptype == POSITION_TYPE_BUY && short_stack_full)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
        }
      if(ptype == POSITION_TYPE_SELL && long_stack_full)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
        }

      // 2-stage trail.
      const double profit_dist = (ptype == POSITION_TYPE_BUY) ? (bid - open_price) : (open_price - ask);
      if(profit_dist >= trail_activate_atr_mult * atr14_1)
        {
         // Stage 2 — PSAR trail; only move SL if PSAR improves the current stop.
         if(ptype == POSITION_TYPE_BUY)
           {
            if(sar_1 > 0.0 && sar_1 < bid && (cur_sl <= 0.0 || sar_1 > cur_sl))
               QM_TM_MoveSL(ticket, sar_1, "psar_trail_stage2");
           }
         else
           {
            if(sar_1 > 0.0 && sar_1 > ask && (cur_sl <= 0.0 || sar_1 < cur_sl))
               QM_TM_MoveSL(ticket, sar_1, "psar_trail_stage2");
           }
        }
      else
        {
         // Stage 1 — ATR trail.
         QM_TM_TrailATR(ticket, atr_period, sl_atr_mult);
        }
     }
  }

// TS5 exit is handled inside ManageOpenPosition (flip-close + trail). No
// separate discretionary exit.
bool Strategy_ExitSignal()
  {
   return false;
  }

// Defer entirely to the central 2-axis news filter.
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
