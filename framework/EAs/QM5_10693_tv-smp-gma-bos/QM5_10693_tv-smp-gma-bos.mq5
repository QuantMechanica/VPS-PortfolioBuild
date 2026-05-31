#property strict
#property version   "5.0"
#property description "QM5_10693 TV SMPivot Gaussian BOS"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 10693;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal       = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance     = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_gma_length          = 30;
input int    strategy_pivot_length        = 20;
input int    strategy_pivot_scan_bars     = 240;
input double strategy_stop_percent        = 1.0;
input double strategy_take_percent        = 3.0;
input int    strategy_atr_period          = 14;
input double strategy_atr_stop_cap_mult   = 2.5;
input bool   strategy_gma_slope_filter    = true;

double GaussianDoubleSmoothedClose(const int shift, const int length)
  {
   if(shift < 1 || length < 2)
      return 0.0;

   const int samples = (2 * length) - 1;
   const double sigma = MathMax(1.0, ((double)length / 3.0) * MathSqrt(2.0));
   double weighted_sum = 0.0;
   double weight_sum = 0.0;

   for(int i = 0; i < samples; ++i)
     {
      const double close_i = iClose(_Symbol, _Period, shift + i);
      if(close_i <= 0.0)
         return 0.0;

      const double x = (double)i / sigma;
      const double weight = MathExp(-0.5 * x * x);
      weighted_sum += close_i * weight;
      weight_sum += weight;
     }

   if(weight_sum <= 0.0)
      return 0.0;
   return weighted_sum / weight_sum;
  }

bool FindLatestConfirmedPivot(const bool want_high, const int pivot_len, const int scan_bars, double &pivot_price)
  {
   pivot_price = 0.0;
   if(pivot_len < 1)
      return false;

   const int first_shift = pivot_len + 1;
   const int last_shift = MathMax(first_shift, scan_bars);
   const int window = (2 * pivot_len) + 1;

   for(int shift = first_shift; shift <= last_shift; ++shift)
     {
      const int start = shift - pivot_len;
      const int pivot_index = want_high
                              ? iHighest(_Symbol, _Period, MODE_HIGH, window, start)
                              : iLowest(_Symbol, _Period, MODE_LOW, window, start);
      if(pivot_index != shift)
         continue;

      pivot_price = want_high ? iHigh(_Symbol, _Period, shift)
                              : iLow(_Symbol, _Period, shift);
      return (pivot_price > 0.0);
     }

   return false;
  }

bool BuildMarketRequest(const QM_OrderType side, const string reason, QM_EntryRequest &req)
  {
   const double entry = QM_OrderTypeIsBuy(side)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double pct_stop_dist = entry * (strategy_stop_percent / 100.0);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   double stop_dist = pct_stop_dist;
   if(atr > 0.0 && strategy_atr_stop_cap_mult > 0.0)
      stop_dist = MathMin(pct_stop_dist, atr * strategy_atr_stop_cap_mult);

   const double take_dist = entry * (strategy_take_percent / 100.0);
   if(stop_dist <= 0.0 || take_dist <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = NormalizeDouble(QM_OrderTypeIsBuy(side) ? entry - stop_dist : entry + stop_dist, _Digits);
   req.tp = NormalizeDouble(QM_OrderTypeIsBuy(side) ? entry + take_dist : entry - take_dist, _Digits);
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   return (req.sl > 0.0 && req.tp > 0.0);
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

   if(strategy_gma_length < 2 || strategy_pivot_length < 1 ||
      strategy_stop_percent <= 0.0 || strategy_take_percent <= 0.0)
      return false;

   double updated_high = 0.0;
   double updated_low = 0.0;
   if(!FindLatestConfirmedPivot(true, strategy_pivot_length, strategy_pivot_scan_bars, updated_high))
      return false;
   if(!FindLatestConfirmedPivot(false, strategy_pivot_length, strategy_pivot_scan_bars, updated_low))
      return false;

   const double close_1 = iClose(_Symbol, _Period, 1);
   const double close_2 = iClose(_Symbol, _Period, 2);
   if(close_1 <= 0.0 || close_2 <= 0.0)
      return false;

   const double gma_1 = GaussianDoubleSmoothedClose(1, strategy_gma_length);
   const double gma_2 = GaussianDoubleSmoothedClose(2, strategy_gma_length);
   if(gma_1 <= 0.0 || gma_2 <= 0.0)
      return false;

   const bool gma_up = (!strategy_gma_slope_filter || gma_1 > gma_2);
   const bool gma_down = (!strategy_gma_slope_filter || gma_1 < gma_2);

   if(close_1 > updated_high && close_2 <= updated_high && close_1 > gma_1 && gma_up)
      return BuildMarketRequest(QM_BUY, "BOS_LONG_GMA_UP", req);

   if(close_1 < updated_low && close_2 >= updated_low && close_1 < gma_1 && gma_down)
      return BuildMarketRequest(QM_SELL, "BOS_SHORT_GMA_DOWN", req);

   return false;
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
   if(broker_time <= 0)
      return false;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10693\",\"ea\":\"QM5_10693_tv-smp-gma-bos\"}");
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
