#property strict
#property version   "5.0"
#property description "QM5_12397 Oil-return equity index timing"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 12397;
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
input string strategy_oil_symbol          = "XTIUSD.DWX";
input int    strategy_month_bars          = 21;
input int    strategy_regression_months   = 24;
input double strategy_cash_hurdle_pct     = 0.0;
input int    strategy_atr_period          = 20;
input double strategy_atr_stop_mult       = 3.0;
input double strategy_emergency_r_mult    = 4.0;
input int    strategy_spread_lookback_d1  = 60;

bool   g_signal_valid       = false;
bool   g_target_long        = false;
double g_last_forecast_pct  = 0.0;
string g_universe[2];

bool GetOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype, double &open_price, double &sl_price)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_price = 0.0;
   sl_price = 0.0;

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
      sl_price = PositionGetDouble(POSITION_SL);
      return true;
     }

   return false;
  }

bool FirstD1BarOfCalendarMonth()
  {
   const datetime t1 = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: monthly rebalance date, called after framework new-bar gate
   const datetime t2 = iTime(_Symbol, PERIOD_D1, 2); // perf-allowed: monthly rebalance date, called after framework new-bar gate
   if(t1 <= 0 || t2 <= 0)
      return false;

   MqlDateTime d1;
   MqlDateTime d2;
   TimeToStruct(t1, d1);
   TimeToStruct(t2, d2);
   return (d1.year != d2.year || d1.mon != d2.mon);
  }

double ReturnPct(const string symbol, const int end_shift, const int bars)
  {
   if(!QM_SymbolAssertOrLog(symbol))
      return 0.0;
   if(bars <= 0 || end_shift <= 0)
      return 0.0;

   const double end_close = iClose(symbol, PERIOD_D1, end_shift);        // perf-allowed: D1 monthly-proxy close read, monthly gate
   const double start_close = iClose(symbol, PERIOD_D1, end_shift + bars); // perf-allowed: D1 monthly-proxy close read, monthly gate
   if(end_close <= 0.0 || start_close <= 0.0)
      return 0.0;

   return 100.0 * ((end_close / start_close) - 1.0);
  }

bool CurrentSpreadTooWide()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, strategy_spread_lookback_d1, rates); // perf-allowed: 60D spread median, monthly gate
   if(copied <= 0)
      return false;

   double spreads[];
   ArrayResize(spreads, copied);
   int n = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].spread > 0)
        {
         spreads[n] = (double)rates[i].spread;
         n++;
        }
     }

   if(n <= 0)
      return false;

   for(int i = 1; i < n; ++i)
     {
      const double key = spreads[i];
      int j = i - 1;
      while(j >= 0 && spreads[j] > key)
        {
         spreads[j + 1] = spreads[j];
         j--;
        }
      spreads[j + 1] = key;
     }

   double median = spreads[n / 2];
   if((n % 2) == 0)
      median = 0.5 * (spreads[(n / 2) - 1] + spreads[n / 2]);
   if(median <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double current_points = (ask - bid) / point;
   return (current_points > (2.0 * median));
  }

bool ComputeForecast(double &forecast_pct)
  {
   forecast_pct = 0.0;
   if(strategy_month_bars < 10 || strategy_regression_months < 2)
      return false;

   double sum_x = 0.0;
   double sum_y = 0.0;
   double sum_xx = 0.0;
   double sum_xy = 0.0;
   int n = 0;

   for(int j = 1; j <= strategy_regression_months; ++j)
     {
      const int oil_end_shift = 1 + (j * strategy_month_bars);
      const int eq_end_shift = 1 + ((j - 1) * strategy_month_bars);
      const double x = ReturnPct(strategy_oil_symbol, oil_end_shift, strategy_month_bars);
      const double y = ReturnPct(_Symbol, eq_end_shift, strategy_month_bars);
      if(x == 0.0 || y == 0.0)
         continue;

      sum_x += x;
      sum_y += y;
      sum_xx += x * x;
      sum_xy += x * y;
      n++;
     }

   if(n < strategy_regression_months)
      return false;

   const double denom = (n * sum_xx) - (sum_x * sum_x);
   if(MathAbs(denom) <= 0.00000001)
      return false;

   const double slope = ((n * sum_xy) - (sum_x * sum_y)) / denom;
   const double intercept = (sum_y - (slope * sum_x)) / n;
   const double recent_oil = ReturnPct(strategy_oil_symbol, 1, strategy_month_bars);
   if(recent_oil == 0.0)
      return false;

   forecast_pct = intercept + (slope * recent_oil);
   return true;
  }

bool Strategy_NoTradeFilter()
  {
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

   if(!FirstD1BarOfCalendarMonth())
      return false;

   double forecast_pct = 0.0;
   g_signal_valid = ComputeForecast(forecast_pct);
   g_last_forecast_pct = forecast_pct;
   g_target_long = (g_signal_valid && forecast_pct > strategy_cash_hurdle_pct);

   if(!g_signal_valid || !g_target_long)
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double sl_price;
   if(GetOurPosition(ticket, ptype, open_price, sl_price))
      return false;

   if(CurrentSpreadTooWide())
      return false;

   double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_stop_mult);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.tp = 0.0;
   req.reason = StringFormat("OIL_EQ_REG_LONG forecast=%.4f hurdle=%.4f", forecast_pct, strategy_cash_hurdle_pct);
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double sl_price;
   if(!GetOurPosition(ticket, ptype, open_price, sl_price))
      return;
   if(ptype != POSITION_TYPE_BUY || open_price <= 0.0 || sl_price <= 0.0 || sl_price >= open_price)
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0)
      return;

   const double one_r = open_price - sl_price;
   if(one_r <= 0.0)
      return;

   if((open_price - bid) >= (strategy_emergency_r_mult * one_r))
      QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double sl_price;
   if(!GetOurPosition(ticket, ptype, open_price, sl_price))
      return false;

   if(!g_signal_valid || !g_target_long)
      return true;

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

   g_universe[0] = _Symbol;
   g_universe[1] = strategy_oil_symbol;
   QM_SymbolGuardInit(g_universe);
   QM_BasketWarmupHistory(g_universe, PERIOD_D1, strategy_month_bars * (strategy_regression_months + 3));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12397\",\"ea\":\"QM5_12397_oil_eq_reg\"}");
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
