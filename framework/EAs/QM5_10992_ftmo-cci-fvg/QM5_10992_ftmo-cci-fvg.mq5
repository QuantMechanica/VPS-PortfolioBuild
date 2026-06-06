#property strict
#property version   "5.0"
#property description "QM5_10992 FTMO CCI FVG continuation"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10992;
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
input ENUM_TIMEFRAMES strategy_timeframe          = PERIOD_H1;
input int             strategy_cci_period         = 20;
input int             strategy_ema_period         = 50;
input int             strategy_atr_period         = 14;
input int             strategy_cci_cross_lookback = 3;
input int             strategy_fvg_lookback_bars  = 8;
input double          strategy_fvg_min_atr_mult   = 0.25;
input double          strategy_fvg_max_atr_mult   = 1.50;
input double          strategy_sl_atr_mult        = 0.35;
input double          strategy_rr                 = 2.0;
input int             strategy_max_hold_bars      = 36;
input int             strategy_spread_median_bars = 20;
input double          strategy_spread_median_mult = 1.5;

struct StrategyFvg
  {
   bool   found;
   bool   bullish;
   double lower;
   double upper;
   double midpoint;
  };

double StrategyClose(const int shift)
  {
   return iClose(_Symbol, strategy_timeframe, shift); // perf-allowed: bounded FVG closed-bar structural read
  }

double StrategyHigh(const int shift)
  {
   return iHigh(_Symbol, strategy_timeframe, shift); // perf-allowed: bounded FVG closed-bar structural read
  }

double StrategyLow(const int shift)
  {
   return iLow(_Symbol, strategy_timeframe, shift); // perf-allowed: bounded FVG closed-bar structural read
  }

int StrategyOpenPositionCount()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      count++;
     }
   return count;
  }

bool StrategySpreadAllowsEntry()
  {
   if(strategy_spread_median_bars <= 0)
      return true;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return false;

   long spreads[];
   ArraySetAsSeries(spreads, true);
   const int copied = CopySpread(_Symbol, strategy_timeframe, 1, strategy_spread_median_bars, spreads); // perf-allowed: closed-bar spread median filter
   if(copied < strategy_spread_median_bars)
      return false;

   ArraySort(spreads);
   double median = 0.0;
   const int mid = copied / 2;
   if((copied % 2) == 0)
      median = ((double)spreads[mid - 1] + (double)spreads[mid]) * 0.5;
   else
      median = (double)spreads[mid];

   if(median <= 0.0)
      return false;

   return ((double)current_spread <= median * strategy_spread_median_mult);
  }

bool StrategyCciCrossed(const bool long_side)
  {
   const int lookback = MathMax(1, strategy_cci_cross_lookback);
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double cci_now = QM_CCI(_Symbol, strategy_timeframe, strategy_cci_period, shift);
      const double cci_prev = QM_CCI(_Symbol, strategy_timeframe, strategy_cci_period, shift + 1);
      if(long_side && cci_prev <= 0.0 && cci_now > 0.0)
         return true;
      if(!long_side && cci_prev >= 0.0 && cci_now < 0.0)
         return true;
     }
   return false;
  }

bool StrategyFindFvg(const bool bullish, const double atr, StrategyFvg &out_fvg)
  {
   out_fvg.found = false;
   out_fvg.bullish = bullish;
   out_fvg.lower = 0.0;
   out_fvg.upper = 0.0;
   out_fvg.midpoint = 0.0;

   if(atr <= 0.0 || strategy_fvg_lookback_bars < 3)
      return false;

   const int max_start = MathMax(1, strategy_fvg_lookback_bars - 2);
   for(int shift = 1; shift <= max_start; ++shift)
     {
      const double newer_low = StrategyLow(shift);
      const double newer_high = StrategyHigh(shift);
      const double older_low = StrategyLow(shift + 2);
      const double older_high = StrategyHigh(shift + 2);
      if(newer_low <= 0.0 || newer_high <= 0.0 || older_low <= 0.0 || older_high <= 0.0)
         continue;

      double lower = 0.0;
      double upper = 0.0;
      if(bullish)
        {
         if(newer_low <= older_high)
            continue;
         lower = older_high;
         upper = newer_low;
        }
      else
        {
         if(newer_high >= older_low)
            continue;
         lower = newer_high;
         upper = older_low;
        }

      const double height = upper - lower;
      if(height < strategy_fvg_min_atr_mult * atr || height > strategy_fvg_max_atr_mult * atr)
         continue;

      out_fvg.found = true;
      out_fvg.lower = lower;
      out_fvg.upper = upper;
      out_fvg.midpoint = (lower + upper) * 0.5;
      return true;
     }

   return false;
  }

