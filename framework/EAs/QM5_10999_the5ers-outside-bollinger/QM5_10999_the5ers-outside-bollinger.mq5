#property strict
#property version   "5.0"
#property description "QM5_10999 the5ers-outside-bollinger — Outside-Bollinger body reversal (H1 FX)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10999 the5ers-outside-bollinger
// -----------------------------------------------------------------------------
// Source: The5ers "Forex Trading Strategy Outside Bollinger Bands"
//   (the5ers.com/outside-bolinger-bands, updated 2020-02-28).
// Card: artifacts/cards_approved/QM5_10999_the5ers-outside-bollinger.md
//   (g0_status APPROVED).
//
// Mechanics (mean-reversion, closed-bar reads at shift 1; enter next H1 open):
//   BB           : Bollinger(period=20, dev=2.0, close).
//   Body         : body_low = min(open[1],close[1]); body_high = max(open[1],close[1]).
//   Long entry   : body_high < lower_band[1]  (whole BODY outside below lower band)
//                  AND reversal confirm (close[1]>open[1] OR close[1]>close[2])
//                  AND no open position under this magic.
//   Short entry  : body_low  > upper_band[1]
//                  AND reversal confirm (close[1]<open[1] OR close[1]<close[2])
//                  AND no open position under this magic.
//   Stop (long)  : low[1]  - sl_atr_mult * ATR(14).
//   Stop (short) : high[1] + sl_atr_mult * ATR(14).
//   Take profit  : hard TP at tp_rr * R (secondary 1.5R target) — whichever of
//                  the hard TP / middle-band exit / time stop fires first.
//   Primary exit : Bollinger middle band (SMA20) touch/cross -> close manually.
//   Time stop    : close after time_stop_bars closed H1 bars.
//   Filters      : skip if BB bandwidth (upper-lower)/middle is in the bottom
//                  bandwidth_pctile of the last bandwidth_lookback closed bars;
//                  skip if the outside-body candle range > range_atr_cap * ATR(14).
//   Spread guard : no card-specific spread cap; only unusable/crossed quotes block.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10999;
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
input int    strategy_bb_period          = 20;     // Bollinger period
input double strategy_bb_deviation       = 2.0;    // Bollinger deviations
input int    strategy_atr_period         = 14;     // ATR period (stop / range filter)
input double strategy_sl_atr_mult        = 0.5;    // stop = beyond bar extreme by mult*ATR
input double strategy_tp_rr              = 1.5;    // secondary hard TP in R-multiples
input bool   strategy_use_color_confirm  = true;   // require candle-color OR close>prior-close reversal confirm
input int    strategy_time_stop_bars     = 18;     // close after N closed H1 bars
input int    strategy_bandwidth_lookback = 240;    // bars for bandwidth percentile
input double strategy_bandwidth_pctile   = 10.0;   // skip if bandwidth below this percentile
input double strategy_range_atr_cap      = 3.0;    // skip if outside-body range > cap*ATR

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. No card-specific time/spread filter; framework news
// runs before this hook. Zero modeled .DWX spread is tradeable.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;
   if(ask > 0.0 && bid > 0.0 && ask < bid)
      return true;

   return false;
  }

// Bandwidth percentile gate: TRUE if the current bandwidth is in the bottom
// `pctile` percent of the last `lookback` closed bars (narrow-band squeeze).
bool BandwidthInBottomPercentile()
  {
   const int lookback = MathMax(20, strategy_bandwidth_lookback);
   double bw[];
   ArrayResize(bw, lookback);
   int n = 0;
   double bw_now = -1.0;
   for(int s = 1; s <= lookback; ++s)
     {
      const double up  = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, s);
      const double mid = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, s);
      const double lo  = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, s);
      if(up <= 0.0 || mid <= 0.0 || lo <= 0.0)
         continue;
      const double v = (up - lo) / mid;
      bw[n] = v;
      ++n;
      if(s == 1)
         bw_now = v;
     }
   if(n < 20 || bw_now < 0.0)
      return false; // not enough data — do not block on it

   // Count how many of the sampled bandwidths are strictly below the current one.
   int below = 0;
   for(int i = 0; i < n; ++i)
      if(bw[i] < bw_now)
         ++below;

   const double pct_rank = (100.0 * below) / n; // 0 = narrowest, 100 = widest
   return (pct_rank < strategy_bandwidth_pctile);
  }

