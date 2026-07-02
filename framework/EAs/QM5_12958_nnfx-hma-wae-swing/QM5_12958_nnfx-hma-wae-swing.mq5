#property strict
#property version   "5.0"
#property description "QM5_12958 NNFX HMA WAE swing"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12958;
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
input int    strategy_hma_period          = 20;
input int    strategy_wae_fast_macd       = 12;
input int    strategy_wae_slow_macd       = 26;
input int    strategy_wae_signal_macd     = 9;
input int    strategy_wae_bb_period       = 20;
input double strategy_wae_bb_deviation    = 2.0;
input double strategy_wae_sensitivity     = 150.0;
input double strategy_wae_deadzone_points = 15.0;
input int    strategy_atr_period          = 14;
input double strategy_sl_mult             = 1.5;
input double strategy_partial_tp_mult     = 1.0;
input double strategy_partial_fraction    = 0.50;

ulong g_partial_ticket = 0;

int Strategy_ExpectedSlot()
  {
   if(_Symbol == "XAUUSD.DWX")
      return 0;
   if(_Symbol == "GDAXI.DWX")
      return 1;
   if(_Symbol == "EURJPY.DWX")
      return 2;
   return -1;
  }

bool Strategy_IsTarget()
  {
   return (_Period == PERIOD_D1 && Strategy_ExpectedSlot() == qm_magic_slot_offset);
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

bool Strategy_WaeState(const int shift, double &bull, double &bear, double &explosion, double &deadzone)
  {
   bull = 0.0;
   bear = 0.0;
   explosion = 0.0;
   deadzone = 0.0;
   if(shift < 1)
      return false;

   const double macd_now = QM_MACD_Main(_Symbol, PERIOD_D1, strategy_wae_fast_macd,
                                        strategy_wae_slow_macd, strategy_wae_signal_macd,
                                        shift, PRICE_CLOSE);
   const double macd_prev = QM_MACD_Main(_Symbol, PERIOD_D1, strategy_wae_fast_macd,
                                         strategy_wae_slow_macd, strategy_wae_signal_macd,
                                         shift + 1, PRICE_CLOSE);
   const double upper = QM_BB_Upper(_Symbol, PERIOD_D1, strategy_wae_bb_period,
                                    strategy_wae_bb_deviation, shift, PRICE_CLOSE);
   const double lower = QM_BB_Lower(_Symbol, PERIOD_D1, strategy_wae_bb_period,
                                    strategy_wae_bb_deviation, shift, PRICE_CLOSE);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || upper <= 0.0 || lower <= 0.0)
      return false;

   const double trend = (macd_now - macd_prev) * strategy_wae_sensitivity;
   if(trend > 0.0)
      bull = trend;
   else
      bear = -trend;
   explosion = MathAbs(upper - lower);
   deadzone = strategy_wae_deadzone_points * point;
   return (explosion > 0.0 && deadzone >= 0.0);
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsTarget())
      return true;
   if(strategy_hma_period < 4)
      return true;
   if(strategy_wae_fast_macd <= 0 || strategy_wae_slow_macd <= strategy_wae_fast_macd)
      return true;
   if(strategy_wae_signal_macd <= 0 || strategy_wae_bb_period <= 1)
      return true;
   if(strategy_wae_bb_deviation <= 0.0 || strategy_wae_sensitivity <= 0.0)
      return true;
   if(strategy_wae_deadzone_points < 0.0)
      return true;
   if(strategy_atr_period <= 0 || strategy_sl_mult <= 0.0 || strategy_partial_tp_mult <= 0.0)
      return true;
   if(strategy_partial_fraction <= 0.0 || strategy_partial_fraction >= 1.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "NNFX_HMA_WAE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   const double close1 = iClose(_Symbol, PERIOD_D1, 1);
   const double close2 = iClose(_Symbol, PERIOD_D1, 2);
   const double hma1 = QM_HMA(_Symbol, PERIOD_D1, strategy_hma_period, 1, PRICE_CLOSE);
   const double hma2 = QM_HMA(_Symbol, PERIOD_D1, strategy_hma_period, 2, PRICE_CLOSE);
   if(close1 <= 0.0 || close2 <= 0.0 || hma1 <= 0.0 || hma2 <= 0.0)
      return false;

   double bull = 0.0;
   double bear = 0.0;
   double explosion = 0.0;
   double deadzone = 0.0;
   if(!Strategy_WaeState(1, bull, bear, explosion, deadzone))
      return false;

   int direction = 0;
   if(close1 > hma1 && close2 <= hma2 && bull > deadzone && bull > explosion)
      direction = 1;
   else if(close1 < hma1 && close2 >= hma2 && bear > deadzone && bear > explosion)
      direction = -1;
   else
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_sl_mult);
   if(req.sl <= 0.0)
      return false;
   req.reason = (direction > 0) ? "NNFX_HMA_WAE_LONG" : "NNFX_HMA_WAE_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(ticket == g_partial_ticket)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double market_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                              : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || market_price <= 0.0)
         continue;
      const double moved = (type == POSITION_TYPE_BUY) ? (market_price - open_price)
                                                       : (open_price - market_price);
      if(moved < atr * strategy_partial_tp_mult)
         continue;

      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double lots = volume * strategy_partial_fraction;
      if(QM_TM_PartialClose(ticket, lots, QM_EXIT_STRATEGY))
        {
         g_partial_ticket = ticket;
         const double be = QM_StopRulesNormalizePrice(_Symbol, open_price);
         const bool improves = (current_sl <= 0.0) ||
                               (type == POSITION_TYPE_BUY ? (be > current_sl)
                                                           : (be < current_sl));
         if(improves)
            QM_TM_MoveSL(ticket, be, "nnfx_be_after_partial");
        }
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const double close1 = iClose(_Symbol, PERIOD_D1, 1);
   const double hma1 = QM_HMA(_Symbol, PERIOD_D1, strategy_hma_period, 1, PRICE_CLOSE);
   if(close1 <= 0.0 || hma1 <= 0.0)
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
      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY && close1 < hma1)
         return true;
      if(type == POSITION_TYPE_SELL && close1 > hma1)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12958\",\"ea\":\"nnfx-hma-wae-swing\"}");
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
