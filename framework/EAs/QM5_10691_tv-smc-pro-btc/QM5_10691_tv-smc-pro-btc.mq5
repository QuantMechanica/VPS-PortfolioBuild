#property strict
#property version   "5.0"
#property description "QM5_10691 TradingView SMC Pro BTC OB/FVG"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10691;
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
input ENUM_TIMEFRAMES strategy_direction_tf       = PERIOD_H4;
input ENUM_TIMEFRAMES strategy_confirmation_tf    = PERIOD_H1;
input bool            strategy_selective_mode     = false;
input int             strategy_swing_length       = 10;
input int             strategy_ob_lookback        = 15;
input int             strategy_fvg_lookback       = 15;
input int             strategy_sweep_memory_bars  = 20;
input int             strategy_atr_period         = 14;
input double          strategy_sl_buffer_pct      = 0.30;
input double          strategy_max_stop_atr       = 3.00;
input double          strategy_rr                 = 2.00;
input int             strategy_max_spread_points  = 0;

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, _Digits);
  }

bool Strategy_LoadRates(MqlRates &rates[], const ENUM_TIMEFRAMES tf, const int bars)
  {
   const int requested = MathMax(bars, strategy_swing_length + strategy_ob_lookback + strategy_sweep_memory_bars + 12);
   ArrayResize(rates, requested);
   const int copied = CopyRates(_Symbol, tf, 1, requested, rates); // perf-allowed: bounded SMC structure snapshot on closed-bar entry path.
   if(copied < MathMax(20, strategy_swing_length + 8))
      return false;
   ArraySetAsSeries(rates, true);
   return true;
  }

double Strategy_HighestHigh(MqlRates &rates[], const int start_shift, const int count)
  {
   const int total = ArraySize(rates);
   const int end_shift = MathMin(total - 1, start_shift + MathMax(count, 1) - 1);
   double highest = -DBL_MAX;
   for(int i = start_shift; i <= end_shift; ++i)
      highest = MathMax(highest, rates[i].high);
   return highest;
  }

double Strategy_LowestLow(MqlRates &rates[], const int start_shift, const int count)
  {
   const int total = ArraySize(rates);
   const int end_shift = MathMin(total - 1, start_shift + MathMax(count, 1) - 1);
   double lowest = DBL_MAX;
   for(int i = start_shift; i <= end_shift; ++i)
      lowest = MathMin(lowest, rates[i].low);
   return lowest;
  }

int Strategy_StructureDirection(MqlRates &rates[])
  {
   if(ArraySize(rates) < strategy_swing_length + 3)
      return 0;

   const double break_high = Strategy_HighestHigh(rates, 1, strategy_swing_length);
   const double break_low = Strategy_LowestLow(rates, 1, strategy_swing_length);
   if(break_high <= 0.0 || break_low == DBL_MAX)
      return 0;

   if(rates[0].close > break_high)
      return 1;
   if(rates[0].close < break_low)
      return -1;
   return 0;
  }

bool Strategy_FindOrderBlock(MqlRates &rates[],
                             const int direction,
                             double &ob_low,
                             double &ob_high)
  {
   ob_low = 0.0;
   ob_high = 0.0;
   const int total = ArraySize(rates);
   const int max_shift = MathMin(strategy_ob_lookback, total - 3);

   for(int shift = 1; shift <= max_shift; ++shift)
     {
      const bool bearish_candle = (rates[shift].close < rates[shift].open);
      const bool bullish_candle = (rates[shift].close > rates[shift].open);
      if(direction > 0 && bearish_candle && rates[0].close > rates[shift].high)
        {
         ob_low = rates[shift].low;
         ob_high = rates[shift].high;
         return (ob_high > ob_low && ob_low > 0.0);
        }
      if(direction < 0 && bullish_candle && rates[0].close < rates[shift].low)
        {
         ob_low = rates[shift].low;
         ob_high = rates[shift].high;
         return (ob_high > ob_low && ob_low > 0.0);
        }
     }

   return false;
  }

bool Strategy_HasFvgOverlap(MqlRates &rates[],
                            const int direction,
                            const double ob_low,
                            const double ob_high)
  {
   const int total = ArraySize(rates);
   const int max_shift = MathMin(strategy_fvg_lookback, total - 3);
   for(int shift = 0; shift <= max_shift; ++shift)
     {
      if(direction > 0 && rates[shift].low > rates[shift + 2].high)
        {
         const double fvg_low = rates[shift + 2].high;
         const double fvg_high = rates[shift].low;
         if(MathMax(fvg_low, ob_low) <= MathMin(fvg_high, ob_high))
            return true;
        }
      if(direction < 0 && rates[shift].high < rates[shift + 2].low)
        {
         const double fvg_low = rates[shift].high;
         const double fvg_high = rates[shift + 2].low;
         if(MathMax(fvg_low, ob_low) <= MathMin(fvg_high, ob_high))
            return true;
        }
     }

   return false;
  }

