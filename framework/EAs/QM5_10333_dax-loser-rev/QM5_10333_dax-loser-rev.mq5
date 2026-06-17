#property strict
#property version   "5.0"
#property description "QM5_10333 DAX Intraday Loser Reversal"

#include <QM/QM_Common.mqh>

#define STRATEGY_BASKET_SIZE 4

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10333;
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
input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_M5;
// Session HHMM in BROKER time (inv #5/#13). DXZ broker = NY-Close GMT+2/+3,
// Frankfurt cash 09:00-17:30 CET/CEST ~ broker 10:00-18:30 year-round
// (broker = Frankfurt local + 1h in both DST regimes). Override per symbol in
// the setfile if a different cash session is desired.
input int    strategy_session_start_hhmm          = 1000;
input int    strategy_session_end_hhmm            = 1830;
input int    strategy_session_skip_minutes        = 15;
input int    strategy_ranking_minutes             = 60;
input int    strategy_holding_minutes             = 60;
input int    strategy_atr_period                  = 14;
input double strategy_entry_atr_fraction          = 0.50;
input double strategy_stop_atr_mult               = 0.75;
input int    strategy_min_valid_symbols           = 3;
input int    strategy_spread_lookback_bars        = 240;
input double strategy_spread_percentile           = 80.0;
input double strategy_min_stop_spread_mult        = 4.0;
input int    strategy_basket_warmup_bars          = 1200;

string g_strategy_basket[STRATEGY_BASKET_SIZE];

void Strategy_InitBasket()
  {
   g_strategy_basket[0] = "GDAXI.DWX";
   g_strategy_basket[1] = "SP500.DWX";
   g_strategy_basket[2] = "NDX.DWX";
   g_strategy_basket[3] = "WS30.DWX";
  }

bool Strategy_IsBasketSymbol(const string symbol)
  {
   for(int i = 0; i < STRATEGY_BASKET_SIZE; ++i)
      if(g_strategy_basket[i] == symbol)
         return true;
   return false;
  }

int Strategy_HhmmToMinutes(const int hhmm)
  {
   const int hour = hhmm / 100;
   const int minute = hhmm % 100;
   if(hour < 0 || hour > 23 || minute < 0 || minute > 59)
      return -1;
   return hour * 60 + minute;
  }

int Strategy_MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

bool Strategy_InEntrySession(const datetime broker_time)
  {
   const int start = Strategy_HhmmToMinutes(strategy_session_start_hhmm);
   const int end = Strategy_HhmmToMinutes(strategy_session_end_hhmm);
   if(start < 0 || end < 0 || end <= start || strategy_session_skip_minutes < 0)
      return false;

   const int minute = Strategy_MinutesOfDay(broker_time);
   return (minute >= start + strategy_session_skip_minutes &&
           minute < end - strategy_session_skip_minutes);
  }

bool Strategy_AfterSessionEnd(const datetime broker_time)
  {
   const int end = Strategy_HhmmToMinutes(strategy_session_end_hhmm);
   if(end < 0)
      return false;
   return (Strategy_MinutesOfDay(broker_time) >= end);
  }

bool Strategy_EvaluationCadenceAllows()
  {
   const int start = Strategy_HhmmToMinutes(strategy_session_start_hhmm);
   if(start < 0 || strategy_ranking_minutes <= 0)
      return false;

   // Key off the M5 bar-OPEN minute, not the live tick minute (inv #12). The
   // whole boundary bar (e.g. the 10:00 M5 bar) then qualifies, so the new-bar
   // entry pass at the start of the bucket always sees an open cadence.
   const int offset = Strategy_MinutesOfDay(iTime(_Symbol, strategy_signal_tf, 0)) - start;
   if(offset < 0)
      return false;
   return ((offset % strategy_ranking_minutes) == 0);
  }

int Strategy_RankingBars()
  {
   const int seconds = PeriodSeconds(strategy_signal_tf);
   if(seconds <= 0 || strategy_ranking_minutes <= 0)
      return 0;
   return (strategy_ranking_minutes * 60) / seconds;
  }

bool Strategy_HasOpenPosition()
  {
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
      return true;
     }
   return false;
  }

bool Strategy_ReadRankingReturn(const string symbol, double &ret, double &close_price)
  {
   ret = 0.0;
   close_price = 0.0;
   if(!QM_SymbolAssertOrLog(symbol))
      return false;

   const int bars = Strategy_RankingBars();
   if(bars < 1)
      return false;

   const double close_now = iClose(symbol, strategy_signal_tf, 1);              // perf-allowed: fixed two-close ranking read, called only from the framework QM_IsNewBar-gated entry path.
   const double close_then = iClose(symbol, strategy_signal_tf, bars + 1);      // perf-allowed: fixed two-close ranking read, called only from the framework QM_IsNewBar-gated entry path.
   if(close_now <= 0.0 || close_then <= 0.0)
      return false;

   ret = (close_now - close_then) / close_then;
   close_price = close_now;
   return true;
  }

