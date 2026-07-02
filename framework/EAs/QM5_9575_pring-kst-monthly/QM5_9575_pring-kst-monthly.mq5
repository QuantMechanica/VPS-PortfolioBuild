#property strict
#property version   "5.0"
#property description "QM5_9575 Pring monthly KST long-cycle trend"

#include <QM/QM_Common.mqh>

#define STRATEGY_SYMBOL_COUNT 13

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9575;
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
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_proxy_days_per_month = 21;
input int    strategy_roc1_months          = 6;
input int    strategy_roc2_months          = 9;
input int    strategy_roc3_months          = 12;
input int    strategy_roc4_months          = 18;
input int    strategy_smooth1_months       = 6;
input int    strategy_smooth2_months       = 6;
input int    strategy_smooth3_months       = 9;
input int    strategy_smooth4_months       = 9;
input int    strategy_signal_months        = 9;
input int    strategy_long_ma_months       = 18;
input double strategy_kst_chase_level      = 20.0;
input int    strategy_atr_period           = 14;
input double strategy_sl_atr_mult          = 3.0;
input double strategy_spread_atr_fraction  = 0.20;
input int    strategy_time_stop_months     = 12;
input int    strategy_warmup_months        = 42;

string g_strategy_symbols[STRATEGY_SYMBOL_COUNT] =
  {
   "EURUSD.DWX",
   "GBPUSD.DWX",
   "USDJPY.DWX",
   "AUDUSD.DWX",
   "USDCAD.DWX",
   "USDCHF.DWX",
   "NZDUSD.DWX",
   "XAUUSD.DWX",
   "XTIUSD.DWX",
   "GDAXI.DWX",
   "NDX.DWX",
   "WS30.DWX",
   "UK100.DWX"
  };

int Strategy_SymbolSlot(const string symbol)
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      if(g_strategy_symbols[i] == symbol)
         return i;
   return -1;
  }

bool Strategy_IsTarget()
  {
   const int slot = Strategy_SymbolSlot(_Symbol);
   if(slot < 0)
      return false;
   if(qm_magic_slot_offset != slot)
      return false;
   return ((ENUM_TIMEFRAMES)_Period == PERIOD_D1);
  }

bool Strategy_HasOpenPosition()
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
      return true;
     }
   return false;
  }

int Strategy_OpenDirection()
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
      const long type = PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY)
         return +1;
      if(type == POSITION_TYPE_SELL)
         return -1;
     }
   return 0;
  }

datetime Strategy_OpenTime()
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
      return (datetime)PositionGetInteger(POSITION_TIME);
     }
   return 0;
  }

int Strategy_MonthDiff(const datetime earlier, const datetime later)
  {
   if(earlier <= 0 || later <= 0 || later <= earlier)
      return 0;
   MqlDateTime a;
   MqlDateTime b;
   TimeToStruct(earlier, a);
   TimeToStruct(later, b);
   int months = (b.year - a.year) * 12 + (b.mon - a.mon);
   if(b.day < a.day)
      months--;
   return (months < 0) ? 0 : months;
  }

bool Strategy_NewMonthClosed()
  {
   const int current_month = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const int closed_month = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1);
   return (current_month != 0 && closed_month != 0 && current_month != closed_month);
  }

int Strategy_D1ShiftForMonth(const int month_shift)
  {
   if(strategy_proxy_days_per_month < 10)
      return -1;
   if(month_shift < 0)
      return -1;
   return 1 + month_shift * strategy_proxy_days_per_month;
  }

bool Strategy_CloseAtMonth(const int month_shift, double &out_close)
  {
   out_close = 0.0;
   const int shift = Strategy_D1ShiftForMonth(month_shift);
   if(shift < 1)
      return false;
   const double c = iClose(_Symbol, PERIOD_D1, shift); // perf-allowed: D1-native monthly proxy close, bounded by KST warmup.
   if(c <= 0.0)
      return false;
   out_close = c;
   return true;
  }

bool Strategy_ROCAtMonth(const int month_shift,
                         const int roc_months,
                         double &out_roc)
  {
   out_roc = 0.0;
   if(roc_months <= 0)
      return false;
   double current_close = 0.0;
   double prior_close = 0.0;
   if(!Strategy_CloseAtMonth(month_shift, current_close))
      return false;
   if(!Strategy_CloseAtMonth(month_shift + roc_months, prior_close))
      return false;
   if(prior_close <= 0.0)
      return false;
   out_roc = 100.0 * ((current_close / prior_close) - 1.0);
   return true;
  }

bool Strategy_SmoothedROC(const int month_shift,
                          const int roc_months,
                          const int smooth_months,
                          double &out_value)
  {
   out_value = 0.0;
   if(smooth_months <= 0)
      return false;
   double sum = 0.0;
   for(int i = 0; i < smooth_months; ++i)
     {
      double roc = 0.0;
      if(!Strategy_ROCAtMonth(month_shift + i, roc_months, roc))
         return false;
      sum += roc;
     }
   out_value = sum / (double)smooth_months;
   return true;
  }

bool Strategy_KSTAtMonth(const int month_shift, double &out_kst)
  {
   out_kst = 0.0;
   double r1 = 0.0;
   double r2 = 0.0;
   double r3 = 0.0;
   double r4 = 0.0;
   if(!Strategy_SmoothedROC(month_shift, strategy_roc1_months, strategy_smooth1_months, r1))
      return false;
   if(!Strategy_SmoothedROC(month_shift, strategy_roc2_months, strategy_smooth2_months, r2))
      return false;
   if(!Strategy_SmoothedROC(month_shift, strategy_roc3_months, strategy_smooth3_months, r3))
      return false;
   if(!Strategy_SmoothedROC(month_shift, strategy_roc4_months, strategy_smooth4_months, r4))
      return false;
   out_kst = r1 + 2.0 * r2 + 3.0 * r3 + 4.0 * r4;
   return true;
  }

