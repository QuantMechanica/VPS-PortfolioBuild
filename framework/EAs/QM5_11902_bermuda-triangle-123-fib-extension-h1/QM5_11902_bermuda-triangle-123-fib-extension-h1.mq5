#property strict
#property version   "5.0"
#property description "QM5_11902 Bermuda Triangle 1-2-3 Fib Extension H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_11902 - Bermuda Triangle Compression + 1-2-3 + Fib Extensions, H1 FX
// Source: Michel Selim, Forex Bermuda Trading Strategy; classical triangle,
// 1-2-3 reversal, and Fibonacci-extension pattern rules.
// =============================================================================

#define BERMUDA_MAX_PIVOTS 96

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11902;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal      = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance    = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours                  = 336;
input string qm_news_min_impact                       = "high";
input QM_NewsMode qm_news_mode_legacy                 = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_zigzag_depth          = 12;
input int    strategy_zigzag_deviation_pips = 10;
input int    strategy_zigzag_backstep       = 3;
input int    strategy_triangle_min_bars     = 30;
input int    strategy_triangle_max_bars     = 200;
input int    strategy_apex_max_bars         = 50;
input double strategy_p3_fib_tolerance      = 0.05;
input int    strategy_entry_buffer_pips     = 2;
input int    strategy_stop_buffer_pips      = 5;
input int    strategy_pending_valid_bars    = 50;
input int    strategy_time_stop_bars        = 480;
input double strategy_target1_fib           = 1.618;
input double strategy_target2_fib           = 2.618;
input double strategy_target3_fib           = 4.236;
input double strategy_tp1_fraction          = 0.40;
input double strategy_tp2_fraction          = 0.40;
input int    strategy_max_spread_points     = 0;

struct SwingPivot
  {
   int      shift;
   datetime bar_time;
   double   price;
   int      kind;      // +1 high pivot, -1 low pivot
  };

double g_signal_entry = 0.0;
double g_signal_tp1   = 0.0;
double g_signal_tp2   = 0.0;
double g_signal_tp3   = 0.0;
int    g_signal_dir   = 0;

ulong  g_managed_ticket = 0;
double g_initial_volume = 0.0;
bool   g_tp1_hit        = false;
bool   g_tp2_hit        = false;

int MaxInt(const int a, const int b)
  {
   return (a > b) ? a : b;
  }

int MinInt(const int a, const int b)
  {
   return (a < b) ? a : b;
  }

double AbsD(const double value)
  {
   return (value >= 0.0) ? value : -value;
  }

int H1Seconds()
  {
   const int seconds = PeriodSeconds(PERIOD_H1);
   return (seconds > 0) ? seconds : 3600;
  }

int PivotWing()
  {
   int wing = strategy_zigzag_depth;
   if(wing < 2)
      wing = 2;
   if(wing > 20)
      wing = 20;
   return wing;
  }

int ScanBars()
  {
   int max_bars = strategy_triangle_max_bars;
   if(max_bars < strategy_triangle_min_bars)
      max_bars = strategy_triangle_min_bars;
   if(max_bars < 60)
      max_bars = 60;
   if(max_bars > 240)
      max_bars = 240;
   return max_bars + PivotWing() * 2 + 8;
  }

void InitRequest(QM_EntryRequest &req)
  {
   req.type               = QM_BUY_STOP;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;

   int bars = strategy_pending_valid_bars;
   if(bars < 1)
      bars = 1;
   req.expiration_seconds = bars * H1Seconds();
  }

bool HasOpenPositionForMagic()
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool HasPendingOrderForMagic()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask_px = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid_px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask_px <= 0.0 || bid_px <= 0.0 || ask_px < bid_px)
      return false;

   const double spread_points = (ask_px - bid_px) / point;
   return (spread_points <= strategy_max_spread_points);
  }

