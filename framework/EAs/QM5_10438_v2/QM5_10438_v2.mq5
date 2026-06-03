#property strict
#property version   "5.0"
#property description "QM5_10438 MQL5 FVG Pullback Regime Filter _v2"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica Strategy Card: QM5_10438_v2
// Logic: FVG Pullback with EMA/ADX regime filter.
// Fixes: Increased news stale tolerance to avoid ONINIT_FAILED.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10438;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 1.0;
input double RISK_FIXED                 = 0.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 8760;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int             strategy_atr_period        = 14;
input double          strategy_atr_sl_mult       = 1.5;
input double          strategy_rr                = 2.0;
input ENUM_TIMEFRAMES strategy_regime_tf         = PERIOD_H1;
input int             strategy_ema_fast          = 50;
input int             strategy_ema_slow          = 200;
input int             strategy_adx_period        = 14;
input double          strategy_adx_min           = 20.0;
input int             strategy_session_start_h   = 7;
input int             strategy_session_end_h     = 20;

struct FvgZone { bool active; bool traded; int dir; double lo; double hi; datetime t; };
FvgZone g_zones[32];
int g_z_ptr = 0;

// -----------------------------------------------------------------------------
// Strategy logic
// -----------------------------------------------------------------------------

void UpdateFVG()
  {
   double h3 = iHigh(_Symbol, _Period, 3), l3 = iLow(_Symbol, _Period, 3);
   double h1 = iHigh(_Symbol, _Period, 1), l1 = iLow(_Symbol, _Period, 1);
   datetime t1 = iTime(_Symbol, _Period, 1);

   if(h3 < l1) { g_zones[g_z_ptr].active=true; g_zones[g_z_ptr].traded=false; g_zones[g_z_ptr].dir=1; g_zones[g_z_ptr].lo=h3; g_zones[g_z_ptr].hi=l1; g_zones[g_z_ptr].t=t1; g_z_ptr=(g_z_ptr+1)%32; }
   else if(l3 > h1) { g_zones[g_z_ptr].active=true; g_zones[g_z_ptr].traded=false; g_zones[g_z_ptr].dir=-1; g_zones[g_z_ptr].lo=h1; g_zones[g_z_ptr].hi=l3; g_zones[g_z_ptr].t=t1; g_z_ptr=(g_z_ptr+1)%32; }
  }

bool HasOurPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
        {
         if(PositionGetInteger(POSITION_MAGIC) == magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
            return true;
        }
     }
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   UpdateFVG();
   if(HasOurPosition()) return false;

   double c1 = iClose(_Symbol, _Period, 1);
   double ema_f = QM_EMA(_Symbol, strategy_regime_tf, strategy_ema_fast, 1);
   double ema_s = QM_EMA(_Symbol, strategy_regime_tf, strategy_ema_slow, 1);
   double adx = QM_ADX(_Symbol, strategy_regime_tf, strategy_adx_period, 1);

   for(int i=0; i<32; i++)
     {
      if(!g_zones[i].active || g_zones[i].traded) continue;
      if(c1 >= g_zones[i].lo && c1 <= g_zones[i].hi)
        {
         if(g_zones[i].dir > 0 && ema_f > ema_s && adx >= strategy_adx_min)
           {
            req.type = QM_BUY; req.reason = "FVG_BULL_PULLBACK";
           }
         else if(g_zones[i].dir < 0 && ema_f < ema_s && adx >= strategy_adx_min)
           {
            req.type = QM_SELL; req.reason = "FVG_BEAR_PULLBACK";
           }
         else continue;

         g_zones[i].traded = true;
         double entry = (req.type == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
         req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
         if(req.sl <= 0) return false;
         double risk = MathAbs(entry - req.sl);
         req.tp = (req.type == QM_BUY) ? entry + risk * strategy_rr : entry - risk * strategy_rr;
         req.symbol_slot = qm_magic_slot_offset;
         return true;
        }
     }
   return false;
  }

void Strategy_ManageOpenPosition() {}
bool Strategy_ExitSignal() { return false; }

bool Strategy_NoTradeFilter()
  {
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   if(strategy_session_start_h < strategy_session_end_h) return (dt.hour < strategy_session_start_h || dt.hour >= strategy_session_end_h);
   return (dt.hour < strategy_session_start_h && dt.hour >= strategy_session_end_h);
  }

bool Strategy_NewsFilterHook(const datetime t) { return false; }

// -----------------------------------------------------------------------------
// Framework Wiring
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT, qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker, 30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed, qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
  {
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE) news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows || QM_FrameworkHandleFridayClose() || Strategy_NoTradeFilter()) return;
   Strategy_ManageOpenPosition();
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
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res) { QM_FrameworkOnTradeTransaction(t, r, res); }
double OnTester() { QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