bool Strategy_RankingMidpoint(const string symbol, double &midpoint)
  {
   midpoint = 0.0;
   if(!QM_SymbolAssertOrLog(symbol))
      return false;

   const int bars = Strategy_RankingBars();
   if(bars < 1)
      return false;

   double highest = -DBL_MAX;
   double lowest = DBL_MAX;
   for(int shift = 1; shift <= bars; ++shift)
     {
      const double h = iHigh(symbol, strategy_signal_tf, shift);                // perf-allowed: bounded 60-minute range midpoint, called only from the framework QM_IsNewBar-gated entry path.
      const double l = iLow(symbol, strategy_signal_tf, shift);                 // perf-allowed: bounded 60-minute range midpoint, called only from the framework QM_IsNewBar-gated entry path.
      if(h <= 0.0 || l <= 0.0)
         continue;
      if(h > highest)
         highest = h;
      if(l < lowest)
         lowest = l;
     }

   if(highest <= 0.0 || lowest <= 0.0 || highest <= lowest)
      return false;
   midpoint = (highest + lowest) * 0.5;
   return true;
  }

double Strategy_Percentile(double &values[], const int count, const double percentile)
  {
   if(count <= 0)
      return 0.0;

   ArrayResize(values, count);
   ArraySort(values);

   double p = percentile;
   if(p < 0.0)
      p = 0.0;
   if(p > 100.0)
      p = 100.0;

   int idx = (int)MathCeil((p / 100.0) * (double)count) - 1;
   if(idx < 0)
      idx = 0;
   if(idx >= count)
      idx = count - 1;
   return values[idx];
  }

bool Strategy_CurrentSpreadAllows()
  {
   // DWX tester invariant #1: .DWX symbols quote ask==bid, so SYMBOL_SPREAD and
   // iSpread() both read 0 here. The rolling-80th-percentile spread filter is a
   // LIVE-only refinement; it must never fail-closed on zero spread or it blocks
   // every backtest trade. With no genuine spread data, ALLOW the trade.
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true; // zero modeled spread (tester) -> do not block
   if(strategy_spread_lookback_bars <= 0)
      return true;

   double samples[];
   ArrayResize(samples, strategy_spread_lookback_bars);
   int count = 0;
   for(int shift = 1; shift <= strategy_spread_lookback_bars; ++shift)
     {
      const long historical_spread = iSpread(_Symbol, strategy_signal_tf, shift); // perf-allowed: bounded spread percentile sample, called only from framework QM_IsNewBar-gated EntrySignal.
      if(historical_spread <= 0)
         continue;
      samples[count] = (double)historical_spread;
      count++;
     }

   // Insufficient genuine-spread history (e.g. tester) -> allow.
   if(count < 20)
      return true;

   const double threshold = Strategy_Percentile(samples, count, strategy_spread_percentile);
   if(threshold <= 0.0)
      return true;
   return ((double)current_spread <= threshold);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != strategy_signal_tf)
      return true;
   if(!Strategy_IsBasketSymbol(_Symbol))
      return true;
   if(Strategy_HasOpenPosition())
      return false;

   const datetime broker_now = TimeCurrent();
   if(!Strategy_InEntrySession(broker_now))
      return true;
   if(!Strategy_EvaluationCadenceAllows())
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

   const datetime broker_now = TimeCurrent();
   if(!Strategy_InEntrySession(broker_now) || !Strategy_EvaluationCadenceAllows())
      return false;

   string worst_symbol = "";
   double worst_return = DBL_MAX;
   double worst_close = 0.0;
   int valid_count = 0;

   for(int i = 0; i < STRATEGY_BASKET_SIZE; ++i)
     {
      double r = 0.0;
      double close_price = 0.0;
      if(!Strategy_ReadRankingReturn(g_strategy_basket[i], r, close_price))
         continue;

      valid_count++;
      if(r < worst_return)
        {
         worst_return = r;
         worst_symbol = g_strategy_basket[i];
         worst_close = close_price;
        }
     }

   if(valid_count < strategy_min_valid_symbols)
      return false;
   if(worst_symbol != _Symbol)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(atr <= 0.0 || worst_close <= 0.0)
      return false;

   const double threshold = -strategy_entry_atr_fraction * (atr / worst_close);
   if(worst_return >= threshold)
      return false;
   if(!Strategy_CurrentSpreadAllows())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || point <= 0.0)
      return false;

   const double stop_distance = atr * strategy_stop_atr_mult;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_points > 0 && stop_distance < strategy_min_stop_spread_mult * (double)spread_points * point)
      return false;

   double midpoint = 0.0;
   if(!Strategy_RankingMidpoint(_Symbol, midpoint))
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr, strategy_stop_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = NormalizeDouble(ask, _Digits);
   req.sl = sl;
   req.tp = (midpoint > ask + point) ? NormalizeDouble(midpoint, _Digits) : 0.0;
   req.reason = "DAX_LOSER_REV_LONG";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies single-leg only: no trailing, break-even, partial close, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_holding_minutes <= 0)
      return false;

   const datetime broker_now = TimeCurrent();
   if(Strategy_AfterSessionEnd(broker_now))
      return true;

   const int hold_seconds = strategy_holding_minutes * 60;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time > 0 && broker_now >= open_time + hold_seconds)
         return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
  }

int OnInit()
  {
   Strategy_InitBasket();
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

   QM_SymbolGuardInit(g_strategy_basket);
   QM_BasketWarmupHistory(g_strategy_basket, strategy_signal_tf, strategy_basket_warmup_bars);
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10333\",\"strategy\":\"dax-loser-rev\"}");
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