bool IsHighPivot(MqlRates &rates[], const int index, const int wing, const int total)
  {
   if(index - wing < 0 || index + wing >= total)
      return false;

   const double price = rates[index].high;
   if(price <= 0.0)
      return false;

   for(int k = 1; k <= wing; ++k)
     {
      if(rates[index - k].high >= price)
         return false;
      if(rates[index + k].high >= price)
         return false;
     }
   return true;
  }

bool IsLowPivot(MqlRates &rates[], const int index, const int wing, const int total)
  {
   if(index - wing < 0 || index + wing >= total)
      return false;

   const double price = rates[index].low;
   if(price <= 0.0)
      return false;

   for(int k = 1; k <= wing; ++k)
     {
      if(rates[index - k].low <= price)
         return false;
      if(rates[index + k].low <= price)
         return false;
     }
   return true;
  }

void AppendPivot(SwingPivot &pivots[], int &count, SwingPivot &candidate, const double min_deviation)
  {
   if(candidate.price <= 0.0 || candidate.kind == 0)
      return;

   if(count > 0)
     {
      const int last = count - 1;
      const int spacing = AbsD((double)(pivots[last].shift - candidate.shift));

      if(candidate.kind == pivots[last].kind)
        {
         const bool more_extreme = (candidate.kind > 0)
                                   ? (candidate.price > pivots[last].price)
                                   : (candidate.price < pivots[last].price);
         if(more_extreme)
            pivots[last] = candidate;
         return;
        }

      if(spacing < MaxInt(1, strategy_zigzag_backstep))
         return;
      if(AbsD(candidate.price - pivots[last].price) < min_deviation)
         return;
     }

   if(count >= ArraySize(pivots))
      return;

   pivots[count] = candidate;
   count++;
  }

int CollectPivots(MqlRates &rates[], const int total, SwingPivot &pivots[])
  {
   ArrayResize(pivots, BERMUDA_MAX_PIVOTS);
   int count = 0;

   const int wing = PivotWing();
   const double min_deviation = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_zigzag_deviation_pips);
   if(total <= wing * 2 + 2 || min_deviation <= 0.0)
      return 0;

   for(int i = total - wing - 1; i >= wing; --i)
     {
      const bool high_pivot = IsHighPivot(rates, i, wing, total);
      const bool low_pivot  = IsLowPivot(rates, i, wing, total);
      if(high_pivot == low_pivot)
         continue;

      SwingPivot pivot;
      pivot.shift    = i + 1;
      pivot.bar_time = rates[i].time;
      pivot.kind     = high_pivot ? 1 : -1;
      pivot.price    = high_pivot ? rates[i].high : rates[i].low;
      AppendPivot(pivots, count, pivot, min_deviation);
     }

   return count;
  }

bool FindRecentTwoPivots(SwingPivot &pivots[],
                         const int upto_index,
                         const int kind,
                         SwingPivot &older,
                         SwingPivot &newer)
  {
   int found = 0;
   for(int i = upto_index; i >= 0; --i)
     {
      if(pivots[i].kind != kind)
         continue;
      if(pivots[i].shift > strategy_triangle_max_bars)
         continue;

      if(found == 0)
        {
         newer = pivots[i];
         found = 1;
         continue;
        }

      older = pivots[i];
      return true;
     }
   return false;
  }

bool BuildLine(const SwingPivot &older,
               const SwingPivot &newer,
               double &slope,
               double &intercept)
  {
   const int dx = newer.shift - older.shift;
   if(dx == 0)
      return false;

   slope = (newer.price - older.price) / (double)dx;
   intercept = older.price - slope * (double)older.shift;
   return true;
  }

double LinePrice(const double slope, const double intercept, const double shift)
  {
   return slope * shift + intercept;
  }

