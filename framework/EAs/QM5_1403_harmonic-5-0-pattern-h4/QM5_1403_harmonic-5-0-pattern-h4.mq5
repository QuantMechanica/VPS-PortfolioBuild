#property strict
#property version   "5.0"
#property description "QM5_1403 Harmonic 5-0 Pattern H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1403;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_fractal_wing_bars        = 2;
input int    strategy_min_xd_bars              = 25;
input int    strategy_max_xd_bars              = 80;
input int    strategy_scan_bars                = 96;
input double strategy_fib_tolerance_pct        = 0.03;
input double strategy_ab_xa_min                = 1.13;
input double strategy_ab_xa_max                = 1.618;
input double strategy_bc_ab_min                = 1.618;
input double strategy_bc_ab_max                = 2.24;
input int    strategy_atr_period               = 14;
input double strategy_sl_atr_mult              = 0.5;
input double strategy_sl_cap_atr_mult          = 2.5;
input double strategy_tp1_cd_retracement       = 0.500;
input double strategy_tp2_cd_retracement       = 0.886;
input double strategy_tp1_close_fraction       = 0.50;
input bool   strategy_macro_bias_enabled       = true;
input int    strategy_macro_fast_sma_d1        = 50;
input int    strategy_macro_slow_sma_d1        = 200;
input int    strategy_reuse_guard_bars         = 20;
input bool   strategy_spread_filter_enabled    = true;
input double strategy_spread_avg_multiplier    = 1.5;
input bool   strategy_time_filter_enabled      = false;
input int    strategy_start_hour_broker        = 0;
input int    strategy_end_hour_broker          = 24;

struct StrategyPivot
  {
   int      kind;
   int      shift;
   double   price;
   datetime time;
  };

double   g_avg_spread_points = 0.0;
double   g_active_tp1_price = 0.0;
bool     g_tp1_done = false;
datetime g_reuse_until_time = 0;

double Strategy_NormalizePrice(const double price)
  {
   return QM_StopRulesNormalizePrice(_Symbol, price);
  }

bool Strategy_InHourWindow(const int hour, const int start_hour, const int end_hour)
  {
   if(start_hour == end_hour)
      return true;
   if(start_hour < end_hour)
      return (hour >= start_hour && hour < end_hour);
   return (hour >= start_hour || hour < end_hour);
  }

bool Strategy_SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &position_type)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = candidate;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

bool Strategy_FractalHigh(const MqlRates &rates[], const int index, const int total, const int wing)
  {
   if(index < wing || index >= total - wing)
      return false;

   const double value = rates[index].high;
   for(int i = 1; i <= wing; ++i)
     {
      if(value <= rates[index - i].high || value <= rates[index + i].high)
         return false;
     }
   return true;
  }

bool Strategy_FractalLow(const MqlRates &rates[], const int index, const int total, const int wing)
  {
   if(index < wing || index >= total - wing)
      return false;

   const double value = rates[index].low;
   for(int i = 1; i <= wing; ++i)
     {
      if(value >= rates[index - i].low || value >= rates[index + i].low)
         return false;
     }
   return true;
  }

void Strategy_AddPivot(StrategyPivot &pivots[], int &count, const int kind,
                       const int shift, const double price, const datetime time)
  {
   if(count > 0 && pivots[count - 1].kind == kind)
     {
      const bool replace = (kind > 0 && price > pivots[count - 1].price) ||
                           (kind < 0 && price < pivots[count - 1].price);
      if(replace)
        {
         pivots[count - 1].shift = shift;
         pivots[count - 1].price = price;
         pivots[count - 1].time = time;
        }
      return;
     }

   if(count >= 128)
      return;

   pivots[count].kind = kind;
   pivots[count].shift = shift;
   pivots[count].price = price;
   pivots[count].time = time;
   ++count;
  }

int Strategy_CollectPivots(const MqlRates &rates[], const int total, StrategyPivot &pivots[])
  {
   int count = 0;
   const int wing = MathMax(1, strategy_fractal_wing_bars);

   for(int i = total - wing - 1; i >= wing; --i)
     {
      const bool high = Strategy_FractalHigh(rates, i, total, wing);
      const bool low = Strategy_FractalLow(rates, i, total, wing);
      if(high && !low)
         Strategy_AddPivot(pivots, count, +1, i, rates[i].high, rates[i].time);
      else if(low && !high)
         Strategy_AddPivot(pivots, count, -1, i, rates[i].low, rates[i].time);
     }

   return count;
  }

bool Strategy_RatioInRange(const double value, const double lo, const double hi)
  {
   return (value >= lo && value <= hi);
  }

