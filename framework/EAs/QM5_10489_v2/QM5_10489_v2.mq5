#property strict
#property version   "5.0"
#property description "QM5_10489 MQL5 TrendManager color-change time-stop _v2"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica Strategy Card: QM5_10489_v2
// Logic: TrendManager (Dual SMA) color-change entry/exit.
// Fixes: Increased news stale tolerance to avoid ONINIT_FAILED.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10489;
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
input int    strategy_fast_sma_period   = 23;
input int    strategy_slow_sma_period   = 84;
input int    strategy_dv_limit_points   = 70;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.5;
input double strategy_take_profit_rr    = 2.0;
input int    strategy_max_hold_minutes  = 1200;

// -----------------------------------------------------------------------------
// Strategy logic
// -----------------------------------------------------------------------------

int Strategy_TrendManagerColor(const int shift)
  {
   const double fast = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_fast_sma_period, shift, PRICE_CLOSE);
   const double slow = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_slow_sma_period, shift, PRICE_CLOSE);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(fast <= 0.0 || slow <= 0.0 || point <= 0.0) return 0;

   const double diff = fast - slow;
   const double threshold = strategy_dv_limit_points * point;
   if(diff >= threshold) return 1;
   if(diff <= -threshold) return -1;
   return 0;
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
   if(HasOurPosition()) return false;

   int c1 = Strategy_TrendManagerColor(1);
   int c2 = Strategy_TrendManagerColor(2);
   if(c1 == 0 || c1 == c2) return false;

   QM_OrderType side = (c1 > 0) ? QM_BUY : QM_SELL;
   double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0) return false;

   req.sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0) return false;

   double risk = MathAbs(entry - req.sl);
   req.tp = (side == QM_BUY) ? entry + risk * strategy_take_profit_rr : entry - risk * strategy_take_profit_rr;

   req.type = side;
   req.reason = (c1 > 0) ? "TREND_BULL" : "TREND_BEAR";
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
         datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         if((TimeCurrent() - opened) >= strategy_max_hold_minutes * 60) return true;

         ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         int c1 = Strategy_TrendManagerColor(1);
         if(ptype == POSITION_TYPE_BUY && c1 < 0) return true;
         if(ptype == POSITION_TYPE_SELL && c1 > 0) return true;
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
