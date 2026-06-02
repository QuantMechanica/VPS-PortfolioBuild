#property strict
#property version   "5.0"
#property description "QM5_10126_v2 Carver SMA Crossover Volatility Stop — V2 rebuild"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10126;
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
input ENUM_TIMEFRAMES strategy_timeframe       = PERIOD_D1;
input int             strategy_fast_sma_period = 16;
input int             strategy_slow_sma_period = 64;
input int             strategy_vol_lookback    = 252;
input double          strategy_vol_stop_mult   = 0.50;
input bool            strategy_enable_shorts   = true;
input bool            strategy_reentry_skip    = true;

bool Strategy_NoTradeFilter() { return false; }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY; req.price = 0.0; req.sl = 0.0; req.tp = 0.0;
   req.reason = ""; req.symbol_slot = qm_magic_slot_offset; req.expiration_seconds = 0;

   if(strategy_fast_sma_period <= 0 || strategy_slow_sma_period <= 0 ||
      strategy_fast_sma_period >= strategy_slow_sma_period ||
      strategy_vol_lookback < 2 || strategy_vol_stop_mult <= 0.0)
      return false;

   const int bars_required = MathMax(strategy_vol_lookback + 5, strategy_slow_sma_period + 5);
   if(Bars(_Symbol, strategy_timeframe) < bars_required) return false;

   const double fast = QM_SMA(_Symbol, strategy_timeframe, strategy_fast_sma_period, 1);
   const double slow = QM_SMA(_Symbol, strategy_timeframe, strategy_slow_sma_period, 1);
   if(fast <= 0.0 || slow <= 0.0 || fast == slow) return false;

   const int trend = (fast > slow) ? 1 : -1;
   const int magic = QM_FrameworkMagic();
   const string state_prefix = StringFormat("QM5_10126.%s.%d", _Symbol, qm_magic_slot_offset);
   const string gv_had = state_prefix + ".had_position";
   const string gv_dir = state_prefix + ".last_direction";
   const string gv_block_long = state_prefix + ".block_long";
   const string gv_block_short = state_prefix + ".block_short";

   bool have_position = false;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   ulong ticket = 0;
   double current_sl = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      have_position = true;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ticket = t;
      current_sl = PositionGetDouble(POSITION_SL);
      break;
     }

   if(have_position)
     {
      double closes_pos[];
      ArraySetAsSeries(closes_pos, true);
      const int copied_pos = CopyClose(_Symbol, strategy_timeframe, 0, strategy_vol_lookback + 2, closes_pos);
      if(copied_pos >= strategy_vol_lookback + 2)
        {
         double sum_sq_pos = 0.0; int n_pos = 0;
         for(int r = 1; r <= strategy_vol_lookback; ++r)
           {
            if(closes_pos[r] <= 0.0 || closes_pos[r + 1] <= 0.0) continue;
            const double ret = MathLog(closes_pos[r] / closes_pos[r + 1]);
            sum_sq_pos += ret * ret; n_pos++;
           }
         if(n_pos >= strategy_vol_lookback - 5)
           {
            const double annual_vol_pos = MathSqrt(sum_sq_pos / (double)n_pos) * MathSqrt(252.0);
            const double close_last_pos = closes_pos[1];
            double trail_sl = (position_type == POSITION_TYPE_BUY)
                              ? close_last_pos * (1.0 - strategy_vol_stop_mult * annual_vol_pos)
                              : close_last_pos * (1.0 + strategy_vol_stop_mult * annual_vol_pos);
            trail_sl = QM_TM_NormalizePrice(_Symbol, trail_sl);
            if(trail_sl > 0.0 &&
               ((position_type == POSITION_TYPE_BUY && (current_sl <= 0.0 || trail_sl > current_sl)) ||
                (position_type == POSITION_TYPE_SELL && (current_sl <= 0.0 || trail_sl < current_sl))))
               QM_TM_MoveSL(ticket, trail_sl, "CARVER_VOL_TRAIL");
           }
        }
      GlobalVariableSet(gv_had, 1.0);
      GlobalVariableSet(gv_dir, (position_type == POSITION_TYPE_BUY) ? 1.0 : -1.0);
      return false;
     }

   if(GlobalVariableCheck(gv_had) && GlobalVariableGet(gv_had) > 0.5)
     {
      const int last_dir = GlobalVariableCheck(gv_dir) ? (int)GlobalVariableGet(gv_dir) : 0;
      if(last_dir == 1)
        {
         if(trend > 0 && strategy_reentry_skip) GlobalVariableSet(gv_block_long, 1.0);
         if(trend < 0) GlobalVariableSet(gv_block_long, 0.0);
        }
      else if(last_dir == -1)
        {
         if(trend < 0 && strategy_reentry_skip) GlobalVariableSet(gv_block_short, 1.0);
         if(trend > 0) GlobalVariableSet(gv_block_short, 0.0);
        }
      GlobalVariableSet(gv_had, 0.0);
     }

   if(trend < 0) GlobalVariableSet(gv_block_long, 0.0);
   if(trend > 0) GlobalVariableSet(gv_block_short, 0.0);
   if(trend > 0 && strategy_reentry_skip && GlobalVariableCheck(gv_block_long) && GlobalVariableGet(gv_block_long) > 0.5) return false;
   if(trend < 0 && strategy_reentry_skip && GlobalVariableCheck(gv_block_short) && GlobalVariableGet(gv_block_short) > 0.5) return false;
   if(trend < 0 && !strategy_enable_shorts) return false;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, strategy_timeframe, 0, strategy_vol_lookback + 2, closes);
   if(copied < strategy_vol_lookback + 2) return false;

   double sum_sq = 0.0; int n = 0;
   for(int r = 1; r <= strategy_vol_lookback; ++r)
     {
      if(closes[r] <= 0.0 || closes[r + 1] <= 0.0) continue;
      const double ret = MathLog(closes[r] / closes[r + 1]);
      sum_sq += ret * ret; n++;
     }
   if(n < strategy_vol_lookback - 5) return false;

   const double annual_vol = MathSqrt(sum_sq / (double)n) * MathSqrt(252.0);
   const double close_last = closes[1];
   if(annual_vol <= 0.0 || close_last <= 0.0) return false;

   req.type = (trend > 0) ? QM_BUY : QM_SELL;
   req.sl = (trend > 0) ? close_last * (1.0 - strategy_vol_stop_mult * annual_vol)
                        : close_last * (1.0 + strategy_vol_stop_mult * annual_vol);
   req.sl = QM_TM_NormalizePrice(_Symbol, req.sl);
   req.tp = 0.0;
   req.reason = (trend > 0) ? "CARVER_SMA_LONG" : "CARVER_SMA_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const double entry = (trend > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || req.sl <= 0.0) return false;
   if((trend > 0 && req.sl >= entry) || (trend < 0 && req.sl <= entry)) return false;
   return true;
  }

void Strategy_ManageOpenPosition() { }

bool Strategy_ExitSignal()
  {
   const double fast = QM_SMA(_Symbol, strategy_timeframe, strategy_fast_sma_period, 1);
   const double slow = QM_SMA(_Symbol, strategy_timeframe, strategy_slow_sma_period, 1);
   if(fast <= 0.0 || slow <= 0.0 || fast == slow) return false;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pt == POSITION_TYPE_BUY && fast < slow) return true;
      if(pt == POSITION_TYPE_SELL && fast > slow) return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED,
                        PORTFOLIO_WEIGHT, qm_news_mode_legacy, qm_friday_close_enabled,
                        qm_friday_close_hour_broker, 30, 30, qm_news_stale_max_hours,
                        qm_news_min_impact, qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance))
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
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }
   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();
   QM_EntryRequest req;
   if(Strategy_EntrySignal(req)) { ulong t = 0; QM_TM_OpenPosition(req, t); }
  }

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  { QM_FrameworkOnTradeTransaction(trans, request, result); }
double OnTester() { QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