bool StrategyBuildRequest(const bool long_side, const StrategyFvg &fvg, const double atr, QM_EntryRequest &req)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double close1 = StrategyClose(1);
   const double high1 = StrategyHigh(1);
   const double low1 = StrategyLow(1);
   if(point <= 0.0 || close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || atr <= 0.0)
      return false;

   if(long_side)
     {
      const bool retraced_upper_half = (low1 <= fvg.upper && low1 >= fvg.midpoint);
      if(!retraced_upper_half || close1 <= fvg.midpoint)
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl = fvg.lower - strategy_sl_atr_mult * atr;
      if(entry <= 0.0 || sl <= 0.0 || sl >= entry)
         return false;

      const double risk = entry - sl;
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = entry + strategy_rr * risk;
      req.reason = "CCI_FVG_LONG";
     }
   else
     {
      const bool retraced_lower_half = (high1 >= fvg.lower && high1 <= fvg.midpoint);
      if(!retraced_lower_half || close1 >= fvg.midpoint)
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl = fvg.upper + strategy_sl_atr_mult * atr;
      if(entry <= 0.0 || sl <= 0.0 || sl <= entry)
         return false;

      const double risk = sl - entry;
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = entry - strategy_rr * risk;
      req.reason = "CCI_FVG_SHORT";
     }

   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
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

   if(StrategyOpenPositionCount() > 0)
      return false;
   if(!StrategySpreadAllowsEntry())
      return false;

   const double close1 = StrategyClose(1);
   const double ema = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, 1);
   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double cci = QM_CCI(_Symbol, strategy_timeframe, strategy_cci_period, 1);
   if(close1 <= 0.0 || ema <= 0.0 || atr <= 0.0)
      return false;

   if(close1 > ema && cci < 200.0 && StrategyCciCrossed(true))
     {
      StrategyFvg fvg;
      if(StrategyFindFvg(true, atr, fvg) && StrategyBuildRequest(true, fvg, atr, req))
         return true;
     }

   if(close1 < ema && cci > -200.0 && StrategyCciCrossed(false))
     {
      StrategyFvg fvg;
      if(StrategyFindFvg(false, atr, fvg) && StrategyBuildRequest(false, fvg, atr, req))
         return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;

      const double initial_risk = is_buy ? (open_price - current_sl) : (current_sl - open_price);
      const double moved = is_buy ? (market - open_price) : (open_price - market);
      if(initial_risk <= 0.0 || moved < initial_risk)
         continue;

      const bool improves = is_buy ? (current_sl < open_price) : (current_sl > open_price);
      if(improves)
         QM_TM_MoveSL(ticket, open_price, "cci_fvg_break_even_1r");
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const double cci = QM_CCI(_Symbol, strategy_timeframe, strategy_cci_period, 1);
   const datetime now = TimeCurrent();
   const int max_hold_seconds = strategy_max_hold_bars * PeriodSeconds(strategy_timeframe);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && cci < 0.0)
         return true;
      if(pos_type == POSITION_TYPE_SELL && cci > 0.0)
         return true;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(max_hold_seconds > 0 && opened > 0 && now - opened >= max_hold_seconds)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10992_ftmo-cci-fvg\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
