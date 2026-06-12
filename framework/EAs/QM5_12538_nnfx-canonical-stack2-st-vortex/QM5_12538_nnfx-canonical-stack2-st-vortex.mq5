#property strict
#property version   "5.0"
#property description "QM5_12538 NNFX Stack2 McGinley SuperTrend Vortex"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Strategy implementation for approved card QM5_12538:
// McGinley Dynamic baseline + SuperTrend + Vortex + ADX on closed D1 bars.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12538;
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
input int    strategy_mcginley_period       = 20;
input int    strategy_mcginley_warmup       = 120;
input int    strategy_supertrend_period     = 10;
input double strategy_supertrend_mult       = 3.0;
input int    strategy_supertrend_warmup     = 120;
input int    strategy_vortex_period         = 14;
input int    strategy_adx_period            = 14;
input double strategy_adx_min               = 20.0;
input int    strategy_atr_period            = 14;
input double strategy_atr_proximity_mult    = 1.0;
input double strategy_sl_atr_mult           = 1.5;
input double strategy_tp_half_atr_mult      = 1.0;

int g_cached_exit_dir = 0;

bool Strategy_LoadClosedBars(MqlRates &rates[], const int count)
  {
   if(count <= 0)
      return false;
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, count, rates); // perf-allowed: bounded D1 closed-bar stack read; EntrySignal is called only after framework QM_IsNewBar().
   return (copied >= count);
  }

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = 8;
   return NormalizeDouble(price, digits);
  }

double Strategy_McGinleyValue(const int target_shift)
  {
   if(strategy_mcginley_period < 2 || target_shift < 1)
      return 0.0;

   int warmup = strategy_mcginley_warmup;
   if(warmup < strategy_mcginley_period + 5)
      warmup = strategy_mcginley_period + 5;
   MqlRates rates[];
   const int need = target_shift + warmup + 1;
   if(!Strategy_LoadClosedBars(rates, need))
      return 0.0;

   double md = rates[need - 1].close;
   if(md <= 0.0)
      return 0.0;

   for(int i = need - 2; i >= target_shift - 1; --i)
     {
      const double price = rates[i].close;
      if(price <= 0.0)
         return 0.0;
      double ratio = price / md;
      if(ratio <= 0.0)
         ratio = 1.0;
      md = md + (price - md) / (strategy_mcginley_period * MathPow(ratio, 4.0));
     }

   return md;
  }

bool Strategy_BaselineRecentCross(const int direction)
  {
   MqlRates rates[];
   if(!Strategy_LoadClosedBars(rates, 5))
      return false;

   for(int shift = 1; shift <= 3; ++shift)
     {
      const double close_now = rates[shift - 1].close;
      const double close_prev = rates[shift].close;
      const double md_now = Strategy_McGinleyValue(shift);
      const double md_prev = Strategy_McGinleyValue(shift + 1);
      if(close_now <= 0.0 || close_prev <= 0.0 || md_now <= 0.0 || md_prev <= 0.0)
         continue;
      if(direction > 0 && close_now > md_now && close_prev <= md_prev)
         return true;
      if(direction < 0 && close_now < md_now && close_prev >= md_prev)
         return true;
     }

   return false;
  }

bool Strategy_ProximityPass(const int direction)
  {
   MqlRates rates[];
   if(!Strategy_LoadClosedBars(rates, 1))
      return false;

   const double close_price = rates[0].close;
   const double baseline = Strategy_McGinleyValue(1);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(close_price <= 0.0 || baseline <= 0.0 || atr <= 0.0)
      return false;
   if(direction > 0 && close_price <= baseline)
      return false;
   if(direction < 0 && close_price >= baseline)
      return false;
   return (MathAbs(close_price - baseline) < atr * strategy_atr_proximity_mult);
  }

