#property strict
#property version   "5.0"
#property description "QM5_1287 MTF MACD histogram-divergence (H4 anchor + H1 trigger)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_1287 mtf-macd-histogram-divergence
// -----------------------------------------------------------------------------
// H4 anchor / H1 trigger price-vs-MACD-histogram divergence fade.
//
//   1. H4 3-bar fractal swing detector: a confirmed swing-high sits at H4
//      shift 4 when its high exceeds the 1 bar before it and the 3 bars closed
//      past it (card formula H[i+1] > H[i+2] & > H[i] & > H[i-1] & > H[i-2]);
//      mirrored for swing-lows. Kept as a 2-entry ring buffer (newest, older).
//   2. Divergence latch (H4): bearish when SH[1].price > SH[2].price AND
//      SH[1].hist < SH[2].hist AND SH[1].hist > 0 (mirror for bullish). Latch
//      expires 24 H1 bars after confirmation.
//   3. Entry (H1): on the latched-direction H1 histogram zero-cross, rejected
//      only when the H4 EMA(50) slope runs sharply WITH the trend the
//      divergence fades ( |slope| > 2*ATR(14,H4) ). Latch consumed on entry.
//   4. Exit: primary H1 histogram opposite zero-cross; secondary hard TP at
//      2*ATR(14,H4); tertiary 48 H1-bar time stop. SL at the triggering swing
//      extremum +/- 0.3*ATR(14,H4), floored at 0.5*ATR(14,H4) min distance.
//
// The H4 structural / divergence-latch state is advanced ONCE per closed H4
// bar (QM_IsNewBar(_Symbol, PERIOD_H4), a distinct new-bar key from the
// framework's bare H1 entry gate). The H1 zero-cross confirmation runs on the
// framework's per-H1-bar entry gate. The hand-rolled fractal reads iHigh/iLow
// directly (bespoke structural logic) and is marked // perf-allowed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1287;
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
input int    strategy_macd_fast          = 12;    // MACD fast EMA (H4 anchor + H1 trigger)
input int    strategy_macd_slow          = 26;    // MACD slow EMA
input int    strategy_macd_signal        = 9;     // MACD signal EMA
input int    strategy_ema_period         = 50;    // H4 regime EMA
input int    strategy_atr_period         = 14;    // H4 ATR period (SL/TP/slope scale)
input double strategy_atr_tp_mult        = 2.0;   // TP = mult * ATR(H4)
input double strategy_sl_buffer_atr_mult = 0.3;   // SL buffer beyond swing extremum
input double strategy_sl_floor_atr_mult  = 0.5;   // min SL distance floor (ATR mult)
input double strategy_slope_atr_mult     = 2.0;   // EMA slope reject threshold (ATR mult)
input int    strategy_latch_max_h1_bars  = 24;    // divergence latch lifetime (H1 bars)
input int    strategy_max_hold_h1_bars   = 48;    // tertiary time stop (H1 bars)
input int    strategy_skip_bars_open     = 2;     // skip first N H1 bars of broker day
input int    strategy_skip_bars_close    = 2;     // skip last N H1 bars of broker day
input int    strategy_spread_cap_pips    = 25;    // block genuinely wide spread (pips)

// -----------------------------------------------------------------------------
// Strategy state (advanced once per closed H4 bar). Ring buffers hold the two
// most recent confirmed H4 swing extremes: index 0 = newest, 1 = older.
// -----------------------------------------------------------------------------
double   g_sh_price[2];              // confirmed swing-high prices
double   g_sh_hist[2];               // MACD-hist(H4) at those swing-high bars
int      g_sh_count               = 0;
double   g_sl_price[2];              // confirmed swing-low prices
double   g_sl_hist[2];               // MACD-hist(H4) at those swing-low bars
int      g_sl_count               = 0;

int      g_latch_dir              = 0;    // -1 bearish (short) / +1 bullish (long) / 0 none
datetime g_latch_stamp            = 0;    // H4-close time when latch was set
double   g_latch_swing_price      = 0.0;  // swing extremum used for the stop

// MACD histogram = MAIN(MACD line) - SIGNAL, per the card.
double H4Hist(const int shift)
  {
   return QM_MACD_Main(_Symbol, PERIOD_H4, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift)
        - QM_MACD_Signal(_Symbol, PERIOD_H4, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);
  }

double H1Hist(const int shift)
  {
   return QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift)
        - QM_MACD_Signal(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);
  }

