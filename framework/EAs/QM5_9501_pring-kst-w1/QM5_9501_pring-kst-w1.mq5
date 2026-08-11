#property strict
#property version   "5.0"
#property description "QM5_9501 Pring Know-Sure-Thing (KST) Signal-Line Cross (W1)"
// Strategy Card: QM5_9501 (pring-kst-w1), G0 APPROVED.
// Source lineage: 6e967762-b26d-59a3-b076-35c17f2e7c36 (ForexFactory Trading
// Systems, Martin Pring long-term-KST thread cluster). Long-term (weekly) KST
// parameter set per Pring 1993 "Martin Pring on Market Momentum" ch. 8-9.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — Pring long-term KST Signal-Line Cross (weekly).
// -----------------------------------------------------------------------------
// KST is a weighted composite of four SMA-smoothed Rate-of-Change series, all on
// CLOSED W1 bars:
//   rcma1 = SMA(ROC(9) , 6)   rcma2 = SMA(ROC(12), 6)
//   rcma3 = SMA(ROC(18), 6)   rcma4 = SMA(ROC(24), 9)
//   KST   = 1*rcma1 + 2*rcma2 + 3*rcma3 + 4*rcma4
//   Signal= SMA(KST, 9)
// The composite has no QM_Indicators equivalent, so it is reconstructed once per
// new W1 bar from closed-bar closes (iClose shift>=1, // perf-allowed) inside the
// QM_IsNewBar(_Symbol,PERIOD_W1) gate and cached in file-scope state. The 40-week
// bias MA and the ATR(14,W1) stop distance use the framework readers QM_SMA /
// QM_ATR (handle-pooled). The per-tick path only reads cached state.
//
// LONG  : Close > SMA(Close,40) AND KST crosses ABOVE Signal AND KST > 0.
// SHORT : Close < SMA(Close,40) AND KST crosses BELOW Signal AND KST < 0.
//         Entry fires at the new W1 bar's market open (first tick of the bar).
// EXIT  : opposite KST/Signal cross, OR 26-W1-bar time stop, OR broker-side
//         3.0*ATR(14,W1) hard stop set at entry (rides on the server).
// GUARD : no fresh entry within 4 W1 bars of a prior stop-loss exit (whipsaw).
//         Spread filter: skip entry if spread > 0.05*ATR(14,W1) (never blocks on
//         .DWX zero modeled spread). News temporal gate OFF (card: not applied to
//         W1 entries). Friday-close flatten OFF (multi-week position holds).
// Broker-time native: the W1 bar boundary is the broker week open; no UTC/DST
// conversion is needed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9501;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// Card: news filter NOT applied to W1 entries (HIGH events are intra-day and
// average out over a multi-week hold). Temporal axis OFF; DXZ compliance overlay
// retained for the live venue (no extra backtest blackout).
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
// OFF: this is a weekly position EA that holds across many Fridays; a Friday
// flatten would truncate every multi-week hold.
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_roc1_period       = 9;    // Card: ROC lookback 1 (W1 bars).
input int    strategy_roc2_period       = 12;   // Card: ROC lookback 2 (W1 bars).
input int    strategy_roc3_period       = 18;   // Card: ROC lookback 3 (W1 bars).
input int    strategy_roc4_period       = 24;   // Card: ROC lookback 4 (W1 bars).
input int    strategy_rcma_short        = 6;    // Card: SMA smoothing for ROC1..ROC3.
input int    strategy_rcma_long         = 9;    // Card: SMA smoothing for ROC4.
input int    strategy_signal_period     = 9;    // Card: Signal = SMA(KST, 9).
input int    strategy_bias_ma_period    = 40;   // Card: 40-week close SMA regime filter.
input int    strategy_atr_period        = 14;   // Card: ATR(14, W1) stop-distance basis.
input double strategy_atr_sl_mult       = 3.0;  // Card: SL = entry -/+ 3.0*ATR(14,W1).
input int    strategy_time_stop_bars    = 26;   // Card: time stop after 26 closed W1 bars.
input int    strategy_reentry_block_bars= 4;    // Card: no re-entry within 4 W1 bars of an SL exit.
input double strategy_spread_atr_frac   = 0.05; // Card: skip entry if spread > 0.05*ATR(14,W1).

// KST composite weights are Pring's canonical long-term fixed constants (1,2,3,4)
// that define the indicator identity — held as literals, not tunables.
#define KST_W1 1.0
#define KST_W2 2.0
#define KST_W3 3.0
#define KST_W4 4.0

