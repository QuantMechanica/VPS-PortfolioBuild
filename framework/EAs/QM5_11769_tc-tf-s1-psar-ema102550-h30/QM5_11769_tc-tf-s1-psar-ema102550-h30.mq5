#property strict
#property version   "5.0"
#property description "QM5_11769 tc-tf-s1-psar-ema102550-h30 — Triple-EMA stack + PSAR flip trigger (M30)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11769 tc-tf-s1-psar-ema102550-h30
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "Strategy #1", in "20 Trend Following Systems", 2014
//   (514732392-Forex-Trend-Following-Strategy.pdf, pp.8-9). Original TF 30min →
//   M30 (the "h30" in the slug = M30, the nearest DWX-testable 30-minute bar).
// Card: artifacts/cards_approved/QM5_11769_tc-tf-s1-psar-ema102550-h30.md
//   (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; one open position per magic):
//   Trend STATE  : EMA(10) > EMA(25) > EMA(50) (bullish ordered ribbon) for a
//                  long; EMA(10) < EMA(25) < EMA(50) (bearish) for a short.
//   Trigger EVENT: PSAR FLIP in the trend direction — the SAR dot crosses from
//                  ABOVE price (shift 2) to BELOW price (shift 1) for a long
//                  (mirror for short). The EMA stack is a STATE; the SAR flip is
//                  the single fresh EVENT, so the two-cross-same-bar zero-trade
//                  trap is avoided (only ONE thing has to "just happen").
//   Stop         : the current closed-bar SAR dot (shift 1), the standard
//                  Parabolic-SAR trailing stop. Capped at sl_cap_pips so a SAR
//                  dot that has drifted far from price cannot blow the risk.
//   Take profit  : card "Factory hard cap: 4xATR(14)". RR target via QM_TakeRR
//                  bounded by a 4*ATR ceiling (card: exit on EMA/PSAR reversal,
//                  TP is a hard cap not a primary target).
//   Exit (card)  : close[1] crosses back through ALL three EMAs to the slow side
//                  (close[1] < EMA50 for a long / close[1] > EMA50 for a short)
//                  OR PSAR flips against the position. Closed at next bar open.
//   SL trail     : trail the stop up/down each closed bar with the SAR dot (the
//                  card's "Trail with PSAR on subsequent bars").
//   Spread guard : block only a genuinely WIDE spread (> spread_pct_of_stop of
//                  the SAR stop distance); fail-open on .DWX zero modeled spread.
//
// Symbols (all in dwx_symbol_matrix.csv — no porting needed):
//   EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX, AUDUSD.DWX, USDCAD.DWX.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11769;
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
input int    strategy_ema_fast_period   = 10;     // fast EMA (ribbon top)
input int    strategy_ema_mid_period    = 25;     // mid EMA (ribbon middle)
input int    strategy_ema_slow_period   = 50;     // slow EMA (ribbon bottom)
input double strategy_sar_step          = 0.02;   // Parabolic SAR acceleration step (card standard)
input double strategy_sar_max           = 0.20;   // Parabolic SAR acceleration maximum (card standard)
input int    strategy_atr_period        = 14;     // ATR period for the TP hard cap
input double strategy_tp_atr_cap_mult   = 4.0;    // card "Factory hard cap: 4xATR(14)"
input double strategy_tp_rr             = 2.0;    // RR-multiple TP target (bounded by ATR cap)
input int    strategy_sl_cap_pips       = 30;     // cap SAR stop distance
input double strategy_spread_pct_of_stop = 15.0;  // block if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work lives in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Stop-distance reference for the spread cap: the SAR dot distance from the
   // closed-bar close, capped the same way the entry stop is capped.
   const double sar1   = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(sar1 <= 0.0 || close1 <= 0.0)
      return false; // defer to entry gate — do not block on missing data

   double stop_distance = MathAbs(close1 - sar1);
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(cap > 0.0 && stop_distance > cap)
      stop_distance = cap;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Compute the SL price from the SAR dot, capped to strategy_sl_cap_pips.
double SarStopPrice(const QM_OrderType type, const double entry, const double sar1)
  {
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   double sl = sar1;
   if(type == QM_BUY)
     {
      // SAR sits below price for a long. If it drifted further than the cap,
      // pull the stop up to the cap distance.
      if(cap > 0.0 && (entry - sl) > cap)
         sl = entry - cap;
     }
   else
     {
      if(cap > 0.0 && (sl - entry) > cap)
         sl = entry + cap;
     }
   return QM_StopRulesNormalizePrice(_Symbol, sl);
  }

