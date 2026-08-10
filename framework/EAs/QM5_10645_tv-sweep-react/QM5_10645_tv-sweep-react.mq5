#property strict
#property version   "5.0"
#property description "QM5_10645 Unknown Strategy"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_10645
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10645;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
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


// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return !(dt.hour >= 8 && dt.hour < 21);
}

double GetLastFractalLow()
{
   for(int i = 4; i < 100; i++)
   {
      double val = QM_FractalLower(_Symbol, _Period, i);
      if(val != EMPTY_VALUE && val > 0.0)
         return val;
   }
   return 0.0;
}

double GetLastFractalHigh()
{
   for(int i = 4; i < 100; i++)
   {
      double val = QM_FractalUpper(_Symbol, _Period, i);
      if(val != EMPTY_VALUE && val > 0.0)
         return val;
   }
   return 0.0;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   const int magic = QM_FrameworkMagic();
   if(QM_EntryHasOpenPosition(magic, _Symbol))
      return false;

   double atr = QM_ATR(_Symbol, _Period, 14, 1);
   if(atr <= 0.0)
      return false;

   double last_low = GetLastFractalLow();
   double c1 = iClose(_Symbol, _Period, 1); // perf-allowed
   double l1 = iLow(_Symbol, _Period, 1);   // perf-allowed
   double h1 = iHigh(_Symbol, _Period, 1);  // perf-allowed

   if(last_low > 0.0 && l1 < last_low && c1 > last_low)
   {
      double entry = h1;
      double sl = l1;
      double dist = entry - sl;
      if(dist >= 0.4 * atr && dist <= 3.0 * atr)
      {
         req.type = QM_BUY_STOP;
         req.price = entry;
         req.sl = sl;
         req.tp = entry + 2.0 * dist;
         req.reason = "tv-sweep-react BuyStop";
         return true;
      }
   }

   double last_high = GetLastFractalHigh();
   if(last_high > 0.0 && h1 > last_high && c1 < last_high)
   {
      double entry = l1;
      double sl = h1;
      double dist = sl - entry;
      if(dist >= 0.4 * atr && dist <= 3.0 * atr)
      {
         req.type = QM_SELL_STOP;
         req.price = entry;
         req.sl = sl;
         req.tp = entry - 2.0 * dist;
         req.reason = "tv-sweep-react SellStop";
         return true;
      }
   }

   return false;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour >= 21)
      return true;
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

void CancelAllPendingOrders()
{
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      QM_OrderType type = QM_OrderTypeFromMT5((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE));
      if(QM_OrderTypeIsStop(type) || QM_OrderTypeIsLimit(type))
      {
         QM_TM_RemovePendingOrder(ticket, "Cancel unfilled entry stop after one bar");
      }
   }
}

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
{
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!QM_IsNewBar()) return;
   CancelAllPendingOrders();
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
