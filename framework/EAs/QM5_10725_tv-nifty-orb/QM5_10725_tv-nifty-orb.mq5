#property strict
#property version   "5.0"
#property description "QM5_10725 TradingView Nifty 1m ORB"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10725;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_or_bars                 = 5;
input int    strategy_atr_period              = 14;
input double strategy_buffer_atr_mult         = 0.05;
input double strategy_min_stop_atr_mult       = 0.25;
input double strategy_max_stop_atr_mult       = 2.5;
input int    strategy_ema_trail_period        = 20;
input double strategy_rr_target               = 2.0;
input double strategy_partial_close_fraction  = 0.50;
input int    strategy_session_start_override  = -1;
input int    strategy_session_end_override    = -1;
input double strategy_max_spread_points       = 0.0;

int    g_strategy_session_key       = 0;
bool   g_strategy_or_has_range      = false;
bool   g_strategy_or_ready          = false;
bool   g_strategy_long_taken        = false;
bool   g_strategy_short_taken       = false;
double g_strategy_or_high           = 0.0;
double g_strategy_or_low            = 0.0;
datetime g_strategy_or_locked_at    = 0;

int Strategy_HhmmToMinutes(const int hhmm)
  {
   const int hh = hhmm / 100;
   const int mm = hhmm % 100;
   if(hh < 0 || hh > 23 || mm < 0 || mm > 59)
      return -1;
   return hh * 60 + mm;
  }

int Strategy_HhmmFromTime(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool Strategy_TimeInWindow(const int hhmm, const int start_hhmm, const int end_hhmm)
  {
   const int now_m = Strategy_HhmmToMinutes(hhmm);
   const int start_m = Strategy_HhmmToMinutes(start_hhmm);
   const int end_m = Strategy_HhmmToMinutes(end_hhmm);
   if(now_m < 0 || start_m < 0 || end_m < 0 || start_m == end_m)
      return false;
   if(start_m < end_m)
      return (now_m >= start_m && now_m < end_m);
   return (now_m >= start_m || now_m < end_m);
  }

bool Strategy_IsUSIndex()
  {
   return (StringFind(_Symbol, "NDX") >= 0 ||
           StringFind(_Symbol, "WS30") >= 0 ||
           StringFind(_Symbol, "SP500") >= 0);
  }

int Strategy_SessionStartHhmm()
  {
   if(strategy_session_start_override >= 0)
      return strategy_session_start_override;
   return Strategy_IsUSIndex() ? 1630 : 1000;
  }

int Strategy_SessionEndHhmm()
  {
   if(strategy_session_end_override >= 0)
      return strategy_session_end_override;
   return Strategy_IsUSIndex() ? 2300 : 1830;
  }

int Strategy_MinutesFromSessionStart(const int hhmm)
  {
   const int now_m = Strategy_HhmmToMinutes(hhmm);
   const int start_m = Strategy_HhmmToMinutes(Strategy_SessionStartHhmm());
   if(now_m < 0 || start_m < 0)
      return -1;
   int delta = now_m - start_m;
   if(delta < 0)
      delta += 1440;
   return delta;
  }

datetime Strategy_SessionStartTime(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   const int start_hhmm = Strategy_SessionStartHhmm();
   dt.hour = start_hhmm / 100;
   dt.min = start_hhmm % 100;
   dt.sec = 0;
   return StructToTime(dt);
  }

datetime Strategy_SessionEndTime(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   const int end_hhmm = Strategy_SessionEndHhmm();
   dt.hour = end_hhmm / 100;
   dt.min = end_hhmm % 100;
   dt.sec = 0;

   datetime end_time = StructToTime(dt);
   if(Strategy_HhmmToMinutes(end_hhmm) <= Strategy_HhmmToMinutes(Strategy_SessionStartHhmm()) &&
      end_time <= t)
      end_time += 86400;
   return end_time;
  }

int Strategy_SecondsUntilSessionEnd(const datetime t)
  {
   return MathMax(60, (int)(Strategy_SessionEndTime(t) - t));
  }

void Strategy_ResetSession(const int day_key)
  {
   g_strategy_session_key = day_key;
   g_strategy_or_has_range = false;
   g_strategy_or_ready = false;
   g_strategy_long_taken = false;
   g_strategy_short_taken = false;
   g_strategy_or_high = 0.0;
   g_strategy_or_low = 0.0;
   g_strategy_or_locked_at = 0;
  }

void Strategy_ResetSessionIfNeeded(const datetime t)
  {
   const int day_key = Strategy_DayKey(t);
   if(day_key != g_strategy_session_key)
      Strategy_ResetSession(day_key);
  }

bool Strategy_SpreadAllowed()
  {
   if(strategy_max_spread_points <= 0.0)
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;

   return ((ask - bid) / point) <= strategy_max_spread_points;
  }

bool Strategy_HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_IsOurStopOrderType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
  }

int Strategy_OurPendingStopCount()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(Strategy_IsOurStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         ++count;
     }
   return count;
  }

