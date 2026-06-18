#property strict
#property version   "5.0"
#property description "QM5_1374 carter-ttm-wave-h1 — Carter TTM-Wave three-MACD confluence (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1374 carter-ttm-wave-h1
// -----------------------------------------------------------------------------
// Source: John F. Carter, "Mastering the Trade" (McGraw-Hill, 2005 / 2nd ed.
//   2012, ISBN 978-0071775144) — TTM Wave. FF Trading-Systems Carter cluster
//   (source_id 6e967762-b26d-59a3-b076-35c17f2e7c36).
// Card: artifacts/cards_approved/QM5_1374_carter-ttm-wave-h1.md (g0 APPROVED).
//
// THIS build is the LITERAL three-distinct-MACD realization of the card:
//
//   Wave-A MACD = EMA(close,8) - EMA(close,34),  histA = MACD - EMA(MACD,5)
//   Wave-B MACD = EMA(close,8) - EMA(close,89),  histB = MACD - EMA(MACD,5)
//   Wave-C MACD = EMA(close,8) - EMA(close,144), histC = MACD - EMA(MACD,5)
//
//   In the V5 framework, MT5's MACD signal line IS EMA(MACD, signal_period), so
//   each wave histogram is read directly as
//       hist = QM_MACD_Main(_Symbol,_Period,8,slow,5,shift)
//            - QM_MACD_Signal(_Symbol,_Period,8,slow,5,shift)
//   sharing fast=8, signal=5, with slow = 34 / 89 / 144. No raw iMACD.
//
//   Closed-bar convention: card "[0]" = last closed bar = shift 1; card "[-1]" =
//   shift 2; card "[-2]" = shift 3.
//
//   Wave-bar color (canonical Carter): GREEN (rising) = hist[s] > hist[s+1];
//   RED (falling) = hist[s] < hist[s+1].
//
//   Entry — BUY (three-wave bullish confluence), all on the last closed bar:
//     1. histA[1]>0 AND rising (histA[1]>histA[2])
//     2. histB[1]>0 AND rising
//     3. histC[1]>0 AND rising
//     4. FIRST-bar-of-confluence trigger (the single EVENT): on the PRIOR bar at
//        least one of A/B/C was either <=0 OR not-rising — i.e. confluence did
//        NOT already hold at shift 2. This makes the all-positive-and-rising
//        STATE fire only on its first bar, preventing re-fires deep in the move.
//     5. Bias: close[1] > EMA(close,200) (macro uptrend).
//     6. Spread guard (fail-open on .DWX zero modeled spread).
//     7. No prior open position on this magic.
//   SELL mirrors: all three hist<0 AND falling; first bar of that confluence;
//   close[1] < EMA(200).
//
//   Stop loss : BUY entry - 1.8*ATR(14); SELL entry + 1.8*ATR(14).
//   Take profit: BUY entry + 2.5*ATR(14); SELL entry - 2.5*ATR(14)
//                (expressed via QM_TakeRR off the SL so framework price
//                 normalization applies; RR chosen so |TP-entry| = 2.5*ATR).
//   Exits (closed-bar, in Strategy_ExitSignal):
//     - Wave-A color-flip (fastest): BUY closes when histA losing momentum for
//       two bars: histA[1]<histA[2] AND histA[2]<histA[3]. SELL mirrored.
//     - Wave-C reversal (slowest): BUY closes if histC[1]<0 (slow wave flipped
//       sign — structure broken). SELL mirrored.
//     - Time-stop: close after strategy_time_stop_bars (60) H1 bars held.
//
//   One position per magic. RISK_FIXED in tester, RISK_PERCENT live. No ML, no
//   external feed, no adaptive/PnL-based params. All wave math is fixed
//   closed-form MACD-difference arithmetic over bounded closed-bar shifts —
//   transparent non-ML computation (HR14 compliant).
//
//   NOTE (dedup): sibling QM5_1311 shares this slug but realizes the waves as a
//   single shared (12/26) MACD line with SMA-of-SMA signal smoothing + macro-EMA
//   cross exits + session gate. THIS card's three distinct Fib-period MACDs
//   (8/34, 8/89, 8/144), per-wave histogram color, 60-bar time-stop, and
//   1.8/2.5 ATR stop/target are mechanically DIFFERENT. Built faithful to 1374.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1374;
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
input int    strategy_wave_fast_period   = 8;      // shared MACD fast EMA (Carter)
input int    strategy_wave_a_slow        = 34;     // Wave-A slow EMA
input int    strategy_wave_b_slow        = 89;     // Wave-B slow EMA
input int    strategy_wave_c_slow        = 144;    // Wave-C slow EMA
input int    strategy_signal_period      = 5;      // histogram signal smoothing EMA(MACD,5)
input int    strategy_macro_ema_period   = 200;    // macro-bias EMA gate
input int    strategy_atr_period         = 14;     // ATR period for stop/target
input double strategy_sl_atr_mult        = 1.8;    // stop  = mult * ATR from entry
input double strategy_tp_atr_mult        = 2.5;    // take  = mult * ATR from entry
input int    strategy_time_stop_bars     = 60;     // close after N H1 bars held
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy helpers
// -----------------------------------------------------------------------------

