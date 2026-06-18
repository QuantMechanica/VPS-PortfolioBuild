#property strict
#property version   "5.0"
#property description "QM5_1311 carter-ttm-wave-h1 — Carter TTM-Wave triple-MACD confluence (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1311 carter-ttm-wave-h1
// -----------------------------------------------------------------------------
// Source: John F. Carter, "Mastering the Trade" (McGraw-Hill, 2005,
//   ISBN 0-07-176314-5) — TTM Wave (histogram companion to TTM Squeeze,
//   QM5_1291). FF Trading-Systems Carter cluster (6e967762).
// Card: artifacts/cards_approved/QM5_1311_carter-ttm-wave-h1.md (g0 APPROVED).
//
// Realization (framework-native, closed-bar reads at shift 1 latest):
//
//   Wave line   : a single MACD-style line shared by all three waves,
//                   wave[s] = EMA(close, fast)[s] - EMA(close, slow)[s].
//                 (Carter A/B/C share the same (12,26) lookback; only the
//                  signal-line smoothing differs.)
//
//   Signals     : progressively heavier SMA smoothing OF the wave line:
//                   SignalA[s] = SMA_p(wave)[s]
//                   SignalB[s] = SMA_p(SMA_p(wave))[s]
//                   SignalC[s] = SMA_p(SMA_p(SMA_p(wave)))[s]
//                 (p = strategy_signal_period).
//
//   Direction   : dir(W)[s] = sign(wave[s] - Signal_W[s])  -> +1 / -1 / 0 per
//                 wave, per closed bar. The three direction STATES are the
//                 momentum-confluence filter.
//
//   Entry (BUY) on the closed bar (trigger shift 1, prior shift 2):
//     1. dirA[1]=+1 AND dirB[1]=+1 AND dirC[1]=+1   (all three bullish now)
//     2. dirA[2]=-1 AND dirA[1]=+1                  (Wave A just FLIPPED bull —
//                                                    the single trigger EVENT)
//     3. dirB[2]=+1 AND dirC[2]=+1                  (slower waves PRE-positioned)
//     4. close[1] > EMA(close, macro)              (macro-bias STATE)
//   SELL mirrors with all signs reversed.
//
//   Only Wave A's flip is the EVENT; every other wave condition is a STATE, so
//   there is no two-fresh-cross-same-bar zero-trade trap.
//
//   Stop        : recent-3-bar low (BUY) / high (SELL) -/+ sl_atr_buf * ATR.
//   Take profit : QM_TakeRR off entry/SL, RR derived so the TP price equals
//                 entry +/- tp_atr_mult * ATR (the card's "2 x ATR from entry").
//   Exits (closed-bar):
//     - Wave A direction-flip AGAINST the open position -> close.
//     - Macro EMA cross against the position (close[1] crosses the macro EMA).
//
//   Session     : trade only inside [session_start_h, session_end_h) broker time
//                 (06:00-21:00 — skip overnight low-liquidity bars). O(1) gate.
//   Spread guard: only a genuinely wide spread blocks (fail-open on .DWX zero
//                 modeled spread).
//   Re-arm      : one position per magic + the Wave-A-flip-against-position exit
//                 means the same-side setup cannot re-fire while a position is
//                 open; after exit, a fresh Wave-A flip is required to re-enter.
//
//   One position per magic. RISK_FIXED in tester, RISK_PERCENT live. No ML, no
//   external feed. All wave/signal math is fixed closed-form SMA-of-EMA-diff over
//   bounded closed-bar windows — transparent non-ML computation (HR14 compliant).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1311;
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
input int    strategy_wave_fast_period   = 12;     // wave fast EMA (P3 sweep 10-14)
input int    strategy_wave_slow_period   = 26;     // wave slow EMA (P3 sweep 22-30)
input int    strategy_signal_period      = 9;      // SMA signal smoothing (P3 sweep 7-12)
input int    strategy_macro_ema_period   = 200;    // macro-bias EMA gate (P3 sweep 150-250)
input int    strategy_atr_period         = 14;     // ATR period for stop/target
input double strategy_tp_atr_mult        = 2.0;    // take profit = mult * ATR from entry (P3 1.5-3.0)
input double strategy_sl_atr_buf         = 0.5;    // stop buffer = mult * ATR beyond 3-bar extreme (P3 0.3-1.0)
input int    strategy_struct_lookback    = 3;      // recent-bar extreme window for the stop
input int    strategy_session_start_h    = 6;      // broker-hour session open (inclusive)
input int    strategy_session_end_h      = 21;     // broker-hour session close (exclusive)
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy helpers
// -----------------------------------------------------------------------------

