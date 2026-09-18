// =============================================================================
// QM5_41476 Cash-open index mean reversion (session-flat, H1) — strategy module
// -----------------------------------------------------------------------------
// All H-MR strategy logic lives here; the .mq5 carries inputs, framework
// wiring, and the Design-2 panel glue only. Rules are the mechanized
// QM-RESEARCH-2026-0006 H_MR card (preregistration 8129b0fc...d2d):
//
//   * Session in UTC hours (inputs; broker time mapped via QM_DSTAware).
//   * Opening range = max high / min low of the first N session H1 bars.
//   * Long : closed H1 bar pierces below range low - buffer, closes back
//            INSIDE the range, and closes below the EMA (stretched down);
//            min reward:risk >= min_target_r at market price.  Short mirrored.
//   * One entry per symbol per day; max_positions_total across the EA family.
//   * Stop = failed extreme +/- atr_stop_mult * ATR; TP = range MIDPOINT.
//   * Time stop time_stop_bars H1 bars; mandatory flat at flatten_hour_utc.
//   * Filters: first-bar shock, spread vs 20-day median, high-impact news
//     blackout (fail-closed), daily/weekly circuit breakers, Friday cutoff.
//   * Optional break-even move at +1.0 ATR (never widens the stop).
//
// All heavy work is new-bar gated; per-tick paths are O(1).
// =============================================================================

// ---------------------------------------------------------------------------
// Session time helpers (UTC-anchored; DST handled by QM_DSTAware)
// ---------------------------------------------------------------------------

// Broker wall clock converted to a UTC MqlDateTime.
void HmrUtcStruct(const datetime broker_time, MqlDateTime &utc_dt)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   ZeroMemory(utc_dt);
   TimeToStruct(utc > 0 ? utc : broker_time, utc_dt);
  }

int HmrUtcDayKey(const MqlDateTime &utc_dt)
  {
   return utc_dt.year * 10000 + utc_dt.mon * 100 + utc_dt.day;
  }

// ---------------------------------------------------------------------------
// Mutable strategy state
// ---------------------------------------------------------------------------

int      g_hmr_slot              = -1;     // resolved symbol slot (== qm_magic_slot_offset)
int      g_hmr_day_key           = -1;     // UTC day key of the evaluated session
bool     g_hmr_shock_blocked     = false;  // first session bar range shock
bool     g_hmr_trade_taken_today = false;  // one entry per symbol per day
double   g_hmr_or_high           = 0.0;    // max high of the first N session bars
double   g_hmr_or_low            = 0.0;    // min low of the first N session bars
double   g_hmr_or_mid            = 0.0;    // opening-range midpoint (profit target)
bool     g_hmr_window_ready      = false;  // at least N session bars closed today

int      g_hmr_spread_day_key    = -1;
double   g_hmr_spread_today[];             // today's H1 spread samples (points)
double   g_hmr_daily_median[];             // rolling last-20 daily medians (points)
double   g_hmr_spread_median     = 0.0;    // median of daily medians (0 = none yet)

bool     g_hmr_breaker_day_hit   = false;
bool     g_hmr_breaker_week_hit  = false;

datetime g_hmr_news_cache_bucket = -1;
bool     g_hmr_news_cache_blocked= false;

ulong    g_hmr_active_ticket     = 0;
bool     g_hmr_be_done           = false;

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

bool HmrIsOurMagic(const long magic)
  {
   return magic >= (long)qm_ea_id * 10000 && magic < (long)(qm_ea_id + 1) * 10000;
  }

int HmrPortfolioPositionCount()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(!HmrIsOurMagic(PositionGetInteger(POSITION_MAGIC)))
         continue;
      count++;
     }
   return count;
  }

bool HmrSelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype, double &open_price, double &sl)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_price = 0.0;
   sl = 0.0;
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
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      return true;
     }
   return false;
  }

// ---------------------------------------------------------------------------
// Spread statistics: one sample per closed H1 bar, per-day median, rolling
// 20-day median of daily medians (card: spread vs 20-day median).
// ---------------------------------------------------------------------------

