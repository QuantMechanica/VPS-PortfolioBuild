#property strict
#property version   "5.0"
#property description "QM5_1106 Unger Nasdaq Pullback Trend Following"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1106;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_lookback_bars       = 12;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 1.5;
input bool   strategy_use_rr_take_profit  = false;
input double strategy_take_profit_rr      = 2.5;
input int    strategy_session_open_hhmm   = 930;
input int    strategy_session_close_hhmm  = 1600;
input int    strategy_skip_open_minutes   = 15;
input int    strategy_skip_close_minutes  = 10;
input int    strategy_daily_atr_median_days = 60;

const int STRATEGY_SYMBOL_COUNT = 3;
string g_strategy_symbols[3] = {"NDX.DWX", "SP500.DWX", "WS30.DWX"};

datetime g_last_entry_eval_bar = 0;
int g_last_entry_day_key = 0;

int NyUtcOffsetHours(const datetime utc)
  {
   return QM_IsUSDSTUTC(utc) ? -4 : -5;
  }

datetime BrokerToNY(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   return utc + (NyUtcOffsetHours(utc) * 3600);
  }

int HhmmFromTime(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int DayKeyFromTime(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool IsWeekdayNY(const datetime ny_time)
  {
   MqlDateTime dt;
   TimeToStruct(ny_time, dt);
   return (dt.day_of_week >= 1 && dt.day_of_week <= 5);
  }

int HhmmAddMinutes(const int hhmm, const int minutes)
  {
   int total = (hhmm / 100) * 60 + (hhmm % 100) + minutes;
   if(total < 0)
      total = 0;
   if(total > 2359)
      total = 2359;
   return (total / 60) * 100 + (total % 60);
  }

int Strategy_CurrentSymbolSlot()
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      if(g_strategy_symbols[i] == _Symbol)
         return i;
   return -1;
  }

bool Strategy_HasOpenPosition()
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

bool Strategy_IsTradableEntryCloseNY(const datetime ny_close)
  {
   if(!IsWeekdayNY(ny_close))
      return false;

   const int hhmm = HhmmFromTime(ny_close);
   const int first_entry_hhmm = HhmmAddMinutes(strategy_session_open_hhmm, strategy_skip_open_minutes);
   const int last_entry_hhmm = HhmmAddMinutes(strategy_session_close_hhmm, -strategy_skip_close_minutes);
   return (hhmm >= first_entry_hhmm && hhmm < last_entry_hhmm);
  }

double Strategy_Median(double &values[], const int count)
  {
   if(count <= 0)
      return 0.0;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(values[j] < values[i])
           {
            const double tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
           }

   if((count % 2) == 1)
      return values[count / 2];
   return 0.5 * (values[(count / 2) - 1] + values[count / 2]);
  }

bool Strategy_DailyAtrRegimeAllows()
  {
   if(strategy_daily_atr_median_days <= 0)
      return true;

   const double current_close = iClose(_Symbol, PERIOD_D1, 1);
   const double current_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(current_close <= 0.0 || current_atr <= 0.0)
      return false;

   double ratios[];
   ArrayResize(ratios, strategy_daily_atr_median_days);
   int count = 0;
   for(int shift = 2; shift <= strategy_daily_atr_median_days + 1; ++shift)
     {
      const double close_i = iClose(_Symbol, PERIOD_D1, shift);
      const double atr_i = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, shift);
      if(close_i <= 0.0 || atr_i <= 0.0)
         continue;
      ratios[count] = atr_i / close_i;
      count++;
     }

   if(count < MathMin(strategy_daily_atr_median_days, 20))
      return false;

   const double median_ratio = Strategy_Median(ratios, count);
   return (median_ratio > 0.0 && (current_atr / current_close) > median_ratio);
  }

bool Strategy_UptrendSetupOnBar(const int setup_shift)
  {
   if(strategy_lookback_bars <= 0)
      return false;

   const double setup_high = iHigh(_Symbol, PERIOD_M5, setup_shift);
   if(setup_high <= 0.0)
      return false;

   double prior_highest = -DBL_MAX;
   for(int shift = setup_shift + 1; shift <= setup_shift + strategy_lookback_bars; ++shift)
     {
      const double high_i = iHigh(_Symbol, PERIOD_M5, shift);
      if(high_i <= 0.0)
         return false;
      if(high_i > prior_highest)
         prior_highest = high_i;
     }

   return (prior_highest > 0.0 && setup_high > prior_highest);
  }

bool Strategy_StopDistanceAllowed(const double entry, const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0 || sl >= entry)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double stop_points = MathAbs(entry - sl) / point;
   return (stops_level <= 0 || stop_points > (double)stops_level);
  }

bool Strategy_NoTradeFilter()
  {
   const int symbol_slot = Strategy_CurrentSymbolSlot();
   if(symbol_slot < 0)
      return true;
   if(symbol_slot != qm_magic_slot_offset)
      return true;
   if(_Period != PERIOD_M5)
      return true;
   if(strategy_lookback_bars <= 0 || strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;

   const datetime ny_now = BrokerToNY(TimeCurrent());
   if(!IsWeekdayNY(ny_now))
      return true;
   if(HhmmFromTime(ny_now) >= strategy_session_close_hhmm)
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

   const datetime pullback_bar_open = iTime(_Symbol, PERIOD_M5, 1);
   if(pullback_bar_open <= 0 || pullback_bar_open == g_last_entry_eval_bar)
      return false;
   g_last_entry_eval_bar = pullback_bar_open;

   const datetime pullback_ny_close = BrokerToNY(pullback_bar_open + PeriodSeconds(PERIOD_M5));
   if(!Strategy_IsTradableEntryCloseNY(pullback_ny_close))
      return false;

   const int signal_day_key = DayKeyFromTime(pullback_ny_close);
   if(g_last_entry_day_key == signal_day_key)
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_DailyAtrRegimeAllows())
      return false;
   if(!Strategy_UptrendSetupOnBar(2))
      return false;

   const double pullback_close = iClose(_Symbol, PERIOD_M5, 1);
   const double setup_close = iClose(_Symbol, PERIOD_M5, 2);
   if(pullback_close <= 0.0 || setup_close <= 0.0 || pullback_close >= setup_close)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   const double entry = QM_EntryMarketPrice(QM_BUY);
   if(atr <= 0.0 || entry <= 0.0)
      return false;

   req.price = entry;
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_sl_mult);
   if(!Strategy_StopDistanceAllowed(entry, req.sl))
      return false;

   if(strategy_use_rr_take_profit)
      req.tp = QM_TakeRR(_Symbol, QM_BUY, entry, req.sl, strategy_take_profit_rr);

   req.reason = "UNGER_NASDAQ_PULLBACK_TF_LONG";
   g_last_entry_day_key = signal_day_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card default: fixed hard ATR stop, optional disabled RR target, no trailing.
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;

   const datetime ny_now = BrokerToNY(TimeCurrent());
   if(!IsWeekdayNY(ny_now))
      return true;
   return (HhmmFromTime(ny_now) >= HhmmAddMinutes(strategy_session_close_hhmm, -5));
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1106\",\"ea\":\"unger-nasdaq-pullback-tf\"}");
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
