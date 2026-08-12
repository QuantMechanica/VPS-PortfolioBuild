#property strict
#property version   "5.0"
#property description "QM5_10628 Elite Trader FVG Sweep Fill"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10628;
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
input int    strategy_atr_period              = 14;
input int    strategy_h4_swing_lookback       = 60;
input int    strategy_d1_swing_lookback       = 15;
input double strategy_sweep_depth_atr         = 0.20;
input int    strategy_sweep_reclaim_bars      = 3;
input int    strategy_displacement_window     = 8;
input double strategy_displacement_body_atr   = 1.20;
input double strategy_displacement_close_pct  = 0.25;
input double strategy_fvg_min_width_atr       = 0.15;
input double strategy_fvg_max_width_atr       = 1.20;
input double strategy_fvg_fill_level          = 0.50;
input double strategy_max_spread_width_frac   = 0.20;
input double strategy_max_fvg_level_atr       = 1.50;
input int    strategy_pending_bars            = 6;
input int    strategy_m15_swing_lookback      = 20;
input int    strategy_time_exit_bars          = 24;
input double strategy_rr_cap                  = 2.00;

#define STRATEGY_STATE_VERSION  2
#define STRATEGY_MAX_CATCHUP    64

enum StrategyPhase
  {
   STRATEGY_WAIT_LIQUIDITY = 0,
   STRATEGY_WAIT_RECLAIM,
   STRATEGY_WAIT_DISPLACEMENT,
   STRATEGY_FVG_READY,
   STRATEGY_WAIT_MITIGATION,
   STRATEGY_POSITION_LIVE
  };

static StrategyPhase g_phase             = STRATEGY_WAIT_LIQUIDITY;
static int           g_setup_side        = 0;       // +1 long, -1 short
static datetime      g_pool_time         = 0;
static uint          g_pool_hash         = 0;
static double        g_pool_level        = 0.0;
static datetime      g_penetration_time  = 0;
static double        g_sweep_extreme     = 0.0;
static double        g_sweep_atr         = 0.0;
static datetime      g_reclaim_time      = 0;
static datetime      g_fvg_time          = 0;
static double        g_fvg_low           = 0.0;
static double        g_fvg_high          = 0.0;
static double        g_entry_price       = 0.0;
static double        g_stop_price        = 0.0;
static double        g_target_price      = 0.0;
static datetime      g_pending_bar       = 0;
static datetime      g_consumed_time     = 0;
static datetime      g_last_processed_bar = 0;
static bool          g_submission_claimed = false;

bool Strategy_IsTester()
  {
   return ((bool)MQLInfoInteger(MQL_TESTER));
  }

double Strategy_TickSize()
  {
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return tick;
  }

// mode -1=floor, 0=nearest, +1=ceil. NormalizeDouble is applied only after
// the value is on the broker's tick grid.
double Strategy_ToTick(const double value, const int mode)
  {
   const double tick = Strategy_TickSize();
   if(value <= 0.0 || tick <= 0.0)
      return 0.0;

   const double units = value / tick;
   double rounded = MathRound(units);
   if(mode < 0)
      rounded = MathFloor(units + 1.0e-10);
   else if(mode > 0)
      rounded = MathCeil(units - 1.0e-10);
   return NormalizeDouble(rounded * tick, _Digits);
  }

datetime Strategy_BarTime(const int shift)
  {
   return iTime(_Symbol, PERIOD_M15, shift); // perf-allowed
  }

int Strategy_ClosedBarsBetween(const datetime earlier_bar,
                               const datetime later_bar)
  {
   if(earlier_bar <= 0 || later_bar <= 0 || later_bar < earlier_bar)
      return -1;
   const int earlier_shift = iBarShift(_Symbol, PERIOD_M15, earlier_bar, true);
   const int later_shift = iBarShift(_Symbol, PERIOD_M15, later_bar, true);
   if(earlier_shift < 0 || later_shift < 0 || earlier_shift < later_shift)
      return -1;
   return earlier_shift - later_shift;
  }

int Strategy_ClosedBarsSinceTime(const datetime event_time)
  {
   if(event_time <= 0)
      return -1;
   return iBarShift(_Symbol, PERIOD_M15, event_time, false);
  }

void Strategy_ResetSetup()
  {
   g_phase = STRATEGY_WAIT_LIQUIDITY;
   g_setup_side = 0;
   g_pool_time = 0;
   g_pool_hash = 0;
   g_pool_level = 0.0;
   g_penetration_time = 0;
   g_sweep_extreme = 0.0;
   g_sweep_atr = 0.0;
   g_reclaim_time = 0;
   g_fvg_time = 0;
   g_fvg_low = 0.0;
   g_fvg_high = 0.0;
   g_entry_price = 0.0;
   g_stop_price = 0.0;
   g_target_price = 0.0;
   g_pending_bar = 0;
   g_submission_claimed = false;
  }

bool Strategy_ValidateInputs()
  {
   if(qm_ea_id != 10628 || _Period != PERIOD_M15)
      return false;
   if(strategy_atr_period < 2 || strategy_h4_swing_lookback < 3 || strategy_d1_swing_lookback < 3)
      return false;
   if(strategy_sweep_depth_atr <= 0.0 || strategy_sweep_reclaim_bars < 1)
      return false;
   if(strategy_displacement_window < 1 || strategy_displacement_body_atr <= 0.0)
      return false;
   if(strategy_displacement_close_pct <= 0.0 || strategy_displacement_close_pct > 0.50)
      return false;
   if(strategy_fvg_min_width_atr <= 0.0 || strategy_fvg_max_width_atr < strategy_fvg_min_width_atr)
      return false;
   if(strategy_fvg_fill_level <= 0.0 || strategy_fvg_fill_level >= 1.0)
      return false;
   if(strategy_max_spread_width_frac <= 0.0 || strategy_max_fvg_level_atr <= 0.0)
      return false;
   if(strategy_pending_bars < 1 || strategy_m15_swing_lookback < 3 || strategy_time_exit_bars < 1)
      return false;
   if(strategy_rr_cap <= 0.0 || Strategy_TickSize() <= 0.0)
      return false;
   return true;
  }

