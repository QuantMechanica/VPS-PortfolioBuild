#property strict
#property version   "5.0"
#property description "QM5_11897 Vegas-Wave EMA 144/169 Channel + Fractal Breakout H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11897
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11897;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input string strategy_timeframe = "H1";
input int    strategy_ema_upper_period = 144;
input int    strategy_ema_lower_period = 169;
input int    strategy_fractal_lookback_bars = 5;
input int    strategy_fractal_filter_pips = 3;
input string strategy_time_filter_majors_start_gmt = "07:00";
input string strategy_time_filter_majors_end_gmt = "17:00";
input string strategy_time_filter_majors_pairs = "[EURUSD.DWX, GBPUSD.DWX]";
input double strategy_scale_out_fraction = 0.5;
input double strategy_tp1_fib_extension = 2.62;
input double strategy_tp2_fib_extension = 3.62;
input bool   strategy_breakeven_after_tp1 = true;


// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter() { return false; }

ENUM_TIMEFRAMES GetStrategyTimeframe()
{
   if(strategy_timeframe == "M1") return PERIOD_M1;
   if(strategy_timeframe == "M5") return PERIOD_M5;
   if(strategy_timeframe == "M15") return PERIOD_M15;
   if(strategy_timeframe == "M30") return PERIOD_M30;
   if(strategy_timeframe == "H1") return PERIOD_H1;
   if(strategy_timeframe == "H4") return PERIOD_H4;
   if(strategy_timeframe == "D1") return PERIOD_D1;
   return PERIOD_H1;
}

int ParseHourFromHHMM(const string s)
{
   string parts[];
   if(StringSplit(s, ':', parts) >= 1)
      return (int)StringToInteger(parts[0]);
   return (int)StringToInteger(s);
}

bool IsBullishFractal(int shift, int lookback_bars = 5)
{
   int wing = (lookback_bars - 1) / 2;
   if(wing < 1) wing = 2;
   const ENUM_TIMEFRAMES tf = GetStrategyTimeframe();
   double h = iHigh(_Symbol, tf, shift); // perf-allowed
   for(int i = 1; i <= wing; ++i)
   {
      if(h <= iHigh(_Symbol, tf, shift + i) || h <= iHigh(_Symbol, tf, shift - i)) // perf-allowed
         return false;
   }
   return true;
}

bool IsBearishFractal(int shift, int lookback_bars = 5)
{
   int wing = (lookback_bars - 1) / 2;
   if(wing < 1) wing = 2;
   const ENUM_TIMEFRAMES tf = GetStrategyTimeframe();
   double l = iLow(_Symbol, tf, shift); // perf-allowed
   for(int i = 1; i <= wing; ++i)
   {
      if(l >= iLow(_Symbol, tf, shift + i) || l >= iLow(_Symbol, tf, shift - i)) // perf-allowed
         return false;
   }
   return true;
}

bool IsTimeAllowed(datetime time_broker)
{
   if(StringFind(strategy_time_filter_majors_pairs, _Symbol) < 0 && _Symbol != "EURUSD.DWX" && _Symbol != "GBPUSD.DWX")
      return true;
   int broker_gmt_offset = (int)(TimeCurrent() - TimeGMT());
   datetime gmt_time = time_broker - broker_gmt_offset;
   MqlDateTime dt;
   TimeToStruct(gmt_time, dt);
   int start_hr = ParseHourFromHHMM(strategy_time_filter_majors_start_gmt);
   int end_hr = ParseHourFromHHMM(strategy_time_filter_majors_end_gmt);
   return (dt.hour >= start_hr && dt.hour < end_hr);
}