// Compute the TP price: RR-multiple of the stop distance, bounded by a hard
// 4*ATR(14) ceiling (card: "Factory hard cap: 4xATR(14)").
double CappedTakeProfit(const QM_OrderType type, const double entry, const double sl)
  {
   double tp = QM_TakeRR(_Symbol, type, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return 0.0;

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr > 0.0 && strategy_tp_atr_cap_mult > 0.0)
     {
      const double cap_dist = strategy_tp_atr_cap_mult * atr;
      if(type == QM_BUY)
        {
         const double cap_price = entry + cap_dist;
         if(tp > cap_price)
            tp = cap_price;
        }
      else
        {
         const double cap_price = entry - cap_dist;
         if(tp < cap_price)
            tp = cap_price;
        }
     }
   return QM_StopRulesNormalizePrice(_Symbol, tp);
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Triple EMA ribbon (closed bar, shift 1) ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_mid  = QM_EMA(_Symbol, _Period, strategy_ema_mid_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_mid <= 0.0 || ema_slow <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // --- Parabolic SAR at the trigger bar (shift 1) and prior bar (shift 2) ---
   const double sar_now  = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double sar_prev = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 2);
   const double close2   = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(sar_now <= 0.0 || sar_prev <= 0.0 || close2 <= 0.0)
      return false;

   // --- LONG: ribbon ordered 10>25>50 (STATE) + SAR FLIP from above price
   //     (shift 2) to below price (shift 1) (EVENT). ---
   const bool stack_long    = (ema_fast > ema_mid && ema_mid > ema_slow);
   const bool sar_flip_bull = (sar_prev >= close2 && sar_now < close1);
   if(stack_long && sar_flip_bull)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = SarStopPrice(QM_BUY, entry, sar_now);
      if(sl <= 0.0 || sl >= entry)
         return false;
      const double tp = CappedTakeProfit(QM_BUY, entry, sl);
      if(tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ema_ribbon_psar_long";
      return true;
     }

   // --- SHORT: ribbon ordered 10<25<50 (STATE) + SAR FLIP from below price
   //     (shift 2) to above price (shift 1) (EVENT). ---
   const bool stack_short   = (ema_fast < ema_mid && ema_mid < ema_slow);
   const bool sar_flip_bear = (sar_prev <= close2 && sar_now > close1);
   if(stack_short && sar_flip_bear)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = SarStopPrice(QM_SELL, entry, sar_now);
      if(sl <= 0.0 || sl <= entry)
         return false;
      const double tp = CappedTakeProfit(QM_SELL, entry, sl);
      if(tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ema_ribbon_psar_short";
      return true;
     }

   return false;
  }

// Trail the SL with the SAR dot each closed bar (card: "Trail with PSAR on
// subsequent bars"). Only ever tighten the stop in the trade's favour.
void Strategy_ManageOpenPosition()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return;
   // NOTE: must NOT call QM_IsNewBar() here. The framework calls this hook
   // BEFORE its own new-bar gate; consuming the event here would starve the
   // entry path (single-consume per bar). The SAR dot at shift 1 only changes
   // on a closed bar, and QM_TM_MoveSL is a no-op when the target is unchanged,
   // so the per-tick path stays cheap and idempotent.
   const double sar1 = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   if(sar1 <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const bool   is_long  = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      const double cur_sl   = PositionGetDouble(POSITION_SL);
      const double open_px  = PositionGetDouble(POSITION_PRICE_OPEN);
      const double new_sl   = SarStopPrice(is_long ? QM_BUY : QM_SELL, open_px, sar1);
      if(new_sl <= 0.0)
         continue;

      // Only move the stop in the favourable direction (never loosen it).
      if(is_long && new_sl > cur_sl)
         QM_TM_MoveSL(ticket, new_sl, "psar_trail");
      else if(!is_long && (cur_sl <= 0.0 || new_sl < cur_sl))
         QM_TM_MoveSL(ticket, new_sl, "psar_trail");
     }
  }

// Card exit: price crosses back through ALL three EMAs to the slow side
// (close[1] < EMA50 long / close[1] > EMA50 short) OR PSAR flips against the
// position. State check on the closed bar (shift 1).
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double close1   = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double sar1     = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   if(ema_slow <= 0.0 || close1 <= 0.0 || sar1 <= 0.0)
      return false;

   // Determine the direction of the open position.
   bool is_long = false;
   bool found   = false;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      found   = true;
      break;
     }
   if(!found)
      return false;

   if(is_long)
     {
      // Close long if price closed below EMA50, or SAR flipped above price.
      if(close1 < ema_slow || sar1 > close1)
         return true;
     }
   else
     {
      // Close short if price closed above EMA50, or SAR flipped below price.
      if(close1 > ema_slow || sar1 < close1)
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
