#property strict
#property version   "5.0"
#property description "QM5_11737 rfs-adx-momentum-m5"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11737;
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
input int    strategy_adx_period        = 14;
input double strategy_adx_threshold     = 25.0;
input double strategy_di_threshold      = 25.0;
input int    strategy_momentum_period   = 14;
input double strategy_momentum_level    = 100.0;
input bool   strategy_use_ema_filter    = true;
input int    strategy_ema_period        = 55;
input int    strategy_sl_pips           = 6;
input double strategy_tp_rr             = 2.5;
input double strategy_max_spread_sl_pct = 25.0;

// -----------------------------------------------------------------------------
// Strategy hooks - implement the card's No Trade Filter, Trade Entry,
// Trade Management, Trade Close, and News Filter Hook.
// -----------------------------------------------------------------------------

// No Trade Filter: only block genuinely wide spreads. .DWX zero spread is valid.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   const double cap = stop_distance * strategy_max_spread_sl_pct / 100.0;
   if(spread > 0.0 && spread > cap)
      return true;

   return false;
  }

// Trade Entry: ADX/DI trend state + Momentum(14) state + optional EMA(55) bias.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(strategy_adx_period <= 0 || strategy_momentum_period <= 0 ||
      strategy_ema_period <= 0 || strategy_sl_pips <= 0 || strategy_tp_rr <= 0.0)
      return false;

   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   const double di_plus = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double di_minus = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double momentum = QM_Momentum(_Symbol, _Period, strategy_momentum_period, 1);
   const double close_bar = QM_EMA(_Symbol, _Period, 1, 1);
   const double ema = strategy_use_ema_filter ? QM_EMA(_Symbol, _Period, strategy_ema_period, 1) : 0.0;

   if(adx <= strategy_adx_threshold || di_plus <= 0.0 || di_minus <= 0.0 ||
      momentum <= 0.0 || close_bar <= 0.0)
      return false;
   if(strategy_use_ema_filter && ema <= 0.0)
      return false;

   const bool long_signal = (di_plus > strategy_di_threshold &&
                             di_plus > di_minus &&
                             momentum > strategy_momentum_level &&
                             (!strategy_use_ema_filter || close_bar > ema));
   const bool short_signal = (di_minus > strategy_di_threshold &&
                              di_minus > di_plus &&
                              momentum < strategy_momentum_level &&
                              (!strategy_use_ema_filter || close_bar < ema));

   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, side, entry, strategy_sl_pips);
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_signal ? "adx_momentum_long" : "adx_momentum_short";
   req.symbol_slot = qm_magic_slot_offset;
   return true;
  }

// Trade Management: card specifies fixed SL/TP only, no trailing or partials.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: flatten when the opposite ADX/DI + Momentum + EMA state appears.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   const double di_plus = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double di_minus = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double momentum = QM_Momentum(_Symbol, _Period, strategy_momentum_period, 1);
   const double close_bar = QM_EMA(_Symbol, _Period, 1, 1);
   const double ema = strategy_use_ema_filter ? QM_EMA(_Symbol, _Period, strategy_ema_period, 1) : 0.0;

   if(adx <= strategy_adx_threshold || di_plus <= 0.0 || di_minus <= 0.0 ||
      momentum <= 0.0 || close_bar <= 0.0)
      return false;
   if(strategy_use_ema_filter && ema <= 0.0)
      return false;

   const bool opposite_long = (di_plus > strategy_di_threshold &&
                               di_plus > di_minus &&
                               momentum > strategy_momentum_level &&
                               (!strategy_use_ema_filter || close_bar > ema));
   const bool opposite_short = (di_minus > strategy_di_threshold &&
                                di_minus > di_plus &&
                                momentum < strategy_momentum_level &&
                                (!strategy_use_ema_filter || close_bar < ema));

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && opposite_short)
         return true;
      if(ptype == POSITION_TYPE_SELL && opposite_long)
         return true;
     }

   return false;
  }

// News Filter Hook: no card-specific override; defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
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
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
        }
     }

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
