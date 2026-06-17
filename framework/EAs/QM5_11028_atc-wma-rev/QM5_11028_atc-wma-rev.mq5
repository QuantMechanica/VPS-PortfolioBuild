#property strict
#property version   "5.0"
#property description "QM5_11028 atc-wma-rev — WMA Reversal Trend (fast/slow LWMA crossover, JPY crosses, H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11028 atc-wma-rev
// -----------------------------------------------------------------------------
// Source: Alexey Masterov, ATC 2012 interview, MQL5 Articles 624 (2013-01-08).
// Card: artifacts/cards_approved/QM5_11028_atc-wma-rev.md (g0_status APPROVED).
//
// Mechanics (both directions, closed-bar reads at shift 1; WMA == MT5 LWMA):
//   Long  STATE/EVENT: fast WMA crosses ABOVE slow WMA (fresh event), OR
//                      close > slow WMA AND fast WMA slope positive (state).
//   Short STATE/EVENT: fast WMA crosses BELOW slow WMA (fresh event), OR
//                      close < slow WMA AND fast WMA slope negative (state).
//   Optional related-symbol confirmation (default OFF): weighted fast-vs-slow
//                      WMA direction of GBPUSD/USDJPY; long needs score >=
//                      +confirm_threshold, short needs score <= -confirm_threshold.
//   Reverse exit : on opposite entry signal, close then re-enter the other way
//                  (framework OnTick closes via Strategy_ExitSignal, next bar
//                  re-enters via Strategy_EntrySignal).
//   Stop loss    : entry -/+ sl_atr_mult * ATR(atr_period).
//   Take profit  : entry +/- tp_atr_mult * ATR (same ATR value); tp_atr_mult<=0
//                  disables the TP (pure trend-capture variant).
//   Spread guard : skip only a genuinely wide spread > spread_pct_of_stop of the
//                  stop distance (fail-open on .DWX zero modeled spread).
//
// One active position per symbol/magic. Mechanical, fixed params, no ML.
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11028;
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
input int    strategy_fast_wma_period    = 24;    // fast WMA (LWMA) period
input int    strategy_slow_wma_period    = 144;   // slow WMA (LWMA) period
input int    strategy_atr_period         = 14;    // ATR period (stop / target)
input double strategy_sl_atr_mult        = 2.5;   // stop distance = mult * ATR
input double strategy_tp_atr_mult        = 5.0;   // target = mult * ATR (<=0 disables TP)
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance
// Optional related-symbol confirmation (sweep candidate; default OFF so the
// traded-symbol WMA logic stands alone and the basket dependency cannot starve
// trades). When enabled, reads GBPUSD/USDJPY fast-vs-slow WMA direction.
input bool   strategy_use_related_confirm = false; // enable related-symbol confirmation
input double strategy_confirm_weight_a    = 0.5;   // weight for related symbol A
input double strategy_confirm_weight_b    = 0.5;   // weight for related symbol B
input double strategy_confirm_threshold   = 0.5;   // |score| needed to confirm
input string strategy_related_symbol_a    = "GBPUSD.DWX"; // related confirm symbol A
input string strategy_related_symbol_b    = "USDJPY.DWX"; // related confirm symbol B

// -----------------------------------------------------------------------------
// Internal helpers
// -----------------------------------------------------------------------------

// Weighted related-symbol WMA-direction score in [-1, +1] (roughly): each
// related symbol contributes +weight if its fast WMA > slow WMA, -weight if
// below. Returns 0.0 when confirmation is disabled or data is missing.
double RelatedConfirmScore()
  {
   if(!strategy_use_related_confirm)
      return 0.0;

   double score = 0.0;

   const double a_fast = QM_WMA(strategy_related_symbol_a, _Period, strategy_fast_wma_period, 1);
   const double a_slow = QM_WMA(strategy_related_symbol_a, _Period, strategy_slow_wma_period, 1);
   if(a_fast > 0.0 && a_slow > 0.0)
      score += (a_fast > a_slow ? strategy_confirm_weight_a : -strategy_confirm_weight_a);

   const double b_fast = QM_WMA(strategy_related_symbol_b, _Period, strategy_fast_wma_period, 1);
   const double b_slow = QM_WMA(strategy_related_symbol_b, _Period, strategy_slow_wma_period, 1);
   if(b_fast > 0.0 && b_slow > 0.0)
      score += (b_fast > b_slow ? strategy_confirm_weight_b : -strategy_confirm_weight_b);

   return score;
  }