double HmrMedian(double &values[], const int n)
  {
   if(n <= 0)
      return 0.0;
   double tmp[];
   ArrayResize(tmp, n);
   for(int i = 0; i < n; ++i)
      tmp[i] = values[i];
   ArraySort(tmp);
   if((n & 1) == 1)
      return tmp[n / 2];
   return 0.5 * (tmp[n / 2 - 1] + tmp[n / 2]);
  }

// Called once per closed bar with the closed bar's broker time.
void HmrSpreadSample(const datetime closed_bar_time)
  {
   MqlDateTime utc;
   HmrUtcStruct(closed_bar_time, utc);
   const int day_key = HmrUtcDayKey(utc);

   if(day_key != g_hmr_spread_day_key)
     {
      // Finalize the previous day's median into the rolling window.
      const int n = ArraySize(g_hmr_spread_today);
      if(g_hmr_spread_day_key > 0 && n > 0)
        {
         const double med = HmrMedian(g_hmr_spread_today, n);
         const int m = ArraySize(g_hmr_daily_median);
         if(m >= 20)
            ArrayRemove(g_hmr_daily_median, 0, 1);
         ArrayResize(g_hmr_daily_median, ArraySize(g_hmr_daily_median) + 1);
         g_hmr_daily_median[ArraySize(g_hmr_daily_median) - 1] = med;
        }
      ArrayResize(g_hmr_spread_today, 0);
      g_hmr_spread_day_key = day_key;
     }

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;
   // Sample the CURRENT spread at the first tick of the new bar; .DWX zero
   // modeled spread samples as 0 and simply never blocks.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return;
   const int n = ArraySize(g_hmr_spread_today);
   ArrayResize(g_hmr_spread_today, n + 1);
   g_hmr_spread_today[n] = (ask - bid) / point;
  }

void HmrSpreadMedianRefresh()
  {
   const int m = ArraySize(g_hmr_daily_median);
   g_hmr_spread_median = (m > 0) ? HmrMedian(g_hmr_daily_median, m) : 0.0;
  }

bool HmrSpreadFilterBlocks()
  {
   const int days = ArraySize(g_hmr_daily_median);
   if(days < strategy_spread_min_days)
      return false; // warmup: not enough history to define a median yet
   HmrSpreadMedianRefresh();
   if(g_hmr_spread_median <= 0.0)
      return false; // zero modeled spread on .DWX can never exceed the cap
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;
   return ((ask - bid) / point) > strategy_spread_median_mult * g_hmr_spread_median;
  }

// ---------------------------------------------------------------------------
// Daily / weekly circuit breakers (strategy P&L = our deals + our floating).
// New-bar gated; the result is cached for the per-tick panel.
// ---------------------------------------------------------------------------

double HmrFamilyPnlSince(const datetime broker_from)
  {
   double pnl = 0.0;
   if(!HistorySelect(broker_from, TimeCurrent() + 60))
      return 0.0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      const ulong dt = HistoryDealGetTicket(i);
      if(dt == 0)
         continue;
      if(!HmrIsOurMagic(HistoryDealGetInteger(dt, DEAL_MAGIC)))
         continue;
      pnl += HistoryDealGetDouble(dt, DEAL_PROFIT)
           + HistoryDealGetDouble(dt, DEAL_SWAP)
           + HistoryDealGetDouble(dt, DEAL_COMMISSION);
     }
   // Add floating P&L of open family positions once.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(!HmrIsOurMagic(PositionGetInteger(POSITION_MAGIC)))
         continue;
      pnl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }
   return pnl;
  }