// Mean-reversion entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Bollinger bands on the last closed bar (shift 1) ---
   const double bb_up  = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_lo  = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_mid = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   if(bb_up <= 0.0 || bb_lo <= 0.0 || bb_mid <= 0.0)
      return false;

   // --- Candle body of the last closed bar (single closed-bar reads) ---
   const double open1  = iOpen(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   const double close1 = iClose(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double high1  = iHigh(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   const double low1   = iLow(_Symbol, _Period, 1);    // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2);  // perf-allowed: single closed-bar read
   if(open1 <= 0.0 || close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close2 <= 0.0)
      return false;

   const double body_low  = MathMin(open1, close1);
   const double body_high = MathMax(open1, close1);

   // --- ATR for the stop and the range-shock filter ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- Filter: skip narrow-band squeezes (fake-signal prone) ---
   if(BandwidthInBottomPercentile())
      return false;

   // --- Filter: skip news-shock-sized outside candles ---
   const double candle_range = high1 - low1;
   if(candle_range > strategy_range_atr_cap * atr_value)
      return false;

   // --- Long reversal: whole body closed below the lower band ---
   const bool long_outside = (body_high < bb_lo);
   const bool long_confirm = (!strategy_use_color_confirm) ||
                             (close1 > open1) || (close1 > close2);
   if(long_outside && long_confirm)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, low1 - strategy_sl_atr_mult * atr_value);
      if(sl <= 0.0 || sl >= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "outside_bb_long";
      return true;
     }

   // --- Short reversal: whole body closed above the upper band ---
   const bool short_outside = (body_low > bb_up);
   const bool short_confirm = (!strategy_use_color_confirm) ||
                              (close1 < open1) || (close1 < close2);
   if(short_outside && short_confirm)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, high1 + strategy_sl_atr_mult * atr_value);
      if(sl <= 0.0 || sl <= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "outside_bb_short";
      return true;
     }

   return false;
  }

// No active SL/TP modification — the fixed stop, hard TP, middle-band exit, and
// time stop in Strategy_ExitSignal cover management.
void Strategy_ManageOpenPosition()
  {
  }

// Primary exit: Bollinger middle-band (SMA20) touch/cross. Secondary: time stop
// after `time_stop_bars` closed H1 bars. (The hard TP and SL fire via the broker
// order.) Returns TRUE to close the open position for this magic.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Select this EA's position to read direction + open time.
   ulong   ticket   = 0;
   long    pos_type = -1;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      ticket    = t;
      pos_type  = PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }
   if(ticket == 0)
      return false;

   const double bb_mid = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double close1 = iClose(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double high1 = iHigh(_Symbol, _Period, 1);    // perf-allowed: single closed-bar read
   const double low1 = iLow(_Symbol, _Period, 1);      // perf-allowed: single closed-bar read

   // Primary exit: last closed bar reached/crossed the middle band.
   if(bb_mid > 0.0 && close1 > 0.0 && high1 > 0.0 && low1 > 0.0)
     {
      if(pos_type == POSITION_TYPE_BUY && high1 >= bb_mid)
         return true;
      if(pos_type == POSITION_TYPE_SELL && low1 <= bb_mid)
         return true;
     }

   // Time stop: bars held since entry >= time_stop_bars.
   if(open_time > 0)
     {
      const int bar_secs = PeriodSeconds(_Period);
      if(bar_secs > 0)
        {
         const int held_bars = (int)((TimeCurrent() - open_time) / bar_secs);
         if(held_bars >= strategy_time_stop_bars)
            return true;
        }
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
