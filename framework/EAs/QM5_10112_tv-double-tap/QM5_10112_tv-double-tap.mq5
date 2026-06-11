#property strict
#property version   "5.0"
#property description "QM5_10112 TradingView Bjorgum Double Tap"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  - closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        - risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() - use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly -
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10112;
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
input int    strategy_pivot_lookback_bars = 5;
input int    strategy_atr_period          = 14;
input double strategy_pivot_tolerance_atr = 0.50;
input double strategy_stop_buffer_atr     = 0.25;
input int    strategy_scan_bars           = 220;
input int    strategy_max_spread_points   = 0;

// -----------------------------------------------------------------------------
// Strategy hooks - implement these against the card mechanically.
// -----------------------------------------------------------------------------

// No Trade Filter - framework gates time/news/Friday close; this EA only adds an
// optional spread ceiling when a setfile declares one.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points <= 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return true;

   return ((ask - bid) / point > strategy_max_spread_points);
  }

// Trade Entry - confirmed double-top/double-bottom neckline breakouts from a
// fixed-lookback zig-zag pivot scan. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   static datetime fired_bottom_time = 0;
   static datetime fired_top_time = 0;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_pivot_lookback_bars < 2 ||
      strategy_atr_period < 1 ||
      strategy_pivot_tolerance_atr <= 0.0 ||
      strategy_stop_buffer_atr <= 0.0 ||
      strategy_scan_bars < (strategy_pivot_lookback_bars * 2 + 20))
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, strategy_scan_bars, rates); // perf-allowed: bespoke pivot scan; Strategy_EntrySignal is called only after the framework QM_IsNewBar() gate.
   const int min_bars = strategy_pivot_lookback_bars * 2 + 3;
   if(copied < min_bars)
      return false;

   int pivot_type[96];
   double pivot_price[96];
   datetime pivot_time[96];
   int pivot_index[96];
   int pivot_count = 0;

   for(int i = copied - strategy_pivot_lookback_bars - 1; i >= strategy_pivot_lookback_bars; --i)
     {
      bool is_high = true;
      bool is_low = true;
      for(int j = 1; j <= strategy_pivot_lookback_bars; ++j)
        {
         if(rates[i].high <= rates[i - j].high || rates[i].high <= rates[i + j].high)
            is_high = false;
         if(rates[i].low >= rates[i - j].low || rates[i].low >= rates[i + j].low)
            is_low = false;
        }

      int next_type = 0;
      double next_price = 0.0;
      if(is_high && !is_low)
        {
         next_type = 1;
         next_price = rates[i].high;
        }
      else if(is_low && !is_high)
        {
         next_type = -1;
         next_price = rates[i].low;
        }
      else
         continue;

      if(pivot_count > 0 && pivot_type[pivot_count - 1] == next_type)
        {
         const bool more_extreme = (next_type > 0)
                                   ? (next_price > pivot_price[pivot_count - 1])
                                   : (next_price < pivot_price[pivot_count - 1]);
         if(more_extreme)
           {
            pivot_price[pivot_count - 1] = next_price;
            pivot_time[pivot_count - 1] = rates[i].time;
            pivot_index[pivot_count - 1] = i;
           }
         continue;
        }

      if(pivot_count >= 96)
         break;

      pivot_type[pivot_count] = next_type;
      pivot_price[pivot_count] = next_price;
      pivot_time[pivot_count] = rates[i].time;
      pivot_index[pivot_count] = i;
      pivot_count++;
     }

   if(pivot_count < 3)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = 8;
   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double min_stop_distance = MathMax((double)stops_level * point, point);
   const double tolerance = atr * strategy_pivot_tolerance_atr;
   const double stop_buffer = atr * strategy_stop_buffer_atr;
   const double last_close = rates[0].close;
   const double prev_close = rates[1].close;

   for(int p = pivot_count - 1; p >= 2; --p)
     {
      if(pivot_type[p] == -1 && pivot_type[p - 1] == 1 && pivot_type[p - 2] == -1)
        {
         const double first_low = pivot_price[p - 2];
         const double neckline = pivot_price[p - 1];
         const double second_low = pivot_price[p];
         const double pattern_low = MathMin(first_low, second_low);
         if(fired_bottom_time == pivot_time[p])
            continue;
         if(MathAbs(second_low - first_low) > tolerance)
            continue;
         if(second_low < first_low - tolerance)
            continue;
         if(rates[0].time <= pivot_time[p])
            continue;
         if(!(last_close > neckline && prev_close <= neckline))
            continue;

         double sl = NormalizeDouble(pattern_low - stop_buffer, digits);
         double tp = NormalizeDouble(neckline + (neckline - pattern_low), digits);
         if(sl <= 0.0 || tp <= 0.0 || sl >= ask || tp <= ask)
            continue;
         if(ask - sl < min_stop_distance)
            sl = NormalizeDouble(ask - min_stop_distance - point, digits);
         if(tp - ask < min_stop_distance)
            tp = NormalizeDouble(ask + min_stop_distance + point, digits);

         req.type = QM_BUY;
         req.sl = sl;
         req.tp = tp;
         req.reason = "double_bottom_neckline_breakout";
         fired_bottom_time = pivot_time[p];
         return true;
        }

      if(pivot_type[p] == 1 && pivot_type[p - 1] == -1 && pivot_type[p - 2] == 1)
        {
         const double first_high = pivot_price[p - 2];
         const double neckline = pivot_price[p - 1];
         const double second_high = pivot_price[p];
         const double pattern_high = MathMax(first_high, second_high);
         if(fired_top_time == pivot_time[p])
            continue;
         if(MathAbs(second_high - first_high) > tolerance)
            continue;
         if(second_high > first_high + tolerance)
            continue;
         if(rates[0].time <= pivot_time[p])
            continue;
         if(!(last_close < neckline && prev_close >= neckline))
            continue;

         double sl = NormalizeDouble(pattern_high + stop_buffer, digits);
         double tp = NormalizeDouble(neckline - (pattern_high - neckline), digits);
         if(sl <= 0.0 || tp <= 0.0 || sl <= bid || tp >= bid)
            continue;
         if(sl - bid < min_stop_distance)
            sl = NormalizeDouble(bid + min_stop_distance + point, digits);
         if(bid - tp < min_stop_distance)
            tp = NormalizeDouble(bid - min_stop_distance - point, digits);

         req.type = QM_SELL;
         req.sl = sl;
         req.tp = tp;
         req.reason = "double_top_neckline_breakout";
         fired_top_time = pivot_time[p];
         return true;
        }
     }

   return false;
  }

// Trade Management - baseline card uses fixed TP/SL only; optional ATR trailing
// is reserved for P3 and is intentionally not enabled in this build.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close - discretionary exits are represented by fixed structure TP/SL.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook - defer to the central framework news filter.
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
