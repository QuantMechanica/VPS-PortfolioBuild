#property strict
#property version   "5.0"
#property description "QM5_10208 TradingView PSAR ATR SMA Trend Trail"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Strategy: TradingView PSAR ATR SMA Trend Trail
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10208;
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
input ENUM_TIMEFRAMES strategy_timeframe       = PERIOD_H1;
input int    strategy_sma_period               = 100;
input int    strategy_atr_period               = 14;
input double strategy_atr_stop_mult            = 6.0;
input double strategy_psar_start               = 0.02;
input double strategy_psar_increment           = 0.02;
input double strategy_psar_maximum             = 0.20;
input double strategy_max_spread_stop_fraction = 0.15;
input int    strategy_psar_warmup_bars         = 80;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(ask <= 0.0 || bid <= 0.0 || atr <= 0.0 || strategy_atr_stop_mult <= 0.0)
      return true;

   const double spread = ask - bid;
   const double stop_distance = strategy_atr_stop_mult * atr;
   return (spread > strategy_max_spread_stop_fraction * stop_distance);
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

   if(strategy_sma_period <= 1 ||
      strategy_atr_period <= 0 ||
      strategy_atr_stop_mult <= 0.0 ||
      strategy_psar_start <= 0.0 ||
      strategy_psar_increment <= 0.0 ||
      strategy_psar_maximum <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int bars_needed = MathMax(strategy_psar_warmup_bars, 30);
   const int copied = CopyRates(_Symbol, strategy_timeframe, 1, bars_needed, rates); // perf-allowed: one bounded OHLC read inside the framework new-bar entry hook for PSAR state.
   if(copied < 10)
      return false;

   const double close_1 = rates[0].close;
   const double close_2 = rates[1].close;
   const double sma_1 = QM_SMA(_Symbol, strategy_timeframe, strategy_sma_period, 1);
   const double atr_1 = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(close_1 <= 0.0 || close_2 <= 0.0 || sma_1 <= 0.0 || atr_1 <= 0.0)
      return false;

   double psar_values[];
   bool psar_uptrend[];
   ArrayResize(psar_values, copied);
   ArrayResize(psar_uptrend, copied);
   ArrayInitialize(psar_values, 0.0);

   const int oldest = copied - 1;
   const int previous = oldest - 1;
   bool uptrend = (rates[previous].close >= rates[oldest].close);
   double af = strategy_psar_start;
   double ep = uptrend ? MathMax(rates[oldest].high, rates[previous].high)
                       : MathMin(rates[oldest].low, rates[previous].low);
   double sar = uptrend ? MathMin(rates[oldest].low, rates[previous].low)
                        : MathMax(rates[oldest].high, rates[previous].high);

   psar_values[oldest] = sar;
   psar_values[previous] = sar;
   psar_uptrend[oldest] = uptrend;
   psar_uptrend[previous] = uptrend;

   for(int bar = oldest - 2; bar >= 0; --bar)
     {
      sar = sar + af * (ep - sar);

      if(uptrend)
        {
         sar = MathMin(sar, rates[bar + 1].low);
         sar = MathMin(sar, rates[bar + 2].low);
         if(rates[bar].low < sar)
           {
            uptrend = false;
            sar = ep;
            ep = rates[bar].low;
            af = strategy_psar_start;
           }
         else if(rates[bar].high > ep)
           {
            ep = rates[bar].high;
            af = MathMin(af + strategy_psar_increment, strategy_psar_maximum);
           }
        }
      else
        {
         sar = MathMax(sar, rates[bar + 1].high);
         sar = MathMax(sar, rates[bar + 2].high);
         if(rates[bar].high > sar)
           {
            uptrend = true;
            sar = ep;
            ep = rates[bar].high;
            af = strategy_psar_start;
           }
         else if(rates[bar].low < ep)
           {
            ep = rates[bar].low;
            af = MathMin(af + strategy_psar_increment, strategy_psar_maximum);
           }
        }

      psar_values[bar] = sar;
      psar_uptrend[bar] = uptrend;
     }

   if(psar_values[0] <= 0.0 || psar_values[1] <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(close_1 > sma_1 && psar_values[0] < close_1 && psar_values[1] >= close_2 &&
      psar_uptrend[0] && !psar_uptrend[1])
     {
      req.type = QM_BUY;
      req.sl = NormalizeDouble(ask - strategy_atr_stop_mult * atr_1, _Digits);
      req.reason = "PSAR_ATR_SMA_LONG";
      return (req.sl > 0.0 && req.sl < ask);
     }

   if(close_1 < sma_1 && psar_values[0] > close_1 && psar_values[1] <= close_2 &&
      !psar_uptrend[0] && psar_uptrend[1])
     {
      req.type = QM_SELL;
      req.sl = NormalizeDouble(bid + strategy_atr_stop_mult * atr_1, _Digits);
      req.reason = "PSAR_ATR_SMA_SHORT";
      return (req.sl > bid);
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_atr_stop_mult);
     }
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10208\",\"ea\":\"QM5_10208_tv-psar-atr-sma\"}");
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