bool Strategy_SignalAtMonth(const int month_shift, double &out_signal)
  {
   out_signal = 0.0;
   if(strategy_signal_months <= 0)
      return false;
   double sum = 0.0;
   for(int i = 0; i < strategy_signal_months; ++i)
     {
      double kst = 0.0;
      if(!Strategy_KSTAtMonth(month_shift + i, kst))
         return false;
      sum += kst;
     }
   out_signal = sum / (double)strategy_signal_months;
   return true;
  }

bool Strategy_LongCycleMAAtMonth(const int month_shift, double &out_ma)
  {
   out_ma = 0.0;
   if(strategy_long_ma_months <= 0)
      return false;
   double sum = 0.0;
   for(int i = 0; i < strategy_long_ma_months; ++i)
     {
      double c = 0.0;
      if(!Strategy_CloseAtMonth(month_shift + i, c))
         return false;
      sum += c;
     }
   out_ma = sum / (double)strategy_long_ma_months;
   return true;
  }

bool Strategy_ReadMonthlyState(const int month_shift,
                               double &out_close,
                               double &out_kst,
                               double &out_signal,
                               double &out_ma)
  {
   if(!Strategy_CloseAtMonth(month_shift, out_close))
      return false;
   if(!Strategy_KSTAtMonth(month_shift, out_kst))
      return false;
   if(!Strategy_SignalAtMonth(month_shift, out_signal))
      return false;
   if(!Strategy_LongCycleMAAtMonth(month_shift, out_ma))
      return false;
   return true;
  }

bool Strategy_BuildSignal(int &out_direction,
                          bool &out_opposite_cross,
                          bool &out_ma_exit)
  {
   out_direction = 0;
   out_opposite_cross = false;
   out_ma_exit = false;
   if(!Strategy_NewMonthClosed())
      return false;

   double close0 = 0.0;
   double kst0 = 0.0;
   double sig0 = 0.0;
   double ma0 = 0.0;
   double close1 = 0.0;
   double kst1 = 0.0;
   double sig1 = 0.0;
   double ma1 = 0.0;
   if(!Strategy_ReadMonthlyState(0, close0, kst0, sig0, ma0))
      return false;
   if(!Strategy_ReadMonthlyState(1, close1, kst1, sig1, ma1))
      return false;

   const bool cross_up = (kst1 <= sig1 && kst0 > sig0);
   const bool cross_down = (kst1 >= sig1 && kst0 < sig0);
   const bool long_bias = (close0 > ma0);
   const bool short_bias = (close0 < ma0);

   if(cross_up && long_bias && kst0 < strategy_kst_chase_level)
      out_direction = +1;
   else if(cross_down && short_bias && kst0 > -strategy_kst_chase_level)
      out_direction = -1;

   const int open_dir = Strategy_OpenDirection();
   if(open_dir > 0)
     {
      out_opposite_cross = cross_down;
      out_ma_exit = short_bias;
     }
   else if(open_dir < 0)
     {
      out_opposite_cross = cross_up;
      out_ma_exit = long_bias;
     }
   return true;
  }

bool Strategy_WideSpread()
  {
   if(strategy_spread_atr_fraction <= 0.0)
      return false;
   const double atr = QM_ATR(_Symbol, PERIOD_W1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;
   const double spread = ask - bid;
   return (spread > 0.0 && spread > strategy_spread_atr_fraction * atr);
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsTarget())
      return true;
   if(Strategy_WideSpread())
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   if(!Strategy_IsTarget())
      return false;
   if(Strategy_HasOpenPosition())
      return false;

   int direction = 0;
   bool opposite_cross = false;
   bool ma_exit = false;
   if(!Strategy_BuildSignal(direction, opposite_cross, ma_exit))
      return false;
   if(direction == 0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_W1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   if(direction > 0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_sl_atr_mult);
      req.tp = 0.0;
      req.reason = "pring_kst_monthly_long";
      return (req.sl > 0.0);
     }

   const double entry_s = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_s <= 0.0)
      return false;
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry_s, atr, strategy_sl_atr_mult);
   req.tp = 0.0;
   req.reason = "pring_kst_monthly_short";
   return (req.sl > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_IsTarget())
      return false;
   if(!Strategy_HasOpenPosition())
      return false;

   const datetime opened = Strategy_OpenTime();
   if(strategy_time_stop_months > 0 && Strategy_MonthDiff(opened, TimeCurrent()) >= strategy_time_stop_months)
      return true;

   int direction = 0;
   bool opposite_cross = false;
   bool ma_exit = false;
   if(!Strategy_BuildSignal(direction, opposite_cross, ma_exit))
      return false;
   return (opposite_cross || ma_exit);
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

   if(!Strategy_IsTarget())
     {
      QM_LogEvent(QM_ERROR, "SETUP_CONFIG_INVALID", "{\"component\":\"symbol_slot_or_timeframe\"}");
      return INIT_FAILED;
     }

   QM_SymbolGuardInit(g_strategy_symbols);
   QM_BasketWarmupHistory(g_strategy_symbols, PERIOD_D1, strategy_warmup_months * strategy_proxy_days_per_month);
   QM_BasketWarmupHistory(g_strategy_symbols, PERIOD_W1, 80);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9575\",\"ea\":\"pring-kst-monthly\"}");
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
