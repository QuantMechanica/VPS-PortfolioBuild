#property strict
#property version   "5.0"
#property description "QM5_9641 Bandy CCI Extreme Fade (Mean-Reversion, Long-Only, Index, D1)"
// Strategy Card: QM5_9641 (bandy-cci-extreme-fade-mr-index), G0 APPROVED.
// Source lineage: 9ef19e06-5ca6-5b35-aa06-b8187aa0e016 (Howard Bandy,
// "Quantitative Technical Analysis", Blue Owl Press 2015, ISBN 978-0-9791037-7-1).
// Lambert CCI(20) extreme-fade with a long SMA regime gate, long-only per Bandy's
// equity-index treatment.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — Bandy CCI Extreme Fade (daily, long-only mean reversion).
// -----------------------------------------------------------------------------
// All strategy math runs on CLOSED D1 bars (shift 1). On each new D1 bar the EA
// caches: cci = QM_CCI(20, D1) (Lambert typical-price formulation), the 200-day
// close SMA regime gate, the latest closed close, ATR(14, D1), and the
// ATR/close volatility ratio. A rolling 252-bar buffer of that ratio drives a
// bespoke "no-trade-on-chaos" percentile filter (blocks new entries when the
// current ratio is in the top 1st percentile of the trailing window). The
// per-tick path only reads cached state + current Ask/Bid.
//
// ENTRY (LONG only): CCI(20) <= -100 AND Close > SMA(Close,200) -> enter long at
//        the next session open (first tick of the new D1 bar). Short side is
//        disabled entirely (Bandy long-only index treatment). One position per
//        magic; no pyramiding.
// EXIT : take-profit when CCI(20) crosses back to >= 0 (zero-line) -> close at the
//        next session open (== the signal bar's close on gapless .DWX index CFDs,
//        open[0]==close[1]); OR a 7-trading-day (7 closed D1 bars) time stop; OR a
//        broker-side hard stop set at entry to 2.5*ATR(14,D1).
// FILTER: incomplete-daily-bar skip is intrinsic to the closed-bar cadence; the
//        vol-percentile chaos filter gates new entries only; the news temporal
//        gate (PRE30_POST30, ±30min high-impact) gates new entries only and never
//        suspends management/exits (audit-binding OnTick ordering).
// Broker-time native: D1 bar boundary is the broker day open; no UTC/DST
// conversion is needed for the daily cadence.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9641;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// Card: skip new entries within +/-30 min of high-impact macro releases
// (NFP/FOMC/CPI). Temporal axis = PRE30_POST30 (±30min); DXZ compliance overlay
// for the live venue. Gate applies to NEW ENTRIES ONLY (management/exits run
// through news windows).
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
// OFF: a daily mean-reversion hold spans up to 7 trading days across weekends; a
// Friday flatten would truncate every multi-day hold.
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_cci_period        = 20;      // Card: Lambert CCI period (D1).
input double strategy_cci_entry         = -100.0;  // Card: enter long when CCI <= this.
input double strategy_cci_exit          = 0.0;     // Card: take-profit when CCI back >= this (zero line).
input int    strategy_regime_ma_period  = 200;     // Card: long-only regime gate SMA(Close,200,D1).
input int    strategy_atr_period        = 14;      // Card: ATR(14,D1) stop-distance basis.
input double strategy_atr_sl_mult       = 2.5;     // Card: hard SL = entry - 2.5*ATR(14,D1).
input int    strategy_time_stop_days    = 7;       // Card: force exit after 7 closed D1 bars.
input int    strategy_vol_lookback      = 252;     // Card: trailing-window length for the chaos filter.
input double strategy_vol_top_pctile    = 1.0;     // Card: skip if ATR/close in top Nth percentile.

// -----------------------------------------------------------------------------
// File-scope cached state (advanced once per new closed D1 bar).
// -----------------------------------------------------------------------------
bool   g_state_valid = false;
double g_cci_curr  = 0.0;   // CCI at shift 1 (latest closed D1 bar).
double g_close_curr = 0.0;  // latest closed D1 close (regime gate + vol denominator).
double g_sma_regime = 0.0;  // SMA(Close, regime_ma_period, D1) at shift 1.
double g_atr14      = 0.0;  // ATR(atr_period, D1) at shift 1.
bool   g_chaos_block = false; // true when the current vol ratio is in the top percentile.