void Strategy_DeleteOurPendingStops(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!Strategy_IsOurStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

void Strategy_AdvanceOpeningRange(const MqlRates &bar)
  {
   Strategy_ResetSessionIfNeeded(bar.time);

   const int hhmm = Strategy_HhmmFromTime(bar.time);
   const int elapsed = Strategy_MinutesFromSessionStart(hhmm);
   const int or_bars = MathMax(1, MathMin(60, strategy_or_bars));
   const int bar_minutes = MathMax(1, PeriodSeconds((ENUM_TIMEFRAMES)_Period) / 60);
   if(elapsed < 0)
      return;

   if(elapsed >= or_bars)
     {
      if(!g_strategy_or_has_range)
        {
         const datetime range_start = Strategy_SessionStartTime(bar.time);
         const datetime range_end = range_start + or_bars * 60 - 1;
         MqlRates range_bars[];
         const int copied = CopyRates(_Symbol, PERIOD_M1, range_start, range_end, range_bars); // perf-allowed: at most five M1 OR bars, called after QM_IsNewBar().
         if(copied < or_bars)
            return;

         for(int i = 0; i < copied; ++i)
           {
            if(!g_strategy_or_has_range)
              {
               g_strategy_or_high = range_bars[i].high;
               g_strategy_or_low = range_bars[i].low;
               g_strategy_or_has_range = true;
              }
            else
              {
               g_strategy_or_high = MathMax(g_strategy_or_high, range_bars[i].high);
               g_strategy_or_low = MathMin(g_strategy_or_low, range_bars[i].low);
              }
           }
        }

      if(g_strategy_or_has_range && !g_strategy_or_ready)
        {
         g_strategy_or_ready = true;
         g_strategy_or_locked_at = Strategy_SessionStartTime(bar.time) + or_bars * 60;
        }
      return;
     }

   if(!Strategy_TimeInWindow(hhmm, Strategy_SessionStartHhmm(), Strategy_SessionEndHhmm()))
      return;

   if(!g_strategy_or_has_range)
     {
      g_strategy_or_high = bar.high;
      g_strategy_or_low = bar.low;
      g_strategy_or_has_range = true;
     }
   else
     {
      g_strategy_or_high = MathMax(g_strategy_or_high, bar.high);
      g_strategy_or_low = MathMin(g_strategy_or_low, bar.low);
     }

   if(elapsed + bar_minutes >= or_bars)
     {
      g_strategy_or_ready = true;
      g_strategy_or_locked_at = bar.time + bar_minutes * 60;
     }
  }

void Strategy_InitEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_GetOurPosition(ulong &ticket,
                             ENUM_POSITION_TYPE &position_type,
                             double &open_price,
                             double &current_sl,
                             double &current_tp,
                             double &volume)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   current_sl = 0.0;
   current_tp = 0.0;
   volume = 0.0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = t;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      current_sl = PositionGetDouble(POSITION_SL);
      current_tp = PositionGetDouble(POSITION_TP);
      volume = PositionGetDouble(POSITION_VOLUME);
      return true;
     }
   return false;
  }

bool Strategy_StopDistanceAllowed(const double entry, const double sl, const double atr)
  {
   if(entry <= 0.0 || sl <= 0.0 || atr <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry - sl);
   if(stop_distance < strategy_min_stop_atr_mult * atr)
      return false;
   if(stop_distance > strategy_max_stop_atr_mult * atr)
      return false;
   return true;
  }

double Strategy_StructureStop(const bool want_long, const MqlRates &bars[])
  {
   if(want_long)
     {
      double sl = g_strategy_or_low;
      for(int i = 0; i < 3; ++i)
         sl = MathMin(sl, bars[i].low);
      return sl;
     }

   double sl = g_strategy_or_high;
   for(int i = 0; i < 3; ++i)
      sl = MathMax(sl, bars[i].high);
   return sl;
  }