bool GetBuyStopSignal(double &order_price, double &order_sl, double &order_tp1, double &order_tp2, int &expire_seconds)
{
   const ENUM_TIMEFRAMES tf = GetStrategyTimeframe();
   int cross_bar = -1;
   for(int x = 1; x <= 50; ++x)
   {
      double ema_upper = QM_EMA(_Symbol, tf, strategy_ema_upper_period, x);
      double ema_lower = QM_EMA(_Symbol, tf, strategy_ema_lower_period, x);
      double max_ema = MathMax(ema_upper, ema_lower);
      
      if(iClose(_Symbol, tf, x) > max_ema) // perf-allowed
      {
         bool prior_below = false;
         for(int y = x + 1; y <= x + 10; ++y)
         {
            double ema_u_y = QM_EMA(_Symbol, tf, strategy_ema_upper_period, y);
            double ema_l_y = QM_EMA(_Symbol, tf, strategy_ema_lower_period, y);
            if(iClose(_Symbol, tf, y) < MathMin(ema_u_y, ema_l_y)) // perf-allowed
            {
               prior_below = true;
               break;
            }
         }
         if(prior_below)
         {
            cross_bar = x;
            break;
         }
      }
   }
   
   if(cross_bar == -1) return false;
   
   int fractal_bar = -1;
   for(int f = 3; f < cross_bar && (cross_bar - f) <= 20 && f <= 12; ++f)
   {
      if(IsBullishFractal(f, strategy_fractal_lookback_bars))
      {
         fractal_bar = f;
         break;
      }
   }
   
   if(fractal_bar == -1) return false;
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double pip = (digits == 3 || digits == 5) ? point * 10.0 : point;
   
   double fractal_high = iHigh(_Symbol, tf, fractal_bar); // perf-allowed
   order_price = fractal_high + (double)strategy_fractal_filter_pips * pip;
   
   double ema_u_now = QM_EMA(_Symbol, tf, strategy_ema_upper_period, 1);
   double ema_l_now = QM_EMA(_Symbol, tf, strategy_ema_lower_period, 1);
   double min_ema_now = MathMin(ema_u_now, ema_l_now);
   double sl_channel = min_ema_now - 5.0 * pip;
   
   double sl_fractal = 0.0;
   for(int f = 1; f <= 100; ++f)
   {
      if(IsBearishFractal(f, strategy_fractal_lookback_bars))
      {
         sl_fractal = iLow(_Symbol, tf, f); // perf-allowed
         break;
      }
   }
   
   if(sl_fractal > 0.0)
      order_sl = MathMax(sl_channel, sl_fractal);
   else
      order_sl = sl_channel;
   
   double leg = MathAbs(fractal_high - iClose(_Symbol, tf, cross_bar)); // perf-allowed
   order_tp1 = order_price + strategy_tp1_fib_extension * leg;
   order_tp2 = order_price + strategy_tp2_fib_extension * leg;
   
   expire_seconds = (10 - (fractal_bar - 3)) * 3600;
   return true;
}

