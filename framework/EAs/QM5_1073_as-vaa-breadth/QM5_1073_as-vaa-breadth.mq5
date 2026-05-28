#property strict
#property version   "5.0"
#property description "QM5_1073 Allocate Smartly VAA breadth momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Strategy Card: QM5_1073_as-vaa-breadth
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1073;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_min_monthly_bars      = 14;
input double strategy_score_floor           = 0.0;
input bool   strategy_use_defensive_proxy   = false;
input int    strategy_atr_period            = 20;
input double strategy_atr_sl_mult           = 4.0;
input double strategy_take_profit_rr        = 0.0;
input int    strategy_max_spread_points     = 5000;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

string Strategy_SymbolForSlot(const int slot)
  {
   if(slot == 0) return "SP500.DWX";
   if(slot == 1) return "NDX.DWX";
   if(slot == 2) return "WS30.DWX";
   if(slot == 3) return "GDAXI.DWX";
   if(slot == 4) return "XAUUSD.DWX";
   return "";
  }

bool Strategy_SymbolSlotMatches()
  {
   return (_Symbol == Strategy_SymbolForSlot(qm_magic_slot_offset));
  }

bool Strategy_IsRebalanceDay()
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

bool Strategy_MonthlyClose(const string symbol, const int shift, double &price)
  {
   price = 0.0;
   if(shift < 1)
      return false;
   if(Bars(symbol, PERIOD_MN1) <= shift)
      return false;

   price = QM_SMA(symbol, PERIOD_MN1, 1, shift, PRICE_CLOSE);
   return (price > 0.0);
  }

bool Strategy_WeightedMomentumScore(const string symbol, double &score)
  {
   score = 0.0;
   if(Bars(symbol, PERIOD_MN1) < strategy_min_monthly_bars)
      return false;

   double p0 = 0.0;
   double p1 = 0.0;
   double p3 = 0.0;
   double p6 = 0.0;
   double p12 = 0.0;
   if(!Strategy_MonthlyClose(symbol, 1, p0))  return false;
   if(!Strategy_MonthlyClose(symbol, 2, p1))  return false;
   if(!Strategy_MonthlyClose(symbol, 4, p3))  return false;
   if(!Strategy_MonthlyClose(symbol, 7, p6))  return false;
   if(!Strategy_MonthlyClose(symbol, 13, p12)) return false;

   score = 12.0 * (p0 / p1  - 1.0)
         +  4.0 * (p0 / p3  - 1.0)
         +  2.0 * (p0 / p6  - 1.0)
         +        (p0 / p12 - 1.0);
   return true;
  }

bool Strategy_OffensiveBreadthPositive()
  {
   for(int slot = 0; slot <= 3; ++slot)
     {
      double score = 0.0;
      if(!Strategy_WeightedMomentumScore(Strategy_SymbolForSlot(slot), score))
         return false;
      if(score <= strategy_score_floor)
         return false;
     }
   return true;
  }

string Strategy_BestOffensiveSymbol()
  {
   string best_symbol = "";
   double best_score = -DBL_MAX;
   for(int slot = 0; slot <= 3; ++slot)
     {
      const string symbol = Strategy_SymbolForSlot(slot);
      double score = 0.0;
      if(!Strategy_WeightedMomentumScore(symbol, score))
         return "";
      if(best_symbol == "" || score > best_score)
        {
         best_symbol = symbol;
         best_score = score;
        }
     }
   return best_symbol;
  }

string Strategy_SelectedSymbol()
  {
   if(Strategy_OffensiveBreadthPositive())
      return Strategy_BestOffensiveSymbol();

   if(!strategy_use_defensive_proxy)
      return "";

   double xau_score = 0.0;
   if(!Strategy_WeightedMomentumScore("XAUUSD.DWX", xau_score))
      return "";
   if(xau_score <= strategy_score_floor)
      return "";
   return "XAUUSD.DWX";
  }

bool Strategy_HasOpenLong()
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
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         return true;
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_SymbolSlotMatches())
      return true;

   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1073_VAA_MONTHLY";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return false;
   if(!Strategy_IsRebalanceDay())
      return false;
   if(Strategy_HasOpenLong())
      return false;
   if(Strategy_SelectedSymbol() != _Symbol)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   if(strategy_take_profit_rr > 0.0)
     {
      req.tp = QM_TakeRR(_Symbol, QM_BUY, entry, req.sl, strategy_take_profit_rr);
      if(req.tp <= entry)
         req.tp = 0.0;
     }

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card authorizes monthly rotation only; no trailing, BE, partial close,
   // pyramiding, or intramonth management rule is added here.
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_IsRebalanceDay())
      return false;
   if(!Strategy_HasOpenLong())
      return false;

   return (Strategy_SelectedSymbol() != _Symbol);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line.
// -----------------------------------------------------------------------------

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
