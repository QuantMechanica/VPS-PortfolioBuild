#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA - Andrews Pitchfork Sliding Parallel H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1434;
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
input int    strategy_atr_period         = 14;
input int    strategy_pivot_min_bars     = 40;
input int    strategy_pivot_max_bars     = 200;
input int    strategy_fractal_side       = 2;
input int    strategy_significance_bars  = 10;
input double strategy_pivot_sig_atr      = 0.70;
input double strategy_swing1_atr         = 1.50;
input double strategy_swing2_atr         = 1.00;
input double strategy_slope_min_atr      = 0.05;
input double strategy_slope_max_atr      = 0.50;
input double strategy_warn_reach_atr     = 0.30;
input double strategy_warn_breach_atr    = 0.20;
input double strategy_failure_atr        = 1.00;
input double strategy_sl_warn_atr        = 0.80;
input double strategy_sl_cap_atr         = 3.00;
input double strategy_spread_atr         = 0.20;
input int    strategy_time_stop_bars     = 25;
input int    strategy_failure_bars       = 8;
input int    strategy_reuse_guard_bars   = 20;

struct PitchforkPivot
  {
   int    shift;
   double price;
   int    kind;
  };

struct PitchforkState
  {
   bool     valid;
   int      direction;
   int      p0_shift;
   int      p1_shift;
   int      p2_shift;
   double   p0_price;
   double   p1_price;
   double   p2_price;
   double   slope;
   double   upper_offset;
   double   lower_offset;
   double   warning_offset;
   datetime p2_time;
  };

PitchforkState g_last_entry_pf;
bool           g_have_entry_pf = false;
bool           g_tp1_done = false;
ulong          g_tp1_ticket = 0;
datetime       g_last_pattern_time = 0;

double NormalizeStrategyPrice(const double price)
  {
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

double PointValue()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return (point > 0.0 ? point : 0.00001);
  }

double LineValueAtShift(const PitchforkState &pf, const double offset, const int shift)
  {
   return pf.p0_price + offset + pf.slope * (double)(pf.p0_shift - shift);
  }

bool IsSignificantPivot(const MqlRates &rates[], const int count, const int shift, const int kind, const double atr)
  {
   double hi = rates[shift].high;
   double lo = rates[shift].low;
   const int from_shift = MathMax(strategy_fractal_side, shift - strategy_significance_bars);
   const int to_shift = MathMin(count - strategy_fractal_side - 1, shift + strategy_significance_bars);

   for(int j = from_shift; j <= to_shift; ++j)
     {
      hi = MathMax(hi, rates[j].high);
      lo = MathMin(lo, rates[j].low);
     }

   if(kind > 0)
      return (rates[shift].high - lo >= strategy_pivot_sig_atr * atr);
   return (hi - rates[shift].low >= strategy_pivot_sig_atr * atr);
  }