// Advance the H4 fractal / divergence-latch state by one closed H4 bar.
void AdvanceH4State()
  {
   // Hand-rolled 3-bar fractal: candidate at H4 shift 4 (3 bars have closed
   // past it). iHigh/iLow are bespoke structural reads -> // perf-allowed.
   const double h1 = iHigh(_Symbol, PERIOD_H4, 1); // perf-allowed
   const double h2 = iHigh(_Symbol, PERIOD_H4, 2); // perf-allowed
   const double h3 = iHigh(_Symbol, PERIOD_H4, 3); // perf-allowed
   const double h4 = iHigh(_Symbol, PERIOD_H4, 4); // perf-allowed
   const double h5 = iHigh(_Symbol, PERIOD_H4, 5); // perf-allowed
   const double l1 = iLow(_Symbol, PERIOD_H4, 1);  // perf-allowed
   const double l2 = iLow(_Symbol, PERIOD_H4, 2);  // perf-allowed
   const double l3 = iLow(_Symbol, PERIOD_H4, 3);  // perf-allowed
   const double l4 = iLow(_Symbol, PERIOD_H4, 4);  // perf-allowed
   const double l5 = iLow(_Symbol, PERIOD_H4, 5);  // perf-allowed
   if(h1 <= 0.0 || h2 <= 0.0 || h3 <= 0.0 || h4 <= 0.0 || h5 <= 0.0 ||
      l1 <= 0.0 || l2 <= 0.0 || l3 <= 0.0 || l4 <= 0.0 || l5 <= 0.0)
      return;

   // Confirmed swing HIGH at shift 4: higher than the bar before + the 3 after.
   if(h4 > h5 && h4 > h3 && h4 > h2 && h4 > h1)
     {
      g_sh_price[1] = g_sh_price[0];
      g_sh_hist[1]  = g_sh_hist[0];
      g_sh_price[0] = h4;
      g_sh_hist[0]  = H4Hist(4);
      if(g_sh_count < 2)
         g_sh_count++;
      // Bearish regular divergence latch on the two most recent swing-highs.
      if(g_sh_count >= 2 &&
         g_sh_price[0] > g_sh_price[1] &&
         g_sh_hist[0]  < g_sh_hist[1]  &&
         g_sh_hist[0]  > 0.0)
        {
         g_latch_dir         = -1;
         g_latch_stamp       = TimeCurrent();
         g_latch_swing_price = g_sh_price[0];
        }
     }

   // Confirmed swing LOW at shift 4: lower than the bar before + the 3 after.
   if(l4 < l5 && l4 < l3 && l4 < l2 && l4 < l1)
     {
      g_sl_price[1] = g_sl_price[0];
      g_sl_hist[1]  = g_sl_hist[0];
      g_sl_price[0] = l4;
      g_sl_hist[0]  = H4Hist(4);
      if(g_sl_count < 2)
         g_sl_count++;
      // Bullish regular divergence latch on the two most recent swing-lows.
      if(g_sl_count >= 2 &&
         g_sl_price[0] < g_sl_price[1] &&
         g_sl_hist[0]  > g_sl_hist[1]  &&
         g_sl_hist[0]  < 0.0)
        {
         g_latch_dir         = +1;
         g_latch_stamp       = TimeCurrent();
         g_latch_swing_price = g_sl_price[0];
        }
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// --- No Trade Filter (time / spread / news) ---
// Cheap O(1) per-tick guard: parameter sanity + genuinely-wide-spread block.
// .DWX quotes ask==bid (0 modeled spread) in the tester, so this only blocks a
// real wide spread and never fail-closes on zero spread.
bool Strategy_NoTradeFilter()
  {
   if(strategy_macd_fast < 1 || strategy_macd_slow <= strategy_macd_fast ||
      strategy_macd_signal < 1 || strategy_ema_period < 1 || strategy_atr_period < 1 ||
      strategy_atr_tp_mult <= 0.0 || strategy_sl_buffer_atr_mult < 0.0 ||
      strategy_sl_floor_atr_mult <= 0.0 || strategy_slope_atr_mult < 0.0 ||
      strategy_latch_max_h1_bars < 1 || strategy_max_hold_h1_bars < 1 ||
      strategy_skip_bars_open < 0 || strategy_skip_bars_close < 0 ||
      strategy_spread_cap_pips < 0)
      return true;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(ask > 0.0 && bid > 0.0 && ask > bid && cap > 0.0 && (ask - bid) > cap)
      return true;

   return false;
  }

// --- Trade Entry ---
// Advances H4 divergence state, then fires on the H1 zero-cross confirmation in
// the latched direction (session/expiry/regime gated). Caller guarantees a new
// H1 bar (framework QM_IsNewBar() gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Advance H4 structural/divergence state once per closed H4 bar. Distinct
   // new-bar key from the framework's bare H1 gate; latched until consumed.
   if(QM_IsNewBar(_Symbol, PERIOD_H4))
      AdvanceH4State();

   // One position per symbol per magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // No active divergence latch.
   if(g_latch_dir == 0)
      return false;

   // Latch expiry: valid for at most strategy_latch_max_h1_bars H1 bars.
   const long h1_secs = (long)PeriodSeconds(PERIOD_H1);
   if(h1_secs > 0 && g_latch_stamp > 0 &&
      (long)(TimeCurrent() - g_latch_stamp) > (long)strategy_latch_max_h1_bars * h1_secs)
     {
      g_latch_dir = 0;
      return false;
     }

   // Session-edge filter (broker time-of-day): no entry in the first/last N H1
   // bars of the broker trading day (NY-Close daily boundary at 00:00 broker).
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour < strategy_skip_bars_open || dt.hour >= (24 - strategy_skip_bars_close))
      return false;

   // H1 histogram zero-cross confirmation in the latch direction.
   const double hist1 = H1Hist(1);
   const double hist2 = H1Hist(2);
   bool triggered = false;
   if(g_latch_dir < 0)                                   // bearish -> short on down-cross
      triggered = (hist2 > 0.0 && hist1 <= 0.0);
   else                                                  // bullish -> long on up-cross
      triggered = (hist2 < 0.0 && hist1 >= 0.0);
   if(!triggered)
      return false;

   // Regime reject: refuse to fade a very strong intermediate H4 trend.
   const double ema1   = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_period, 1);
   const double ema5   = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_period, 5);
   const double atr_h4 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr_h4 <= 0.0 || ema1 <= 0.0 || ema5 <= 0.0)
      return false;
   const double slope = ema1 - ema5;
   if(g_latch_dir < 0 && slope >  strategy_slope_atr_mult * atr_h4)
      return false;
   if(g_latch_dir > 0 && slope < -strategy_slope_atr_mult * atr_h4)
      return false;

   // Build the market order.
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   const QM_OrderType side  = (g_latch_dir < 0) ? QM_SELL : QM_BUY;
   const double       entry = (side == QM_SELL) ? bid : ask;

   const double buffer     = strategy_sl_buffer_atr_mult * atr_h4;
   const double floor_dist = strategy_sl_floor_atr_mult  * atr_h4;
   double sl = 0.0;
   if(side == QM_SELL)
     {
      sl = g_latch_swing_price + buffer;
      if(sl - entry < floor_dist)
         sl = entry + floor_dist;
     }
   else
     {
      sl = g_latch_swing_price - buffer;
      if(entry - sl < floor_dist)
         sl = entry - floor_dist;
     }
   sl = QM_TM_NormalizePrice(_Symbol, sl);

   const double tp = QM_TakeATRFromValue(_Symbol, side, entry, atr_h4, strategy_atr_tp_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type               = side;
   req.price              = 0.0;
   req.sl                 = sl;
   req.tp                 = tp;
   req.reason             = (side == QM_SELL) ? "MTF_MACD_DIV_SHORT" : "MTF_MACD_DIV_LONG";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Latch consumed on entry.
   g_latch_dir = 0;
   return true;
  }

