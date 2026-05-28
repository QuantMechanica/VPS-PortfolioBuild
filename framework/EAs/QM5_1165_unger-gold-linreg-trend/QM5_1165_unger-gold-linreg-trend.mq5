#property strict
#property version   "5.0"
#property description "QM5_1165 Unger Gold Linear Regression Trend"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1165;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_SKIP_DAY;
input QM_NewsComplianceProfile qm_news_compliance  = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_SKIP_DAY;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_lr_period           = 40;
input double strategy_lr_dev              = 1.0;
input int    strategy_atr_period          = 14;
input double strategy_sl_atr_mult         = 2.0;
input double strategy_tp_atr_mult         = 4.0;
input int    strategy_max_hold_bars       = 72;
input int    strategy_start_hour_broker   = 7;
input int    strategy_end_hour_broker     = 22;
input int    strategy_max_spread_points   = 250;

const string STRATEGY_SYMBOL = "XAUUSD.DWX";

datetime g_last_signal_bar = 0;

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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool InBrokerSession(const datetime broker_time)
  {
   if(strategy_start_hour_broker == strategy_end_hour_broker)
      return true;

   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   const int hour = dt.hour;
   const int start_hour = MathMax(0, MathMin(23, strategy_start_hour_broker));
   const int end_hour = MathMax(0, MathMin(23, strategy_end_hour_broker));
   if(end_hour > start_hour)
      return (hour >= start_hour && hour < end_hour);
   return (hour >= start_hour || hour < end_hour);
  }

bool SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread > 0 && spread <= strategy_max_spread_points);
  }

bool LinearRegressionStats(const int first_closed_shift, double &line_value, double &resid_stdev)
  {
   line_value = 0.0;
   resid_stdev = 0.0;

   const int n = strategy_lr_period;
   if(n < 2 || n > 256)
      return false;

   double y[];
   ArrayResize(y, n);
   double sum_y = 0.0;
   for(int k = 0; k < n; ++k)
     {
      const int shift = first_closed_shift + (n - 1 - k);
      const double close_price = iClose(_Symbol, PERIOD_H1, shift);
      if(close_price <= 0.0)
         return false;
      y[k] = close_price;
      sum_y += close_price;
     }

   const double mean_x = 0.5 * (double)(n - 1);
   const double mean_y = sum_y / (double)n;
   double numerator = 0.0;
   double denominator = 0.0;
   for(int k = 0; k < n; ++k)
     {
      const double x_dev = (double)k - mean_x;
      numerator += x_dev * (y[k] - mean_y);
      denominator += x_dev * x_dev;
     }

   if(denominator <= 0.0)
      return false;

   const double slope = numerator / denominator;
   const double intercept = mean_y - slope * mean_x;
   line_value = intercept + slope * (double)(n - 1);

   double residual_sum = 0.0;
   for(int k = 0; k < n; ++k)
     {
      const double fitted = intercept + slope * (double)k;
      const double residual = y[k] - fitted;
      residual_sum += residual * residual;
     }

   resid_stdev = MathSqrt(residual_sum / (double)n);
   return (line_value > 0.0 && resid_stdev > 0.0);
  }

bool StopDistanceAllowed(const QM_OrderType side, const double entry, const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0)
      return false;
   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double stop_points = MathAbs(entry - sl) / point;
   return (stops_level <= 0 || stop_points > (double)stops_level);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != STRATEGY_SYMBOL)
      return true;
   if(_Period != PERIOD_H1)
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_lr_period < 2 || strategy_lr_period > 256 || strategy_lr_dev <= 0.0)
      return true;
   if(strategy_atr_period <= 0 || strategy_sl_atr_mult <= 0.0 || strategy_tp_atr_mult <= 0.0)
      return true;
   if(strategy_max_hold_bars <= 0)
      return true;
   if(Bars(_Symbol, PERIOD_H1) < strategy_lr_period + 5)
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

   const datetime signal_bar = iTime(_Symbol, PERIOD_H1, 1);
   if(signal_bar <= 0 || signal_bar == g_last_signal_bar)
      return false;
   g_last_signal_bar = signal_bar;

   if(!InBrokerSession(signal_bar) || HasOpenPositionForMagic() || !SpreadAllowsEntry())
      return false;

   double line1 = 0.0, stdev1 = 0.0, line2 = 0.0, stdev2 = 0.0;
   if(!LinearRegressionStats(1, line1, stdev1) || !LinearRegressionStats(2, line2, stdev2))
      return false;

   const double close1 = iClose(_Symbol, PERIOD_H1, 1);
   const double close2 = iClose(_Symbol, PERIOD_H1, 2);
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double upper1 = line1 + strategy_lr_dev * stdev1;
   const double lower1 = line1 - strategy_lr_dev * stdev1;
   const double upper2 = line2 + strategy_lr_dev * stdev2;
   const double lower2 = line2 - strategy_lr_dev * stdev2;

   QM_OrderType side = QM_BUY;
   string reason = "";
   if(close2 <= upper2 && close1 > upper1)
     {
      side = QM_BUY;
      reason = "UNGER_GOLD_LINREG_BREAK_LONG";
     }
   else if(close2 >= lower2 && close1 < lower1)
     {
      side = QM_SELL;
      reason = "UNGER_GOLD_LINREG_BREAK_SHORT";
     }
   else
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, MathMax(1, strategy_atr_period), 1);
   const double entry = QM_EntryMarketPrice(side);
   if(atr <= 0.0 || entry <= 0.0)
      return false;

   req.type = side;
   req.price = entry;
   req.sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_sl_atr_mult);
   req.tp = QM_TakeATRFromValue(_Symbol, side, entry, atr, strategy_tp_atr_mult);
   req.reason = reason;

   return (StopDistanceAllowed(side, entry, req.sl) && req.tp > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed ATR-derived SL/TP; no trailing, scale-out, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_H1)
      return false;

   double line1 = 0.0, stdev1 = 0.0;
   if(!LinearRegressionStats(1, line1, stdev1))
      return false;

   const double close1 = iClose(_Symbol, PERIOD_H1, 1);
   if(close1 <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && close1 < line1)
         return true;
      if(pos_type == POSITION_TYPE_SELL && close1 > line1)
         return true;

      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened_at > 0 && iBarShift(_Symbol, PERIOD_H1, opened_at, false) >= strategy_max_hold_bars)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1165\",\"ea\":\"unger-gold-linreg-trend\"}");
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
