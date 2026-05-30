#property strict
#property version   "5.0"
#property description "QM5_1079 Allocate Smartly Ivy Portfolio tactical overlay"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Strategy Card: QM5_1079_as-ivy-taa
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1079;
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
input int    strategy_sma_months        = 10;
input int    strategy_min_monthly_bars  = 12;
input int    strategy_atr_period_d1     = 20;
input double strategy_atr_sl_mult       = 4.0;
input double strategy_take_profit_rr    = 0.0;
input int    strategy_max_spread_points = 5000;

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
   if(slot == 5) return "XTIUSD.DWX";
   return "";
  }

bool Strategy_SymbolSlotAllowed()
  {
   return (_Symbol == Strategy_SymbolForSlot(qm_magic_slot_offset));
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_SymbolSlotAllowed())
      return true;

   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }

   return false;
  }

bool Strategy_IsMonthlyRebalanceBar()
  {
   if(_Period == PERIOD_MN1)
      return QM_IsNewBar(_Symbol, PERIOD_MN1);

   const datetime last_bar = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);
   const datetime prev_bar = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 2);
   if(last_bar <= 0 || prev_bar <= 0)
      return false;

   MqlDateTime last_dt;
   MqlDateTime prev_dt;
   TimeToStruct(last_bar, last_dt);
   TimeToStruct(prev_bar, prev_dt);
   return (last_dt.year != prev_dt.year || last_dt.mon != prev_dt.mon);
  }

bool Strategy_IsRiskOn()
  {
   if(strategy_sma_months <= 0 || strategy_min_monthly_bars < strategy_sma_months + 2)
      return false;
   if(Bars(_Symbol, PERIOD_MN1) < strategy_min_monthly_bars)
      return false;

   const double month_close = QM_SMA(_Symbol, PERIOD_MN1, 1, 1, PRICE_CLOSE);
   const double month_sma = QM_SMA(_Symbol, PERIOD_MN1, strategy_sma_months, 1, PRICE_CLOSE);
   if(month_close <= 0.0 || month_sma <= 0.0)
      return false;

   return (month_close > month_sma);
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

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "IVY_MONTH_CLOSE_ABOVE_SMA10";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_IsMonthlyRebalanceBar())
      return false;
   if(Strategy_HasOpenLong())
      return false;
   if(!Strategy_IsRiskOn())
      return false;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period_d1, strategy_atr_sl_mult);
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
   // Ivy TAA uses monthly risk-on/risk-off exits; no trailing, BE, or partials.
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenLong())
      return false;
   if(!Strategy_IsMonthlyRebalanceBar())
      return false;

   return !Strategy_IsRiskOn();
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1079_as_ivy_taa\"}");
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