// --- Trade Management ---
// Baseline carries no trailing / break-even; SL/TP and the rule exits below own
// the position. (P3-optional break-even move is not part of the baseline.)
void Strategy_ManageOpenPosition()
  {
  }

// --- Trade Close ---
// Primary: H1 histogram opposite zero-cross. Tertiary: 48 H1-bar time stop.
// (Secondary TP is the hard order TP set at entry.)
bool Strategy_ExitSignal()
  {
   const int      magic          = QM_FrameworkMagic();
   const long     period_seconds = (long)PeriodSeconds(PERIOD_H1);
   const datetime now            = TimeCurrent();

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime           opened   = (datetime)PositionGetInteger(POSITION_TIME);

      // Tertiary: time stop.
      if(period_seconds > 0 && opened > 0 &&
         (long)(now - opened) >= (long)strategy_max_hold_h1_bars * period_seconds)
         return true;

      // Primary: H1 histogram opposite zero-cross (read only when a position is open).
      const double hist1 = H1Hist(1);
      const double hist2 = H1Hist(2);
      if(pos_type == POSITION_TYPE_BUY  && hist2 > 0.0 && hist1 <= 0.0)
         return true;    // long closed on down-cross
      if(pos_type == POSITION_TYPE_SELL && hist2 < 0.0 && hist1 >= 0.0)
         return true;    // short closed on up-cross
     }

   return false;
  }

// --- News Filter Hook ---
// Defer to the central QM_NewsAllowsTrade* gate (P8 News Impact phase).
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
   // only (2026-07-02 audit rule).
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

   // Per-closed-bar: entry-signal evaluation.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled.
   QM_EquityStreamOnNewBar();

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
