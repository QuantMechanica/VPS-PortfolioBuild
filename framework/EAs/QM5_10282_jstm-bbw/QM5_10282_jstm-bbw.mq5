#property strict
#property version   "5.0"
#property description "QM5_10282 Unknown Strategy"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_10282
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10282;
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

bool Strategy_NoTradeFilter() { return false; }

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   const int magic = QM_FrameworkMagic();
   if(QM_EntryHasOpenPosition(magic, _Symbol))
      return false;

   double upper_1 = QM_BB_Upper(_Symbol, _Period, 20, 2.0, 1);
   double price_1 = iClose(_Symbol, _Period, 1); // perf-allowed

   if(price_1 <= upper_1)
      return false;

   bool moveon = false;
   double threshold = 0.0;
   int j_node = -1;
   int k_node = -1;

   for(int j = 1; j <= 75; j++)
   {
      double price_j = iClose(_Symbol, _Period, j); // perf-allowed
      double mid_j = QM_BB_Middle(_Symbol, _Period, 20, 2.0, j);
      if(MathAbs(mid_j - price_j) < 0.0001 && MathAbs(mid_j - upper_1) < 0.0001)
      {
         j_node = j;
         moveon = true;
         break;
      }
   }

   if(moveon)
   {
      moveon = false;
      for(int k = j_node; k <= 75; k++)
      {
         double price_k = iClose(_Symbol, _Period, k); // perf-allowed
         double lower_k = QM_BB_Lower(_Symbol, _Period, 20, 2.0, k);
         if(MathAbs(lower_k - price_k) < 0.0001)
         {
            threshold = price_k;
            k_node = k;
            moveon = true;
            break;
         }
      }
   }

   if(moveon)
   {
      moveon = false;
      for(int l = k_node; l <= 75; l++)
      {
         double price_l = iClose(_Symbol, _Period, l); // perf-allowed
         double mid_l = QM_BB_Middle(_Symbol, _Period, 20, 2.0, l);
         if(mid_l < price_l)
         {
            moveon = true;
            break;
         }
      }
   }

   if(moveon)
   {
      moveon = false;
      for(int m = 1; m < j_node; m++)
      {
         double price_m = iClose(_Symbol, _Period, m); // perf-allowed
         double lower_m = QM_BB_Lower(_Symbol, _Period, 20, 2.0, m);
         if((price_m - lower_m < 0.0001) && (price_m > lower_m) && (price_m < threshold))
         {
            moveon = true;
            break;
         }
      }
   }

   if(moveon)
   {
      double atr = QM_ATR(_Symbol, _Period, 14, 1);
      if(atr <= 0.0)
         return false;

      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type = QM_BUY;
      req.price = ask;
      req.sl = ask - 2.0 * atr;
      req.tp = 0.0;
      req.reason = "jstm-bbw Bottom-W Buy";
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      datetime bar_time = iTime(_Symbol, _Period, 0); // perf-allowed
      if(open_time >= bar_time)
         return false;
      
      double upper_0 = QM_BB_Upper(_Symbol, _Period, 20, 2.0, 0);
      double mid_0 = QM_BB_Middle(_Symbol, _Period, 20, 2.0, 0);
      double std_dev = (upper_0 - mid_0) / 2.0;
      if(std_dev < 0.0001)
         return true;
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

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
