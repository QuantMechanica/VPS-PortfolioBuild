#property strict
#property version   "5.0"
#property description "QM5_11000 the5ers-macd-third-div — Third MACD Divergence Reversal (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11000 the5ers-macd-third-div
// -----------------------------------------------------------------------------
// Source: The5ers blog "Forex Trading Strategy The Powerful Third MACD Divergence"
//         https://the5ers.com/macd-divergence-trading-strategy/  (MACD 3/9/7, D1/W1).
// Card: artifacts/cards_approved/QM5_11000_the5ers-macd-third-div.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift >= 1; MACD main line CAN be negative):
//   Swing points : confirmed swing high/low with left=right=swing_wing bars
//                  (a bar with `right` confirmed bars to its right; newest usable
//                   pivot sits at shift `swing_wing+1`).
//   Bearish entry: last 3 confirmed swing HIGHS have RISING price
//                  (h3>h2>h1, oldest->newest) and FALLING MACD (m3<m2<m1) — i.e.
//                  the classic "higher highs, lower MACD" third bearish divergence.
//                  Confirmation: latest close below the low of the bar AFTER the
//                  newest swing high, OR MACD main below MACD signal. -> SELL.
//   Bullish entry: last 3 confirmed swing LOWS have FALLING price (l3<l2<l1) and
//                  RISING MACD (m3>m2>m1). Confirmation: latest close above the
//                  high of the bar AFTER the newest swing low, OR MACD main above
//                  MACD signal. -> BUY.
//   Span filter  : oldest->newest of the 3 pivots must span [span_min, span_max] D1 bars.
//   Vol filter   : skip if ATR(D1,14) is in the bottom atr_pctile_floor percentile
//                  of the last atr_pctile_window closed D1 bars.
//   Stop         : SELL -> newest swing high + sl_atr_mult*ATR;
//                  BUY  -> newest swing low  - sl_atr_mult*ATR.
//   Take profit  : tp_rr R-multiple of the initial stop distance.
//   Exits        : momentum (MACD main/signal cross against the trade) OR
//                  time stop after time_stop_bars closed D1 bars.
//   Spread guard : fail-open on .DWX zero modeled spread; block only a genuinely
//                  wide spread > spread_pct_of_stop of the stop distance.
//
// .DWX notes: spread guard fails OPEN (no block on 0 spread); no swap gate; the
// "close below the low of the bar after the swing high" confirmation uses the
// prior CLOSE / a real prior bar low (no synthetic gap). MACD main is NOT guarded
// against <= 0. No external macro feed.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11000;
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
input int    strategy_macd_fast         = 3;      // MACD fast EMA (source 3/9/7)
input int    strategy_macd_slow         = 9;      // MACD slow EMA
input int    strategy_macd_signal       = 7;      // MACD signal period
input int    strategy_swing_wing        = 3;      // left=right bars for a confirmed pivot
input int    strategy_scan_bars         = 140;    // closed bars scanned for pivots (>= span_max + wings)
input int    strategy_span_min          = 15;     // min D1 bars spanned by the 3 pivots
input int    strategy_span_max          = 120;    // max D1 bars spanned by the 3 pivots
input int    strategy_atr_period        = 14;     // ATR period (vol filter + stop)
input double strategy_atr_pctile_floor  = 15.0;   // skip if ATR below this percentile
input int    strategy_atr_pctile_window = 250;    // ATR percentile lookback (D1 bars)
input double strategy_sl_atr_mult       = 0.5;    // stop buffer beyond pivot = mult*ATR
input double strategy_tp_rr             = 2.0;    // take-profit R-multiple
input int    strategy_time_stop_bars    = 20;     // close after this many D1 bars
input double strategy_spread_pct_of_stop = 25.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers (structural pivot detection — perf-allowed raw bar reads, gated by the
// closed-bar entry path; bounded scan of strategy_scan_bars).
// -----------------------------------------------------------------------------

// Confirmed swing high at shift `s` if high[s] strictly exceeds the highs of the
// `wing` bars on each side. Uses only closed bars (s >= wing+1 enforced by caller).
bool IsSwingHigh(const int s, const int wing)
  {
   const double h = iHigh(_Symbol, _Period, s); // perf-allowed: structural pivot
   if(h <= 0.0)
      return false;
   for(int k = 1; k <= wing; ++k)
     {
      if(iHigh(_Symbol, _Period, s + k) >= h) return false;
      if(iHigh(_Symbol, _Period, s - k) >= h) return false;
     }
   return true;
  }

bool IsSwingLow(const int s, const int wing)
  {
   const double l = iLow(_Symbol, _Period, s); // perf-allowed: structural pivot
   if(l <= 0.0)
      return false;
   for(int k = 1; k <= wing; ++k)
     {
      if(iLow(_Symbol, _Period, s + k) <= l) return false;
      if(iLow(_Symbol, _Period, s - k) <= l) return false;
     }
   return true;
  }

// ATR percentile floor: skip when current ATR is in the bottom `floor_pct` of the
// last `window` closed-bar ATR readings. Returns TRUE if the floor is satisfied
// (i.e. trading is allowed by volatility).
bool VolFloorOK(const double atr_now)
  {
   if(atr_now <= 0.0)
      return false;
   if(strategy_atr_pctile_floor <= 0.0)
      return true;
   const int window = (strategy_atr_pctile_window < 20 ? 20 : strategy_atr_pctile_window);
   int below = 0;
   int counted = 0;
   for(int s = 1; s <= window; ++s)
     {
      const double a = QM_ATR(_Symbol, _Period, strategy_atr_period, s);
      if(a <= 0.0)
         continue;
      counted++;
      if(a < atr_now)
         below++;
     }
   if(counted <= 0)
      return false;
   const double pctile = 100.0 * (double)below / (double)counted;
   return (pctile >= strategy_atr_pctile_floor);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // defer to entry gate, do not block

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Third-MACD-divergence entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int wing = (strategy_swing_wing < 1 ? 1 : strategy_swing_wing);
   // Newest usable confirmed pivot sits at shift wing+1 (needs `wing` closed bars
   // to its right). Scan toward older bars up to strategy_scan_bars.
   const int first_shift = wing + 1;
   const int last_shift  = strategy_scan_bars;
   if(last_shift <= first_shift + 2)
      return false;

   // Collect the 3 most-recent confirmed swing highs and lows (newest first).
   int    hi_shift[3]; double hi_price[3]; double hi_macd[3];
   int    lo_shift[3]; double lo_price[3]; double lo_macd[3];
   int    n_hi = 0, n_lo = 0;

   for(int s = first_shift; s <= last_shift && (n_hi < 3 || n_lo < 3); ++s)
     {
      if(n_hi < 3 && IsSwingHigh(s, wing))
        {
         hi_shift[n_hi] = s;
         hi_price[n_hi] = iHigh(_Symbol, _Period, s);          // perf-allowed: structural
         hi_macd[n_hi]  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                       strategy_macd_slow, strategy_macd_signal, s);
         n_hi++;
        }
      if(n_lo < 3 && IsSwingLow(s, wing))
        {
         lo_shift[n_lo] = s;
         lo_price[n_lo] = iLow(_Symbol, _Period, s);           // perf-allowed: structural
         lo_macd[n_lo]  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                       strategy_macd_slow, strategy_macd_signal, s);
         n_lo++;
        }
     }

   // Volatility floor (shared by both directions).
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(!VolFloorOK(atr_value))
      return false;

   const double macd_main_now   = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                               strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_signal_now = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                                 strategy_macd_slow, strategy_macd_signal, 1);
   const double close1 = iClose(_Symbol, _Period, 1);          // perf-allowed: latest closed bar

   // --- Bearish third divergence (last 3 swing highs) ---
   // Index 0 = newest pivot, 2 = oldest. Oldest->newest: price rising, MACD falling.
   if(n_hi >= 3)
     {
      const bool price_rising = (hi_price[2] > 0.0 && hi_price[1] > 0.0 && hi_price[0] > 0.0 &&
                                 hi_price[2] < hi_price[1] && hi_price[1] < hi_price[0]);
      const bool macd_falling = (hi_macd[2] > hi_macd[1] && hi_macd[1] > hi_macd[0]);
      // span = oldest pivot shift - newest pivot shift (in D1 bars)
      const int  span = hi_shift[2] - hi_shift[0];
      const bool span_ok = (span >= strategy_span_min && span <= strategy_span_max);

      if(price_rising && macd_falling && span_ok)
        {
         // Confirmation: close below the low of the bar AFTER the newest swing high
         // (one bar more recent, smaller shift), OR MACD main below signal.
         const int  post_shift = hi_shift[0] - 1;              // bar after the pivot
         double post_low = 0.0;
         if(post_shift >= 1)
            post_low = iLow(_Symbol, _Period, post_shift);     // perf-allowed: prior real bar
         const bool conf_close = (post_low > 0.0 && close1 > 0.0 && close1 < post_low);
         const bool conf_macd  = (macd_main_now < macd_signal_now);

         if(conf_close || conf_macd)
           {
            const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID); // SELL fills at bid
            if(entry <= 0.0)
               return false;
            // Stop above the newest swing high + 0.5*ATR.
            const double sl = QM_StopRulesNormalizePrice(_Symbol, hi_price[0] + strategy_sl_atr_mult * atr_value);
            if(sl <= entry)
               return false;
            const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
            if(tp <= 0.0)
               return false;

            req.type   = QM_SELL;
            req.price  = 0.0;
            req.sl     = sl;
            req.tp     = tp;
            req.reason = "macd_third_div_short";
            return true;
           }
        }
     }

   // --- Bullish third divergence (last 3 swing lows) ---
   // Oldest->newest: price falling, MACD rising.
   if(n_lo >= 3)
     {
      const bool price_falling = (lo_price[2] > 0.0 && lo_price[1] > 0.0 && lo_price[0] > 0.0 &&
                                  lo_price[2] > lo_price[1] && lo_price[1] > lo_price[0]);
      const bool macd_rising = (lo_macd[2] < lo_macd[1] && lo_macd[1] < lo_macd[0]);
      const int  span = lo_shift[2] - lo_shift[0];
      const bool span_ok = (span >= strategy_span_min && span <= strategy_span_max);

      if(price_falling && macd_rising && span_ok)
        {
         const int  post_shift = lo_shift[0] - 1;
         double post_high = 0.0;
         if(post_shift >= 1)
            post_high = iHigh(_Symbol, _Period, post_shift);   // perf-allowed: prior real bar
         const bool conf_close = (post_high > 0.0 && close1 > 0.0 && close1 > post_high);
         const bool conf_macd  = (macd_main_now > macd_signal_now);

         if(conf_close || conf_macd)
           {
            const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK); // BUY fills at ask
            if(entry <= 0.0)
               return false;
            const double sl = QM_StopRulesNormalizePrice(_Symbol, lo_price[0] - strategy_sl_atr_mult * atr_value);
            if(sl <= 0.0 || sl >= entry)
               return false;
            const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
            if(tp <= 0.0)
               return false;

            req.type   = QM_BUY;
            req.price  = 0.0;
            req.sl     = sl;
            req.tp     = tp;
            req.reason = "macd_third_div_long";
            return true;
           }
        }
     }

   return false;
  }

// No active management beyond the fixed stop/target; exits are in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Momentum exit (MACD main/signal cross against the trade) OR D1 time stop.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double macd_main_now   = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                               strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_signal_now = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                                 strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_main_prev   = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                                strategy_macd_slow, strategy_macd_signal, 2);
   const double macd_signal_prev = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                                  strategy_macd_slow, strategy_macd_signal, 2);

   const bool cross_up   = (macd_main_prev <= macd_signal_prev && macd_main_now > macd_signal_now);
   const bool cross_down = (macd_main_prev >= macd_signal_prev && macd_main_now < macd_signal_now);

   // Inspect this EA's open position(s) for direction + age.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long ptype = PositionGetInteger(POSITION_TYPE);

      // Momentum exit: close short on bullish MACD cross; close long on bearish cross.
      if(ptype == POSITION_TYPE_SELL && cross_up)
         return true;
      if(ptype == POSITION_TYPE_BUY && cross_down)
         return true;

      // Time stop: close after strategy_time_stop_bars closed D1 bars.
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int open_shift = iBarShift(_Symbol, _Period, open_time, false); // perf-allowed
      if(open_shift >= strategy_time_stop_bars)
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
