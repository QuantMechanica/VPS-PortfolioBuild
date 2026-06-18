#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA - Schiff Pitchfork Median-Line Reversion H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// Schiff Pitchfork — Median-Line Reversion (H4)
// -----------------------------------------------------------------------------
// SCHIFF variant of the Andrews pitchfork (cf. QM5_1368 = canonical Andrews).
// From 3 alternating confirmed swing pivots P0 (oldest), P1, P2 (newest)
// detected as strict fractals on CLOSED bars, the SCHIFF modification shifts
// the handle/anchor from P0 to the MIDPOINT of (P0,P1) in both time-index and
// price. The MEDIAN LINE is the ray from that Schiff anchor through the midpoint
// M of (P1,P2). The two parallel "tines" are offset by the card-specified
// spread = |price(M) - price(P2)| (== 0.5*|P1-P2| since M = midpoint(P1,P2)).
//
// Trade thesis = geometric-line mean-reversion. Bullish Schiff (handle = swing
// low, up-trend regime): BUY the reaction off the LOWER parallel back toward the
// median. Bearish Schiff (mirror): SELL the reaction off the UPPER parallel.
//
// Trigger EVENT (modelled, fired once per new closed bar): a lower/upper-parallel
// touch + close-back inside the fork on the last CLOSED bar, with trend-bias
// agreement (SMA50/SMA200) and a meaningful P1->P2 leg. Pitchfork lines
// (median / upper-parallel / lower-parallel) are STATES projected forward by the
// slope. The median line is the canonical reversion TP.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1377;
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
input int    strategy_zigzag_backstep    = 3;         // min separation before an accepted pivot
input double strategy_zigzag_dev_pips    = 5.0;       // min price deviation between pivots (pips)
input int    strategy_fresh_p2_bars      = 60;        // P2 (newest pivot) must be this fresh (card: <=60)
input double strategy_leg_min_atr        = 1.5;       // |P1-P2| leg-meaningfulness (card: >=1.5*ATR)
input double strategy_touch_atr          = 0.20;      // parallel-touch close-back tolerance (card: 0.2*ATR)
input double strategy_inside_atr         = 0.20;      // min room from median toward parallel (ATR)
input int    strategy_sma_fast_period    = 50;        // trend-bias fast SMA (card: SMA50)
input int    strategy_sma_slow_period    = 200;       // trend-bias slow SMA (card: SMA200)
input double strategy_spread_atr         = 0.40;      // fail-OPEN spread cap (card: <0.4*ATR)
input double strategy_stop_buffer_atr    = 0.50;      // SL buffer beyond parallel (card: 0.5*ATR)
input double strategy_stop_cap_atr       = 3.00;      // hard cap on initial SL distance (card: 3.0*ATR)
input int    strategy_time_stop_bars     = 30;        // bars without TP/SL -> market close (card: 30)
input int    strategy_session_start_hour = 6;         // broker-time entry window start (card: 06:00)
input int    strategy_session_end_hour   = 22;        // broker-time entry window end (card: <22:00)

// -----------------------------------------------------------------------------
// Pitchfork state
// -----------------------------------------------------------------------------
struct SPF_Pivot
  {
   int      shift;
   double   price;
   int      type;     // +1 swing-high, -1 swing-low
   datetime time;
  };

struct SPF_Fork
  {
   bool     valid;
   int      direction;        // +1 bullish (handle = swing-low), -1 bearish (handle = swing-high)
   double   anchor_shift;     // Schiff anchor = midpoint(P0,P1) time-index
   double   anchor_price;     // Schiff anchor price = midpoint(P0,P1)
   double   slope;            // price per bar; price = anchor_price + slope*(anchor_shift - shift)
   double   parallel_offset;  // |midpoint(P1,P2) - P2| ; >= 0
   double   p2_price;         // corrective swing extreme (structural SL reference)
   datetime p0_time;
   datetime p1_time;
   datetime p2_time;
   string   key;
  };

SPF_Fork g_fork;
bool     g_have_fork        = false;
string   g_last_fork_key    = "";

double SPF_NormalizePrice(const double price)
  {
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

double SPF_PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   return (digits == 3 || digits == 5) ? point * 10.0 : point;
  }

// Median line (offset=0) or a parallel (offset = +/- parallel_offset) at a bar shift.
double SPF_LineAtShift(const SPF_Fork &fork, const double offset, const int shift)
  {
   return fork.anchor_price + offset + fork.slope * (fork.anchor_shift - (double)shift);
  }

