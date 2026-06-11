#property strict
#property version   "5.0"
#property description "QM5_11554 Carter-T M5 WMA/SMA/Stoch/RSI/MACD"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11554;
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
input ENUM_TIMEFRAMES strategy_timeframe = PERIOD_M5;
input int    strategy_wma_period        = 10;
input int    strategy_sma_period        = 20;
input int    strategy_stoch_k_period    = 10;
input int    strategy_stoch_d_period    = 6;
input int    strategy_stoch_slowing     = 6;
input int    strategy_rsi_period        = 28;
input double strategy_rsi_midline       = 50.0;
input int    strategy_macd_fast         = 24;
input int    strategy_macd_slow         = 52;
input int    strategy_macd_signal       = 18;
input int    strategy_sl_lookback_bars  = 10;
input int    strategy_max_sl_pips       = 20;
input double strategy_rr                = 1.0;
input double strategy_max_spread_pips   = 5.0;

double Strategy_PipDistance(const double pips)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return pips * point * pip_factor;
  }

bool Strategy_IsFriday()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.day_of_week == 5);
  }

bool Strategy_NoTradeFilter()
  {
   if(Strategy_IsFriday())
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double max_spread = Strategy_PipDistance(strategy_max_spread_pips);
   if(ask <= 0.0 || bid <= 0.0 || max_spread <= 0.0)
      return true;

   return ((ask - bid) > max_spread);
  }

bool Strategy_BuildStops(const QM_OrderType side, const double entry, double &sl, double &tp)
  {
   sl = 0.0;
   tp = 0.0;
   if(entry <= 0.0 || strategy_sl_lookback_bars <= 0 || strategy_max_sl_pips <= 0 || strategy_rr <= 0.0)
      return false;

   const double structure_sl = QM_StopStructure(_Symbol, side, entry, strategy_sl_lookback_bars);
   const double fixed_sl = QM_StopFixedPips(_Symbol, side, entry, strategy_max_sl_pips);
   if(fixed_sl <= 0.0)
      return false;

   if(QM_OrderTypeIsBuy(side))
     {
      sl = (structure_sl > 0.0 && structure_sl < entry) ? MathMax(structure_sl, fixed_sl) : fixed_sl;
      if(sl >= entry)
         return false;
     }
   else
     {
      sl = (structure_sl > entry) ? MathMin(structure_sl, fixed_sl) : fixed_sl;
      if(sl <= entry)
         return false;
     }

   tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_rr);
   return (tp > 0.0);
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

   const double wma10 = QM_WMA(_Symbol, strategy_timeframe, strategy_wma_period, 1);
   const double sma20 = QM_SMA(_Symbol, strategy_timeframe, strategy_sma_period, 1);
   const double stoch_k = QM_Stoch_K(_Symbol, strategy_timeframe,
                                     strategy_stoch_k_period,
                                     strategy_stoch_d_period,
                                     strategy_stoch_slowing,
                                     1);
   const double stoch_d = QM_Stoch_D(_Symbol, strategy_timeframe,
                                     strategy_stoch_k_period,
                                     strategy_stoch_d_period,
                                     strategy_stoch_slowing,
                                     1);
   const double rsi28 = QM_RSI(_Symbol, strategy_timeframe, strategy_rsi_period, 1);
   const double macd_main = QM_MACD_Main(_Symbol, strategy_timeframe,
                                         strategy_macd_fast,
                                         strategy_macd_slow,
                                         strategy_macd_signal,
                                         1);
   if(wma10 <= 0.0 || sma20 <= 0.0 || rsi28 <= 0.0)
      return false;

   double entry = 0.0;
   if(wma10 > sma20 && stoch_k > stoch_d && rsi28 > strategy_rsi_midline && macd_main > 0.0)
     {
      req.type = QM_BUY;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(!Strategy_BuildStops(req.type, entry, req.sl, req.tp))
         return false;
      req.price = entry;
      req.reason = "CARTER_T_M5_LONG";
      return true;
     }

   if(wma10 < sma20 && stoch_k < stoch_d && rsi28 < strategy_rsi_midline && macd_main < 0.0)
     {
      req.type = QM_SELL;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(!Strategy_BuildStops(req.type, entry, req.sl, req.tp))
         return false;
      req.price = entry;
      req.reason = "CARTER_T_M5_SHORT";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, or partial-close management.
  }

bool Strategy_ExitSignal()
  {
   // Card exits only through the initial SL/TP plus framework Friday close.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11554\",\"source\":\"42530cb3-0265-534a-89cc-150f80733ff5\"}");
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
