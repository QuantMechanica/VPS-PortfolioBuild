#property strict
#property version   "5.0"
#property description "QM5_1351 Frankfurt-Box First-Hour Breakout (M30)"

// Frankfurt-Box First-Hour Breakout (M30) — pre-London European momentum.
// Source: ForexFactory "Frankfort Breakout EA" thread/465064 community cluster.
//
// The "Box" is the M30 high/low range of the FIRST HOUR of the Frankfurt /
// Xetra cash-equity session (07:00-08:00 Frankfurt LOCAL time). Two M30 bars
// form the box. After the box window closes, the first M30 close OUTSIDE the
// box (above box_high => BUY, below box_low => SELL) is the single breakout
// TRIGGER EVENT. The box high/low are a per-day STATE; only the cross is the
// event. One direction per day (whipsaw guard). TP = 1.5 x box-width; SL just
// beyond the opposite box boundary (Box-counter-break is the structural fail
// signal); hard day-end flat at 17:00 broker-time; intraday time-stop.
//
// BROKER-TIME / DST DISCIPLINE (.DWX invariant #5, #13):
//   The box window is anchored to FRANKFURT LOCAL time, NOT a hardcoded server
//   offset. Each tick maps broker server time -> UTC via QM_BrokerToUTC()
//   (DXZ = NY-Close GMT+2 / GMT+3 during US DST, DST-aware in the framework),
//   then UTC -> Frankfurt local via the EU-DST rule (CET=UTC+1 winter,
//   CEST=UTC+2 summer; last-Sun-Mar .. last-Sun-Oct). The framework only ships
//   a US-DST helper, so EU DST is derived here. This keeps the box on the real
//   Frankfurt open across the 1-2 week windows where US and EU DST disagree.
//
// .DWX BACKTEST INVARIANTS honoured:
//   - Fail-OPEN spread guard (never blocks on the .DWX zero modelled spread;
//     only a genuinely WIDE positive spread blocks). Invariant #1.
//   - No swap gate. Invariant #2.
//   - QM_IsNewBar() consumed exactly ONCE per tick (framework OnTick). #3.
//   - ONE trigger event (the box-boundary cross). Box high/low + window-closed
//     + one-direction-per-day are STATES, not co-incident events. #4.
//   - Session window in BROKER->UTC->Frankfurt-local time, matched to the DAX
//     symbol's session. #5, #13.
//   - Box-width gate scales a multi-bar range to a multi-bar D1-ATR baseline. #7.
//   - Pip-correct thresholds via ATR price distances, never raw points. #14.
//   - RISK_FIXED sizing, one position per magic. HR4 / HR14.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1351;
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
// Box window in FRANKFURT LOCAL hours (24h). Card: first hour of the Frankfurt
// cash session = 07:00-08:00 local. The two M30 bars 07:00 and 07:30 form the
// box; the box "closes" at 08:00 local. Mapped to UTC/broker time internally.
input int    strategy_box_start_local_hour   = 7;    // Frankfurt-local box open hour
input int    strategy_box_start_local_minute = 0;    // Frankfurt-local box open minute
input int    strategy_box_end_local_hour     = 8;    // Frankfurt-local box close hour (exclusive)
input int    strategy_box_end_local_minute   = 0;    // Frankfurt-local box close minute
// Entry trading window in Frankfurt-local hours (post-box-close -> pre-NY).
// Card: broker 08:30-14:00 (out-DST) / 09:30-15:00 (in-DST). In Frankfurt-local
// terms that is a stable 07:30-13:00 window (box-close .. early NY).
input int    strategy_trade_start_local_hour = 8;    // entries allowed from (local), inclusive of box-close
input int    strategy_trade_start_local_minute = 0;  // entries allowed from local minute
input int    strategy_trade_end_local_hour   = 13;   // entries allowed until (local), exclusive
input int    strategy_trade_end_local_minute = 0;    // entries allowed until local minute
// Day-end mandatory flat, Frankfurt-local hour (card: 17:00 broker ~ 16:00 local).
input int    strategy_dayend_local_hour      = 16;   // flatten all at/after this local hour
input int    strategy_dayend_local_minute    = 0;    // flatten all at/after this local minute
input int    strategy_max_hold_bars          = 12;   // intraday time-stop: M30 bars (~6h)

