#property strict
#property version   "5.0"
#property description "QM5_11472 Nekritin/Peters Big Belt Marubozu D1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Strategy Card: QM5_11472_nekritin-peters-big-belt-d1
// Source: Nekritin and Peters, Naked Forex, Chapter 9.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11472;
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
input int    strategy_room_bars          = 7;
input double strategy_proximity_ratio    = 0.20;
input bool   strategy_gap_required       = true;
input int    strategy_dow_mode           = 0;      // 0=any day, 1=Monday, 2=Monday-Tuesday.
input double strategy_pip_offset_pips    = 1.0;
input int    strategy_max_range_pips     = 100;
input int    strategy_spread_cap_pips    = 25;
input int    strategy_fractal_lookback   = 80;

double Strategy_PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return point * pip_factor;
  }

bool Strategy_DayAllowed(const datetime bar_time)
  {
   if(strategy_dow_mode <= 0)
      return true;

   MqlDateTime dt;
   TimeToStruct(bar_time, dt);
   if(strategy_dow_mode == 1)
      return (dt.day_of_week == 1);
   if(strategy_dow_mode == 2)
      return (dt.day_of_week == 1 || dt.day_of_week == 2);
   return true;
  }

bool Strategy_LoadD1Rates(MqlRates &rates[], const int min_count)
  {
   if(min_count < 5)
      return false;

   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 0, min_count, rates); // perf-allowed: bounded D1 structural scan, called only after QM_IsNewBar().
   return (copied >= min_count);
  }

double Strategy_HighestHigh(MqlRates &rates[], const int from_shift, const int count)
  {
   double highest = -DBL_MAX;
   const int total = ArraySize(rates);
   const int last = from_shift + count - 1;
   if(from_shift < 0 || count <= 0 || last >= total)
      return 0.0;

   for(int shift = from_shift; shift <= last; ++shift)
      highest = MathMax(highest, rates[shift].high);
   return (highest == -DBL_MAX) ? 0.0 : highest;
  }

double Strategy_LowestLow(MqlRates &rates[], const int from_shift, const int count)
  {
   double lowest = DBL_MAX;
   const int total = ArraySize(rates);
   const int last = from_shift + count - 1;
   if(from_shift < 0 || count <= 0 || last >= total)
      return 0.0;

   for(int shift = from_shift; shift <= last; ++shift)
      lowest = MathMin(lowest, rates[shift].low);
   return (lowest == DBL_MAX) ? 0.0 : lowest;
  }

bool Strategy_IsSwingLow(MqlRates &rates[], const int shift)
  {
   const int total = ArraySize(rates);
   if(shift - 2 < 1 || shift + 2 >= total)
      return false;

   const double low = rates[shift].low;
   return (low < rates[shift - 1].low &&
           low < rates[shift - 2].low &&
           low <= rates[shift + 1].low &&
           low <= rates[shift + 2].low);
  }

bool Strategy_IsSwingHigh(MqlRates &rates[], const int shift)
  {
   const int total = ArraySize(rates);
   if(shift - 2 < 1 || shift + 2 >= total)
      return false;

   const double high = rates[shift].high;
   return (high > rates[shift - 1].high &&
           high > rates[shift - 2].high &&
           high >= rates[shift + 1].high &&
           high >= rates[shift + 2].high);
  }

double Strategy_NearestSupportBelow(MqlRates &rates[], const double entry_price)
  {
   double best = 0.0;
   const int total = ArraySize(rates);
   int last = strategy_fractal_lookback;
   if(last > total - 3)
      last = total - 3;

   for(int shift = 3; shift <= last; ++shift)
     {
      if(!Strategy_IsSwingLow(rates, shift))
         continue;
      const double level = rates[shift].low;
      if(level <= 0.0 || level >= entry_price)
         continue;
      if(best <= 0.0 || level > best)
         best = level;
     }
   return best;
  }

