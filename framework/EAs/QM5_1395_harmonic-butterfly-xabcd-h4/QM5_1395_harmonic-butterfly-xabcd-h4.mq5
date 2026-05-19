#property strict
#property version   "5.0"
#property description "QM5_1395 Harmonic Butterfly XABCD H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1395;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_pivot_window       = 5;
input int    strategy_pivot_lookback     = 200;
input int    strategy_atr_period         = 14;
input int    strategy_sma_macro_period   = 200;
input double strategy_b_min              = 0.770;
input double strategy_b_max              = 0.802;
input double strategy_c_min              = 0.382;
input double strategy_c_max              = 0.886;
input double strategy_bc_min             = 1.618;
input double strategy_bc_max             = 2.618;
input double strategy_d_min              = 1.272;
input double strategy_d_max              = 1.618;
input double strategy_xa_d1_atr_min      = 2.0;
input double strategy_d_beyond_d1_atr    = 0.2;
input double strategy_body_ratio_min     = 0.45;
input double strategy_d_tag_atr_mult     = 0.3;
input double strategy_sma_atr_band       = 6.0;
input double strategy_vol_min_mult       = 0.7;
input double strategy_vol_max_mult       = 3.0;
input double strategy_spread_atr_mult    = 0.4;
input double strategy_sl_atr_mult        = 1.0;
input double strategy_invalidation_atr   = 1.5;
input double strategy_tp1_ad_retrace     = 0.382;
input double strategy_tp2_ad_retrace     = 0.618;
input double strategy_tp1_close_fraction = 0.50;
input int    strategy_time_stop_bars     = 32;
input int    strategy_reuse_guard_bars   = 24;
input int    strategy_max_trades_week    = 2;
input int    strategy_session_start_hour = 7;
input int    strategy_session_end_hour   = 21;
input int    strategy_friday_cutoff_hour = 16;

struct PivotPoint
  {
   int      type;
   int      shift;
   datetime time;
   double   price;
  };

struct ButterflyPattern
  {
   int      side;
   PivotPoint x;
   PivotPoint a;
   PivotPoint b;
   PivotPoint c;
   PivotPoint d;
   double   atr_h4;
   double   tp1;
   double   tp2;
   double   invalidation;
  };

datetime g_last_x_time = 0;
int      g_last_week_key = -1;
int      g_trades_this_week = 0;
int      g_active_side = 0;
datetime g_active_x_time = 0;
double   g_active_tp1 = 0.0;
double   g_active_invalidation = 0.0;
bool     g_tp1_done = false;

double BarOpen(const int shift)  { return iOpen(_Symbol, PERIOD_H4, shift); }
double BarHigh(const int shift)  { return iHigh(_Symbol, PERIOD_H4, shift); }
double BarLow(const int shift)   { return iLow(_Symbol, PERIOD_H4, shift); }
double BarClose(const int shift) { return iClose(_Symbol, PERIOD_H4, shift); }

int WeekKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 60 + dt.day_of_year / 7;
  }

bool SameSymbolMagicPosition(ulong &ticket)
  {
   const int magic = QM_FrameworkMagic();
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
      return true;
     }
   ticket = 0;
   return false;
  }

bool IsSwingHigh(const int shift)
  {
   const double h = BarHigh(shift);
   if(h <= 0.0)
      return false;
   for(int k = 1; k <= strategy_pivot_window; ++k)
      if(h <= BarHigh(shift - k) || h <= BarHigh(shift + k))
         return false;
   return true;
  }

bool IsSwingLow(const int shift)
  {
   const double l = BarLow(shift);
   if(l <= 0.0)
      return false;
   for(int k = 1; k <= strategy_pivot_window; ++k)
      if(l >= BarLow(shift - k) || l >= BarLow(shift + k))
         return false;
   return true;
  }

