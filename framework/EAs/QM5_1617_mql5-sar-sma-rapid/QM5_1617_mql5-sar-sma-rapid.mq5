#property strict
#property version   "5.0"
#property description "QM5_1617 MQL5 Rapid-Fire SAR Reversal With SMA Filter"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1617 — Rapid-Fire Parabolic SAR reversal with SMA(60) filter
// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_1617_mql5-sar-sma-rapid.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1617;
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
input double strategy_sar_step           = 0.02;
input double strategy_sar_maximum        = 0.20;
input int    strategy_sma_period         = 60;
input int    strategy_stop_points        = 150;
input int    strategy_take_profit_points = 100;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   return (_Period != PERIOD_M15);
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(strategy_sar_step <= 0.0 || strategy_sar_maximum <= 0.0 ||
      strategy_sma_period < 1 || strategy_stop_points <= 0 ||
      strategy_take_profit_points <= 0)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double sar_current = QM_SAR(_Symbol, PERIOD_M15,
                                     strategy_sar_step, strategy_sar_maximum, 1);
   const double sar_previous = QM_SAR(_Symbol, PERIOD_M15,
                                      strategy_sar_step, strategy_sar_maximum, 2);
   const double sma_current = QM_SMA(_Symbol, PERIOD_M15, strategy_sma_period,
                                     1, PRICE_CLOSE);
   const double low_current = iLow(_Symbol, PERIOD_M15, 1);    // perf-allowed: closed-bar hook
   const double high_current = iHigh(_Symbol, PERIOD_M15, 1);  // perf-allowed: closed-bar hook
   const double low_previous = iLow(_Symbol, PERIOD_M15, 2);   // perf-allowed: closed-bar hook
   const double high_previous = iHigh(_Symbol, PERIOD_M15, 2); // perf-allowed: closed-bar hook
   if(sar_current <= 0.0 || sar_previous <= 0.0 || sma_current <= 0.0 ||
      low_current <= 0.0 || high_current <= 0.0 ||
      low_previous <= 0.0 || high_previous <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   const bool buy_signal = (sar_current < low_current &&
                            sar_previous > high_previous &&
                            sma_current < ask);
   const bool sell_signal = (sar_current > high_current &&
                             sar_previous < low_previous &&
                             sma_current > bid);
   if(buy_signal == sell_signal)
      return false;

   const QM_OrderType side = buy_signal ? QM_BUY : QM_SELL;
   const double entry = buy_signal ? ask : bid;
   const double stop_distance = (double)strategy_stop_points * point;
   const double take_distance = (double)strategy_take_profit_points * point;
   const double stop = QM_TM_NormalizePrice(
      _Symbol, buy_signal ? entry - stop_distance : entry + stop_distance);
   const double take = QM_TM_NormalizePrice(
      _Symbol, buy_signal ? entry + take_distance : entry - take_distance);
   if(stop <= 0.0 || take <= 0.0)
      return false;
   if((buy_signal && (stop >= entry || take <= entry)) ||
      (sell_signal && (stop <= entry || take >= entry)))
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = stop;
   req.tp = take;
   req.reason = buy_signal ? "SAR_SMA_BUY" : "SAR_SMA_SELL";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
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
