#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA - Andrews Pitchfork Median-Line Bounce / Outer-Tine Fade H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// Andrew's Pitchfork — Median-Line Bounce / Outer-Tine Fade (H4)
// -----------------------------------------------------------------------------
// Standard Andrews construction (NOT Schiff/Modified): from 3 alternating
// confirmed swing pivots P0 (oldest), P1, P2 (newest) detected as fractals on
// CLOSED bars, the MEDIAN LINE is the ray from the handle P0 through the
// midpoint M of (P1,P2). The two parallel tines are offset by the
// Andrews-canonical equidistant spread = +/- 0.5 * (price(P2) - price(P1)).
//
// Trigger EVENT (modelled): a median-line touch + bounce-and-close back in the
// pitchfork direction on the last CLOSED bar (Andrews' 80% median-line
// frequency rule). Pitchfork lines (median / upper-tine / lower-tine) are
// STATES projected forward by the slope. Optional Mode B trades the outer tines
// (continuation off the trend-side tine, counter-trend fade off the far tine).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1368;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_timeframe = PERIOD_H4;
input int    strategy_atr_period         = 14;        // ATR period (H4) for sizing + tolerances
input int    strategy_pivot_scan_bars    = 120;       // window of closed bars scanned for pivots
input int    strategy_zigzag_depth       = 12;        // fractal half-width for swing detection
input int    strategy_zigzag_backstep    = 3;         // min separation between accepted pivots
input double strategy_zigzag_dev_pips    = 5.0;       // min price deviation between pivots (pips)
input int    strategy_fresh_p2_bars      = 50;        // P2 (newest pivot) must be this fresh
input double strategy_swing_min_d1_atr   = 1.0;       // min |P0-P1| and |P1-P2| in D1-ATR units
input double strategy_touch_atr          = 0.20;      // median-touch tolerance (ATR)
input double strategy_body_ratio_min     = 0.45;      // min body/range of the trigger bar
input double strategy_inside_atr         = 0.30;      // min room to the far tine (ATR)
input double strategy_spread_atr         = 0.40;      // fail-OPEN spread cap (ATR)
input double strategy_stop_atr           = 1.00;      // SL cushion beyond the line (ATR)
input double strategy_stop_cap_atr       = 2.50;      // hard cap on initial SL distance (ATR)
input double strategy_tp_r_mult          = 1.50;      // TP = entry +/- R_mult * ATR
input double strategy_be_trigger_atr     = 1.00;      // break-even shift trigger (ATR in favour)
input int    strategy_time_stop_bars     = 18;        // bars without TP/SL -> market close
input int    strategy_reuse_guard_bars   = 12;        // cool-down bars after an entry on a fork
input bool   strategy_mode_b_lower_tine  = true;      // Mode B: trend-side tine continuation
input bool   strategy_mode_b_upper_tine  = true;      // Mode B: far-tine counter-trend fade
input int    strategy_session_start_hour = 7;         // broker-time entry window start (H)
input int    strategy_session_end_hour   = 21;        // broker-time entry window end (H)
input int    strategy_rollover_block_h   = 22;        // no new entry in this broker hour (rollover)

// -----------------------------------------------------------------------------
// Pitchfork state
// -----------------------------------------------------------------------------
struct APF_Pivot
  {
   int      shift;
   double   price;
   int      type;     // +1 swing-high, -1 swing-low
   datetime time;
  };

struct APF_Fork
  {
   bool     valid;
   int      direction;        // +1 bullish (P0=low), -1 bearish (P0=high)
   double   p0_shift;
   double   p0_price;
   double   slope;            // price per bar; price = p0_price + slope*(p0_shift - shift)
   double   tine_offset;      // |0.5 * (price(P2) - price(P1))| ; >= 0
   datetime p0_time;
   datetime p1_time;
   datetime p2_time;
   string   key;
  };

APF_Fork g_fork;
bool     g_have_fork        = false;
string   g_last_fork_key    = "";
datetime g_reuse_guard_until = 0;
bool     g_be_done          = false;