void AddPivot(PivotPoint &pivots[], int &count, const int type, const int shift, const double price)
  {
   if(count >= ArraySize(pivots))
      return;
   pivots[count].type = type;
   pivots[count].shift = shift;
   pivots[count].time = iTime(_Symbol, PERIOD_H4, shift);
   pivots[count].price = price;
   count++;
  }

int CollectConfirmedPivots(PivotPoint &pivots[])
  {
   int count = 0;
   const int oldest = MathMax(strategy_pivot_window + 2, strategy_pivot_lookback);
   for(int shift = oldest; shift >= strategy_pivot_window + 1; --shift)
     {
      if(IsSwingHigh(shift))
         AddPivot(pivots, count, 1, shift, BarHigh(shift));
      if(IsSwingLow(shift))
         AddPivot(pivots, count, -1, shift, BarLow(shift));
     }
   return count;
  }

bool ExtractXABC(const int side, const int before_shift, ButterflyPattern &pattern)
  {
   PivotPoint pivots[80];
   const int count = CollectConfirmedPivots(pivots);
   const int x_type = (side > 0) ? -1 : 1;
   const int a_type = -x_type;
   const int b_type = x_type;
   const int c_type = a_type;

   int c_idx = -1;
   int b_idx = -1;
   int a_idx = -1;
   int x_idx = -1;

   for(int i = count - 1; i >= 0; --i)
     {
      if(pivots[i].shift <= before_shift + strategy_pivot_window)
         continue;
      if(c_idx < 0 && pivots[i].type == c_type)
        {
         c_idx = i;
         continue;
        }
      if(c_idx >= 0 && b_idx < 0 && i < c_idx && pivots[i].type == b_type)
        {
         b_idx = i;
         continue;
        }
      if(b_idx >= 0 && a_idx < 0 && i < b_idx && pivots[i].type == a_type)
        {
         a_idx = i;
         continue;
        }
      if(a_idx >= 0 && x_idx < 0 && i < a_idx && pivots[i].type == x_type)
        {
         x_idx = i;
         break;
        }
     }

   if(x_idx < 0 || a_idx < 0 || b_idx < 0 || c_idx < 0)
      return false;

   pattern.x = pivots[x_idx];
   pattern.a = pivots[a_idx];
   pattern.b = pivots[b_idx];
   pattern.c = pivots[c_idx];
   return true;
  }

bool RatioInRange(const double value, const double lo, const double hi)
  {
   return (value >= lo && value <= hi);
  }

double BodyRatio(const int shift)
  {
   const double range = BarHigh(shift) - BarLow(shift);
   if(range <= 0.0)
      return 0.0;
   return MathAbs(BarClose(shift) - BarOpen(shift)) / (range + 1e-9);
  }

bool RuntimeReuseBlocked(const ButterflyPattern &pattern)
  {
   if(g_last_x_time <= 0)
      return false;
   if(pattern.x.time != g_last_x_time)
      return false;
   const int last_shift = iBarShift(_Symbol, PERIOD_H4, g_last_x_time, false);
   if(last_shift < 0)
      return false;
   return (last_shift - pattern.d.shift <= strategy_reuse_guard_bars);
  }

bool WeekFrequencyBlocked()
  {
   const int key = WeekKey(TimeCurrent());
   if(key != g_last_week_key)
     {
      g_last_week_key = key;
      g_trades_this_week = 0;
     }
   return (g_trades_this_week >= strategy_max_trades_week);
  }