input int    strategy_atr_m30_period         = 20;   // ATR(20,M30) for SL buffer + spread cap
input int    strategy_atr_d1_period          = 14;   // ATR(14,D1) for box-width gate baseline
input double strategy_box_width_min_atr_frac = 0.4;  // box width must exceed this * ATR(D1)
input double strategy_sl_atr_buffer_mult     = 0.2;  // SL sits opp-boundary -/+ this * ATR(M30)
input double strategy_sl_atr_cap_mult        = 2.0;  // cap initial-SL distance at this * ATR(M30)
input double strategy_tp_box_width_mult      = 1.5;  // TP = entry +/- this * box width
input double strategy_max_spread_atr_frac    = 0.4;  // fail-OPEN wide-spread cap (* ATR(M30))

input bool   strategy_use_macro_bias         = false; // optional EMA(200,H1) bias filter (P3 sweep)
input int    strategy_macro_ema_period       = 200;
input ENUM_TIMEFRAMES strategy_macro_ema_tf  = PERIOD_H1;

// -----------------------------------------------------------------------------
// File-scope per-trading-day state (advanced once per closed M30 bar).
// -----------------------------------------------------------------------------
int      g_box_day_key       = 0;      // Frankfurt-local YYYYMMDD the box belongs to
bool     g_box_ready         = false;  // box high/low computed for g_box_day_key
double   g_box_high          = 0.0;
double   g_box_low           = 0.0;
int      g_traded_day_key    = 0;      // day key on which a direction has been taken
int      g_traded_direction  = 0;      // 0 none, +1 up-break done, -1 down-break done
int      g_entry_bar_index   = 0;      // bar count since entry (time-stop)
bool     g_in_position       = false;

// =============================================================================
// EU DST: CEST (UTC+2) from last Sunday of March 01:00 UTC to last Sunday of
// October 01:00 UTC; CET (UTC+1) otherwise. Derived here because the framework
// ships only a US-DST helper.
// =============================================================================
datetime LastSundayUTC(const int year, const int month, const int hour_utc)
  {
   // Find the last day of `month`, walk back to Sunday.
   MqlDateTime dt;
   ZeroMemory(dt);
   dt.year = year;
   dt.mon  = month;
   dt.day  = 31;            // March and October both have 31 days
   dt.hour = hour_utc;
   dt.min  = 0;
   dt.sec  = 0;
   datetime t = StructToTime(dt);
   MqlDateTime back;
   ZeroMemory(back);
   TimeToStruct(t, back);
   // back.day_of_week: 0=Sunday .. 6=Saturday
   int dow = back.day_of_week;
   t -= dow * 24 * 3600;    // step back to the Sunday
   return t;
  }

bool IsEUDSTUTC(const datetime utc)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc, dt);
   datetime start_utc = LastSundayUTC(dt.year, 3, 1);   // 01:00 UTC last Sun Mar
   datetime end_utc   = LastSundayUTC(dt.year, 10, 1);  // 01:00 UTC last Sun Oct
   if(start_utc == 0 || end_utc == 0)
      return false;
   return (utc >= start_utc && utc < end_utc);
  }

// UTC -> Frankfurt local time (CET/CEST).
datetime UTCToFrankfurt(const datetime utc)
  {
   const int off = IsEUDSTUTC(utc) ? 2 : 1;
   return utc + off * 3600;
  }

// Frankfurt-local time for a broker (server) datetime, via UTC.
datetime BrokerToFrankfurt(const datetime broker_time)
  {
   return UTCToFrankfurt(QM_BrokerToUTC(broker_time));
  }

int FrankfurtDayKey(const datetime frankfurt_time)
  {
   MqlDateTime f;
   ZeroMemory(f);
   TimeToStruct(frankfurt_time, f);
   return f.year * 10000 + f.mon * 100 + f.day;
  }

