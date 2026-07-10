#property strict
#property version   "5.0"
#property description "QM5_13108 WTI partial-moment managed time-series momentum S2"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13108 - XTI Managed Time-Series Momentum S2
// -----------------------------------------------------------------------------
// Daily structural commodity state machine from Liu, Lu, and Wang (2021):
//   - base direction = sign of cumulative 30-D1 return
//   - tail overlay = five-D1 upper and lower partial moments
//   - references = separate historical 80th percentiles, no current data
//   - S2 map: both tails flat; LPM-only long; UPM-only short; else momentum
// Runtime inputs are Darwinex-native OHLC, ATR, spread, and framework state.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                      = 13108;
input int    qm_magic_slot_offset          = 0;
input uint   qm_rng_seed                   = 42;

input group "Risk"
input double RISK_PERCENT                  = 0.0;
input double RISK_FIXED                    = 1000.0;
input double PORTFOLIO_WEIGHT              = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours        = 336;
input string qm_news_min_impact             = "high";
input QM_NewsMode qm_news_mode_legacy       = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled        = true;
input int    qm_friday_close_hour_broker    = 21;

input group "Stress"
input double qm_stress_reject_probability   = 0.0;

input group "Strategy"
input int    strategy_momentum_days         = 30;
input int    strategy_partial_moment_days   = 5;
input int    strategy_percentile_history    = 252;
input double strategy_tail_percentile       = 80.0;
input int    strategy_atr_period             = 20;
input double strategy_atr_sl_mult            = 3.0;
input int    strategy_max_hold_days          = 8;
input int    strategy_max_spread_points      = 1500;

int      g_target_state = 0;       // +1 long, -1 short, 0 flat
bool     g_state_valid = false;
datetime g_state_bar_time = 0;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

bool Strategy_ParametersValid()
  {
   if(strategy_momentum_days < 2 || strategy_momentum_days > 250)
      return false;
   if(strategy_partial_moment_days != 5)
      return false;
   if(strategy_percentile_history < 100 || strategy_percentile_history > 1000)
      return false;
   if(strategy_tail_percentile != 80.0)
      return false;
   if(strategy_atr_period <= 1 || strategy_atr_sl_mult <= 0.0)
      return false;
   if(strategy_max_hold_days <= 0 || strategy_max_hold_days > 14)
      return false;
   if(strategy_max_spread_points < 0)
      return false;
   return true;
  }

bool Strategy_LoadClosedCloses(double &closes[])
  {
   const int momentum_required = strategy_momentum_days + 1;
   const int percentile_required = strategy_percentile_history
                                   + strategy_partial_moment_days + 1;
   const int required = MathMax(momentum_required, percentile_required);
   if(required <= 0)
      return false;

   ArrayResize(closes, required);
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, required, closes); // perf-allowed: new-D1 bounded history copy.
   if(copied != required)
      return false;

   for(int i = 0; i < required; ++i)
     {
      if(closes[i] <= 0.0 || !MathIsValidNumber(closes[i]))
         return false;
     }
   return true;
  }

bool Strategy_PartialMoments(const double &closes[],
                             const int base_shift,
                             double &upm,
                             double &lpm)
  {
   upm = 0.0;
   lpm = 0.0;
   if(base_shift < 1 || strategy_partial_moment_days <= 0)
      return false;

   for(int j = 0; j < strategy_partial_moment_days; ++j)
     {
      const int current_index = base_shift + j - 1;
      const int prior_index = current_index + 1;
      if(prior_index >= ArraySize(closes))
         return false;

      const double current_close = closes[current_index];
      const double prior_close = closes[prior_index];
      if(current_close <= 0.0 || prior_close <= 0.0)
         return false;

      const double daily_return = current_close / prior_close - 1.0;
      if(!MathIsValidNumber(daily_return))
         return false;
      const double squared = daily_return * daily_return;
      if(daily_return > 0.0)
         upm += squared;
      else if(daily_return < 0.0)
         lpm += squared;
     }

   upm /= strategy_partial_moment_days;
   lpm /= strategy_partial_moment_days;
   return MathIsValidNumber(upm) && MathIsValidNumber(lpm);
  }

bool Strategy_MomentumReturn(const double &closes[], double &momentum_return)
  {
   momentum_return = 0.0;
   for(int j = 0; j < strategy_momentum_days; ++j)
     {
      if(j + 1 >= ArraySize(closes))
         return false;
      const double daily_return = closes[j] / closes[j + 1] - 1.0;
      if(!MathIsValidNumber(daily_return))
         return false;
      momentum_return += daily_return;
     }
   return MathIsValidNumber(momentum_return);
  }