bool Strategy_SuperTrendAtShift(const int target_shift, int &dir, double &line)
  {
   dir = 0;
   line = 0.0;
   if(strategy_supertrend_period < 1 || strategy_supertrend_mult <= 0.0 || target_shift < 1)
      return false;

   int warmup = strategy_supertrend_warmup;
   if(warmup < strategy_supertrend_period + 5)
      warmup = strategy_supertrend_period + 5;
   const int oldest = target_shift + warmup;
   double prev_upper = 0.0;
   double prev_lower = 0.0;
   int prev_dir = 0;

   for(int shift = oldest; shift >= target_shift; --shift)
     {
      const double high = iHigh(_Symbol, PERIOD_D1, shift);       // perf-allowed: bespoke SuperTrend recurrence on framework closed-bar path.
      const double low = iLow(_Symbol, PERIOD_D1, shift);         // perf-allowed: bespoke SuperTrend recurrence on framework closed-bar path.
      const double close = iClose(_Symbol, PERIOD_D1, shift);     // perf-allowed: bespoke SuperTrend recurrence on framework closed-bar path.
      const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_supertrend_period, shift);
      if(high <= 0.0 || low <= 0.0 || close <= 0.0 || atr <= 0.0)
         return false;

      const double hl2 = (high + low) * 0.5;
      const double basic_upper = hl2 + strategy_supertrend_mult * atr;
      const double basic_lower = hl2 - strategy_supertrend_mult * atr;

      if(shift == oldest)
        {
         prev_upper = basic_upper;
         prev_lower = basic_lower;
         prev_dir = (close >= hl2) ? 1 : -1;
        }
      else
        {
         const double prev_close = iClose(_Symbol, PERIOD_D1, shift + 1); // perf-allowed: bespoke SuperTrend recurrence on framework closed-bar path.
         if(prev_close <= 0.0)
            return false;

         const double upper = (basic_upper < prev_upper || prev_close > prev_upper) ? basic_upper : prev_upper;
         const double lower = (basic_lower > prev_lower || prev_close < prev_lower) ? basic_lower : prev_lower;

         int current_dir = prev_dir;
         if(prev_dir < 0 && close > upper)
            current_dir = 1;
         else if(prev_dir > 0 && close < lower)
            current_dir = -1;

         prev_upper = upper;
         prev_lower = lower;
         prev_dir = current_dir;
        }
     }

   dir = prev_dir;
   line = Strategy_NormalizePrice((dir > 0) ? prev_lower : prev_upper);
   return (dir != 0 && line > 0.0);
  }

int Strategy_SuperTrendSignal()
  {
   int dir = 0;
   double line = 0.0;
   if(!Strategy_SuperTrendAtShift(1, dir, line))
      return 0;
   return dir;
  }

bool Strategy_VortexValues(const int period,
                           const int shift,
                           MqlRates &rates[],
                           double &out_plus,
                           double &out_minus)
  {
   out_plus = 0.0;
   out_minus = 0.0;
   if(period <= 1 || shift < 1)
      return false;

   double vm_plus = 0.0;
   double vm_minus = 0.0;
   double true_range = 0.0;
   for(int i = shift; i < shift + period; ++i)
     {
      const double high_now = rates[i].high;
      const double low_now = rates[i].low;
      const double high_prev = rates[i + 1].high;
      const double low_prev = rates[i + 1].low;
      const double close_prev = rates[i + 1].close;

      vm_plus += MathAbs(high_now - low_prev);
      vm_minus += MathAbs(low_now - high_prev);

      const double range_hl = high_now - low_now;
      const double range_hc = MathAbs(high_now - close_prev);
      const double range_lc = MathAbs(low_now - close_prev);
      true_range += MathMax(range_hl, MathMax(range_hc, range_lc));
     }

   if(true_range <= 0.0)
      return false;

   out_plus = vm_plus / true_range;
   out_minus = vm_minus / true_range;
   return true;
  }

int Strategy_VortexSignal()
  {
   MqlRates rates[];
   const int period = (strategy_vortex_period < 2) ? 2 : strategy_vortex_period;
   if(!Strategy_LoadClosedBars(rates, period + 2))
      return 0;

   double plus = 0.0;
   double minus = 0.0;
   if(!Strategy_VortexValues(period, 1, rates, plus, minus))
      return 0;
   if(plus > minus)
      return 1;
   if(minus > plus)
      return -1;
   return 0;
  }

