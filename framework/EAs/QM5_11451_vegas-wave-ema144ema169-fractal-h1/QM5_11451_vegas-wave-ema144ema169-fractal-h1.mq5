#property strict
#property version   "5.0"
#property description "QM5_11451 vegas-wave-ema144ema169-fractal-h1 — Vegas Wave EMA144/169 tunnel STATE + Williams fractal breakout EVENT (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11451 vegas-wave-ema144ema169-fractal-h1
// -----------------------------------------------------------------------------
// Source: "Vegas Wave System" by Vegas Operator (Forex Factory community,
//         pseudonymous). source_id 5cb677f3-e06a-590b-a6b5-94a2d4bc9e81.
// Card: artifacts/cards_approved/QM5_11451_vegas-wave-ema144ema169-fractal-h1.md
//       (g0_status: APPROVED).
//
// Mechanics (H1, closed-bar reads at shift 1+):
//   Trend STATE  : the EMA(144)/EMA(169) "Vegas tunnel".
//                  BULLISH state = last closed bar Close[1] > EMA169[1]
//                                  AND EMA144[1] > EMA169[1] (stacked up).
//                  BEARISH state = last closed bar Close[1] < EMA144[1]
//                                  AND EMA144[1] < EMA169[1] (stacked down).
//   Pullback     : price must have recently pulled back toward the tunnel —
//                  LONG : some bar in the last `strategy_pullback_lookback`
//                         closed bars had Low <= EMA169 + pullback_pips.
//                  SHORT: some bar had High >= EMA144 - pullback_pips.
//   Entry EVENT  : a single Williams fractal that JUST confirmed this bar.
//                  A fractal centred at shift (side+1) is confirmed now (its
//                  `side` right-hand bars are shifts 1..side). Exactly ONE
//                  event per bar — never two crossings on the same bar
//                  (zero-trade trap, .DWX invariant #4).
//                  LONG  : an UP fractal (local HIGH) confirmed -> BUY STOP
//                          `entry_buffer_pips` above that fractal bar's HIGH.
//                  SHORT : a DOWN fractal (local LOW) confirmed -> SELL STOP
//                          `entry_buffer_pips` below that fractal bar's LOW.
//   Pending life : order expires after `strategy_pending_bars` H1 candles
//                  (framework ORDER_TIME_SPECIFIED via req.expiration_seconds).
//                  Card: cancel BUYSTOP if not filled within 24H -> 24 H1 bars.
//   Stop loss    : ATR(14)[1] * strategy_sl_atr_mult from the stop entry price
//                  (card's "prior fractal" proxy = entry -/+ ATR*1.5), capped
//                  at strategy_sl_max_pips (card P2 cap: 80 pips).
//   Take profit  : runner target = ATR(14)[1] * strategy_tp_atr_mult from the
//                  stop entry (card TP Lot2 = ATR*3.5; the runner). The card's
//                  two-lot split (TP1 @ ATR*2.0 + BE-after-TP1) is realised in
//                  the one-position-per-magic framework as: a single runner to
//                  TP2, with SL pulled to break-even once price has travelled
//                  strategy_be_atr_mult * ATR in favour (== the TP1 distance).
//                  See open_questions in build_result re the 2-lot collapse.
//   Session      : trade only inside [session_start, session_end) BROKER hours.
//                  Card states 07:00-18:00 GMT. .DWX invariant #5: sessions are
//                  matched in BROKER time (DXZ = NY-Close GMT+2/+3, DST-aware).
//                  Defaults below are the GMT window shifted +2 (standard time);
//                  the exact broker offset is set-file tunable per the matrix.
//   Spread guard : fail-OPEN on .DWX zero modeled spread; block only a
//                  genuinely wide spread > strategy_spread_cap_pips.
//
// One position per magic; one live pending order per magic at a time. Only the
// 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11451;
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
input int    strategy_ema_fast_period    = 144;   // Vegas tunnel fast EMA (BEARISH boundary)
input int    strategy_ema_slow_period    = 169;   // Vegas tunnel slow EMA (BULLISH boundary)
input int    strategy_fractal_side_bars  = 2;     // Williams fractal: bars on EACH side
input int    strategy_pullback_lookback  = 5;     // bars to scan for a tunnel pullback
input double strategy_pullback_pips      = 10.0;  // pullback proximity to the boundary (pips)
input int    strategy_atr_period         = 14;    // ATR period (SL / TP / BE distance)
input double strategy_sl_atr_mult        = 1.5;   // SL distance = mult * ATR (card prior-fractal proxy)
input double strategy_tp_atr_mult        = 3.5;   // TP distance = mult * ATR (card TP Lot2 runner)
input double strategy_be_atr_mult        = 2.0;   // move SL to BE after price moves mult*ATR (== card TP1)
input double strategy_entry_buffer_pips  = 1.0;   // stop trigger offset beyond the fractal extreme
input double strategy_sl_max_pips        = 80.0;  // P2 cap on the stop distance (card cap)
input int    strategy_pending_bars       = 24;    // cancel pending after N H1 candles (card: 24H)
input int    strategy_session_start_hr   = 7;     // GMT session open hour, inclusive (card: 07:00 GMT)
input int    strategy_session_end_hr     = 18;    // GMT session close hour, exclusive (card: 18:00 GMT)
input double strategy_spread_cap_pips    = 20.0;  // skip only a genuinely WIDE spread (card cap)

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