// Rolling vol-ratio ring buffer for the bespoke percentile filter.
double g_vol_ring[];        // sized to strategy_vol_lookback.
int    g_vol_head  = 0;     // next write index (ring).
int    g_vol_count = 0;     // filled samples (caps at strategy_vol_lookback).
bool   g_ring_init = false;

int    g_pos_dir   = 0;     // 0 flat / +1 long (short never used).
int    g_bars_held = 0;     // closed D1 bars since entry.
bool   g_pending_long = false;
bool   g_exit_now  = false; // set on TP (CCI>=0) or time stop.
bool   g_we_closed = false; // true once THIS EA issued the close (vs broker SL hit).
QM_ExitReason g_exit_reason = QM_EXIT_STRATEGY;

// -----------------------------------------------------------------------------
// Bespoke rolling-percentile chaos filter — computed ONCE per new D1 bar from
// cached closed-bar history (not per tick). Returns true when the current
// ATR/close ratio sits in the top `strategy_vol_top_pctile` percent of the
// trailing `strategy_vol_lookback`-bar window (window includes the current bar).
// -----------------------------------------------------------------------------
bool ComputeChaosBlock(const double vol_ratio_now)
  {
   if(g_vol_count < strategy_vol_lookback)
      return false;                       // window not full yet — cannot rank; do not block.
   if(vol_ratio_now <= 0.0)
      return false;

   double tmp[];
   ArrayResize(tmp, g_vol_count);
   for(int i = 0; i < g_vol_count; i++)
      tmp[i] = g_vol_ring[i];
   ArraySort(tmp);                         // ascending.

   double frac = 1.0 - (strategy_vol_top_pctile / 100.0);
   if(frac < 0.0) frac = 0.0;
   if(frac > 1.0) frac = 1.0;
   int idx = (int)MathRound(frac * (g_vol_count - 1));
   if(idx < 0) idx = 0;
   if(idx > g_vol_count - 1) idx = g_vol_count - 1;

   const double threshold = tmp[idx];      // (1 - pctile) quantile of the trailing window.
   return (vol_ratio_now >= threshold);
  }

