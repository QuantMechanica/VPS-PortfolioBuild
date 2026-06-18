#property strict
#property version   "5.0"
#property description "QM5_11697 pl-bb20-m5-scalp-d1trend — Langer BB(20) M5 pullback scalp, D1 trend bias"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11697 pl-bb20-m5-scalp-d1trend
// -----------------------------------------------------------------------------
// Source: Paul Langer, "A Scalping Strategy", in: The Black Book of Forex
//         Trading, Alura Publishing, 2015 (pp.64-70).
// Card: artifacts/cards_approved/QM5_11697_pl-bb20-m5-scalp-d1trend.md
//       (g0_status APPROVED). Sibling of QM5_11499 — same family, this card's
//       literal rules govern (pierce + reversal candle on the SAME M5 bar;
//       continuation entry in the D1-trend direction; ATR stop; 20-pip TP).
//
// Mechanics (closed-bar reads; M5 entries, D1 trend bias):
//   D1 BIAS STATE : daily close[1] vs SMA(200) on PERIOD_D1.
//                     close_d1 > sma200_d1  -> bullish bias (longs only)
//                     close_d1 < sma200_d1  -> bearish bias (shorts only)
//   BB pierce STATE + reversal EVENT (same just-closed M5 bar [1]):
//     long  : low[1]  <= BB_lower[1]   (price pierced/touched the lower band)
//             AND close[1] > open[1]   (bar closed bullish = continuation cue)
//     short : high[1] >= BB_upper[1]   (price pierced/touched the upper band)
//             AND close[1] < open[1]   (bar closed bearish)
//     A band TOUCH (a level test) and the bar's CLOSE DIRECTION are not two
//     cross EVENTS — they coexist naturally on a pierce-and-recover bar, so the
//     two-cross-same-bar zero-trade trap does not apply. The bullish/bearish
//     close is the single directional trigger; the touch is its qualifying
//     state.
//   Entry          : pending STOP just beyond the reversal bar's extreme, in the
//                    D1-trend (continuation) direction.
//                     long : BUY_STOP  at high[1] + buffer
//                     short: SELL_STOP at low[1]  - buffer
//                    pending order expires after `strategy_pending_expiry_bars`
//                    M5 bars (card: cancel if not triggered within 1 bar).
//   Stop loss      : `strategy_sl_atr_mult` * ATR(`strategy_atr_period`, M5)
//                    from the pending entry price (card factory default 2xATR).
//   Take profit    : fixed `strategy_tp_pips` from the pending entry price.
//   Break-even     : move SL to entry after `strategy_be_trigger_pips` in favour.
//
// .DWX invariants honoured:
//   * Spread guard fails OPEN on zero modeled spread (only a genuinely wide
//     spread blocks).
//   * FX CFDs are gapless (open[0]==close[1]); the reversal test uses the bar's
//     own open/close, not a gap against the prior range.
//   * No swap gating. Pip-scaled SL/TP via QM_* pip helpers (5-digit / JPY safe).
//   * RISK_FIXED in tester; framework sizes lots (no lots field on the request).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11697;
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
input int    strategy_bb_period           = 20;     // M5 Bollinger Band period
input double strategy_bb_deviation        = 2.0;    // M5 Bollinger Band deviation
input int    strategy_d1_sma_period       = 200;    // D1 trend-filter SMA period
input int    strategy_atr_period          = 14;     // M5 ATR period for the stop
input double strategy_sl_atr_mult         = 2.0;    // SL distance = mult * ATR (card default)
input int    strategy_tp_pips             = 20;     // fixed take-profit (pips)
input int    strategy_be_trigger_pips     = 10;     // move SL to BE after this many pips
input int    strategy_entry_buffer_pips   = 1;      // pending stop offset beyond bar extreme
input int    strategy_pending_expiry_bars = 1;      // pending order lifetime in M5 bars
input double strategy_spread_cap_pips     = 15.0;   // skip a genuinely wide spread (pips)