// Direction of a fresh traded-symbol signal on the last closed bar:
//   +1 long, -1 short, 0 none. Combines the cross EVENT with the state rule.
int TradedSignalDirection()
  {
   const double fast_now  = QM_WMA(_Symbol, _Period, strategy_fast_wma_period, 1);
   const double slow_now  = QM_WMA(_Symbol, _Period, strategy_slow_wma_period, 1);
   const double fast_prev = QM_WMA(_Symbol, _Period, strategy_fast_wma_period, 2);
   const double slow_prev = QM_WMA(_Symbol, _Period, strategy_slow_wma_period, 2);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return 0;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return 0;

   // Cross EVENT on the last closed bar.
   const bool crossed_up   = (fast_prev <= slow_prev && fast_now > slow_now);
   const bool crossed_down = (fast_prev >= slow_prev && fast_now < slow_now);

   // State rule: price vs slow WMA plus fast WMA slope.
   const bool slope_up   = (fast_now > fast_prev);
   const bool slope_down = (fast_now < fast_prev);
   const bool long_state  = (close1 > slow_now && slope_up);
   const bool short_state = (close1 < slow_now && slope_down);

   const bool want_long  = (crossed_up   || long_state);
   const bool want_short = (crossed_down || short_state);

   // Resolve any same-bar ambiguity in favour of the fresh cross EVENT, then
   // the state direction; never both.
   if(crossed_up && !crossed_down)
      return +1;
   if(crossed_down && !crossed_up)
      return -1;
   if(want_long && !want_short)
      return +1;
   if(want_short && !want_long)
      return -1;
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int dir = TradedSignalDirection();
   if(dir == 0)
      return false;

   // Optional weighted related-symbol confirmation.
   if(strategy_use_related_confirm)
     {
      const double score = RelatedConfirmScore();
      if(dir > 0 && score < strategy_confirm_threshold)
         return false;
      if(dir < 0 && score > -strategy_confirm_threshold)
         return false;
     }

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const QM_OrderType otype = (dir > 0) ? QM_BUY : QM_SELL;
   const double entry = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, otype, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   double tp = 0.0; // 0.0 = no TP (trend-capture variant)
   if(strategy_tp_atr_mult > 0.0)
     {
      tp = QM_TakeATRFromValue(_Symbol, otype, entry, atr_value, strategy_tp_atr_mult);
      if(tp <= 0.0)
         return false;
     }

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (dir > 0) ? "wma_rev_long" : "wma_rev_short";
   return true;
  }

// No active management beyond the fixed ATR stop/target. Reversal handled by
// Strategy_ExitSignal + next-bar re-entry.
void Strategy_ManageOpenPosition()
  {
  }

// Reverse exit: close the open position when the traded-symbol signal flips to
// the opposite direction of the held position.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int dir = TradedSignalDirection();
   if(dir == 0)
      return false;

   // Find this EA's open position direction.
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
      if(ptype == POSITION_TYPE_BUY && dir < 0)
         return true; // held long, signal flipped short -> close
      if(ptype == POSITION_TYPE_SELL && dir > 0)
         return true; // held short, signal flipped long -> close
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

   // Related-symbol confirmation needs the related symbols' history loaded into
   // the tester context. Register a basket guard + warm up history only when the
   // confirmation feature is enabled; otherwise stay single-symbol.
   if(strategy_use_related_confirm)
     {
      string basket[];
      ArrayResize(basket, 3);
      basket[0] = _Symbol;
      basket[1] = strategy_related_symbol_a;
      basket[2] = strategy_related_symbol_b;
      QM_SymbolGuardInit(basket);
      QM_BasketWarmupHistory(basket, (ENUM_TIMEFRAMES)_Period, 300);
     }

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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
