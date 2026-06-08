#property strict
#property version   "5.0"
#property description "QM5_11355 RoboForex PSAR CCI M5 Scalp"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11355;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_fast_period     = 21;
input int    strategy_ema_slow_period     = 50;
input int    strategy_cci_period          = 45;
input double strategy_cci_threshold       = 100.0;
input double strategy_psar_step           = 0.02;
input double strategy_psar_maximum        = 0.20;
input int    strategy_psar_warmup_bars    = 120;
input double strategy_tp_pips             = 10.0;
input double strategy_max_stop_pips       = 15.0;
input double strategy_spread_cap_pips     = 3.0;
input int    strategy_session_start_gmt   = 13;
input int    strategy_session_end_gmt     = 22;

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_M5)
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pip = ((digits == 3 || digits == 5) ? 10.0 : 1.0) * point;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || pip <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return true;

   const double spread_pips = (ask - bid) / pip;
   if(spread_pips > strategy_spread_cap_pips)
      return true;

   MqlDateTime gmt;
   TimeToStruct(TimeGMT(), gmt);
   if(strategy_session_start_gmt != strategy_session_end_gmt)
     {
      bool in_session = false;
      if(strategy_session_start_gmt < strategy_session_end_gmt)
         in_session = (gmt.hour >= strategy_session_start_gmt && gmt.hour < strategy_session_end_gmt);
      else
         in_session = (gmt.hour >= strategy_session_start_gmt || gmt.hour < strategy_session_end_gmt);
      if(!in_session)
         return true;
     }

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

   if(strategy_ema_fast_period < 1 ||
      strategy_ema_slow_period < 1 ||
      strategy_cci_period < 2 ||
      strategy_cci_threshold <= 0.0 ||
      strategy_psar_step <= 0.0 ||
      strategy_psar_maximum <= 0.0 ||
      strategy_psar_warmup_bars < 20 ||
      strategy_tp_pips <= 0.0 ||
      strategy_max_stop_pips <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int bars_needed = strategy_psar_warmup_bars;
   const int copied = CopyRates(_Symbol, PERIOD_M5, 1, bars_needed, rates); // perf-allowed: PSAR has no framework reader; bounded closed-bar reconstruction inside framework QM_IsNewBar entry hook.
   if(copied < 20)
      return false;

   const int oldest = copied - 1;
   const int next_oldest = copied - 2;
   bool psar_up = (rates[next_oldest].close >= rates[oldest].close);
   double psar = psar_up ? rates[oldest].low : rates[oldest].high;
   double ep = psar_up ? MathMax(rates[oldest].high, rates[next_oldest].high)
                       : MathMin(rates[oldest].low, rates[next_oldest].low);
   double af = strategy_psar_step;
   const double max_af = strategy_psar_maximum;

   for(int idx = copied - 3; idx >= 0; --idx)
     {
      psar = psar + af * (ep - psar);

      if(psar_up)
        {
         psar = MathMin(psar, rates[idx + 1].low);
         psar = MathMin(psar, rates[idx + 2].low);
         if(rates[idx].low < psar)
           {
            psar_up = false;
            psar = ep;
            ep = rates[idx].low;
            af = strategy_psar_step;
           }
         else if(rates[idx].high > ep)
           {
            ep = rates[idx].high;
            af = MathMin(af + strategy_psar_step, max_af);
           }
        }
      else
        {
         psar = MathMax(psar, rates[idx + 1].high);
         psar = MathMax(psar, rates[idx + 2].high);
         if(rates[idx].high > psar)
           {
            psar_up = true;
            psar = ep;
            ep = rates[idx].high;
            af = strategy_psar_step;
           }
         else if(rates[idx].low < ep)
           {
            ep = rates[idx].low;
            af = MathMin(af + strategy_psar_step, max_af);
           }
        }
     }

   const ENUM_TIMEFRAMES tf = PERIOD_M5;
   const double close_1 = rates[0].close;
   const double ema_fast = QM_EMA(_Symbol, tf, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, tf, strategy_ema_slow_period, 1);
   const double cci = QM_CCI(_Symbol, tf, strategy_cci_period, 1, PRICE_TYPICAL);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pip = ((digits == 3 || digits == 5) ? 10.0 : 1.0) * point;
   if(close_1 <= 0.0 ||
      ema_fast <= 0.0 ||
      ema_slow <= 0.0 ||
      !MathIsValidNumber(cci) ||
      psar <= 0.0 ||
      ask <= 0.0 ||
      bid <= 0.0 ||
      point <= 0.0 ||
      pip <= 0.0)
      return false;

   const double tp_dist = strategy_tp_pips * pip;
   const double max_stop_dist = strategy_max_stop_pips * pip;
   if(tp_dist <= 0.0 || max_stop_dist <= 0.0)
      return false;

   if(psar < close_1 &&
      close_1 > ema_fast &&
      close_1 > ema_slow &&
      cci > strategy_cci_threshold)
     {
      const double entry = ask;
      double sl = ema_fast;
      if(entry - sl > max_stop_dist)
         sl = entry - max_stop_dist;
      if(sl <= 0.0 || sl >= entry)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble(entry + tp_dist, _Digits);
      req.reason = "ROBO_PSAR_CCI_LONG";
      return (req.sl > 0.0 && req.sl < entry && req.tp > entry);
     }

   if(psar > close_1 &&
      close_1 < ema_fast &&
      close_1 < ema_slow &&
      cci < -strategy_cci_threshold)
     {
      const double entry = bid;
      double sl = ema_fast;
      if(sl - entry > max_stop_dist)
         sl = entry + max_stop_dist;
      if(sl <= entry)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble(entry - tp_dist, _Digits);
      req.reason = "ROBO_PSAR_CCI_SHORT";
      return (req.sl > entry && req.tp > 0.0 && req.tp < entry);
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card has no trailing, partial close, or break-even management.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   // Card exits through the initial EMA21 stop, fixed take-profit, and framework exits.
   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0)
      return false;
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