int Strategy_ADXSignal()
  {
   const double adx_1 = QM_ADX(_Symbol, PERIOD_D1, strategy_adx_period, 1);
   const double adx_2 = QM_ADX(_Symbol, PERIOD_D1, strategy_adx_period, 2);
   if(adx_1 <= 0.0 || adx_2 <= 0.0)
      return 0;
   return (adx_1 >= strategy_adx_min && adx_1 > adx_2) ? 1 : 0;
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }

   return false;
  }

int Strategy_PositionDirection()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         return 1;
      if(ptype == POSITION_TYPE_SELL)
         return -1;
     }

   return 0;
  }

void Strategy_UpdateExitCache()
  {
   g_cached_exit_dir = 0;
   const int pos_dir = Strategy_PositionDirection();
   if(pos_dir == 0)
      return;

   MqlRates rates[];
   if(!Strategy_LoadClosedBars(rates, 2))
      return;

   const double close_now = rates[0].close;
   const double close_prev = rates[1].close;
   const double md_now = Strategy_McGinleyValue(1);
   const double md_prev = Strategy_McGinleyValue(2);
   const int st_dir = Strategy_SuperTrendSignal();
   if(close_now <= 0.0 || close_prev <= 0.0 || md_now <= 0.0 || md_prev <= 0.0 || st_dir == 0)
      return;

   if(pos_dir > 0)
     {
      if(st_dir < 0 || (close_now < md_now && close_prev >= md_prev))
         g_cached_exit_dir = 1;
     }
   else if(pos_dir < 0)
     {
      if(st_dir > 0 || (close_now > md_now && close_prev <= md_prev))
         g_cached_exit_dir = -1;
     }
  }

bool Strategy_NoTradeFilter()
  {
   return (_Period != PERIOD_D1);
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

   Strategy_UpdateExitCache();
   if(Strategy_HasOpenPosition())
      return false;
   if(strategy_atr_period < 1 || strategy_mcginley_period < 2 || strategy_supertrend_period < 1 ||
      strategy_vortex_period < 2 || strategy_adx_period < 1)
      return false;

   const int supertrend = Strategy_SuperTrendSignal();
   const int vortex = Strategy_VortexSignal();
   const int adx = Strategy_ADXSignal();

   int direction = 0;
   if(Strategy_BaselineRecentCross(1) && Strategy_ProximityPass(1) &&
      supertrend > 0 && vortex > 0 && adx > 0)
      direction = 1;
   else if(Strategy_BaselineRecentCross(-1) && Strategy_ProximityPass(-1) &&
           supertrend < 0 && vortex < 0 && adx > 0)
      direction = -1;
   else
      return false;

   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr, strategy_sl_atr_mult);
   req.tp = 0.0;
   req.reason = (direction > 0) ? "NNFX_STACK2_LONG" : "NNFX_STACK2_SHORT";
   return (req.sl > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || price <= 0.0 || volume <= 0.0)
         continue;

      const double trigger = is_buy ? (open_price + atr * strategy_tp_half_atr_mult)
                                    : (open_price - atr * strategy_tp_half_atr_mult);
      const bool hit_trigger = is_buy ? (price >= trigger) : (price <= trigger);
      const bool sl_not_breakeven = (current_sl <= 0.0) ||
                                    (is_buy ? (current_sl < open_price) : (current_sl > open_price));
      if(!hit_trigger || !sl_not_breakeven)
         continue;

      const double half_lots = QM_TM_NormalizeVolume(_Symbol, volume * 0.5);
      if(half_lots > 0.0 && half_lots < volume && QM_TM_PartialClose(ticket, half_lots, QM_EXIT_PARTIAL))
        {
         const double be = QM_TM_NormalizePrice(_Symbol, open_price);
         QM_TM_MoveSL(ticket, be, "nnfx_stack2_tp_half_move_runner_be");
        }
     }
  }

bool Strategy_ExitSignal()
  {
   const int pos_dir = Strategy_PositionDirection();
   if(pos_dir == 0 || g_cached_exit_dir == 0)
      return false;
   return (pos_dir == g_cached_exit_dir);
  }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12538\",\"ea\":\"QM5_12538_nnfx_canonical_stack2_st_vortex\"}");
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
      g_cached_exit_dir = 0;
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
