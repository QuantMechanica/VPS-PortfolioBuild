#property strict
#property version   "5.0"
#property description "QM5_1558 Alpha Architect Zakamulin SMA 3/10 monthly crossover"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1558;
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
input int    strategy_fast_sma_months      = 3;
input int    strategy_slow_sma_months      = 10;
input int    strategy_min_completed_months = 11;
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_sl_mult          = 3.0;
input bool   strategy_use_dead_atr_filter  = true;
input int    strategy_monthly_atr_period   = 6;
input int    strategy_atr_median_months    = 36;
input double strategy_min_atr_median_ratio = 0.50;

bool   g_state_valid          = false;
bool   g_trend_long           = false;
bool   g_volatility_ok        = false;
int    g_last_state_month_key = -1;
int    g_last_entry_month_key = -1;
double g_last_fast_sma        = 0.0;
double g_last_slow_sma        = 0.0;
double g_last_monthly_atr     = 0.0;
double g_last_median_atr      = 0.0;

int MonthKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

double AverageWindow(double &values[], const int start, const int count)
  {
   if(count <= 0)
      return 0.0;
   double sum = 0.0;
   for(int i = 0; i < count; ++i)
      sum += values[start + i];
   return sum / (double)count;
  }

void SortAscending(double &values[], const int count)
  {
   for(int i = 1; i < count; ++i)
     {
      const double x = values[i];
      int j = i - 1;
      while(j >= 0 && values[j] > x)
        {
         values[j + 1] = values[j];
         --j;
        }
      values[j + 1] = x;
     }
  }

bool LoadCompletedMonthlyBars(const int months_needed,
                              double &opens[],
                              double &highs[],
                              double &lows[],
                              double &closes[])
  {
   if(months_needed <= 0)
      return false;

   ArrayResize(opens, months_needed);
   ArrayResize(highs, months_needed);
   ArrayResize(lows, months_needed);
   ArrayResize(closes, months_needed);

   MqlRates daily[];
   ArraySetAsSeries(daily, true);
   const int lookback_days = MathMax(420, months_needed * 34 + 40);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, lookback_days, daily); // perf-allowed: monthly OHLC aggregation, called only on init/month rollover.
   if(copied <= 0)
      return false;

   const int current_month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   int count = 0;
   int active_key = -1;

   for(int i = 0; i < copied && count < months_needed; ++i)
     {
      const int key = MonthKey(daily[i].time);
      if(key <= 0 || key == current_month_key)
         continue;

      if(key != active_key)
        {
         active_key = key;
         opens[count]  = daily[i].open;
         highs[count]  = daily[i].high;
         lows[count]   = daily[i].low;
         closes[count] = daily[i].close;
         ++count;
         continue;
        }

      const int idx = count - 1;
      if(idx < 0)
         continue;
      highs[idx] = MathMax(highs[idx], daily[i].high);
      lows[idx]  = MathMin(lows[idx], daily[i].low);
      opens[idx] = daily[i].open;
     }

   return (count >= months_needed);
  }

double MonthlyTrueRange(const int idx,
                        double &highs[],
                        double &lows[],
                        double &closes[])
  {
   const double hi = highs[idx];
   const double lo = lows[idx];
   const double prev_close = closes[idx + 1];
   if(hi <= 0.0 || lo <= 0.0 || prev_close <= 0.0 || hi < lo)
      return 0.0;
   return MathMax(hi - lo, MathMax(MathAbs(hi - prev_close), MathAbs(lo - prev_close)));
  }

double MonthlyATR(const int start_idx,
                  const int period,
                  double &highs[],
                  double &lows[],
                  double &closes[])
  {
   if(period <= 0)
      return 0.0;
   double sum = 0.0;
   for(int i = 0; i < period; ++i)
     {
      const double tr = MonthlyTrueRange(start_idx + i, highs, lows, closes);
      if(tr <= 0.0)
         return 0.0;
      sum += tr;
     }
   return sum / (double)period;
  }

