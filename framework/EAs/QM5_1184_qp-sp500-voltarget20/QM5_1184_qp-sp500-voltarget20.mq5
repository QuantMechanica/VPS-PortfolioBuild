#property strict
#property version   "5.0"
#property description "QM5_1184 Quantpedia SP500 20D Volatility Targeting"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1184;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input double strategy_target_annual_vol   = 0.10;
input int    strategy_half_life_days      = 20;
input double strategy_min_exposure        = 0.25;
input double strategy_max_exposure        = 1.00;
input double strategy_rebalance_threshold = 0.25;
input double strategy_vol_exit_threshold  = 0.40;
input int    strategy_vol_exit_days       = 3;
input int    strategy_atr_period_d1       = 20;
input double strategy_atr_sl_mult         = 3.0;
input int    strategy_min_history_d1_bars = 90;
input int    strategy_max_spread_points   = 0;

const string STRATEGY_SYMBOL = "SP500.DWX";

datetime g_last_entry_bar = 0;
datetime g_last_exit_bar = 0;
datetime g_last_manage_bar = 0;
double   g_position_exposure = 0.0;

datetime Strategy_LastClosedD1Time()
  {
   return iTime(_Symbol, PERIOD_D1, 1);
  }

bool Strategy_TradingStatusValid(const string symbol)
  {
   if(!SymbolSelect(symbol, true))
      return false;
   return (SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_DISABLED);
  }