void HmrBreakersRefresh()
  {
   MqlDateTime utc;
   HmrUtcStruct(TimeCurrent(), utc);

   MqlDateTime day_start = utc;
   day_start.hour = 0; day_start.min = 0; day_start.sec = 0;
   const datetime day_start_broker = QM_UTCToBroker(StringToTime(StringFormat(
      "%04d.%02d.%02d %02d:%02d:%02d", day_start.year, day_start.mon, day_start.day,
      day_start.hour, day_start.min, day_start.sec)));

   const double day_pnl = HmrFamilyPnlSince(day_start_broker);
   double anchor = AccountInfoDouble(ACCOUNT_EQUITY) - day_pnl;
   if(anchor <= 0.0)
      anchor = AccountInfoDouble(ACCOUNT_BALANCE);
   g_hmr_breaker_day_hit = (anchor > 0.0 && day_pnl / anchor * 100.0 <= strategy_daily_stop_pct);

   // Week anchor: recompute from Monday 00:00 UTC.
   const int back = (utc.day_of_week + 6) % 7;
   MqlDateTime mon = utc;
   mon.hour = 0; mon.min = 0; mon.sec = 0;
   const datetime monday_utc = StringToTime(StringFormat(
      "%04d.%02d.%02d 00:00:00", mon.year, mon.mon, mon.day)) - back * 86400;
   const double week_pnl = HmrFamilyPnlSince(QM_UTCToBroker(monday_utc));
   anchor = AccountInfoDouble(ACCOUNT_EQUITY) - week_pnl;
   if(anchor <= 0.0)
      anchor = AccountInfoDouble(ACCOUNT_BALANCE);
   g_hmr_breaker_week_hit = (anchor > 0.0 && week_pnl / anchor * 100.0 <= strategy_weekly_stop_pct);
  }

// ---------------------------------------------------------------------------
// Session state (new-bar gated): day roll, shock filter, opening range.
// ---------------------------------------------------------------------------

// Recompute the opening range from today's closed session bars.
// Returns true when at least N session bars have closed today.
bool HmrBuildOpeningRange(const datetime closed_bar_time)
  {
   g_hmr_or_high = 0.0;
   g_hmr_or_low = 0.0;
   g_hmr_or_mid = 0.0;
   g_hmr_window_ready = false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H1, 0, 32, rates); // perf-allowed: one current-day H1 window, new-bar gated.
   if(copied < 1)
      return false;

   MqlDateTime utc;
   HmrUtcStruct(closed_bar_time, utc);
   const int today = HmrUtcDayKey(utc);

   int counted = 0;
   double hi = 0.0;
   double lo = 0.0;
   // Index 0 is the still-forming bar; the reference uses closed bars only.
   for(int i = copied - 1; i >= 1; --i)
     {
      MqlDateTime bar_utc;
      HmrUtcStruct(rates[i].time, bar_utc);
      if(HmrUtcDayKey(bar_utc) != today)
         continue;
      if(bar_utc.hour < strategy_session_start_hour_utc)
         continue;
      if(counted >= strategy_opening_range_bars)
         break;
      counted++;
      if(counted == 1 || rates[i].high > hi)
         hi = rates[i].high;
      if(counted == 1 || rates[i].low < lo)
         lo = rates[i].low;
     }

   if(counted < strategy_opening_range_bars || hi <= 0.0 || lo <= 0.0 || hi <= lo)
      return false;

   g_hmr_or_high = hi;
   g_hmr_or_low = lo;
   g_hmr_or_mid = 0.5 * (hi + lo);
   g_hmr_window_ready = true;
   return true;
  }

// Advance the session state for the newly closed bar (shift 1).
void HmrOnNewClosedBar()
  {
   const datetime closed_time = iTime(_Symbol, PERIOD_H1, 1);
   if(closed_time <= 0)
      return;

   HmrSpreadSample(closed_time);
   HmrBreakersRefresh();

   MqlDateTime utc;
   HmrUtcStruct(closed_time, utc);
   const int day_key = HmrUtcDayKey(utc);
   if(day_key != g_hmr_day_key)
     {
      g_hmr_day_key = day_key;
      g_hmr_shock_blocked = false;
      g_hmr_trade_taken_today = false;
      g_hmr_window_ready = false;
      g_hmr_or_high = 0.0;
      g_hmr_or_low = 0.0;
      g_hmr_or_mid = 0.0;
     }

   // Shock filter: first session bar's range vs ATR at its own close.
   if(utc.hour == strategy_session_start_hour_utc && !g_hmr_shock_blocked)
     {
      const int shift = iBarShift(_Symbol, PERIOD_H1, closed_time, false);
      const double range = iHigh(_Symbol, PERIOD_H1, shift) - iLow(_Symbol, PERIOD_H1, shift);
      const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, shift + 1);
      if(range > 0.0 && atr > 0.0 && range > strategy_shock_atr_mult * atr)
         g_hmr_shock_blocked = true;
     }

   HmrBuildOpeningRange(closed_time);
  }