bool TriangleContextOk(SwingPivot &pivots[], const int setup_index, const SwingPivot &p3)
  {
   SwingPivot high_older, high_newer, low_older, low_newer;
   if(!FindRecentTwoPivots(pivots, setup_index, 1, high_older, high_newer))
      return false;
   if(!FindRecentTwoPivots(pivots, setup_index, -1, low_older, low_newer))
      return false;

   if(high_newer.price >= high_older.price)
      return false;
   if(low_newer.price <= low_older.price)
      return false;

   const int triangle_age = MaxInt(high_older.shift, low_older.shift);
   if(triangle_age < strategy_triangle_min_bars || triangle_age > strategy_triangle_max_bars)
      return false;

   double res_slope = 0.0;
   double res_intercept = 0.0;
   double sup_slope = 0.0;
   double sup_intercept = 0.0;
   if(!BuildLine(high_older, high_newer, res_slope, res_intercept))
      return false;
   if(!BuildLine(low_older, low_newer, sup_slope, sup_intercept))
      return false;

   if(res_slope <= 0.0 || sup_slope >= 0.0)
      return false;

   const double denom = res_slope - sup_slope;
   if(AbsD(denom) < 0.0000000001)
      return false;

   const double apex_shift = (sup_intercept - res_intercept) / denom;
   if(apex_shift > 1.0 || apex_shift < -1.0 * (double)strategy_apex_max_bars)
      return false;

   const double width_now = LinePrice(res_slope, res_intercept, 1.0) -
                            LinePrice(sup_slope, sup_intercept, 1.0);
   const double width_old = LinePrice(res_slope, res_intercept, (double)triangle_age) -
                            LinePrice(sup_slope, sup_intercept, (double)triangle_age);
   const double min_width = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_zigzag_deviation_pips * 2);
   if(width_now <= min_width || width_old <= width_now)
      return false;

   const double res_at_p3 = LinePrice(res_slope, res_intercept, (double)p3.shift);
   const double sup_at_p3 = LinePrice(sup_slope, sup_intercept, (double)p3.shift);
   const double pad = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_zigzag_deviation_pips * 2);
   if(p3.price > res_at_p3 + pad)
      return false;
   if(p3.price < sup_at_p3 - pad)
      return false;

   return true;
  }

bool FibRetraceOk(const int direction,
                  const SwingPivot &p1,
                  const SwingPivot &p2,
                  const SwingPivot &p3)
  {
   double retrace = 0.0;

   if(direction > 0)
     {
      const double leg = p2.price - p1.price;
      if(leg <= 0.0 || p3.price <= p1.price || p3.price >= p2.price)
         return false;
      retrace = (p2.price - p3.price) / leg;
     }
   else
     {
      const double leg = p1.price - p2.price;
      if(leg <= 0.0 || p3.price >= p1.price || p3.price <= p2.price)
         return false;
      retrace = (p3.price - p2.price) / leg;
     }

   if(retrace < 0.0 || retrace > 0.65)
      return false;

   const double levels[4] = {0.236, 0.382, 0.500, 0.618};
   for(int i = 0; i < 4; ++i)
     {
      if(AbsD(retrace - levels[i]) <= strategy_p3_fib_tolerance)
         return true;
     }
   return false;
  }