string Strategy_StatePrefix()
  {
   return StringFormat("Q10628.%I64d.%d.%s.",
                       (long)AccountInfoInteger(ACCOUNT_LOGIN),
                       QM_FrameworkMagic(),
                       _Symbol);
  }

string Strategy_StateKey(const string field)
  {
   return Strategy_StatePrefix() + field;
  }

bool Strategy_WriteStateValue(const string field, const double value)
  {
   return (GlobalVariableSet(Strategy_StateKey(field), value) != 0);
  }

bool Strategy_ReadStateValue(const string field, double &value)
  {
   const string key = Strategy_StateKey(field);
   if(!GlobalVariableCheck(key))
      return false;
   value = GlobalVariableGet(key);
   return true;
  }

bool Strategy_PersistState()
  {
   if(Strategy_IsTester())
      return true;

   double previous_generation = 0.0;
   Strategy_ReadStateValue("commit", previous_generation);
   const double generation = MathFloor(previous_generation) + 1.0;
   if(!Strategy_WriteStateValue("begin", generation))
      return false;

   bool ok = true;
   ok = Strategy_WriteStateValue("version", STRATEGY_STATE_VERSION) && ok;
   ok = Strategy_WriteStateValue("phase", (int)g_phase) && ok;
   ok = Strategy_WriteStateValue("side", g_setup_side) && ok;
   ok = Strategy_WriteStateValue("pool_t", (double)g_pool_time) && ok;
   ok = Strategy_WriteStateValue("pool_h", (double)g_pool_hash) && ok;
   ok = Strategy_WriteStateValue("pool_l", g_pool_level) && ok;
   ok = Strategy_WriteStateValue("pen_t", (double)g_penetration_time) && ok;
   ok = Strategy_WriteStateValue("sweep_x", g_sweep_extreme) && ok;
   ok = Strategy_WriteStateValue("sweep_a", g_sweep_atr) && ok;
   ok = Strategy_WriteStateValue("reclaim_t", (double)g_reclaim_time) && ok;
   ok = Strategy_WriteStateValue("fvg_t", (double)g_fvg_time) && ok;
   ok = Strategy_WriteStateValue("fvg_lo", g_fvg_low) && ok;
   ok = Strategy_WriteStateValue("fvg_hi", g_fvg_high) && ok;
   ok = Strategy_WriteStateValue("entry", g_entry_price) && ok;
   ok = Strategy_WriteStateValue("sl", g_stop_price) && ok;
   ok = Strategy_WriteStateValue("tp", g_target_price) && ok;
   ok = Strategy_WriteStateValue("pending_t", (double)g_pending_bar) && ok;
   ok = Strategy_WriteStateValue("consumed_t", (double)g_consumed_time) && ok;
   ok = Strategy_WriteStateValue("last_bar", (double)g_last_processed_bar) && ok;
   GlobalVariablesFlush();
   if(!ok)
      return false;
   if(!Strategy_WriteStateValue("commit", generation))
      return false;
   GlobalVariablesFlush();
   return true;
  }

bool Strategy_StateIsCoherent()
  {
   if((int)g_phase < (int)STRATEGY_WAIT_LIQUIDITY ||
      (int)g_phase > (int)STRATEGY_POSITION_LIVE)
      return false;
   if(g_setup_side < -1 || g_setup_side > 1)
      return false;
   if(g_phase == STRATEGY_WAIT_RECLAIM)
      return (g_setup_side != 0 && g_pool_time > 0 && g_pool_level > 0.0 &&
              g_penetration_time >= g_pool_time && g_sweep_extreme > 0.0 && g_sweep_atr > 0.0);
   if(g_phase == STRATEGY_WAIT_DISPLACEMENT)
      return (g_setup_side != 0 && g_pool_time > 0 && g_pool_level > 0.0 &&
              g_reclaim_time >= g_penetration_time && g_reclaim_time > 0);
   if(g_phase == STRATEGY_FVG_READY || g_phase == STRATEGY_WAIT_MITIGATION ||
      g_phase == STRATEGY_POSITION_LIVE)
      return (g_setup_side != 0 && g_fvg_time > g_reclaim_time &&
              g_fvg_low > 0.0 && g_fvg_high > g_fvg_low &&
              g_entry_price > g_fvg_low && g_entry_price < g_fvg_high &&
              g_stop_price > 0.0 && g_target_price > 0.0);
   return true;
  }