// Wave line at a given closed-bar shift: MACD-style EMA difference shared by all
// three Carter waves. Returns true into `ok` on a valid read.
double WaveAt(const int shift, bool &ok)
  {
   ok = false;
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_wave_fast_period, shift);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_wave_slow_period, shift);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return 0.0;       // warmup -> fail closed
   ok = true;
   return ema_fast - ema_slow;
  }

// Simple moving average of the wave line over `strategy_signal_period` closed
// bars ending at `shift`. SignalA = SMA(wave). Bounded loop (signal_period) on
// the closed-bar path only.
double WaveSMA1At(const int shift, bool &ok)
  {
   ok = false;
   const int p = strategy_signal_period;
   if(p < 1)
      return 0.0;
   double sum = 0.0;
   for(int k = 0; k < p; ++k)
     {
      bool w_ok = false;
      const double w = WaveAt(shift + k, w_ok);
      if(!w_ok)
         return 0.0;    // warmup -> fail closed
      sum += w;
     }
   ok = true;
   return sum / (double)p;
  }

// SMA of SMA1 -> SignalB. SMA of SignalB -> SignalC. `level` selects the depth
// (1 = SignalA, 2 = SignalB, 3 = SignalC). Each extra level averages the
// next-lower signal over `strategy_signal_period` consecutive shifts. Bounded
// nested window (<= 3*signal_period wave reads), closed-bar path only.
double WaveSignalAt(const int level, const int shift, bool &ok)
  {
   ok = false;
   const int p = strategy_signal_period;
   if(p < 1 || level < 1)
      return 0.0;

   if(level == 1)
      return WaveSMA1At(shift, ok);

   double sum = 0.0;
   for(int k = 0; k < p; ++k)
     {
      bool lower_ok = false;
      const double lower = WaveSignalAt(level - 1, shift + k, lower_ok);
      if(!lower_ok)
         return 0.0;    // warmup -> fail closed
      sum += lower;
     }
   ok = true;
   return sum / (double)p;
  }

// Direction state of a wave at a shift: sign(wave[s] - signal_level[s]).
// Returns +1 / -1 / 0; `ok` false on any warmup read.
int WaveDirAt(const int level, const int shift, bool &ok)
  {
   ok = false;
   bool w_ok = false;
   const double w = WaveAt(shift, w_ok);
   if(!w_ok)
      return 0;
   bool s_ok = false;
   const double sig = WaveSignalAt(level, shift, s_ok);
   if(!s_ok)
      return 0;
   ok = true;
   const double d = w - sig;
   if(d > 0.0) return  1;
   if(d < 0.0) return -1;
   return 0;
  }