bool Strategy_HasLiquiditySweep(MqlRates &rates[], const int direction)
  {
   const int total = ArraySize(rates);
   const int memory = MathMin(strategy_sweep_memory_bars, total - strategy_swing_length - 2);
   for(int shift = 0; shift < memory; ++shift)
     {
      const double prior_low = Strategy_LowestLow(rates, shift + 1, strategy_swing_length);
      const double prior_high = Strategy_HighestHigh(rates, shift + 1, strategy_swing_length);
      if(direction > 0 && prior_low < DBL_MAX && rates[shift].low < prior_low && rates[shift].close > prior_low)
         return true;
      if(direction < 0 && prior_high > 0.0 && rates[shift].high > prior_high && rates[shift].close < prior_high)
         return true;
     }

   return false;
  }

bool Strategy_SelectiveLocationOk(MqlRates &htf_rates[], MqlRates &ctf_rates[], const int direction)
  {
   if(!strategy_selective_mode)
      return true;

   const double range_high = Strategy_HighestHigh(htf_rates, 0, MathMax(strategy_swing_length * 2, 20));
   const double range_low = Strategy_LowestLow(htf_rates, 0, MathMax(strategy_swing_length * 2, 20));
   if(range_high <= 0.0 || range_low <= 0.0 || range_high <= range_low)
      return false;

   const double midpoint = (range_high + range_low) * 0.5;
   if(direction > 0)
      return (ctf_rates[0].close <= midpoint);
   return (ctf_rates[0].close >= midpoint);
  }

bool Strategy_HasOurPosition()
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }

   return false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != strategy_confirmation_tf)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
         return true;
      if((ask - bid) / point > strategy_max_spread_points)
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

   if(Strategy_HasOurPosition())
      return false;
   if(strategy_swing_length < 3 || strategy_ob_lookback < 3 || strategy_fvg_lookback < 3 ||
      strategy_sweep_memory_bars < 1 || strategy_atr_period < 1 ||
      strategy_rr <= 0.0 || strategy_max_stop_atr <= 0.0)
      return false;

   MqlRates htf_rates[];
   MqlRates ctf_rates[];
   const int bars_needed = MathMax(strategy_swing_length * 3,
                                   strategy_ob_lookback + strategy_fvg_lookback + strategy_sweep_memory_bars + 12);
   if(!Strategy_LoadRates(htf_rates, strategy_direction_tf, bars_needed))
      return false;
   if(!Strategy_LoadRates(ctf_rates, strategy_confirmation_tf, bars_needed))
      return false;

   const int htf_dir = Strategy_StructureDirection(htf_rates);
   const int ctf_dir = Strategy_StructureDirection(ctf_rates);
   if(htf_dir == 0 || ctf_dir == 0 || htf_dir != ctf_dir)
      return false;

   const int direction = htf_dir;
   double ob_low = 0.0;
   double ob_high = 0.0;
   if(!Strategy_FindOrderBlock(ctf_rates, direction, ob_low, ob_high))
      return false;
   if(!Strategy_HasFvgOverlap(ctf_rates, direction, ob_low, ob_high))
      return false;
   if(!Strategy_HasLiquiditySweep(ctf_rates, direction))
      return false;
   if(!Strategy_SelectiveLocationOk(htf_rates, ctf_rates, direction))
      return false;

   const double atr = QM_ATR(_Symbol, strategy_confirmation_tf, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   const double buffer_mult = MathMax(strategy_sl_buffer_pct, 0.0) / 100.0;
   if(direction > 0)
     {
      const double raw_sl = ob_low * (1.0 - buffer_mult);
      const double capped_sl = ask - atr * strategy_max_stop_atr;
      const double sl = Strategy_NormalizePrice(MathMax(raw_sl, capped_sl));
      if(sl <= 0.0 || sl >= ask - point)
         return false;

      const double tp = QM_TakeRR(_Symbol, QM_BUY, ask, sl, strategy_rr);
      if(tp <= ask)
         return false;

      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = "SMC_PRO_LONG_BOS_CHOCH_OB_FVG_SWEEP";
      return true;
     }

   const double raw_sl = ob_high * (1.0 + buffer_mult);
   const double capped_sl = bid + atr * strategy_max_stop_atr;
   const double sl = Strategy_NormalizePrice(MathMin(raw_sl, capped_sl));
   if(sl <= bid + point)
      return false;

   const double tp = QM_TakeRR(_Symbol, QM_SELL, bid, sl, strategy_rr);
   if(tp <= 0.0 || tp >= bid)
      return false;

   req.type = QM_SELL;
   req.sl = sl;
   req.tp = tp;
   req.reason = "SMC_PRO_SHORT_BOS_CHOCH_OB_FVG_SWEEP";
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card baseline has fixed OB stop, fixed 2R target, no trailing or pyramiding.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   // Opposite confirmed structure close is reserved for a P3 variant.
   return false;
  }

// News Filter Hook
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10691_tv-smc-pro-btc\"}");
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
