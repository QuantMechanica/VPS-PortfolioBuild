#property strict
#property version   "5.0"
#property description "QM5_10983 FTMO Trendline Break 1-2-3 Reversal"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10983;
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
input ENUM_TIMEFRAMES strategy_timeframe          = PERIOD_H4;
input int    strategy_ema_period                  = 50;
input int    strategy_atr_period                  = 14;
input int    strategy_fractal_wing                = 3;
input int    strategy_scan_bars                   = 160;
input int    strategy_bounce_max_bars             = 12;
input double strategy_trendline_break_atr         = 0.20;
input double strategy_sl_buffer_atr               = 0.30;
input double strategy_tp_r_multiple               = 2.0;
input double strategy_max_risk_atr                = 2.50;
input int    strategy_exhaustion_bars             = 100;
input double strategy_exhaustion_atr              = 0.50;
input double strategy_spread_atr                  = 0.20;
input int    strategy_max_hold_bars               = 30;

struct StrategyPivot
  {
   int      idx;
   double   price;
   datetime time;
  };

struct StrategySignal
  {
   bool     valid;
   int      side;
   double   entry;
   double   sl;
   double   tp;
   datetime key_time;
  };

datetime g_last_entry_key = 0;
bool     g_exit_on_opposite = false;

void ResetSignal(StrategySignal &sig)
  {
   sig.valid = false;
   sig.side = 0;
   sig.entry = 0.0;
   sig.sl = 0.0;
   sig.tp = 0.0;
   sig.key_time = 0;
  }

bool IsFractalHigh(const MqlRates &rates[], const int idx, const int bars)
  {
   if(idx < strategy_fractal_wing || idx + strategy_fractal_wing >= bars)
      return false;
   const double h = rates[idx].high;
   if(h <= 0.0)
      return false;
   for(int j = 1; j <= strategy_fractal_wing; ++j)
      if(h <= rates[idx - j].high || h <= rates[idx + j].high)
         return false;
   return true;
  }

bool IsFractalLow(const MqlRates &rates[], const int idx, const int bars)
  {
   if(idx < strategy_fractal_wing || idx + strategy_fractal_wing >= bars)
      return false;
   const double l = rates[idx].low;
   if(l <= 0.0)
      return false;
   for(int j = 1; j <= strategy_fractal_wing; ++j)
      if(l >= rates[idx - j].low || l >= rates[idx + j].low)
         return false;
   return true;
  }

int CollectPivots(const MqlRates &rates[],
                  const int bars,
                  StrategyPivot &highs[],
                  StrategyPivot &lows[],
                  int &high_count,
                  int &low_count)
  {
   high_count = 0;
   low_count = 0;
   const int max_pivots = 80;
   for(int idx = strategy_fractal_wing; idx < bars - strategy_fractal_wing && idx < strategy_scan_bars; ++idx)
     {
      if(IsFractalHigh(rates, idx, bars) && high_count < max_pivots)
        {
         highs[high_count].idx = idx;
         highs[high_count].price = rates[idx].high;
         highs[high_count].time = rates[idx].time;
         ++high_count;
        }
      if(IsFractalLow(rates, idx, bars) && low_count < max_pivots)
        {
         lows[low_count].idx = idx;
         lows[low_count].price = rates[idx].low;
         lows[low_count].time = rates[idx].time;
         ++low_count;
        }
     }
   return MathMax(high_count, low_count);
  }

double TrendLineAt(const StrategyPivot &newer_pivot,
                   const StrategyPivot &older_pivot,
                   const int idx)
  {
   const double denom = (double)(newer_pivot.idx - older_pivot.idx);
   if(MathAbs(denom) <= 0.000001)
      return 0.0;
   const double slope = (newer_pivot.price - older_pivot.price) / denom;
   return older_pivot.price + slope * (double)(idx - older_pivot.idx);
  }

bool ThreePriorRisingLows(const StrategyPivot &lows[],
                          const int pivot_count,
                          const int break_idx,
                          StrategyPivot &newer,
                          StrategyPivot &older)
  {
   StrategyPivot found[3];
   int count = 0;
   for(int i = 0; i < pivot_count && count < 3; ++i)
     {
      if(lows[i].idx <= break_idx)
         continue;
      found[count] = lows[i];
      ++count;
     }
   if(count < 3)
      return false;
   if(!(found[2].price < found[1].price && found[1].price < found[0].price))
      return false;
   newer = found[0];
   older = found[1];
   return true;
  }

