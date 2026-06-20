#property strict
#property version   "5.0"
#property description "QM5_11733 tc-m5-s15-ema-bb-channel-macd"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_11733 tc-m5-s15-ema-bb-channel-macd
// -----------------------------------------------------------------------------
// Mechanical build from approved Strategy Card:
// D:/QM/strategy_farm/artifacts/cards_approved/
// QM5_11733_tc-m5-s15-ema-bb-channel-macd.md
//
// Card rules:
// - EMA(50) of high and EMA(50) of low form the channel.
// - Long when EMA(15, close) is above the channel and MACD histogram is positive.
// - Short when EMA(15, close) is below the channel and MACD histogram is negative.
// - Entry is at the next bar open, implemented by the framework closed-bar gate.
// - SL and TP are both 2 * ATR(14), so target is 1R.
// - No discretionary exit override beyond SL/TP and framework exits.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11733;
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
input ENUM_TIMEFRAMES strategy_signal_timeframe = PERIOD_M5;
input int    strategy_ema_fast_period           = 15;
input int    strategy_channel_period            = 50;
input int    strategy_macd_fast                 = 15;
input int    strategy_macd_slow                 = 70;
input int    strategy_macd_signal               = 24;
input int    strategy_atr_period                = 14;
input double strategy_sl_atr_mult               = 2.0;
input double strategy_tp_atr_mult               = 2.0;

// Return TRUE to block trading this tick. The card declares no additional
// strategy no-trade filter, so central framework filters handle news/Friday/risk.
bool Strategy_NoTradeFilter()
  {
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

   if(strategy_ema_fast_period <= 0 ||
      strategy_channel_period <= 0 ||
      strategy_macd_fast <= 0 ||
      strategy_macd_slow <= strategy_macd_fast ||
      strategy_macd_signal <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_sl_atr_mult <= 0.0 ||
      strategy_tp_atr_mult <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double upper = QM_EMA(_Symbol, strategy_signal_timeframe, strategy_channel_period, 1, PRICE_HIGH);
   const double lower = QM_EMA(_Symbol, strategy_signal_timeframe, strategy_channel_period, 1, PRICE_LOW);
   const double ema_fast = QM_EMA(_Symbol, strategy_signal_timeframe, strategy_ema_fast_period, 1, PRICE_CLOSE);
   if(upper <= 0.0 || lower <= 0.0 || ema_fast <= 0.0)
      return false;

   const double macd_main = QM_MACD_Main(_Symbol, strategy_signal_timeframe,
                                         strategy_macd_fast, strategy_macd_slow,
                                         strategy_macd_signal, 1, PRICE_CLOSE);
   const double macd_signal = QM_MACD_Signal(_Symbol, strategy_signal_timeframe,
                                             strategy_macd_fast, strategy_macd_slow,
                                             strategy_macd_signal, 1, PRICE_CLOSE);
   const double macd_hist = macd_main - macd_signal;

   QM_OrderType side;
   if(ema_fast > upper && macd_hist > 0.0)
      side = QM_BUY;
   else if(ema_fast < lower && macd_hist < 0.0)
      side = QM_SELL;
   else
      return false;

   const double atr_value = QM_ATR(_Symbol, strategy_signal_timeframe, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry_price = (side == QM_BUY)
                              ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                              : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry_price, atr_value, strategy_sl_atr_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, side, entry_price, atr_value, strategy_tp_atr_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "ema_channel_macd_long" : "ema_channel_macd_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

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