bool ValidatePattern(const int side, const int d_shift, ButterflyPattern &pattern)
  {
   pattern.side = side;
   if(!ExtractXABC(side, d_shift, pattern))
      return false;

   pattern.d.type = (side > 0) ? -1 : 1;
   pattern.d.shift = d_shift;
   pattern.d.time = iTime(_Symbol, PERIOD_H4, d_shift);
   pattern.d.price = (side > 0) ? BarLow(d_shift) : BarHigh(d_shift);
   pattern.atr_h4 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double atr_h4_40 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 40);
   const double atr_h4_60 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 60);
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double sma200 = QM_SMA(_Symbol, PERIOD_H4, strategy_sma_macro_period, 1);
   if(pattern.atr_h4 <= 0.0 || atr_h4_40 <= 0.0 || atr_h4_60 <= 0.0 || atr_d1 <= 0.0 || sma200 <= 0.0)
      return false;

   const double xa = MathAbs(pattern.x.price - pattern.a.price);
   const double ab = MathAbs(pattern.a.price - pattern.b.price);
   if(xa <= 0.0 || ab <= 0.0)
      return false;

   if(side > 0)
     {
      if(!(pattern.x.price < pattern.a.price && pattern.b.price > pattern.x.price &&
           pattern.c.price < pattern.a.price && pattern.d.price < pattern.x.price))
         return false;
      if(!(pattern.d.price < pattern.x.price - strategy_d_beyond_d1_atr * atr_d1))
         return false;
      if(!(BarClose(1) > sma200 - strategy_sma_atr_band * pattern.atr_h4))
         return false;
      if(!(BarClose(1) > BarOpen(1) && BodyRatio(1) >= strategy_body_ratio_min))
         return false;
      if(!(BarClose(1) > BarClose(2) && BarClose(1) > BarOpen(2)))
         return false;
      if(MathAbs(BarLow(1) - pattern.d.price) > strategy_d_tag_atr_mult * pattern.atr_h4)
         return false;
      pattern.tp1 = pattern.d.price + strategy_tp1_ad_retrace * (pattern.a.price - pattern.d.price);
      pattern.tp2 = pattern.d.price + strategy_tp2_ad_retrace * (pattern.a.price - pattern.d.price);
      pattern.invalidation = pattern.d.price - strategy_invalidation_atr * pattern.atr_h4;
     }
   else
     {
      if(!(pattern.x.price > pattern.a.price && pattern.b.price < pattern.x.price &&
           pattern.c.price > pattern.a.price && pattern.d.price > pattern.x.price))
         return false;
      if(!(pattern.d.price > pattern.x.price + strategy_d_beyond_d1_atr * atr_d1))
         return false;
      if(!(BarClose(1) < sma200 + strategy_sma_atr_band * pattern.atr_h4))
         return false;
      if(!(BarClose(1) < BarOpen(1) && BodyRatio(1) >= strategy_body_ratio_min))
         return false;
      if(!(BarClose(1) < BarClose(2) && BarClose(1) < BarOpen(2)))
         return false;
      if(MathAbs(BarHigh(1) - pattern.d.price) > strategy_d_tag_atr_mult * pattern.atr_h4)
         return false;
      pattern.tp1 = pattern.d.price - strategy_tp1_ad_retrace * (pattern.d.price - pattern.a.price);
      pattern.tp2 = pattern.d.price - strategy_tp2_ad_retrace * (pattern.d.price - pattern.a.price);
      pattern.invalidation = pattern.d.price + strategy_invalidation_atr * pattern.atr_h4;
     }

   const double b_retrace = MathAbs(pattern.b.price - pattern.a.price) / xa;
   const double c_retrace = MathAbs(pattern.c.price - pattern.b.price) / ab;
   const double bc_projection = MathAbs(pattern.d.price - pattern.c.price) / ab;
   const double d_extension = MathAbs(pattern.d.price - pattern.a.price) / xa;

   if(!RatioInRange(b_retrace, strategy_b_min, strategy_b_max))
      return false;
   if(!RatioInRange(c_retrace, strategy_c_min, strategy_c_max))
      return false;
   if(!RatioInRange(bc_projection, strategy_bc_min, strategy_bc_max))
      return false;
   if(!RatioInRange(d_extension, strategy_d_min, strategy_d_max))
      return false;
   if(xa < strategy_xa_d1_atr_min * atr_d1)
      return false;
   if(pattern.atr_h4 < strategy_vol_min_mult * atr_h4_40 || pattern.atr_h4 > strategy_vol_max_mult * atr_h4_40)
      return false;
   if(pattern.atr_h4 > strategy_vol_max_mult * atr_h4_60)
      return false;

   return true;
  }