bool Strategy_BullishMacroOK()
  {
   if(!strategy_macro_bias_enabled)
      return true;

   const double fast = QM_SMA(_Symbol, PERIOD_D1, strategy_macro_fast_sma_d1, 1, PRICE_CLOSE);
   const double slow = QM_SMA(_Symbol, PERIOD_D1, strategy_macro_slow_sma_d1, 1, PRICE_CLOSE);
   return (fast > 0.0 && slow > 0.0 && fast > slow);
  }

bool Strategy_BearishMacroOK()
  {
   if(!strategy_macro_bias_enabled)
      return true;

   const double fast = QM_SMA(_Symbol, PERIOD_D1, strategy_macro_fast_sma_d1, 1, PRICE_CLOSE);
   const double slow = QM_SMA(_Symbol, PERIOD_D1, strategy_macro_slow_sma_d1, 1, PRICE_CLOSE);
   return (fast > 0.0 && slow > 0.0 && fast < slow);
  }

void Strategy_UpdateAverageSpread(const MqlRates &rates[], const int total)
  {
   const int n = (total < 20) ? total : 20;
   if(n <= 0)
      return;

   double sum = 0.0;
   for(int i = 0; i < n; ++i)
      sum += (double)rates[i].spread;
   g_avg_spread_points = sum / (double)n;
  }

bool Strategy_BuildEntry(const bool bullish, const double c_price, const double d_price,
                         const double zone_edge, const double atr, QM_EntryRequest &req)
  {
   const QM_OrderType order_type = bullish ? QM_BUY : QM_SELL;
   const double entry = bullish ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   double sl = bullish ? (zone_edge - strategy_sl_atr_mult * atr)
                       : (zone_edge + strategy_sl_atr_mult * atr);
   const double max_risk = strategy_sl_cap_atr_mult * atr;
   if(bullish && entry - sl > max_risk)
      sl = entry - max_risk;
   if(!bullish && sl - entry > max_risk)
      sl = entry + max_risk;

   const double cd = MathAbs(c_price - d_price);
   if(cd <= 0.0)
      return false;

   const double tp1 = bullish ? (d_price + strategy_tp1_cd_retracement * cd)
                              : (d_price - strategy_tp1_cd_retracement * cd);
   const double tp2 = bullish ? (d_price + strategy_tp2_cd_retracement * cd)
                              : (d_price - strategy_tp2_cd_retracement * cd);

   if(bullish && (sl >= entry || tp2 <= entry))
      return false;
   if(!bullish && (sl <= entry || tp2 >= entry))
      return false;

   req.type = order_type;
   req.price = 0.0;
   req.sl = Strategy_NormalizePrice(sl);
   req.tp = Strategy_NormalizePrice(tp2);
   req.reason = bullish ? "HARMONIC_5_0_BULLISH" : "HARMONIC_5_0_BEARISH";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_active_tp1_price = Strategy_NormalizePrice(tp1);
   g_tp1_done = false;
   return (req.sl > 0.0 && req.tp > 0.0 && g_active_tp1_price > 0.0);
  }

bool Strategy_CheckBullish(const StrategyPivot &x, const StrategyPivot &a,
                           const StrategyPivot &b, const StrategyPivot &c,
                           const MqlRates &d_bar, QM_EntryRequest &req)
  {
   if(x.kind != -1 || a.kind != +1 || b.kind != -1 || c.kind != +1)
      return false;
   if(x.shift < strategy_min_xd_bars || x.shift > strategy_max_xd_bars)
      return false;
   if(!(b.price < x.price && c.price > a.price))
      return false;

   const double xa = MathAbs(a.price - x.price);
   const double ab = MathAbs(a.price - b.price);
   const double bc = MathAbs(c.price - b.price);
   const double ac = MathAbs(c.price - a.price);
   if(xa <= 0.0 || ab <= 0.0 || bc <= 0.0 || ac <= 0.0)
      return false;

   if(!Strategy_RatioInRange(ab / xa, strategy_ab_xa_min, strategy_ab_xa_max))
      return false;
   if(!Strategy_RatioInRange(bc / ab, strategy_bc_ab_min, strategy_bc_ab_max))
      return false;

   const double d_target = a.price - strategy_tp1_cd_retracement * ac;
   const double zone_low = d_target - strategy_fib_tolerance_pct * ac;
   const double zone_high = d_target + strategy_fib_tolerance_pct * ac;
   const bool low_touched = (d_bar.low >= zone_low && d_bar.low <= zone_high);
   const bool bullish_bar = (d_bar.close > d_bar.open);
   const bool close_inside_ac = (d_bar.close >= MathMin(a.price, c.price) &&
                                 d_bar.close <= MathMax(a.price, c.price));
   if(!low_touched || !bullish_bar || !close_inside_ac)
      return false;
   if(!Strategy_BullishMacroOK())
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   return Strategy_BuildEntry(true, c.price, d_bar.low, zone_low, atr, req);
  }

