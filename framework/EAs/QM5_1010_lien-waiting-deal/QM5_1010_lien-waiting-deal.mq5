#property strict
#property version   "5.0"
#property description "QM5_1010 lien-waiting-deal"

#include <QM/QM_Common.mqh>
input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1010;
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
input int    spike_threshold_pips    = 25;
input int    entry_offset_pips       = 10;
input int    stop_offset_pips        = 25;
input int    max_spread_points       = 15;
input int    range_start_hour        = 6;   // GMT
input int    range_end_hour          = 7;   // GMT
input int    entry_window_end_hour   = 21;  // GMT

string QM_ConfigStrategyName() { return "lien-waiting-deal"; }
int    QM_ConfigEaId() { return 1010; }

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


enum EDealState
{
   DEAL_STATE_WAITING_RANGE,
   DEAL_STATE_WAITING_SPIKE,
   DEAL_STATE_WAITING_REVERSAL,
   DEAL_STATE_IN_POSITION,
};

EDealState g_deal_state = DEAL_STATE_WAITING_RANGE;
double g_range_high = 0;
double g_range_low = 0;
int g_range_bar_count = 0;

void ResetDealState()
{
   g_deal_state = DEAL_STATE_WAITING_RANGE;
   g_range_high = 0;
   g_range_low = 0;
   g_range_bar_count = 0;
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

   MqlDateTime gmt_dt;
   TimeToStruct(TimeGMT(), gmt_dt);
   const int gmt_hour = gmt_dt.hour;

   // State machine reset on new day
   if(gmt_hour < range_start_hour && g_deal_state != DEAL_STATE_WAITING_RANGE)
   {
      ResetDealState();
   }

   if(HasPosition()) return false;

   // State 0: Range definition window
   if(g_deal_state == DEAL_STATE_WAITING_RANGE)
   {
      if(gmt_hour >= range_start_hour && gmt_hour < range_end_hour)
      {
         const double h = iHigh(_Symbol, PERIOD_M5, 1);
         const double l = iLow(_Symbol, PERIOD_M5, 1);
         if(h > g_range_high) g_range_high = h;
         if(l < g_range_low || g_range_low == 0) g_range_low = l;
      }
      if(gmt_hour >= range_end_hour && g_range_high > 0 && g_range_low > 0)
         g_deal_state = DEAL_STATE_WAITING_SPIKE;
      return false;
   }

   // State 1: Awaiting spike outside range
   if(g_deal_state == DEAL_STATE_WAITING_SPIKE)
   {
      if(gmt_hour >= entry_window_end_hour)
      {
         ResetDealState();
         return false;
      }

      const double close1 = iClose(_Symbol, PERIOD_M5, 1);
      if(close1 <= 0) return false;

      const double spike_up = g_range_high + spike_threshold_pips * _Point;
      const double spike_down = g_range_low - spike_threshold_pips * _Point;

      // Track 0 = spiked up (wait for short), -1 = spiked down (wait for long)
      g_range_bar_count = 0; // reuse as spike direction indicator
      if(close1 >= spike_up)
      {
         g_deal_state = DEAL_STATE_WAITING_REVERSAL;
         g_range_bar_count = 0; // spiked UP -> arm SHORT
      }
      else if(close1 <= spike_down)
      {
         g_deal_state = DEAL_STATE_WAITING_REVERSAL;
         g_range_bar_count = -1; // spiked DOWN -> arm LONG
      }
      return false;
   }

   // State 2: Awaiting reversal back through opposite extreme
   if(g_deal_state == DEAL_STATE_WAITING_REVERSAL)
   {
      if(gmt_hour >= entry_window_end_hour)
      {
         ResetDealState();
         return false;
      }

      const double close1 = iClose(_Symbol, PERIOD_M5, 1);
      if(close1 <= 0) return false;

      if(g_range_bar_count == 0) // spiked UP, wait for reversal DOWN
      {
         if(close1 <= g_range_low)
         {
            const double entry = g_range_low - entry_offset_pips * _Point;
            if(entry < SymbolInfoDouble(_Symbol, SYMBOL_BID))
            {
               req.type = QM_SELL;
               req.price = entry;
               req.sl = g_range_low + stop_offset_pips * _Point;
               req.tp = 0;
               req.reason = "DEAL_SHORT";
               req.symbol_slot = qm_magic_slot_offset;
               req.expiration_seconds = 86400;
               g_deal_state = DEAL_STATE_IN_POSITION;
               return true;
            }
         }
      }
      else // spiked DOWN, wait for reversal UP
      {
         if(close1 >= g_range_high)
         {
            const double entry = g_range_high + entry_offset_pips * _Point;
            if(entry > SymbolInfoDouble(_Symbol, SYMBOL_ASK))
            {
               req.type = QM_BUY;
               req.price = entry;
               req.sl = g_range_high - stop_offset_pips * _Point;
               req.tp = 0;
               req.reason = "DEAL_LONG";
               req.symbol_slot = qm_magic_slot_offset;
               req.expiration_seconds = 86400;
               g_deal_state = DEAL_STATE_IN_POSITION;
               return true;
            }
         }
      }
      return false;
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
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1010\",\"strategy\":\"lien-waiting-deal\"}");
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

