#property strict
#property version   "5.0"
#property description "QM5_10686 TradingView 09:31 FVG Silver Bullet"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_10686  tv-fvg-0931
// TradingView `Strategi FVG 09:31 (Pro)` (author babyd7717) — mechanical port.
//
// Mechanic (M1 baseline):
//   * Evaluate only on closed 1-minute bars.
//   * At New York 09:32 ET, inspect the three M1 candles ending at the 09:31
//     close (the 09:29, 09:30, 09:31 ET candles).
//       first  candle = 09:29 ET (shift 3 at the 09:32 bar-open)
//       middle candle = 09:30 ET (shift 2)
//       third  candle = 09:31 ET (shift 1)
//   * Bullish FVG: low(first) > high(third). Zone = [high(third), low(first)].
//       -> BUY LIMIT at the UPPER boundary of the bullish FVG = low(first).
//   * Bearish FVG: high(first) < low(third). Zone = [high(first), low(third)].
//       -> SELL LIMIT at the LOWER boundary of the bearish FVG = high(first).
//   * Cancel the pending order if not filled within 15 M1 candles.
//   * Fixed-tick R: SL = 1.0R, TP = 2.0R from the limit entry price.
//   * One setup attempt per day per symbol; reset state at the next trading day.
//   * Skip if spread is more than 15% of the planned stop (fail-open on the
//     zero-spread .DWX tester).
//
// Broker / DST discipline (.DWX tester = NY-Close broker, GMT+2 std / GMT+3 US
// DST). The 09:31 ET anchor is matched by converting the FORMING bar's open
// time to UTC (QM_BrokerToUTC) then to NY ET wall-clock (ET = UTC-5 std /
// UTC-4 during US DST, via QM_IsUSDSTUTC). We key off iTime bar-open, NOT an
// exact tick-minute equality, so the new-bar tick arriving after :59 still
// matches the window.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10686;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// New York anchor: inspect the three M1 candles ending at the 09:31 ET close,
// evaluated on the 09:32 ET bar-open. Expressed in NY ET wall-clock so the
// DST conversion is handled internally.
input int    strategy_ny_entry_hour       = 9;     // NY ET hour of the eval bar-open
input int    strategy_ny_entry_minute     = 32;    // NY ET minute of the eval bar-open
// Fixed-tick R model.
input int    strategy_stop_pips           = 20;    // 1.0R stop distance (pips)
input double strategy_rr                  = 2.0;   // TP = strategy_rr * R
// Pending-order lifetime: cancel if unfilled within N M1 candles.
input int    strategy_order_expiry_bars   = 15;
// Spread gate: skip if spread > this fraction of the planned stop distance.
input double strategy_max_spread_stop_frac = 0.15;

// --- per-day single-attempt latch (ET date key YYYYMMDD; not a new-bar gate) ---
static int g_last_attempt_et_day = 0;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Convert a broker-time bar timestamp to a New York ET MqlDateTime struct.
// Broker -> UTC (DST-aware) -> NY ET wall-clock. US DST is the only DST that
// applies to both the broker offset and the ET offset, so they shift together.
void NYTimeFromBroker(const datetime broker_time, MqlDateTime &et_out)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   const int et_offset_hours = QM_IsUSDSTUTC(utc) ? -4 : -5; // EDT vs EST
   const datetime et = utc + (et_offset_hours * 3600);
   TimeToStruct(et, et_out);
  }

