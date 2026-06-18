#property strict
#property version   "5.0"
#property description "QM5_11020 The5ers Jacques London M15 Breakout (pending-stop bracket, broker-time London session)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11020 the5ers-london-bo
// -----------------------------------------------------------------------------
// Source: The5ers blog interview with Jacques S (london-breakout / session-breakout).
// Card: artifacts/cards_approved/QM5_11020_the5ers-london-bo.md (g0_status APPROVED).
//
// Mechanics (M15, one trade per symbol per day, one position per magic):
//   Pre-London RANGE : high/low of the M15 bars whose LONDON local time falls in
//                      [range_start_hhmm, range_end_hhmm) (default 06:00-07:00).
//   Range filter     : skip if range_height < range_min_atr_mult * ATR(M15,96)
//                      or range_height > range_max_atr_mult * ATR(M15,96).
//   Placement EVENT  : at/after place_hhmm (default 07:00 London), once the range
//                      window has closed, place a BUY_STOP one tick above the range
//                      high and a SELL_STOP one tick below the range low. One bracket
//                      per symbol per London day.
//   Opposite cancel  : when one side fills (a position opens), delete the unfilled
//                      pending order of the opposite side.
//   Unfilled cancel  : delete all unfilled bracket orders at/after cancel_hhmm
//                      (default 10:00 London).
//   Stop loss        : opposite side of the range +/- stop_buffer_atr_mult*ATR buffer.
//                      Skip if SL distance < min_stop_spread_mult * spread or
//                      > range_max_atr_mult * ATR(M15,96).
//   Take profit      : reward_r (default 2.0) R from the stop-order price.
//   Signal exit      : close any open position at/after signal_exit_hhmm (12:00 London).
//   EOD exit         : close any open position at/after eod_exit_hhmm (16:00 London).
//   Day-of-week      : trade Tue-Fri only by default (Monday optional via input).
//   Spread guard     : fail-OPEN on .DWX zero modeled spread; only a genuinely wide
//                      spread > spread_pct_of_range % of range height blocks placement.
//
// .DWX invariants honoured: London session derived from the bar TIMESTAMP in broker
// time via QM_BrokerToUTC then a self-derived UK-DST offset (last-Sun-Mar..last-Sun-Oct);
// no swap gate; spread guard fails open on zero spread; no external-macro CSV.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else is
// framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11020;
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
// All session HHMM values are LONDON LOCAL TIME (UK clock, DST-aware). The EA
// converts each bar's broker timestamp -> UTC -> London internally.
input int    strategy_range_start_hhmm   = 600;    // pre-London range window start (London)
input int    strategy_range_end_hhmm     = 700;    // pre-London range window end (exclusive, London)
input int    strategy_place_hhmm         = 700;    // place bracket at/after this London time
input int    strategy_cancel_hhmm        = 1000;   // cancel unfilled brackets at/after this London time
input int    strategy_signal_exit_hhmm   = 1200;   // close open position at/after this London time
input int    strategy_eod_exit_hhmm      = 1600;   // hard end-of-day close (London)
input int    strategy_atr_period         = 96;     // ATR(M15,96) for range/stop sizing
input double strategy_range_min_atr_mult = 0.4;    // skip if range height < this * ATR
input double strategy_range_max_atr_mult = 1.5;    // skip if range height > this * ATR (also stop cap)
input double strategy_stop_buffer_atr_mult = 0.1;  // SL buffer beyond opposite range side, in ATR
input double strategy_reward_r           = 2.0;    // take-profit R multiple
input int    strategy_breakout_ticks     = 1;      // stop-order offset beyond range edge, in ticks
input double strategy_min_stop_spread_mult = 3.0;  // skip if SL distance < this * current spread
input double strategy_spread_pct_of_range  = 20.0; // skip if spread > this % of range height
input bool   strategy_trade_monday       = false;  // card: Tue-Fri only; Monday optional

