#property strict
#property version   "5.0"
#property description "QM5_11613 robo-bb-wpr25-rsi5-m15 — BB+WPR(25)+RSI(5) mean-reversion (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11613 robo-bb-wpr25-rsi5-m15
// -----------------------------------------------------------------------------
// Source: RoboForex Educational Team, "Forex Strategy Collection" (~2015),
//         "The right moment", pages 30-33.
// Card: artifacts/cards_approved/QM5_11613_robo-bb-wpr25-rsi5-m15.md (g0 APPROVED).
//
// Mechanics (mean-reversion at Bollinger extremes, closed-bar reads at shift 1):
//   Confirming STATE (band) : last closed bar's Low <= BB lower (long) /
//                             High >= BB upper (short).
//   Confirming STATE (RSI)  : RSI(5) oversold < rsi_lo (long) /
//                             overbought > rsi_hi (short).
//   Trigger  EVENT (WPR)    : WPR(25) exits its extreme — crosses back UP through
//                             wpr_lo i.e. -80 (long) / crosses back DOWN through
//                             wpr_hi i.e. -20 (short). ONE event per bar; the
//                             band touch + RSI state are confirmations observed on
//                             the SAME closed bar, never a second fresh cross.
//   Stop     : entry -/+ sl_atr_mult * ATR(atr_period).
//   Take     : BB middle band at signal time, if it is beyond the entry by at
//              least the SL distance; otherwise tp_atr_mult * ATR fallback.
//   Spread guard : skip only a genuinely wide spread (> spread_pct_of_stop of the
//                  stop distance); fail-open on .DWX zero modeled spread.
//
// WPR scale note: iWPR/QM_WPR return 0 (top) to -100 (bottom). -80 = oversold,
// -20 = overbought. "Exit oversold" => value rises THROUGH -80 from below.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11613;
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
input int    strategy_bb_period         = 20;     // Bollinger period
input double strategy_bb_deviation      = 2.0;    // Bollinger deviation
input int    strategy_wpr_period        = 25;     // Williams %R period (card: 25)
input double strategy_wpr_lo            = -80.0;  // WPR oversold level (long trigger)
input double strategy_wpr_hi            = -20.0;  // WPR overbought level (short trigger)
input int    strategy_rsi_period        = 5;      // RSI period (card: 5)
input double strategy_rsi_lo            = 30.0;   // RSI oversold state (long)
input double strategy_rsi_hi            = 70.0;   // RSI overbought state (short)
input int    strategy_atr_period        = 14;     // ATR period for stop/target
input double strategy_sl_atr_mult       = 2.0;    // stop distance = mult * ATR
input double strategy_tp_atr_mult       = 4.0;    // target fallback if BB-mid too near
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Mean-reversion entry. Caller guarantees QM_IsNewBar() == true (closed bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Bollinger bands on the last closed bar (deviation arg MANDATORY) ---
   const double bb_upper = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
   const double bb_lower = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
   const double bb_mid   = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
   if(bb_upper <= 0.0 || bb_lower <= 0.0 || bb_mid <= 0.0)
      return false;

   // --- WPR(25): now (shift 1) and prior (shift 2) for the cross EVENT ---
   const double wpr_now  = QM_WPR(_Symbol, _Period, strategy_wpr_period, 1);
   const double wpr_prev = QM_WPR(_Symbol, _Period, strategy_wpr_period, 2);

   // --- RSI(5) state on the last closed bar ---
   const double rsi_now = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi_now <= 0.0)
      return false;

   // --- Band-touch STATE on the last closed bar (perf-allowed single read) ---
   const double low1  = iLow(_Symbol, _Period, 1);
   const double high1 = iHigh(_Symbol, _Period, 1);
   if(low1 <= 0.0 || high1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double entry_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_ask <= 0.0 || entry_bid <= 0.0)
      return false;

   // ---------------- LONG ----------------
   // Trigger EVENT: WPR exits oversold — rises back THROUGH wpr_lo (-80).
   const bool wpr_exit_oversold = (wpr_prev <= strategy_wpr_lo && wpr_now > strategy_wpr_lo);
   // Confirming STATES on the same closed bar: RSI oversold + price touched lower band.
   const bool rsi_oversold      = (rsi_now < strategy_rsi_lo);
   const bool touched_lower     = (low1 <= bb_lower);

   if(wpr_exit_oversold && rsi_oversold && touched_lower)
     {
      const double entry = entry_ask;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      const double sl_dist = entry - sl;
      // TP = BB middle if it is at least one stop-distance above entry, else ATR fallback.
      double tp = bb_mid;
      if(!(tp > entry + sl_dist))
         tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_tp_atr_mult);
      if(tp <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "bb_wpr_rsi_long";
      return true;
     }

   // ---------------- SHORT ----------------
   // Trigger EVENT: WPR exits overbought — falls back THROUGH wpr_hi (-20).
   const bool wpr_exit_overbought = (wpr_prev >= strategy_wpr_hi && wpr_now < strategy_wpr_hi);
   const bool rsi_overbought      = (rsi_now > strategy_rsi_hi);
   const bool touched_upper       = (high1 >= bb_upper);

   if(wpr_exit_overbought && rsi_overbought && touched_upper)
     {
      const double entry = entry_bid;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      const double sl_dist = sl - entry;
      double tp = bb_mid;
      if(!(tp < entry - sl_dist))
         tp = QM_TakeATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_tp_atr_mult);
      if(tp <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "bb_wpr_rsi_short";
      return true;
     }

   return false;
  }

// Fixed ATR stop + BB-mid/ATR target manage the trade; no active trailing.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond SL/TP. The BB-mid target captures the reversion.
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