// Broker-time session gate: true if `broker_now` is inside the [start, end) hour
// window. Wrap-safe. O(1).
bool InSession(const datetime broker_now)
  {
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   const int h = dt.hour;
   if(strategy_session_start_h == strategy_session_end_h)
      return true; // degenerate full-day
   if(strategy_session_start_h < strategy_session_end_h)
      return (h >= strategy_session_start_h && h < strategy_session_end_h);
   return (h >= strategy_session_start_h || h < strategy_session_end_h); // overnight wrap
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: session window + spread guard. Regime / signal work
// is on the closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero
// modeled spread (ask == bid).
bool Strategy_NoTradeFilter()
  {
   if(!InSession(TimeCurrent()))
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate

   const double stop_distance = strategy_tp_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// TTM-Wave triple-confluence entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Direction states at trigger shift 1 and prior shift 2 for all waves ---
   bool okA1=false, okB1=false, okC1=false, okA2=false, okB2=false, okC2=false;
   const int dirA1 = WaveDirAt(1, 1, okA1);
   const int dirB1 = WaveDirAt(2, 1, okB1);
   const int dirC1 = WaveDirAt(3, 1, okC1);
   const int dirA2 = WaveDirAt(1, 2, okA2);
   const int dirB2 = WaveDirAt(2, 2, okB2);
   const int dirC2 = WaveDirAt(3, 2, okC2);
   if(!(okA1 && okB1 && okC1 && okA2 && okB2 && okC2))
      return false; // warmup / unavailable -> no trade

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double macro  = QM_EMA(_Symbol, _Period, strategy_macro_ema_period, 1);
   if(close1 <= 0.0 || macro <= 0.0)
      return false;

   QM_OrderType dir;
   double entry;

   // --- BUY confluence ---
   const bool buy_now_all   = (dirA1 ==  1 && dirB1 ==  1 && dirC1 ==  1);
   const bool buy_trigger   = (dirA2 == -1 && dirA1 ==  1);            // Wave A flip up = EVENT
   const bool buy_prepos    = (dirB2 ==  1 && dirC2 ==  1);            // slow waves pre-positioned
   const bool buy_macro     = (close1 > macro);

   // --- SELL confluence (mirror) ---
   const bool sell_now_all  = (dirA1 == -1 && dirB1 == -1 && dirC1 == -1);
   const bool sell_trigger  = (dirA2 ==  1 && dirA1 == -1);
   const bool sell_prepos   = (dirB2 == -1 && dirC2 == -1);
   const bool sell_macro    = (close1 < macro);

   if(buy_now_all && buy_trigger && buy_prepos && buy_macro)
     {
      dir   = QM_BUY;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
     }
   else if(sell_now_all && sell_trigger && sell_prepos && sell_macro)
     {
      dir   = QM_SELL;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
     }
   else
      return false;

   if(entry <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- Stop: recent-N-bar extreme +/- buffer*ATR (structural stop) ---
   const int lb = (strategy_struct_lookback > 0 ? strategy_struct_lookback : 3);
   double hh = -DBL_MAX, ll = DBL_MAX;
   for(int s = 1; s <= lb; ++s)
     {
      const double hi = iHigh(_Symbol, _Period, s); // perf-allowed: bounded closed-bar structure window
      const double lo = iLow(_Symbol, _Period, s);  // perf-allowed
      if(hi <= 0.0 || lo <= 0.0)
         return false;
      if(hi > hh) hh = hi;
      if(lo < ll) ll = lo;
     }

   double sl;
   if(dir == QM_BUY)
      sl = ll - strategy_sl_atr_buf * atr_value;
   else
      sl = hh + strategy_sl_atr_buf * atr_value;
   sl = QM_TM_NormalizePrice(_Symbol, sl);
   if(sl <= 0.0)
      return false;

   // --- Take profit: tp_atr_mult * ATR from entry, expressed via RR off the
   //     structural stop so the framework's price normalization applies. ---
   const double sl_dist = MathAbs(entry - sl);
   if(sl_dist <= 0.0)
      return false;
   const double rr = (strategy_tp_atr_mult * atr_value) / sl_dist;
   if(rr <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, dir, entry, sl, rr);
   if(tp <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "ttm_wave_confluence";
   return true;
  }

// Primary exits are the broker-side structural stop and ATR target; no active
// management (trailing/BE) per the card.
void Strategy_ManageOpenPosition()
  {
  }

// Closed-bar exits: Wave A direction-flip against the position OR macro-EMA cross
// against the position. Caller closes the magic's positions when this returns true.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Find this magic's open position to read its direction.
   bool have_pos = false;
   long pos_type = -1;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      pos_type = PositionGetInteger(POSITION_TYPE);
      have_pos = true;
      break;
     }
   if(!have_pos)
      return false;

   // --- Wave A direction-flip against the position (+1 -> -1 for a BUY) ---
   bool okA1=false, okA2=false;
   const int dirA1 = WaveDirAt(1, 1, okA1);
   const int dirA2 = WaveDirAt(1, 2, okA2);
   if(okA1 && okA2)
     {
      if(pos_type == POSITION_TYPE_BUY  && dirA2 ==  1 && dirA1 == -1)
         return true;
      if(pos_type == POSITION_TYPE_SELL && dirA2 == -1 && dirA1 ==  1)
         return true;
     }

   // --- Macro EMA cross against the position (closing-bar cross) ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed
   const double macro1 = QM_EMA(_Symbol, _Period, strategy_macro_ema_period, 1);
   const double macro2 = QM_EMA(_Symbol, _Period, strategy_macro_ema_period, 2);
   if(close1 > 0.0 && close2 > 0.0 && macro1 > 0.0 && macro2 > 0.0)
     {
      // BUY closes if close crossed below the macro EMA this bar.
      if(pos_type == POSITION_TYPE_BUY  && close2 >= macro2 && close1 < macro1)
         return true;
      // SELL closes if close crossed above the macro EMA this bar.
      if(pos_type == POSITION_TYPE_SELL && close2 <= macro2 && close1 > macro1)
         return true;
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