double APF_NormalizePrice(const double price)
  {
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

double APF_PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   return (digits == 3 || digits == 5) ? point * 10.0 : point;
  }

// Median line (offset=0) or a parallel tine (offset = +/- tine_offset) at a bar shift.
double APF_LineAtShift(const APF_Fork &fork, const double offset, const int shift)
  {
   return fork.p0_price + offset + fork.slope * (fork.p0_shift - (double)shift);
  }

bool APF_CurrentSymbolAllowed()
  {
   const string s = _Symbol;
   return (s == "EURUSD.DWX" || s == "GBPUSD.DWX" || s == "USDJPY.DWX" ||
           s == "AUDUSD.DWX" || s == "USDCAD.DWX" || s == "USDCHF.DWX" ||
           s == "NZDUSD.DWX" || s == "EURJPY.DWX" || s == "GBPJPY.DWX" ||
           s == "EURGBP.DWX" || s == "XAUUSD.DWX" || s == "NDX.DWX" ||
           s == "WS30.DWX"   || s == "GDAXI.DWX"  || s == "UK100.DWX");
  }

// Entry only inside the broker-time session window and outside the rollover hour.
bool APF_IsSessionAllowed(const datetime bar_open_time)
  {
   // The new entry fires on the OPEN of bar[0]; gate on that bar-open broker time.
   const datetime bar_close_time = bar_open_time + (datetime)PeriodSeconds(strategy_timeframe);
   MqlDateTime dt;
   TimeToStruct(bar_close_time, dt);
   if(dt.hour < strategy_session_start_hour || dt.hour > strategy_session_end_hour)
      return false;
   if(dt.hour == strategy_rollover_block_h)
      return false;
   return true;
  }

// Strict fractal: bar[shift] is the local extreme over +/- depth neighbours.
bool APF_IsFractalPivot(const MqlRates &rates[], const int count, const int shift, const int type)
  {
   if(shift < strategy_zigzag_backstep || shift + strategy_zigzag_depth >= count)
      return false;

   for(int j = 1; j <= strategy_zigzag_depth; ++j)
     {
      if(type > 0)
        {
         if(rates[shift].high <= rates[shift - j].high || rates[shift].high <= rates[shift + j].high)
            return false;
        }
      else
        {
         if(rates[shift].low >= rates[shift - j].low || rates[shift].low >= rates[shift + j].low)
            return false;
        }
     }
   return true;
  }

// ZigZag-style append: keep alternation, replace same-type extreme, enforce min dev.
bool APF_AppendPivot(APF_Pivot &pivots[], int &pivot_count, const APF_Pivot &candidate, const double min_dev)
  {
   if(pivot_count > 0)
     {
      APF_Pivot last = pivots[pivot_count - 1];
      if(last.type == candidate.type)
        {
         const bool replace = (candidate.type > 0) ? (candidate.price > last.price) : (candidate.price < last.price);
         if(replace)
            pivots[pivot_count - 1] = candidate;
         return true;
        }
      if(MathAbs(candidate.price - last.price) < min_dev)
         return true;
     }

   if(pivot_count >= 80)
      return false;

   pivots[pivot_count] = candidate;
   pivot_count++;
   return true;
  }

