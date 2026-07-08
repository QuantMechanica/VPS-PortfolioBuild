#property strict
#property version   "5.0"
#property description "QM5_9980 Bandy double-top formalised D1 MR"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9980;
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
input int    strategy_pivot_lookback_bars = 3;
input int    strategy_scan_bars           = 60;
input int    strategy_min_sep_bars        = 10;
input int    strategy_max_sep_bars        = 50;
input double strategy_tolerance_pct       = 0.02;
input double strategy_min_depth_pct       = 0.03;
input int    strategy_regime_sma_period   = 200;
input int    strategy_atr_period          = 14;
input double strategy_stop_buffer_atr     = 0.50;
input double strategy_stop_cap_atr        = 3.50;
input int    strategy_max_hold_bars       = 20;
input int    strategy_max_spread_points   = 0;

bool Strategy_SymbolAllowed(const string sym)
  {
   return (sym == "SP500.DWX" ||
           sym == "NDX.DWX" ||
           sym == "WS30.DWX" ||
           sym == "EURUSD.DWX" ||
           sym == "GBPUSD.DWX" ||
           sym == "USDJPY.DWX" ||
           sym == "XAUUSD.DWX");
  }

bool Strategy_ParamsValid()
  {
   return (strategy_pivot_lookback_bars >= 1 &&
           strategy_scan_bars >= strategy_pivot_lookback_bars * 2 + 20 &&
           strategy_min_sep_bars >= 1 &&
           strategy_max_sep_bars >= strategy_min_sep_bars &&
           strategy_tolerance_pct > 0.0 &&
           strategy_min_depth_pct > 0.0 &&
           strategy_regime_sma_period >= 20 &&
           strategy_atr_period >= 1 &&
           strategy_stop_buffer_atr > 0.0 &&
           strategy_stop_cap_atr > 0.0 &&
           strategy_max_hold_bars >= 1);
  }

// Return TRUE to block trading this tick.
bool Strategy_NoTradeFilter()
  {
   if(!Strategy_ParamsValid())
      return true;
   if(_Period != PERIOD_D1)
      return true;
   if(!Strategy_SymbolAllowed(_Symbol))
      return true;

   if(strategy_max_spread_points <= 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return true;

   if(ask > bid && ((ask - bid) / point) > strategy_max_spread_points)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   static datetime last_fired_p2_time = 0;

   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double sma200 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                strategy_regime_sma_period, 1, PRICE_CLOSE);
   if(sma200 <= 0.0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int need_bars = strategy_scan_bars + strategy_pivot_lookback_bars + 5;
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, need_bars, rates); // perf-allowed: bespoke double-top pivot scan, bounded and called only behind the framework new-bar gate.
   if(copied < strategy_scan_bars + strategy_pivot_lookback_bars)
      return false;

   const double last_close = rates[0].close;
   if(last_close <= 0.0 || last_close >= sma200)
      return false;

   int p2_index = -1;
   int p1_index = -1;
   double p2_high = 0.0;
   double p1_high = 0.0;
   datetime p2_time = 0;

   const int last_candidate = MathMin(strategy_scan_bars - 1,
                                      copied - strategy_pivot_lookback_bars - 1);
   for(int i = strategy_pivot_lookback_bars; i <= last_candidate; ++i)
     {
      const double h = rates[i].high;
      if(h <= 0.0)
         continue;

      bool is_pivot = true;
      for(int j = 1; j <= strategy_pivot_lookback_bars && is_pivot; ++j)
        {
         if(h <= rates[i - j].high || h <= rates[i + j].high)
            is_pivot = false;
        }
      if(!is_pivot)
         continue;

      if(p2_index < 0)
        {
         p2_index = i;
         p2_high = h;
         p2_time = rates[i].time;
        }
      else
        {
         p1_index = i;
         p1_high = h;
         break;
        }
     }

   if(p1_index < 0 || p2_index < 0)
      return false;
   if(p2_time == last_fired_p2_time)
      return false;

   const int separation = p1_index - p2_index;
   if(separation < strategy_min_sep_bars || separation > strategy_max_sep_bars)
      return false;

   if(MathAbs(p2_high - p1_high) / p1_high > strategy_tolerance_pct)
      return false;

   double neckline_low = rates[p2_index + 1].low;
   for(int i = p2_index + 1; i <= p1_index - 1; ++i)
     {
      if(rates[i].low < neckline_low)
         neckline_low = rates[i].low;
     }
   const double pattern_high = MathMax(p1_high, p2_high);
   const double pattern_height = pattern_high - neckline_low;
   if(pattern_high <= 0.0 || neckline_low <= 0.0 || pattern_height <= 0.0)
      return false;
   if(pattern_height / pattern_high < strategy_min_depth_pct)
      return false;
   if(last_close >= neckline_low)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period,
                             strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || point <= 0.0 || bid <= 0.0)
      return false;

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = 8;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double min_stop_distance = MathMax((double)stops_level * point, point);

   double sl_raw = pattern_high + strategy_stop_buffer_atr * atr;
   const double sl_cap = bid + strategy_stop_cap_atr * atr;
   if(sl_raw > sl_cap)
      sl_raw = sl_cap;
   if(sl_raw - bid < min_stop_distance)
      sl_raw = bid + min_stop_distance + point;

   double tp_raw = bid - pattern_height;
   if(bid - tp_raw < min_stop_distance)
      tp_raw = bid - min_stop_distance - point;
   if(tp_raw <= 0.0)
      return false;

   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = NormalizeDouble(sl_raw, digits);
   req.tp = NormalizeDouble(tp_raw, digits);
   req.reason = "bandy_double_top_neckline_break";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   last_fired_p2_time = p2_time;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(period_seconds <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && TimeCurrent() - opened >= strategy_max_hold_bars * period_seconds)
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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
