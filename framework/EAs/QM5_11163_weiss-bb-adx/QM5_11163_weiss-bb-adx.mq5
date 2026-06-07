#property strict
#property version   "5.0"
#property description "QM5_11163 Weissman Bollinger ADX mean reversion"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 11163;
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
input int    strategy_bb_period          = 20;
input double strategy_bb_deviation       = 2.0;
input int    strategy_adx_period         = 9;
input double strategy_adx_max            = 20.0;
input double strategy_profit_pct         = 0.0125;
input double strategy_source_parity_pct  = 0.0250;
input bool   strategy_use_source_parity_pct = true;
input int    strategy_max_spread_points  = 500;

ENUM_TIMEFRAMES Strategy_Timeframe()
  {
   return PERIOD_D1;
  }

int Strategy_SymbolSlot()
  {
   if(_Symbol == "EURUSD.DWX")
      return 0;
   if(_Symbol == "EURJPY.DWX")
      return 1;
   if(_Symbol == "EURCHF.DWX")
      return 2;
   if(_Symbol == "AUDCAD.DWX")
      return 3;
   if(_Symbol == "SP500.DWX")
      return 4;
   return -1;
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

double Strategy_ProfitPct()
  {
   if(strategy_use_source_parity_pct &&
      (_Symbol == "SP500.DWX" || StringFind(_Symbol, "JPY") >= 0))
      return strategy_source_parity_pct;
   return strategy_profit_pct;
  }

bool Strategy_StopDistanceAllowed(const double entry, const double sl, const double tp)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0 || tp <= 0.0)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stops_level <= 0)
      return true;

   const double sl_points = MathAbs(entry - sl) / point;
   const double tp_points = MathAbs(entry - tp) / point;
   return (sl_points > (double)stops_level && tp_points > (double)stops_level);
  }

bool Strategy_NoTradeFilter()
  {
   const int slot = Strategy_SymbolSlot();
   if(slot < 0 || slot != qm_magic_slot_offset)
      return true;
   if(_Period != Strategy_Timeframe())
      return true;
   if(strategy_bb_period < 2 || strategy_bb_deviation <= 0.0)
      return true;
   if(strategy_adx_period < 2 || strategy_adx_max <= 0.0)
      return true;
   if(strategy_profit_pct <= 0.0 || strategy_source_parity_pct <= 0.0)
      return true;

   const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_max_spread_points > 0 && spread > strategy_max_spread_points)
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

   if(Strategy_HasOpenPosition())
      return false;

   const ENUM_TIMEFRAMES tf = Strategy_Timeframe();
   const double adx = QM_ADX(_Symbol, tf, strategy_adx_period, 1);
   if(adx <= 0.0 || adx >= strategy_adx_max)
      return false;

   const int bb_now = QM_Sig_BB_MeanRev(_Symbol, tf, strategy_bb_period, strategy_bb_deviation, 1);
   const int bb_prev = QM_Sig_BB_MeanRev(_Symbol, tf, strategy_bb_period, strategy_bb_deviation, 2);
   const bool long_signal = (bb_now > 0 && bb_prev <= 0);
   const bool short_signal = (bb_now < 0 && bb_prev >= 0);
   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry = QM_EntryMarketPrice(side);
   const double pct = Strategy_ProfitPct();
   if(entry <= 0.0 || pct <= 0.0)
      return false;

   double sl = 0.0;
   double tp = 0.0;
   if(side == QM_BUY)
     {
      sl = entry * (1.0 - pct);
      tp = entry * (1.0 + pct);
     }
   else
     {
      sl = entry * (1.0 + pct);
      tp = entry * (1.0 - pct);
     }

   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   if(!Strategy_StopDistanceAllowed(entry, sl, tp))
      return false;

   req.type = side;
   req.price = entry;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_signal ? "WEISSMAN_BB_ADX_LONG" : "WEISSMAN_BB_ADX_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11163\",\"ea\":\"weiss-bb-adx\"}");
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
