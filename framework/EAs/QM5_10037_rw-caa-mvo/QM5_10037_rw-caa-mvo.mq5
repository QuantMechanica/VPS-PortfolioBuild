#property strict
#property version   "5.0"
#property description "QM5_10037 Robot Wealth CAA MVO"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 10037;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_lookback_months     = 4;
input double strategy_target_vol_pct      = 10.0;
input int    strategy_grid_step_pct       = 10;
input int    strategy_atr_period          = 20;
input double strategy_atr_sl_mult         = 4.0;
input int    strategy_rebalance_day_limit = 7;

const string STRATEGY_SYMBOL_SP500 = "SP500.DWX";
const string STRATEGY_SYMBOL_NDX   = "NDX.DWX";
const string STRATEGY_SYMBOL_WS30  = "WS30.DWX";
const string STRATEGY_SYMBOL_XAU   = "XAUUSD.DWX";

int    g_last_allocation_month_key = 0;
double g_target_allocation         = -1.0;
bool   g_rebalance_close_needed    = false;

int MonthKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

bool IsRebalanceWindow(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.day >= 1 && dt.day <= strategy_rebalance_day_limit);
  }

int CurrentSymbolIndex()
  {
   if(_Symbol == STRATEGY_SYMBOL_SP500)
      return 0;
   if(_Symbol == STRATEGY_SYMBOL_NDX)
      return 1;
   if(_Symbol == STRATEGY_SYMBOL_WS30)
      return 2;
   if(_Symbol == STRATEGY_SYMBOL_XAU)
      return 3;
   return -1;
  }

bool HasPositionForCurrentMagic()
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

double MonthlyReturn(const string symbol, const int shift)
  {
   const double mom = QM_Momentum(symbol, PERIOD_MN1, 1, shift);
   if(mom <= 0.0)
      return EMPTY_VALUE;
   return (mom / 100.0) - 1.0;
  }

bool HasCleanMonthlyHistory(const string symbol, const int months)
  {
   const int needed = (months > 12) ? months : 12;
   const double mom = QM_Momentum(symbol, PERIOD_MN1, needed, 1);
   return (mom > 0.0);
  }

bool LoadMonthlyReturns(const string symbol, const int months, double &out_returns[])
  {
   if(!HasCleanMonthlyHistory(symbol, months))
      return false;

   for(int i = 0; i < months; ++i)
     {
      const double r = MonthlyReturn(symbol, i + 1);
      if(r == EMPTY_VALUE)
         return false;
      out_returns[i] = r;
     }
   return true;
  }

