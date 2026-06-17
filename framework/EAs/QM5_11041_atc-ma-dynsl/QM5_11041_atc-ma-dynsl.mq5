#property strict
#property version   "5.0"
#property description "QM5_11041 atc-ma-dynsl — MA comparison entry, constant D1-ATR TP, dynamic SL (H1)"

#include <QM/QM_Common.mqh>
#include <QM/QM_StopRules.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11041 atc-ma-dynsl
// -----------------------------------------------------------------------------
// Source: Alexander Anufrenko, "A danger foreseen is half avoided" (ATC 2010),
//   MQL5 Articles 2010-11-09, https://www.mql5.com/en/articles/535
// Card: artifacts/cards_approved/QM5_11041_atc-ma-dynsl.md (g0_status APPROVED).
//
// Mechanics (long+short, closed-bar reads at shift 1, H1 base):
//   Entry STATE  : fast SMA vs slow SMA position decides direction.
//                  Long  when fast > slow AND fast has positive slope
//                        (fast@1 > fast@2).
//                  Short when fast < slow AND fast has negative slope
//                        (fast@1 < fast@2).
//                  One position per symbol/magic; no entry while one is open.
//   Take profit  : CONSTANT distance = tp_daily_range_mult * ATR(14, D1).
//   Dynamic SL   : distance = max( sl_atr_mult * ATR(14, H1),
//                                  ma_gap_mult * |fast - slow|,
//                                  min_sl_pips floor ).
//   Exit         : opposite MA comparison (fast crosses to the other side of
//                  slow) closes the position manually; SL/TP handle the rest.
//   Optional D1 trend filter (default OFF): longs only when D1 close > D1 EMA,
//                  shorts only when D1 close < D1 EMA.
//   Optional vol filter (default OFF): skip if H1 ATR exceeds a rolling high.
//   Spread guard : skip only a genuinely wide spread > spread_pct_of_stop of
//                  the dynamic stop distance (fail-open on .DWX zero spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11041;
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
input int    strategy_fast_ma_period     = 13;     // fast moving average period
input int    strategy_slow_ma_period     = 55;     // slow moving average period
input int    strategy_atr_period_h1      = 14;     // H1 ATR period (dynamic SL component)
input int    strategy_atr_period_d1      = 14;     // D1 ATR period (constant TP basis)
input double strategy_sl_atr_mult        = 1.5;    // SL ATR component multiple
input double strategy_ma_gap_mult        = 1.5;    // SL MA-gap component multiple
input int    strategy_min_sl_pips        = 100;    // SL floor in pips (scale-correct)
input double strategy_tp_daily_range_mult = 0.50;  // TP = mult * D1 ATR
input bool   strategy_use_d1_trend_filter = false; // optional D1 EMA direction filter
input int    strategy_d1_ema_period      = 50;     // D1 trend-filter EMA period
input bool   strategy_use_vol_filter     = false;  // optional high-volatility skip
input int    strategy_vol_lookback_bars  = 100;    // bars for rolling vol reference
input double strategy_vol_skip_mult      = 2.0;    // skip if H1 ATR > mult * mean H1 ATR proxy
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Internal helpers
// -----------------------------------------------------------------------------

// Dynamic SL distance (price units) per the card:
//   max( sl_atr_mult * ATR(H1), ma_gap_mult * |fast-slow|, min_sl_pips floor ).
double DynamicStopDistance(const double atr_h1,
                           const double fast_ma,
                           const double slow_ma)
  {
   const double atr_component = strategy_sl_atr_mult * atr_h1;
   const double ma_component  = strategy_ma_gap_mult * MathAbs(fast_ma - slow_ma);
   const double floor_dist    = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_min_sl_pips);

   double dist = atr_component;
   if(ma_component > dist)
      dist = ma_component;
   if(floor_dist > dist)
      dist = floor_dist;
   return dist;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is on the