bool ComputeMonthlyState(bool &trend_long,
                         bool &volatility_ok,
                         double &fast_sma,
                         double &slow_sma,
                         double &monthly_atr,
                         double &median_atr)
  {
   const int fast_period = MathMax(1, strategy_fast_sma_months);
   const int slow_period = MathMax(fast_period + 1, strategy_slow_sma_months);
   const int atr_period = MathMax(1, strategy_monthly_atr_period);
   const int median_months = MathMax(3, strategy_atr_median_months);
   int months_needed = MathMax(strategy_min_completed_months, slow_period);
   if(strategy_use_dead_atr_filter)
      months_needed = MathMax(months_needed, median_months + atr_period);

   double opens[];
   double highs[];
   double lows[];
   double closes[];
   if(!LoadCompletedMonthlyBars(months_needed, opens, highs, lows, closes))
      return false;

   fast_sma = AverageWindow(closes, 0, fast_period);
   slow_sma = AverageWindow(closes, 0, slow_period);
   if(fast_sma <= 0.0 || slow_sma <= 0.0)
      return false;

   trend_long = (fast_sma > slow_sma);
   volatility_ok = true;
   monthly_atr = 0.0;
   median_atr = 0.0;

   if(strategy_use_dead_atr_filter)
     {
      monthly_atr = MonthlyATR(0, atr_period, highs, lows, closes);
      if(monthly_atr <= 0.0)
         return false;

      double atr_samples[];
      ArrayResize(atr_samples, median_months);
      for(int i = 0; i < median_months; ++i)
        {
         atr_samples[i] = MonthlyATR(i, atr_period, highs, lows, closes);
         if(atr_samples[i] <= 0.0)
            return false;
        }
      SortAscending(atr_samples, median_months);
      if((median_months % 2) == 1)
         median_atr = atr_samples[median_months / 2];
      else
         median_atr = 0.5 * (atr_samples[median_months / 2 - 1] + atr_samples[median_months / 2]);

      if(median_atr <= 0.0)
         return false;
      volatility_ok = (monthly_atr >= median_atr * strategy_min_atr_median_ratio);
     }

   return true;
  }

void RefreshMonthlyStateIfNeeded()
  {
   const int month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const bool calendar_roll = QM_IsNewCalendarPeriod(PERIOD_MN1, _Symbol);
   // A data-invalid state is still the state for this calendar month.  Retrying
   // it on every tick both wastes tester CPU and emits MONTHLY_STATE_INVALID
   // until the journal reaches the log-bomb ceiling.  Retry only after the
   // monthly calendar advances (or if no month has ever been evaluated).
   if(g_last_state_month_key == month_key && !calendar_roll)
      return;

   bool trend_long = false;
   bool volatility_ok = false;
   double fast_sma = 0.0;
   double slow_sma = 0.0;
   double monthly_atr = 0.0;
   double median_atr = 0.0;

   const bool ok = ComputeMonthlyState(trend_long, volatility_ok, fast_sma, slow_sma, monthly_atr, median_atr);
   g_state_valid = ok;
   g_trend_long = ok && trend_long;
   g_volatility_ok = ok && volatility_ok;
   g_last_state_month_key = month_key;
   g_last_fast_sma = fast_sma;
   g_last_slow_sma = slow_sma;
   g_last_monthly_atr = monthly_atr;
   g_last_median_atr = median_atr;

   QM_LogEvent(ok ? QM_INFO : QM_WARN,
               ok ? "MONTHLY_STATE" : "MONTHLY_STATE_INVALID",
               StringFormat("{\"month_key\":%d,\"trend_long\":%s,\"volatility_ok\":%s,\"fast_sma\":%.8f,\"slow_sma\":%.8f,\"monthly_atr\":%.8f,\"median_atr\":%.8f}",
                            month_key,
                            g_trend_long ? "true" : "false",
                            g_volatility_ok ? "true" : "false",
                            fast_sma,
                            slow_sma,
                            monthly_atr,
                            median_atr));
  }

bool Strategy_NoTradeFilter()
  {
   return ((ENUM_TIMEFRAMES)_Period != PERIOD_D1);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_state_valid || !g_trend_long || !g_volatility_ok)
      return false;

   const int month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   if(month_key <= 0 || g_last_entry_month_key == month_key)
      return false;

   if(QM_EntryHasOpenPosition((long)QM_FrameworkMagic(), _Symbol))
      return false;

   const double price = QM_EntryMarketPrice(QM_BUY);
   if(price <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(atr <= 0.0 || strategy_atr_sl_mult <= 0.0)
      return false;

   req.type   = QM_BUY;
   req.price  = price;
   req.sl     = price - atr * strategy_atr_sl_mult;
   req.tp     = 0.0;
   req.reason = "AA_ZAK_MAC_3_10_LONG";

   if(req.sl <= 0.0 || req.sl >= req.price)
      return false;

   g_last_entry_month_key = month_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   RefreshMonthlyStateIfNeeded();
  }

bool Strategy_ExitSignal()
  {
   if(!g_state_valid || g_trend_long)
      return false;

   const long magic = (long)QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
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
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const long magic = (long)QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
