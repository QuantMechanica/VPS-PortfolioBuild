#property strict
#property version   "5.0"
#property description "QM5_1406 Classical Descending Triangle Breakdown H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1406;
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
input ENUM_TIMEFRAMES strategy_tf        = PERIOD_H4;
input int    strategy_atr_period         = 14;
input int    strategy_min_window_bars    = 25;
input int    strategy_max_window_bars    = 80;
input int    strategy_fractal_wing       = 2;
input double strategy_support_band_atr   = 0.40;
input double strategy_high_tol_atr       = 0.20;
input double strategy_slope_min_d1_atr   = 0.30;
input double strategy_slope_max_d1_atr   = 2.00;
input double strategy_amplitude_atr      = 2.50;
input double strategy_convergence_frac   = 0.50;
input double strategy_no_break_atr       = 0.30;
input double strategy_break_atr          = 0.50;
input double strategy_sl_buffer_atr      = 0.30;
input double strategy_max_stop_atr       = 3.00;
input double strategy_spread_atr         = 0.25;
input int    strategy_sma_period         = 200;
input int    strategy_order_valid_bars   = 10;
input int    strategy_time_stop_bars     = 48;
input int    strategy_reuse_guard_bars   = 20;

struct DT_Pivot { int shift; double price; datetime time; };
struct DT_Pattern { bool valid; double support; double max_high; double slope; double intercept; datetime key_time; };

datetime g_guard_until_bar = 0;
datetime g_last_pattern_key = 0;
double g_active_support = 0.0;
double g_active_height = 0.0;
double g_active_slope = 0.0;
double g_active_intercept = 0.0;
bool g_partial_done = false;

bool DT_IsFractalHigh(const int shift)
  {
   const double h = iHigh(_Symbol, strategy_tf, shift);
   if(h <= 0.0) return false;
   for(int j = 1; j <= strategy_fractal_wing; ++j)
      if(h <= iHigh(_Symbol, strategy_tf, shift - j) || h <= iHigh(_Symbol, strategy_tf, shift + j)) return false;
   return true;
  }

bool DT_IsFractalLow(const int shift)
  {
   const double l = iLow(_Symbol, strategy_tf, shift);
   if(l <= 0.0) return false;
   for(int j = 1; j <= strategy_fractal_wing; ++j)
      if(l >= iLow(_Symbol, strategy_tf, shift - j) || l >= iLow(_Symbol, strategy_tf, shift + j)) return false;
   return true;
  }

double DT_Median(double &values[], const int count)
  {
   if(count <= 0) return 0.0;
   ArraySort(values);
   const int mid = count / 2;
   if((count % 2) == 1) return values[mid];
   return 0.5 * (values[mid - 1] + values[mid]);
  }

double DT_LineAtShift(const double slope, const double intercept, const int window_start_shift, const int shift)
  {
   return intercept + slope * (double)(window_start_shift - shift);
  }

