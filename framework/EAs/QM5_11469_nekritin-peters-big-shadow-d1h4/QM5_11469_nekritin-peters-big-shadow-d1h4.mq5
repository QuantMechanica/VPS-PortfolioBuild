#property strict
#property version   "5.0"
#property description "QM5_11469 Nekritin/Peters Big Shadow D1"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11469;
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
input int    strategy_room_bars           = 7;
input double strategy_close_near_pct      = 0.25;
input double strategy_atr_multiplier      = 0.0;
input int    strategy_entry_offset_pips   = 1;
input int    strategy_stop_offset_pips    = 1;
input int    strategy_max_stop_pips       = 100;
input int    strategy_spread_cap_pips     = 25;
input int    strategy_sr_lookback_bars    = 50;
input int    strategy_fractal_wing        = 2;
input int    strategy_min_tp_pips         = 1;

// -----------------------------------------------------------------------------
// Strategy hooks - implement these against the card mechanically.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news): skip Friday entries and wide spreads.
bool Strategy_NoTradeFilter()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 5)
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pip = ((digits == 3 || digits == 5) ? 10.0 : 1.0) * point;
   if(pip <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return true;

   return ((ask - bid) / pip > (double)strategy_spread_cap_pips);
  }

// Trade Entry: D1 Big Shadow stop entry on the bar after the engulfing candle.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = PeriodSeconds(PERIOD_D1);

   if(strategy_room_bars < 1 || strategy_close_near_pct <= 0.0 ||
      strategy_close_near_pct >= 1.0 || strategy_entry_offset_pips < 0 ||
      strategy_stop_offset_pips < 0 || strategy_max_stop_pips <= 0 ||
      strategy_sr_lookback_bars < 5 || strategy_fractal_wing < 1 ||
      strategy_min_tp_pips < 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 5)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pip = ((digits == 3 || digits == 5) ? 10.0 : 1.0) * point;
   if(point <= 0.0 || pip <= 0.0)
      return false;

   const double open1 = iOpen(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 Big Shadow OHLC, called only after QM_IsNewBar gate.
   const double high1 = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 Big Shadow OHLC, called only after QM_IsNewBar gate.
   const double low1 = iLow(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 Big Shadow OHLC, called only after QM_IsNewBar gate.
   const double close1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 Big Shadow OHLC, called only after QM_IsNewBar gate.
   const double high2 = iHigh(_Symbol, PERIOD_D1, 2); // perf-allowed: D1 Big Shadow engulfing comparison.
   const double low2 = iLow(_Symbol, PERIOD_D1, 2); // perf-allowed: D1 Big Shadow engulfing comparison.
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 ||
      high2 <= 0.0 || low2 <= 0.0 || high1 <= low1)
      return false;

   const double range = high1 - low1;
   if(high1 <= high2 || low1 >= low2)
      return false;

   const double range_pips = range / pip;
   if(range_pips > (double)strategy_max_stop_pips)
      return false;

   if(strategy_atr_multiplier > 0.0)
     {
      const double atr = QM_ATR(_Symbol, PERIOD_D1, 14, 2);
      if(atr <= 0.0 || range <= atr * strategy_atr_multiplier)
         return false;
     }

   double prior_high = -DBL_MAX;
   double prior_low = DBL_MAX;
   for(int shift = 2; shift < 2 + strategy_room_bars; ++shift)
     {
      const double high = iHigh(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded room-to-left D1 scan.
      const double low = iLow(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded room-to-left D1 scan.
      if(high <= 0.0 || low <= 0.0)
         return false;
      prior_high = MathMax(prior_high, high);
      prior_low = MathMin(prior_low, low);
     }

   const bool bullish = (close1 > open1 &&
                         (high1 - close1) < strategy_close_near_pct * range &&
                         high1 > prior_high);
   const bool bearish = (close1 < open1 &&
                         (close1 - low1) < strategy_close_near_pct * range &&
                         low1 < prior_low);
   if(!bullish && !bearish)
      return false;

   const double offset_entry = strategy_entry_offset_pips * pip;
   const double offset_stop = strategy_stop_offset_pips * pip;
   const double min_tp_distance = strategy_min_tp_pips * pip;
   const int wing = MathMax(1, strategy_fractal_wing);
   const int lookback = MathMax(wing * 2 + 3, strategy_sr_lookback_bars);

   if(bullish)
     {
      const double entry = high1 + offset_entry;
      const double sl = low1 - offset_stop;
      const double sl_pips = MathAbs(entry - sl) / pip;
      if(sl <= 0.0 || sl_pips > (double)strategy_max_stop_pips)
         return false;

      double tp = 0.0;
      for(int shift = 2 + wing; shift <= lookback; ++shift)
        {
         const double candidate = iHigh(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded S/R fractal scan for TP.
         if(candidate <= entry + min_tp_distance)
            continue;
         bool is_fractal = true;
         for(int j = 1; j <= wing; ++j)
           {
            if(iHigh(_Symbol, PERIOD_D1, shift - j) >= candidate || // perf-allowed: bounded S/R fractal scan for TP.
               iHigh(_Symbol, PERIOD_D1, shift + j) > candidate) // perf-allowed: bounded S/R fractal scan for TP.
              {
               is_fractal = false;
               break;
              }
           }
         if(is_fractal && (tp <= 0.0 || candidate < tp))
            tp = candidate;
        }
      if(tp <= entry)
         return false;

      req.type = QM_BUY_STOP;
      req.price = entry;
      req.sl = sl;
      req.tp = tp;
      req.reason = "big_shadow_bullish_d1";
      return true;
     }

   const double entry = low1 - offset_entry;
   const double sl = high1 + offset_stop;
   const double sl_pips = MathAbs(sl - entry) / pip;
   if(entry <= 0.0 || sl_pips > (double)strategy_max_stop_pips)
      return false;

   double tp = 0.0;
   for(int shift = 2 + wing; shift <= lookback; ++shift)
     {
      const double candidate = iLow(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded S/R fractal scan for TP.
      if(candidate <= 0.0 || candidate >= entry - min_tp_distance)
         continue;
      bool is_fractal = true;
      for(int j = 1; j <= wing; ++j)
        {
         if(iLow(_Symbol, PERIOD_D1, shift - j) <= candidate || // perf-allowed: bounded S/R fractal scan for TP.
            iLow(_Symbol, PERIOD_D1, shift + j) < candidate) // perf-allowed: bounded S/R fractal scan for TP.
           {
            is_fractal = false;
            break;
           }
        }
      if(is_fractal && (tp <= 0.0 || candidate > tp))
         tp = candidate;
     }
   if(tp <= 0.0 || tp >= entry)
      return false;

   req.type = QM_SELL_STOP;
   req.price = entry;
   req.sl = sl;
   req.tp = tp;
   req.reason = "big_shadow_bearish_d1";
   return true;
  }

// Trade Management: no trailing, BE, partial, or pyramiding in the card.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: exits are SL/TP, pending-order expiration, and framework Friday close.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook: no strategy-specific override; framework axes handle news.
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