bool BuildSignal(ButterflyPattern &pattern)
  {
   for(int d_shift = 1; d_shift <= 2; ++d_shift)
     {
      ButterflyPattern bullish;
      if(ValidatePattern(1, d_shift, bullish) && !RuntimeReuseBlocked(bullish))
        {
         pattern = bullish;
         return true;
        }

      ButterflyPattern bearish;
      if(ValidatePattern(-1, d_shift, bearish) && !RuntimeReuseBlocked(bearish))
        {
         pattern = bearish;
         return true;
        }
     }
   return false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(Period() != PERIOD_H4)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour < strategy_session_start_hour || dt.hour >= strategy_session_end_hour)
      return true;
   if(dt.day_of_week == 5 && dt.hour >= strategy_friday_cutoff_hour)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;
   if((ask - bid) >= strategy_spread_atr_mult * atr)
      return true;

   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ulong existing_ticket = 0;
   if(SameSymbolMagicPosition(existing_ticket))
      return false;
   if(WeekFrequencyBlocked())
      return false;

   ButterflyPattern pattern;
   if(!BuildSignal(pattern))
      return false;

   const double entry = (pattern.side > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                           : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(entry <= 0.0 || point <= 0.0)
      return false;

   if(pattern.side > 0)
     {
      req.type = QM_BUY;
      req.sl = pattern.d.price - strategy_sl_atr_mult * pattern.atr_h4;
      req.tp = pattern.tp2;
      req.reason = "BULLISH_BUTTERFLY_XABCD_H4";
     }
   else
     {
      req.type = QM_SELL;
      req.sl = pattern.d.price + strategy_sl_atr_mult * pattern.atr_h4;
      req.tp = pattern.tp2;
      req.reason = "BEARISH_BUTTERFLY_XABCD_H4";
     }

   if(MathAbs(entry - req.sl) / point <= 0.0)
      return false;

   g_active_side = pattern.side;
   g_active_x_time = pattern.x.time;
   g_active_tp1 = pattern.tp1;
   g_active_invalidation = pattern.invalidation;
   g_last_x_time = pattern.x.time;
   g_tp1_done = false;
   g_trades_this_week++;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   if(!SameSymbolMagicPosition(ticket) || !PositionSelectByTicket(ticket))
      return;
   if(g_tp1_done || g_active_side == 0 || g_active_tp1 <= 0.0)
      return;

   const double volume = PositionGetDouble(POSITION_VOLUME);
   if(volume <= 0.0)
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const bool tp1_hit = (g_active_side > 0) ? (bid >= g_active_tp1) : (ask <= g_active_tp1);
   if(!tp1_hit)
      return;

   const double lots_to_close = volume * strategy_tp1_close_fraction;
   if(QM_TM_PartialClose(ticket, lots_to_close, QM_EXIT_PARTIAL))
     {
      g_tp1_done = true;
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      if(open_price > 0.0)
         QM_TM_MoveSL(ticket, open_price, "butterfly_tp1_move_to_breakeven");
     }
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   if(!SameSymbolMagicPosition(ticket) || !PositionSelectByTicket(ticket))
      return false;

   const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
   const int open_shift = iBarShift(_Symbol, PERIOD_H4, open_time, false);
   if(open_shift >= strategy_time_stop_bars)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   if(g_active_side > 0 && g_active_invalidation > 0.0 && BarClose(1) < g_active_invalidation)
      return true;
   if(g_active_side < 0 && g_active_invalidation > 0.0 && BarClose(1) > g_active_invalidation)
      return true;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1395\",\"ea\":\"QM5_1395_harmonic_butterfly_xabcd_h4\"}");
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

   if(!QM_IsNewBar())
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