// Minimum closed bars required before any wave is meaningful: slowest slow EMA
// period + the signal smoothing + the deepest shift used (3) + a safety margin.
// QM_IndicatorReadBuffer returns 0.0 (not EMPTY_VALUE) on a not-yet-warmed
// handle, and a MACD histogram value of exactly 0.0 is legitimate, so we cannot
// distinguish warmup from a real zero on the value alone — gate on bar count.
int WaveWarmupBars()
  {
   int slow_max = strategy_wave_a_slow;
   if(strategy_wave_b_slow > slow_max) slow_max = strategy_wave_b_slow;
   if(strategy_wave_c_slow > slow_max) slow_max = strategy_wave_c_slow;
   return slow_max + strategy_signal_period + 5;
  }

bool WavesWarm()
  {
   return (Bars(_Symbol, _Period) > WaveWarmupBars());
  }

// Wave histogram at a closed-bar shift for a given wave slow period.
// hist = MACD(8,slow,5) main - signal = (EMA8-EMAslow) - EMA(MACD,5).
// Caller must first confirm WavesWarm(); this returns the raw difference.
double WaveHist(const int slow, const int shift, bool &ok)
  {
   ok = false;
   const double m = QM_MACD_Main(_Symbol, _Period, strategy_wave_fast_period, slow,
                                 strategy_signal_period, shift);
   const double s = QM_MACD_Signal(_Symbol, _Period, strategy_wave_fast_period, slow,
                                   strategy_signal_period, shift);
   ok = true;
   return m - s;
  }

// Bullish wave at `shift`: histogram positive AND rising (green) vs `shift+1`.
bool WaveBull(const int slow, const int shift, bool &ok)
  {
   ok = false;
   bool ok0=false, ok1=false;
   const double h0 = WaveHist(slow, shift,     ok0);
   const double h1 = WaveHist(slow, shift + 1, ok1);
   if(!ok0 || !ok1)
      return false;
   ok = true;
   return (h0 > 0.0 && h0 > h1);
  }