bool Strategy_RestoreState()
  {
   if(Strategy_IsTester())
      return false;

   double begin_value = 0.0;
   double commit_value = 0.0;
   double value = 0.0;
   if(!Strategy_ReadStateValue("begin", begin_value) ||
      !Strategy_ReadStateValue("commit", commit_value) || begin_value != commit_value)
      return false;
   if(!Strategy_ReadStateValue("version", value) || (int)value != STRATEGY_STATE_VERSION)
      return false;

   if(!Strategy_ReadStateValue("phase", value)) return false;
   g_phase = (StrategyPhase)(int)value;
   if(!Strategy_ReadStateValue("side", value)) return false;
   g_setup_side = (int)value;
   if(!Strategy_ReadStateValue("pool_t", value)) return false;
   g_pool_time = (datetime)(long)value;
   if(!Strategy_ReadStateValue("pool_h", value)) return false;
   g_pool_hash = (uint)value;
   if(!Strategy_ReadStateValue("pool_l", g_pool_level)) return false;
   if(!Strategy_ReadStateValue("pen_t", value)) return false;
   g_penetration_time = (datetime)(long)value;
   if(!Strategy_ReadStateValue("sweep_x", g_sweep_extreme)) return false;
   if(!Strategy_ReadStateValue("sweep_a", g_sweep_atr)) return false;
   if(!Strategy_ReadStateValue("reclaim_t", value)) return false;
   g_reclaim_time = (datetime)(long)value;
   if(!Strategy_ReadStateValue("fvg_t", value)) return false;
   g_fvg_time = (datetime)(long)value;
   if(!Strategy_ReadStateValue("fvg_lo", g_fvg_low)) return false;
   if(!Strategy_ReadStateValue("fvg_hi", g_fvg_high)) return false;
   if(!Strategy_ReadStateValue("entry", g_entry_price)) return false;
   if(!Strategy_ReadStateValue("sl", g_stop_price)) return false;
   if(!Strategy_ReadStateValue("tp", g_target_price)) return false;
   if(!Strategy_ReadStateValue("pending_t", value)) return false;
   g_pending_bar = (datetime)(long)value;
   if(!Strategy_ReadStateValue("consumed_t", value)) return false;
   g_consumed_time = (datetime)(long)value;
   if(!Strategy_ReadStateValue("last_bar", value)) return false;
   g_last_processed_bar = (datetime)(long)value;
   g_submission_claimed = false;
   return Strategy_StateIsCoherent();
  }

bool Strategy_ParseSetupComment(const string comment,
                                int &side,
                                datetime &fvg_time)
  {
   side = 0;
   fvg_time = 0;
   if(StringFind(comment, "Q10628L_") == 0)
      side = 1;
   else if(StringFind(comment, "Q10628S_") == 0)
      side = -1;
   else
      return false;

   fvg_time = (datetime)StringToInteger(StringSubstr(comment, 8));
   return (fvg_time > 0);
  }

string Strategy_SetupComment()
  {
   const string side_code = (g_setup_side > 0) ? "L" : "S";
   return StringFormat("Q10628%s_%I64d", side_code, (long)g_fvg_time);
  }

bool Strategy_FindOwnPosition(ulong &ticket)
  {
   ticket = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = candidate;
      return true;
     }
   return false;
  }

bool Strategy_FindOwnPending(ulong &ticket)
  {
   ticket = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = OrderGetTicket(i);
      if(candidate == 0 || !OrderSelect(candidate))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type != ORDER_TYPE_BUY_LIMIT && type != ORDER_TYPE_SELL_LIMIT)
         continue;
      ticket = candidate;
      return true;
     }
   return false;
  }

bool Strategy_RecoverFvgGeometry(const int side, const datetime fvg_time)
  {
   const int shift = iBarShift(_Symbol, PERIOD_M15, fvg_time, true);
   if(shift < 1)
      return false;

   double low_edge = 0.0;
   double high_edge = 0.0;
   if(side > 0)
     {
      low_edge = iHigh(_Symbol, PERIOD_M15, shift + 2); // perf-allowed
      high_edge = iLow(_Symbol, PERIOD_M15, shift); // perf-allowed
     }
   else
     {
      low_edge = iHigh(_Symbol, PERIOD_M15, shift); // perf-allowed
      high_edge = iLow(_Symbol, PERIOD_M15, shift + 2); // perf-allowed
     }
   if(low_edge <= 0.0 || high_edge <= low_edge)
      return false;

   g_fvg_time = fvg_time;
   g_fvg_low = low_edge;
   g_fvg_high = high_edge;
   g_entry_price = Strategy_ToTick(low_edge + (high_edge - low_edge) * strategy_fvg_fill_level, 0);
   return (g_entry_price > low_edge && g_entry_price < high_edge);
  }

void Strategy_RecoverConsumedFromHistory()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || !HistorySelect(0, TimeCurrent()))
      return;

   for(int i = HistoryOrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = HistoryOrderGetTicket(i);
      if(ticket == 0 || HistoryOrderGetString(ticket, ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryOrderGetInteger(ticket, ORDER_MAGIC) != magic)
         continue;
      int side = 0;
      datetime setup_time = 0;
      if(Strategy_ParseSetupComment(HistoryOrderGetString(ticket, ORDER_COMMENT), side, setup_time))
         g_consumed_time = (datetime)MathMax((long)g_consumed_time, (long)setup_time);
     }

   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0 || HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic)
         continue;
      int side = 0;
      datetime setup_time = 0;
      if(Strategy_ParseSetupComment(HistoryDealGetString(ticket, DEAL_COMMENT), side, setup_time))
         g_consumed_time = (datetime)MathMax((long)g_consumed_time, (long)setup_time);
     }
  }

