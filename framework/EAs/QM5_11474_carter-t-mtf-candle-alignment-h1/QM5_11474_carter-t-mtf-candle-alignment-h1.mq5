#property strict
#property version   "5.0"
#property description "QM5_11474 carter-t-mtf-candle-alignment-h1 — Multi-Timeframe Candle Alignment Momentum (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11474 carter-t-mtf-candle-alignment-h1
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
//   Strategy #16 (self-published, 2014). R1 CONDITIONAL.
// Card: artifacts/cards_approved/QM5_11474_carter-t-mtf-candle-alignment-h1.md
//   (g0_status APPROVED).
//
// Mechanics (all reads on CLOSED bars, shift 1):
//   Alignment STATE : the last completed candles on M5, M15, M30, and H1 all
//                     close the SAME color. Bullish means close > open; bearish
//                     means close < open.
//   Entry           : at the H1 closed-bar gate, place a stop order 3 pips
//                     beyond the H1 close in the aligned direction. The pending
//                     order expires after 3 H1 bars.
//   Direction        : all bullish -> BUY ; all bearish -> SELL.
//   Stop / Take      : fixed pips (50 / 50 by default, card defaults). Scaled to
//                      price distance via QM_StopRulesPipsToPriceDistance so it
//                      is correct on 5-digit / JPY symbols.
//   Filters          : spread cap (fail-open on .DWX zero spread), optional
//                      no-Friday-entry (card "No Friday entry").
//   One open position per symbol/magic.
//
// Candle reads use bounded CopyRates calls for one closed bar per timeframe.
// perf-allowed: no QM helper exposes raw candle color, and this structural rule
// runs only inside the framework H1 new-bar entry gate.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11474;
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
// Alignment timeframes (lower-TF confluence STATE). H1 is the trigger TF and is
// always _Period when the EA runs on H1.
input ENUM_TIMEFRAMES strategy_tf_a       = PERIOD_M5;   // alignment TF 1
input ENUM_TIMEFRAMES strategy_tf_b       = PERIOD_M15;  // alignment TF 2
input ENUM_TIMEFRAMES strategy_tf_c       = PERIOD_M30;  // alignment TF 3
input int    strategy_trigger_pips        = 3;      // stop-order offset beyond H1 close (pips)
input int    strategy_sl_pips             = 50;     // fixed stop loss (pips)
input int    strategy_tp_pips             = 50;     // fixed take profit (pips)
input int    strategy_expire_hours        = 3;      // pending stop order expiration (hours)
input int    strategy_spread_cap_pips     = 20;     // skip if genuine spread wider than this (pips)
input bool   strategy_no_friday_entry     = true;   // card: no Friday entries

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Candle color of the last completed bar on a given TF.
//   +1 bullish (close > open), -1 bearish (close < open), 0 doji/no-data.
// perf-allowed: single closed-bar CopyRates read per TF; no QM helper exposes
// raw candle color, and this is bounded structural logic gated to the H1 path.
int CandleColor(const ENUM_TIMEFRAMES tf)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, tf, 1, 1, rates); // perf-allowed: one closed bar
   if(copied != 1)
      return 0;
   if(rates[0].open <= 0.0 || rates[0].close <= 0.0)
      return 0;
   if(rates[0].close > rates[0].open)
      return 1;
   if(rates[0].close < rates[0].open)
      return -1;
   return 0;
  }

double ClosedBarClose(const ENUM_TIMEFRAMES tf)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, tf, 1, 1, rates); // perf-allowed: one closed bar
   if(copied != 1 || rates[0].close <= 0.0)
      return 0.0;
   return rates[0].close;
  }

bool HasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         return true;
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter: time, spread, news. News is delegated to Strategy_NewsFilterHook.
// Cheap O(1) per-tick gate. Spread guard fail-opens on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday broker time
         return true;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Convert the pip cap to a price distance (scale-correct on 5-digit / JPY).
   const double cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(cap_distance > 0.0 && spread > 0.0 && spread > cap_distance)
      return true;

   return false;
  }

// Trade Entry. Caller guarantees QM_IsNewBar() == true on H1 (closed-bar gate).
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

   if(HasOurPendingOrder())
      return false;

   // --- Alignment STATE: all 4 TFs same candle color (closed bars) ---
   const int col_a = CandleColor(strategy_tf_a);
   const int col_b = CandleColor(strategy_tf_b);
   const int col_c = CandleColor(strategy_tf_c);
   const int col_h1 = CandleColor(PERIOD_H1);
   if(col_a == 0 || col_b == 0 || col_c == 0 || col_h1 == 0)
      return false;
   if(!(col_a == col_b && col_b == col_c && col_c == col_h1))
      return false;
   const int align_dir = col_a; // +1 all bullish, -1 all bearish

   const double h1_close = ClosedBarClose(PERIOD_H1);
   if(h1_close <= 0.0)
      return false;

   const double trigger_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_trigger_pips);
   if(trigger_distance <= 0.0)
      return false;

   const QM_OrderType order_type = (align_dir > 0 ? QM_BUY_STOP : QM_SELL_STOP);
   const double entry = (align_dir > 0 ? h1_close + trigger_distance
                                       : h1_close - trigger_distance);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, order_type, entry, strategy_sl_pips);
   const double tp = QM_TakeFixedPips(_Symbol, order_type, entry, strategy_tp_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = order_type;
   req.price = QM_StopRulesNormalizePrice(_Symbol, entry);
   req.sl = sl;
   req.tp = tp;
   req.reason = (align_dir > 0 ? "mtf_align_buystop" : "mtf_align_sellstop");
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = strategy_expire_hours * 3600;
   return true;
  }

// Trade Management. Fixed SL/TP and pending-order expiration only.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close. No discretionary exit — positions close on the fixed SL/TP.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook. Defer to the central news filter.
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
