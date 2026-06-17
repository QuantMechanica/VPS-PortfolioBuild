#property strict
#property version   "5.0"
#property description "QM5_11067 bulls-trend80 — Bulls Power trend/magnitude, fixed 80/40 TP/SL (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11067 bulls-trend80
// -----------------------------------------------------------------------------
// Source: MQL5 ATC 2010 top-ten interview (Tomasz Tauzowski, article 537).
// Card: artifacts/cards_approved/QM5_11067_bulls-trend80.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads, shift 1 = last closed bar):
//   Bulls Power : BP[s] = High[s] - EMA(Close, ema_period)[s].
//   Trend       : bulls_slope = BP[1] - BP[slope_lookback + 1].
//   Magnitude   : bulls_z = BP[1] / stdev(BP over z_lookback bars).
//   Long entry  : bulls_slope > slope_thresh AND bulls_z > magnitude_thresh
//                 AND Close[1] > EMA(Close, ema_period)[1].
//   Short entry : bulls_slope < -slope_thresh AND bulls_z < -magnitude_thresh
//                 AND Close[1] < EMA(Close, ema_period)[1].
//   Exit        : fixed broker SL/TP only (TP = 2x SL). No discretionary exit
//                 by default (opposite-signal exit is a Q03 sweep variant, OFF).
//   Stop / Take : fixed sl_pips / tp_pips (pip-scaled via QM_StopFixedPips/Take).
//   Filters     : ATR(14) liquidity floor; fail-open spread guard; news hook.
//   Position    : one open position per magic.
//
// .DWX invariants honoured: fail-OPEN spread (zero modeled spread never blocks);
// no swap gate; pip-scaled stops (5-digit safe); no external feed; gapless CFDs
// use prior CLOSE/EMA, not range gaps.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11067;
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
input int    strategy_ema_period        = 13;     // EMA(Close) period for Bulls Power
input int    strategy_slope_lookback    = 3;      // bars back for the Bulls Power slope
input int    strategy_z_lookback        = 96;     // bars for the Bulls Power stdev (z-score)
input double strategy_slope_thresh      = 0.0;    // min |slope| for a trend signal (price units)
input double strategy_magnitude_thresh  = 1.0;    // min |bulls_z| magnitude
input int    strategy_sl_pips           = 40;     // hard stop, pips
input int    strategy_tp_pips           = 80;     // take profit, pips (2x SL)
input int    strategy_atr_period        = 14;     // ATR liquidity-floor period
input double strategy_atr_floor_pips    = 5.0;    // min ATR in pips (noise floor)
input double strategy_spread_pct_of_stop = 25.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Bulls Power helper: BP[shift] = High[shift] - EMA(Close, ema_period)[shift].
// Closed-bar reads only. iHigh is a single bar read (perf-allowed), matching the
// reference-EA pattern; EMA goes through the pooled QM_EMA reader.
// -----------------------------------------------------------------------------
double BullsPowerAt(const int shift)
  {
   const double high_s = iHigh(_Symbol, _Period, shift); // perf-allowed: single closed-bar read
   const double ema_s  = QM_EMA(_Symbol, _Period, strategy_ema_period, shift);
   if(high_s <= 0.0 || ema_s <= 0.0)
      return EMPTY_VALUE;
   return high_s - ema_s;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; regime/signal work runs on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Stop distance reference for the spread cap, scaled to the symbol via pips.
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Bulls Power trend + magnitude entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Liquidity / noise floor: ATR(14) must exceed a minimum pip floor ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;
   const double atr_floor_price = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_atr_floor_pips);
   if(atr_floor_price > 0.0 && atr_value < atr_floor_price)
      return false;

   // --- Bulls Power trend (slope) over the closed-bar series ---
   const double bp_now  = BullsPowerAt(1);
   const double bp_back = BullsPowerAt(strategy_slope_lookback + 1);
   if(bp_now == EMPTY_VALUE || bp_back == EMPTY_VALUE)
      return false;
   const double bulls_slope = bp_now - bp_back;

   // --- Bulls Power magnitude (z-score) over z_lookback bars ---
   // stdev of BP across shifts 1 .. z_lookback. Bounded loop (~96 iterations),
   // runs once per closed bar (this hook is on the QM_IsNewBar path).
   const int n = strategy_z_lookback;
   if(n < 2)
      return false;
   double sum = 0.0;
   int    cnt = 0;
   for(int s = 1; s <= n; ++s)
     {
      const double bp_s = BullsPowerAt(s);
      if(bp_s == EMPTY_VALUE)
         continue;
      sum += bp_s;
      cnt++;
     }
   if(cnt < 2)
      return false;
   const double mean = sum / cnt;
   double var_sum = 0.0;
   for(int s = 1; s <= n; ++s)
     {
      const double bp_s = BullsPowerAt(s);
      if(bp_s == EMPTY_VALUE)
         continue;
      const double d = bp_s - mean;
      var_sum += d * d;
     }
   const double stdev = MathSqrt(var_sum / (cnt - 1));
   if(stdev <= 0.0)
      return false;
   const double bulls_z = bp_now / stdev;

   // --- Price vs EMA position (closed bar) ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double ema1   = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   if(close1 <= 0.0 || ema1 <= 0.0)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   bool is_long  = (bulls_slope >  strategy_slope_thresh &&
                    bulls_z     >  strategy_magnitude_thresh &&
                    close1      >  ema1);
   bool is_short = (bulls_slope < -strategy_slope_thresh &&
                    bulls_z     < -strategy_magnitude_thresh &&
                    close1      <  ema1);

   if(!is_long && !is_short)
      return false;

   const QM_OrderType side = is_long ? QM_BUY : QM_SELL;
   const double ref = is_long ? entry : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ref <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, side, ref, strategy_sl_pips);
   const double tp = QM_TakeFixedPips(_Symbol, side, ref, strategy_tp_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = is_long ? "bulls_trend_long" : "bulls_trend_short";
   return true;
  }

// Fixed SL/TP only — no active trade management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit by default; SL/TP do the work. (Opposite-signal exit is
// a Q03 sweep variant, intentionally OFF in the baseline.)
bool Strategy_ExitSignal()
  {
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
