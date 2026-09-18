// =============================================================================
// QM5_41477 FX session mean reversion (session-flat, M15) — strategy module
// -----------------------------------------------------------------------------
// All H-FXMR strategy logic lives here; the .mq5 carries inputs, framework
// wiring, and the Design-2 panel glue only. Rules are the mechanized
// QM-RESEARCH-2026-0005 H_FXMR card (preregistration c408f534...7475):
//
//   * Two UTC session windows (London / New York, inputs; broker time mapped
//     via QM_DSTAware). Skip-first-minutes after each window open.
//   * Long : prior closed bar stretched down (>= stretch_bars consecutive
//     down-closes OR close more than stretch_atr_mult x ATR below its EMA)
//     and the just-closed bar closed back above the EMA (reclaim). Short
//     mirrored.
//   * Stop = stretch extreme of the last stretch_bars stretch bars +/-
//     stop_buffer_atr x ATR; skipped when wider than max_stop_atr x ATR.
//   * TP = target_r x stop distance. No trailing, no break-even (card).
//   * Time stop time_stop_bars M15 bars; mandatory flat at the window's flat
//     minute; lunch-gap and end-of-day flat backstops; Friday cutoff.
//   * Filters: per-window first-bar shock, spread vs 20-day median,
//     fail-closed high-impact news blackout, daily/weekly circuit breakers.
//   * Density: one entry per symbol per session window; max_trades_per_day
//     per symbol-day; max_positions_total across the EA family.
//
// All heavy work is new-bar gated; per-tick paths are O(1).
// =============================================================================

// ---------------------------------------------------------------------------
// Session time helpers (UTC-anchored; DST handled by QM_DSTAware)
// ---------------------------------------------------------------------------

// Broker wall clock converted to a UTC MqlDateTime.
void FxmrUtcStruct(const datetime broker_time, MqlDateTime &utc_dt)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   ZeroMemory(utc_dt);
   TimeToStruct(utc > 0 ? utc : broker_time, utc_dt);
  }

int FxmrUtcDayKey(const MqlDateTime &utc_dt)
  {
   return utc_dt.year * 10000 + utc_dt.mon * 100 + utc_dt.day;
  }

// Minute of the UTC day for a broker time.
int FxmrUtcMinuteOfDay(const datetime broker_time)
  {
   MqlDateTime utc;
   FxmrUtcStruct(broker_time, utc);
   return utc.hour * 60 + utc.min;
  }

// Session membership by minute-of-day. session: 0 = none, 1 = London, 2 = NY.
int FxmrSessionAtMinute(const int minute_of_day)
  {
   if(minute_of_day >= strategy_london_start_hour_utc * 60 &&
      minute_of_day < strategy_london_end_hour_utc * 60)
      return 1;
   if(minute_of_day >= strategy_ny_start_hour_utc * 60 &&
      minute_of_day < strategy_ny_end_hour_utc * 60)
      return 2;
   return 0;
  }

// ---------------------------------------------------------------------------
// Mutable strategy state
// ---------------------------------------------------------------------------

int      g_fxmr_slot                = -1;    // resolved symbol slot (== qm_magic_slot_offset)
int      g_fxmr_day_key             = -1;    // UTC day key of the evaluated session
int      g_fxmr_trades_today        = 0;     // entries taken this UTC day (per symbol)
bool     g_fxmr_traded_london_today = false; // one entry per symbol per window
bool     g_fxmr_traded_ny_today     = false;
bool     g_fxmr_shock_london        = false; // first-bar shock of today's London window
bool     g_fxmr_shock_ny            = false; // first-bar shock of today's NY window

double   g_fxmr_stretch_high        = 0.0;   // highest high of the stretch window
double   g_fxmr_stretch_low         = 0.0;   // lowest low of the stretch window
bool     g_fxmr_stretch_ready       = false; // stretch window fully available this bar

int      g_fxmr_spread_day_key      = -1;
double   g_fxmr_spread_today[];              // today's M15 spread samples (points)
double   g_fxmr_daily_median[];              // rolling last-20 daily medians (points)
double   g_fxmr_spread_median       = 0.0;   // median of daily medians (0 = none yet)

bool     g_fxmr_breaker_day_hit     = false;
bool     g_fxmr_breaker_week_hit    = false;

