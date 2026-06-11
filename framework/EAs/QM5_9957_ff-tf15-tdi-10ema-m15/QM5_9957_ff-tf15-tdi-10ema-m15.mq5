#property strict
#property version   "5.0"
#property description "QM5_9957 ForexFactory TF15 TDI 10EMA M15"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Source card: QM5_9957_ff-tf15-tdi-10ema-m15
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9957;
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
input int    strategy_fast_ema_period       = 10;
input int    strategy_side_ema_period       = 200;
input int    strategy_far_ema_period        = 800;
input int    strategy_slope_bars            = 3;
input int    strategy_tdi_rsi_period        = 13;
input int    strategy_tdi_green_smooth      = 2;
input int    strategy_tdi_yellow_smooth     = 34;
input int    strategy_atr_period            = 14;
input int    strategy_stop_pips             = 20;
input double strategy_atr_min_mult          = 0.7;
input double strategy_atr_max_mult          = 1.5;
input double strategy_atr_fallback_mult     = 1.0;
input double strategy_take_profit_rr        = 1.0;
input int    strategy_be_trigger_pips       = 12;
input int    strategy_be_buffer_pips        = 0;
input int    strategy_session_start_minutes = 480;
input int    strategy_session_end_minutes   = 990;
input double strategy_ema_sep_atr_mult      = 0.5;
input double strategy_max_spread_stop_frac  = 0.12;

double Strategy_PipDistance(const int pips)
  {
   if(pips <= 0)
      return 0.0;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return pips * point * pip_factor;
  }

double Strategy_StopDistance()
  {
   const double fixed_distance = Strategy_PipDistance(strategy_stop_pips);
   if(fixed_distance <= 0.0)
      return 0.0;

   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   if(atr <= 0.0)
      return fixed_distance;

   if(fixed_distance < strategy_atr_min_mult * atr ||
      fixed_distance > strategy_atr_max_mult * atr)
      return atr * strategy_atr_fallback_mult;

   return fixed_distance;
  }

double Strategy_TdiLine(const int shift, const int smooth_period)
  {
   if(shift < 1 || smooth_period < 1)
      return 0.0;

   double sum = 0.0;
   int samples = 0;
   for(int i = 0; i < smooth_period; ++i)
     {
      const double rsi = QM_RSI(_Symbol, PERIOD_M15, strategy_tdi_rsi_period, shift + i);
      if(rsi <= 0.0)
         return 0.0;
      sum += rsi;
      samples++;
     }

   if(samples <= 0)
      return 0.0;
   return sum / samples;
  }

int Strategy_TdiCrossSignal()
  {
   const double green_now = Strategy_TdiLine(1, strategy_tdi_green_smooth);
   const double green_prev = Strategy_TdiLine(2, strategy_tdi_green_smooth);
   const double yellow_now = Strategy_TdiLine(1, strategy_tdi_yellow_smooth);
   const double yellow_prev = Strategy_TdiLine(2, strategy_tdi_yellow_smooth);
   if(green_now <= 0.0 || green_prev <= 0.0 || yellow_now <= 0.0 || yellow_prev <= 0.0)
      return 0;

   if(green_now > yellow_now && green_prev <= yellow_prev)
      return 1;
   if(green_now < yellow_now && green_prev >= yellow_prev)
      return -1;
   return 0;
  }

bool Strategy_InSession()
  {
   datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   const int minutes = dt.hour * 60 + dt.min;
   return (minutes >= strategy_session_start_minutes &&
           minutes <= strategy_session_end_minutes);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M15)
      return true;

   if(!Strategy_InSession())
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   const double ema200 = QM_EMA(_Symbol, PERIOD_M15, strategy_side_ema_period, 1);
   const double ema800 = QM_EMA(_Symbol, PERIOD_M15, strategy_far_ema_period, 1);
   if(atr <= 0.0 || ema200 <= 0.0 || ema800 <= 0.0)
      return true;

   if(MathAbs(ema200 - ema800) < strategy_ema_sep_atr_mult * atr)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double stop_distance = Strategy_StopDistance();
   if(ask <= 0.0 || bid <= 0.0 || stop_distance <= 0.0)
      return true;

   if((ask - bid) > strategy_max_spread_stop_frac * stop_distance)
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

   if(_Period != PERIOD_M15)
      return false;

   const int tdi_cross = Strategy_TdiCrossSignal();
   if(tdi_cross == 0)
      return false;

   const int side200 = QM_Sig_Price_Above_MA(_Symbol, PERIOD_M15, strategy_side_ema_period, 0.0, 1);
   const int fast_now = QM_Sig_Price_Above_MA(_Symbol, PERIOD_M15, strategy_fast_ema_period, 0.0, 1);
   const int fast_prev = QM_Sig_Price_Above_MA(_Symbol, PERIOD_M15, strategy_fast_ema_period, 0.0, 2);
   const double ema_now = QM_EMA(_Symbol, PERIOD_M15, strategy_fast_ema_period, 1);
   const double ema_then = QM_EMA(_Symbol, PERIOD_M15, strategy_fast_ema_period, 1 + strategy_slope_bars);
   const double stop_distance = Strategy_StopDistance();
   if(side200 == 0 || fast_now == 0 || ema_now <= 0.0 || ema_then <= 0.0 || stop_distance <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(tdi_cross > 0 &&
      side200 > 0 &&
      fast_now > 0 &&
      fast_prev <= 0 &&
      ema_now > ema_then)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = QM_StopRulesStopFromDistance(_Symbol, req.type, req.price, stop_distance);
      req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_take_profit_rr);
      req.reason = "QM5_9957_LONG_TDI_10EMA";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   if(tdi_cross < 0 &&
      side200 < 0 &&
      fast_now < 0 &&
      fast_prev >= 0 &&
      ema_now < ema_then)
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = QM_StopRulesStopFromDistance(_Symbol, req.type, req.price, stop_distance);
      req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_take_profit_rr);
      req.reason = "QM5_9957_SHORT_TDI_10EMA";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      QM_TM_MoveToBreakEven(ticket, strategy_be_trigger_pips, strategy_be_buffer_pips);
     }
  }

bool Strategy_ExitSignal()
  {
   const int tdi_cross = Strategy_TdiCrossSignal();
   if(tdi_cross == 0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY && tdi_cross < 0)
         return true;
      if(type == POSITION_TYPE_SELL && tdi_cross > 0)
         return true;
     }

   return false;
  }

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