// ---------------------------------------------------------------------------
// News blackout (card: high-impact events within news_blackout_minutes of the
// entry bar block the trade; fail-closed when the calendar is unavailable).
// Per-minute bucket cache; evaluated inside the new-bar entry path only.
// ---------------------------------------------------------------------------

bool HmrNewsBlackoutBlocks(const datetime broker_now)
  {
   if(strategy_news_blackout_minutes <= 0)
      return false;

   const datetime bucket = broker_now / 60;
   if(bucket == g_hmr_news_cache_bucket)
      return g_hmr_news_cache_blocked;

   g_hmr_news_cache_bucket = bucket;
   g_hmr_news_cache_blocked = false;

   // LIVE / real-time: the native MT5 economic calendar is the ONLY source
   // (Hard Rule: a live EA never reads the factory backtest archive). The
   // framework helper fails closed when the calendar is unreachable or
   // unpopulated (out_ok=false -> block). Impact threshold follows the
   // framework input qm_news_min_impact (default "high", card semantics).
   // Fix 2026-09-18 (Fable critic, blocking finding B-NEWS).
   if(MQLInfoInteger(MQL_TESTER) == 0 && MQLInfoInteger(MQL_OPTIMIZATION) == 0)
     {
      bool calendar_ok = false;
      const bool in_window = QM_NewsLiveInWindow(_Symbol, TimeTradeServer(),
                                                 strategy_news_blackout_minutes, 0,
                                                 calendar_ok);
      g_hmr_news_cache_blocked = (!calendar_ok) || in_window;
      return g_hmr_news_cache_blocked;
     }

   // Strategy Tester: deterministic factory archive (gate-validated path).
   if(!QM_NewsIsLoaded() &&
      !QM_NewsInit("D:\\QM\\data\\news_calendar",
                   qm_news_stale_max_hours,
                   30,
                   30,
                   qm_news_min_impact))
     {
      g_hmr_news_cache_blocked = true; // fail-closed
      return g_hmr_news_cache_blocked;
     }
   if(!QM_NewsIsAvailable())
     {
      g_hmr_news_cache_blocked = true; // fail-closed
      return g_hmr_news_cache_blocked;
     }

   datetime utc_time = QM_BrokerToUTC(broker_now);
   if(utc_time <= 0)
      utc_time = TimeGMT();
   g_hmr_news_cache_blocked = QM_NewsInWindow(utc_time, _Symbol,
                                              strategy_news_blackout_minutes, 0,
                                              "high");
   return g_hmr_news_cache_blocked;
  }

// ---------------------------------------------------------------------------
// Strategy hooks (called by the framework wiring in the .mq5)
// ---------------------------------------------------------------------------