double SelectAllocationForCurrentSymbol()
  {
   const int symbol_index = CurrentSymbolIndex();
   if(symbol_index < 0)
      return 0.0;

   int months = strategy_lookback_months;
   if(months < 3)
      months = 3;
   if(months > 12)
      months = 12;

   int step_units = strategy_grid_step_pct / 10;
   if(step_units < 1)
      step_units = 1;
   if(step_units > 10)
      step_units = 10;

   double r0[12];
   double r1[12];
   double r2[12];
   double r3[12];
   ArrayInitialize(r0, 0.0);
   ArrayInitialize(r1, 0.0);
   ArrayInitialize(r2, 0.0);
   ArrayInitialize(r3, 0.0);

   const bool ok0 = LoadMonthlyReturns(STRATEGY_SYMBOL_SP500, months, r0);
   const bool ok1 = LoadMonthlyReturns(STRATEGY_SYMBOL_NDX,   months, r1);
   const bool ok2 = LoadMonthlyReturns(STRATEGY_SYMBOL_WS30,  months, r2);
   const bool ok3 = LoadMonthlyReturns(STRATEGY_SYMBOL_XAU,   months, r3);

   int best0 = 0;
   int best1 = 0;
   int best2 = 0;
   int best3 = 0;
   double best_avg = -DBL_MAX;
   const double target_vol = strategy_target_vol_pct / 100.0;

   for(int u0 = 0; u0 <= 10; u0 += step_units)
     {
      if(!ok0 && u0 > 0)
         continue;
      for(int u1 = 0; u1 <= 10 - u0; u1 += step_units)
        {
         if(!ok1 && u1 > 0)
            continue;
         for(int u2 = 0; u2 <= 10 - u0 - u1; u2 += step_units)
           {
            if(!ok2 && u2 > 0)
               continue;
            for(int u3 = 0; u3 <= 10 - u0 - u1 - u2; u3 += step_units)
              {
               if(!ok3 && u3 > 0)
                  continue;

               double monthly_port[12];
               ArrayInitialize(monthly_port, 0.0);
               double avg = 0.0;
               for(int m = 0; m < months; ++m)
                 {
                  monthly_port[m] = (u0 * 0.1 * r0[m]) +
                                    (u1 * 0.1 * r1[m]) +
                                    (u2 * 0.1 * r2[m]) +
                                    (u3 * 0.1 * r3[m]);
                  avg += monthly_port[m];
                 }
               avg /= (double)months;

               double var_sum = 0.0;
               for(int m = 0; m < months; ++m)
                 {
                  const double d = monthly_port[m] - avg;
                  var_sum += d * d;
                 }
               const double denom = (months > 1) ? (double)(months - 1) : 1.0;
               const double ann_vol = MathSqrt(var_sum / denom) * MathSqrt(12.0);
               if(ann_vol <= target_vol && avg > best_avg)
                 {
                  best_avg = avg;
                  best0 = u0;
                  best1 = u1;
                  best2 = u2;
                  best3 = u3;
                 }
              }
           }
        }
     }

   if(symbol_index == 0)
      return best0 * 0.1;
   if(symbol_index == 1)
      return best1 * 0.1;
   if(symbol_index == 2)
      return best2 * 0.1;
   return best3 * 0.1;
  }

void RefreshMonthlyAllocation()
  {
   const datetime now = TimeCurrent();
   if(!IsRebalanceWindow(now))
      return;

   const int key = MonthKey(now);
   if(key == g_last_allocation_month_key)
      return;

   g_last_allocation_month_key = key;
   const double prior_allocation = g_target_allocation;
   g_target_allocation = SelectAllocationForCurrentSymbol();
   if(prior_allocation >= 0.0 && HasPositionForCurrentMagic())
      g_rebalance_close_needed = true;
  }

bool ConfigureRiskForTargetAllocation()
  {
   if(g_target_allocation <= 0.0 || g_target_allocation > 1.0)
      return false;

   if(RISK_FIXED > 0.0 && RISK_PERCENT == 0.0)
      return QM_RiskSizerConfigure(QM_RISK_MODE_FIXED, RISK_PERCENT, RISK_FIXED, g_target_allocation);

   if(RISK_PERCENT > 0.0 && RISK_FIXED == 0.0)
      return QM_RiskSizerConfigure(QM_RISK_MODE_PERCENT, RISK_PERCENT, RISK_FIXED, g_target_allocation);

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   return (CurrentSymbolIndex() < 0);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   RefreshMonthlyAllocation();

   if(g_rebalance_close_needed || g_target_allocation <= 0.0)
      return false;
   if(HasPositionForCurrentMagic())
      return false;
   if(!ConfigureRiskForTargetAllocation())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || atr <= 0.0 || point <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = ask - (strategy_atr_sl_mult * atr);
   req.tp = 0.0;
   req.reason = "RW_CAA_MVO_MONTHLY_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return (req.sl > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   RefreshMonthlyAllocation();
  }

bool Strategy_ExitSignal()
  {
   if(!g_rebalance_close_needed)
      return false;
   if(!HasPositionForCurrentMagic())
     {
      g_rebalance_close_needed = false;
      return false;
     }
   if(g_target_allocation > 0.0)
      g_rebalance_close_needed = false;
   return true;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10037_rw_caa_mvo\"}");
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
         if(PositionGetInteger(POSITION_MAGIC) != magic)
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