// -----------------------------------------------------------------------------
// London local-time conversion (broker timestamp -> UTC -> UK wall clock).
// UK DST: BST (UTC+1) from last Sunday of March 01:00 UTC to last Sunday of
// October 01:00 UTC; otherwise GMT (UTC+0). Derived here because the framework
// only provides US-DST helpers.
// -----------------------------------------------------------------------------
int Strategy_DaysInMonth(const int year, const int month)
  {
   if(month == 2)
     {
      const bool leap = ((year % 4) == 0 && (year % 100) != 0) || ((year % 400) == 0);
      return leap ? 29 : 28;
     }
   if(month == 4 || month == 6 || month == 9 || month == 11)
      return 30;
   return 31;
  }

int Strategy_LastSundayOfMonth(const int year, const int month)
  {
   const int days = Strategy_DaysInMonth(year, month);
   for(int day = days; day >= 1; --day)
     {
      MqlDateTime dt;
      ZeroMemory(dt);
      dt.year = year;
      dt.mon  = month;
      dt.day  = day;
      const datetime t = StructToTime(dt);
      MqlDateTime probe;
      ZeroMemory(probe);
      TimeToStruct(t, probe);
      if(probe.day_of_week == 0) // Sunday
         return day;
     }
   return -1;
  }

bool Strategy_IsUKDSTUTC(const datetime utc)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc, dt);

   const int start_day = Strategy_LastSundayOfMonth(dt.year, 3);
   const int end_day   = Strategy_LastSundayOfMonth(dt.year, 10);
   if(start_day < 0 || end_day < 0)
      return false;

   MqlDateTime sdt;
   ZeroMemory(sdt);
   sdt.year = dt.year; sdt.mon = 3;  sdt.day = start_day; sdt.hour = 1;
   const datetime start_utc = StructToTime(sdt);

   MqlDateTime edt;
   ZeroMemory(edt);
   edt.year = dt.year; edt.mon = 10; edt.day = end_day; edt.hour = 1;
   const datetime end_utc = StructToTime(edt);

   return (utc >= start_utc && utc < end_utc);
  }

datetime Strategy_BrokerToLondon(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   const int uk_offset_hours = Strategy_IsUKDSTUTC(utc) ? 1 : 0;
   return utc + uk_offset_hours * 3600;
  }

int Strategy_HhmmFromTime(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int Strategy_DayKeyFromTime(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int Strategy_LondonHhmmNow()
  {
   return Strategy_HhmmFromTime(Strategy_BrokerToLondon(TimeCurrent()));
  }

int Strategy_LondonDayKeyNow()
  {
   return Strategy_DayKeyFromTime(Strategy_BrokerToLondon(TimeCurrent()));
  }

// Monday=1 .. Sunday=0 in MqlDateTime.day_of_week. Card: trade Tue-Fri only,
// Monday optional via input.
bool Strategy_DayOfWeekAllowed(const datetime london_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(london_time, dt);
   const int dow = dt.day_of_week;
   if(dow == 0 || dow == 6) // Sun / Sat
      return false;
   if(dow == 1 && !strategy_trade_monday) // Monday gated off by default
      return false;
   return true; // Tue(2)-Fri(5) always; Mon(1) only if enabled
  }

// -----------------------------------------------------------------------------
// Pending-order / position bookkeeping (framework magic, this symbol only).
// -----------------------------------------------------------------------------
bool Strategy_IsOurStopOrderType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
  }

bool Strategy_HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
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

int Strategy_OurPendingStopCount()
  {
   const int magic = QM_FrameworkMagic();
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

bool Strategy_CurrentSpread(double &spread_price)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   spread_price = 0.0;
   if(ask <= 0.0 || bid <= 0.0)
      return false;        // no valid quote yet
   if(ask > bid)
      spread_price = ask - bid; // .DWX models this as 0.0 -> fail-open downstream
   return true;
  }

void Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

// One bracket per London day. Guards re-placement after a fill/cancel.
int g_placed_day_key = -1;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news): cheap O(1). Never blocks management of an
// existing position / pending bracket. Blocks new setup outside placement time and
// on a genuinely wide spread.
bool Strategy_NoTradeFilter()
  {
   if(Strategy_HasOurOpenPosition() || Strategy_OurPendingStopCount() > 0)
      return false; // let management/exit/cancel logic run

   const datetime london_now = Strategy_BrokerToLondon(TimeCurrent());
   if(!Strategy_DayOfWeekAllowed(london_now))
      return true;

   const int hhmm = Strategy_HhmmFromTime(london_now);
   // Only allow the placement window: [place_hhmm, cancel_hhmm).
   if(hhmm < strategy_place_hhmm || hhmm >= strategy_cancel_hhmm)
      return true;

   return false;
  }

