#property strict
#property version   "5.0"
#property description "QM5_9294 MQL5 TRIX WPR Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9294;
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
input int    strategy_trix_period          = 14;
input int    strategy_trix_extreme_lookback = 20;
input int    strategy_wpr_period           = 14;
input int    strategy_ema_period           = 20;
input int    strategy_atr_period           = 14;
input double strategy_atr_sl_mult          = 1.5;
input int    strategy_slope_median_lookback = 20;
input int    strategy_max_spread_points    = 0;

double g_trix_current = 0.0;
double g_trix_previous = 0.0;
double g_trix_roll_max = 0.0;
double g_trix_roll_min = 0.0;
double g_wpr_current = 0.0;
double g_ema_current = 0.0;
double g_close_current = 0.0;
double g_slope_abs = 0.0;
double g_slope_median = 0.0;
bool   g_signal_cache_ready = false;

bool SelectOurPosition(ENUM_POSITION_TYPE &ptype)
  {
   ptype = POSITION_TYPE_BUY;
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
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

double MedianValue(double &values[], const int count)
  {
   if(count <= 0)
      return 0.0;
   ArraySort(values);
   if((count % 2) == 1)
      return values[count / 2];
   return 0.5 * (values[count / 2 - 1] + values[count / 2]);
  }

bool RefreshSignalCache()
  {
   g_signal_cache_ready = false;

   if(strategy_trix_period < 2 ||
      strategy_trix_extreme_lookback < 2 ||
      strategy_wpr_period < 2 ||
      strategy_ema_period < 2 ||
      strategy_atr_period < 1 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_slope_median_lookback < 1)
      return false;

   const int needed_shift = MathMax(strategy_trix_extreme_lookback + 2,
                                    strategy_slope_median_lookback + 2);
   const int warmup = strategy_trix_period * 8;
   const int bars_needed = needed_shift + warmup + 10;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, _Period, 0, bars_needed, closes); // perf-allowed: bespoke TRIX, called from framework new-bar path or initial cache hydrate.
   if(copied < needed_shift + 3)
      return false;

   double ema1[];
   double ema2[];
   double ema3[];
   ArrayResize(ema1, copied);
   ArrayResize(ema2, copied);
   ArrayResize(ema3, copied);
   ArraySetAsSeries(ema1, true);
   ArraySetAsSeries(ema2, true);
   ArraySetAsSeries(ema3, true);

   const double alpha = 2.0 / ((double)strategy_trix_period + 1.0);
   const int oldest = copied - 1;
   ema1[oldest] = closes[oldest];
   ema2[oldest] = ema1[oldest];
   ema3[oldest] = ema2[oldest];

   for(int i = oldest - 1; i >= 0; --i)
     {
      ema1[i] = alpha * closes[i] + (1.0 - alpha) * ema1[i + 1];
      ema2[i] = alpha * ema1[i] + (1.0 - alpha) * ema2[i + 1];
      ema3[i] = alpha * ema2[i] + (1.0 - alpha) * ema3[i + 1];
     }

   double trix[];
   ArrayResize(trix, copied - 1);
   ArraySetAsSeries(trix, true);
   for(int shift = 0; shift < copied - 1; ++shift)
     {
      if(MathAbs(ema3[shift + 1]) <= DBL_EPSILON)
         trix[shift] = 0.0;
      else
         trix[shift] = 100.0 * (ema3[shift] - ema3[shift + 1]) / MathAbs(ema3[shift + 1]);
     }

   g_trix_current = trix[1];
   g_trix_previous = trix[2];
   g_trix_roll_max = trix[1];
   g_trix_roll_min = trix[1];
   for(int shift = 2; shift <= strategy_trix_extreme_lookback; ++shift)
     {
      if(trix[shift] > g_trix_roll_max)
         g_trix_roll_max = trix[shift];
      if(trix[shift] < g_trix_roll_min)
         g_trix_roll_min = trix[shift];
     }

   g_slope_abs = MathAbs(g_trix_current - g_trix_previous);
   double slopes[];
   ArrayResize(slopes, strategy_slope_median_lookback);
   for(int i = 0; i < strategy_slope_median_lookback; ++i)
      slopes[i] = MathAbs(trix[i + 1] - trix[i + 2]);
   g_slope_median = MedianValue(slopes, strategy_slope_median_lookback);

   g_wpr_current = QM_WPR(_Symbol, PERIOD_CURRENT, strategy_wpr_period, 1);
   g_ema_current = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_period, 1, PRICE_CLOSE);
   g_close_current = closes[1];
   g_signal_cache_ready = (g_wpr_current != 0.0 && g_ema_current > 0.0 && g_close_current > 0.0);
   return g_signal_cache_ready;
  }

int SymbolSlotForCurrentSymbol()
  {
   if(_Symbol == "EURUSD.DWX")
      return 0;
   if(_Symbol == "GBPJPY.DWX")
      return 1;
   if(_Symbol == "CHFJPY.DWX")
      return 2;
   return qm_magic_slot_offset;
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points <= 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return true;

   if(ask > bid)
     {
      const double spread_points = (ask - bid) / point;
      if(spread_points > (double)strategy_max_spread_points)
         return true;
     }
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = SymbolSlotForCurrentSymbol();
   req.expiration_seconds = 0;

   if(!RefreshSignalCache())
      return false;

   ENUM_POSITION_TYPE ptype;
   if(SelectOurPosition(ptype))
      return false;

   if(g_slope_abs <= g_slope_median)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double eps = 1.0e-10;
   if(g_trix_current > 0.0 &&
      g_trix_previous < 0.0 &&
      g_trix_current >= g_trix_roll_max - eps &&
      g_wpr_current >= -50.0 &&
      g_wpr_current <= -20.0)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, ask, strategy_atr_period, strategy_atr_sl_mult);
      req.tp = 0.0;
      req.reason = "TRIX_ZERO_BREAK_MAX_WPR_NEUTRAL_LONG";
      return (req.sl > 0.0);
     }

   if(g_trix_previous > 0.0 &&
      g_trix_current < 0.0 &&
      g_trix_current <= g_trix_roll_min + eps &&
      g_wpr_current >= -80.0 &&
      g_wpr_current <= -50.0)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, bid, strategy_atr_period, strategy_atr_sl_mult);
      req.tp = 0.0;
      req.reason = "TRIX_ZERO_BREAK_MIN_WPR_NEUTRAL_SHORT";
      return (req.sl > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   if(!SelectOurPosition(ptype))
      return false;

   if(!g_signal_cache_ready && !RefreshSignalCache())
      return false;

   if(ptype == POSITION_TYPE_BUY)
     {
      if(g_trix_current < 0.0 && g_trix_previous > 0.0)
         return true;
      if(g_wpr_current < -80.0)
         return true;
      if(g_close_current < g_ema_current)
         return true;
     }
   else if(ptype == POSITION_TYPE_SELL)
     {
      if(g_trix_current > 0.0 && g_trix_previous < 0.0)
         return true;
      if(g_wpr_current > -20.0)
         return true;
      if(g_close_current > g_ema_current)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9294_mql5-trix-wpr-break\"}");
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