bool SPF_CurrentSymbolAllowed()
  {
   const string s = _Symbol;
   return (s == "EURUSD.DWX" || s == "GBPUSD.DWX" || s == "USDJPY.DWX" ||
           s == "AUDUSD.DWX" || s == "USDCAD.DWX" || s == "USDCHF.DWX" ||
           s == "NZDUSD.DWX" || s == "EURJPY.DWX" || s == "GBPJPY.DWX" ||
           s == "EURGBP.DWX" || s == "XAUUSD.DWX" || s == "NDX.DWX" ||
           s == "WS30.DWX"   || s == "GDAXI.DWX"  || s == "UK100.DWX");
  }

// Entry only inside the broker-time session window (card: no new entry 22:00-06:00 broker).
bool SPF_IsSessionAllowed(const datetime bar_open_time)
  {
   // New entry fires on the OPEN of bar[0]; gate on that bar-open broker time.
   MqlDateTime dt;
   TimeToStruct(bar_open_time, dt);
   if(dt.hour < strategy_session_start_hour || dt.hour >= strategy_session_end_hour)
      return false;
   return true;
  }

// Strict fractal: bar[shift] is the local extreme over +/- depth neighbours.
bool SPF_IsFractalPivot(const MqlRates &rates[], const int count, const int shift, const int type)
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
bool SPF_AppendPivot(SPF_Pivot &pivots[], int &pivot_count, const SPF_Pivot &candidate, const double min_dev)
  {
   if(pivot_count > 0)
     {
      SPF_Pivot last = pivots[pivot_count - 1];
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

// Build the most recent valid SCHIFF pitchfork from closed bars.
// perf-allowed: single CopyRates per new-bar (caller is QM_IsNewBar-gated).
bool SPF_BuildFork(SPF_Fork &fork)
  {
   fork.valid = false;

   const int needed = strategy_pivot_scan_bars + strategy_zigzag_depth + strategy_zigzag_backstep + 8;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_timeframe, 0, needed, rates); // perf-allowed
   if(copied < needed - 2)
      return false;

   const double h4_atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double pip = SPF_PipSize();
   if(h4_atr <= 0.0 || pip <= 0.0)
      return false;

   SPF_Pivot pivots[80];
   int pivot_count = 0;
   const double min_dev = strategy_zigzag_dev_pips * pip;
   const int max_shift = MathMin(strategy_pivot_scan_bars, copied - strategy_zigzag_depth - 1);

   // Walk oldest -> newest so pivots[] is chronological (index 0 = oldest).
   for(int shift = max_shift; shift >= strategy_zigzag_backstep + 1; --shift)
     {
      SPF_Pivot candidate;
      candidate.shift = shift;
      candidate.time  = rates[shift].time;
      candidate.type  = 0;
      candidate.price = 0.0;

      if(SPF_IsFractalPivot(rates, copied, shift, 1))
        {
         candidate.type  = 1;
         candidate.price = rates[shift].high;
        }
      else if(SPF_IsFractalPivot(rates, copied, shift, -1))
        {
         candidate.type  = -1;
         candidate.price = rates[shift].low;
        }

      if(candidate.type == 0)
         continue;
      if(!SPF_AppendPivot(pivots, pivot_count, candidate, min_dev))
         break;
     }

   // Most recent alternating trio P0(oldest) P1 P2(newest): P0.type==P2.type, P0!=P1.
   for(int i = pivot_count - 3; i >= 0; --i)
     {
      SPF_Pivot p0 = pivots[i];
      SPF_Pivot p1 = pivots[i + 1];
      SPF_Pivot p2 = pivots[i + 2];
      if(!(p0.type == p2.type && p0.type != p1.type))
         continue;
      if(p2.shift > strategy_fresh_p2_bars)
         continue;

      // Card: bullish needs P0=low, P1=high, P2=low with P2 > P0 (up-anchored Schiff).
      const bool bullish = (p0.type == -1);
      if(bullish && !(p2.price > p0.price))
         continue;
      if(!bullish && !(p2.price < p0.price))   // bearish: P0=high, P2=high, P2 < P0
         continue;

      // P1->P2 leg-meaningfulness gate (card: |P1-P2| >= 1.5 * ATR(14,H4)).
      if(MathAbs(p1.price - p2.price) < strategy_leg_min_atr * h4_atr)
         continue;

      // SCHIFF anchor = midpoint(P0,P1) in time-index and price.
      const double anchor_shift = 0.5 * ((double)p0.shift + (double)p1.shift);
      const double anchor_price = 0.5 * (p0.price + p1.price);

      // Median line: ray from Schiff anchor through M = midpoint(P1,P2).
      // Slope is price-per-bar; time increases as shift decreases, so
      // denom = anchor_shift - mid_shift.
      const double mid_shift = 0.5 * ((double)p1.shift + (double)p2.shift);
      const double mid_price = 0.5 * (p1.price + p2.price);
      const double denom = anchor_shift - mid_shift;
      if(MathAbs(denom) <= 0.0)
         continue;
      const double slope = (mid_price - anchor_price) / denom;

      // Card parallel offset = |midpoint(P1,P2) - P2| = 0.5*|P1-P2|.
      const double parallel_offset = MathAbs(mid_price - p2.price);
      if(parallel_offset <= 0.0)
         continue;

      fork.valid           = true;
      fork.direction       = bullish ? 1 : -1;
      fork.anchor_shift    = anchor_shift;
      fork.anchor_price    = anchor_price;
      fork.slope           = slope;
      fork.parallel_offset = parallel_offset;
      fork.p2_price        = p2.price;
      fork.p0_time         = p0.time;
      fork.p1_time         = p1.time;
      fork.p2_time         = p2.time;
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
   if(!SPF_CurrentSymbolAllowed())
      return true;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;

   // Fail-OPEN spread guard: block only a genuinely wide REAL spread. On .DWX the
   // modelled spread is 0 (ask==bid) -> never blocks in the tester.
   if(ask > bid && (ask - bid) > strategy_spread_atr * atr)
      return true;

   return false;
  }

// =============================================================================
// Trade Entry — reaction off the lower/upper parallel back toward the median.
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
   if(!SPF_IsSessionAllowed(current_bar))
      return false;

   SPF_Fork fork;
   if(!SPF_BuildFork(fork))
      return false;
   // Cool-down: do not re-enter the same fork structure (same P0,P1,P2).
   if(fork.key == g_last_fork_key)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;
   if(ask > bid && (ask - bid) > strategy_spread_atr * atr)
      return false;

   // Trend-bias agreement (card: SMA50/SMA200 regime).
   const double sma_fast = QM_SMA(_Symbol, strategy_timeframe, strategy_sma_fast_period, 1);
   const double sma_slow = QM_SMA(_Symbol, strategy_timeframe, strategy_sma_slow_period, 1);
   if(sma_fast <= 0.0 || sma_slow <= 0.0)
      return false;

   // Trigger bar = last CLOSED bar (shift 1).
   const double close1 = iClose(_Symbol, strategy_timeframe, 1); // perf-allowed: pitchfork structural read
   const double low1   = iLow(_Symbol, strategy_timeframe, 1);   // perf-allowed
   const double high1  = iHigh(_Symbol, strategy_timeframe, 1);  // perf-allowed
   if(close1 <= 0.0 || low1 <= 0.0 || high1 <= 0.0)
      return false;

   const double ml1    = SPF_LineAtShift(fork, 0.0, 1);
   const double upper1 = SPF_LineAtShift(fork, fork.parallel_offset, 1);
   const double lower1 = SPF_LineAtShift(fork, -fork.parallel_offset, 1);

   double entry_price = 0.0;
   double sl = 0.0;
   double tp = 0.0;
   string reason = "";
   QM_OrderType otype = QM_BUY;
   bool fire = false;

   if(fork.direction > 0) // bullish Schiff -> BUY reaction off the LOWER parallel
     {
      // Up-trend regime persists (Schiff longs = entry-on-pullback only).
      if(!(close1 > sma_fast && sma_fast > sma_slow))
         return false;

      // Lower-parallel contact + close-back above it (reaction, not a clean break).
      const bool contact     = (low1 <= lower1);
      const bool closed_back  = (close1 > lower1 - strategy_touch_atr * atr) && (close1 > lower1);
      // Median is the reversion TP; require room toward it.
      const bool room_to_med  = (close1 < ml1 - strategy_inside_atr * atr);
      if(contact && closed_back && room_to_med)
        {
         entry_price = ask;
         // SL: wider of structural P2 or lower-parallel buffer (card).
         sl = MathMin(fork.p2_price, lower1 - strategy_stop_buffer_atr * atr);
         tp = ml1; // median-line target (recomputed each bar in management).
         otype  = QM_BUY;
         reason = "schiff_lower_parallel_reaction_buy";
         fire = true;
        }
     }
   else // bearish Schiff -> SELL reaction off the UPPER parallel
     {
      if(!(close1 < sma_fast && sma_fast < sma_slow))
         return false;

      const bool contact     = (high1 >= upper1);
      const bool closed_back  = (close1 < upper1 + strategy_touch_atr * atr) && (close1 < upper1);
      const bool room_to_med  = (close1 > ml1 + strategy_inside_atr * atr);
      if(contact && closed_back && room_to_med)
        {
         entry_price = bid;
         sl = MathMax(fork.p2_price, upper1 + strategy_stop_buffer_atr * atr);
         tp = ml1;
         otype  = QM_SELL;
         reason = "schiff_upper_parallel_reaction_sell";
         fire = true;
        }
     }

   if(!fire)
      return false;

   // Cap the initial SL distance at strategy_stop_cap_atr * ATR (card: 3.0*ATR).
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
   req.sl     = SPF_NormalizePrice(sl);
   req.tp     = SPF_NormalizePrice(tp);
   req.reason = reason;

   g_fork = fork;
   g_have_fork = true;
   g_last_fork_key = fork.key;
   return true;
  }

// =============================================================================
// Trade Management — ratchet TP to the evolving median line; trail SL to the
// near parallel after the median is touched (card: median is the moving target,
// parallel is the moving floor for the runner).
// =============================================================================
void Strategy_ManageOpenPosition()
  {
   if(!g_have_fork)
      return;

   const int magic = QM_FrameworkMagic();
   const double ml1    = SPF_LineAtShift(g_fork, 0.0, 1);
   const double upper1 = SPF_LineAtShift(g_fork, g_fork.parallel_offset, 1);
   const double lower1 = SPF_LineAtShift(g_fork, -g_fork.parallel_offset, 1);
   const double close1 = iClose(_Symbol, strategy_timeframe, 1); // perf-allowed: structural read
   if(ml1 <= 0.0 || close1 <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic || PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double cur_tp = PositionGetDouble(POSITION_TP);
      const double cur_sl = PositionGetDouble(POSITION_SL);

      if(type == POSITION_TYPE_BUY)
        {
         // TP rides the evolving median line.
         const double new_tp = SPF_NormalizePrice(ml1);
         if(MathAbs(new_tp - cur_tp) > _Point)
            QM_TM_MoveTP(ticket, new_tp, "schiff_median_target");
         // After the median is reached, trail SL up to the lower parallel.
         if(close1 >= ml1)
           {
            const double new_sl = SPF_NormalizePrice(lower1);
            if(new_sl > cur_sl && new_sl < SymbolInfoDouble(_Symbol, SYMBOL_BID))
               QM_TM_MoveSL(ticket, new_sl, "schiff_lower_parallel_trail");
           }
        }
      else if(type == POSITION_TYPE_SELL)
        {
         const double new_tp = SPF_NormalizePrice(ml1);
         if(MathAbs(new_tp - cur_tp) > _Point)
            QM_TM_MoveTP(ticket, new_tp, "schiff_median_target");
         if(close1 <= ml1)
           {
            const double new_sl = SPF_NormalizePrice(upper1);
            if((cur_sl <= 0.0 || new_sl < cur_sl) && new_sl > SymbolInfoDouble(_Symbol, SYMBOL_ASK))
               QM_TM_MoveSL(ticket, new_sl, "schiff_upper_parallel_trail");
           }
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

      // Time-stop: 30 H4 bars (~5 trading days) without TP/SL (card).
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int entry_shift = iBarShift(_Symbol, strategy_timeframe, open_time, false); // perf-allowed
      if(entry_shift >= strategy_time_stop_bars)
         return true;

      if(!g_have_fork)
         continue;

      // Pitchfork-invalidation exit: price closes beyond the FAR outer parallel
      // (structure break against the reversion thesis).
      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double upper1 = SPF_LineAtShift(g_fork, g_fork.parallel_offset, 1);
      const double lower1 = SPF_LineAtShift(g_fork, -g_fork.parallel_offset, 1);
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
