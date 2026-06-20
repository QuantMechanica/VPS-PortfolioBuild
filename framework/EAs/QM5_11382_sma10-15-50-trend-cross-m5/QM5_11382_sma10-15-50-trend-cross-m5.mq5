#property strict
#property version   "5.0"
#property description "QM5_11382 sma10-15-50-trend-cross-m5 - Triple-SMA trend + band-breakout scalper (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_11382 sma10-15-50-trend-cross-m5
// -----------------------------------------------------------------------------
// Source: "5 Minute Forex Scalping Strategy (SMA 10/15/50)" (anonymous LQDFX
//   broker promotional ebook, local PDF). Card:
//   artifacts/cards_approved/QM5_11382_sma10-15-50-trend-cross-m5.md (APPROVED).
//
// Mechanics (M5, closed-bar reads):
//   Trend state    : close[1] > SMA50  (bullish)  /  close[1] < SMA50 (bearish).
//   Alignment state: SMA10 > SMA50 AND SMA15 > SMA50 (long); inverse (short).
//   Trigger        : the closed M5 candle is completely above BOTH SMA10 and
//                    SMA15 (long): low[1] > max(SMA10,SMA15). Short is the
//                    mirror: high[1] < min(SMA10,SMA15).
//   Stop           : entry -/+ min(ATR(14)*sl_atr_mult, sl_cap_pips).
//   Take profit    : entry +/- ATR(14)*tp_atr_mult.
//   Defensive exit : price candle closes back below SMA10 OR SMA15 (long) /
//                    above SMA10 OR SMA15 (short) - the source "re-cross" exit.
//   Session        : London + NY only, broker-time window [sess_start,sess_end).
//   Spread guard   : block only a genuinely wide spread > spread_cap_pips
//                    (fail-OPEN on .DWX zero modeled spread, invariant #1).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11382;
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
input int    strategy_sma_fast_period   = 10;     // fast SMA of the trigger band
input int    strategy_sma_mid_period    = 15;     // mid SMA of the trigger band
input int    strategy_sma_trend_period  = 50;     // trend-filter SMA
input int    strategy_atr_period        = 14;     // ATR period (stop / target)
input double strategy_sl_atr_mult       = 1.0;    // stop distance = mult * ATR
input double strategy_tp_atr_mult       = 1.5;    // target distance = mult * ATR
input int    strategy_sl_cap_pips       = 20;     // P2 hard cap on stop distance (pips)
input int    strategy_spread_cap_pips   = 12;     // block only spread wider than this (pips)
input int    strategy_sess_start_broker = 13;     // London+NY window open hour (broker time)
input int    strategy_sess_end_broker   = 22;     // window close hour (exclusive, broker time)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: session window + spread guard. Fail-OPEN on .DWX
// zero modeled spread (only a genuinely wide spread blocks).
bool Strategy_NoTradeFilter()
  {
   // --- Session filter (broker time). Wrap-safe within a single day. ---
   const datetime now = TimeCurrent();
   MqlDateTime mt;
   TimeToStruct(now, mt);
   const int h = mt.hour;
   const int s = strategy_sess_start_broker;
   const int e = strategy_sess_end_broker;
   bool in_session;
   if(s <= e)
      in_session = (h >= s && h < e);
   else
      in_session = (h >= s || h < e); // overnight wrap
   if(!in_session)
      return true; // outside London+NY window - block

   // --- Spread guard: fail-OPEN on zero/negative modeled spread. ---
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet - do not block on it

   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(cap <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > cap)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_sma_fast_period <= 0 ||
      strategy_sma_mid_period <= 0 ||
      strategy_sma_trend_period <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_sl_atr_mult <= 0.0 ||
      strategy_tp_atr_mult <= 0.0 ||
      strategy_sl_cap_pips <= 0 ||
      strategy_spread_cap_pips <= 0 ||
      strategy_sess_start_broker < 0 ||
      strategy_sess_start_broker > 23 ||
      strategy_sess_end_broker < 0 ||
      strategy_sess_end_broker > 23)
      return false;

   // --- SMAs at the trigger bar [1] ---
   const double sma10_1 = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 1);
   const double sma15_1 = QM_SMA(_Symbol, _Period, strategy_sma_mid_period, 1);
   const double sma50_1 = QM_SMA(_Symbol, _Period, strategy_sma_trend_period, 1);
   if(sma10_1 <= 0.0 || sma15_1 <= 0.0 || sma50_1 <= 0.0)
      return false;

   // --- Bespoke OHLC reads (perf-allowed: single closed-bar reads) ---
   const double low1   = iLow(_Symbol, _Period, 1);   // perf-allowed
   const double high1  = iHigh(_Symbol, _Period, 1);  // perf-allowed
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed
   if(low1 <= 0.0 || high1 <= 0.0 || close1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double band_top_1 = MathMax(sma10_1, sma15_1);
   const double band_bot_1 = MathMin(sma10_1, sma15_1);

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   // ---------------- LONG ----------------
   const bool long_state =
      (close1 > sma50_1) && (sma10_1 > sma50_1) && (sma15_1 > sma50_1);
   const bool long_trigger = (low1 > band_top_1);

   if(long_state && long_trigger)
     {
      double sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr_value, strategy_sl_atr_mult);
      const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
      if(cap > 0.0 && MathAbs(ask - sl) > cap)
         sl = QM_StopRulesNormalizePrice(_Symbol, ask - cap);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, ask, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "sma_band_breakout_long";
      return true;
     }

   // ---------------- SHORT ----------------
   const bool short_state =
      (close1 < sma50_1) && (sma10_1 < sma50_1) && (sma15_1 < sma50_1);
   const bool short_trigger = (high1 < band_bot_1);

   if(short_state && short_trigger)
     {
      double sl = QM_StopATRFromValue(_Symbol, QM_SELL, bid, atr_value, strategy_sl_atr_mult);
      const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
      if(cap > 0.0 && MathAbs(sl - bid) > cap)
         sl = QM_StopRulesNormalizePrice(_Symbol, bid + cap);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL, bid, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "sma_band_breakout_short";
      return true;
     }

   return false;
  }

// Fixed ATR stop/target - no active management beyond the defensive re-cross
// exit in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: price candle closes back inside/through the band - close
// below SMA10 OR SMA15 for a long; above SMA10 OR SMA15 for a short. One
// closed-bar read at shift 1.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double sma10_1 = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 1);
   const double sma15_1 = QM_SMA(_Symbol, _Period, strategy_sma_mid_period, 1);
   const double close1  = iClose(_Symbol, _Period, 1); // perf-allowed
   if(sma10_1 <= 0.0 || sma15_1 <= 0.0 || close1 <= 0.0)
      return false;

   // Determine current position direction for this magic.
   bool is_long  = false;
   bool is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         is_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         is_short = true;
      break;
     }

   if(is_long)
      return (close1 < sma10_1 || close1 < sma15_1);
   if(is_short)
      return (close1 > sma10_1 || close1 > sma15_1);
   return false;
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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
