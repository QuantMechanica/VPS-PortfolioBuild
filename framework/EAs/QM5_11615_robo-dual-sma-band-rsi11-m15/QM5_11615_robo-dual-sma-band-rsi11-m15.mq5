#property strict
#property version   "5.0"
#property description "QM5_11615 robo-dual-sma-band-rsi11-m15 — Double Volatility Channel + RSI(11) (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11615 robo-dual-sma-band-rsi11-m15
// -----------------------------------------------------------------------------
// Source: RoboForex Educational Team, "Forex Strategy Collection" (~2015),
//         page 42, "Breaking of the Double Volatility Channel".
// Card: artifacts/cards_approved/QM5_11615_robo-dual-sma-band-rsi11-m15.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1, M15):
//   Two SMA bands applied to High and Low prices form a double volatility
//   channel. SMA(5,H/L) is the inner band; SMA(20,H/L) is the outer band.
//   RSI(11) confirms momentum.
//
//   Band STATE (the filter, NOT the trigger — comparing two moving averages is
//   a persistent state, not an event):
//     Bullish channel : SMA(inner,High) > SMA(outer,High)
//     Bearish channel : SMA(inner,High) < SMA(outer,Low)
//
//   Trigger EVENT (exactly ONE event so we never need two crosses on one bar):
//     Long  : RSI(11) crosses UP through rsi_long_level (e.g. 65) while the
//             channel STATE is bullish.
//     Short : RSI(11) crosses DOWN through rsi_short_level (e.g. 35) while the
//             channel STATE is bearish.
//
//   Stop  : ATR(period) * sl_atr_mult (factory default 2x), via QM_StopATR.
//   Take  : RR-multiple of the stop distance (tp_rr, default 2.0 ~= 4xATR/2xATR
//           tracking the card's 4xATR target).
//   Exit  : card's RSI mean-reversion exit — RSI falls back below the long
//           level (close long) / rises back above the short level (close short).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11615;
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
input int    strategy_sma_inner_period   = 5;     // inner band SMA period (on High/Low)
input int    strategy_sma_outer_period   = 20;    // outer band SMA period (on High/Low)
input int    strategy_rsi_period         = 11;    // RSI lookback period
input double strategy_rsi_long_level     = 65.0;  // RSI long trigger / long-exit level
input double strategy_rsi_short_level    = 35.0;  // RSI short trigger / short-exit level
input int    strategy_atr_period         = 14;    // ATR period (stop sizing)
input double strategy_sl_atr_mult        = 2.0;   // stop distance = mult * ATR
input double strategy_tp_rr              = 2.0;   // take-profit as RR multiple of stop
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — band/RSI work is on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero spread.
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

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Band STATE (closed bar): inner vs outer SMA on High/Low prices ---
   const double sma_in_high  = QM_SMA(_Symbol, _Period, strategy_sma_inner_period, 1, PRICE_HIGH);
   const double sma_out_high = QM_SMA(_Symbol, _Period, strategy_sma_outer_period, 1, PRICE_HIGH);
   const double sma_out_low  = QM_SMA(_Symbol, _Period, strategy_sma_outer_period, 1, PRICE_LOW);
   if(sma_in_high <= 0.0 || sma_out_high <= 0.0 || sma_out_low <= 0.0)
      return false;

   const bool bullish_channel = (sma_in_high > sma_out_high);
   const bool bearish_channel = (sma_in_high < sma_out_low);

   // --- Trigger EVENT: a single fresh RSI cross. Band comparison above is a
   //     STATE; only the RSI cross is an event, so no two-cross-same-bar trap. ---
   const double rsi_now  = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double rsi_prev = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   if(rsi_now <= 0.0 || rsi_prev <= 0.0)
      return false;

   const bool rsi_cross_up   = (rsi_prev <= strategy_rsi_long_level &&
                                rsi_now  >  strategy_rsi_long_level);
   const bool rsi_cross_down = (rsi_prev >= strategy_rsi_short_level &&
                                rsi_now  <  strategy_rsi_short_level);

   QM_OrderType side;
   string reason;
   if(bullish_channel && rsi_cross_up)
     {
      side   = QM_BUY;
      reason = "double_channel_long";
     }
   else if(bearish_channel && rsi_cross_down)
     {
      side   = QM_SELL;
      reason = "double_channel_short";
     }
   else
      return false;

   // --- Stop / take. Framework sizes lots (no lots field on the request). ---
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = reason;
   return true;
  }

// No active management beyond the fixed ATR stop / RR target. The RSI
// mean-reversion exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Card exit: RSI mean-reverts back through the trigger level. Long closes when
// RSI falls back below the long level; short closes when RSI rises back above
// the short level. Direction is taken from the live open position.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double rsi_now = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi_now <= 0.0)
      return false;

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
      if(ptype == POSITION_TYPE_BUY && rsi_now < strategy_rsi_long_level)
         return true;
      if(ptype == POSITION_TYPE_SELL && rsi_now > strategy_rsi_short_level)
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
