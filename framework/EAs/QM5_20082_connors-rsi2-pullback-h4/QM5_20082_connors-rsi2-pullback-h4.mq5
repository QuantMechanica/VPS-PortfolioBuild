#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA — QM5_20082 connors-rsi2-pullback-h4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_20082 connors-rsi2-pullback-h4
// -----------------------------------------------------------------------------
// Connors RSI(2) pullback-in-trend mean reversion on H4. Six-gate entry:
//   1. SMA(200,H4) long-term trend filter
//   2. RSI(2,H4) extreme (<10 long / >90 short)
//   3. Pullback magnitude >= 0.5*ATR(20,H4) over the past 3 bars
//   4. D1 SMA(50) macro-bias agreement (rising for long / falling for short)
//   5. Entry-uniqueness — no same-direction entry within the past 10 H4 bars
//   6. Trend-establishment — >=8 of the past 12 bars on the trend side of SMA200
// Exits (all in Strategy_ManageOpenPosition): time-stop 12 bars, RSI-overshoot
// hard exit within first 3 bars, TP1 partial 75% at SMA(5) mean-line touch,
// TP2 remainder at SMA(10) mean-line touch. Backstop SL at 1.5*ATR(20,H4).
//
// Only QM_* helpers used for indicators / bar reads / stops / trade management.
// Framework wiring below the marker line is untouched.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20082;
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
input int    rsi_period                 = 2;
input double rsi_oversold               = 10.0;
input double rsi_overbought             = 90.0;
input int    trend_sma_period           = 200;
input int    exit_sma_fast              = 5;
input int    exit_sma_mid               = 10;
input int    atr_period                 = 20;
input double pullback_atr_mult          = 0.5;
input int    entry_uniqueness_bars      = 10;
input int    trend_establish_lookback   = 12;
input int    trend_establish_min_bars   = 8;
input double sl_atr_mult                = 1.5;
input int    time_stop_bars             = 12;
input double rsi_overshoot              = 95.0;
input int    rsi_overshoot_window_bars  = 3;
input double spread_atr_mult_cap        = 0.15;
input double partial_close_pct          = 0.75;

// File-scope strategy state.
datetime g_last_long_entry_time  = 0;
datetime g_last_short_entry_time = 0;
datetime g_position_entry_time   = 0;
bool     g_tp1_done              = false;