bool DT_BuildPattern(DT_Pattern &out_pattern)
  {
   out_pattern.valid = false;
   const double atr_h4 = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_h4 <= 0.0 || atr_d1 <= 0.0) return false;
   for(int window = strategy_min_window_bars; window <= strategy_max_window_bars; ++window)
     {
      DT_Pivot lows[32]; DT_Pivot highs[32];
      int low_count = 0; int high_count = 0;
      double low_values[32]; double max_high = 0.0;
      for(int shift = window; shift >= strategy_fractal_wing + 1; --shift)
        {
         const double h = iHigh(_Symbol, strategy_tf, shift);
         if(h > max_high) max_high = h;
         if(DT_IsFractalLow(shift) && low_count < 32)
           {
            lows[low_count].shift = shift; lows[low_count].price = iLow(_Symbol, strategy_tf, shift);
            lows[low_count].time = iTime(_Symbol, strategy_tf, shift); low_values[low_count] = lows[low_count].price; ++low_count;
           }
         if(DT_IsFractalHigh(shift) && high_count < 32)
           {
            highs[high_count].shift = shift; highs[high_count].price = h; highs[high_count].time = iTime(_Symbol, strategy_tf, shift); ++high_count;
           }
        }
      if(low_count < 3 || high_count < 3 || max_high <= 0.0) continue;
      const double support = DT_Median(low_values, low_count);
      int support_touches = 0;
      for(int i = 0; i < low_count; ++i) if(MathAbs(lows[i].price - support) <= strategy_support_band_atr * atr_h4) ++support_touches;
      if(support_touches < 3) continue;
      bool descending = true;
      for(int i = 1; i < high_count; ++i)
        if(!(highs[i].price < highs[i - 1].price - strategy_high_tol_atr * atr_h4)) { descending = false; break; }
      if(!descending) continue;
      double sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
      for(int i = 0; i < high_count; ++i)
        {
         const double x = (double)(window - highs[i].shift); const double y = highs[i].price;
         sx += x; sy += y; sxx += x * x; sxy += x * y;
        }
      const double n = (double)high_count; const double denom = n * sxx - sx * sx;
      if(MathAbs(denom) <= 0.0000001) continue;
      const double slope = (n * sxy - sx * sy) / denom;
      const double intercept = (sy - slope * sx) / n;
      const double min_slope = -strategy_slope_max_d1_atr * atr_d1 / 50.0;
      const double max_slope = -strategy_slope_min_d1_atr * atr_d1 / 50.0;
      if(slope < min_slope || slope > max_slope) continue;
      const double height = max_high - support;
      if(height < strategy_amplitude_atr * atr_h4) continue;
      const double supply_right = DT_LineAtShift(slope, intercept, window, 1);
      if((supply_right - support) > strategy_convergence_frac * height) continue;
      bool broken = false;
      for(int shift2 = window; shift2 >= 1; --shift2)
        if(iClose(_Symbol, strategy_tf, shift2) < support - strategy_no_break_atr * atr_h4) { broken = true; break; }
      if(broken) continue;
      out_pattern.valid = true; out_pattern.support = support; out_pattern.max_high = max_high;
      out_pattern.slope = slope; out_pattern.intercept = intercept; out_pattern.key_time = highs[high_count - 1].time;
      return true;
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0) return true;
   if((ask - bid) > strategy_spread_atr * atr) return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const datetime current_bar = iTime(_Symbol, strategy_tf, 0);
   if(g_guard_until_bar > 0 && current_bar <= g_guard_until_bar) return false;
   const double close1 = iClose(_Symbol, strategy_tf, 1);
   const double sma200 = QM_SMA(_Symbol, strategy_tf, strategy_sma_period, 1);
   if(close1 <= 0.0 || sma200 <= 0.0 || close1 >= sma200) return false;
   DT_Pattern pattern;
   if(!DT_BuildPattern(pattern)) return false;
   if(pattern.key_time == g_last_pattern_key) return false;
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double entry = pattern.support - strategy_break_atr * atr;
   double recent_high = 0.0;
   for(int shift = 1; shift <= 10; ++shift) recent_high = MathMax(recent_high, iHigh(_Symbol, strategy_tf, shift));
   const double sl = MathMax(pattern.max_high, recent_high) + strategy_sl_buffer_atr * atr;
   if(sl - entry > strategy_max_stop_atr * atr) return false;
   const double tp = pattern.support - (pattern.max_high - pattern.support);
   if(entry <= 0.0 || sl <= entry || tp >= entry) return false;
   req.type = QM_SELL_STOP; req.price = NormalizeDouble(entry, _Digits); req.sl = NormalizeDouble(sl, _Digits); req.tp = NormalizeDouble(tp, _Digits);
   req.reason = "descending_triangle_h4"; req.symbol_slot = qm_magic_slot_offset; req.expiration_seconds = strategy_order_valid_bars * PeriodSeconds(strategy_tf);
   g_last_pattern_key = pattern.key_time; g_guard_until_bar = current_bar + (datetime)(strategy_reuse_guard_bars * PeriodSeconds(strategy_tf));
   g_active_support = pattern.support; g_active_height = pattern.max_high - pattern.support; g_active_slope = pattern.slope; g_active_intercept = pattern.intercept; g_partial_done = false;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i); if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL) continue;
      const double market = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double partial_level = g_active_support - 0.5 * g_active_height;
      if(!g_partial_done && g_active_height > 0.0 && market <= partial_level)
        {
         QM_TM_PartialClose(ticket, volume * 0.5, QM_EXIT_STRATEGY);
         QM_TM_MoveSL(ticket, open_price, "descending_triangle_tp1_be");
         g_partial_done = true;
        }
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i); if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL) continue;
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int entry_shift = iBarShift(_Symbol, strategy_tf, open_time, false);
      if(entry_shift >= strategy_time_stop_bars) return true;
      if(g_active_slope != 0.0)
        {
         const double close1 = iClose(_Symbol, strategy_tf, 1);
         const double supply1 = g_active_intercept + g_active_slope * (double)(entry_shift - 1);
         if(close1 > supply1) return true;
        }
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(qm_news_mode == QM_NEWS_OFF) return false;
   return !QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode);
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT, qm_news_mode, qm_friday_close_enabled, qm_friday_close_hour_broker)) return INIT_FAILED;
   QM_LogEvent(QM_INFO, "INIT_OK", "{}"); return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason)); QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode)) return;
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i); if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }
   if(!QM_IsNewBar()) return;
   QM_EntryRequest req;
   if(Strategy_EntrySignal(req)) { ulong out_ticket = 0; QM_TM_OpenPosition(req, out_ticket); }
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

double OnTester()
  {
   QM_ChartUI_Refresh(); return QM_DefaultObjective();
  }