double Strategy_NearestResistanceAbove(MqlRates &rates[], const double entry_price)
  {
   double best = DBL_MAX;
   const int total = ArraySize(rates);
   int last = strategy_fractal_lookback;
   if(last > total - 3)
      last = total - 3;

   for(int shift = 3; shift <= last; ++shift)
     {
      if(!Strategy_IsSwingHigh(rates, shift))
         continue;
      const double level = rates[shift].high;
      if(level <= entry_price)
         continue;
      if(level < best)
         best = level;
     }
   return (best == DBL_MAX) ? 0.0 : best;
  }

bool Strategy_NoTradeFilter()
  {
   const double pip = Strategy_PipSize();
   if(pip <= 0.0 || strategy_spread_cap_pips <= 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return true;

   const double spread_pips = (ask - bid) / pip;
   return (spread_pips > strategy_spread_cap_pips);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_room_bars < 1 || strategy_fractal_lookback < 7)
      return false;
   if(strategy_proximity_ratio <= 0.0 || strategy_proximity_ratio >= 0.5)
      return false;

   const double pip = Strategy_PipSize();
   if(pip <= 0.0 || strategy_pip_offset_pips <= 0.0)
      return false;

   int needed = strategy_fractal_lookback + 4;
   if(strategy_room_bars + 4 > needed)
      needed = strategy_room_bars + 4;

   MqlRates rates[];
   if(!Strategy_LoadD1Rates(rates, needed))
      return false;

   const MqlRates belt = rates[1];
   const MqlRates prior = rates[2];
   const double range = belt.high - belt.low;
   if(range <= 0.0 || belt.open <= 0.0 || belt.close <= 0.0 || prior.close <= 0.0)
      return false;

   if(strategy_max_range_pips > 0 && range / pip > strategy_max_range_pips)
      return false;

   if(!Strategy_DayAllowed(belt.time))
      return false;

   const double offset = strategy_pip_offset_pips * pip;
   int expiry = PeriodSeconds(PERIOD_D1);
   if(expiry <= 0)
      expiry = 86400;

   const bool bearish_gap = (!strategy_gap_required || belt.open > prior.close);
   const bool bearish_shape = ((belt.high - belt.open) < strategy_proximity_ratio * range &&
                               (belt.close - belt.low) < strategy_proximity_ratio * range);
   const double room_high = Strategy_HighestHigh(rates, 2, strategy_room_bars);
   if(bearish_gap && bearish_shape && room_high > 0.0 && belt.high > room_high)
     {
      req.type = QM_SELL_STOP;
      req.price = QM_TM_NormalizePrice(_Symbol, belt.low - offset);
      req.sl = QM_TM_NormalizePrice(_Symbol, belt.high + offset);
      req.tp = QM_TM_NormalizePrice(_Symbol, Strategy_NearestSupportBelow(rates, req.price));
      req.reason = "BIG_BELT_BEARISH_SELLSTOP";
      req.expiration_seconds = expiry;
      return (req.price > 0.0 && req.sl > req.price && req.tp > 0.0 && req.tp < req.price);
     }

   const bool bullish_gap = (!strategy_gap_required || belt.open < prior.close);
   const bool bullish_shape = ((belt.open - belt.low) < strategy_proximity_ratio * range &&
                               (belt.high - belt.close) < strategy_proximity_ratio * range);
   const double room_low = Strategy_LowestLow(rates, 2, strategy_room_bars);
   if(bullish_gap && bullish_shape && room_low > 0.0 && belt.low < room_low)
     {
      req.type = QM_BUY_STOP;
      req.price = QM_TM_NormalizePrice(_Symbol, belt.high + offset);
      req.sl = QM_TM_NormalizePrice(_Symbol, belt.low - offset);
      req.tp = QM_TM_NormalizePrice(_Symbol, Strategy_NearestResistanceAbove(rates, req.price));
      req.reason = "BIG_BELT_BULLISH_BUYSTOP";
      req.expiration_seconds = expiry;
      return (req.price > 0.0 && req.sl > 0.0 && req.sl < req.price && req.tp > req.price);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial close, or break-even management.
  }

bool Strategy_ExitSignal()
  {
   // Exits are broker SL/TP plus framework Friday close.
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