// Static configuration guard only — cheap O(1), runs every tick. Session,
// breaker, and filter gates live in the new-bar entry path so that the
// mandatory-flat exit and break-even management can never be blocked here.
bool HmrNoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_H1)
      return true;
   if(g_hmr_slot < 0)
      return true;
   if(strategy_opening_range_bars < 2 || strategy_opening_range_bars > 4)
      return true;
   if(strategy_ema_period < 15 || strategy_ema_period > 30)
      return true;
   if(strategy_atr_period < 10 || strategy_atr_period > 20)
      return true;
   if(strategy_atr_stop_mult < 0.5 || strategy_atr_stop_mult > 1.5)
      return true;
   if(strategy_min_target_r < 0.4 || strategy_min_target_r > 0.8)
      return true;
   if(strategy_time_stop_bars < 4 || strategy_time_stop_bars > 8)
      return true;
   if(strategy_daily_stop_pct != -1.0 || strategy_weekly_stop_pct != -2.0)
      return true;
   if(strategy_shock_atr_mult < 2.5 || strategy_shock_atr_mult > 4.0)
      return true;
   if(strategy_spread_median_mult < 1.25 || strategy_spread_median_mult > 1.75)
      return true;
   if(strategy_session_start_hour_utc < 13 || strategy_session_start_hour_utc > 14 ||
      strategy_session_end_hour_utc < 16 || strategy_session_end_hour_utc > 17 ||
      strategy_flatten_hour_utc < 20 || strategy_flatten_hour_utc > 21 ||
      strategy_friday_cutoff_hour_utc < 17 || strategy_friday_cutoff_hour_utc > 18)
      return true;
   if(strategy_max_positions_total < 1 || strategy_max_positions_total > 3)
      return true;
   if(strategy_news_blackout_minutes < 0 || strategy_news_blackout_minutes > 120)
      return true;
   return false;
  }

// Entry on the closed H1 bar (shift 1). The framework guarantees a new bar.
bool HmrEntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   HmrOnNewClosedBar();

   // One entry per symbol per day.
   if(g_hmr_trade_taken_today)
      return false;

   // Session day must have its full opening range closed.
   if(!g_hmr_window_ready)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const datetime now = TimeCurrent();
   MqlDateTime utc;
   HmrUtcStruct(now, utc);

   // Entry window is evaluated on the CLOSED signal bar (shift 1): its UTC
   // hour must lie within [start + N, end] inclusive, i.e. strictly after the
   // opening range bars (a range bar cannot fail against its own reference).
   // Fix 2026-09-18 (Fable critic, blocking finding B-WINDOW): the forming
   // bar's hour was tested before, which made the last opening range bar dead
   // and silently dropped the session_end signal bar (binary != prereg pilot).
   // `now` keeps governing the Friday cutoff and the flatten proximity below.
   MqlDateTime sig;
   HmrUtcStruct(iTime(_Symbol, PERIOD_H1, 1), sig);
   if(sig.hour < strategy_session_start_hour_utc + strategy_opening_range_bars ||
      sig.hour > strategy_session_end_hour_utc)
      return false;

   // Friday cutoff for NEW entries.
   if(utc.day_of_week == 5 && utc.hour >= strategy_friday_cutoff_hour_utc)
      return false;

   // Flatten proximity: no fresh entry right at the mandatory-flat boundary.
   if(utc.hour >= strategy_flatten_hour_utc)
      return false;

   // Circuit breakers (cached this bar by HmrOnNewClosedBar).
   if(g_hmr_breaker_day_hit || g_hmr_breaker_week_hit)
      return false;

   // Shock filter.
   if(g_hmr_shock_blocked)
      return false;

   // Spread filter.
   if(HmrSpreadFilterBlocks())
      return false;

   // News blackout (fail-closed).
   if(HmrNewsBlackoutBlocks(now))
      return false;

   // Portfolio capacity across this EA's symbol slots.
   if(HmrPortfolioPositionCount() >= strategy_max_positions_total)
      return false;

   // Closed-bar reads (shift 1).
   const double high1 = iHigh(_Symbol, PERIOD_H1, 1);
   const double low1 = iLow(_Symbol, PERIOD_H1, 1);
   const double close1 = iClose(_Symbol, PERIOD_H1, 1);
   const double ema1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period, 1);
   const double atr1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || ema1 <= 0.0 || atr1 <= 0.0)
      return false;

   const double buffer = strategy_breakout_buffer_atr * atr1;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   // Failed breakdown (long): pierce below the range low, close back inside,
   // stretched below the EMA, midpoint reward pays min_target_r vs the stop.
   if(low1 < g_hmr_or_low - buffer && close1 > g_hmr_or_low && close1 < g_hmr_or_high &&
      close1 < ema1)
     {
      const double sl = NormalizeDouble(low1 - strategy_atr_stop_mult * atr1, _Digits);
      const double tp = NormalizeDouble(g_hmr_or_mid, _Digits);
      const double risk = ask - sl;
      const double reward = tp - ask;
      if(sl > 0.0 && sl < ask && tp > ask && risk >= point &&
         reward >= strategy_min_target_r * risk)
        {
         req.type = QM_BUY;
         req.price = 0.0;
         req.sl = sl;
         req.tp = tp;
         req.reason = "hmr_failed_breakdown_long";
         req.symbol_slot = qm_magic_slot_offset;
         req.expiration_seconds = 0;
         g_hmr_trade_taken_today = true;
         return true;
        }
     }

   // Failed breakout (short): pierce above the range high, close back inside,
   // stretched above the EMA, mirrored reward/risk eligibility.
   if(high1 > g_hmr_or_high + buffer && close1 < g_hmr_or_high && close1 > g_hmr_or_low &&
      close1 > ema1)
     {
      const double sl = NormalizeDouble(high1 + strategy_atr_stop_mult * atr1, _Digits);
      const double tp = NormalizeDouble(g_hmr_or_mid, _Digits);
      const double risk = sl - bid;
      const double reward = bid - tp;
      if(sl > bid && tp > 0.0 && tp < bid && risk >= point &&
         reward >= strategy_min_target_r * risk)
        {
         req.type = QM_SELL;
         req.price = 0.0;
         req.sl = sl;
         req.tp = tp;
         req.reason = "hmr_failed_breakout_short";
         req.symbol_slot = qm_magic_slot_offset;
         req.expiration_seconds = 0;
         g_hmr_trade_taken_today = true;
         return true;
        }
     }

   return false;
  }