bool TryBuildSetup(SwingPivot &pivots[],
                   const int count,
                   int &direction,
                   double &entry,
                   double &sl,
                   double &tp1,
                   double &tp2,
                   double &tp3)
  {
   direction = 0;
   entry = 0.0;
   sl = 0.0;
   tp1 = 0.0;
   tp2 = 0.0;
   tp3 = 0.0;

   if(count < 5)
      return false;

   const double entry_buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_entry_buffer_pips);
   const double stop_buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_stop_buffer_pips);
   if(entry_buffer <= 0.0 || stop_buffer <= 0.0)
      return false;

   for(int i = count - 1; i >= 2; --i)
     {
      const SwingPivot p1 = pivots[i - 2];
      const SwingPivot p2 = pivots[i - 1];
      const SwingPivot p3 = pivots[i];

      if(p3.shift > strategy_pending_valid_bars)
         continue;
      const int pattern_span = p1.shift - p3.shift;
      if(pattern_span <= 0 || pattern_span > strategy_triangle_max_bars)
         continue;

      int dir = 0;
      if(p1.kind == -1 && p2.kind == 1 && p3.kind == -1 && p3.price > p1.price)
         dir = 1;
      else if(p1.kind == 1 && p2.kind == -1 && p3.kind == 1 && p3.price < p1.price)
         dir = -1;
      else
         continue;

      if(!FibRetraceOk(dir, p1, p2, p3))
         continue;
      if(!TriangleContextOk(pivots, i, p3))
         continue;

      if(dir > 0)
        {
         const double leg = p2.price - p1.price;
         const double e = p2.price + entry_buffer;
         const double s = p3.price - stop_buffer;
         const double t1 = p1.price + leg * strategy_target1_fib;
         const double t2 = p1.price + leg * strategy_target2_fib;
         const double t3 = p1.price + leg * strategy_target3_fib;
         if(s <= 0.0 || s >= e || t1 <= e || t2 <= t1 || t3 <= t2)
            continue;

         direction = dir;
         entry = e;
         sl = s;
         tp1 = t1;
         tp2 = t2;
         tp3 = t3;
         return true;
        }

      const double leg = p1.price - p2.price;
      const double e = p2.price - entry_buffer;
      const double s = p3.price + stop_buffer;
      const double t1 = p1.price - leg * strategy_target1_fib;
      const double t2 = p1.price - leg * strategy_target2_fib;
      const double t3 = p1.price - leg * strategy_target3_fib;
      if(e <= 0.0 || s <= e || t1 >= e || t2 >= t1 || t3 >= t2 || t3 <= 0.0)
         continue;

      direction = dir;
      entry = e;
      sl = s;
      tp1 = t1;
      tp2 = t2;
      tp3 = t3;
      return true;
     }

   return false;
  }

bool SeedFallbackTargetsFromPosition()
  {
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double tp = PositionGetDouble(POSITION_TP);
   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   if(open_price <= 0.0 || tp <= 0.0 || strategy_target3_fib <= 0.0)
      return false;

   const int dir = (ptype == POSITION_TYPE_BUY) ? 1 : -1;
   const double total_dist = AbsD(tp - open_price);
   if(total_dist <= 0.0)
      return false;

   g_signal_dir = dir;
   g_signal_entry = open_price;
   g_signal_tp3 = tp;
   g_signal_tp1 = open_price + (double)dir * total_dist * (strategy_target1_fib / strategy_target3_fib);
   g_signal_tp2 = open_price + (double)dir * total_dist * (strategy_target2_fib / strategy_target3_fib);
   return true;
  }