datetime g_fxmr_news_cache_bucket   = -1;
bool     g_fxmr_news_cache_blocked  = false;

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

bool FxmrIsOurMagic(const long magic)
  {
   return magic >= (long)qm_ea_id * 10000 && magic < (long)(qm_ea_id + 1) * 10000;
  }

int FxmrPortfolioPositionCount()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(!FxmrIsOurMagic(PositionGetInteger(POSITION_MAGIC)))
         continue;
      count++;
     }
   return count;
  }

bool FxmrSelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype, double &open_price, double &sl)
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
// Spread statistics: one sample per closed M15 bar, per-day median, rolling
// 20-day median of daily medians (card: spread vs 20-day median).
// ---------------------------------------------------------------------------

double FxmrMedian(double &values[], const int n)
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
void FxmrSpreadSample(const datetime closed_bar_time)
  {
   MqlDateTime utc;
   FxmrUtcStruct(closed_bar_time, utc);
   const int day_key = FxmrUtcDayKey(utc);

   if(day_key != g_fxmr_spread_day_key)
     {
      // Finalize the previous day's median into the rolling window.
      const int n = ArraySize(g_fxmr_spread_today);
      if(g_fxmr_spread_day_key > 0 && n > 0)
        {
         const double med = FxmrMedian(g_fxmr_spread_today, n);
         const int m = ArraySize(g_fxmr_daily_median);
         if(m >= 20)
            ArrayRemove(g_fxmr_daily_median, 0, 1);
         ArrayResize(g_fxmr_daily_median, ArraySize(g_fxmr_daily_median) + 1);
         g_fxmr_daily_median[ArraySize(g_fxmr_daily_median) - 1] = med;
        }
      ArrayResize(g_fxmr_spread_today, 0);
      g_fxmr_spread_day_key = day_key;
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
   const int n = ArraySize(g_fxmr_spread_today);
   ArrayResize(g_fxmr_spread_today, n + 1);
   g_fxmr_spread_today[n] = (ask - bid) / point;
  }

void FxmrSpreadMedianRefresh()
  {
   const int m = ArraySize(g_fxmr_daily_median);
   g_fxmr_spread_median = (m > 0) ? FxmrMedian(g_fxmr_daily_median, m) : 0.0;
  }

bool FxmrSpreadFilterBlocks()
  {
   const int days = ArraySize(g_fxmr_daily_median);
   if(days < strategy_spread_min_days)
      return false; // warmup: not enough history to define a median yet
   FxmrSpreadMedianRefresh();
   if(g_fxmr_spread_median <= 0.0)
      return false; // zero modeled spread on .DWX can never exceed the cap
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;
   return ((ask - bid) / point) > strategy_spread_median_mult * g_fxmr_spread_median;
  }

// ---------------------------------------------------------------------------
// Daily / weekly circuit breakers (strategy P&L = our deals + our floating).
// New-bar gated; the result is cached for the per-tick panel.
// ---------------------------------------------------------------------------

double FxmrFamilyPnlSince(const datetime broker_from)
  {
   double pnl = 0.0;
   if(!HistorySelect(broker_from, TimeCurrent() + 60))
      return 0.0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      const ulong dt = HistoryDealGetTicket(i);
      if(dt == 0)
         continue;
      if(!FxmrIsOurMagic(HistoryDealGetInteger(dt, DEAL_MAGIC)))
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
      if(!FxmrIsOurMagic(PositionGetInteger(POSITION_MAGIC)))
         continue;
      pnl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }
   return pnl;
  }

