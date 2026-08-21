#property strict
#property version   "5.0"
#property description "QM5_12945 TradingView KN EMA-Cross ATR TP"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_12945
// Slug: tv-kn-ema-cross-atr-tp
// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_12945_tv-kn-ema-cross-atr-tp.md
// Source: TradingView KN - Smart TP SL Signals (Xmti9o4w)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12945;
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
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_H1;
input int    strategy_ema_fast_period    = 9;
input int    strategy_ema_slow_period    = 21;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 1.5;
input double strategy_atr_tp_mult        = 1.0;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(strategy_ema_fast_period < 1 ||
      strategy_ema_slow_period <= strategy_ema_fast_period ||
      strategy_atr_period < 1 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_atr_tp_mult <= 0.0)
      return true;
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const double fast_1 = QM_EMA(_Symbol, strategy_signal_tf,
                                strategy_ema_fast_period, 1, PRICE_CLOSE);
   const double fast_2 = QM_EMA(_Symbol, strategy_signal_tf,
                                strategy_ema_fast_period, 2, PRICE_CLOSE);
   const double slow_1 = QM_EMA(_Symbol, strategy_signal_tf,
                                strategy_ema_slow_period, 1, PRICE_CLOSE);
   const double slow_2 = QM_EMA(_Symbol, strategy_signal_tf,
                                strategy_ema_slow_period, 2, PRICE_CLOSE);
   const double atr_1 = QM_ATR(_Symbol, strategy_signal_tf,
                               strategy_atr_period, 1);
   if(fast_1 <= 0.0 || fast_2 <= 0.0 ||
      slow_1 <= 0.0 || slow_2 <= 0.0 || atr_1 <= 0.0)
      return false;

   int signal = 0;
   if(fast_2 <= slow_2 && fast_1 > slow_1)
      signal = 1;
   else if(fast_2 >= slow_2 && fast_1 < slow_1)
      signal = -1;
   if(signal == 0)
      return false;

   const QM_OrderType side = (signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (signal > 0)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.type = side;
   req.sl = QM_StopATRFromValue(_Symbol, side, entry,
                                atr_1, strategy_atr_sl_mult);
   req.tp = QM_TakeATRFromValue(_Symbol, side, entry,
                                atr_1, strategy_atr_tp_mult);
   req.reason = (signal > 0)
                ? "KN_EMA_CROSS_ATR_LONG"
                : "KN_EMA_CROSS_ATR_SHORT";

   if(signal > 0)
      return (req.sl > 0.0 && req.sl < entry && req.tp > entry);
   return (req.sl > entry && req.tp > 0.0 && req.tp < entry);
}

void Strategy_ManageOpenPosition()
{
   // The approved baseline uses only its server-side ATR SL and TP1 bracket.
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   int position_side = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      position_side = (position_type == POSITION_TYPE_BUY) ? 1 : -1;
      break;
   }
   if(position_side == 0)
      return false;

   const double fast_1 = QM_EMA(_Symbol, strategy_signal_tf,
                                strategy_ema_fast_period, 1, PRICE_CLOSE);
   const double fast_2 = QM_EMA(_Symbol, strategy_signal_tf,
                                strategy_ema_fast_period, 2, PRICE_CLOSE);
   const double slow_1 = QM_EMA(_Symbol, strategy_signal_tf,
                                strategy_ema_slow_period, 1, PRICE_CLOSE);
   const double slow_2 = QM_EMA(_Symbol, strategy_signal_tf,
                                strategy_ema_slow_period, 2, PRICE_CLOSE);
   if(fast_1 <= 0.0 || fast_2 <= 0.0 ||
      slow_1 <= 0.0 || slow_2 <= 0.0)
      return false;

   const int cross_signal =
      (fast_2 <= slow_2 && fast_1 > slow_1) ? 1 :
      ((fast_2 >= slow_2 && fast_1 < slow_1) ? -1 : 0);
   return (cross_signal != 0 && cross_signal == -position_side);
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
   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
}

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
