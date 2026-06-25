#property strict
#property version   "5.0"
#property description "QM5_11330 tc-m5-16-wma5-sma11-psar-adx"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11330;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_wma_period        = 5;
input int    strategy_sma_period        = 11;
input double strategy_psar_step         = 0.01;
input double strategy_psar_max          = 0.10;
input int    strategy_adx_period        = 14;
input int    strategy_stop_model        = 1;     // 0=structure, 1=ATR, 2=structure_with_ATR_fallback
input int    strategy_swing_lookback    = 20;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.5;
input int    strategy_spread_cap_pips   = 12;

// Return TRUE to BLOCK trading this tick. Framework gates handle news,
// kill-switch, Friday close, and broker session; this hook adds card spread cap.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread = ask - bid;
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(spread > 0.0 && cap > 0.0 && spread > cap)
      return true;

   return false;
  }

// Caller guarantees QM_IsNewBar() == true. Card entry is simultaneous WMA/SMA,
// PSAR side, and ADX DI direction on the just-closed M5 bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(strategy_wma_period <= 0 || strategy_sma_period <= 0 ||
      strategy_adx_period <= 0 || strategy_atr_period <= 0)
      return false;

   const double wma = QM_WMA(_Symbol, _Period, strategy_wma_period, 1);
   const double sma = QM_SMA(_Symbol, _Period, strategy_sma_period, 1);
   const double sar = QM_SAR(_Symbol, _Period, strategy_psar_step, strategy_psar_max, 1);
   const double di_plus = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double di_minus = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 1);
   // perf-allowed: PSAR side needs the last closed candle close; no framework OHLC reader exists.
   const double close_1 = iClose(_Symbol, _Period, 1);
   if(wma <= 0.0 || sma <= 0.0 || sar <= 0.0 || close_1 <= 0.0)
      return false;
   if(di_plus <= 0.0 && di_minus <= 0.0)
      return false;

   int direction = 0;
   if(wma > sma && sar < close_1 && di_plus > di_minus)
      direction = 1;
   else if(wma < sma && sar > close_1 && di_minus > di_plus)
      direction = -1;
   else
      return false;

   const QM_OrderType side = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double sl = 0.0;
   if(strategy_stop_model == 0 || strategy_stop_model == 2)
      sl = QM_StopStructure(_Symbol, side, entry, strategy_swing_lookback);

   const bool structure_ok = (direction > 0) ? (sl > 0.0 && sl < entry)
                                             : (sl > 0.0 && sl > entry);
   if(strategy_stop_model == 1 || !structure_ok)
     {
      const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
      if(atr <= 0.0)
         return false;
      sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
     }

   const bool sl_ok = (direction > 0) ? (sl > 0.0 && sl < entry)
                                      : (sl > 0.0 && sl > entry);
   if(!sl_ok)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (direction > 0) ? "wma_sma_psar_adx_long" : "wma_sma_psar_adx_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Card does not specify trailing, break-even, partial close, or pyramiding.
void Strategy_ManageOpenPosition()
  {
  }

// Exit on PSAR reversal to the opposite side of the just-closed candle.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double sar = QM_SAR(_Symbol, _Period, strategy_psar_step, strategy_psar_max, 1);
   // perf-allowed: PSAR reversal compares SAR to the last closed candle close.
   const double close_1 = iClose(_Symbol, _Period, 1);
   if(sar <= 0.0 || close_1 <= 0.0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && sar > close_1)
         return true;
      if(ptype == POSITION_TYPE_SELL && sar < close_1)
         return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