// -----------------------------------------------------------------------------
// Local helpers (framework-state reads only — no strategy indicator math here).
// -----------------------------------------------------------------------------

// Count this EA's working pending orders so we never stack a second STOP order
// while one is still live. Orders (not positions) are framework state; read the
// same way the framework reads PositionsTotal()/PositionGetTicket().
int QM_LocalPendingCount(const int magic)
  {
   int count = 0;
   const int total = OrdersTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(!OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      count++;
     }
   return count;
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

   const double spread     = ask - bid;
   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread_cap > 0.0 && spread > spread_cap)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed M5 bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();

   // One position per magic; and at most one live pending STOP at a time.
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;
   if(QM_LocalPendingCount(magic) > 0)
      return false;

   // --- D1 BIAS STATE: yesterday's D1 close vs D1 SMA(200) (closed bar) ---
   const double sma200_d1 = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 1);
   const double close_d1  = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: single closed-bar read
   if(sma200_d1 <= 0.0 || close_d1 <= 0.0)
      return false;

   const bool long_bias  = (close_d1 > sma200_d1);
   const bool short_bias = (close_d1 < sma200_d1);
   if(!long_bias && !short_bias)
      return false; // flat / exactly on the SMA — no bias

   // --- M5 Bollinger bands on the just-closed bar [1] (deviation arg MANDATORY) ---
   const double bb_upper1 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_lower1 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   if(bb_upper1 <= 0.0 || bb_lower1 <= 0.0)
      return false;

   // --- M5 pierce STATE + reversal EVENT on the just-closed bar [1] ---
   const double open1  = iOpen(_Symbol, _Period, 1);  // perf-allowed: single closed-bar reads
   const double close1 = iClose(_Symbol, _Period, 1);
   const double high1  = iHigh(_Symbol, _Period, 1);
   const double low1   = iLow(_Symbol, _Period, 1);
   if(open1 <= 0.0 || close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;

   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_entry_buffer_pips);

   QM_OrderType side;
   double entry_price = 0.0;

   if(long_bias)
     {
      // Pullback into the lower band + bullish close = continuation cue up.
      if(!(low1 <= bb_lower1))                 // price pierced/touched the lower band
         return false;
      if(!(close1 > open1))                    // bar closed bullish (reversal trigger)
         return false;
      side        = QM_BUY_STOP;
      entry_price = high1 + buffer;            // stop above the reversal bar's high
     }
   else
     {
      // Pullback into the upper band + bearish close = continuation cue down.
      if(!(high1 >= bb_upper1))                // price pierced/touched the upper band
         return false;
      if(!(close1 < open1))                    // bar closed bearish (reversal trigger)
         return false;
      side        = QM_SELL_STOP;
      entry_price = low1 - buffer;             // stop below the reversal bar's low
     }

   entry_price = QM_TM_NormalizePrice(_Symbol, entry_price);
   if(entry_price <= 0.0)
      return false;

   // --- Stop loss: factory default strategy_sl_atr_mult * ATR(period, M5) ---
   const double sl = QM_StopATR(_Symbol, side, entry_price, strategy_atr_period, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   // --- Take profit: fixed pips from the pending entry price ---
   const double tp = QM_TakeFixedPips(_Symbol, side, entry_price, strategy_tp_pips);
   if(tp <= 0.0)
      return false;

   req.type               = side;
   req.price              = entry_price;     // pending STOP price
   req.sl                 = sl;
   req.tp                 = tp;
   req.reason             = (side == QM_BUY_STOP) ? "langer_bb_pb_long" : "langer_bb_pb_short";
   req.expiration_seconds = strategy_pending_expiry_bars * PeriodSeconds(_Period);
   return true;
  }

// Break-even management: lock in once the trade has run far enough in favour.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_TM_MoveToBreakEven(ticket, strategy_be_trigger_pips, strategy_entry_buffer_pips);
     }
  }

// No discretionary exit beyond the fixed SL/TP and break-even shift.
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