// Build the most recent valid standard-Andrews pitchfork from closed bars.
// perf-allowed: single CopyRates per new-bar (caller is QM_IsNewBar-gated).
bool APF_BuildFork(APF_Fork &fork)
  {
   fork.valid = false;

   const int needed = strategy_pivot_scan_bars + strategy_zigzag_depth + strategy_zigzag_backstep + 8;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_timeframe, 0, needed, rates); // perf-allowed
   if(copied < needed - 2)
      return false;

   const double d1_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double pip = APF_PipSize();
   if(d1_atr <= 0.0 || pip <= 0.0)
      return false;

   APF_Pivot pivots[80];
   int pivot_count = 0;
   const double min_dev = strategy_zigzag_dev_pips * pip;
   const int max_shift = MathMin(strategy_pivot_scan_bars, copied - strategy_zigzag_depth - 1);

   // Walk oldest -> newest so pivots[] is chronological (index 0 = oldest).
   for(int shift = max_shift; shift >= strategy_zigzag_backstep + 1; --shift)
     {
      APF_Pivot candidate;
      candidate.shift = shift;
      candidate.time  = rates[shift].time;
      candidate.type  = 0;
      candidate.price = 0.0;

      if(APF_IsFractalPivot(rates, copied, shift, 1))
        {
         candidate.type  = 1;
         candidate.price = rates[shift].high;
        }
      else if(APF_IsFractalPivot(rates, copied, shift, -1))
        {
         candidate.type  = -1;
         candidate.price = rates[shift].low;
        }

      if(candidate.type == 0)
         continue;
      if(!APF_AppendPivot(pivots, pivot_count, candidate, min_dev))
         break;
     }

   // Most recent alternating trio P0(oldest) P1 P2(newest): P0.type==P2.type, P0!=P1.
   for(int i = pivot_count - 3; i >= 0; --i)
     {
      APF_Pivot p0 = pivots[i];
      APF_Pivot p1 = pivots[i + 1];
      APF_Pivot p2 = pivots[i + 2];
      if(!(p0.type == p2.type && p0.type != p1.type))
         continue;
      if(p2.shift > strategy_fresh_p2_bars)
         continue;
      if(MathAbs(p0.price - p1.price) < strategy_swing_min_d1_atr * d1_atr)
         continue;
      if(MathAbs(p2.price - p1.price) < strategy_swing_min_d1_atr * d1_atr)
         continue;

      // Bullish pitchfork = handle is a swing-low (P0.type == -1); bearish = swing-high.
      const bool bullish = (p0.type == -1);

      // Median line: ray from P0 through M = midpoint(P1,P2). Slope is price-per-bar;
      // time increases as shift decreases, so denom = shift(P0) - shift(M).
      const double mid_shift = 0.5 * ((double)p1.shift + (double)p2.shift);
      const double mid_price = 0.5 * (p1.price + p2.price);
      const double denom = (double)p0.shift - mid_shift;
      if(MathAbs(denom) <= 0.0)
         continue;
      const double slope = (mid_price - p0.price) / denom;

      // Andrews-canonical equidistant tine offset = 0.5 * |price(P2) - price(P1)|.
      const double tine_offset = 0.5 * MathAbs(p2.price - p1.price);
      if(tine_offset <= 0.0)
         continue;

      fork.valid       = true;
      fork.direction   = bullish ? 1 : -1;
      fork.p0_shift    = (double)p0.shift;
      fork.p0_price    = p0.price;
      fork.slope       = slope;
      fork.tine_offset = tine_offset;
      fork.p0_time     = p0.time;
      fork.p1_time     = p1.time;
      fork.p2_time     = p2.time;
      fork.key = StringFormat("%I64d-%I64d-%I64d", (long)p0.time, (long)p1.time, (long)p2.time);
      return true;
     }

   return false;
  }

// =============================================================================
// No Trade Filter (time, spread, news)
// =============================================================================
bool Strategy_NoTradeFilter()
  {
   if(!APF_CurrentSymbolAllowed())
      return true;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;

   // Fail-OPEN spread guard: block only a genuinely wide real spread. On .DWX the
   // modelled spread is 0 (ask==bid) -> never blocks in the tester.
   if(ask > bid && (ask - bid) > strategy_spread_atr * atr)
      return true;

   return false;
  }