void FxmrBreakersRefresh()
  {
   MqlDateTime utc;
   FxmrUtcStruct(TimeCurrent(), utc);

   MqlDateTime day_start = utc;
   day_start.hour = 0; day_start.min = 0; day_start.sec = 0;
   const datetime day_start_broker = QM_UTCToBroker(StringToTime(StringFormat(
      "%04d.%02d.%02d %02d:%02d:%02d", day_start.year, day_start.mon, day_start.day,
      day_start.hour, day_start.min, day_start.sec)));

   const double day_pnl = FxmrFamilyPnlSince(day_start_broker);
   double anchor = AccountInfoDouble(ACCOUNT_EQUITY) - day_pnl;
   if(anchor <= 0.0)
      anchor = AccountInfoDouble(ACCOUNT_BALANCE);
   g_fxmr_breaker_day_hit = (anchor > 0.0 && day_pnl / anchor * 100.0 <= strategy_daily_stop_pct);

   // Week anchor: recompute from Monday 00:00 UTC.
   const int back = (utc.day_of_week + 6) % 7;
   MqlDateTime mon = utc;
   mon.hour = 0; mon.min = 0; mon.sec = 0;
   const datetime monday_utc = StringToTime(StringFormat(
      "%04d.%02d.%02d 00:00:00", mon.year, mon.mon, mon.day)) - back * 86400;
   const double week_pnl = FxmrFamilyPnlSince(QM_UTCToBroker(monday_utc));
   anchor = AccountInfoDouble(ACCOUNT_EQUITY) - week_pnl;
   if(anchor <= 0.0)
      anchor = AccountInfoDouble(ACCOUNT_BALANCE);
   g_fxmr_breaker_week_hit = (anchor > 0.0 && week_pnl / anchor * 100.0 <= strategy_weekly_stop_pct);
  }

// ---------------------------------------------------------------------------
// Stretch window: extreme of the last stretch_bars stretch bars (bars
// 2..stretch_bars+1, shift-1 anchored closed bars). Used for the stop and the
// panel's active range. Returns false when not enough bars exist yet.
// ---------------------------------------------------------------------------

bool FxmrBuildStretchWindow()
  {
   g_fxmr_stretch_high = 0.0;
   g_fxmr_stretch_low = 0.0;
   g_fxmr_stretch_ready = false;

   double hi = 0.0;
   double lo = 0.0;
   for(int i = 2; i <= strategy_stretch_bars + 1; ++i)
     {
      const double h = iHigh(_Symbol, PERIOD_M15, i);
      const double l = iLow(_Symbol, PERIOD_M15, i);
      if(h <= 0.0 || l <= 0.0)
         return false;
      if(i == 2 || h > hi)
         hi = h;
      if(i == 2 || l < lo)
         lo = l;
     }
   if(hi <= 0.0 || lo <= 0.0 || hi <= lo)
      return false;

   g_fxmr_stretch_high = hi;
   g_fxmr_stretch_low = lo;
   g_fxmr_stretch_ready = true;
   return true;
  }

// Count of consecutive down-closes (for a long reversion) ending at shift 2.
// A down-close at shift i means close[i] < close[i+1] (series indexing).
int FxmrDownCloseRun(const int max_lookback)
  {
   int run = 0;
   for(int i = 2; i < max_lookback; ++i)
     {
      const double c0 = iClose(_Symbol, PERIOD_M15, i);
      const double c1 = iClose(_Symbol, PERIOD_M15, i + 1);
      if(c0 <= 0.0 || c1 <= 0.0)
         break;
      if(c0 >= c1)
         break;
      run++;
     }
   return run;
  }

int FxmrUpCloseRun(const int max_lookback)
  {
   int run = 0;
   for(int i = 2; i < max_lookback; ++i)
     {
      const double c0 = iClose(_Symbol, PERIOD_M15, i);
      const double c1 = iClose(_Symbol, PERIOD_M15, i + 1);
      if(c0 <= 0.0 || c1 <= 0.0)
         break;
      if(c0 <= c1)
         break;
      run++;
     }
   return run;
  }

// ---------------------------------------------------------------------------
// Session state (new-bar gated): day roll, per-window shock filter.
// ---------------------------------------------------------------------------

