#property strict
#property version   "5.0"
#property description "QM5_9961 Bandy HMA Supertrend Confluence D1 Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_9961
// Strategy Card: C:/QM/repo/framework/EAs/QM5_9961_bandy-hma-supertrend-confluence-trend/docs/strategy_card.md
// Source: Howard Bandy, Quantitative Technical Analysis 2015 (9ef19e06-5ca6-5b35-aa06-b8187aa0e016)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9961;
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
input int    strategy_hma_fast          = 14;
input int    strategy_hma_slow          = 50;
input int    strategy_supertrend_period = 10;
input double strategy_supertrend_mult   = 3.0;
input int    strategy_regime_sma_period = 200;
input int    strategy_atr_period        = 14;
input double strategy_stop_atr_mult     = 3.0;
input int    strategy_max_hold_bars     = 60;
input int    strategy_warmup_bars       = 250;
input int    strategy_max_spread_points = 0;

// -----------------------------------------------------------------------------
// Strategy calculation helpers
// -----------------------------------------------------------------------------

bool Strategy_SymbolAllowed(const string sym)
{
   return (sym == "SP500.DWX" ||
           sym == "NDX.DWX" ||
           sym == "WS30.DWX" ||
           sym == "GDAXI.DWX" ||
           sym == "UK100.DWX" ||
           sym == "EURUSD.DWX" ||
           sym == "GBPUSD.DWX" ||
           sym == "USDJPY.DWX" ||
           sym == "USDCHF.DWX" ||
           sym == "USDCAD.DWX" ||
           sym == "AUDUSD.DWX" ||
           sym == "NZDUSD.DWX" ||
           sym == "XAUUSD.DWX");
}

bool Strategy_ParamsValid()
{
   return (strategy_hma_fast >= 1 &&
           strategy_hma_slow > strategy_hma_fast &&
           strategy_supertrend_period >= 1 &&
           strategy_supertrend_mult > 0.0 &&
           strategy_regime_sma_period >= 20 &&
           strategy_atr_period >= 1 &&
           strategy_stop_atr_mult > 0.0 &&
           strategy_max_hold_bars >= 1 &&
           strategy_warmup_bars >= strategy_hma_slow + 50);
}

