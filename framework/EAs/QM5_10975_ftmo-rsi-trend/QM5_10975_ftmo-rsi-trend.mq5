#property strict
#property version   "5.0"
#property description "QM5_10975 ftmo-rsi-trend — RSI trend-range pullback (long+short, H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10975 ftmo-rsi-trend
// -----------------------------------------------------------------------------
// Source: FTMO, "Technical analysis - what's the magic of RSI", 2022-12-23.
// Card: artifacts/cards_approved/QM5_10975_ftmo-rsi-trend.md (g0_status APPROVED).
//
// Mechanics (long + short, closed-bar reads at shift 1; H4):
//   Long regime STATE : RSI(14) in [40,80] on >= 14 of the last 20 closed bars
//                       AND close(1) > EMA(100).
//   Long pullback STATE: prior closed RSI dipped below 50 but stayed above 40
//                       (40 < RSI < 50).
//   Long trigger EVENT: RSI crosses back above 50 (prev<=50, now>50)
//                       AND the trigger candle closes above the PRIOR candle high.
//   Short is the mirror: RSI(14) in [20,60] on >=14/20, close<EMA(100), pullback
//                       50<RSI<60, trigger RSI crosses below 50 and candle closes
//                       below the prior candle low.
//   Stop  (long)  : recent 8-bar swing low  - 0.25*ATR(14).
//   Stop  (short) : recent 8-bar swing high + 0.25*ATR(14).
//   Take profit   : 2.0R from entry/stop (QM_TakeRR).
//   Breakeven     : after price travels >= 1.0R, move SL to entry.
//   Discretionary exit: long closes if RSI(1) < 40; short closes if RSI(1) > 60;
//                       OR time exit after 18 closed bars in trade.
//   Vol floor     : skip if ATR(14,1) < 100-bar 25th percentile of ATR.
//   Stop-distance band: skip if stop distance < 0.5*ATR or > 2.5*ATR.
//   Spread guard  : fail-OPEN on .DWX zero modeled spread; block only a
//                   genuinely wide spread > spread_pct_of_stop of stop distance.
//
// One open position per symbol/magic. RISK_FIXED sizing in tester. No ML,
// no martingale, no grid. Only the 5 Strategy_* hooks + Strategy inputs are
// EA-specific; everything else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10975;
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
input int    strategy_rsi_period         = 14;     // RSI lookback period
input int    strategy_ema_period         = 100;    // directional EMA filter
input int    strategy_atr_period         = 14;     // ATR period (filter / stop)
input int    strategy_regime_lookback    = 20;     // bars in the trend-range test
input int    strategy_regime_min_in_band = 14;     // min bars inside the band
input double strategy_long_band_lo       = 40.0;   // long regime RSI band low
input double strategy_long_band_hi       = 80.0;   // long regime RSI band high
input double strategy_short_band_lo      = 20.0;   // short regime RSI band low
input double strategy_short_band_hi      = 60.0;   // short regime RSI band high
input double strategy_rsi_cross_level    = 50.0;   // RSI resumption trigger level
input double strategy_long_pb_floor      = 40.0;   // long pullback: RSI stays above this
input double strategy_short_pb_ceil      = 60.0;   // short pullback: RSI stays below this
input int    strategy_swing_lookback     = 8;      // swing low/high lookback for the stop
input double strategy_swing_atr_buffer   = 0.25;   // ATR buffer beyond the swing extreme
input double strategy_tp_rr              = 2.0;    // take-profit in R multiples
input double strategy_be_trigger_rr      = 1.0;    // move SL to BE after this many R
input double strategy_long_exit_rsi      = 40.0;   // close long if RSI closes below this
input double strategy_short_exit_rsi     = 60.0;   // close short if RSI closes above this
input int    strategy_time_exit_bars     = 18;     // close after this many closed bars
input int    strategy_atr_pctile_window  = 100;    // window for the ATR 25th-percentile floor
input double strategy_atr_pctile         = 25.0;   // ATR floor percentile (0..100)
input double strategy_stop_min_atr_mult  = 0.5;    // skip if stop distance < this * ATR
input double strategy_stop_max_atr_mult  = 2.5;    // skip if stop distance > this * ATR
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helper: count how many of the last `lookback` closed RSI values lie within
// [lo, hi]. Reads shift 1 .. lookback (all closed bars).
// -----------------------------------------------------------------------------
int RsiCountInBand(const int lookback, const double lo, const double hi)
  {
   int count = 0;
   for(int s = 1; s <= lookback; ++s)
     {
      const double r = QM_RSI(_Symbol, _Period, strategy_rsi_period, s);
      if(r <= 0.0)
         continue;
      if(r >= lo && r <= hi)
         count++;
     }
   return count;
  }