void FxmrOnNewClosedBar()
  {
   const datetime closed_time = iTime(_Symbol, PERIOD_M15, 1);
   if(closed_time <= 0)
      return;

   FxmrSpreadSample(closed_time);
   FxmrBreakersRefresh();

   MqlDateTime utc;
   FxmrUtcStruct(closed_time, utc);
   const int day_key = FxmrUtcDayKey(utc);
   if(day_key != g_fxmr_day_key)
     {
      g_fxmr_day_key = day_key;
      g_fxmr_trades_today = 0;
      g_fxmr_traded_london_today = false;
      g_fxmr_traded_ny_today = false;
      g_fxmr_shock_london = false;
      g_fxmr_shock_ny = false;
      g_fxmr_stretch_ready = false;
      g_fxmr_stretch_high = 0.0;
      g_fxmr_stretch_low = 0.0;
     }

   // Shock filter: the window's first M15 bar range vs ATR at its own close.
   const int bar_min = utc.hour * 60 + utc.min;
   if(bar_min == strategy_london_start_hour_utc * 60 && !g_fxmr_shock_london)
     {
      const int shift = iBarShift(_Symbol, PERIOD_M15, closed_time, false);
      const double range = iHigh(_Symbol, PERIOD_M15, shift) - iLow(_Symbol, PERIOD_M15, shift);
      const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, shift + 1);
      if(range > 0.0 && atr > 0.0 && range > strategy_shock_atr_mult * atr)
         g_fxmr_shock_london = true;
     }
   if(bar_min == strategy_ny_start_hour_utc * 60 && !g_fxmr_shock_ny)
     {
      const int shift = iBarShift(_Symbol, PERIOD_M15, closed_time, false);
      const double range = iHigh(_Symbol, PERIOD_M15, shift) - iLow(_Symbol, PERIOD_M15, shift);
      const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, shift + 1);
      if(range > 0.0 && atr > 0.0 && range > strategy_shock_atr_mult * atr)
         g_fxmr_shock_ny = true;
     }

   FxmrBuildStretchWindow();
  }

// ---------------------------------------------------------------------------
// News blackout (card: high-impact events for the pair's currencies within
// news_blackout_minutes of the entry bar block the trade; fail-closed when
// the calendar is unavailable). Per-minute bucket cache; evaluated inside
// the new-bar entry path only.
// ---------------------------------------------------------------------------

bool FxmrNewsBlackoutBlocks(const datetime broker_now)
  {
   if(strategy_news_blackout_minutes <= 0)
      return false;

   const datetime bucket = broker_now / 60;
   if(bucket == g_fxmr_news_cache_bucket)
      return g_fxmr_news_cache_blocked;

   g_fxmr_news_cache_bucket = bucket;
   g_fxmr_news_cache_blocked = false;

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
      g_fxmr_news_cache_blocked = (!calendar_ok) || in_window;
      return g_fxmr_news_cache_blocked;
     }

   // Strategy Tester: deterministic factory archive (gate-validated path).
   if(!QM_NewsIsLoaded() &&
      !QM_NewsInit("D:\\QM\\data\\news_calendar",
                   qm_news_stale_max_hours,
                   30,
                   30,
                   qm_news_min_impact))
     {
      g_fxmr_news_cache_blocked = true; // fail-closed
      return g_fxmr_news_cache_blocked;
     }
   if(!QM_NewsIsAvailable())
     {
      g_fxmr_news_cache_blocked = true; // fail-closed
      return g_fxmr_news_cache_blocked;
     }

   datetime utc_time = QM_BrokerToUTC(broker_now);
   if(utc_time <= 0)
      utc_time = TimeGMT();
   g_fxmr_news_cache_blocked = QM_NewsInWindow(utc_time, _Symbol,
                                               strategy_news_blackout_minutes, 0,
                                               "high");
   return g_fxmr_news_cache_blocked;
  }

// ---------------------------------------------------------------------------
// Strategy hooks (called by the framework wiring in the .mq5)
// ---------------------------------------------------------------------------