// closed-bar path. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_h1 = QM_ATR(_Symbol, _Period, strategy_atr_period_h1, 1);
   if(atr_h1 <= 0.0)
      return false; // no ATR yet — defer to the entry gate

   const double fast_ma = QM_SMA(_Symbol, _Period, strategy_fast_ma_period, 1);
   const double slow_ma = QM_SMA(_Symbol, _Period, strategy_slow_ma_period, 1);
   if(fast_ma <= 0.0 || slow_ma <= 0.0)
      return false;

   const double stop_distance = DynamicStopDistance(atr_h1, fast_ma, slow_ma);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// MA-comparison entry. Caller guarantees QM_IsNewBar() == true (closed bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Moving averages at shifts 1 and 2 (slope from the closed bars) ---
   const double fast_now  = QM_SMA(_Symbol, _Period, strategy_fast_ma_period, 1);
   const double slow_now  = QM_SMA(_Symbol, _Period, strategy_slow_ma_period, 1);
   const double fast_prev = QM_SMA(_Symbol, _Period, strategy_fast_ma_period, 2);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0)
      return false;

   // Direction from MA position; slope confirms it (one STATE, no double-event).
   bool go_long  = (fast_now > slow_now) && (fast_now > fast_prev);
   bool go_short = (fast_now < slow_now) && (fast_now < fast_prev);
   if(!go_long && !go_short)
      return false;

   // --- Optional D1 trend filter ---
   if(strategy_use_d1_trend_filter)
     {
      const double d1_ema   = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period, 1);
      const double d1_close = QM_SMA(_Symbol, PERIOD_D1, 1, 1); // 1-period SMA = prior D1 close
      if(d1_ema <= 0.0 || d1_close <= 0.0)
         return false;
      if(go_long && !(d1_close > d1_ema))
         return false;
      if(go_short && !(d1_close < d1_ema))
         return false;
     }

   // --- Volatility components / filters ---
   const double atr_h1 = QM_ATR(_Symbol, _Period, strategy_atr_period_h1, 1);
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(atr_h1 <= 0.0 || atr_d1 <= 0.0)
      return false;

   // Optional vol filter: skip when current H1 ATR sits far above a slower
   // ATR baseline (a coarse rolling-high proxy without per-tick scans).
   if(strategy_use_vol_filter)
     {
      const double atr_slow = QM_ATR(_Symbol, _Period, strategy_vol_lookback_bars, 1);
      if(atr_slow > 0.0 && atr_h1 > strategy_vol_skip_mult * atr_slow)
         return false;
     }

   // --- Build entry. Framework sizes lots (no lots field on req). ---
   const QM_OrderType side  = go_long ? QM_BUY : QM_SELL;
   const double entry = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl_distance = DynamicStopDistance(atr_h1, fast_now, slow_now);
   const double tp_distance = strategy_tp_daily_range_mult * atr_d1;
   if(sl_distance <= 0.0 || tp_distance <= 0.0)
      return false;

   const double sl = QM_StopRulesStopFromDistance(_Symbol, side, entry, sl_distance);
   const double tp = QM_StopRulesTakeFromDistance(_Symbol, side, entry, tp_distance);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = go_long ? "atc_ma_dynsl_long" : "atc_ma_dynsl_short";
   return true;
  }

// Constant TP + dynamic SL set at entry; no active trade management.
void Strategy_ManageOpenPosition()
  {
  }

// Opposite MA comparison closes the position. The open side is inferred from
// the live position; close when the MA position flips against it.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double fast_now = QM_SMA(_Symbol, _Period, strategy_fast_ma_period, 1);
   const double slow_now = QM_SMA(_Symbol, _Period, strategy_slow_ma_period, 1);
   if(fast_now <= 0.0 || slow_now <= 0.0)
      return false;

   // Determine the held direction.
   bool have_long  = false;
   bool have_short = false;
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
      if(ptype == POSITION_TYPE_BUY)
         have_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         have_short = true;
     }

   // Close a long when fast falls below slow; close a short when fast rises above.
   if(have_long && fast_now < slow_now)
      return true;
   if(have_short && fast_now > slow_now)
      return true;
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