ulong g_vegas_partial_ticket = 0;

// Pip size for the current symbol (10 * point on 3/5-digit quotes, else point).
double Vegas_PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   return (digits == 3 || digits == 5) ? point * 10.0 : point;
  }

// Cheap O(1) wide-spread guard, fail-OPEN on .DWX zero modeled spread.
bool Vegas_WideSpread()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;                 // no valid quote — never block on it
   const double pip = Vegas_PipSize();
   if(pip <= 0.0)
      return false;
   const double spread = ask - bid;
   // Only a genuinely wide positive spread blocks; zero/negative passes.
   return (spread > 0.0 && spread > strategy_spread_cap_pips * pip);
  }

// Inside the trading session, in card GMT/UTC time (wrap-safe within a single day).
bool Vegas_InSession(const datetime broker_now)
  {
   const datetime utc_now = QM_BrokerToUTC(broker_now);
   MqlDateTime dt;
   TimeToStruct(utc_now, dt);
   const int h = dt.hour;
   if(strategy_session_start_hr <= strategy_session_end_hr)
      return (h >= strategy_session_start_hr && h < strategy_session_end_hr);
   // Wrapped window (e.g. 22..6): inside if before end OR at/after start.
   return (h >= strategy_session_start_hr || h < strategy_session_end_hr);
  }

// Count this EA's live PENDING orders (stop orders awaiting trigger).
int Vegas_PendingCount(const int magic)
  {
   int count = 0;
   const int total = OrdersTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) == magic)
         count++;
     }
   return count;
  }

bool Vegas_ValidFractalLevel(const double level)
  {
   return (level > 0.0 && level < DBL_MAX / 2.0);
  }

// True if any of the last `lookback` closed bars dipped within `pips` of the
// EMA169 boundary from above (LONG pullback into the tunnel). Bounded scan,
// closed bars only.
bool Vegas_PullbackLong(const double ema_slow, const double pips_dist, const int lookback)
  {
   for(int s = 1; s <= lookback; ++s)
     {
      const double low_s = iLow(_Symbol, _Period, s); // perf-allowed: bounded closed-bar scan
      if(low_s <= 0.0)
         continue;
      if(low_s <= ema_slow + pips_dist)
         return true;
     }
   return false;
  }