bool GetShortStopSignal(double &order_price, double &order_sl, double &order_tp1, double &order_tp2, int &expire_seconds)
{
   const ENUM_TIMEFRAMES tf = GetStrategyTimeframe();
   int cross_bar = -1;
   for(int x = 1; x <= 50; ++x)
   {
      double ema_upper = QM_EMA(_Symbol, tf, strategy_ema_upper_period, x);
      double ema_lower = QM_EMA(_Symbol, tf, strategy_ema_lower_period, x);
      double min_ema = MathMin(ema_upper, ema_lower);
      
      if(iClose(_Symbol, tf, x) < min_ema) // perf-allowed
      {
         bool prior_above = false;
         for(int y = x + 1; y <= x + 10; ++y)
         {
            double ema_u_y = QM_EMA(_Symbol, tf, strategy_ema_upper_period, y);
            double ema_l_y = QM_EMA(_Symbol, tf, strategy_ema_lower_period, y);
            if(iClose(_Symbol, tf, y) > MathMax(ema_u_y, ema_l_y)) // perf-allowed
            {
               prior_above = true;
               break;
            }
         }
         if(prior_above)
         {
            cross_bar = x;
            break;
         }
      }
   }
   
   if(cross_bar == -1) return false;
   
   int fractal_bar = -1;
   for(int f = 3; f < cross_bar && (cross_bar - f) <= 20 && f <= 12; ++f)
   {
      if(IsBearishFractal(f, strategy_fractal_lookback_bars))
      {
         fractal_bar = f;
         break;
      }
   }
   
   if(fractal_bar == -1) return false;
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double pip = (digits == 3 || digits == 5) ? point * 10.0 : point;
   
   double fractal_low = iLow(_Symbol, tf, fractal_bar); // perf-allowed
   order_price = fractal_low - (double)strategy_fractal_filter_pips * pip;
   
   double ema_u_now = QM_EMA(_Symbol, tf, strategy_ema_upper_period, 1);
   double ema_l_now = QM_EMA(_Symbol, tf, strategy_ema_lower_period, 1);
   double max_ema_now = MathMax(ema_u_now, ema_l_now);
   double sl_channel = max_ema_now + 5.0 * pip;
   
   double sl_fractal = 0.0;
   for(int f = 1; f <= 100; ++f)
   {
      if(IsBullishFractal(f, strategy_fractal_lookback_bars))
      {
         sl_fractal = iHigh(_Symbol, tf, f); // perf-allowed
         break;
      }
   }
   
   if(sl_fractal > 0.0)
      order_sl = MathMin(sl_channel, sl_fractal);
   else
      order_sl = sl_channel;
   
   double leg = MathAbs(fractal_low - iClose(_Symbol, tf, cross_bar)); // perf-allowed
   order_tp1 = order_price - strategy_tp1_fib_extension * leg;
   order_tp2 = order_price - strategy_tp2_fib_extension * leg;
   
   expire_seconds = (10 - (fractal_bar - 3)) * 3600;
   return true;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   double order_price = 0.0, order_sl = 0.0, order_tp1 = 0.0, order_tp2 = 0.0;
   int expire_seconds = 0;
   
   if(GetBuyStopSignal(order_price, order_sl, order_tp1, order_tp2, expire_seconds))
   {
      if(IsTimeAllowed(TimeCurrent()))
      {
         int magic1 = QM_MagicChecked(qm_ea_id, qm_magic_slot_offset, _Symbol);
         int magic2 = QM_MagicChecked(qm_ea_id, qm_magic_slot_offset + 100, _Symbol);
         
         if(magic1 > 0 && magic2 > 0 &&
            !QM_EntryHasOpenPosition(magic1, _Symbol) &&
            !QM_EntryHasOpenPosition(magic2, _Symbol) &&
            !QM_EntryHasPendingOrder(magic1, _Symbol, ORDER_TYPE_BUY_STOP) &&
            !QM_EntryHasPendingOrder(magic2, _Symbol, ORDER_TYPE_BUY_STOP))
         {
            QM_EntryRequest req1;
            req1.type = QM_BUY_STOP;
            req1.price = order_price;
            req1.sl = order_sl;
            req1.tp = order_tp1;
            req1.reason = "VEGAS_WAVE_BUY_STOP_TP1";
            req1.symbol_slot = qm_magic_slot_offset;
            req1.expiration_seconds = expire_seconds;
            
            QM_EntryRequest req2;
            req2.type = QM_BUY_STOP;
            req2.price = order_price;
            req2.sl = order_sl;
            req2.tp = order_tp2;
            req2.reason = "VEGAS_WAVE_BUY_STOP_TP2";
            req2.symbol_slot = qm_magic_slot_offset + 100;
            req2.expiration_seconds = expire_seconds;
            
            ulong ticket1 = 0, ticket2 = 0;
            QM_RiskMode r_mode = g_qm_risk_mode;
            double r_total = (r_mode == QM_RISK_MODE_PERCENT) ? RISK_PERCENT : RISK_FIXED;
            double r_val1 = r_total * strategy_scale_out_fraction;
            double r_val2 = r_total * (1.0 - strategy_scale_out_fraction);
            
            QM_TM_OpenPosition(req1, ticket1, magic1, r_mode, r_val1);
            QM_TM_OpenPosition(req2, ticket2, magic2, r_mode, r_val2);
         }
      }
   }
   
   if(GetShortStopSignal(order_price, order_sl, order_tp1, order_tp2, expire_seconds))
   {
      if(IsTimeAllowed(TimeCurrent()))
      {
         int magic1 = QM_MagicChecked(qm_ea_id, qm_magic_slot_offset, _Symbol);
         int magic2 = QM_MagicChecked(qm_ea_id, qm_magic_slot_offset + 100, _Symbol);
         
         if(magic1 > 0 && magic2 > 0 &&
            !QM_EntryHasOpenPosition(magic1, _Symbol) &&
            !QM_EntryHasOpenPosition(magic2, _Symbol) &&
            !QM_EntryHasPendingOrder(magic1, _Symbol, ORDER_TYPE_SELL_STOP) &&
            !QM_EntryHasPendingOrder(magic2, _Symbol, ORDER_TYPE_SELL_STOP))
         {
            QM_EntryRequest req1;
            req1.type = QM_SELL_STOP;
            req1.price = order_price;
            req1.sl = order_sl;
            req1.tp = order_tp1;
            req1.reason = "VEGAS_WAVE_SELL_STOP_TP1";
            req1.symbol_slot = qm_magic_slot_offset;
            req1.expiration_seconds = expire_seconds;
            
            QM_EntryRequest req2;
            req2.type = QM_SELL_STOP;
            req2.price = order_price;
            req2.sl = order_sl;
            req2.tp = order_tp2;
            req2.reason = "VEGAS_WAVE_SELL_STOP_TP2";
            req2.symbol_slot = qm_magic_slot_offset + 100;
            req2.expiration_seconds = expire_seconds;
            
            ulong ticket1 = 0, ticket2 = 0;
            QM_RiskMode r_mode = g_qm_risk_mode;
            double r_total = (r_mode == QM_RISK_MODE_PERCENT) ? RISK_PERCENT : RISK_FIXED;
            double r_val1 = r_total * strategy_scale_out_fraction;
            double r_val2 = r_total * (1.0 - strategy_scale_out_fraction);
            
            QM_TM_OpenPosition(req1, ticket1, magic1, r_mode, r_val1);
            QM_TM_OpenPosition(req2, ticket2, magic2, r_mode, r_val2);
         }
      }
   }
   
   return false;
}

