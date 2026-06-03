#property strict
#property version   "5.0"
#property description "QM5_10427 Elite Trader Three-Bar XMA Range Breakout _v2"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica Strategy Card: QM5_10427_v2
// Logic: Three-bar breakout with XMA filter.
// Fixes: Increased news stale tolerance to avoid ONINIT_FAILED.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10427;
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
input int    strategy_xma_period          = 200;
input int    strategy_atr_period          = 20;
input double strategy_max_range_atr_mult  = 0.75;
input double strategy_min_stop_atr_mult   = 0.75;
input double strategy_body_range_min      = 0.65;
input double strategy_target_range_mult   = 0.50;
input int    strategy_entry_buffer_points = 0;
input int    strategy_window1_start_hhmm  = 0;
input int    strategy_window1_end_hhmm    = 2359;
input int    strategy_session_close_hhmm  = 2359;

// -----------------------------------------------------------------------------
// Strategy logic
// -----------------------------------------------------------------------------

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
   if(HasOurPosition()) return false;

   double h1 = iHigh(_Symbol, _Period, 1), h2 = iHigh(_Symbol, _Period, 2), h3 = iHigh(_Symbol, _Period, 3);
   double l1 = iLow(_Symbol, _Period, 1), l2 = iLow(_Symbol, _Period, 2), l3 = iLow(_Symbol, _Period, 3);
   double c1 = iClose(_Symbol, _Period, 1), o1 = iOpen(_Symbol, _Period, 1);
   double c2 = iClose(_Symbol, _Period, 2), o2 = iOpen(_Symbol, _Period, 2);
   double c3 = iClose(_Symbol, _Period, 3), o3 = iOpen(_Symbol, _Period, 3);

   double hh = MathMax(h1, MathMax(h2, h3));
   double ll = MathMin(l1, MathMin(l2, l3));
   double range = hh - ll;
   double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   double xma = QM_EMA(_Symbol, _Period, strategy_xma_period, 1);

   if(range <= 0 || atr <= 0 || xma <= 0 || range > strategy_max_range_atr_mult * atr) return false;

   bool bull = (c1 > o1 && c2 > o2 && c3 > o3);
   bool bear = (c1 < o1 && c2 < o2 && c3 < o3);

   if(bull && c1 > xma)
     {
      req.type = QM_BUY_STOP; req.price = hh;
      req.sl = hh - MathMax(range, strategy_min_stop_atr_mult * atr);
      req.tp = hh + strategy_target_range_mult * range;
      req.reason = "3BAR_XMA_LONG"; req.symbol_slot = qm_magic_slot_offset;
      return true;
     }
   else if(bear && c1 < xma)
     {
      req.type = QM_SELL_STOP; req.price = ll;
      req.sl = ll + MathMax(range, strategy_min_stop_atr_mult * atr);
      req.tp = ll - strategy_target_range_mult * range;
      req.reason = "3BAR_XMA_SHORT"; req.symbol_slot = qm_magic_slot_offset;
      return true;
     }
   return false;
  }

void Strategy_ManageOpenPosition() {}
bool Strategy_ExitSignal() { return false; }
bool Strategy_NoTradeFilter() { return false; }
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