// True if any of the last `lookback` closed bars rallied within `pips` of the
// EMA144 boundary from below (SHORT pullback into the tunnel).
bool Vegas_PullbackShort(const double ema_fast, const double pips_dist, const int lookback)
  {
   for(int s = 1; s <= lookback; ++s)
     {
      const double high_s = iHigh(_Symbol, _Period, s); // perf-allowed: bounded closed-bar scan
      if(high_s <= 0.0)
         continue;
      if(high_s >= ema_fast - pips_dist)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: session window (broker time) + wide-spread guard.
bool Strategy_NoTradeFilter()
  {
   if(!Vegas_InSession(TimeCurrent()))
      return true;
   if(Vegas_WideSpread())
      return true;
   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// The Vegas tunnel stack is a STATE; the freshly-confirmed fractal is the
// single EVENT. Pullback proximity gates against chasing extended price.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   // One position per magic; and only one resting pending order at a time.
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;
   if(Vegas_PendingCount(magic) > 0)
      return false;

   const double pip = Vegas_PipSize();
   if(pip <= 0.0)
      return false;

   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1); // EMA144
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1); // EMA169
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // The fractal centre sits `side` bars back from the last closed bar so its
   // right-hand confirming bars (shifts 1..side) all exist => ONE event/bar.
   const int center_shift = strategy_fractal_side_bars + 1;
   const double upper_fractal = QM_FractalUpper(_Symbol, _Period, center_shift);
   const double lower_fractal = QM_FractalLower(_Symbol, _Period, center_shift);

   const double buffer       = strategy_entry_buffer_pips * pip;
   const double sl_cap       = strategy_sl_max_pips * pip;
   const double pullback_d   = strategy_pullback_pips * pip;
   const double sl_dist      = strategy_sl_atr_mult * atr_value;
   const double tp_dist      = strategy_tp_atr_mult * atr_value;

   // --- LONG: bullish tunnel stack + recent pullback + UP fractal confirmed ---
   if(close1 > ema_slow && ema_fast > ema_slow &&
      Vegas_PullbackLong(ema_slow, pullback_d, strategy_pullback_lookback) &&
      Vegas_ValidFractalLevel(upper_fractal))
     {
      const double entry = upper_fractal + buffer;      // BUY STOP trigger
      double sl_d = sl_dist;
      if(sl_d > sl_cap)                                 // cap stop distance
         sl_d = sl_cap;
      const double sl = entry - sl_d;                   // ATR-proxy stop below entry
      const double tp = entry + tp_dist;                // runner target (TP Lot2)
      if(!(sl < entry))
         return false;
      req.type   = QM_BUY_STOP;
      req.price  = QM_TM_NormalizePrice(_Symbol, entry);
      req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "vegas_long_buystop";
      req.expiration_seconds = strategy_pending_bars * PeriodSeconds(_Period);
      return true;
     }

   // --- SHORT: bearish tunnel stack + recent pullback + DOWN fractal confirmed ---
   if(close1 < ema_fast && ema_fast < ema_slow &&
      Vegas_PullbackShort(ema_fast, pullback_d, strategy_pullback_lookback) &&
      Vegas_ValidFractalLevel(lower_fractal))
     {
      const double entry = lower_fractal - buffer;      // SELL STOP trigger
      double sl_d = sl_dist;
      if(sl_d > sl_cap)
         sl_d = sl_cap;
      const double sl = entry + sl_d;                   // ATR-proxy stop above entry
      const double tp = entry - tp_dist;                // runner target (TP Lot2)
      if(!(sl > entry))
         return false;
      req.type   = QM_SELL_STOP;
      req.price  = QM_TM_NormalizePrice(_Symbol, entry);
      req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "vegas_short_sellstop";
      req.expiration_seconds = strategy_pending_bars * PeriodSeconds(_Period);
      return true;
     }

   return false;
  }

// Take 50% at the TP1 distance, then shift the runner to break-even.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return;
   const double pip = Vegas_PipSize();
   if(pip <= 0.0)
      return;

   // Trigger distance (ATR*mult) and a tiny 1-pip BE buffer, in pip units.
   const int trigger_pips = (int)MathRound((strategy_be_atr_mult * atr_value) / pip);
   if(trigger_pips <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market_price <= 0.0 || open_price <= 0.0)
         continue;
      const double moved = is_buy ? (market_price - open_price) : (open_price - market_price);
      const double be_buffer = QM_StopRulesPipsToPriceDistance(_Symbol, 1);
      const double be_sl = is_buy ? open_price + be_buffer : open_price - be_buffer;
      const bool be_already_set = (current_sl > 0.0) &&
                                  (is_buy ? (current_sl >= be_sl) : (current_sl <= be_sl));

      if(moved >= strategy_be_atr_mult * atr_value &&
         !be_already_set && g_vegas_partial_ticket != ticket && volume >= min_lot * 2.0)
        {
         const double partial_lots = QM_TM_NormalizeVolume(_Symbol, volume * 0.5);
         if(partial_lots >= min_lot && QM_TM_PartialClose(ticket, partial_lots, QM_EXIT_PARTIAL))
            g_vegas_partial_ticket = ticket;
        }

      QM_TM_MoveToBreakEven(ticket, trigger_pips, /*buffer_pips=*/1);
     }
  }

// No discretionary exit — exits are SL (ATR proxy) / TP (ATR runner) / break-even.
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