bool Strategy_CheckBearish(const StrategyPivot &x, const StrategyPivot &a,
                           const StrategyPivot &b, const StrategyPivot &c,
                           const MqlRates &d_bar, QM_EntryRequest &req)
  {
   if(x.kind != +1 || a.kind != -1 || b.kind != +1 || c.kind != -1)
      return false;
   if(x.shift < strategy_min_xd_bars || x.shift > strategy_max_xd_bars)
      return false;
   if(!(b.price > x.price && c.price < a.price))
      return false;

   const double xa = MathAbs(a.price - x.price);
   const double ab = MathAbs(a.price - b.price);
   const double bc = MathAbs(c.price - b.price);
   const double ac = MathAbs(c.price - a.price);
   if(xa <= 0.0 || ab <= 0.0 || bc <= 0.0 || ac <= 0.0)
      return false;

   if(!Strategy_RatioInRange(ab / xa, strategy_ab_xa_min, strategy_ab_xa_max))
      return false;
   if(!Strategy_RatioInRange(bc / ab, strategy_bc_ab_min, strategy_bc_ab_max))
      return false;

   const double d_target = a.price + strategy_tp1_cd_retracement * ac;
   const double zone_low = d_target - strategy_fib_tolerance_pct * ac;
   const double zone_high = d_target + strategy_fib_tolerance_pct * ac;
   const bool high_touched = (d_bar.high >= zone_low && d_bar.high <= zone_high);
   const bool bearish_bar = (d_bar.close < d_bar.open);
   const bool close_inside_ac = (d_bar.close >= MathMin(a.price, c.price) &&
                                 d_bar.close <= MathMax(a.price, c.price));
   if(!high_touched || !bearish_bar || !close_inside_ac)
      return false;
   if(!Strategy_BearishMacroOK())
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   return Strategy_BuildEntry(false, c.price, d_bar.high, zone_high, atr, req);
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_time_filter_enabled)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(!Strategy_InHourWindow(dt.hour, strategy_start_hour_broker, strategy_end_hour_broker))
         return true;
     }

   if(strategy_spread_filter_enabled)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > 0 && g_avg_spread_points > 0.0 &&
         (double)spread > strategy_spread_avg_multiplier * g_avg_spread_points)
         return true;
     }

   if(g_reuse_until_time > 0 && TimeCurrent() < g_reuse_until_time)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int bars_needed = (strategy_scan_bars > strategy_max_xd_bars + 8) ? strategy_scan_bars : strategy_max_xd_bars + 8;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // Strategy_EntrySignal is called only after OnTick consumes QM_IsNewBar().
   const int copied = CopyRates(_Symbol, PERIOD_H4, 1, bars_needed, rates); // perf-allowed: bounded closed-bar structural XABCD scan.
   if(copied < strategy_min_xd_bars + 6)
      return false;

   Strategy_UpdateAverageSpread(rates, copied);

   StrategyPivot pivots[128];
   const int pivot_count = Strategy_CollectPivots(rates, copied, pivots);
   if(pivot_count < 4)
      return false;

   for(int i = pivot_count - 4; i >= 0; --i)
     {
      if(Strategy_CheckBullish(pivots[i], pivots[i + 1], pivots[i + 2], pivots[i + 3], rates[0], req))
        {
         g_reuse_until_time = TimeCurrent() + strategy_reuse_guard_bars * PeriodSeconds(PERIOD_H4);
         return true;
        }
      if(Strategy_CheckBearish(pivots[i], pivots[i + 1], pivots[i + 2], pivots[i + 3], rates[0], req))
        {
         g_reuse_until_time = TimeCurrent() + strategy_reuse_guard_bars * PeriodSeconds(PERIOD_H4);
         return true;
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type;
   if(!Strategy_SelectOurPosition(ticket, position_type))
     {
      g_tp1_done = false;
      g_active_tp1_price = 0.0;
      return;
     }

   if(g_tp1_done || g_active_tp1_price <= 0.0)
      return;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market <= 0.0)
      return;

   const bool tp1_hit = is_buy ? (market >= g_active_tp1_price) : (market <= g_active_tp1_price);
   if(!tp1_hit)
      return;

   const double volume = PositionGetDouble(POSITION_VOLUME);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double partial_lots = QM_TM_NormalizeVolume(_Symbol, volume * strategy_tp1_close_fraction);
   if(partial_lots > 0.0 && partial_lots < volume)
      QM_TM_PartialClose(ticket, partial_lots, QM_EXIT_PARTIAL);

   QM_TM_MoveSL(ticket, Strategy_NormalizePrice(open_price), "tp1_move_to_break_even");
   g_tp1_done = true;
  }

bool Strategy_ExitSignal()
  {
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1403\",\"ea\":\"harmonic_5_0_pattern_h4\"}");
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