// Trade Entry: build the pre-London range from M15 bars in [range_start,range_end)
// London time, then place a BUY_STOP / SELL_STOP bracket one tick beyond the range.
// Caller guarantees QM_IsNewBar() == true (closed M15 bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);

   if(_Period != PERIOD_M15)
      return false;
   if(strategy_range_end_hhmm <= strategy_range_start_hhmm)
      return false;
   if(strategy_reward_r <= 0.0 || strategy_atr_period <= 0)
      return false;

   if(Strategy_HasOurOpenPosition() || Strategy_OurPendingStopCount() > 0)
      return false;

   // Evaluate on the just-closed M15 bar in London time.
   const datetime closed_bar_broker = iTime(_Symbol, PERIOD_M15, 1); // perf-allowed: bespoke session timestamp, gated by QM_IsNewBar()
   if(closed_bar_broker <= 0)
      return false;
   const datetime closed_bar_london = Strategy_BrokerToLondon(closed_bar_broker);

   if(!Strategy_DayOfWeekAllowed(closed_bar_london))
      return false;

   const int bar_hhmm  = Strategy_HhmmFromTime(closed_bar_london);
   const int day_key   = Strategy_DayKeyFromTime(closed_bar_london);

   // Only place once we are at/after the placement time and before the cancel cutoff,
   // and only one bracket per London day.
   if(bar_hhmm < strategy_place_hhmm || bar_hhmm >= strategy_cancel_hhmm)
      return false;
   if(g_placed_day_key == day_key)
      return false;

   // --- Build the pre-London range from this day's M15 bars in the window. ---
   // Scan back a bounded number of M15 bars (one trading day is < 96 bars; cap at
   // 200 to cover weekends/gaps). Gated by QM_IsNewBar in OnTick -> once per bar.
   double range_high = -DBL_MAX;
   double range_low  = DBL_MAX;
   int    range_bars = 0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int scan_bars = 200;
   const int copied = CopyRates(_Symbol, PERIOD_M15, 1, scan_bars, rates); // perf-allowed: once per closed bar
   if(copied <= 0)
      return false;

   for(int i = 0; i < copied; ++i)
     {
      const datetime bar_london = Strategy_BrokerToLondon(rates[i].time);
      if(Strategy_DayKeyFromTime(bar_london) != day_key)
         continue;
      const int hhmm = Strategy_HhmmFromTime(bar_london);
      if(hhmm < strategy_range_start_hhmm || hhmm >= strategy_range_end_hhmm)
         continue;
      if(rates[i].high > range_high)
         range_high = rates[i].high;
      if(rates[i].low < range_low)
         range_low = rates[i].low;
      ++range_bars;
     }

   if(range_bars <= 0 || range_high <= range_low || range_low <= 0.0)
      return false;

   const double range_height = range_high - range_low;

   // --- Volatility filter: range height inside [min,max] * ATR(M15, atr_period). ---
   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   if(range_height < strategy_range_min_atr_mult * atr)
      return false;
   if(range_height > strategy_range_max_atr_mult * atr)
      return false;

   // --- Spread guard (fail-OPEN on .DWX zero modeled spread). ---
   double spread_price = 0.0;
   if(!Strategy_CurrentSpread(spread_price))
      return false; // no valid quote
   // Only a genuinely wide (>0) spread blocks; zero modeled spread passes.
   if(spread_price > 0.0 && spread_price > (strategy_spread_pct_of_range / 100.0) * range_height)
      return false;

   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0)
      return false;
   const double breakout_offset = strategy_breakout_ticks * tick_size;
   const double stop_buffer     = strategy_stop_buffer_atr_mult * atr;

   const double buy_entry  = QM_TM_NormalizePrice(_Symbol, range_high + breakout_offset);
   const double sell_entry = QM_TM_NormalizePrice(_Symbol, range_low  - breakout_offset);
   if(buy_entry <= 0.0 || sell_entry <= 0.0 || buy_entry <= sell_entry)
      return false;

   // SL on the opposite side of the range +/- ATR buffer.
   const double buy_sl  = QM_TM_NormalizePrice(_Symbol, range_low  - stop_buffer);
   const double sell_sl = QM_TM_NormalizePrice(_Symbol, range_high + stop_buffer);
   if(buy_sl <= 0.0 || sell_sl <= 0.0)
      return false;
   if(buy_sl >= buy_entry || sell_sl <= sell_entry)
      return false;

   const double buy_stop_dist  = buy_entry - buy_sl;
   const double sell_stop_dist = sell_sl - sell_entry;
   if(buy_stop_dist <= 0.0 || sell_stop_dist <= 0.0)
      return false;

   // SL-distance filters: >= min_stop_spread_mult * spread (only when spread>0),
   // and <= range_max_atr_mult * ATR.
   const double min_stop_dist = (spread_price > 0.0) ? strategy_min_stop_spread_mult * spread_price : 0.0;
   const double max_stop_dist = strategy_range_max_atr_mult * atr;
   if(buy_stop_dist < min_stop_dist || buy_stop_dist > max_stop_dist)
      return false;
   if(sell_stop_dist < min_stop_dist || sell_stop_dist > max_stop_dist)
      return false;

   const double buy_tp  = QM_TM_NormalizePrice(_Symbol, buy_entry  + strategy_reward_r * buy_stop_dist);
   const double sell_tp = QM_TM_NormalizePrice(_Symbol, sell_entry - strategy_reward_r * sell_stop_dist);
   if(buy_tp <= buy_entry || sell_tp >= sell_entry || sell_tp <= 0.0)
      return false;

   // Pending orders expire at the cancel cutoff at the latest (broker GTC backstop;
   // Strategy_ManageOpenPosition also deletes them at strategy_cancel_hhmm).
   const int expiry_seconds = 4 * 3600; // ample; explicit cancel handles the cutoff

   // Place the BUY_STOP directly; return the SELL_STOP via req (OnTick sends it).
   QM_EntryRequest buy_req;
   Strategy_InitRequest(buy_req);
   buy_req.type   = QM_BUY_STOP;
   buy_req.price  = buy_entry;
   buy_req.sl     = buy_sl;
   buy_req.tp     = buy_tp;
   buy_req.reason = "LONDON_BO_BUY_STOP";
   buy_req.expiration_seconds = expiry_seconds;

   ulong buy_ticket = 0;
   if(!QM_TM_OpenPosition(buy_req, buy_ticket))
      return false;

   req.type   = QM_SELL_STOP;
   req.price  = sell_entry;
   req.sl     = sell_sl;
   req.tp     = sell_tp;
   req.reason = "LONDON_BO_SELL_STOP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = expiry_seconds;

   g_placed_day_key = day_key;
   return true;
  }