double Strategy_NearestRankPercentile(double &values[], const double percentile)
  {
   const int count = ArraySize(values);
   if(count <= 0 || percentile <= 0.0 || percentile > 100.0)
      return -1.0;

   ArraySort(values);
   int rank = (int)MathCeil(percentile * count / 100.0) - 1;
   rank = MathMax(0, MathMin(count - 1, rank));
   return values[rank];
  }

bool Strategy_CalculateTarget(int &target_state)
  {
   target_state = 0;
   double closes[];
   if(!Strategy_LoadClosedCloses(closes))
      return false;

   double momentum_return = 0.0;
   double current_upm = 0.0;
   double current_lpm = 0.0;
   if(!Strategy_MomentumReturn(closes, momentum_return))
      return false;
   if(!Strategy_PartialMoments(closes, 1, current_upm, current_lpm))
      return false;

   double historical_upm[];
   double historical_lpm[];
   ArrayResize(historical_upm, strategy_percentile_history);
   ArrayResize(historical_lpm, strategy_percentile_history);
   for(int i = 0; i < strategy_percentile_history; ++i)
     {
      double obs_upm = 0.0;
      double obs_lpm = 0.0;
      // base_shift=2 excludes the current observation; older rolling windows
      // overlap recent returns exactly as in the source's daily construction.
      if(!Strategy_PartialMoments(closes, i + 2, obs_upm, obs_lpm))
         return false;
      historical_upm[i] = obs_upm;
      historical_lpm[i] = obs_lpm;
     }

   const double up_reference = Strategy_NearestRankPercentile(historical_upm,
                                                               strategy_tail_percentile);
   const double low_reference = Strategy_NearestRankPercentile(historical_lpm,
                                                                strategy_tail_percentile);
   if(up_reference <= 0.0 || low_reference <= 0.0 ||
      !MathIsValidNumber(up_reference) || !MathIsValidNumber(low_reference))
      return false;

   const bool up_tail = current_upm >= up_reference;
   const bool low_tail = current_lpm >= low_reference;

   // MTSM-S2 region map from the approved card. Do not substitute S1.
   if(up_tail && low_tail)       // Region 1: close out
      target_state = 0;
   else if(!up_tail && low_tail) // Region 2: long all
      target_state = 1;
   else if(up_tail && !low_tail) // Region 4: short all
      target_state = -1;
   else                          // Region 3: original momentum
      target_state = (momentum_return > 0.0) ? 1 : -1;
   return true;
  }

void Strategy_RefreshState()
  {
   g_state_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: new-D1 state key.
   g_target_state = 0;
   g_state_valid = Strategy_CalculateTarget(g_target_state);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
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

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   return !Strategy_ParametersValid();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_13108_XTI_MTSM_S2";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_state_valid || g_target_state == 0 || g_state_bar_time <= 0)
      return false;
   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      // Custom .DWX tester bars may report zero spread; only a wide spread blocks.
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   const double atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_last <= 0.0 || !MathIsValidNumber(atr_last))
      return false;

   req.type = (g_target_state > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol,
                                req.type,
                                entry_price,
                                atr_last,
                                strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if((req.type == QM_BUY && req.sl >= entry_price) ||
      (req.type == QM_SELL && req.sl <= entry_price))
      return false;

   req.reason = (g_target_state > 0) ? "XTI_MTSM_S2_LONG" : "XTI_MTSM_S2_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int max_hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long position_type = PositionGetInteger(POSITION_TYPE);
      const int position_state = (position_type == POSITION_TYPE_BUY) ? 1 : -1;
      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      const bool stale = opened_at > 0 && now - opened_at >= max_hold_seconds;
      const bool target_changed = !g_state_valid || g_target_state == 0 ||
                                  position_state != g_target_state;
      if(stale || target_changed)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_ExitSignal()
  {
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13108\",\"ea\":\"xti-mtsm-s2\"}");
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
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
     {
      QM_EquityStreamOnNewBar();
      Strategy_RefreshState();
      Strategy_ManageOpenPosition();
     }

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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol,
                                        broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol,
                                       broker_now,
                                       qm_news_mode_legacy);
   if(!news_allows || !is_new_bar)
      return;

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