void Strategy_RecoverExposureLifecycle()
  {
   ulong ticket = 0;
   if(Strategy_FindOwnPosition(ticket) && PositionSelectByTicket(ticket))
     {
      int parsed_side = 0;
      datetime parsed_time = 0;
      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const int actual_side = (type == POSITION_TYPE_BUY) ? 1 : -1;
      if(Strategy_ParseSetupComment(PositionGetString(POSITION_COMMENT), parsed_side, parsed_time) &&
         (g_fvg_time <= 0 || g_fvg_low <= 0.0 || g_fvg_high <= g_fvg_low))
         Strategy_RecoverFvgGeometry(parsed_side, parsed_time);
      g_setup_side = actual_side;
      g_stop_price = PositionGetDouble(POSITION_SL);
      g_target_price = PositionGetDouble(POSITION_TP);
      g_phase = STRATEGY_POSITION_LIVE;
      g_pending_bar = 0;
      if(parsed_time > 0)
         g_consumed_time = (datetime)MathMax((long)g_consumed_time, (long)parsed_time);
      return;
     }

   if(Strategy_FindOwnPending(ticket) && OrderSelect(ticket))
     {
      int parsed_side = 0;
      datetime parsed_time = 0;
      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      const int actual_side = (type == ORDER_TYPE_BUY_LIMIT) ? 1 : -1;
      if(Strategy_ParseSetupComment(OrderGetString(ORDER_COMMENT), parsed_side, parsed_time) &&
         (g_fvg_time <= 0 || g_fvg_low <= 0.0 || g_fvg_high <= g_fvg_low))
         Strategy_RecoverFvgGeometry(parsed_side, parsed_time);
      g_setup_side = actual_side;
      g_entry_price = OrderGetDouble(ORDER_PRICE_OPEN);
      g_stop_price = OrderGetDouble(ORDER_SL);
      g_target_price = OrderGetDouble(ORDER_TP);
      g_pending_bar = (parsed_time > 0) ? parsed_time : (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      g_phase = STRATEGY_WAIT_MITIGATION;
      if(parsed_time > 0)
         g_consumed_time = (datetime)MathMax((long)g_consumed_time, (long)parsed_time);
      return;
     }

   if(g_phase == STRATEGY_WAIT_MITIGATION || g_phase == STRATEGY_POSITION_LIVE)
      Strategy_ResetSetup();
  }

string Strategy_ClaimKey()
  {
   return Strategy_StatePrefix() + StringFormat("claim.%I64d.%u", (long)g_fvg_time, g_pool_hash);
  }

bool Strategy_ClaimSetup()
  {
   if(g_fvg_time <= 0 || g_fvg_time <= g_consumed_time)
      return false;

   g_consumed_time = g_fvg_time;
   if(Strategy_IsTester())
      return true;

   const string key = Strategy_ClaimKey();
   if(GlobalVariableCheck(key))
      return false;
   if(GlobalVariableSet(key, 0.0) == 0)
      return false;
   if(!GlobalVariableSetOnCondition(key, 1.0, 0.0))
      return false;
   GlobalVariablesFlush();
   return Strategy_PersistState();
  }

uint Strategy_HashText(uint hash, const string text)
  {
   for(int i = 0; i < StringLen(text); ++i)
     {
      hash ^= (uint)StringGetCharacter(text, i);
      hash *= 16777619;
     }
   return hash;
  }

bool Strategy_AddUniqueLevel(double &levels[], int &count, const double value)
  {
   const double tick = Strategy_TickSize();
   if(value <= 0.0 || tick <= 0.0 || count >= ArraySize(levels))
      return false;
   for(int i = 0; i < count; ++i)
      if(MathAbs(levels[i] - value) <= tick * 2.0)
         return false;
   levels[count++] = value;
   return true;
  }

// Build the pool relative to the sweep event, not relative to "now". Starting
// at containing_shift+2 guarantees both neighbours of every pivot were closed
// before event_time. Once a level is swept, only the frozen scalar/hash remain.
bool Strategy_BuildFrozenLiquidityPool(const datetime event_time,
                                       double &low_levels[], int &low_count,
                                       double &high_levels[], int &high_count,
                                       uint &pool_hash)
  {
   low_count = 0;
   high_count = 0;
   pool_hash = 2166136261;
   ENUM_TIMEFRAMES frames[2] = { PERIOD_H4, PERIOD_D1 };
   int lookbacks[2] = { strategy_h4_swing_lookback, strategy_d1_swing_lookback };

   for(int f = 0; f < 2; ++f)
     {
      const int event_htf_shift = iBarShift(_Symbol, frames[f], event_time, false);
      const int available = Bars(_Symbol, frames[f]); // perf-allowed
      const int first_pivot = event_htf_shift + 2;
      const int final_pivot = MathMin(first_pivot + lookbacks[f] - 1, available - 2);
      if(event_htf_shift < 0 || final_pivot < first_pivot)
         continue;

      for(int shift = first_pivot; shift <= final_pivot; ++shift)
        {
         const double high = iHigh(_Symbol, frames[f], shift); // perf-allowed
         const double high_older = iHigh(_Symbol, frames[f], shift + 1); // perf-allowed
         const double high_newer = iHigh(_Symbol, frames[f], shift - 1); // perf-allowed
         if(high > 0.0 && high > high_older && high > high_newer &&
            Strategy_AddUniqueLevel(high_levels, high_count, high))
            pool_hash = Strategy_HashText(pool_hash,
                         StringFormat("H%d:%I64d:%s", f, (long)iTime(_Symbol, frames[f], shift), DoubleToString(high, _Digits))); // perf-allowed

         const double low = iLow(_Symbol, frames[f], shift); // perf-allowed
         const double low_older = iLow(_Symbol, frames[f], shift + 1); // perf-allowed
         const double low_newer = iLow(_Symbol, frames[f], shift - 1); // perf-allowed
         if(low > 0.0 && low < low_older && low < low_newer &&
            Strategy_AddUniqueLevel(low_levels, low_count, low))
            pool_hash = Strategy_HashText(pool_hash,
                         StringFormat("L%d:%I64d:%s", f, (long)iTime(_Symbol, frames[f], shift), DoubleToString(low, _Digits))); // perf-allowed
        }
     }
   return (low_count > 0 || high_count > 0);
  }

bool Strategy_DetectAndFreezeSweep(const int bar_shift)
  {
   const datetime event_time = Strategy_BarTime(bar_shift);
   const double open = iOpen(_Symbol, PERIOD_M15, bar_shift); // perf-allowed
   const double high = iHigh(_Symbol, PERIOD_M15, bar_shift); // perf-allowed
   const double low = iLow(_Symbol, PERIOD_M15, bar_shift); // perf-allowed
   const double close = iClose(_Symbol, PERIOD_M15, bar_shift); // perf-allowed
   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, bar_shift);
   if(event_time <= 0 || open <= 0.0 || high <= low || close <= 0.0 || atr <= 0.0)
      return false;

   double low_levels[128];
   double high_levels[128];
   int low_count = 0;
   int high_count = 0;
   uint pool_hash = 0;
   if(!Strategy_BuildFrozenLiquidityPool(event_time,
                                         low_levels, low_count,
                                         high_levels, high_count,
                                         pool_hash))
      return false;

   const double required_depth = strategy_sweep_depth_atr * atr;
   bool swept_low = false;
   bool swept_high = false;
   double selected_low = 0.0;
   double selected_high = 0.0;
   double best_low_distance = DBL_MAX;
   double best_high_distance = DBL_MAX;

   for(int i = 0; i < low_count; ++i)
     {
      if(low > low_levels[i] - required_depth)
         continue;
      const double distance = MathAbs(open - low_levels[i]);
      if(distance < best_low_distance ||
         (distance == best_low_distance && low_levels[i] > selected_low))
        {
         swept_low = true;
         selected_low = low_levels[i];
         best_low_distance = distance;
        }
     }

   for(int i = 0; i < high_count; ++i)
     {
      if(high < high_levels[i] + required_depth)
         continue;
      const double distance = MathAbs(open - high_levels[i]);
      if(distance < best_high_distance ||
         (distance == best_high_distance && (selected_high <= 0.0 || high_levels[i] < selected_high)))
        {
         swept_high = true;
         selected_high = high_levels[i];
         best_high_distance = distance;
        }
     }

   // A bar that raids both sides has no deterministic directional state.
   if(swept_low == swept_high)
      return false;

   g_pool_time = event_time;
   g_pool_hash = pool_hash;
   g_penetration_time = event_time;
   g_sweep_atr = atr;
   if(swept_low)
     {
      g_setup_side = 1;
      g_pool_level = selected_low;
      g_sweep_extreme = low;
      if(close > g_pool_level)
        {
         g_reclaim_time = event_time;
         g_phase = STRATEGY_WAIT_DISPLACEMENT;
        }
      else
         g_phase = STRATEGY_WAIT_RECLAIM;
     }
   else
     {
      g_setup_side = -1;
      g_pool_level = selected_high;
      g_sweep_extreme = high;
      if(close < g_pool_level)
        {
         g_reclaim_time = event_time;
         g_phase = STRATEGY_WAIT_DISPLACEMENT;
        }
      else
         g_phase = STRATEGY_WAIT_RECLAIM;
     }
   return true;
  }

