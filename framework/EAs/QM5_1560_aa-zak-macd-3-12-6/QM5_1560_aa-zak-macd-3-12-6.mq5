#property strict
#property version   "5.0"
#property description "QM5_1560 Alpha Architect Zakamulin monthly MACD 3/12/6 timing"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1560;
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
input int    strategy_fast_ema_months      = 3;
input int    strategy_slow_ema_months      = 12;
input int    strategy_signal_ema_months    = 6;
input int    strategy_min_completed_months = 18;
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_sl_mult          = 3.0;
input bool   strategy_use_dead_macd_filter = true;
input int    strategy_monthly_atr_period   = 20;
input double strategy_min_macd_atr_ratio   = 0.25;

bool   g_state_valid          = false;
bool   g_trend_long           = false;
bool   g_amplitude_ok         = false;
int    g_last_state_month_key = -1;
int    g_last_entry_month_key = -1;
double g_last_mac             = 0.0;
double g_last_signal          = 0.0;
double g_last_monthly_atr     = 0.0;

int MonthKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
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
   const int lookback_days = MathMax(760, months_needed * 34 + 60);
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

double EmaAtShift(double &values[],
                  const int shift,
                  const int count,
                  const int period)
  {
   if(period <= 0 || shift < 0 || shift >= count)
      return 0.0;

   const double alpha = 2.0 / ((double)period + 1.0);
   double ema = values[count - 1];
   for(int i = count - 2; i >= shift; --i)
      ema = alpha * values[i] + (1.0 - alpha) * ema;
   return ema;
  }

bool ComputeMonthlyState(bool &trend_long,
                         bool &amplitude_ok,
                         double &mac,
                         double &signal,
                         double &monthly_atr)
  {
   const int fast_period = MathMax(1, strategy_fast_ema_months);
   const int slow_period = MathMax(fast_period + 1, strategy_slow_ema_months);
   const int signal_period = MathMax(1, strategy_signal_ema_months);
   const int monthly_atr_period = MathMax(1, strategy_monthly_atr_period);

   int months_needed = MathMax(strategy_min_completed_months, slow_period + signal_period);
   if(strategy_use_dead_macd_filter)
      months_needed = MathMax(months_needed, monthly_atr_period + 1);

   double opens[];
   double highs[];
   double lows[];
   double closes[];
   if(!LoadCompletedMonthlyBars(months_needed, opens, highs, lows, closes))
      return false;

   double mac_values[];
   ArrayResize(mac_values, months_needed);
   for(int shift = months_needed - 1; shift >= 0; --shift)
     {
      const double fast_ema = EmaAtShift(closes, shift, months_needed, fast_period);
      const double slow_ema = EmaAtShift(closes, shift, months_needed, slow_period);
      mac_values[shift] = fast_ema - slow_ema;
     }

   mac = mac_values[0];
   signal = EmaAtShift(mac_values, 0, months_needed, signal_period);
   trend_long = (mac > signal);
   amplitude_ok = true;
   monthly_atr = 0.0;

   if(strategy_use_dead_macd_filter)
     {
      monthly_atr = MonthlyATR(0, monthly_atr_period, highs, lows, closes);
      if(monthly_atr <= 0.0)
         return false;
      amplitude_ok = (MathAbs(mac) >= monthly_atr * strategy_min_macd_atr_ratio);
     }

   return true;
  }

void RefreshMonthlyStateIfNeeded()
  {
   const int month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const bool calendar_roll = QM_IsNewCalendarPeriod(PERIOD_MN1, _Symbol);
   if(g_state_valid && !calendar_roll)
      return;

   bool trend_long = false;
   bool amplitude_ok = false;
   double mac = 0.0;
   double signal = 0.0;
   double monthly_atr = 0.0;

   const bool ok = ComputeMonthlyState(trend_long, amplitude_ok, mac, signal, monthly_atr);
   g_state_valid = ok;
   g_trend_long = ok && trend_long;
   g_amplitude_ok = ok && amplitude_ok;
   g_last_state_month_key = month_key;
   g_last_mac = mac;
   g_last_signal = signal;
   g_last_monthly_atr = monthly_atr;

   QM_LogEvent(ok ? QM_INFO : QM_WARN,
               ok ? "MONTHLY_MACD_STATE" : "MONTHLY_MACD_STATE_INVALID",
               StringFormat("{\"month_key\":%d,\"trend_long\":%s,\"amplitude_ok\":%s,\"mac\":%.8f,\"signal\":%.8f,\"monthly_atr\":%.8f}",
                            month_key,
                            g_trend_long ? "true" : "false",
                            g_amplitude_ok ? "true" : "false",
                            mac,
                            signal,
                            monthly_atr));
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

   if(!g_state_valid || !g_trend_long || !g_amplitude_ok)
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
   req.reason = "AA_ZAK_MACD_3_12_6_LONG";

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