// Per-tick management: optional break-even move at +1.0 ATR in favour.
// Bounded and finite — the stop is only ever tightened.
void HmrManageOpenPosition()
  {
   if(!strategy_breakeven_at_one_atr)
      return;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price, sl;
   if(!HmrSelectOurPosition(ticket, ptype, open_price, sl))
     {
      if(g_hmr_active_ticket != 0)
        {
         g_hmr_active_ticket = 0;
         g_hmr_be_done = false;
        }
      return;
     }
   if(ticket != g_hmr_active_ticket)
     {
      g_hmr_active_ticket = ticket;
      g_hmr_be_done = false;
     }
   if(g_hmr_be_done || open_price <= 0.0)
      return;

   // ATR cache: refreshed once per H1 bar (management is per-tick).
   const datetime bar0 = iTime(_Symbol, PERIOD_H1, 0);
   static datetime s_be_atr_bar = 0;
   static double s_be_atr = 0.0;
   if(bar0 != s_be_atr_bar)
     {
      s_be_atr_bar = bar0;
      s_be_atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
     }
   const double atr = s_be_atr;
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(atr <= 0.0 || bid <= 0.0 || ask <= 0.0)
      return;

   const bool is_long = (ptype == POSITION_TYPE_BUY);
   const double exit_price = is_long ? bid : ask;
   const double moved = is_long ? (exit_price - open_price) : (open_price - exit_price);
   if(moved < atr)
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double be = NormalizeDouble(open_price, _Digits);
   const bool improves = (sl <= 0.0) ||
                         (is_long ? (be > sl + point * 0.5) : (be < sl - point * 0.5));
   if(improves && QM_TM_MoveSL(ticket, be, "hmr_breakeven_one_atr"))
      g_hmr_be_done = true;
  }

// Per-tick discretionary exit: mandatory session-flat + time stop. Runs
// outside every blocking filter, so flatten can never be gated away.
bool HmrExitSignal()
  {
   MqlDateTime utc;
   HmrUtcStruct(TimeCurrent(), utc);

   // Mandatory flat at the flatten hour.
   if(utc.hour >= strategy_flatten_hour_utc)
      return true;

   // Time stop: full H1 bars elapsed since entry.
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
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && (int)((TimeCurrent() - opened) / PeriodSeconds(PERIOD_H1)) >= strategy_time_stop_bars)
         return true;
     }
   return false;
  }