void Strategy_ProcessReclaim(const int bar_shift)
  {
   const datetime event_time = Strategy_BarTime(bar_shift);
   const int elapsed = Strategy_ClosedBarsBetween(g_penetration_time, event_time);
   if(elapsed < 0 || elapsed > strategy_sweep_reclaim_bars)
     {
      Strategy_ResetSetup();
      Strategy_DetectAndFreezeSweep(bar_shift);
      return;
     }

   const double high = iHigh(_Symbol, PERIOD_M15, bar_shift); // perf-allowed
   const double low = iLow(_Symbol, PERIOD_M15, bar_shift); // perf-allowed
   const double close = iClose(_Symbol, PERIOD_M15, bar_shift); // perf-allowed
   if(g_setup_side > 0)
     {
      if(low > 0.0)
         g_sweep_extreme = MathMin(g_sweep_extreme, low);
      if(close > g_pool_level)
        {
         g_reclaim_time = event_time;
         g_phase = STRATEGY_WAIT_DISPLACEMENT;
        }
     }
   else
     {
      if(high > 0.0)
         g_sweep_extreme = MathMax(g_sweep_extreme, high);
      if(close < g_pool_level)
        {
         g_reclaim_time = event_time;
         g_phase = STRATEGY_WAIT_DISPLACEMENT;
        }
     }
  }

double Strategy_FindOpposingTarget(const int bar_shift, const double entry)
  {
   double target = 0.0;
   const int first_pivot = bar_shift + 2;
   const int final_pivot = first_pivot + strategy_m15_swing_lookback - 1;
   for(int shift = first_pivot; shift <= final_pivot; ++shift)
     {
      if(g_setup_side > 0)
        {
         const double high = iHigh(_Symbol, PERIOD_M15, shift); // perf-allowed
         const double high_older = iHigh(_Symbol, PERIOD_M15, shift + 1); // perf-allowed
         const double high_newer = iHigh(_Symbol, PERIOD_M15, shift - 1); // perf-allowed
         if(high > entry && high > high_older && high > high_newer &&
            (target <= 0.0 || high < target))
            target = high;
        }
      else
        {
         const double low = iLow(_Symbol, PERIOD_M15, shift); // perf-allowed
         const double low_older = iLow(_Symbol, PERIOD_M15, shift + 1); // perf-allowed
         const double low_newer = iLow(_Symbol, PERIOD_M15, shift - 1); // perf-allowed
         if(low > 0.0 && low < entry && low < low_older && low < low_newer &&
            (target <= 0.0 || low > target))
            target = low;
        }
     }
   return target;
  }