// Bars elapsed since a stored bar-open timestamp. t==0 -> "very long ago".
int BarsSinceTime(const datetime t)
  {
   if(t <= 0)
      return 999999;
   // perf-allowed structural bar-index lookup
   const int shift = iBarShift(_Symbol, PERIOD_CURRENT, t, false);
   if(shift < 0)
      return 999999;
   return shift;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // 1. Bar reads: last closed bar (shift 1) and the pullback reference (shift 4).
   MqlRates c1, c4;
   if(!QM_ReadBar(_Symbol, PERIOD_CURRENT, 1, c1))
      return false;
   if(!QM_ReadBar(_Symbol, PERIOD_CURRENT, 4, c4))
      return false;

   // 2. Indicators.
   const double sma200_1   = QM_SMA(_Symbol, PERIOD_CURRENT, trend_sma_period, 1);
   const double rsi2_1     = QM_RSI(_Symbol, PERIOD_CURRENT, rsi_period, 1);
   const double atr20_1    = QM_ATR(_Symbol, PERIOD_CURRENT, atr_period, 1);
   const double d1_sma50_1  = QM_SMA(_Symbol, PERIOD_D1, 50, 1);
   const double d1_sma50_11 = QM_SMA(_Symbol, PERIOD_D1, 50, 11);
   if(sma200_1 <= 0.0 || atr20_1 <= 0.0)
      return false;

   // 3. Spread filter (do NOT fail-closed on zero spread — .DWX quotes 0 in tester).
   const double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(spread > 0.0 && spread > spread_atr_mult_cap * atr20_1)
      return false;

   // 4. Gate 6 helper: count bars above/below SMA200 over the establishment window.
   int bars_above = 0;
   int bars_below = 0;
   for(int j = 1; j <= trend_establish_lookback; ++j)
     {
      MqlRates cj;
      if(!QM_ReadBar(_Symbol, PERIOD_CURRENT, j, cj))
         continue;
      const double sma_j = QM_SMA(_Symbol, PERIOD_CURRENT, trend_sma_period, j);
      if(sma_j <= 0.0)
         continue;
      if(cj.close > sma_j)
         bars_above++;
      else if(cj.close < sma_j)
         bars_below++;
     }

   // 5. Entry-uniqueness (Gate 5).
   const int bars_since_long  = BarsSinceTime(g_last_long_entry_time);
   const int bars_since_short = BarsSinceTime(g_last_short_entry_time);

   // 6. Long gate composite.
   const bool long_ok =
      c1.close > sma200_1 &&
      rsi2_1 < rsi_oversold &&
      c1.close <= c4.close - pullback_atr_mult * atr20_1 &&
      d1_sma50_1 >= d1_sma50_11 &&
      bars_since_long > entry_uniqueness_bars &&
      bars_above >= trend_establish_min_bars;

   // 7. Short gate composite (mirror).
   const bool short_ok =
      c1.close < sma200_1 &&
      rsi2_1 > rsi_overbought &&
      c1.close >= c4.close + pullback_atr_mult * atr20_1 &&
      d1_sma50_1 <= d1_sma50_11 &&
      bars_since_short > entry_uniqueness_bars &&
      bars_below >= trend_establish_min_bars;

   // 8. Long entry.
   if(long_ok)
     {
      req.type   = QM_BUY;
      req.price  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.sl     = QM_StopATR(_Symbol, QM_BUY, req.price, atr_period, sl_atr_mult);
      req.tp     = 0.0;
      req.reason = "connors_rsi2_pullback_long";
      g_last_long_entry_time = c1.time;
      g_position_entry_time  = c1.time;
      g_tp1_done             = false;
      return true;
     }

   // 9. Short entry (mirror).
   if(short_ok)
     {
      req.type   = QM_SELL;
      req.price  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.sl     = QM_StopATR(_Symbol, QM_SELL, req.price, atr_period, sl_atr_mult);
      req.tp     = 0.0;
      req.reason = "connors_rsi2_pullback_short";
      g_last_short_entry_time = c1.time;
      g_position_entry_time   = c1.time;
      g_tp1_done              = false;
      return true;
     }

   // 10. No signal.
   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Connors-canonical exits: time-stop, RSI-overshoot, TP1 partial at SMA(5),
// TP2 remainder at SMA(10).
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const int    bars_since_entry = (g_position_entry_time > 0)
                                   ? BarsSinceTime(g_position_entry_time) : 0;
   const double sma5_1  = QM_SMA(_Symbol, PERIOD_CURRENT, exit_sma_fast, 1);
   const double sma10_1 = QM_SMA(_Symbol, PERIOD_CURRENT, exit_sma_mid, 1);
   const double rsi2_1  = QM_RSI(_Symbol, PERIOD_CURRENT, rsi_period, 1);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const bool is_buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);

      // Time-stop.
      if(bars_since_entry >= time_stop_bars)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
        }

      // RSI-overshoot hard exit within the early window.
      if(bars_since_entry <= rsi_overshoot_window_bars)
        {
         if(is_buy && rsi2_1 > rsi_overshoot)
           {
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
            continue;
           }
         if(!is_buy && rsi2_1 < (100.0 - rsi_overshoot))
           {
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
            continue;
           }
        }

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      // TP1 — partial 75% at the SMA(5) mean-line touch (once).
      if(!g_tp1_done && sma5_1 > 0.0)
        {
         if(is_buy && bid >= sma5_1)
           {
            QM_TM_PartialClose(ticket, PositionGetDouble(POSITION_VOLUME) * partial_close_pct, QM_EXIT_STRATEGY);
            g_tp1_done = true;
            continue;
           }
         if(!is_buy && ask <= sma5_1)
           {
            QM_TM_PartialClose(ticket, PositionGetDouble(POSITION_VOLUME) * partial_close_pct, QM_EXIT_STRATEGY);
            g_tp1_done = true;
            continue;
           }
        }

      // TP2 — close the remainder at the SMA(10) mean-line touch (after TP1).
      if(g_tp1_done && sma10_1 > 0.0)
        {
         if(is_buy && bid >= sma10_1)
           {
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
            continue;
           }
         if(!is_buy && ask <= sma10_1)
           {
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
            continue;
           }
        }
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // All exits handled in Strategy_ManageOpenPosition (HR14 one-pos-per-magic).
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // framework's own 2-axis news gate already applies
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