// Static configuration guard only — cheap O(1), runs every tick. Session,
// breaker, and filter gates live in the new-bar entry path so that the
// mandatory-flat exit can never be blocked here.
bool FxmrNoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_M15)
      return true;
   if(g_fxmr_slot < 0)
      return true;
   if(strategy_stretch_bars < 2 || strategy_stretch_bars > 4)
      return true;
   if(strategy_ema_period < 10 || strategy_ema_period > 20)
      return true;
   if(strategy_stretch_atr_mult < 0.5 || strategy_stretch_atr_mult > 1.5)
      return true;
   if(strategy_atr_period < 10 || strategy_atr_period > 20)
      return true;
   if(strategy_stop_buffer_atr < 0.1 || strategy_stop_buffer_atr > 0.5)
      return true;
   if(strategy_max_stop_atr < 1.5 || strategy_max_stop_atr > 2.5)
      return true;
   if(strategy_target_r < 1.0 || strategy_target_r > 1.5)
      return true;
   if(strategy_time_stop_bars < 8 || strategy_time_stop_bars > 16)
      return true;
   if(strategy_daily_stop_pct != -1.0 || strategy_weekly_stop_pct != -2.0)
      return true;
   if(strategy_shock_atr_mult < 1.5 || strategy_shock_atr_mult > 2.5)
      return true;
   if(strategy_spread_median_mult < 1.25 || strategy_spread_median_mult > 1.75)
      return true;
   if(strategy_london_start_hour_utc < 7 || strategy_london_start_hour_utc > 8 ||
      strategy_london_end_hour_utc < 10 || strategy_london_end_hour_utc > 12 ||
      strategy_ny_start_hour_utc < 12 || strategy_ny_start_hour_utc > 13 ||
      strategy_ny_end_hour_utc < 15 || strategy_ny_end_hour_utc > 16)
      return true;
   if(strategy_london_flat_min_utc < 660 || strategy_london_flat_min_utc > 720 ||
      strategy_ny_flat_min_utc < 960 || strategy_ny_flat_min_utc > 1020)
      return true;
   // Window coherence: London flat inside the lunch gap before NY opens; the
   // NY flat backstop never precedes the NY entry window end.
   if(strategy_london_flat_min_utc >= strategy_ny_start_hour_utc * 60)
      return true;
   if(strategy_ny_flat_min_utc < strategy_ny_end_hour_utc * 60)
      return true;
   if(strategy_london_end_hour_utc * 60 > strategy_london_flat_min_utc)
      return true;
   if(strategy_friday_cutoff_min_utc < 780 || strategy_friday_cutoff_min_utc > 900)
      return true;
   if(strategy_skip_first_minutes < 0 || strategy_skip_first_minutes > 30)
      return true;
   if(strategy_max_positions_total < 2 || strategy_max_positions_total > 4)
      return true;
   if(strategy_max_trades_per_day < 2 || strategy_max_trades_per_day > 6)
      return true;
   if(strategy_news_blackout_minutes < 0 || strategy_news_blackout_minutes > 120)
      return true;
   return false;
  }

