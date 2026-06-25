#property strict
#property version   "5.0"
#property description "QM5_11828 carter-m5-s18-ema20-macd-10pip-m5 - EMA20 + MACD histogram offset entry (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_11828 carter-m5-s18-ema20-macd-10pip-m5
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         2014, Strategy 18.
// Card: artifacts/cards_approved/QM5_11828_carter-m5-s18-ema20-macd-10pip-m5.md
//       (g0_status APPROVED). Timeframe M5.
//
// Mechanics (closed-bar reads at shift 1; one position per magic):
//   Trend STATE  : price clearly on one side of EMA(20) by an offset cushion.
//                  Long  -> close[1] > EMA20[1] + 10 pips.
//                  Short -> close[1] < EMA20[1] - 10 pips.
//   Momentum     : MACD(12,26,9) histogram state.
//                  Long  -> MACD main - signal > 0.
//                  Short -> MACD main - signal < 0.
//   Stop loss    : initial SL at 2x ATR(14), per card factory rule.
//   Take profit  : maximum TP at 4x ATR(14), per card factory rule.
//   Trade mgmt   : EMA-referenced trailing stop: tighten SL toward
//                  EMA20 -/+ 15 pips while the position runs, never loosening.
//   Spread guard : block only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11828;
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
input int    strategy_ema_period         = 20;    // trend EMA (Carter EMA20)
input int    strategy_macd_fast          = 12;    // MACD fast EMA
input int    strategy_macd_slow          = 26;    // MACD slow EMA
input int    strategy_macd_signal        = 9;     // MACD signal SMA
input int    strategy_offset_pips        = 10;    // STATE cushion: price beyond EMA by this many pips
input int    strategy_atr_period         = 14;    // ATR period for initial SL and maximum TP
input double strategy_atr_sl_mult        = 2.0;   // initial protective stop in ATR multiples
input double strategy_atr_tp_mult        = 4.0;   // maximum TP in ATR multiples
input int    strategy_trail_pips         = 15;    // EMA-referenced trailing stop offset (pips)
input int    strategy_spread_cap_pips    = 5;     // skip only if spread wider than this cap

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet - do not block on it

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(spread_cap > 0.0)
     {
      const double spread = ask - bid;
      // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
      if(spread > 0.0 && spread > spread_cap)
         return true;
     }

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_ema_period <= 0 || strategy_macd_fast <= 0 ||
      strategy_macd_slow <= strategy_macd_fast || strategy_macd_signal <= 0 ||
      strategy_offset_pips <= 0 || strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 || strategy_atr_tp_mult <= 0.0)
      return false;

   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double ema = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   if(ema <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double offset = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_offset_pips);
   if(offset <= 0.0)
      return false;

   // --- Momentum STATE: MACD histogram side (main - signal) ---
   const double macd_main = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                         strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_sig = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                          strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_hist = macd_main - macd_sig;

   // --- Trend STATE: price clearly above/below EMA by the offset cushion ---
   const bool uptrend_state   = (close1 > ema + offset);
   const bool downtrend_state = (close1 < ema - offset);

   QM_OrderType side = QM_BUY;
   string reason = "";
   if(uptrend_state && macd_hist > 0.0)
     {
      side   = QM_BUY;
      reason = "ema20_offset_macd_hist_long";
     }
   else if(downtrend_state && macd_hist < 0.0)
     {
      side   = QM_SELL;
      reason = "ema20_offset_macd_hist_short";
     }
   else
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, side, entry, atr, strategy_atr_tp_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = reason;
   return true;
  }

// EMA-referenced trailing stop. Tighten SL toward EMA20 -/+ trail offset while
// the position runs; never loosen. Reads closed-bar EMA (shift 1).
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   const double ema = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   if(ema <= 0.0)
      return;

   const double trail_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_trail_pips);
   if(trail_dist <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long ptype  = PositionGetInteger(POSITION_TYPE);
      const double cur_sl = PositionGetDouble(POSITION_SL);

      if(ptype == POSITION_TYPE_BUY)
        {
         const double new_sl = QM_TM_NormalizePrice(_Symbol, ema - trail_dist);
         // Only move the stop UP (tighten), never down.
         if(new_sl > 0.0 && (cur_sl <= 0.0 || new_sl > cur_sl))
            QM_TM_MoveSL(ticket, new_sl, "ema_trail");
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double new_sl = QM_TM_NormalizePrice(_Symbol, ema + trail_dist);
         // Only move the stop DOWN (tighten), never up.
         if(new_sl > 0.0 && (cur_sl <= 0.0 || new_sl < cur_sl))
            QM_TM_MoveSL(ticket, new_sl, "ema_trail");
        }
     }
  }

// No discretionary exit beyond the ATR TP, protective SL, and the EMA trail.
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
