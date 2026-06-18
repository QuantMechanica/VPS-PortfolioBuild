#property strict
#property version   "5.0"
#property description "QM5_11424 williams-fakeout-day-stop-entry-d1 — Larry Williams Fake Out Day reversal, stop-entry (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11424 williams-fakeout-day-stop-entry-d1
// -----------------------------------------------------------------------------
// Source: Larry Williams, "Inner Circle Workshop Trading Method".
// Card: artifacts/cards_approved/QM5_11424_williams-fakeout-day-stop-entry-d1.md
//       (g0_status APPROVED).
//
// Mechanics (D1, deterministic OHLC geometry on CLOSED bars at shift 1 & 2):
//   A "Fake Out Day" is a failed range-expansion bar — the trap.
//
//   Bullish (reversal BUY) — signal bar[1] vs prior bar[2]:
//       High[1]  > High[2]   (new higher high — expanded up)
//       Low[1]   > Low[2]    (higher low)
//       Close[1] < Close[2]  (BUT closes weak vs prior close — failure)
//     Entry  : BUY_STOP at High[2] + 1 pip   (prior day's high, NOT signal high)
//     Stop   : Low[1] - 1 pip                (low of the fake-out bar)
//
//   Bearish (reversal SELL) — mirror:
//       Low[1]   < Low[2]    (new lower low — expanded down)
//       High[1]  < High[2]   (lower high)
//       Close[1] > Close[2]  (closes strong vs prior close — failure)
//     Entry  : SELL_STOP at Low[2] - 1 pip
//     Stop   : High[1] + 1 pip
//
//   The pattern completion (signal bar close) is the single EVENT; the stop
//   order is placed at the open of the next bar[0] and EXPIRES at end of that
//   bar (day-only pending). TP = tp_rr * risk (entry->SL distance).
//
//   .DWX invariants honoured:
//     - Gapless-safe: entry/stop/risk reference prior-bar CLOSE/HIGH/LOW only;
//       no gap rule (open vs prior range) is required.
//     - Spread guard fails OPEN on zero modelled spread.
//     - No swap gate, no session/broker-time clock, no external feed.
//     - Pip buffers / SL cap via QM_StopRulesPipsToPriceDistance (scale-correct
//       on 5-digit FX and 3-digit JPY).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11424;
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
input int    strategy_entry_buffer_pips   = 1;      // buffer beyond prior bar H/L for the stop trigger
input int    strategy_stop_buffer_pips    = 1;      // buffer beyond signal-bar L/H for the protective stop
input int    strategy_min_signal_range_pips = 10;   // min signal-bar range (High[1]-Low[1]) to filter trivial signals
input int    strategy_sl_cap_pips         = 70;     // P2 cap on stop distance (entry->SL)
input double strategy_tp_rr               = 2.0;    // take-profit = tp_rr * risk distance
input double strategy_spread_cap_pips     = 25.0;   // skip a genuinely wide spread (fail-open on .DWX zero spread)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — pattern work is on the
// closed-bar entry path. Fail-OPEN on .DWX zero modelled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote — do not block on it

   const double spread = ask - bid;
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   // Only a genuinely wide spread blocks; zero/negative modelled spread passes.
   if(spread > 0.0 && cap > 0.0 && spread > cap)
      return true;

   return false;
  }