void Strategy_ManageOpenPosition()
{
   int magic1 = QM_MagicChecked(qm_ea_id, qm_magic_slot_offset, _Symbol);
   int magic2 = QM_MagicChecked(qm_ea_id, qm_magic_slot_offset + 100, _Symbol);
   if(magic1 <= 0 || magic2 <= 0) return;
   
   bool magic1_open = false;
   ulong magic2_ticket = 0;
   double magic2_open_price = 0.0;
   double magic2_sl = 0.0;
   
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      long pos_magic = PositionGetInteger(POSITION_MAGIC);
      if(pos_magic == magic1)
      {
         magic1_open = true;
      }
      else if(pos_magic == magic2)
      {
         magic2_ticket = ticket;
         magic2_open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         magic2_sl = PositionGetDouble(POSITION_SL);
      }
   }
   
   if(strategy_breakeven_after_tp1 && magic2_ticket > 0 && !magic1_open)
   {
      bool is_buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      bool sl_at_entry = false;
      if(is_buy)
         sl_at_entry = (magic2_sl >= magic2_open_price - 1e-5);
      else
         sl_at_entry = (magic2_sl <= magic2_open_price + 1e-5);
      
      if(!sl_at_entry)
      {
         QM_TM_MoveSL(magic2_ticket, magic2_open_price, "VEGAS_WAVE_BREAKEVEN");
      }
   }
   
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      long pos_magic = PositionGetInteger(POSITION_MAGIC);
      if(pos_magic == magic1 || pos_magic == magic2)
      {
         datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
         if(TimeCurrent() - open_time >= 120 * 3600)
         {
            QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
         }
      }
   }
}

bool Strategy_ExitSignal()
{
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
{
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