double PartialLots(const double initial_volume, const double fraction, const double current_volume)
  {
   if(initial_volume <= 0.0 || fraction <= 0.0 || current_volume <= 0.0)
      return 0.0;

   const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double raw_lots = initial_volume * fraction;
   double lots = QM_TM_NormalizeVolume(_Symbol, raw_lots);
   if(lots <= 0.0)
      return 0.0;
   if(min_lot > 0.0 && lots >= current_volume - min_lot * 0.5)
      return 0.0;
   return lots;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   InitRequest(req);

   if(strategy_triangle_min_bars < 10 ||
      strategy_triangle_max_bars < strategy_triangle_min_bars ||
      strategy_pending_valid_bars < 1 ||
      strategy_target1_fib <= 1.0 ||
      strategy_target2_fib <= strategy_target1_fib ||
      strategy_target3_fib <= strategy_target2_fib)
      return false;

   if(HasOpenPositionForMagic() || HasPendingOrderForMagic())
      return false;
   if(!SpreadAllowsEntry())
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int bars_needed = ScanBars();
   const int copied = CopyRates(_Symbol, PERIOD_H1, 1, bars_needed, rates); // perf-allowed: bounded H1 structural pivot scan, called only from the framework QM_IsNewBar-gated entry hook.
   if(copied < strategy_triangle_min_bars + PivotWing() * 2 + 4)
      return false;

   SwingPivot pivots[];
   const int pivot_count = CollectPivots(rates, copied, pivots);
   int direction = 0;
   double entry = 0.0;
   double sl = 0.0;
   double tp1 = 0.0;
   double tp2 = 0.0;
   double tp3 = 0.0;
   if(!TryBuildSetup(pivots, pivot_count, direction, entry, sl, tp1, tp2, tp3))
      return false;

   const double ask_px = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid_px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(direction > 0 && ask_px > 0.0 && entry <= ask_px)
      return false;
   if(direction < 0 && bid_px > 0.0 && entry >= bid_px)
      return false;

   req.type = (direction > 0) ? QM_BUY_STOP : QM_SELL_STOP;
   req.price = QM_TM_NormalizePrice(_Symbol, entry);
   req.sl = QM_TM_NormalizePrice(_Symbol, sl);
   req.tp = QM_TM_NormalizePrice(_Symbol, tp3);
   req.reason = (direction > 0) ? "BERMUDA_123_FIB_LONG" : "BERMUDA_123_FIB_SHORT";

   g_signal_dir = direction;
   g_signal_entry = req.price;
   g_signal_tp1 = QM_TM_NormalizePrice(_Symbol, tp1);
   g_signal_tp2 = QM_TM_NormalizePrice(_Symbol, tp2);
   g_signal_tp3 = req.tp;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(g_managed_ticket != ticket)
        {
         g_managed_ticket = ticket;
         g_initial_volume = PositionGetDouble(POSITION_VOLUME);
         g_tp1_hit = false;
         g_tp2_hit = false;
         if(g_signal_tp1 <= 0.0 || g_signal_tp2 <= 0.0 || g_signal_tp3 <= 0.0)
            SeedFallbackTargetsFromPosition();
        }

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market_price <= 0.0)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_volume = PositionGetDouble(POSITION_VOLUME);
      if(open_price <= 0.0 || current_volume <= 0.0)
         continue;

      if(!g_tp1_hit && g_signal_tp1 > 0.0)
        {
         const bool hit = is_buy ? (market_price >= g_signal_tp1) : (market_price <= g_signal_tp1);
         if(hit)
           {
            const double lots = PartialLots(g_initial_volume, strategy_tp1_fraction, current_volume);
            bool ok = true;
            if(lots > 0.0)
               ok = QM_TM_PartialClose(ticket, lots, QM_EXIT_PARTIAL);
            if(ok && PositionSelectByTicket(ticket))
              {
               QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, open_price), "BERMUDA_TP1_TO_BE");
               g_tp1_hit = true;
              }
           }
        }

      if(g_tp1_hit && !g_tp2_hit && g_signal_tp2 > 0.0)
        {
         if(!PositionSelectByTicket(ticket))
            continue;
         const double refreshed_volume = PositionGetDouble(POSITION_VOLUME);
         const bool hit = is_buy ? (market_price >= g_signal_tp2) : (market_price <= g_signal_tp2);
         if(hit)
           {
            const double lots = PartialLots(g_initial_volume, strategy_tp2_fraction, refreshed_volume);
            bool ok = true;
            if(lots > 0.0)
               ok = QM_TM_PartialClose(ticket, lots, QM_EXIT_PARTIAL);
            if(ok && PositionSelectByTicket(ticket))
              {
               QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, g_signal_tp1), "BERMUDA_TP2_TO_TP1");
               g_tp2_hit = true;
              }
           }
        }
     }
  }

bool Strategy_ExitSignal()
  {
   if(strategy_time_stop_bars <= 0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const datetime now = TimeCurrent();
   const int h1_seconds = H1Seconds();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int held_bars = (int)((now - open_time) / h1_seconds);
      if(held_bars >= strategy_time_stop_bars)
         return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11902\",\"ea\":\"bermuda-triangle-123-fib-extension-h1\"}");
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
                        const MqlTradeRequest      &request,
                        const MqlTradeResult       &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