bool Strategy_FreezeOrderGeometry(const int bar_shift)
  {
   const double raw_entry = g_fvg_low + (g_fvg_high - g_fvg_low) * strategy_fvg_fill_level;
   const double opposing = Strategy_FindOpposingTarget(bar_shift, raw_entry);
   if(g_setup_side > 0)
     {
      g_entry_price = Strategy_ToTick(raw_entry, 0);
      g_stop_price = Strategy_ToTick(g_sweep_extreme - strategy_sweep_depth_atr * g_sweep_atr, -1);
      if(g_entry_price <= 0.0 || g_stop_price <= 0.0 || g_stop_price >= g_entry_price)
         return false;
      const double rr_target = g_entry_price + (g_entry_price - g_stop_price) * strategy_rr_cap;
      const double raw_target = (opposing > g_entry_price) ? MathMin(opposing, rr_target) : rr_target;
      g_target_price = Strategy_ToTick(raw_target, -1);
      return (g_target_price > g_entry_price);
     }

   g_entry_price = Strategy_ToTick(raw_entry, 0);
   g_stop_price = Strategy_ToTick(g_sweep_extreme + strategy_sweep_depth_atr * g_sweep_atr, 1);
   if(g_entry_price <= 0.0 || g_stop_price <= g_entry_price)
      return false;
   const double rr_target = g_entry_price - (g_stop_price - g_entry_price) * strategy_rr_cap;
   const double raw_target = (opposing > 0.0 && opposing < g_entry_price) ? MathMax(opposing, rr_target) : rr_target;
   g_target_price = Strategy_ToTick(raw_target, 1);
   return (g_target_price > 0.0 && g_target_price < g_entry_price);
  }

// The displacement candle is bar_shift+1 and must be strictly later than the
// reclaim. The FVG completes on bar_shift, one still-later closed bar.
bool Strategy_DetectAndFreezeFvg(const int bar_shift)
  {
   const int displacement_shift = bar_shift + 1;
   const int older_shift = bar_shift + 2;
   const datetime fvg_time = Strategy_BarTime(bar_shift);
   const datetime displacement_time = Strategy_BarTime(displacement_shift);
   if(fvg_time <= displacement_time || displacement_time <= g_reclaim_time)
      return false;

   const int displacement_after_reclaim = Strategy_ClosedBarsBetween(g_reclaim_time,
                                                                      displacement_time);
   if(displacement_after_reclaim < 1 ||
      displacement_after_reclaim > strategy_displacement_window)
      return false;

   const double open_b = iOpen(_Symbol, PERIOD_M15, displacement_shift); // perf-allowed
   const double high_b = iHigh(_Symbol, PERIOD_M15, displacement_shift); // perf-allowed
   const double low_b = iLow(_Symbol, PERIOD_M15, displacement_shift); // perf-allowed
   const double close_b = iClose(_Symbol, PERIOD_M15, displacement_shift); // perf-allowed
   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, displacement_shift);
   if(open_b <= 0.0 || high_b <= low_b || close_b <= 0.0 || atr <= 0.0)
      return false;

   const double body = MathAbs(close_b - open_b);
   const double range = high_b - low_b;
   double fvg_low = 0.0;
   double fvg_high = 0.0;

   if(g_setup_side > 0)
     {
      if(close_b <= open_b || body < strategy_displacement_body_atr * atr ||
         (high_b - close_b) > strategy_displacement_close_pct * range)
         return false;
      const double high_older = iHigh(_Symbol, PERIOD_M15, older_shift); // perf-allowed
      const double low_current = iLow(_Symbol, PERIOD_M15, bar_shift); // perf-allowed
      if(high_older <= 0.0 || low_current <= high_older)
         return false;
      fvg_low = high_older;
      fvg_high = low_current;
     }
   else
     {
      if(close_b >= open_b || body < strategy_displacement_body_atr * atr ||
         (close_b - low_b) > strategy_displacement_close_pct * range)
         return false;
      const double high_current = iHigh(_Symbol, PERIOD_M15, bar_shift); // perf-allowed
      const double low_older = iLow(_Symbol, PERIOD_M15, older_shift); // perf-allowed
      if(high_current <= 0.0 || low_older <= high_current)
         return false;
      fvg_low = high_current;
      fvg_high = low_older;
     }

   const double width = fvg_high - fvg_low;
   const double raw_entry = fvg_low + width * strategy_fvg_fill_level;
   if(width < strategy_fvg_min_width_atr * atr ||
      width > strategy_fvg_max_width_atr * atr ||
      MathAbs(raw_entry - g_pool_level) > strategy_max_fvg_level_atr * atr)
      return false;

   g_fvg_time = fvg_time;
   g_fvg_low = fvg_low;
   g_fvg_high = fvg_high;
   if(!Strategy_FreezeOrderGeometry(bar_shift))
     {
      g_fvg_time = 0;
      g_fvg_low = 0.0;
      g_fvg_high = 0.0;
      return false;
     }
   g_phase = STRATEGY_FVG_READY;
   return true;
  }