int ETDayKey(const MqlDateTime &dt)
  {
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

// True if this EA already has a live pending limit order on this symbol/magic.
bool HasOwnPendingOrder(const int magic)
  {
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong order_ticket = OrderGetTicket(i);
      if(order_ticket == 0 || !OrderSelect(order_ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot == ORDER_TYPE_BUY_LIMIT || ot == ORDER_TYPE_SELL_LIMIT)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Framework handles time/news/Friday; the card's spread gate is stop-relative
// and lives inside Strategy_EntrySignal.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Evaluated once per closed M1 bar (framework QM_IsNewBar gate). Arms a single
// FVG limit order per day at the New York 09:31 close.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_LIMIT;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   // The forming bar (shift 0) opens at the New York 09:32 ET minute; its
   // immediately-closed predecessor (shift 1) is the 09:31 ET candle.
   const datetime cur_open = iTime(_Symbol, PERIOD_M1, 0); // perf-allowed: bar-open window anchor
   if(cur_open <= 0)
      return false;

   MqlDateTime et;
   NYTimeFromBroker(cur_open, et);

   // Window match on bar-open (not exact tick-minute).
   if(et.hour != strategy_ny_entry_hour || et.min != strategy_ny_entry_minute)
      return false;

   // One setup attempt per ET day.
   const int day_key = ETDayKey(et);
   if(g_last_attempt_et_day == day_key)
      return false;
   g_last_attempt_et_day = day_key; // consume the daily attempt regardless of outcome

   // Only one live setup at a time.
   if(HasOwnPendingOrder(magic))
      return false;
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   // Three candles ending at the 09:31 close:
   //   first  = 09:29 ET = shift 3
   //   middle = 09:30 ET = shift 2  (not used directly; defines the gap context)
   //   third  = 09:31 ET = shift 1
   const double first_low   = iLow(_Symbol, PERIOD_M1, 3);   // perf-allowed: FVG 3-candle read
   const double first_high  = iHigh(_Symbol, PERIOD_M1, 3);  // perf-allowed
   const double third_low   = iLow(_Symbol, PERIOD_M1, 1);   // perf-allowed
   const double third_high  = iHigh(_Symbol, PERIOD_M1, 1);  // perf-allowed
   if(first_low <= 0.0 || first_high <= 0.0 || third_low <= 0.0 || third_high <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   // Fixed-tick R as a scale-correct price distance (pips -> price).
   const double stop_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_stop_pips);
   if(stop_dist <= 0.0)
      return false;

   // Spread gate — fail-open on zero-spread .DWX tester: only block a genuinely
   // wide modeled spread.
   const double spread = ask - bid;
   if(ask > bid && spread > strategy_max_spread_stop_frac * stop_dist)
      return false;

   const int bar_seconds   = PeriodSeconds(PERIOD_M1);
   const int expiry_seconds = MathMax(bar_seconds, strategy_order_expiry_bars * bar_seconds);

   // Bullish FVG: low(first) > high(third). Buy limit at the upper boundary
   // (= low of the first candle).
   if(first_low > third_high)
     {
      const double entry = NormalizeDouble(first_low, _Digits);
      // Limit must sit below current ask to be a valid buy-limit.
      if(entry > 0.0 && entry < ask - point)
        {
         const double sl = NormalizeDouble(entry - stop_dist, _Digits);
         const double tp = NormalizeDouble(entry + stop_dist * strategy_rr, _Digits);
         if(sl > 0.0 && sl < entry && tp > entry)
           {
            req.type = QM_BUY_LIMIT;
            req.price = entry;
            req.sl = sl;
            req.tp = tp;
            req.reason = "tv-fvg-0931-long";
            req.symbol_slot = qm_magic_slot_offset;
            req.expiration_seconds = expiry_seconds;
            return true;
           }
        }
     }

   // Bearish FVG: high(first) < low(third). Sell limit at the lower boundary
   // (= high of the first candle).
   if(first_high < third_low)
     {
      const double entry = NormalizeDouble(first_high, _Digits);
      // Limit must sit above current bid to be a valid sell-limit.
      if(entry > 0.0 && entry > bid + point)
        {
         const double sl = NormalizeDouble(entry + stop_dist, _Digits);
         const double tp = NormalizeDouble(entry - stop_dist * strategy_rr, _Digits);
         if(sl > entry && tp > 0.0 && tp < entry)
           {
            req.type = QM_SELL_LIMIT;
            req.price = entry;
            req.sl = sl;
            req.tp = tp;
            req.reason = "tv-fvg-0931-short";
            req.symbol_slot = qm_magic_slot_offset;
            req.expiration_seconds = expiry_seconds;
            return true;
           }
        }
     }

   return false;
  }

// Card specifies no trailing / break-even / partial close / pyramiding.
void Strategy_ManageOpenPosition()
  {
  }

// Daily reset: at the next trading day, cancel any still-pending FVG order from
// the prior session (the limit was not filled within its lifetime). SL/TP on a
// filled position are managed by the broker; no discretionary position exit.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const datetime cur_open = iTime(_Symbol, PERIOD_M1, 0); // perf-allowed: bar-open window anchor
   if(cur_open <= 0)
      return false;

   MqlDateTime et;
   NYTimeFromBroker(cur_open, et);
   const int day_key = ETDayKey(et);

   // New trading day rolled in relative to the last armed setup: drop any stale
   // pending limit so each session starts clean.
   if(g_last_attempt_et_day != 0 && day_key != g_last_attempt_et_day)
     {
      for(int i = OrdersTotal() - 1; i >= 0; --i)
        {
         const ulong order_ticket = OrderGetTicket(i);
         if(order_ticket == 0 || !OrderSelect(order_ticket))
            continue;
         if(OrderGetString(ORDER_SYMBOL) != _Symbol)
            continue;
         if((int)OrderGetInteger(ORDER_MAGIC) != magic)
            continue;
         const ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if(ot == ORDER_TYPE_BUY_LIMIT || ot == ORDER_TYPE_SELL_LIMIT)
            QM_TM_RemovePendingOrder(order_ticket, "tv-fvg-0931-daily-reset");
        }
     }

   // No discretionary close of an open position (fixed SL/TP only).
   return false;
  }

// No custom news overlay; defer to the framework two-axis news filter.
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
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
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