bool IsFractalPivot(const MqlRates &rates[], const int count, const int shift, const int kind)
  {
   if(shift < strategy_fractal_side || shift >= count - strategy_fractal_side)
      return false;

   for(int j = 1; j <= strategy_fractal_side; ++j)
     {
      if(kind > 0)
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

double LinearRegressionSlope(const MqlRates &rates[], const int older_shift, const int newer_shift)
  {
   const int n = older_shift - newer_shift + 1;
   if(n < 2)
      return 0.0;

   double sum_x = 0.0, sum_y = 0.0, sum_xy = 0.0, sum_x2 = 0.0;
   int idx = 0;
   for(int shift = older_shift; shift >= newer_shift; --shift)
     {
      const double x = (double)idx;
      const double y = rates[shift].close;
      sum_x += x;
      sum_y += y;
      sum_xy += x * y;
      sum_x2 += x * x;
      idx++;
     }

   const double denom = (double)n * sum_x2 - sum_x * sum_x;
   if(MathAbs(denom) <= 0.0)
      return 0.0;
   return ((double)n * sum_xy - sum_x * sum_y) / denom;
  }

bool HasRailTouch(const MqlRates &rates[], const PitchforkState &pf, const double atr)
  {
   const double tolerance = 0.20 * atr;
   for(int shift = pf.p2_shift - 1; shift >= 1; --shift)
     {
      const double upper = LineValueAtShift(pf, pf.upper_offset, shift);
      const double lower = LineValueAtShift(pf, pf.lower_offset, shift);
      if(rates[shift].high >= upper - tolerance && rates[shift].low <= upper + tolerance)
         return true;
      if(rates[shift].high >= lower - tolerance && rates[shift].low <= lower + tolerance)
         return true;
     }
   return false;
  }

bool BuildPitchfork(PitchforkState &pf, MqlRates &rates[], const int count, const double atr)
  {
   PitchforkPivot pivots[80];
   int pivot_count = 0;

   for(int shift = strategy_pivot_max_bars; shift >= strategy_fractal_side; --shift)
     {
      if(shift >= count - strategy_fractal_side)
         continue;

      int kind = 0;
      double price = 0.0;
      if(IsFractalPivot(rates, count, shift, 1) && IsSignificantPivot(rates, count, shift, 1, atr))
        {
         kind = 1;
         price = rates[shift].high;
        }
      else if(IsFractalPivot(rates, count, shift, -1) && IsSignificantPivot(rates, count, shift, -1, atr))
        {
         kind = -1;
         price = rates[shift].low;
        }

      if(kind == 0)
         continue;

      if(pivot_count > 0 && pivots[pivot_count - 1].kind == kind)
        {
         if((kind > 0 && price > pivots[pivot_count - 1].price) ||
            (kind < 0 && price < pivots[pivot_count - 1].price))
           {
            pivots[pivot_count - 1].shift = shift;
            pivots[pivot_count - 1].price = price;
           }
         continue;
        }

      pivots[pivot_count].shift = shift;
      pivots[pivot_count].price = price;
      pivots[pivot_count].kind = kind;
      pivot_count++;
      if(pivot_count >= 80)
         break;
     }

   for(int i = pivot_count - 3; i >= 0; --i)
     {
      PitchforkPivot p0 = pivots[i];
      PitchforkPivot p1 = pivots[i + 1];
      PitchforkPivot p2 = pivots[i + 2];
      if(!(p0.kind == p2.kind && p0.kind != p1.kind))
         continue;
      if(p0.shift - p2.shift < strategy_pivot_min_bars || p0.shift - p2.shift > strategy_pivot_max_bars)
         continue;
      if(MathAbs(p1.price - p0.price) < strategy_swing1_atr * atr)
         continue;
      if(MathAbs(p2.price - p1.price) < strategy_swing2_atr * atr)
         continue;

      const double mid_price = 0.5 * (p1.price + p2.price);
      const double mid_shift = 0.5 * (double)(p1.shift + p2.shift);
      const double denom = (double)p0.shift - mid_shift;
      if(MathAbs(denom) <= 0.0)
         continue;

      const double slope = (mid_price - p0.price) / denom;
      const double abs_slope = MathAbs(slope);
      if(abs_slope < strategy_slope_min_atr * atr || abs_slope > strategy_slope_max_atr * atr)
         continue;

      pf.valid = true;
      pf.direction = (p0.kind < 0 ? 1 : -1);
      pf.p0_shift = p0.shift;
      pf.p1_shift = p1.shift;
      pf.p2_shift = p2.shift;
      pf.p0_price = p0.price;
      pf.p1_price = p1.price;
      pf.p2_price = p2.price;
      pf.slope = slope;
      pf.upper_offset = MathMax(p1.price - (p0.price + slope * (double)(p0.shift - p1.shift)),
                                p2.price - (p0.price + slope * (double)(p0.shift - p2.shift)));
      pf.lower_offset = MathMin(p1.price - (p0.price + slope * (double)(p0.shift - p1.shift)),
                                p2.price - (p0.price + slope * (double)(p0.shift - p2.shift)));
      const double rail_width = MathAbs(pf.upper_offset - pf.lower_offset);
      pf.warning_offset = (pf.direction > 0 ? pf.upper_offset + rail_width : pf.lower_offset - rail_width);
      pf.p2_time = rates[p2.shift].time;
      return true;
     }

   pf.valid = false;
   return false;
  }

bool CurrentSymbolInRegisteredBasket()
  {
   const string s = _Symbol;
   return (s == "EURUSD.DWX" || s == "GBPUSD.DWX" || s == "USDJPY.DWX" ||
           s == "AUDUSD.DWX" || s == "USDCAD.DWX" || s == "USDCHF.DWX" ||
           s == "NZDUSD.DWX" || s == "XAUUSD.DWX" || s == "NDX.DWX" ||
           s == "WS30.DWX" || s == "GDAXI.DWX" || s == "UK100.DWX" ||
           s == "XTIUSD.DWX");
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(!CurrentSymbolInRegisteredBasket())
      return true;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(atr <= 0.0)
      return true;

   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   const double spread_price = (double)spread_points * PointValue();
   return (spread_price > strategy_spread_atr * atr);
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int needed = strategy_pivot_max_bars + strategy_significance_bars + strategy_fractal_side + 8;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_timeframe, 0, needed, rates);
   if(copied < needed - 2)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   PitchforkState pf;
   if(!BuildPitchfork(pf, rates, copied, atr))
      return false;

   if(g_last_pattern_time > 0 && pf.p2_time == g_last_pattern_time)
      return false;

   const int max_age = (int)MathRound(3.0 * (double)(pf.p0_shift - pf.p2_shift));
   if(pf.p2_shift > max_age)
      return false;

   if(!HasRailTouch(rates, pf, atr))
      return false;

   const double warning = LineValueAtShift(pf, pf.warning_offset, 1);
   bool trigger = false;
   QM_OrderType side = QM_BUY;

   if(pf.direction > 0)
     {
      if(rates[1].high < warning - strategy_warn_reach_atr * atr)
         return false;
      if(rates[1].high > warning + strategy_warn_breach_atr * atr)
         return false;
      if(!(rates[1].close < rates[1].open && rates[1].high - rates[1].close >= 0.5 * (rates[1].high - rates[1].low)))
         return false;
      side = QM_SELL;
      trigger = true;
     }
   else
     {
      if(rates[1].low > warning + strategy_warn_reach_atr * atr)
         return false;
      if(rates[1].low < warning - strategy_warn_breach_atr * atr)
         return false;
      if(!(rates[1].close > rates[1].open && rates[1].close - rates[1].low >= 0.5 * (rates[1].high - rates[1].low)))
         return false;
      side = QM_BUY;
      trigger = true;
     }

   if(!trigger)
      return false;

   const double reg_slope = LinearRegressionSlope(rates, pf.p0_shift, 1);
   if(reg_slope * pf.slope <= 0.0)
      return false;

   const double sma_now = QM_SMA(_Symbol, PERIOD_D1, 50, 1);
   const double sma_prev = QM_SMA(_Symbol, PERIOD_D1, 50, 2);
   if(sma_now <= 0.0 || sma_prev <= 0.0)
      return false;
   if(side == QM_SELL && sma_now > sma_prev)
      return false;
   if(side == QM_BUY && sma_now < sma_prev)
      return false;

   const double market_price = (side == QM_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   if(market_price <= 0.0)
      return false;

   double sl = 0.0;
   if(side == QM_SELL)
     {
      sl = warning + strategy_sl_warn_atr * atr;
      sl = MathMin(sl, market_price + strategy_sl_cap_atr * atr);
     }
   else
     {
      sl = warning - strategy_sl_warn_atr * atr;
      sl = MathMax(sl, market_price - strategy_sl_cap_atr * atr);
     }

   const double tp2 = LineValueAtShift(pf, (side == QM_SELL ? pf.lower_offset : pf.upper_offset), -18);

   req.type = side;
   req.price = 0.0;
   req.sl = NormalizeStrategyPrice(sl);
   req.tp = NormalizeStrategyPrice(tp2);
   req.reason = "andrews_sliding_parallel_h4";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_last_entry_pf = pf;
   g_have_entry_pf = true;
   g_tp1_done = false;
   g_tp1_ticket = 0;
   g_last_pattern_time = pf.p2_time;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   if(!g_have_entry_pf)
      return;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic || PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      if(g_tp1_done && g_tp1_ticket == ticket)
         continue;

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double tp1 = LineValueAtShift(g_last_entry_pf, 0.0, -6);

      if(pos_type == POSITION_TYPE_SELL && ask <= tp1)
        {
         QM_TM_PartialClose(ticket, volume * 0.60, QM_EXIT_PARTIAL);
         QM_TM_MoveSL(ticket, NormalizeStrategyPrice(entry), "tp1_break_even");
         g_tp1_done = true;
         g_tp1_ticket = ticket;
        }
      else if(pos_type == POSITION_TYPE_BUY && bid >= tp1)
        {
         QM_TM_PartialClose(ticket, volume * 0.60, QM_EXIT_PARTIAL);
         QM_TM_MoveSL(ticket, NormalizeStrategyPrice(entry), "tp1_break_even");
         g_tp1_done = true;
         g_tp1_ticket = ticket;
        }
     }
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic || PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_open = (int)((TimeCurrent() - open_time) / PeriodSeconds(strategy_timeframe));
      if(bars_open >= strategy_time_stop_bars)
         return true;

      if(!g_have_entry_pf || atr <= 0.0)
         continue;

      if(bars_open <= strategy_failure_bars)
        {
         const long pos_type = PositionGetInteger(POSITION_TYPE);
         const double warning = LineValueAtShift(g_last_entry_pf, g_last_entry_pf.warning_offset, 0);
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(pos_type == POSITION_TYPE_SELL && ask > warning + strategy_failure_atr * atr)
            return true;
         if(pos_type == POSITION_TYPE_BUY && bid < warning - strategy_failure_atr * atr)
            return true;
        }
     }
   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
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