bool Strategy_HasOpenPosition(ulong &ticket, double &current_sl, datetime &opened_at)
  {
   ticket = 0;
   current_sl = 0.0;
   opened_at = 0;

   const int magic = QM_Magic(qm_ea_id, qm_magic_slot_offset);
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      ticket = pos_ticket;
      current_sl = PositionGetDouble(POSITION_SL);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_RealizedVolAnnualAtShift(const int first_shift, double &out_sigma)
  {
   out_sigma = 0.0;
   const int half_life = MathMax(1, strategy_half_life_days);
   const int lookback = MathMax(half_life * 5, half_life + 10);
   if(lookback > 512)
      return false;
   if(Bars(_Symbol, PERIOD_D1) < first_shift + lookback + 2)
      return false;

   const double lambda = MathExp(MathLog(0.5) / (double)half_life);
   double weight = 1.0;
   double weighted_sum = 0.0;
   double weight_total = 0.0;

   for(int i = 0; i < lookback; ++i)
     {
      const int shift = first_shift + i;
      const double c0 = iClose(_Symbol, PERIOD_D1, shift);
      const double c1 = iClose(_Symbol, PERIOD_D1, shift + 1);
      if(c0 <= 0.0 || c1 <= 0.0)
         return false;

      const double r = MathLog(c0 / c1);
      weighted_sum += weight * r * r;
      weight_total += weight;
      weight *= lambda;
     }

   if(weight_total <= 0.0 || weighted_sum <= 0.0)
      return false;

   out_sigma = MathSqrt(weighted_sum / weight_total) * MathSqrt(252.0);
   return (out_sigma > 0.0);
  }

double Strategy_TargetExposure(const double sigma_annual)
  {
   if(sigma_annual <= 0.0 || strategy_target_annual_vol <= 0.0)
      return 0.0;

   const double raw = strategy_target_annual_vol / sigma_annual;
   return MathMax(strategy_min_exposure, MathMin(strategy_max_exposure, raw));
  }

bool Strategy_CurrentExposure(double &out_sigma, double &out_exposure)
  {
   out_sigma = 0.0;
   out_exposure = 0.0;
   if(!Strategy_RealizedVolAnnualAtShift(1, out_sigma))
      return false;

   out_exposure = Strategy_TargetExposure(out_sigma);
   return (out_exposure >= strategy_min_exposure && out_exposure <= strategy_max_exposure);
  }

bool Strategy_VolExitTriggered()
  {
   const int days = MathMax(1, strategy_vol_exit_days);
   if(strategy_vol_exit_threshold <= 0.0)
      return false;

   for(int i = 0; i < days; ++i)
     {
      double sigma = 0.0;
      if(!Strategy_RealizedVolAnnualAtShift(1 + i, sigma))
         return false;
      if(sigma <= strategy_vol_exit_threshold)
         return false;
     }

   return true;
  }

bool Strategy_ConfigureScaledRisk(const double exposure)
  {
   if(exposure <= 0.0 || exposure > 1.0)
      return false;

   if(RISK_PERCENT > 0.0)
      return QM_RiskSizerConfigure(QM_RISK_MODE_PERCENT, RISK_PERCENT * exposure, 0.0, PORTFOLIO_WEIGHT);

   if(RISK_FIXED > 0.0)
      return QM_RiskSizerConfigure(QM_RISK_MODE_FIXED, 0.0, RISK_FIXED * exposure, PORTFOLIO_WEIGHT);

   return false;
  }

bool Strategy_StopDistanceAllowed(const double entry, const double sl)
  {
   if(entry <= 0.0 || sl <= 0.0 || sl >= entry)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double stop_points = MathAbs(entry - sl) / point;
   return (stops_level <= 0 || stop_points > (double)stops_level);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != STRATEGY_SYMBOL)
      return true;
   if(_Period != PERIOD_D1)
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(!Strategy_TradingStatusValid(_Symbol))
      return true;
   if(strategy_target_annual_vol <= 0.0 || strategy_half_life_days <= 0)
      return true;
   if(strategy_min_exposure <= 0.0 || strategy_max_exposure > 1.0 || strategy_min_exposure > strategy_max_exposure)
      return true;
   if(strategy_rebalance_threshold <= 0.0 || strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(Bars(_Symbol, PERIOD_D1) < MathMax(strategy_min_history_d1_bars, strategy_half_life_days * 5 + 10))
      return true;
   if(strategy_max_spread_points > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > strategy_max_spread_points)
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

   const datetime signal_bar = Strategy_LastClosedD1Time();
   if(signal_bar <= 0 || g_last_entry_bar == signal_bar)
      return false;

   ulong ticket = 0;
   double current_sl = 0.0;
   datetime opened_at = 0;
   if(Strategy_HasOpenPosition(ticket, current_sl, opened_at))
      return false;

   double sigma = 0.0;
   double exposure = 0.0;
   if(!Strategy_CurrentExposure(sigma, exposure))
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_sl_mult);
   if(!Strategy_StopDistanceAllowed(entry, sl))
      return false;
   if(!Strategy_ConfigureScaledRisk(exposure))
      return false;

   req.price = entry;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = "QM5_1184_SP500_VOLTARGET_LONG";

   g_position_exposure = exposure;
   g_last_entry_bar = signal_bar;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   double current_sl = 0.0;
   datetime opened_at = 0;
   if(!Strategy_HasOpenPosition(ticket, current_sl, opened_at))
      return;

   const datetime closed_bar = Strategy_LastClosedD1Time();
   if(closed_bar <= 0 || g_last_manage_bar == closed_bar)
      return;

   const double close1 = iClose(_Symbol, PERIOD_D1, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(close1 <= 0.0 || atr <= 0.0)
      return;

   const double trail = QM_TM_NormalizePrice(_Symbol, close1 - atr * strategy_atr_sl_mult);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(trail <= 0.0 || point <= 0.0)
      return;

   if(current_sl <= 0.0 || trail > current_sl + point * 0.5)
      QM_TM_MoveSL(ticket, trail, "QM5_1184_D1_ATR_TRAIL");

   g_last_manage_bar = closed_bar;
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   double current_sl = 0.0;
   datetime opened_at = 0;
   if(!Strategy_HasOpenPosition(ticket, current_sl, opened_at))
      return false;

   const datetime signal_bar = Strategy_LastClosedD1Time();
   if(signal_bar <= 0 || g_last_exit_bar == signal_bar)
      return false;

   if(Strategy_VolExitTriggered())
     {
      g_position_exposure = 0.0;
      g_last_exit_bar = signal_bar;
      return true;
     }

   double sigma = 0.0;
   double target_exposure = 0.0;
   if(!Strategy_CurrentExposure(sigma, target_exposure))
      return false;

   if(g_position_exposure <= 0.0)
     {
      g_position_exposure = target_exposure;
      return false;
     }

   const double relative_diff = MathAbs(target_exposure - g_position_exposure) / g_position_exposure;
   if(relative_diff >= strategy_rebalance_threshold)
     {
      g_position_exposure = 0.0;
      g_last_exit_bar = signal_bar;
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

   string symbols[1] = {STRATEGY_SYMBOL};
   QM_SymbolGuardInit(symbols);
   QM_BasketWarmupHistory(symbols, PERIOD_D1, MathMax(strategy_min_history_d1_bars, strategy_half_life_days * 5 + 10));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1184_qp-sp500-voltarget20\"}");
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
      const int magic = QM_Magic(qm_ea_id, qm_magic_slot_offset);
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