// -----------------------------------------------------------------------------
// Helper: ATR percentile floor. Reads `window` closed ATR values (shift 1..N),
// returns the value at the `pctile`-th percentile (nearest-rank). Returns 0 on
// insufficient data so the caller fails open (does not block).
// -----------------------------------------------------------------------------
double AtrPercentileFloor(const int window, const double pctile)
  {
   if(window <= 1)
      return 0.0;
   double vals[];
   ArrayResize(vals, window);
   int n = 0;
   for(int s = 1; s <= window; ++s)
     {
      const double a = QM_ATR(_Symbol, _Period, strategy_atr_period, s);
      if(a <= 0.0)
         continue;
      vals[n] = a;
      n++;
     }
   if(n < 2)
      return 0.0;
   ArrayResize(vals, n);
   ArraySort(vals); // ascending
   double rank = (pctile / 100.0) * (n - 1);
   int lo_idx = (int)MathFloor(rank);
   int hi_idx = (int)MathCeil(rank);
   if(lo_idx < 0)
      lo_idx = 0;
   if(hi_idx > n - 1)
      hi_idx = n - 1;
   const double frac = rank - lo_idx;
   return vals[lo_idx] + frac * (vals[hi_idx] - vals[lo_idx]);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate

   // Use a representative swing-based stop distance proxy: ATR itself scaled by
   // the swing buffer is too small; use 1*ATR as the spread-cap reference. The
   // cap is intentionally generous; the only goal is to reject pathological
   // spreads, never to block the .DWX zero-spread tester.
   const double stop_distance = atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Long + short entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
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

   const double ema = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   if(ema <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // Volatility floor: skip if ATR below its rolling 25th percentile.
   const double atr_floor = AtrPercentileFloor(strategy_atr_pctile_window, strategy_atr_pctile);
   if(atr_floor > 0.0 && atr_value < atr_floor)
      return false;

   const double rsi_now  = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double rsi_prev = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   if(rsi_now <= 0.0 || rsi_prev <= 0.0)
      return false;

   // Prior candle high/low for the candle-confirmation rule (closed bars).
   const double high_prior = iHigh(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   const double low_prior  = iLow(_Symbol, _Period, 2);  // perf-allowed: single closed-bar read
   if(high_prior <= 0.0 || low_prior <= 0.0)
      return false;

   // === LONG ===
   bool long_ok = false;
   {
      const bool regime = (close1 > ema) &&
                          (RsiCountInBand(strategy_regime_lookback,
                                          strategy_long_band_lo,
                                          strategy_long_band_hi) >= strategy_regime_min_in_band);
      const bool trigger = (rsi_prev <= strategy_rsi_cross_level &&
                            rsi_now  >  strategy_rsi_cross_level) &&
                           (close1 > high_prior); // candle closes above prior high
      const bool pullback = (rsi_prev > strategy_long_pb_floor &&
                             rsi_prev < strategy_rsi_cross_level);
      long_ok = (regime && trigger && pullback);
   }

   // === SHORT ===
   bool short_ok = false;
   if(!long_ok)
     {
      const bool regime = (close1 < ema) &&
                          (RsiCountInBand(strategy_regime_lookback,
                                          strategy_short_band_lo,
                                          strategy_short_band_hi) >= strategy_regime_min_in_band);
      const bool trigger = (rsi_prev >= strategy_rsi_cross_level &&
                            rsi_now  <  strategy_rsi_cross_level) &&
                           (close1 < low_prior); // candle closes below prior low
      const bool pullback = (rsi_prev < strategy_short_pb_ceil &&
                             rsi_prev > strategy_rsi_cross_level);
      short_ok = (regime && trigger && pullback);
     }

   if(!long_ok && !short_ok)
      return false;

   const QM_OrderType side = long_ok ? QM_BUY : QM_SELL;

   // --- Swing-based stop: 8-bar swing low/high +/- 0.25*ATR ---
   double swing_lo = 0.0;
   double swing_hi = 0.0;
   if(!QM_StopRulesReadStructureExtremes(_Symbol, strategy_swing_lookback, swing_lo, swing_hi))
      return false;
   if(swing_lo <= 0.0 || swing_hi <= 0.0)
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double sl_raw = (side == QM_BUY) ? (swing_lo - strategy_swing_atr_buffer * atr_value)
                                    : (swing_hi + strategy_swing_atr_buffer * atr_value);
   const double sl = QM_StopRulesNormalizePrice(_Symbol, sl_raw);
   if(sl <= 0.0)
      return false;

   // Stop must sit on the correct side of entry.
   if(side == QM_BUY && !(sl < entry))
      return false;
   if(side == QM_SELL && !(sl > entry))
      return false;

   // Stop-distance band gate: 0.5*ATR <= distance <= 2.5*ATR.
   const double stop_distance = MathAbs(entry - sl);
   if(stop_distance < strategy_stop_min_atr_mult * atr_value)
      return false;
   if(stop_distance > strategy_stop_max_atr_mult * atr_value)
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "ftmo_rsi_trend_long" : "ftmo_rsi_trend_short";

   return true;
  }

// Per-tick management: move SL to breakeven once price travels >= be_trigger_rr.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double cur_sl     = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0)
         continue;

      // Original risk distance = |entry - initial SL|. We do not store the
      // initial SL, so derive R from the current SL only when SL is still on the
      // far side (pre-BE). Once SL == entry (BE), |entry-SL|==0 and we skip.
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (ptype == POSITION_TYPE_BUY);

      const double risk = MathAbs(open_price - cur_sl);
      if(risk <= 0.0)
         continue; // already at/through breakeven

      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;

      const double moved = is_buy ? (market - open_price) : (open_price - market);
      if(moved < strategy_be_trigger_rr * risk)
         continue;

      // Only move SL toward entry if it improves the stop (buy: up, sell: down).
      const double be = QM_StopRulesNormalizePrice(_Symbol, open_price);
      const bool improves = is_buy ? (be > cur_sl) : (be < cur_sl);
      if(!improves)
         continue;

      QM_TM_MoveSL(ticket, be, "breakeven_after_1R");
     }
  }

// Discretionary exit: RSI threshold OR time exit after N closed bars.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double rsi_now = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi_now <= 0.0)
      return false;

   // Determine our open direction to apply the correct RSI exit threshold.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time > 0)
        {
         const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
         if(period_seconds > 0 && TimeCurrent() - open_time >= strategy_time_exit_bars * period_seconds)
            return true;
        }
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && rsi_now < strategy_long_exit_rsi)
         return true;
      if(ptype == POSITION_TYPE_SELL && rsi_now > strategy_short_exit_rsi)
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