// Entry on the closed M15 bar (shift 1 reclaim over shift 2 stretch). The
// framework guarantees a new bar.
bool FxmrEntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   FxmrOnNewClosedBar();

   const datetime now = TimeCurrent();
   const int minute_of_day = FxmrUtcMinuteOfDay(now);

   // Session entry window (UTC, inclusive start / exclusive end).
   const int session = FxmrSessionAtMinute(minute_of_day);
   if(session == 0)
      return false;

   // Skip-first-minutes after the window open.
   const int window_start_min = (session == 1)
      ? strategy_london_start_hour_utc * 60
      : strategy_ny_start_hour_utc * 60;
   if(minute_of_day < window_start_min + strategy_skip_first_minutes)
      return false;

   // One entry per symbol per session window.
   if(session == 1 && g_fxmr_traded_london_today)
      return false;
   if(session == 2 && g_fxmr_traded_ny_today)
      return false;

   // Per-day trade cap (density control).
   if(g_fxmr_trades_today >= strategy_max_trades_per_day)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   // Flat proximity: no fresh entry inside the final stretch of the window.
   const int flat_min = (session == 1) ? strategy_london_flat_min_utc
                                       : strategy_ny_flat_min_utc;
   if(minute_of_day >= flat_min - strategy_skip_first_minutes)
      return false;

   // Friday cutoff for NEW entries.
   MqlDateTime utc_now;
   FxmrUtcStruct(now, utc_now);
   if(utc_now.day_of_week == 5 && minute_of_day >= strategy_friday_cutoff_min_utc)
      return false;

   // Circuit breakers (cached this bar by FxmrOnNewClosedBar).
   if(g_fxmr_breaker_day_hit || g_fxmr_breaker_week_hit)
      return false;

   // Per-window shock filter.
   if(session == 1 && g_fxmr_shock_london)
      return false;
   if(session == 2 && g_fxmr_shock_ny)
      return false;

   // Spread filter.
   if(FxmrSpreadFilterBlocks())
      return false;

   // News blackout (fail-closed).
   if(FxmrNewsBlackoutBlocks(now))
      return false;

   // Portfolio capacity across this EA's symbol slots.
   if(FxmrPortfolioPositionCount() >= strategy_max_positions_total)
      return false;

   // Stretch window must be complete for the stop anchor.
   if(!FxmrBuildStretchWindow())
      return false;

   // Closed-bar reads (shifts 1 and 2).
   const double close1 = iClose(_Symbol, PERIOD_M15, 1);
   const double close2 = iClose(_Symbol, PERIOD_M15, 2);
   const double ema1 = QM_EMA(_Symbol, PERIOD_M15, strategy_ema_period, 1);
   const double ema2 = QM_EMA(_Symbol, PERIOD_M15, strategy_ema_period, 2);
   const double atr1 = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   const double atr2 = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 2);
   if(close1 <= 0.0 || close2 <= 0.0 || ema1 <= 0.0 || ema2 <= 0.0 || atr1 <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double max_stop_dist = strategy_max_stop_atr * atr1;
   if(max_stop_dist <= 0.0)
      return false;

   // LONG reversion: stretched down at bar 2, reclaimed above the EMA at bar 1.
   const bool stretched_down =
      (atr2 > 0.0 && (ema2 - close2) > strategy_stretch_atr_mult * atr2) ||
      (FxmrDownCloseRun(strategy_stretch_bars + 4) >= strategy_stretch_bars);
   if(stretched_down && close1 > ema1 && close2 <= ema2)
     {
      const double sl_price = NormalizeDouble(g_fxmr_stretch_low - strategy_stop_buffer_atr * atr1, _Digits);
      const double stop_dist = ask - sl_price;
      if(sl_price > 0.0 && stop_dist >= point && stop_dist <= max_stop_dist)
        {
         const double tp = NormalizeDouble(ask + strategy_target_r * stop_dist, _Digits);
         if(tp > ask)
           {
            req.type = QM_BUY;
            req.price = 0.0;
            req.sl = sl_price;
            req.tp = tp;
            req.reason = "fxmr_session_reclaim_long";
            req.symbol_slot = qm_magic_slot_offset;
            req.expiration_seconds = 0;
            g_fxmr_trades_today++;
            if(session == 1)
               g_fxmr_traded_london_today = true;
            else
               g_fxmr_traded_ny_today = true;
            return true;
           }
        }
     }

   // SHORT reversion: stretched up at bar 2, reclaimed below the EMA at bar 1.
   const bool stretched_up =
      (atr2 > 0.0 && (close2 - ema2) > strategy_stretch_atr_mult * atr2) ||
      (FxmrUpCloseRun(strategy_stretch_bars + 4) >= strategy_stretch_bars);
   if(stretched_up && close1 < ema1 && close2 >= ema2)
     {
      const double sl_price = NormalizeDouble(g_fxmr_stretch_high + strategy_stop_buffer_atr * atr1, _Digits);
      const double stop_dist = sl_price - bid;
      if(sl_price > bid && stop_dist >= point && stop_dist <= max_stop_dist)
        {
         const double tp = NormalizeDouble(bid - strategy_target_r * stop_dist, _Digits);
         if(tp > 0.0)
           {
            req.type = QM_SELL;
            req.price = 0.0;
            req.sl = sl_price;
            req.tp = tp;
            req.reason = "fxmr_session_reclaim_short";
            req.symbol_slot = qm_magic_slot_offset;
            req.expiration_seconds = 0;
            g_fxmr_trades_today++;
            if(session == 1)
               g_fxmr_traded_london_today = true;
            else
               g_fxmr_traded_ny_today = true;
            return true;
           }
        }
     }

   return false;
  }

// Per-tick management: the card authorizes NO trailing / break-even — the
// stop stays at the stretch extreme plus buffer and is never widened. Kept
// as an explicit no-op so the wiring documents the choice.
void FxmrManageOpenPosition()
  {
  }

// Per-tick discretionary exit: mandatory session-flat + lunch gap + time
// stop. Runs outside every blocking filter, so flatten can never be gated.
bool FxmrExitSignal()
  {
   const int minute_of_day = FxmrUtcMinuteOfDay(TimeCurrent());

   // End-of-day backstop: nothing is held at/after the NY flat minute.
   if(minute_of_day >= strategy_ny_flat_min_utc)
      return true;

   // Lunch-gap flat: the London flat minute has passed and NY is not open.
   if(minute_of_day >= strategy_london_flat_min_utc &&
      minute_of_day < strategy_ny_start_hour_utc * 60)
      return true;

   // Time stop: full M15 bars elapsed since entry.
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
      if(opened > 0 && (int)((TimeCurrent() - opened) / PeriodSeconds(PERIOD_M15)) >= strategy_time_stop_bars)
         return true;
     }
   return false;
  }
