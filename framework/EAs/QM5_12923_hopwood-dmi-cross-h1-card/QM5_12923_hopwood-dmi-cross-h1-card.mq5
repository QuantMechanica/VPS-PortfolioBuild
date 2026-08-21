#property strict
#property version   "5.0"
#property description "QM5_12923 Hopwood Wilders DMI Cross H1 Trend-Follower"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_12923
// Strategy card: QM5_12923 hopwood-dmi-cross-h1-card, G0 APPROVED.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 12923;
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
input int    strategy_dmi_period         = 14;
input double strategy_adx_threshold      = 22.0;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 2.0;
input double strategy_take_profit_rr     = 2.0;
input double strategy_adx_exit_threshold = 18.0;
input bool   strategy_require_h1         = true;

int GetOpenPositionDirection(const int magic)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         return 1;
      if(ptype == POSITION_TYPE_SELL)
         return -1;
     }
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(strategy_require_h1 && _Period != PERIOD_H1)
      return true;
   if(strategy_dmi_period <= 0 || strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(strategy_require_h1 && _Period != PERIOD_H1)
      return false;
   if(strategy_dmi_period <= 0 || strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double pdi1 = QM_ADX_PlusDI(_Symbol, PERIOD_H1, strategy_dmi_period, 1);
   const double mdi1 = QM_ADX_MinusDI(_Symbol, PERIOD_H1, strategy_dmi_period, 1);
   const double pdi2 = QM_ADX_PlusDI(_Symbol, PERIOD_H1, strategy_dmi_period, 2);
   const double mdi2 = QM_ADX_MinusDI(_Symbol, PERIOD_H1, strategy_dmi_period, 2);
   const double adx1 = QM_ADX(_Symbol, PERIOD_H1, strategy_dmi_period, 1);

   if(adx1 < strategy_adx_threshold)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   const bool bullish_cross = (pdi1 > mdi1 && pdi2 <= mdi2);
   const bool bearish_cross = (mdi1 > pdi1 && mdi2 <= pdi2);

   if(bullish_cross)
     {
      req.type = QM_BUY;
      req.price = ask;
      const double stop = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_atr_sl_mult);
      if(stop <= 0.0 || stop >= ask)
         return false;
      req.sl = NormalizeDouble(stop, _Digits);
      if(strategy_take_profit_rr > 0.0)
         req.tp = NormalizeDouble(QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_take_profit_rr), _Digits);
      else
         req.tp = 0.0;
      req.reason = "HOPWOOD_DMI_CROSS_BUY";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return ((ask - req.sl) / point > 0.0);
     }
   else if(bearish_cross)
     {
      req.type = QM_SELL;
      req.price = bid;
      const double stop = QM_StopATR(_Symbol, QM_SELL, bid, strategy_atr_period, strategy_atr_sl_mult);
      if(stop <= 0.0 || stop <= bid)
         return false;
      req.sl = NormalizeDouble(stop, _Digits);
      if(strategy_take_profit_rr > 0.0)
         req.tp = NormalizeDouble(QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_take_profit_rr), _Digits);
      else
         req.tp = 0.0;
      req.reason = "HOPWOOD_DMI_CROSS_SELL";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return ((req.sl - bid) / point > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Baseline has fixed SL/TP exits.
  }

bool Strategy_ExitSignal()
  {
   if(strategy_require_h1 && _Period != PERIOD_H1)
      return false;

   const int magic = QM_FrameworkMagic();
   const int pos_dir = GetOpenPositionDirection(magic);
   if(pos_dir == 0)
      return false;

   const double pdi1 = QM_ADX_PlusDI(_Symbol, PERIOD_H1, strategy_dmi_period, 1);
   const double mdi1 = QM_ADX_MinusDI(_Symbol, PERIOD_H1, strategy_dmi_period, 1);
   const double pdi2 = QM_ADX_PlusDI(_Symbol, PERIOD_H1, strategy_dmi_period, 2);
   const double mdi2 = QM_ADX_MinusDI(_Symbol, PERIOD_H1, strategy_dmi_period, 2);
   const double adx1 = QM_ADX(_Symbol, PERIOD_H1, strategy_dmi_period, 1);

   if(pos_dir > 0)
     {
      const bool bearish_cross = (mdi1 > pdi1 && mdi2 <= pdi2);
      const bool adx_exit = (strategy_adx_exit_threshold > 0.0 && adx1 > 0.0 && adx1 < strategy_adx_exit_threshold);
      if(bearish_cross || adx_exit)
         return true;
     }
   else if(pos_dir < 0)
     {
      const bool bullish_cross = (pdi1 > mdi1 && pdi2 <= mdi2);
      const bool adx_exit = (strategy_adx_exit_threshold > 0.0 && adx1 > 0.0 && adx1 < strategy_adx_exit_threshold);
      if(bullish_cross || adx_exit)
         return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12923\",\"ea\":\"hopwood-dmi-cross-h1-card\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();

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
         if(!PositionSelectByTicket(ticket))
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
   ZeroMemory(req);
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