// Advance the cached CCI/regime/ATR state, the rolling vol ring, and the
// entry/exit decision flags once per new closed D1 bar.
void AdvanceDaily()
  {
   g_state_valid = false;

   if(!g_ring_init || ArraySize(g_vol_ring) != strategy_vol_lookback)
     {
      ArrayResize(g_vol_ring, strategy_vol_lookback);
      ArrayInitialize(g_vol_ring, 0.0);
      g_vol_head = 0;
      g_vol_count = 0;
      g_ring_init = true;
     }

   const double cci_curr   = QM_CCI(_Symbol, PERIOD_D1, strategy_cci_period, 1, PRICE_TYPICAL);
   const double sma_regime = QM_SMA(_Symbol, PERIOD_D1, strategy_regime_ma_period, 1, PRICE_CLOSE);
   const double atr14      = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double close_curr = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: regime gate + vol denominator, once per new D1 bar.
   if(sma_regime <= 0.0 || atr14 <= 0.0 || close_curr <= 0.0)
      return; // insufficient history — leave g_state_valid = false.

   const double vol_ratio = atr14 / close_curr;

   // Push the current vol ratio into the ring (advance by one bar).
   g_vol_ring[g_vol_head] = vol_ratio;
   g_vol_head = (g_vol_head + 1) % strategy_vol_lookback;
   if(g_vol_count < strategy_vol_lookback)
      g_vol_count++;

   g_cci_curr    = cci_curr;
   g_close_curr  = close_curr;
   g_sma_regime  = sma_regime;
   g_atr14       = atr14;
   g_chaos_block = ComputeChaosBlock(vol_ratio);
   g_state_valid = true;

   // Recompute the pending entry fresh each bar (level-triggered signal).
   g_pending_long = false;

   if(g_pos_dir != 0)
     {
      g_bars_held++;
      if(cci_curr >= strategy_cci_exit)
        { g_exit_now = true; g_exit_reason = QM_EXIT_STRATEGY; }       // take-profit: CCI back to zero line.
      else if(g_bars_held >= strategy_time_stop_days)
        { g_exit_now = true; g_exit_reason = QM_EXIT_TIME_STOP; }      // 7-trading-day time stop.
     }
   else
     {
      // Long-only extreme fade under the regime gate. Chaos filter handled in
      // Strategy_NoTradeFilter (entry-path only).
      g_pending_long = (cci_curr <= strategy_cci_entry) && (close_curr > sma_regime);
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks.
// -----------------------------------------------------------------------------

// No Trade Filter — bespoke vol-percentile "no-trade-on-chaos" gate. Reads the
// cached g_chaos_block only (O(1)); this sits on the entry path in OnTick, so it
// blocks NEW entries without ever suspending management/exits.
bool Strategy_NoTradeFilter()
  {
   if(!g_state_valid)
      return false;
   return g_chaos_block;
  }

// Trade Entry — fires on the first tick of a new D1 bar when the CCI-fade signal
// was latched by AdvanceDaily. Long only. Reads cached state + current Ask only.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_state_valid)
      return false;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   if(g_pos_dir != 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false; // one position per magic; no pyramiding.
   if(!g_pending_long)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, g_atr14, strategy_atr_sl_mult);
   if(sl <= 0.0 || sl >= ask)
      return false; // invalid long stop geometry.

   req.type = QM_BUY;
   req.price = 0.0;   // market fill at send.
   req.sl = sl;
   req.tp = 0.0;      // no fixed TP; exit via CCI zero-line / time stop / hard SL.
   req.reason = "CCI_FADE_LONG_D1";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_pos_dir = 1; g_bars_held = 0; g_exit_now = false; g_we_closed = false;
   g_pending_long = false;
   return true;
  }

// Trade Management — reconcile cached direction against live positions. If a
// position vanished without THIS EA issuing the close, it was the broker-side ATR
// hard stop -> reset cached state. O(1), reads cached state only (no trailing:
// the card SL is a fixed hard stop).
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;
   if(g_pos_dir != 0 && QM_TM_OpenPositionCount(magic) == 0)
     {
      g_pos_dir = 0; g_bars_held = 0; g_exit_now = false; g_we_closed = false;
     }
  }

// Trade Close — reads the once-per-bar exit latch (CCI zero-line TP or time stop).
// The 2.5*ATR hard stop rides broker-side independently.
bool Strategy_ExitSignal()
  {
   if(g_pos_dir == 0)
      return false;
   return g_exit_now;
  }

// News Filter Hook — defer to the central gate (temporal PRE30_POST30 applied in
// the OnTick entry path via QM_NewsAllowsTrade2).
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — closed-bar (D1) cadence. State advances on the D1 new-bar
// latch; management + exits run every tick; only NEW entries pass chaos/news.
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
                        qm_news_temporal,              // FW1 Axis A (±30min)
                        qm_news_compliance))           // FW1 Axis B (DXZ overlay)
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_9641_bandy-cci-extreme-fade-mr-index\"}");
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
   // return.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose())
      return;

   // Advance cached daily state once per new closed D1 bar.
   if(QM_IsNewBar(_Symbol, PERIOD_D1))
     {
      AdvanceDaily();
      QM_EquityStreamOnNewBar();
     }

   // Management + rule-based exits run EVERY tick, through news/chaos windows.
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
         QM_TM_ClosePosition(ticket, g_exit_reason);
         g_we_closed = true;
        }
     }

   // ---- entry path (gates NEW entries only; never management/exits above) ----
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(Strategy_NoTradeFilter())
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   // NOTE: do NOT re-call QM_IsNewBar here — it is single-consume per tick and the
   // AdvanceDaily block above already consumed the D1 new-bar event. g_pending_long
   // is set ONLY inside AdvanceDaily and cleared on fire, so entry already occurs
   // strictly on the new-bar edge.
   QM_EntryRequest req;
   ZeroMemory(req);
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