bool Strategy_PreparePendingRequest(QM_EntryRequest &req)
  {
   if(g_phase != STRATEGY_FVG_READY)
      return false;

   MqlTick quote;
   if(!SymbolInfoTick(_Symbol, quote))
      return false;
   const double ask = quote.ask;
   const double bid = quote.bid;
   const double tick = Strategy_TickSize();
   const double width = g_fvg_high - g_fvg_low;
   if(ask <= 0.0 || bid <= 0.0 || tick <= 0.0 || width <= 0.0)
      return false;
   if((ask - bid) > strategy_max_spread_width_frac * width)
      return false;

   // Keep the limit strictly beyond the atomic quote. The order is created
   // only after the FVG bar closed, so any mitigation/fill belongs to a later
   // bar and cannot collapse into the displacement/FVG event.
   if(g_setup_side > 0 && ask < g_entry_price + tick)
      return false;
   if(g_setup_side < 0 && bid > g_entry_price - tick)
      return false;

   req.type = (g_setup_side > 0) ? QM_BUY_LIMIT : QM_SELL_LIMIT;
   req.price = g_entry_price;
   req.sl = g_stop_price;
   req.tp = g_target_price;
   req.reason = Strategy_SetupComment();
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0; // GTC; closed-bar lifecycle cancels it manually.

   // Claim and persist before the framework can send. A crash/reject consumes
   // this exact (FVG time, frozen-pool hash) setup instead of replaying it.
   if(!Strategy_ClaimSetup())
      return false;
   g_submission_claimed = true;
   return true;
  }

void Strategy_ConsumeReadyWithoutEntry()
  {
   if(g_phase != STRATEGY_FVG_READY)
      return;
   Strategy_ClaimSetup();
   Strategy_ResetSetup();
  }

bool Strategy_ProcessClosedBar(const int bar_shift,
                               const bool entry_allowed,
                               QM_EntryRequest &req)
  {
   // One state transition family per closed bar. In particular, a newly
   // detected sweep/reclaim returns immediately and cannot also displace.
   switch(g_phase)
     {
      case STRATEGY_WAIT_LIQUIDITY:
         Strategy_DetectAndFreezeSweep(bar_shift);
         return false;

      case STRATEGY_WAIT_RECLAIM:
         Strategy_ProcessReclaim(bar_shift);
         return false;

      case STRATEGY_WAIT_DISPLACEMENT:
        {
         const datetime event_time = Strategy_BarTime(bar_shift);
         const int elapsed = Strategy_ClosedBarsBetween(g_reclaim_time, event_time);
         if(elapsed < 0)
           {
            Strategy_ResetSetup();
            return false;
           }

         if(Strategy_DetectAndFreezeFvg(bar_shift))
           {
            // Historical catch-up and news-blocked detections are consumed,
            // never submitted late. Only the just-closed bar (shift 1) may arm.
            if(bar_shift != 1 || !entry_allowed)
              {
               Strategy_ConsumeReadyWithoutEntry();
               return false;
              }
            if(Strategy_PreparePendingRequest(req))
               return true;
            Strategy_ConsumeReadyWithoutEntry();
            return false;
           }

         // The last admissible displacement is followed by one FVG-completion
         // bar; retain the state until that completion has been evaluated.
         if(elapsed >= strategy_displacement_window + 1)
           {
            Strategy_ResetSetup();
            Strategy_DetectAndFreezeSweep(bar_shift);
           }
         return false;
        }

      case STRATEGY_FVG_READY:
         // Restart between claim and send is deliberately fail-closed.
         Strategy_ConsumeReadyWithoutEntry();
         return false;

      case STRATEGY_WAIT_MITIGATION:
      case STRATEGY_POSITION_LIVE:
         return false;
     }
   return false;
  }

bool Strategy_EntryNewsAllows(const datetime broker_time)
  {
   if(Strategy_NewsFilterHook(broker_time))
      return false;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      return QM_NewsAllowsTrade2(_Symbol, broker_time,
                                 qm_news_temporal, qm_news_compliance);
   return QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode_legacy);
  }

// Replays only missed closed bars, oldest to newest, with all event-time HTF
// scans anchored to each bar. A long outage skips stale opportunities instead
// of replaying entries; the cap exceeds every pre-entry lifecycle in the card.
bool Strategy_ProcessNewClosedBars(const bool entry_allowed,
                                   QM_EntryRequest &req)
  {
   const datetime newest_closed = Strategy_BarTime(1);
   if(newest_closed <= 0)
      return false;

   if(g_last_processed_bar <= 0)
     {
      g_last_processed_bar = newest_closed;
      Strategy_PersistState();
      return false;
     }

   int previous_shift = iBarShift(_Symbol, PERIOD_M15, g_last_processed_bar, true);
   if(previous_shift < 1)
     {
      if(g_phase != STRATEGY_WAIT_MITIGATION && g_phase != STRATEGY_POSITION_LIVE)
         Strategy_ResetSetup();
      g_last_processed_bar = newest_closed;
      Strategy_PersistState();
      return false;
     }
   if(previous_shift == 1)
      return false;

   int first_shift = previous_shift - 1;
   if(first_shift > STRATEGY_MAX_CATCHUP)
     {
      if(g_phase != STRATEGY_WAIT_MITIGATION && g_phase != STRATEGY_POSITION_LIVE)
         Strategy_ResetSetup();
      first_shift = 1;
     }

   for(int shift = first_shift; shift >= 1; --shift)
     {
      const bool may_enter = (shift == 1 && entry_allowed);
      const bool armed = Strategy_ProcessClosedBar(shift, may_enter, req);
      g_last_processed_bar = Strategy_BarTime(shift);
      if(!Strategy_PersistState())
        {
         // State durability is part of no-reuse. Never send if the claimed
         // state cannot be committed.
         if(armed)
           {
            g_submission_claimed = false;
            Strategy_ResetSetup();
           }
         return false;
        }
      if(armed)
         return true;
     }
   return false;
  }