// Bearish wave at `shift`: histogram negative AND falling (red) vs `shift+1`.
bool WaveBear(const int slow, const int shift, bool &ok)
  {
   ok = false;
   bool ok0=false, ok1=false;
   const double h0 = WaveHist(slow, shift,     ok0);
   const double h1 = WaveHist(slow, shift + 1, ok1);
   if(!ok0 || !ok1)
      return false;
   ok = true;
   return (h0 < 0.0 && h0 < h1);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: spread guard only (no session restriction per card).
// Fail-open on .DWX zero modeled spread (ask == bid).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// TTM-Wave three-MACD confluence entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!WavesWarm())
      return false; // not enough history for the slowest wave -> no trade

   // --- Confluence STATE at the last closed bar (shift 1) for all three waves.
   bool a1ok=false,b1ok=false,c1ok=false;
   const bool a1_bull = WaveBull(strategy_wave_a_slow, 1, a1ok);
   const bool b1_bull = WaveBull(strategy_wave_b_slow, 1, b1ok);
   const bool c1_bull = WaveBull(strategy_wave_c_slow, 1, c1ok);
   bool a1bok=false,b1bok=false,c1bok=false;
   const bool a1_bear = WaveBear(strategy_wave_a_slow, 1, a1bok);
   const bool b1_bear = WaveBear(strategy_wave_b_slow, 1, b1bok);
   const bool c1_bear = WaveBear(strategy_wave_c_slow, 1, c1bok);
   if(!(a1ok && b1ok && c1ok && a1bok && b1bok && c1bok))
      return false; // warmup / unavailable -> no trade

   // --- Confluence STATE on the prior bar (shift 2) — used for the
   //     first-bar-of-confluence trigger EVENT. ---
   bool a2ok=false,b2ok=false,c2ok=false;
   const bool a2_bull = WaveBull(strategy_wave_a_slow, 2, a2ok);
   const bool b2_bull = WaveBull(strategy_wave_b_slow, 2, b2ok);
   const bool c2_bull = WaveBull(strategy_wave_c_slow, 2, c2ok);
   bool a2bok=false,b2bok=false,c2bok=false;
   const bool a2_bear = WaveBear(strategy_wave_a_slow, 2, a2bok);
   const bool b2_bear = WaveBear(strategy_wave_b_slow, 2, b2bok);
   const bool c2_bear = WaveBear(strategy_wave_c_slow, 2, c2bok);
   if(!(a2ok && b2ok && c2ok && a2bok && b2bok && c2bok))
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double macro  = QM_EMA(_Symbol, _Period, strategy_macro_ema_period, 1);
   if(close1 <= 0.0 || macro <= 0.0)
      return false;

   // Bullish confluence holds now; first-bar trigger = it did NOT all hold last bar.
   const bool buy_now_all  = (a1_bull && b1_bull && c1_bull);
   const bool buy_prev_all = (a2_bull && b2_bull && c2_bull);
   const bool buy_trigger  = (buy_now_all && !buy_prev_all);   // single EVENT
   const bool buy_macro    = (close1 > macro);

   const bool sell_now_all  = (a1_bear && b1_bear && c1_bear);
   const bool sell_prev_all = (a2_bear && b2_bear && c2_bear);
   const bool sell_trigger  = (sell_now_all && !sell_prev_all);
   const bool sell_macro    = (close1 < macro);

   QM_OrderType dir;
   double entry;
   if(buy_trigger && buy_macro)
     {
      dir   = QM_BUY;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
     }
   else if(sell_trigger && sell_macro)
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

   // --- Stop: entry -/+ sl_atr_mult * ATR (card-literal ATR stop). ---
   double sl;
   if(dir == QM_BUY)
      sl = entry - strategy_sl_atr_mult * atr_value;
   else
      sl = entry + strategy_sl_atr_mult * atr_value;
   sl = QM_TM_NormalizePrice(_Symbol, sl);
   if(sl <= 0.0)
      return false;

   // --- Take profit: tp_atr_mult * ATR from entry, via RR off the stop so the
   //     framework price normalization applies. RR = tp_dist / sl_dist. ---
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
   req.reason = "ttm_wave3_confluence";
   return true;
  }

// Primary protective exits are the broker-side ATR stop and ATR target; no
// active trailing/BE management per the card.
void Strategy_ManageOpenPosition()
  {
  }

// Closed-bar discretionary exits: Wave-A 2-bar color-flip OR Wave-C sign
// reversal against the position OR time-stop after N bars held.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Locate this magic's open position: read direction + open time.
   bool have_pos = false;
   long pos_type = -1;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      pos_type  = PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      have_pos  = true;
      break;
     }
   if(!have_pos)
      return false;

   // --- Time-stop: N H1 bars elapsed since entry. ---
   if(strategy_time_stop_bars > 0 && open_time > 0)
     {
      const int bars_held = iBarShift(_Symbol, _Period, open_time, false); // perf-allowed: single lookup
      if(bars_held >= strategy_time_stop_bars)
         return true;
     }

   // --- Wave-A color-flip (fastest): two consecutive bars of momentum loss. ---
   bool hA1ok=false,hA2ok=false,hA3ok=false;
   const double hA1 = WaveHist(strategy_wave_a_slow, 1, hA1ok);
   const double hA2 = WaveHist(strategy_wave_a_slow, 2, hA2ok);
   const double hA3 = WaveHist(strategy_wave_a_slow, 3, hA3ok);
   if(hA1ok && hA2ok && hA3ok)
     {
      // BUY closes when Wave-A falling two bars: histA[1]<histA[2] AND histA[2]<histA[3].
      if(pos_type == POSITION_TYPE_BUY  && hA1 < hA2 && hA2 < hA3)
         return true;
      // SELL closes when Wave-A rising two bars (mirror).
      if(pos_type == POSITION_TYPE_SELL && hA1 > hA2 && hA2 > hA3)
         return true;
     }

   // --- Wave-C reversal (slowest): slow wave flipped sign -> structure broken. ---
   bool hC1ok=false;
   const double hC1 = WaveHist(strategy_wave_c_slow, 1, hC1ok);
   if(hC1ok)
     {
      if(pos_type == POSITION_TYPE_BUY  && hC1 < 0.0)
         return true;
      if(pos_type == POSITION_TYPE_SELL && hC1 > 0.0)
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