// Williams Fake Out Day reversal stop-entry. Caller guarantees
// QM_IsNewBar() == true (closed-bar gate) — so this runs once at the open of
// each new daily bar[0], evaluating the just-closed signal bar[1] vs bar[2].
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();

   // One working order per magic/symbol: skip if a position is already open
   // OR a pending stop order from a prior bar is still live (avoid stacking).
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;
   if(OrdersTotal() > 0)
     {
      for(int i = OrdersTotal() - 1; i >= 0; --i)
        {
         const ulong oticket = OrderGetTicket(i);
         if(oticket == 0)
            continue;
         if(!OrderSelect(oticket))
            continue;
         if((long)OrderGetInteger(ORDER_MAGIC) == (long)magic &&
            OrderGetString(ORDER_SYMBOL) == _Symbol)
            return false; // a pending order for this magic/symbol already exists
        }
     }

   // --- Closed-bar OHLC geometry (perf-allowed: bespoke structural pattern,
   //     bounded single-shift reads at shift 1 and 2; no framework reader covers
   //     raw OHLC candle comparison). ---
   const double high1  = iHigh(_Symbol,  _Period, 1); // perf-allowed
   const double low1   = iLow(_Symbol,   _Period, 1); // perf-allowed
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed
   const double high2  = iHigh(_Symbol,  _Period, 2); // perf-allowed
   const double low2   = iLow(_Symbol,   _Period, 2); // perf-allowed
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed
   if(high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 ||
      high2 <= 0.0 || low2 <= 0.0 || close2 <= 0.0)
      return false;

   // --- Minimum signal-bar range filter (gapless-safe: own-bar range). ---
   const double min_range = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_min_signal_range_pips);
   if(min_range > 0.0 && (high1 - low1) < min_range)
      return false;

   const double entry_buf = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_entry_buffer_pips);
   const double stop_buf  = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_stop_buffer_pips);
   const double sl_cap    = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);

   // --- Bullish Fake Out Day (reversal BUY) ---
   const bool bullish_fakeout = (high1 > high2 && low1 > low2 && close1 < close2);
   // --- Bearish Fake Out Day (reversal SELL) ---
   const bool bearish_fakeout = (low1 < low2 && high1 < high2 && close1 > close2);

   QM_OrderType otype;
   double entry_price;
   double sl_price;
   if(bullish_fakeout)
     {
      entry_price = QM_StopRulesNormalizePrice(_Symbol, high2 + entry_buf); // prior day's high + buffer
      sl_price    = QM_StopRulesNormalizePrice(_Symbol, low1  - stop_buf);  // fake-out bar low - buffer
      otype       = QM_BUY_STOP;
     }
   else if(bearish_fakeout)
     {
      entry_price = QM_StopRulesNormalizePrice(_Symbol, low2  - entry_buf); // prior day's low - buffer
      sl_price    = QM_StopRulesNormalizePrice(_Symbol, high1 + stop_buf);  // fake-out bar high + buffer
      otype       = QM_SELL_STOP;
     }
   else
      return false;

   // Validate stop geometry vs entry and apply the P2 stop-distance cap.
   double risk_dist = MathAbs(entry_price - sl_price);
   if(risk_dist <= 0.0)
      return false;
   if(sl_cap > 0.0 && risk_dist > sl_cap)
     {
      // Cap the protective stop to sl_cap pips from the trigger price.
      if(otype == QM_BUY_STOP)
         sl_price = QM_StopRulesNormalizePrice(_Symbol, entry_price - sl_cap);
      else
         sl_price = QM_StopRulesNormalizePrice(_Symbol, entry_price + sl_cap);
      risk_dist = sl_cap;
     }

   // TP = tp_rr * risk distance from the trigger price.
   double tp_price;
   if(otype == QM_BUY_STOP)
      tp_price = QM_StopRulesNormalizePrice(_Symbol, entry_price + strategy_tp_rr * risk_dist);
   else
      tp_price = QM_StopRulesNormalizePrice(_Symbol, entry_price - strategy_tp_rr * risk_dist);

   // Day-only pending: expire near the end of this daily bar so an unfilled
   // order is cancelled (Williams "next day only"). One D1 bar = 86400s; use
   // a small margin under to ensure cancellation before the next bar opens.
   req.type               = otype;
   req.price              = entry_price;
   req.sl                 = sl_price;
   req.tp                 = tp_price;
   req.reason             = bullish_fakeout ? "fakeout_day_buy" : "fakeout_day_sell";
   req.expiration_seconds = 82800; // ~23h — cancels within the current D1 bar
   return true;
  }

// No active trade management — fixed protective stop + RR target carried by the
// pending order. (Williams' optional 3-bar trail is a P3 sweep variant.)
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the order's SL/TP.
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