// -----------------------------------------------------------------------------
// File-scope cached state (advanced once per new W1 bar).
// -----------------------------------------------------------------------------
bool   g_state_valid = false;
double g_kst_curr = 0.0, g_kst_prev = 0.0;   // KST at shift 1 (latest closed) / shift 2.
double g_sig_curr = 0.0, g_sig_prev = 0.0;   // Signal at shift 1 / shift 2.
double g_close_curr = 0.0;                    // latest closed W1 close.
double g_sma_bias   = 0.0;                    // SMA(Close, bias_period) on W1.
double g_atr14      = 0.0;                    // ATR(atr_period, W1) snapshot.

int    g_pos_dir   = 0;      // 0 flat / +1 long / -1 short.
int    g_bars_held = 0;      // closed W1 bars since entry.
int    g_reentry_block = 0;  // W1 bars remaining in the post-SL re-entry block.
bool   g_pending_long  = false;
bool   g_pending_short = false;
bool   g_exit_now  = false;  // set on opposite-cross or time-stop.
bool   g_we_closed = false;  // true once THIS EA issued the close (distinguishes SL exits).
QM_ExitReason g_exit_reason = QM_EXIT_STRATEGY;

// -----------------------------------------------------------------------------
// KST reconstruction — bespoke composite, no QM_Indicators equivalent.
// perf-allowed: all reads are closed-bar W1 (shift>=1) and run ONCE per new W1
// bar inside the QM_IsNewBar(_Symbol,PERIOD_W1) gate (not per tick).
// -----------------------------------------------------------------------------
bool ComputeKSTAt(const int base_shift, double &kst_out)
  {
   double rcma1 = 0.0, rcma2 = 0.0, rcma3 = 0.0, rcma4 = 0.0;

   // rcma1/2/3: SMA over strategy_rcma_short of ROC(9)/ROC(12)/ROC(18).
   for(int k = 0; k < strategy_rcma_short; k++)
     {
      const int s = base_shift + k;
      const double c  = iClose(_Symbol, PERIOD_W1, s);                        // perf-allowed
      const double c1 = iClose(_Symbol, PERIOD_W1, s + strategy_roc1_period); // perf-allowed
      const double c2 = iClose(_Symbol, PERIOD_W1, s + strategy_roc2_period); // perf-allowed
      const double c3 = iClose(_Symbol, PERIOD_W1, s + strategy_roc3_period); // perf-allowed
      if(c <= 0.0 || c1 <= 0.0 || c2 <= 0.0 || c3 <= 0.0)
         return false;
      rcma1 += (c - c1) / c1 * 100.0;
      rcma2 += (c - c2) / c2 * 100.0;
      rcma3 += (c - c3) / c3 * 100.0;
     }
   rcma1 /= strategy_rcma_short;
   rcma2 /= strategy_rcma_short;
   rcma3 /= strategy_rcma_short;

   // rcma4: SMA over strategy_rcma_long of ROC(24).
   for(int k = 0; k < strategy_rcma_long; k++)
     {
      const int s = base_shift + k;
      const double c  = iClose(_Symbol, PERIOD_W1, s);                        // perf-allowed
      const double c4 = iClose(_Symbol, PERIOD_W1, s + strategy_roc4_period); // perf-allowed
      if(c <= 0.0 || c4 <= 0.0)
         return false;
      rcma4 += (c - c4) / c4 * 100.0;
     }
   rcma4 /= strategy_rcma_long;

   kst_out = KST_W1 * rcma1 + KST_W2 * rcma2 + KST_W3 * rcma3 + KST_W4 * rcma4;
   return true;
  }