// Trade Management: cancel the opposite unfilled order once a side fills, and
// cancel all unfilled brackets at/after the cancel cutoff.
void Strategy_ManageOpenPosition()
  {
   if(Strategy_HasOurOpenPosition())
     {
      if(Strategy_OurPendingStopCount() > 0)
         Strategy_DeleteOurPendingStops("opposite_order_after_fill");
      return;
     }

   if(Strategy_OurPendingStopCount() > 0)
     {
      const int hhmm = Strategy_LondonHhmmNow();
      if(hhmm >= strategy_cancel_hhmm)
         Strategy_DeleteOurPendingStops("unfilled_cancel_cutoff");
     }
  }

// Trade Close: signal exit at signal_exit_hhmm; hard EOD close at eod_exit_hhmm
// (both London local time). The framework loop closes the position when this
// returns true.
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOurOpenPosition())
      return false;
   const int hhmm = Strategy_LondonHhmmNow();
   return (hhmm >= strategy_signal_exit_hhmm || hhmm >= strategy_eod_exit_hhmm);
  }

// News Filter Hook (callable for Q09 News Impact phase): defer to framework.
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

   // Per-tick: manage the bracket (opposite-cancel after fill, cutoff cancel).
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (signal-time / EOD close). Separate from SL/TP.
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
        }
     }

   // Per-closed-bar: bracket placement evaluation.
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
