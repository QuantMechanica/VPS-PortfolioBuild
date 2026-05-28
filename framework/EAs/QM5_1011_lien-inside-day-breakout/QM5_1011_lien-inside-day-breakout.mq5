#property strict
#property version   "5.0"
#property description "QM5_1011 lien-inside-day-breakout"

#include <QM/QM_Common.mqh>
input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1011;
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
input int    inside_days_min         = 2;
input int    breakout_offset_pips    = 10;
input int    stop_offset_pips        = 10;
input double tp1_rr                  = 2.0;
input int    max_spread_points       = 30;

string QM_ConfigStrategyName() { return "lien-inside-day-breakout"; }
int    QM_ConfigEaId() { return 1011; }

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


// Inside-day state tracking
int g_consecutive_inside = 0;
double g_prev_inside_high = 0;
double g_prev_inside_low = 0;
double g_nearest_inside_high = 0;
double g_nearest_inside_low = 0;

bool IsInsideDay(const int shift)
{
   const double h = iHigh(_Symbol, PERIOD_D1, shift);
   const double l = iLow(_Symbol, PERIOD_D1, shift);
   const double ph = iHigh(_Symbol, PERIOD_D1, shift + 1);
   const double pl = iLow(_Symbol, PERIOD_D1, shift + 1);
   if(h <= 0 || l <= 0 || ph <= 0 || pl <= 0) return false;
   return (h <= ph && l >= pl);
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

   // Count consecutive inside days (bar 1 = yesterday)
   int inside_count = 0;
   g_prev_inside_high = 0;
   g_prev_inside_low = 0;
   g_nearest_inside_high = 0;
   g_nearest_inside_low = 0;

   for(int b = 1; b <= inside_days_min + 2; b++)
   {
      if(IsInsideDay(b))
      {
         inside_count++;
         if(inside_count == 1)
         {
            g_prev_inside_high = iHigh(_Symbol, PERIOD_D1, b);
            g_prev_inside_low = iLow(_Symbol, PERIOD_D1, b);
         }
         g_nearest_inside_high = iHigh(_Symbol, PERIOD_D1, b);
         g_nearest_inside_low = iLow(_Symbol, PERIOD_D1, b);
      }
      else
      {
         inside_count = 0;
         g_prev_inside_high = 0;
         g_prev_inside_low = 0;
      }
   }

   if(inside_count < inside_days_min) return false;
   if(g_prev_inside_high <= 0 || g_prev_inside_low <= 0) return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Long bracket: stop-buy above prev inside day high
   const double long_entry = g_prev_inside_high + breakout_offset_pips * _Point;
   if(long_entry > ask)
   {
      req.type = QM_BUY;
      req.price = long_entry;
      req.sl = g_nearest_inside_low - stop_offset_pips * _Point;
      req.tp = 0;
      req.reason = "INSIDE_LONG";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 86400;
      return true;
   }

   // Short bracket: stop-sell below prev inside day low
   const double short_entry = g_prev_inside_low - breakout_offset_pips * _Point;
   if(short_entry < bid)
   {
      req.type = QM_SELL;
      req.price = short_entry;
      req.sl = g_nearest_inside_high + stop_offset_pips * _Point;
      req.tp = 0;
      req.reason = "INSIDE_SHORT";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 86400;
      return true;
   }

   return false;

}

void Strategy_ManageOpenPosition()
{

}

bool Strategy_ExitSignal()
{
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
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1011\",\"strategy\":\"lien-inside-day-breakout\"}");
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

