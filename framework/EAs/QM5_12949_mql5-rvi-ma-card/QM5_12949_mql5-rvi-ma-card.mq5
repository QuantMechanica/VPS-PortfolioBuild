#property strict
#property version   "5.0"
#property description "QM5_12949 MQL5 RVI MA Crossover"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_12949 - MQL5 RVI MA Crossover
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12949;
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
input int    strategy_rvi_period        = 10;
input int    strategy_ma_period         = 100;
input int    strategy_atr_period        = 14;
input int    strategy_atr_slow_period   = 100;
input double strategy_atr_min_ratio     = 0.5;
input double strategy_atr_sl_mult       = 1.6;
input double strategy_tp_r_mult         = 2.0;
input int    strategy_max_bars_in_trade = 48;
input int    strategy_max_spread_points = 0;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(strategy_max_spread_points <= 0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;

   if((ask - bid) / point > strategy_max_spread_points)
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

   const double atr14 = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr14 <= 0.0)
      return false;

   if(strategy_atr_min_ratio > 0.0 && strategy_atr_slow_period > 0)
   {
      const double atr100 = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_slow_period, 1);
      if(atr100 > 0.0 && atr14 < strategy_atr_min_ratio * atr100)
         return false; // dead volatility range filter per card
   }

   const double close1    = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);
   const double ma100     = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ma_period, 1, PRICE_CLOSE);
   const double rvi_main1 = QM_RVI_Main(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rvi_period, 1);
   const double rvi_sig1  = QM_RVI_Signal(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rvi_period, 1);

   if(close1 <= 0.0 || ma100 <= 0.0)
      return false;

   const bool buy_signal  = (close1 > ma100 && rvi_main1 > rvi_sig1);
   const bool sell_signal = (close1 < ma100 && rvi_main1 < rvi_sig1);

   if(!buy_signal && !sell_signal)
      return false;

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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && sell_signal)
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
      else if(ptype == POSITION_TYPE_SELL && buy_signal)
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
      return false; // exactly one open position per magic
   }

   if(buy_signal)
   {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr14, strategy_atr_sl_mult);
      if(entry <= 0.0 || sl <= 0.0)
         return false;

      const double risk_dist = entry - sl;
      const double tp = (strategy_tp_r_mult > 0.0 && risk_dist > 0.0) ? (entry + risk_dist * strategy_tp_r_mult) : 0.0;

      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = "rvi_ma_crossover_long";
      return true;
   }

   if(sell_signal)
   {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr14, strategy_atr_sl_mult);
      if(entry <= 0.0 || sl <= 0.0)
         return false;

      const double risk_dist = sl - entry;
      const double tp = (strategy_tp_r_mult > 0.0 && risk_dist > 0.0) ? (entry - risk_dist * strategy_tp_r_mult) : 0.0;

      req.type = QM_SELL;
      req.sl = sl;
      req.tp = tp;
      req.reason = "rvi_ma_crossover_short";
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
}

bool Strategy_ExitSignal()
{
   const double close1    = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);
   const double ma100     = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ma_period, 1, PRICE_CLOSE);
   const double rvi_main1 = QM_RVI_Main(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rvi_period, 1);
   const double rvi_sig1  = QM_RVI_Signal(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rvi_period, 1);

   if(close1 <= 0.0 || ma100 <= 0.0)
      return false;

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

      // Failsafe time exit after 48 H1 bars
      if(strategy_max_bars_in_trade > 0)
      {
         const datetime pos_time = (datetime)PositionGetInteger(POSITION_TIME);
         if(pos_time > 0)
         {
            const int bars_held = iBarShift(_Symbol, (ENUM_TIMEFRAMES)_Period, pos_time);
            if(bars_held >= strategy_max_bars_in_trade)
               return true;
         }
      }

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
      {
         if(rvi_main1 < rvi_sig1 || close1 < ma100)
            return true;
      }
      else if(ptype == POSITION_TYPE_SELL)
      {
         if(rvi_main1 > rvi_sig1 || close1 > ma100)
            return true;
      }
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
   QM_FrameworkTrackOpenPositionMae();
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
         ulong ticket = PositionGetTicket(i);
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

void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