// =============================================================================
// Trade Entry
// =============================================================================
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime current_bar = iTime(_Symbol, strategy_timeframe, 0); // perf-allowed: bar-open clock
   if(g_reuse_guard_until > 0 && current_bar <= g_reuse_guard_until)
      return false;
   if(!APF_IsSessionAllowed(current_bar))
      return false;

   APF_Fork fork;
   if(!APF_BuildFork(fork))
      return false;
   // Cool-down: do not re-enter the same fork until a new swing trio supersedes.
   if(fork.key == g_last_fork_key)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;
   if(ask > bid && (ask - bid) > strategy_spread_atr * atr)
      return false;

   // Trigger bar = last CLOSED bar (shift 1).
   const double open1  = iOpen(_Symbol, strategy_timeframe, 1);  // perf-allowed: pitchfork structural read
   const double close1 = iClose(_Symbol, strategy_timeframe, 1); // perf-allowed
   const double high1  = iHigh(_Symbol, strategy_timeframe, 1);  // perf-allowed
   const double low1   = iLow(_Symbol, strategy_timeframe, 1);   // perf-allowed
   const double range1 = high1 - low1;
   if(open1 <= 0.0 || close1 <= 0.0 || range1 <= 0.0)
      return false;

   const double body_ratio = MathAbs(close1 - open1) / range1;
   if(body_ratio < strategy_body_ratio_min)
      return false;

   const double ml1    = APF_LineAtShift(fork, 0.0, 1);
   const double upper1 = APF_LineAtShift(fork, fork.tine_offset, 1);
   const double lower1 = APF_LineAtShift(fork, -fork.tine_offset, 1);

   double entry_price = 0.0;
   double sl = 0.0;
   double tp = 0.0;
   string reason = "";
   QM_OrderType otype = QM_BUY;
   bool fire = false;

   if(fork.direction > 0) // bullish pitchfork
     {
      const bool median_touch = (low1 <= ml1 + strategy_touch_atr * atr && high1 >= ml1 - strategy_touch_atr * atr);
      const bool bull_bar     = (close1 > open1);

      // --- Median-line bounce (primary BUY) ---
      if(median_touch && bull_bar && close1 > ml1 &&
         close1 < upper1 - strategy_inside_atr * atr)
        {
         entry_price = ask;
         sl = ml1 - strategy_stop_atr * atr;
         tp = entry_price + strategy_tp_r_mult * atr;
         otype  = QM_BUY;
         reason = "andrews_median_bounce_buy";
         fire = true;
        }
      // --- Mode B: lower-tine touch + bounce-up = trend-side continuation BUY ---
      else if(strategy_mode_b_lower_tine && bull_bar && close1 > open1 &&
              low1 <= lower1 + strategy_touch_atr * atr && close1 > lower1 &&
              close1 < ml1) // still below the median => room toward the median target
        {
         entry_price = ask;
         sl = lower1 - strategy_stop_atr * atr;
         tp = entry_price + strategy_tp_r_mult * atr;
         otype  = QM_BUY;
         reason = "andrews_lower_tine_continuation_buy";
         fire = true;
        }
      // --- Mode B: upper-tine touch + reject-down = counter-trend fade SELL ---
      else if(strategy_mode_b_upper_tine && close1 < open1 &&
              high1 >= upper1 - strategy_touch_atr * atr && close1 < upper1)
        {
         entry_price = bid;
         sl = upper1 + strategy_stop_atr * atr;
         tp = entry_price - strategy_tp_r_mult * atr;
         otype  = QM_SELL;
         reason = "andrews_upper_tine_fade_sell";
         fire = true;
        }
     }
   else // bearish pitchfork
     {
      const bool median_touch = (high1 >= ml1 - strategy_touch_atr * atr && low1 <= ml1 + strategy_touch_atr * atr);
      const bool bear_bar     = (close1 < open1);

      // --- Median-line bounce (primary SELL) ---
      if(median_touch && bear_bar && close1 < ml1 &&
         close1 > lower1 + strategy_inside_atr * atr)
        {
         entry_price = bid;
         sl = ml1 + strategy_stop_atr * atr;
         tp = entry_price - strategy_tp_r_mult * atr;
         otype  = QM_SELL;
         reason = "andrews_median_bounce_sell";
         fire = true;
        }
      // --- Mode B: upper-tine touch + reject-down = trend-side continuation SELL ---
      else if(strategy_mode_b_lower_tine && bear_bar &&
              high1 >= upper1 - strategy_touch_atr * atr && close1 < upper1 &&
              close1 > ml1)
        {
         entry_price = bid;
         sl = upper1 + strategy_stop_atr * atr;
         tp = entry_price - strategy_tp_r_mult * atr;
         otype  = QM_SELL;
         reason = "andrews_upper_tine_continuation_sell";
         fire = true;
        }
      // --- Mode B: lower-tine touch + reject-up = counter-trend fade BUY ---
      else if(strategy_mode_b_upper_tine && close1 > open1 &&
              low1 <= lower1 + strategy_touch_atr * atr && close1 > lower1)
        {
         entry_price = ask;
         sl = lower1 - strategy_stop_atr * atr;
         tp = entry_price + strategy_tp_r_mult * atr;
         otype  = QM_BUY;
         reason = "andrews_lower_tine_fade_buy";
         fire = true;
        }
     }

   if(!fire)
      return false;

   // Cap the initial SL distance at strategy_stop_cap_atr * ATR.
   const double max_sl_dist = strategy_stop_cap_atr * atr;
   if(otype == QM_BUY)
     {
      if(entry_price - sl > max_sl_dist)
         sl = entry_price - max_sl_dist;
      if(sl >= entry_price || tp <= entry_price)
         return false;
     }
   else
     {
      if(sl - entry_price > max_sl_dist)
         sl = entry_price + max_sl_dist;
      if(sl <= entry_price || tp >= entry_price)
         return false;
     }

   req.type   = otype;
   req.price  = 0.0; // market fill at send
   req.sl     = APF_NormalizePrice(sl);
   req.tp     = APF_NormalizePrice(tp);
   req.reason = reason;

   g_fork = fork;
   g_have_fork = true;
   g_be_done = false;
   g_last_fork_key = fork.key;
   g_reuse_guard_until = current_bar + (datetime)(strategy_reuse_guard_bars * PeriodSeconds(strategy_timeframe));
   return true;
  }

