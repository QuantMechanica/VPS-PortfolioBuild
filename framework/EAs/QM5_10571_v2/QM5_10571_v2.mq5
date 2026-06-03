#property strict
#property version   "5.0"
#property description "QM5_10571 MQL5 PriceChannel Stop Trend Change _v2"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica Strategy Card: QM5_10571_v2
// Logic: Price Channel Stop trend reversal. 
// Fixes: Implemented internal logic (indicator missing), increased news tolerance.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10571;
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
input int    strategy_channel_period    = 22;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.0;
input double strategy_tp_r_multiple     = 1.5;

// Internal state
int g_trend = 0; // 1=Long, -1=Short

// -----------------------------------------------------------------------------
// Strategy logic
// -----------------------------------------------------------------------------

void UpdateTrend(const int shift)
  {
   double hh = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, strategy_channel_period, shift + 1));
   double ll = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, strategy_channel_period, shift + 1));
   double close = iClose(_Symbol, _Period, shift);

   if(close > hh) g_trend = 1;
   else if(close < ll) g_trend = -1;
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
   int prev_trend = g_trend;
   UpdateTrend(1);
   if(g_trend == 0 || g_trend == prev_trend || HasOurPosition()) return false;

   QM_OrderType side = (g_trend > 0) ? QM_BUY : QM_SELL;
   double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0) return false;

   req.sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0) return false;

   double risk = MathAbs(entry - req.sl);
   req.tp = (side == QM_BUY) ? entry + risk * strategy_tp_r_multiple : entry - risk * strategy_tp_r_multiple;

   req.type = side;
   req.reason = (g_trend > 0) ? "PCHAN_BULL_REVERSAL" : "PCHAN_BEAR_REVERSAL";
   req.symbol_slot = qm_magic_slot_offset;

   return true;
  }

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == magic)
        {
         ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         UpdateTrend(1);
         if(ptype == POSITION_TYPE_BUY && g_trend < 0) return true;
         if(ptype == POSITION_TYPE_SELL && g_trend > 0) return true;
        }
     }
   return false;
  }

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
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == magic) QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
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
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res) { QM_FrameworkOnTradeTransaction(t, r, res); }
double OnTester() { QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