bool Strategy_GetSupertrendStates(int &trend_curr, int &trend_prev, double &close_curr)
{
   trend_curr = 0;
   trend_prev = 0;
   close_curr = 0.0;

   const int period = MathMax(1, strategy_supertrend_period);
   const int warmup = MathMax(strategy_warmup_bars, period + 20);

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, warmup + 2, rates);
   if(copied < period + 5)
      return false;

   close_curr = rates[0].close;

   int trend = 0;
   double final_upper = 0.0;
   double final_lower = 0.0;

   for(int idx = copied - 2; idx >= 0; --idx)
   {
      const int shift = idx + 1;
      const double high = rates[idx].high;
      const double low = rates[idx].low;
      const double close = rates[idx].close;
      const double prev_close = rates[idx + 1].close;
      const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, period, shift);
      if(high <= 0.0 || low <= 0.0 || close <= 0.0 || prev_close <= 0.0 || atr <= 0.0)
         continue;

      const double midpoint = (high + low) * 0.5;
      const double basic_upper = midpoint + strategy_supertrend_mult * atr;
      const double basic_lower = midpoint - strategy_supertrend_mult * atr;

      if(trend == 0)
      {
         final_upper = basic_upper;
         final_lower = basic_lower;
         trend = (close >= midpoint) ? 1 : -1;
         continue;
      }

      final_upper = (basic_upper < final_upper || prev_close > final_upper) ? basic_upper : final_upper;
      final_lower = (basic_lower > final_lower || prev_close < final_lower) ? basic_lower : final_lower;

      if(trend < 0 && close > final_upper)
         trend = 1;
      else if(trend > 0 && close < final_lower)
         trend = -1;

      if(idx == 1)
         trend_prev = trend;
      if(idx == 0)
         trend_curr = trend;
   }

   return (trend_curr != 0 && trend_prev != 0);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(!Strategy_ParamsValid())
      return true;
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;
   if(!Strategy_SymbolAllowed(_Symbol))
      return true;
   if(iBars(_Symbol, PERIOD_D1) < strategy_warmup_bars)
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
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   int st_curr = 0;
   int st_prev = 0;
   double close1 = 0.0;
   if(!Strategy_GetSupertrendStates(st_curr, st_prev, close1))
      return false;

   const double hma_f1 = QM_HMA(_Symbol, PERIOD_D1, strategy_hma_fast, 1, PRICE_CLOSE);
   const double hma_s1 = QM_HMA(_Symbol, PERIOD_D1, strategy_hma_slow, 1, PRICE_CLOSE);
   const double hma_f2 = QM_HMA(_Symbol, PERIOD_D1, strategy_hma_fast, 2, PRICE_CLOSE);
   const double hma_s2 = QM_HMA(_Symbol, PERIOD_D1, strategy_hma_slow, 2, PRICE_CLOSE);
   const double regime = QM_SMA(_Symbol, PERIOD_D1, strategy_regime_sma_period, 1, PRICE_CLOSE);

   if(hma_f1 <= 0.0 || hma_s1 <= 0.0 || hma_f2 <= 0.0 || hma_s2 <= 0.0 || regime <= 0.0 || close1 <= 0.0)
      return false;

   const int hma_curr = (hma_f1 > hma_s1) ? 1 : ((hma_f1 < hma_s1) ? -1 : 0);
   const int hma_prev = (hma_f2 > hma_s2) ? 1 : ((hma_f2 < hma_s2) ? -1 : 0);

   const double atr14 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr14 <= 0.0 || point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = 8;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double min_stop_distance = MathMax((double)stops_level * point, point);

   // Long entry: HMA long AND Supertrend long AND close > regime AND first bar of confluence
   const bool long_confluence_now = (hma_curr == 1 && st_curr == 1 && close1 > regime);
   const bool long_confluence_prev = (hma_prev == 1 && st_prev == 1);
   if(long_confluence_now && !long_confluence_prev)
   {
      double sl_raw = ask - strategy_stop_atr_mult * atr14;
      if(ask - sl_raw < min_stop_distance)
         sl_raw = ask - min_stop_distance - point;
      if(sl_raw <= 0.0)
         return false;

      req.type               = QM_BUY;
      req.price              = 0.0;
      req.sl                 = NormalizeDouble(sl_raw, digits);
      req.tp                 = 0.0;
      req.reason             = "bandy_hma_supertrend_bullish_confluence";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   // Short entry: HMA short AND Supertrend short AND close < regime AND first bar of confluence
   const bool short_confluence_now = (hma_curr == -1 && st_curr == -1 && close1 < regime);
   const bool short_confluence_prev = (hma_prev == -1 && st_prev == -1);
   if(short_confluence_now && !short_confluence_prev)
   {
      double sl_raw = bid + strategy_stop_atr_mult * atr14;
      if(sl_raw - bid < min_stop_distance)
         sl_raw = bid + min_stop_distance + point;

      req.type               = QM_SELL;
      req.price              = 0.0;
      req.sl                 = NormalizeDouble(sl_raw, digits);
      req.tp                 = 0.0;
      req.reason             = "bandy_hma_supertrend_bearish_confluence";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   return false;
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

   int st_curr = 0;
   int st_prev = 0;
   double close1 = 0.0;
   const bool st_ok = Strategy_GetSupertrendStates(st_curr, st_prev, close1);

   const double hma_f1 = QM_HMA(_Symbol, PERIOD_D1, strategy_hma_fast, 1, PRICE_CLOSE);
   const double hma_s1 = QM_HMA(_Symbol, PERIOD_D1, strategy_hma_slow, 1, PRICE_CLOSE);
   const int hma_curr = (hma_f1 > 0.0 && hma_s1 > 0.0) ? ((hma_f1 > hma_s1) ? 1 : ((hma_f1 < hma_s1) ? -1 : 0)) : 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      // Time stop
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && TimeCurrent() - opened >= strategy_max_hold_bars * period_seconds)
         return true;

      // Confluence break exit (either filter flips against the position)
      const long pos_type = PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY)
      {
         if((st_ok && st_curr == -1) || hma_curr == -1)
            return true;
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         if((st_ok && st_curr == 1) || hma_curr == 1)
            return true;
      }
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

// -----------------------------------------------------------------------------
// Framework wiring
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
   QM_FrameworkTrackOpenPositionMae();

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