// Advance the cached KST/Signal/bias/ATR state and the entry/exit decision flags
// once per new closed W1 bar.
void AdvanceWeekly()
  {
   g_state_valid = false;

   // Whipsaw guard countdown (one step per new W1 bar).
   if(g_reentry_block > 0)
      g_reentry_block--;

   const int nvals = strategy_signal_period + 1; // KST at shifts 1..nvals.
   double kbuf[];
   ArrayResize(kbuf, nvals + 1); // index 1..nvals used.
   for(int b = 1; b <= nvals; b++)
     {
      double kv = 0.0;
      if(!ComputeKSTAt(b, kv))
         return; // insufficient history — leave g_state_valid = false.
      kbuf[b] = kv;
     }

   double sum_curr = 0.0, sum_prev = 0.0;
   for(int b = 1; b <= strategy_signal_period; b++)
      sum_curr += kbuf[b];                  // shifts 1..P.
   for(int b = 2; b <= strategy_signal_period + 1; b++)
      sum_prev += kbuf[b];                  // shifts 2..P+1.

   const double kst_curr = kbuf[1];
   const double kst_prev = kbuf[2];
   const double sig_curr = sum_curr / strategy_signal_period;
   const double sig_prev = sum_prev / strategy_signal_period;

   const double close_curr = iClose(_Symbol, PERIOD_W1, 1); // perf-allowed: regime-filter close.
   const double sma_bias   = QM_SMA(_Symbol, PERIOD_W1, strategy_bias_ma_period, 1);
   const double atr14      = QM_ATR(_Symbol, PERIOD_W1, strategy_atr_period, 1);
   if(close_curr <= 0.0 || sma_bias <= 0.0 || atr14 <= 0.0)
      return;

   g_kst_curr = kst_curr; g_kst_prev = kst_prev;
   g_sig_curr = sig_curr; g_sig_prev = sig_prev;
   g_close_curr = close_curr; g_sma_bias = sma_bias; g_atr14 = atr14;
   g_state_valid = true;

   const bool long_cross  = (kst_prev <= sig_prev) && (kst_curr > sig_curr);
   const bool short_cross = (kst_prev >= sig_prev) && (kst_curr < sig_curr);

   // Recompute pending entries fresh each bar (crosses are edge events).
   g_pending_long  = false;
   g_pending_short = false;

   if(g_pos_dir != 0)
     {
      g_bars_held++;
      if(g_pos_dir > 0 && short_cross)
        { g_exit_now = true; g_exit_reason = QM_EXIT_OPPOSITE_SIGNAL; }
      else if(g_pos_dir < 0 && long_cross)
        { g_exit_now = true; g_exit_reason = QM_EXIT_OPPOSITE_SIGNAL; }
      else if(g_bars_held >= strategy_time_stop_bars)
        { g_exit_now = true; g_exit_reason = QM_EXIT_TIME_STOP; }
     }
   else if(g_reentry_block == 0)
     {
      g_pending_long  = long_cross  && (close_curr > sma_bias) && (kst_curr > 0.0);
      g_pending_short = short_cross && (close_curr < sma_bias) && (kst_curr < 0.0);
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks.
// -----------------------------------------------------------------------------

// No Trade Filter — spread gate only. Reads cached ATR; never fail-closed on the
// .DWX zero modeled spread (invariant #1).
bool Strategy_NoTradeFilter()
  {
   if(!g_state_valid)
      return false;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
     {
      const double cap = strategy_spread_atr_frac * g_atr14;
      if(cap > 0.0 && (ask - bid) > cap)
         return true;
     }
   return false;
  }

// Trade Entry — fires on the first tick of a new W1 bar when a fresh cross was
// latched by AdvanceWeekly. Reads cached state + current Ask/Bid only.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_state_valid)
      return false;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   if(g_pos_dir != 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;
   if(g_reentry_block > 0)
      return false;
   if(!g_pending_long && !g_pending_short)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(g_pending_long)
     {
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, g_atr14, strategy_atr_sl_mult);
      if(sl <= 0.0 || sl >= ask)
         return false; // invalid long stop geometry.
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = 0.0;      // no fixed TP; exit via opposite cross / time stop / SL.
      req.reason = "KST_CROSS_UP_W1";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      g_pos_dir = 1; g_bars_held = 0; g_exit_now = false; g_we_closed = false;
      g_pending_long = false;
      return true;
     }

   if(g_pending_short)
     {
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, bid, g_atr14, strategy_atr_sl_mult);
      if(sl <= bid)
         return false; // invalid short stop geometry (also catches sl==0).
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "KST_CROSS_DN_W1";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      g_pos_dir = -1; g_bars_held = 0; g_exit_now = false; g_we_closed = false;
      g_pending_short = false;
      return true;
     }

   return false;
  }

// Trade Management — reconcile cached direction against live positions. If a
// position vanished without THIS EA issuing the close, it was the broker-side ATR
// stop → arm the post-SL re-entry block. O(1), reads cached state only.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;
   if(g_pos_dir != 0 && QM_TM_OpenPositionCount(magic) == 0)
     {
      if(!g_we_closed)
         g_reentry_block = strategy_reentry_block_bars; // stop-loss whipsaw guard.
      g_pos_dir = 0; g_bars_held = 0; g_exit_now = false; g_we_closed = false;
     }
  }

// Trade Close — reads the once-per-bar exit latch (opposite cross / time stop).
// The 3.0*ATR hard stop rides broker-side independently.
bool Strategy_ExitSignal()
  {
   if(g_pos_dir == 0)
      return false;
   return g_exit_now;
  }

// News Filter Hook — defer to the central gate (temporal axis OFF per card).
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — closed-bar (W1) cadence. State advances on the W1 new-bar
// latch; management + exits run every tick; only NEW entries pass spread/news.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_9501_pring-kst-w1\"}");
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

   // Advance cached weekly state once per new closed W1 bar.
   if(QM_IsNewBar(_Symbol, PERIOD_W1))
     {
      AdvanceWeekly();
      QM_EquityStreamOnNewBar();
     }

   // Management + rule-based exits run EVERY tick, through news/spread windows.
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
