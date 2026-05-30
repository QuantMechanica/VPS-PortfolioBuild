#property strict
#property version   "5.0"
#property description "QM5_1003 davey-baseline-3bar"

#include <QM/QM_Common.mqh>
input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1003;
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
input double atr_sl_mult            = 0.75;
input int    atr_period             = 14;
input int    max_spread_points      = 30;

string QM_ConfigStrategyName() { return "davey-baseline-3bar"; }
int    QM_ConfigEaId() { return 1003; }

bool HasPosition()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      return true;
   }
   return false;
}




bool Strategy_NoTradeFilter()
{

   if(max_spread_points > 0)
   {
      const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > max_spread_points) return true;
   }
   return false;

}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{

   if(HasPosition()) return false;

   const double close1 = iClose(_Symbol, PERIOD_D1, 1);
   const double close2 = iClose(_Symbol, PERIOD_D1, 2);
   const double close3 = iClose(_Symbol, PERIOD_D1, 3);
   if(close1 <= 0 || close2 <= 0 || close3 <= 0) return false;

   // LONG: three consecutive down closes (mean-reversion)
   // SHORT: three consecutive up closes (mean-reversion)
   bool long_signal = (close1 < close2 && close2 < close3);
   bool short_signal = (close1 > close2 && close2 > close3);

   if(!long_signal && !short_signal) return false;

   const double entry = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, atr_period, 1);
   if(atr <= 0) return false;

   double sl_dist = atr * atr_sl_mult;
   double sl = long_signal ? entry - sl_dist : entry + sl_dist;
   double tp = 0; // No TP — exit via opposite signal or stop

   req.type = long_signal ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_signal ? "3DN_LONG" : "3UP_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;

}

void Strategy_ManageOpenPosition()
{

}

bool Strategy_ExitSignal()
{

   if(!HasPosition()) return false;

   const double close1 = iClose(_Symbol, PERIOD_D1, 1);
   if(close1 <= 0) return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Exit on opposite 3-bar signal (reversal)
      const double c1 = iClose(_Symbol, PERIOD_D1, 1);
      const double c2 = iClose(_Symbol, PERIOD_D1, 2);
      const double c3 = iClose(_Symbol, PERIOD_D1, 3);
      if(c1 <= 0 || c2 <= 0 || c3 <= 0) continue;

      bool exit_signal = false;
      if(pt == POSITION_TYPE_BUY && c1 > c2 && c2 > c3)
         exit_signal = true;
      else if(pt == POSITION_TYPE_SELL && c1 < c2 && c2 < c3)
         exit_signal = true;

      if(exit_signal)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
         continue;
      }
   }
   return false;

}

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30,
                        qm_news_stale_max_hours, qm_news_min_impact,
                        qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance))
     return INIT_FAILED;
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1003\",\"strategy\":\"davey-baseline-3bar\"}");
   return INIT_SUCCEEDED;
  }


void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{{\"reason\":%d}}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {{
   if(!QM_KillSwitchCheck()) return;
   if(!QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;
   Strategy_ManageOpenPosition();
   Strategy_ExitSignal();
   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();
   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {{
    ulong out_ticket = 0;
    QM_TM_OpenPosition(req, out_ticket);
   }}
  }}


void OnTimer() {{ QM_FrameworkOnTimer(); }}
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {{ QM_FrameworkOnTradeTransaction(trans, request, result); }}
double OnTester() {{ QM_ChartUI_Refresh(); return QM_DefaultObjective(); }}