int FrankfurtHour(const datetime frankfurt_time)
  {
   MqlDateTime f;
   ZeroMemory(f);
   TimeToStruct(frankfurt_time, f);
   return f.hour;
  }

int FrankfurtMinuteOfDay(const datetime frankfurt_time)
  {
   MqlDateTime f;
   ZeroMemory(f);
   TimeToStruct(frankfurt_time, f);
   return f.hour * 60 + f.min;
  }

int StrategyLocalMinuteOfDay(const int hour_value, const int minute_value)
  {
   const int hour = MathMax(0, MathMin(23, hour_value));
   const int minute = MathMax(0, MathMin(59, minute_value));
   return hour * 60 + minute;
  }

int MagicForThisEA() { return QM_FrameworkMagic(); }

bool HasOpenPosition()
  {
   const int magic = MagicForThisEA();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Box computation — runs once per closed M30 bar, immediately AFTER the box
// window has closed for the current Frankfurt-local day. Reads the two box M30
// bars by fixed shift (perf-allowed structural OHLC, post-new-bar gate).
// -----------------------------------------------------------------------------
void AdvanceBoxState_OnNewBar()
  {
   // Bar 1 = the just-closed M30 bar. We act when bar 1's CLOSE time has just
   // crossed the box-window end (i.e. bar 1 is the last box bar = the 07:30
   // bar, whose close == 08:00 local). Identify that by Frankfurt-local hour of
   // the just-closed bar's OPEN time.
   const datetime bar1_open_broker = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: fixed closed-bar open time, post QM_IsNewBar gate
   if(bar1_open_broker <= 0)
      return;

   const datetime bar1_open_ffx = BrokerToFrankfurt(bar1_open_broker);
   const int      bar1_minute   = FrankfurtMinuteOfDay(bar1_open_ffx);
   const int      day_key       = FrankfurtDayKey(bar1_open_ffx);
   const int      box_start     = StrategyLocalMinuteOfDay(strategy_box_start_local_hour,
                                                           strategy_box_start_local_minute);
   const int      box_end       = StrategyLocalMinuteOfDay(strategy_box_end_local_hour,
                                                           strategy_box_end_local_minute);

   // New Frankfurt-local day -> reset the per-day state (box + traded flag).
   if(day_key != g_box_day_key)
     {
      g_box_day_key   = day_key;
      g_box_ready     = false;
      g_box_high      = 0.0;
      g_box_low       = 0.0;
      g_traded_day_key   = (g_traded_day_key == day_key) ? g_traded_day_key : 0;
      g_traded_direction = 0;
     }

   // Finalise once the just-closed M30 bar's close crosses box_end. Then scan
   // the closed M30 bars whose Frankfurt-local opens are inside [box_start, box_end).
   if(!g_box_ready && day_key == g_box_day_key)
     {
      const int period_minutes = PeriodSeconds((ENUM_TIMEFRAMES)_Period) / 60;
      const bool is_last_box_bar = (period_minutes > 0 &&
                                    bar1_minute < box_end &&
                                    (bar1_minute + period_minutes) >= box_end);
      if(is_last_box_bar)
        {
         double hi = -DBL_MAX;
         double lo = DBL_MAX;
         int bars_seen = 0;
         for(int shift = 1; shift <= 16; ++shift)
           {
            const datetime open_broker = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, shift); // perf-allowed: bounded box scan
            if(open_broker <= 0)
               break;
            const datetime open_ffx = BrokerToFrankfurt(open_broker);
            if(FrankfurtDayKey(open_ffx) != day_key)
               break;
            const int open_minute = FrankfurtMinuteOfDay(open_ffx);
            if(open_minute < box_start)
               break;
            if(open_minute >= box_start && open_minute < box_end)
              {
               const double h = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, shift); // perf-allowed: bounded box scan
               const double l = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);  // perf-allowed: bounded box scan
               if(h > 0.0 && l > 0.0)
                 {
                  hi = MathMax(hi, h);
                  lo = MathMin(lo, l);
                  bars_seen++;
                 }
              }
           }
         g_box_high  = hi;
         g_box_low   = lo;
         g_box_ready = (bars_seen >= 2 && g_box_high > 0.0 && g_box_low > 0.0 && g_box_high > g_box_low);
        }
     }
  }

