#property strict
#property version   "5.0"
#property description "QM5_1074 Allocate Smartly Defensive Asset Allocation canary"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Reduced DWX port of Keller/Keuning Defensive Asset Allocation:
// - Evaluate once per month on the first D1 bar of a new month.
// - Compute DAA weighted momentum for canary proxies.
// - Long the chart symbol when canaries are risk-on and the chart symbol has
//   positive weighted momentum.
// - Flat when canary regime turns defensive or chart-symbol momentum is <= 0.
//
// The full ETF universe is not broker-routable in MT5. This EA intentionally
// keeps the proxy choices as inputs so P1/P2 can document and approve the DWX
// mapping before any pipeline phase is run.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1074;
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
input bool   qm_friday_close_enabled     = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input string strategy_canary_1_symbol    = "NDX.DWX";
input string strategy_canary_2_symbol    = "";
input double strategy_cash_canary_score  = 0.0;
input int    strategy_max_negative_canaries_for_entry = 0;
input int    strategy_min_monthly_bars   = 14;
input int    strategy_atr_period_d1      = 20;
input double strategy_atr_sl_mult        = 4.0;
input int    strategy_max_spread_points  = 0;

bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   return false;
  }

bool Strategy_IsMonthlyRebalanceBar()
  {
   const datetime d0 = iTime(_Symbol, PERIOD_D1, 0);
   const datetime d1 = iTime(_Symbol, PERIOD_D1, 1);
   if(d0 <= 0 || d1 <= 0)
      return false;

   MqlDateTime t0;
   MqlDateTime t1;
   TimeToStruct(d0, t0);
   TimeToStruct(d1, t1);
   return (t0.year != t1.year || t0.mon != t1.mon);
  }

bool Strategy_HasOurPosition()
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

bool Strategy_WeightedMomentumScore(const string symbol, double &score)
  {
   score = 0.0;
   if(symbol == "")
     {
      score = strategy_cash_canary_score;
      return true;
     }

   if(Bars(symbol, PERIOD_MN1) < strategy_min_monthly_bars)
      return false;

   const double p0  = iClose(symbol, PERIOD_MN1, 1);
   const double p1  = iClose(symbol, PERIOD_MN1, 2);
   const double p3  = iClose(symbol, PERIOD_MN1, 4);
   const double p6  = iClose(symbol, PERIOD_MN1, 7);
   const double p12 = iClose(symbol, PERIOD_MN1, 13);
   if(p0 <= 0.0 || p1 <= 0.0 || p3 <= 0.0 || p6 <= 0.0 || p12 <= 0.0)
      return false;

   score = 12.0 * (p0 / p1 - 1.0)
         +  4.0 * (p0 / p3 - 1.0)
         +  2.0 * (p0 / p6 - 1.0)
         +        (p0 / p12 - 1.0);
   return true;
  }

bool Strategy_RiskRegimeAllowsRisk()
  {
   double score_1 = 0.0;
   double score_2 = 0.0;
   if(!Strategy_WeightedMomentumScore(strategy_canary_1_symbol, score_1))
      return false;
   if(!Strategy_WeightedMomentumScore(strategy_canary_2_symbol, score_2))
      return false;

   int negative_canaries = 0;
   if(score_1 < 0.0)
      negative_canaries++;
   if(score_2 < 0.0)
      negative_canaries++;

   return (negative_canaries <= strategy_max_negative_canaries_for_entry);
  }

bool Strategy_ThisSymbolEligible()
  {
   double own_score = 0.0;
   if(!Strategy_WeightedMomentumScore(_Symbol, own_score))
      return false;
   return (own_score > 0.0);
  }

bool Strategy_ShouldHoldRiskSleeve()
  {
   if(!Strategy_RiskRegimeAllowsRisk())
      return false;
   return Strategy_ThisSymbolEligible();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1074_DAA_CANARY_MONTHLY";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_IsMonthlyRebalanceBar())
      return false;
   if(Strategy_HasOurPosition())
      return false;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return false;
   if(!Strategy_ShouldHoldRiskSleeve())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(ask <= 0.0 || atr <= 0.0)
      return false;

   req.price = ask;
   req.sl = QM_StopATRFromValue(_Symbol, req.type, ask, atr, strategy_atr_sl_mult);
   return (req.sl > 0.0 && req.sl < ask);
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies monthly rebalance/exit only. No intramonth trailing or BE.
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_IsMonthlyRebalanceBar())
      return false;
   if(!Strategy_HasOurPosition())
      return false;

   return !Strategy_ShouldHoldRiskSleeve();
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0)
      return false;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1074_as_daa_canary\"}");
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
