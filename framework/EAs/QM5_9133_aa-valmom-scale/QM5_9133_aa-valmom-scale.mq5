#property strict
#property version   "5.0"
#property description "QM5_9133 Alpha Architect Value Momentum Asset Class Scaling"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9133;
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
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_momentum_months    = 12;
input int    strategy_min_monthly_bars   = 14;
input int    strategy_atr_period_d1      = 20;
input double strategy_atr_sl_mult        = 2.5;
input int    strategy_max_spread_points  = 0;
input double strategy_min_slot_weight    = 0.01;
input double strategy_value_center       = 0.0;
input double strategy_value_threshold    = 0.01;
input bool   strategy_valuation_data_approved = true;
input double strategy_baseline_ndx       = 0.16666667;
input double strategy_baseline_ws30      = 0.16666667;
input double strategy_baseline_gdaxi     = 0.16666667;
input double strategy_baseline_xauusd    = 0.16666667;
input double strategy_baseline_xtiusd    = 0.16666667;
input double strategy_baseline_sp500     = 0.16666667;
input double strategy_value_ndx          = -0.02;
input double strategy_value_ws30         = 0.0;
input double strategy_value_gdaxi        = 0.0;
input double strategy_value_xauusd       = -0.02;
input double strategy_value_xtiusd       = 0.02;
input double strategy_value_sp500        = 0.0;

const int STRATEGY_SYMBOL_COUNT = 6;
string g_strategy_symbols[6] =
  {
   "NDX.DWX", "WS30.DWX", "GDAXI.DWX", "XAUUSD.DWX", "XTIUSD.DWX", "SP500.DWX"
  };

int Strategy_MonthKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 100 + dt.mon;
  }

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      if(g_strategy_symbols[i] == _Symbol)
         return i;
   return -1;
  }

bool Strategy_IsMonthlyRebalanceBar()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day > 3)
      return false;
   return true;
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

double Strategy_BaselineWeight(const int index)
  {
   switch(index)
     {
      case 0: return strategy_baseline_ndx;
      case 1: return strategy_baseline_ws30;
      case 2: return strategy_baseline_gdaxi;
      case 3: return strategy_baseline_xauusd;
      case 4: return strategy_baseline_xtiusd;
      case 5: return strategy_baseline_sp500;
     }
   return 0.0;
  }

double Strategy_ValuationScore(const int index)
  {
   switch(index)
     {
      case 0: return strategy_value_ndx;
      case 1: return strategy_value_ws30;
      case 2: return strategy_value_gdaxi;
      case 3: return strategy_value_xauusd;
      case 4: return strategy_value_xtiusd;
      case 5: return strategy_value_sp500;
     }
   return strategy_value_center;
  }

double Strategy_ValuationFactor(const int index)
  {
   const double score = Strategy_ValuationScore(index);
   if(score <= strategy_value_center - strategy_value_threshold)
      return 1.5;
   if(score >= strategy_value_center + strategy_value_threshold)
      return 0.5;
   return 1.0;
  }

bool Strategy_MomentumPositive(const string symbol)
  {
   if(strategy_momentum_months <= 0 || strategy_min_monthly_bars < strategy_momentum_months + 2)
      return false;
   if(Bars(symbol, PERIOD_MN1) < strategy_min_monthly_bars)
      return false;

   const double recent_close = iClose(symbol, PERIOD_MN1, 1);
   const double past_close = iClose(symbol, PERIOD_MN1, 1 + strategy_momentum_months);
   if(recent_close <= 0.0 || past_close <= 0.0)
      return false;
   return (recent_close > past_close);
  }

double Strategy_RawWeight(const int index)
  {
   if(index < 0 || index >= STRATEGY_SYMBOL_COUNT)
      return 0.0;

   const double baseline = MathMax(0.0, Strategy_BaselineWeight(index));
   if(baseline <= 0.0)
      return 0.0;

   const double valuation_adjusted = baseline * Strategy_ValuationFactor(index);
   const double momentum_factor = Strategy_MomentumPositive(g_strategy_symbols[index]) ? 1.5 : 0.5;
   return valuation_adjusted * momentum_factor;
  }

double Strategy_NormalizedWeight(const int index)
  {
   double total = 0.0;
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      total += Strategy_RawWeight(i);
   if(total <= 0.0)
      return 0.0;
   return Strategy_RawWeight(index) / total;
  }

bool Strategy_ConfigureTargetRisk(const double target_weight)
  {
   const double effective_weight = MathMin(1.0, MathMax(0.0, PORTFOLIO_WEIGHT * target_weight));
   if(effective_weight <= 0.0)
      return false;
   return QM_RiskSizerConfigure(g_qm_risk_mode,
                                RISK_PERCENT,
                                RISK_FIXED,
                                effective_weight,
                                g_qm_risk_per_trade_cap_money);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(!strategy_valuation_data_approved)
      return true;
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(strategy_max_spread_points > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > strategy_max_spread_points)
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
   req.reason = "QM5_9133_VALMOM_SCALE_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_IsMonthlyRebalanceBar())
      return false;
   if(Strategy_HasOpenPosition())
      return false;

   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return false;

   const double target_weight = Strategy_NormalizedWeight(index);
   if(target_weight < strategy_min_slot_weight)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_d1, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;
   if(!Strategy_ConfigureTargetRisk(target_weight))
      return false;

   req.reason = "QM5_9133_MONTHLY_VALUE_MOMENTUM_WEIGHT";
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Monthly rebalance exits are handled by Strategy_ExitSignal; the emergency ATR stop is set at entry.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;
   if(!Strategy_IsMonthlyRebalanceBar())
      return false;

   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return true;
   return (Strategy_NormalizedWeight(index) < strategy_min_slot_weight);
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      SymbolSelect(g_strategy_symbols[i], true);

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9133\",\"ea\":\"aa-valmom-scale\"}");
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

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