// -----------------------------------------------------------------------------
// No Trade Filter — cheap O(1). Only the fail-OPEN wide-spread guard. The
// session / box / window / one-direction-per-day gates live in EntrySignal so
// they cannot suppress the time-based day-end exit.
// -----------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;
   // Fail-OPEN: zero modelled spread on .DWX must NOT block; only a genuinely
   // wide POSITIVE spread does. Scale the cap by ATR(M30) so it is symbol-agnostic.
   if(ask > bid)
     {
      const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_m30_period, 1);
      if(atr > 0.0 && (ask - bid) > (atr * strategy_max_spread_atr_frac))
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Entry — on a closed M30 bar, after the box has closed and inside the trading
// window. The breakout cross (close[0] crosses a box boundary) is the single
// TRIGGER EVENT. One direction per Frankfurt-local day.
// -----------------------------------------------------------------------------
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_box_ready)
      return false;
   if(HasOpenPosition())
      return false;

   const datetime now_ffx  = BrokerToFrankfurt(TimeCurrent());
   const int      day_key  = FrankfurtDayKey(now_ffx);
   const int      minute_ffx = FrankfurtMinuteOfDay(now_ffx);

   // Box must belong to TODAY (Frankfurt-local) — no carry-over to the next day.
   if(day_key != g_box_day_key)
      return false;

   // Entry trading window (Frankfurt-local, post box-close): [start, end).
   const int trade_start = StrategyLocalMinuteOfDay(strategy_trade_start_local_hour,
                                                    strategy_trade_start_local_minute);
   const int trade_end = StrategyLocalMinuteOfDay(strategy_trade_end_local_hour,
                                                  strategy_trade_end_local_minute);
   if(minute_ffx < trade_start || minute_ffx >= trade_end)
      return false;

   // One-direction-per-day whipsaw guard.
   if(g_traded_day_key == day_key && g_traded_direction != 0)
      return false;

   // Box-width meaningfulness gate: scale the box range against a D1-ATR
   // baseline (multi-bar range vs multi-bar baseline, .DWX invariant #7).
   const double box_width = g_box_high - g_box_low;
   if(box_width <= 0.0)
      return false;
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_d1_period, 1);
   if(atr_d1 > 0.0 && box_width < strategy_box_width_min_atr_frac * atr_d1)
      return false;

   // Breakout: the single trigger EVENT is the first M30 close outside the box.
   // close[1] = just-closed bar, close[2] = the prior closed bar.
   const double close_1 = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: fixed closed-bar close, post new-bar gate
   const double close_2 = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 2); // perf-allowed: fixed closed-bar close
   if(close_1 <= 0.0 || close_2 <= 0.0)
      return false;

   const bool break_up   = (close_1 > g_box_high && close_2 <= g_box_high);
   const bool break_down = (close_1 < g_box_low  && close_2 >= g_box_low);
   if(!break_up && !break_down)
      return false;

   const QM_OrderType side = break_up ? QM_BUY : QM_SELL;

   // Optional macro-bias filter (EMA(200,H1)); P3 sweep on/off.
   if(strategy_use_macro_bias)
     {
      const double ema = QM_EMA(_Symbol, strategy_macro_ema_tf, strategy_macro_ema_period, 1, PRICE_CLOSE);
      if(ema > 0.0)
        {
         if(side == QM_BUY  && !(close_1 > ema)) return false;
         if(side == QM_SELL && !(close_1 < ema)) return false;
        }
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;
   const double entry = (side == QM_BUY) ? ask : bid;

   const double atr_m30 = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_m30_period, 1);
   if(atr_m30 <= 0.0)
      return false;

   // Initial SL: just beyond the OPPOSITE box boundary (Box-counter-break is the
   // structural failure). BUY -> box_low - buffer; SELL -> box_high + buffer.
   double sl;
   if(side == QM_BUY)
      sl = g_box_low  - strategy_sl_atr_buffer_mult * atr_m30;
   else
      sl = g_box_high + strategy_sl_atr_buffer_mult * atr_m30;

   // Cap the initial-SL distance at sl_atr_cap_mult * ATR(M30).
   const double max_dist = strategy_sl_atr_cap_mult * atr_m30;
   if(side == QM_BUY)
     {
      const double cap_sl = entry - max_dist;
      if(sl < cap_sl) sl = cap_sl;          // do not allow an SL farther than the cap
     }
   else
     {
      const double cap_sl = entry + max_dist;
      if(sl > cap_sl) sl = cap_sl;
     }
   sl = QM_StopRulesNormalizePrice(_Symbol, sl);

   // TP = entry +/- tp_box_width_mult * box width.
   double tp;
   if(side == QM_BUY)
      tp = entry + strategy_tp_box_width_mult * box_width;
   else
      tp = entry - strategy_tp_box_width_mult * box_width;
   tp = QM_StopRulesNormalizePrice(_Symbol, tp);

   // Sanity: SL on the correct side of entry.
   if(side == QM_BUY && !(sl < entry)) return false;
   if(side == QM_SELL && !(sl > entry)) return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = break_up ? "FFXBOX_BREAK_UP" : "FFXBOX_BREAK_DOWN";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Latch one-direction-per-day + reset the time-stop bar counter.
   g_traded_day_key   = day_key;
   g_traded_direction = break_up ? 1 : -1;
   g_entry_bar_index  = 0;
   return true;
  }

