#property strict
#property version   "5.0"
#property description "QM5_1618 MQL5 Moving Average Support-Resistance Touch"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1618 — Moving-average support/resistance touch continuation
// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_1618_mql5-ma-support.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1618;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode       qm_news_temporal        = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_DXZ;
input int                       qm_news_stale_max_hours = 336;
input string                    qm_news_min_impact      = "high";
input QM_NewsMode               qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ma_period          = 10;
input int    strategy_atr_period         = 14;
input double strategy_atr_buffer_mult    = 1.0;
input double strategy_max_stop_atr_mult  = 2.0;
input double strategy_take_profit_r      = 2.0;
input bool   strategy_require_ma_slope   = false;

bool Strategy_FindOpenPosition(long &position_type)
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
      position_type = PositionGetInteger(POSITION_TYPE);
      return true;
   }
   position_type = -1;
   return false;
}

bool Strategy_TouchSignals(bool &buy_signal, bool &sell_signal,
                           double &signal_low, double &signal_high,
                           double &ma_current, double &atr_value)
{
   buy_signal = false;
   sell_signal = false;
   signal_low = 0.0;
   signal_high = 0.0;
   ma_current = 0.0;
   atr_value = 0.0;

   if(strategy_ma_period < 1 || strategy_atr_period < 1 ||
      strategy_atr_buffer_mult < 0.0 || strategy_max_stop_atr_mult <= 0.0 ||
      strategy_take_profit_r < 0.0)
      return false;

   const double open_current = iOpen(_Symbol, PERIOD_H1, 1);   // perf-allowed: new-bar-gated caller
   const double close_current = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: new-bar-gated caller
   signal_low = iLow(_Symbol, PERIOD_H1, 1);                   // perf-allowed: new-bar-gated caller
   signal_high = iHigh(_Symbol, PERIOD_H1, 1);                 // perf-allowed: new-bar-gated caller
   ma_current = QM_SMA(_Symbol, PERIOD_H1, strategy_ma_period, 1, PRICE_CLOSE);
   const double ma_previous = QM_SMA(_Symbol, PERIOD_H1, strategy_ma_period, 2,
                                     PRICE_CLOSE);
   atr_value = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(open_current <= 0.0 || close_current <= 0.0 ||
      signal_low <= 0.0 || signal_high <= 0.0 ||
      ma_current <= 0.0 || ma_previous <= 0.0 || atr_value <= 0.0)
      return false;

   buy_signal = (signal_low <= ma_current &&
                 open_current > ma_current && close_current > ma_current);
   sell_signal = (signal_high >= ma_current &&
                  open_current < ma_current && close_current < ma_current);

   if(strategy_require_ma_slope)
   {
      buy_signal = buy_signal && (ma_current > ma_previous);
      sell_signal = sell_signal && (ma_current < ma_previous);
   }
   return true;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   return (_Period != PERIOD_H1);
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   bool buy_signal = false;
   bool sell_signal = false;
   double signal_low = 0.0;
   double signal_high = 0.0;
   double ma_current = 0.0;
   double atr_value = 0.0;
   if(!Strategy_TouchSignals(buy_signal, sell_signal, signal_low, signal_high,
                             ma_current, atr_value))
      return false;
   if(buy_signal == sell_signal)
      return false;

   const QM_OrderType side = buy_signal ? QM_BUY : QM_SELL;
   const double entry = buy_signal
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double raw_stop = buy_signal
                           ? signal_low - strategy_atr_buffer_mult * atr_value
                           : signal_high + strategy_atr_buffer_mult * atr_value;
   const double stop = QM_TM_NormalizePrice(_Symbol, raw_stop);
   if(stop <= 0.0 ||
      (buy_signal && stop >= entry) ||
      (sell_signal && stop <= entry))
      return false;

   const double stop_distance = MathAbs(entry - stop);
   if(stop_distance > strategy_max_stop_atr_mult * atr_value)
      return false;

   double take = 0.0;
   if(strategy_take_profit_r > 0.0)
   {
      take = QM_TakeRR(_Symbol, side, entry, stop, strategy_take_profit_r);
      if(take <= 0.0)
         return false;
   }

   req.type = side;
   req.price = 0.0;
   req.sl = stop;
   req.tp = take;
   req.reason = buy_signal ? "MA_TOUCH_BUY" : "MA_TOUCH_SELL";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
}

void Strategy_ManageOpenPosition()
{
}

bool Strategy_ExitSignal()
{
   long position_type = -1;
   if(!Strategy_FindOpenPosition(position_type))
      return false;

   bool buy_signal = false;
   bool sell_signal = false;
   double signal_low = 0.0;
   double signal_high = 0.0;
   double ma_current = 0.0;
   double atr_value = 0.0;
   if(!Strategy_TouchSignals(buy_signal, sell_signal, signal_low, signal_high,
                             ma_current, atr_value))
      return false;

   const double close_current = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: new-bar-gated caller
   if(close_current <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY)
      return (sell_signal || close_current < ma_current);
   if(position_type == POSITION_TYPE_SELL)
      return (buy_signal || close_current > ma_current);
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
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED,
                        PORTFOLIO_WEIGHT, qm_news_mode_legacy,
                        qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact,
                        qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
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

   if(!QM_IsNewBar())
      return;
   QM_EquityStreamOnNewBar();

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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

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