void Strategy_OnSubmissionResult(const bool sent, const ulong ticket)
  {
   if(!g_submission_claimed)
      return;
   g_submission_claimed = false;
   if(!sent || ticket == 0)
     {
      Strategy_ResetSetup();
      Strategy_PersistState();
      return;
     }
   // A synchronous trade callback may already have observed an immediate fill.
   // Never demote that POSITION_LIVE state back to pending.
   if(g_phase != STRATEGY_POSITION_LIVE)
      g_phase = STRATEGY_WAIT_MITIGATION;
   g_pending_bar = g_fvg_time;
   Strategy_PersistState();
  }

void Strategy_SyncExposureLifecycle()
  {
   const StrategyPhase before = g_phase;
   Strategy_RecoverExposureLifecycle();
   if(g_phase != before)
      Strategy_PersistState();
  }

void Strategy_ManagePendingOrder()
  {
   ulong ticket = 0;
   if(!Strategy_FindOwnPending(ticket) || !OrderSelect(ticket))
      return;

   if(g_fvg_time <= 0 || g_fvg_low <= 0.0 || g_fvg_high <= g_fvg_low)
     {
      int parsed_side = 0;
      datetime parsed_time = 0;
      if(!Strategy_ParseSetupComment(OrderGetString(ORDER_COMMENT), parsed_side, parsed_time) ||
         !Strategy_RecoverFvgGeometry(parsed_side, parsed_time))
        {
         if(QM_TM_RemovePendingOrder(ticket, "state_recovery_failed"))
           {
            Strategy_ResetSetup();
            Strategy_PersistState();
           }
         return;
        }
     }

   const datetime newest_closed = Strategy_BarTime(1);
   const int closed_bars = Strategy_ClosedBarsBetween(g_fvg_time, newest_closed);
   const double close = iClose(_Symbol, PERIOD_M15, 1); // perf-allowed
   if(closed_bars < 0)
     {
      if(QM_TM_RemovePendingOrder(ticket, "bar_history_unavailable"))
        {
         Strategy_ResetSetup();
         Strategy_PersistState();
        }
      return;
     }
   const bool invalidated = (close > 0.0 &&
                             ((g_setup_side > 0 && close < g_fvg_low) ||
                              (g_setup_side < 0 && close > g_fvg_high)));
   const bool expired = (closed_bars >= strategy_pending_bars);
   if(!invalidated && !expired)
      return;

   const string reason = invalidated ? "fvg_invalidated" : "bar_expiry";
   if(QM_TM_RemovePendingOrder(ticket, reason))
     {
      Strategy_ResetSetup();
      Strategy_PersistState();
     }
  }

// Card specifies no trailing, break-even, partial close, or pyramiding.
// Pending expiry/invalidation is nevertheless lifecycle management and must
// continue during news windows.
void Strategy_ManageOpenPosition()
  {
   Strategy_SyncExposureLifecycle();
   Strategy_ManagePendingOrder();
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   if(!Strategy_FindOwnPosition(ticket) || !PositionSelectByTicket(ticket))
      return false;

   const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
   const int closed_bars_held = Strategy_ClosedBarsSinceTime(opened);
   if(closed_bars_held >= strategy_time_exit_bars)
      return true;

   const double close = iClose(_Symbol, PERIOD_M15, 1); // perf-allowed
   if(close <= 0.0 || g_fvg_low <= 0.0 || g_fvg_high <= g_fvg_low)
      return false;
   const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   if(type == POSITION_TYPE_BUY && close < g_fvg_low)
      return true;
   if(type == POSITION_TYPE_SELL && close > g_fvg_high)
      return true;
   return false;
  }

void Strategy_HandleFridayPending()
  {
   if(!QM_FrameworkFridayCloseNow())
      return;

   ulong pending_ticket = 0;
   if(Strategy_FindOwnPending(pending_ticket))
     {
      if(QM_TM_RemovePendingOrder(pending_ticket, "friday_close"))
        {
         Strategy_ResetSetup();
         Strategy_PersistState();
        }
      return;
     }

   ulong position_ticket = 0;
   if(!Strategy_FindOwnPosition(position_ticket) &&
      g_phase != STRATEGY_WAIT_LIQUIDITY)
     {
      Strategy_ResetSetup();
      Strategy_PersistState();
     }
  }

bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Returning true blocks new entries only; management and exits are ordered
// before Strategy_EntryNewsAllows in OnTick.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_LIMIT;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return Strategy_ProcessNewClosedBars(Strategy_EntryNewsAllows(TimeCurrent()), req);
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

   if(!Strategy_ValidateInputs())
     {
      QM_FrameworkShutdown();
      return INIT_PARAMETERS_INCORRECT;
     }

   const bool restored = Strategy_RestoreState();
   if(!restored)
     {
      Strategy_ResetSetup();
      g_consumed_time = 0;
      g_last_processed_bar = Strategy_BarTime(1);
     }
   Strategy_RecoverConsumedFromHistory();
   Strategy_RecoverExposureLifecycle();
   // A durable FVG_READY means the claim was committed before a crash. It may
   // not be sent again after restart.
   if(g_phase == STRATEGY_FVG_READY)
      Strategy_ResetSetup();
   if(g_last_processed_bar <= 0)
      g_last_processed_bar = Strategy_BarTime(1);
   Strategy_PersistState();

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   Strategy_PersistState();
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck())
      return;

   // The framework Friday handler closes positions only; remove this EA's
   // pending order first and retry every tick until confirmed.
   Strategy_HandleFridayPending();
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
            (int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      const bool sent = QM_TM_OpenPosition(req, out_ticket);
      Strategy_OnSubmissionResult(sent, out_ticket);
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
   Strategy_SyncExposureLifecycle();
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