bool Strategy_BuildBreakoutRequest(const bool want_long,
                                   const bool pending_stop,
                                   const MqlRates &bars[],
                                   const double atr,
                                   QM_EntryRequest &req)
  {
   const double buffer = atr * MathMax(0.0, strategy_buffer_atr_mult);
   const double trigger = want_long ? (g_strategy_or_high + buffer) : (g_strategy_or_low - buffer);
   if(want_long && g_strategy_long_taken)
      return false;
   if(!want_long && g_strategy_short_taken)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double entry = pending_stop ? trigger : (want_long ? ask : bid);
   if(entry <= 0.0)
      return false;

   if(pending_stop)
     {
      const int stop_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double min_gap = MathMax(0, stop_level) * point;
      if(want_long && entry <= ask + min_gap)
         return false;
      if(!want_long && entry >= bid - min_gap)
         return false;
     }
   else
     {
      if(want_long && ask < trigger)
         return false;
      if(!want_long && bid > trigger)
         return false;
     }

   const double sl = Strategy_StructureStop(want_long, bars);
   if(want_long && sl >= entry)
      return false;
   if(!want_long && sl <= entry)
      return false;
   if(!Strategy_StopDistanceAllowed(entry, sl, atr))
      return false;

   const QM_OrderType side = pending_stop ? (want_long ? QM_BUY_STOP : QM_SELL_STOP)
                                          : (want_long ? QM_BUY : QM_SELL);
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, MathMax(0.1, strategy_rr_target));
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = pending_stop ? QM_StopRulesNormalizePrice(_Symbol, entry) : 0.0;
   req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, tp);
   req.reason = want_long ? "TV_NIFTY_ORB_LONG" : "TV_NIFTY_ORB_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = pending_stop ? Strategy_SecondsUntilSessionEnd(TimeCurrent()) : 0;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   Strategy_ResetSessionIfNeeded(TimeCurrent());

   if(Strategy_HasOurOpenPosition())
      return false;

   if((ENUM_TIMEFRAMES)_Period != PERIOD_M1)
      return true;

   if(!Strategy_SpreadAllowed())
      return true;

   const int hhmm = Strategy_HhmmFromTime(TimeCurrent());
   if(!Strategy_TimeInWindow(hhmm, Strategy_SessionStartHhmm(), Strategy_SessionEndHhmm()))
     {
      Strategy_DeleteOurPendingStops("session_end_no_position");
      return true;
     }

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitEntryRequest(req);

   if((ENUM_TIMEFRAMES)_Period != PERIOD_M1)
      return false;

   MqlRates bars[6];
   if(CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 6, bars) != 6) // perf-allowed: six closed M1 bars for ORB state and stop structure, called after QM_IsNewBar().
      return false;

   Strategy_AdvanceOpeningRange(bars[0]);

   if(Strategy_HasOurOpenPosition())
      return false;
   if(Strategy_OurPendingStopCount() > 0)
      return false;
   if(!g_strategy_or_has_range || !g_strategy_or_ready || g_strategy_or_high <= g_strategy_or_low)
      return false;
   if(bars[0].time < g_strategy_or_locked_at)
      return false;

   const int hhmm = Strategy_HhmmFromTime(bars[0].time);
   if(!Strategy_TimeInWindow(hhmm, Strategy_SessionStartHhmm(), Strategy_SessionEndHhmm()))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_M1, MathMax(1, strategy_atr_period), 1);
   if(atr <= 0.0)
      return false;

   if(Strategy_BuildBreakoutRequest(true, false, bars, atr, req))
      return true;

   if(Strategy_BuildBreakoutRequest(false, false, bars, atr, req))
      return true;

   QM_EntryRequest buy_req;
   Strategy_InitEntryRequest(buy_req);
   const bool have_buy = Strategy_BuildBreakoutRequest(true, true, bars, atr, buy_req);

   QM_EntryRequest sell_req;
   Strategy_InitEntryRequest(sell_req);
   const bool have_sell = Strategy_BuildBreakoutRequest(false, true, bars, atr, sell_req);

   if(have_buy && have_sell)
     {
      ulong buy_ticket = 0;
      QM_TM_OpenPosition(buy_req, buy_ticket);
      req = sell_req;
      return true;
     }

   if(have_buy)
     {
      req = buy_req;
      return true;
     }

   if(have_sell)
     {
      req = sell_req;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price, current_sl, current_tp, volume;
   if(!Strategy_GetOurPosition(ticket, position_type, open_price, current_sl, current_tp, volume))
      return;

   Strategy_DeleteOurPendingStops("opposite_order_after_fill");
   if(position_type == POSITION_TYPE_BUY)
      g_strategy_long_taken = true;
   else
      g_strategy_short_taken = true;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(market <= 0.0 || open_price <= 0.0 || current_tp <= 0.0 || point <= 0.0)
      return;

   const double initial_risk = MathAbs(current_tp - open_price) / MathMax(0.1, strategy_rr_target);
   if(initial_risk <= 0.0)
      return;

   const double profit_distance = is_buy ? (market - open_price) : (open_price - market);
   if(profit_distance < initial_risk)
      return;

   const bool stop_at_breakeven = is_buy ? (current_sl >= open_price - point * 0.5)
                                         : (current_sl <= open_price + point * 0.5);
   if(!stop_at_breakeven)
     {
      const double close_fraction = MathMax(0.0, MathMin(1.0, strategy_partial_close_fraction));
      const double lots_to_close = QM_TM_NormalizeVolume(_Symbol, volume * close_fraction);
      if(lots_to_close > 0.0 && lots_to_close < volume)
         QM_TM_PartialClose(ticket, lots_to_close, QM_EXIT_PARTIAL);

      QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, open_price), "tv_nifty_orb_be_after_1r");
     }

   const double ema = QM_EMA(_Symbol, PERIOD_M1, MathMax(1, strategy_ema_trail_period), 1);
   if(ema <= 0.0)
      return;

   if((is_buy && market <= ema) || (!is_buy && market >= ema))
      QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOurOpenPosition())
      return false;

   const int hhmm = Strategy_HhmmFromTime(TimeCurrent());
   return !Strategy_TimeInWindow(hhmm, Strategy_SessionStartHhmm(), Strategy_SessionEndHhmm());
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
