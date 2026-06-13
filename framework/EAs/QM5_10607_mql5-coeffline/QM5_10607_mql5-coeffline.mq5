#property strict
#property version   "5.0"
#property description "QM5_10607 MQL5 CoeffofLine True histogram zero-cross"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 10607;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_smma_period         = 5;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 2.5;
input int    strategy_max_hold_bars       = 16;
input bool   strategy_use_ema_filter      = false;
input int    strategy_ema_period          = 200;

string Strategy_BaseSymbol()
  {
   string base = _Symbol;
   const int dot = StringFind(base, ".");
   if(dot > 0)
      base = StringSubstr(base, 0, dot);
   return base;
  }

bool Strategy_InvertedCoeffSymbol()
  {
   const string base = Strategy_BaseSymbol();
   return (base == "EURUSD" || base == "GBPUSD" || base == "USDCAD" ||
           base == "USDCHF" || base == "EURGBP" || base == "EURCHF" ||
           base == "AUDUSD" || base == "GBPCHF");
  }

double Strategy_CoeffOfLineValue(const int shift)
  {
   const int n = strategy_smma_period;
   if(n < 2 || shift < 1)
      return 0.0;

   double ty = 0.0;
   double zy = 0.0;
   double ti = 0.0;
   double zi = 0.0;
   double sum_sq = 0.0;
   double sum_n = 0.0;

   for(int cnt = n; cnt >= 1; --cnt)
     {
      const int series_shift = shift + cnt - 1;
      const double high = iHigh(_Symbol, _Period, series_shift); // perf-allowed: bounded CoeffofLine_true formula on closed-bar entry hook.
      const double low = iLow(_Symbol, _Period, series_shift);   // perf-allowed: bounded CoeffofLine_true formula on closed-bar entry hook.
      if(high <= 0.0 || low <= 0.0)
         return 0.0;

      const double median = (high + low) * 0.5;
      const int count = n + 1 - cnt;
      const double smma = QM_SMMA(_Symbol, (ENUM_TIMEFRAMES)_Period, n, series_shift + 3, PRICE_MEDIAN);
      if(smma <= 0.0)
         return 0.0;

      ty += median;
      zy += median * count;
      ti += smma;
      zi += smma * count;
      sum_sq += cnt * cnt;
      sum_n += cnt;
     }

   if(sum_n <= 0.0)
      return 0.0;

   const double ay = (ty + (sum_sq - 2.0 * zy) * n / sum_n) / sum_n;
   const double ai = (ti + (sum_sq - 2.0 * zi) * n / sum_n) / sum_n;
   if(ay <= 0.0 || ai <= 0.0)
      return 0.0;

   const double scale = Strategy_InvertedCoeffSymbol() ? -1000.0 : 1000.0;
   return scale * MathLog(ay / ai);
  }

int Strategy_CoeffCrossSignal()
  {
   const double current = Strategy_CoeffOfLineValue(1);
   const double previous = Strategy_CoeffOfLineValue(2);
   if(previous < 0.0 && current > 0.0)
      return 1;
   if(previous > 0.0 && current < 0.0)
      return -1;
   return 0;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

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

   if(Strategy_HasOpenPosition())
      return false;

   const int signal = Strategy_CoeffCrossSignal();
   if(signal == 0)
      return false;

   if(strategy_use_ema_filter)
     {
      const int bias = QM_Sig_Price_Above_MA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 0.0, 1);
      if(signal > 0 && bias <= 0)
         return false;
      if(signal < 0 && bias >= 0)
         return false;
     }

   req.type = (signal > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   const double entry = (signal > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                     : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.tp = 0.0;
   req.reason = (signal > 0) ? "coeffofline_zero_cross_long" : "coeffofline_zero_cross_short";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int signal = Strategy_CoeffCrossSignal();
   const int hold_seconds = strategy_max_hold_bars * PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   const datetime now = TimeCurrent();

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && signal < 0)
         return true;
      if(pos_type == POSITION_TYPE_SELL && signal > 0)
         return true;

      if(hold_seconds > 0)
        {
         const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
         if(open_time > 0 && now - open_time >= hold_seconds)
            return true;
        }
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10607_mql5_coeffline\"}");
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
         if(ticket == 0)
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