bool ThreePriorFallingHighs(const StrategyPivot &highs[],
                            const int pivot_count,
                            const int break_idx,
                            StrategyPivot &newer,
                            StrategyPivot &older)
  {
   StrategyPivot found[3];
   int count = 0;
   for(int i = 0; i < pivot_count && count < 3; ++i)
     {
      if(highs[i].idx <= break_idx)
         continue;
      found[count] = highs[i];
      ++count;
     }
   if(count < 3)
      return false;
   if(!(found[2].price > found[1].price && found[1].price > found[0].price))
      return false;
   newer = found[0];
   older = found[1];
   return true;
  }

bool PriorHigherHigh(const StrategyPivot &highs[],
                     const int pivot_count,
                     const int pivot_idx,
                     const double price,
                     double &prior_price)
  {
   for(int i = 0; i < pivot_count; ++i)
     {
      if(highs[i].idx > pivot_idx)
        {
         prior_price = highs[i].price;
         return (price < prior_price);
        }
     }
   prior_price = 0.0;
   return false;
  }

bool PriorLowerLow(const StrategyPivot &lows[],
                   const int pivot_count,
                   const int pivot_idx,
                   const double price,
                   double &prior_price)
  {
   for(int i = 0; i < pivot_count; ++i)
     {
      if(lows[i].idx > pivot_idx)
        {
         prior_price = lows[i].price;
         return (price > prior_price);
        }
     }
   prior_price = 0.0;
   return false;
  }

double LowestLowBetween(const MqlRates &rates[], const int newer_idx, const int older_idx)
  {
   double lo = DBL_MAX;
   for(int idx = newer_idx; idx <= older_idx; ++idx)
      lo = MathMin(lo, rates[idx].low);
   return (lo == DBL_MAX) ? 0.0 : lo;
  }

double HighestHighBetween(const MqlRates &rates[], const int newer_idx, const int older_idx)
  {
   double hi = 0.0;
   for(int idx = newer_idx; idx <= older_idx; ++idx)
      hi = MathMax(hi, rates[idx].high);
   return hi;
  }

bool NearExhaustionAgainstTarget(const MqlRates &rates[],
                                 const int bars,
                                 const int side,
                                 const double close_price,
                                 const double atr)
  {
   if(strategy_exhaustion_bars <= 0 || bars < strategy_exhaustion_bars || atr <= 0.0)
      return false;
   double hi = 0.0;
   double lo = DBL_MAX;
   for(int idx = 0; idx < strategy_exhaustion_bars && idx < bars; ++idx)
     {
      hi = MathMax(hi, rates[idx].high);
      lo = MathMin(lo, rates[idx].low);
     }
   if(side < 0)
      return (close_price - lo) <= strategy_exhaustion_atr * atr;
   return (hi - close_price) <= strategy_exhaustion_atr * atr;
  }

bool BuildShortSignal(const MqlRates &rates[],
                      const int bars,
                      const StrategyPivot &highs[],
                      const int high_count,
                      const StrategyPivot &lows[],
                      const int low_count,
                      StrategySignal &sig)
  {
   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double ema = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, 1);
   const double close1 = rates[0].close;
   if(atr <= 0.0 || ema <= 0.0 || close1 <= 0.0 || close1 >= ema)
      return false;

   for(int break_idx = strategy_fractal_wing + 2; break_idx < bars - strategy_fractal_wing; ++break_idx)
     {
      StrategyPivot low_newer, low_older;
      if(!ThreePriorRisingLows(lows, low_count, break_idx, low_newer, low_older))
         continue;
      const double line_at_break = TrendLineAt(low_newer, low_older, break_idx);
      if(line_at_break <= 0.0 || rates[break_idx].close >= line_at_break - strategy_trendline_break_atr * atr)
         continue;

      for(int h = 0; h < high_count; ++h)
        {
         const int pull_idx = highs[h].idx;
         if(pull_idx <= strategy_fractal_wing || pull_idx >= break_idx)
            continue;
         if((break_idx - pull_idx) > strategy_bounce_max_bars)
            continue;
         double prior_high = 0.0;
         if(!PriorHigherHigh(highs, high_count, pull_idx, highs[h].price, prior_high))
            continue;
         const double pullback_low = LowestLowBetween(rates, pull_idx + 1, break_idx);
         if(pullback_low <= 0.0 || close1 >= pullback_low)
            continue;

         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         const double entry = (bid > 0.0) ? bid : close1;
         const double sl = highs[h].price + strategy_sl_buffer_atr * atr;
         const double risk = sl - entry;
         if(risk <= 0.0 || risk > strategy_max_risk_atr * atr)
            continue;
         if(NearExhaustionAgainstTarget(rates, bars, -1, close1, atr))
            continue;

         sig.valid = true;
         sig.side = -1;
         sig.entry = entry;
         sig.sl = NormalizeDouble(sl, _Digits);
         sig.tp = NormalizeDouble(entry - strategy_tp_r_multiple * risk, _Digits);
         sig.key_time = highs[h].time;
         return true;
        }
     }
   return false;
  }