// No trailing / BE / partial — fixed SL/TP plus the structural + time exits.
void Strategy_ManageOpenPosition() {}

// -----------------------------------------------------------------------------
// Exit — three discretionary exits beyond SL/TP, all STATE-driven:
//   1. Day-end mandatory flat at/after strategy_dayend_local_hour (no overnight).
//   2. Box-counter-break: BUY closes if close[1] < box_low (opposite boundary
//      breached); SELL mirror.
//   3. Intraday time-stop: strategy_max_hold_bars M30 bars without TP/SL.
// -----------------------------------------------------------------------------
bool Strategy_ExitSignal()
  {
   if(!HasOpenPosition())
      return false;

   const datetime now_ffx  = BrokerToFrankfurt(TimeCurrent());
   const int      minute_ffx = FrankfurtMinuteOfDay(now_ffx);

   // (1) Day-end mandatory flat.
   const int dayend = StrategyLocalMinuteOfDay(strategy_dayend_local_hour,
                                               strategy_dayend_local_minute);
   if(minute_ffx >= dayend)
      return true;

   // The remaining checks are per-closed-bar structural; only meaningful with a
   // valid box for the current day.
   if(g_box_ready)
     {
      const double close_1 = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: fixed closed-bar close
      if(close_1 > 0.0)
        {
         // (2) Box-counter-break: opposite boundary breached on a close basis.
         if(g_traded_direction > 0 && close_1 < g_box_low)
            return true;
         if(g_traded_direction < 0 && close_1 > g_box_high)
            return true;
        }
     }

   // (3) Intraday time-stop.
   if(g_entry_bar_index >= strategy_max_hold_bars)
      return true;

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

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

   g_box_day_key      = 0;
   g_box_ready        = false;
   g_box_high         = 0.0;
   g_box_low          = 0.0;
   g_traded_day_key   = 0;
   g_traded_direction = 0;
   g_entry_bar_index  = 0;
   g_in_position      = false;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1351\",\"strategy\":\"frankfurt-box-first-hour-breakout-m30\"}");
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

   // Per-tick: trade management (none for this EA).
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exits (day-end flat, counter-break, time-stop).
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

   // Per-closed-bar: single QM_IsNewBar consume gates ALL closed-bar work.
   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   // Advance the per-day box STATE on the new closed bar.
   AdvanceBoxState_OnNewBar();

   // Advance the open-position bar counter for the intraday time-stop.
   if(HasOpenPosition())
      g_entry_bar_index++;
   else
      g_entry_bar_index = 0;

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
