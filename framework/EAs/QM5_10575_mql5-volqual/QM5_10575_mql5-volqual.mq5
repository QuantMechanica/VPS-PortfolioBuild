#property strict
#property version   "5.0"
#property description "QM5_10575 MQL5 VolatilityQuality color-change"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Strategy card: QM5_10575_mql5-volqual, G0 APPROVED 2026-05-22.
// Source: MQL5 CodeBase Exp_VolatilityQuality, VolatilityQuality line color
// changes on closed bars. Framework wiring below this strategy section stays
// unchanged from EA_Skeleton.mq5.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10575;
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
input int             strategy_vq_length        = 5;
input int             strategy_vq_smoothing     = 1;
input int             strategy_vq_filter_points = 5;
input ENUM_MA_METHOD  strategy_vq_ma_method     = MODE_LWMA;
input ENUM_APPLIED_PRICE strategy_vq_price       = PRICE_MEDIAN;
input int             strategy_atr_period       = 14;
input double          strategy_atr_sl_mult      = 2.0;
input double          strategy_rr_target        = 1.5;

// -----------------------------------------------------------------------------
// Strategy hooks and local helpers.
// -----------------------------------------------------------------------------

double Strategy_MA(const ENUM_APPLIED_PRICE price, const int shift)
  {
   if(strategy_vq_length <= 0 || shift <= 0)
      return 0.0;

   switch(strategy_vq_ma_method)
     {
      case MODE_SMA:
         return QM_SMA(_Symbol, _Period, strategy_vq_length, shift, price);
      case MODE_EMA:
         return QM_EMA(_Symbol, _Period, strategy_vq_length, shift, price);
      case MODE_SMMA:
         return QM_SMMA(_Symbol, _Period, strategy_vq_length, shift, price);
      case MODE_LWMA:
         return QM_LWMA(_Symbol, _Period, strategy_vq_length, shift, price);
     }

   return QM_LWMA(_Symbol, _Period, strategy_vq_length, shift, price);
  }

double Strategy_VQDelta(const int shift)
  {
   if(strategy_vq_length <= 0 || strategy_vq_smoothing <= 0 || shift <= 0)
      return 0.0;

   const double mc  = Strategy_MA(strategy_vq_price, shift);
   const double mc1 = Strategy_MA(strategy_vq_price, shift + strategy_vq_smoothing);
   const double mh  = Strategy_MA(PRICE_HIGH, shift);
   const double ml  = Strategy_MA(PRICE_LOW, shift);
   const double mo  = Strategy_MA(PRICE_OPEN, shift);

   if(mc <= 0.0 || mc1 <= 0.0 || mh <= 0.0 || ml <= 0.0 || mo <= 0.0)
      return 0.0;

   const double res1 = MathMax(mh - ml, MathMax(mh - mc1, mc1 - ml));
   const double res2 = mh - ml;
   if(res1 <= 0.0 || res2 <= 0.0)
      return 0.0;

   const double impulse = ((mc - mc1) / res1 + (mc - mo) / res2) * 0.5;
   const double signed_move = (mc - mc1 + (mc - mo)) * 0.5;
   const double delta = MathAbs(impulse) * signed_move;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(strategy_vq_filter_points > 0 && point > 0.0 &&
      MathAbs(delta) < point * strategy_vq_filter_points)
      return 0.0;

   return delta;
  }

int Strategy_VQColorAt(const int shift)
  {
   for(int i = 0; i < 6; ++i)
     {
      const double delta = Strategy_VQDelta(shift + i);
      if(delta > 0.0)
         return 1;
      if(delta < 0.0)
         return -1;
     }
   return 0;
  }

int Strategy_VQColorChange()
  {
   const int current_color = Strategy_VQColorAt(1);
   const int previous_color = Strategy_VQColorAt(2);
   if(current_color > 0 && previous_color < 0)
      return 1;
   if(current_color < 0 && previous_color > 0)
      return -1;
   return 0;
  }

bool Strategy_HasOurPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }

   return false;
  }

bool Strategy_ReadOurPositionType(ENUM_POSITION_TYPE &position_type)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0 ||
      strategy_rr_target <= 0.0 || Strategy_HasOurPosition())
      return false;

   const int signal = Strategy_VQColorChange();
   if(signal == 0)
      return false;

   const QM_OrderType side = (signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   req.type = side;
   req.sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   req.tp = QM_TakeRR(_Symbol, side, entry, req.sl, strategy_rr_target);
   req.reason = (side == QM_BUY) ? "VQ_BULL_COLOR_CHANGE" : "VQ_BEAR_COLOR_CHANGE";

   return (req.sl > 0.0 && req.tp > 0.0);
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   if(!Strategy_ReadOurPositionType(position_type))
      return false;

   const int signal = Strategy_VQColorChange();
   if(position_type == POSITION_TYPE_BUY && signal < 0)
      return true;
   if(position_type == POSITION_TYPE_SELL && signal > 0)
      return true;

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
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