bool BuildLongSignal(const MqlRates &rates[],
                     const int bars,
                     const StrategyPivot &highs[],
                     const int high_count,
                     const StrategyPivot &lows[],
                     const int low_count,
                     StrategySignal &sig)
  {
   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double ema = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, 1);
   const double close1 = rates[0].close;
   if(atr <= 0.0 || ema <= 0.0 || close1 <= 0.0 || close1 <= ema)
      return false;

   for(int break_idx = strategy_fractal_wing + 2; break_idx < bars - strategy_fractal_wing; ++break_idx)
     {
      StrategyPivot high_newer, high_older;
      if(!ThreePriorFallingHighs(highs, high_count, break_idx, high_newer, high_older))
         continue;
      const double line_at_break = TrendLineAt(high_newer, high_older, break_idx);
      if(line_at_break <= 0.0 || rates[break_idx].close <= line_at_break + strategy_trendline_break_atr * atr)
         continue;

      for(int l = 0; l < low_count; ++l)
        {
         const int pull_idx = lows[l].idx;
         if(pull_idx <= strategy_fractal_wing || pull_idx >= break_idx)
            continue;
         if((break_idx - pull_idx) > strategy_bounce_max_bars)
            continue;
         double prior_low = 0.0;
         if(!PriorLowerLow(lows, low_count, pull_idx, lows[l].price, prior_low))
            continue;
         const double pullback_high = HighestHighBetween(rates, pull_idx + 1, break_idx);
         if(pullback_high <= 0.0 || close1 <= pullback_high)
            continue;

         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         const double entry = (ask > 0.0) ? ask : close1;
         const double sl = lows[l].price - strategy_sl_buffer_atr * atr;
         const double risk = entry - sl;
         if(risk <= 0.0 || risk > strategy_max_risk_atr * atr)
            continue;
         if(NearExhaustionAgainstTarget(rates, bars, 1, close1, atr))
            continue;

         sig.valid = true;
         sig.side = 1;
         sig.entry = entry;
         sig.sl = NormalizeDouble(sl, _Digits);
         sig.tp = NormalizeDouble(entry + strategy_tp_r_multiple * risk, _Digits);
         sig.key_time = lows[l].time;
         return true;
        }
     }
   return false;
  }

bool DetectSignal(StrategySignal &sig)
  {
   ResetSignal(sig);
   if(strategy_fractal_wing < 1 || strategy_scan_bars < 60 || strategy_bounce_max_bars < 1)
      return false;

   const int bars_needed = MathMax(strategy_scan_bars, strategy_exhaustion_bars) + strategy_fractal_wing + 8;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_timeframe, 1, bars_needed, rates); // perf-allowed: closed-bar structural scan runs only from framework-gated hooks.
   if(copied < MathMax(80, strategy_exhaustion_bars))
      return false;

   StrategyPivot highs[80];
   StrategyPivot lows[80];
   int high_count = 0;
   int low_count = 0;
   CollectPivots(rates, copied, highs, lows, high_count, low_count);
   if(high_count < 3 || low_count < 3)
      return false;

   if(BuildShortSignal(rates, copied, highs, high_count, lows, low_count, sig))
      return true;
   return BuildLongSignal(rates, copied, highs, high_count, lows, low_count, sig);
  }

bool HasOurPosition(int &side)
  {
   side = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      side = (type == POSITION_TYPE_BUY) ? 1 : -1;
      return true;
     }
   return false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(strategy_spread_atr > 0.0)
     {
      const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
         return true;
      if((ask - bid) > strategy_spread_atr * atr)
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

   int side = 0;
   if(HasOurPosition(side))
      return false;

   StrategySignal sig;
   if(!DetectSignal(sig) || !sig.valid)
      return false;
   if(sig.key_time == g_last_entry_key)
      return false;

   req.type = (sig.side > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = sig.sl;
   req.tp = sig.tp;
   req.reason = (sig.side > 0) ? "ftmo_123_long" : "ftmo_123_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   g_last_entry_key = sig.key_time;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   g_exit_on_opposite = false;
   int side = 0;
   if(!HasOurPosition(side))
      return;
   if(!QM_IsNewBar(_Symbol, strategy_timeframe))
      return;

   StrategySignal sig;
   if(DetectSignal(sig) && sig.valid && sig.side == -side)
      g_exit_on_opposite = true;
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(g_exit_on_opposite)
      return true;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_max_hold_bars <= 0)
      return false;

   const int hold_seconds = strategy_max_hold_bars * PeriodSeconds(strategy_timeframe);
   if(hold_seconds <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && (TimeCurrent() - opened) >= hold_seconds)
         return true;
     }
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