// =============================================================================
// Trade Management — one-time break-even shift after +1 ATR in favour.
// =============================================================================
void Strategy_ManageOpenPosition()
  {
   if(g_be_done)
      return;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic || PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
      if(atr <= 0.0)
         continue;
      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(type == POSITION_TYPE_BUY && bid - entry >= strategy_be_trigger_atr * atr)
        {
         QM_TM_MoveSL(ticket, APF_NormalizePrice(entry), "andrews_break_even");
         g_be_done = true;
        }
      else if(type == POSITION_TYPE_SELL && entry - ask >= strategy_be_trigger_atr * atr)
        {
         QM_TM_MoveSL(ticket, APF_NormalizePrice(entry), "andrews_break_even");
         g_be_done = true;
        }
     }
  }

// =============================================================================
// Trade Close — time-stop + pitchfork-invalidation exit.
// =============================================================================
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const double close1 = iClose(_Symbol, strategy_timeframe, 1); // perf-allowed: structural read
   if(close1 <= 0.0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic || PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      // Time-stop: 18 H4 bars without TP/SL.
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int entry_shift = iBarShift(_Symbol, strategy_timeframe, open_time, false); // perf-allowed
      if(entry_shift >= strategy_time_stop_bars)
         return true;

      if(!g_have_fork)
         continue;

      // Pitchfork-invalidation exit: price closes outside the opposite outer tine
      // (exhaustion / structure break against the entry thesis).
      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double upper1 = APF_LineAtShift(g_fork, g_fork.tine_offset, 1);
      const double lower1 = APF_LineAtShift(g_fork, -g_fork.tine_offset, 1);
      if(type == POSITION_TYPE_BUY && close1 < lower1)
         return true;
      if(type == POSITION_TYPE_SELL && close1 > upper1)
         return true;
     }
   return false;
  }

// =============================================================================
// News Filter Hook (callable for P8 News Impact phase)
// =============================================================================
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(qm_news_mode == QM_NEWS_OFF)
      return false;
   return !QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode);
  }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------
int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
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

   if(!QM_IsNewBar(_Symbol, strategy_timeframe))
      return;

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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
