#property strict
#property version   "5.0"
#property description "QM5_10761 TradingView Vortex Confluence Protocol"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10761;
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
input bool   strategy_enable_longs        = true;
input bool   strategy_enable_shorts       = true;
input int    strategy_min_score           = 3;
input int    strategy_pivot_strength      = 5;
input bool   strategy_require_bos         = true;
input bool   strategy_require_fvg         = false;
input int    strategy_rsi_period          = 14;
input int    strategy_volume_ma_period    = 20;
input double strategy_volume_threshold    = 1.0;
input bool   strategy_adx_filter_enabled  = true;
input int    strategy_adx_period          = 14;
input double strategy_adx_min             = 20.0;
input ENUM_TIMEFRAMES strategy_mtf_timeframe = PERIOD_H4;
input int    strategy_mtf_trend_length    = 50;
input bool   strategy_session_enabled     = true;
input int    strategy_session_start_hour  = 0;
input int    strategy_session_end_hour    = 24;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 1.5;
input double strategy_structure_atr_buffer = 0.2;
input double strategy_rr_target           = 2.0;
input int    strategy_swing_lookback      = 20;
input bool   strategy_trailing_enabled    = false;
input double strategy_trailing_atr_mult   = 1.5;
input int    strategy_max_spread_points   = 0;

// -----------------------------------------------------------------------------
// Strategy hooks - implement these against the card mechanically.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(strategy_session_enabled)
     {
      int start_h = strategy_session_start_hour;
      int end_h = strategy_session_end_hour;
      if(start_h < 0)
         start_h = 0;
      if(start_h > 23)
         start_h = 23;
      if(end_h < 0)
         end_h = 0;
      if(end_h > 24)
         end_h = 24;

      if(!(start_h == 0 && end_h == 24) && start_h != end_h)
        {
         MqlDateTime dt;
         TimeToStruct(TimeCurrent(), dt);
         const bool in_session = (start_h < end_h)
                                 ? (dt.hour >= start_h && dt.hour < end_h)
                                 : (dt.hour >= start_h || dt.hour < end_h);
         if(!in_session)
            return true;
        }
     }

   if(strategy_max_spread_points > 0)
     {
      const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }

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

   if(strategy_min_score < 1 ||
      strategy_pivot_strength < 2 ||
      strategy_rsi_period < 1 ||
      strategy_volume_ma_period < 2 ||
      strategy_atr_period < 1 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_structure_atr_buffer < 0.0 ||
      strategy_rr_target <= 0.0 ||
      strategy_swing_lookback < 2)
      return false;

   const int p = MathMax(2, strategy_pivot_strength);
   const int lookback = MathMax(strategy_swing_lookback, MathMax(strategy_volume_ma_period, p)) + 3;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 1, lookback, rates); // perf-allowed: bounded BOS/FVG/tick-volume read; caller gates by QM_IsNewBar()
   if(copied < lookback)
      return false;

   double prior_high = -DBL_MAX;
   double prior_low = DBL_MAX;
   for(int i = 1; i <= p; ++i)
     {
      prior_high = MathMax(prior_high, rates[i].high);
      prior_low = MathMin(prior_low, rates[i].low);
     }
   if(prior_high <= 0.0 || prior_low <= 0.0)
      return false;

   int structure_dir = 0;
   if(rates[0].close > prior_high)
      structure_dir = 1;
   else if(rates[0].close < prior_low)
      structure_dir = -1;
   else if(rates[0].close > rates[p].close)
      structure_dir = 1;
   else if(rates[0].close < rates[p].close)
      structure_dir = -1;

   int bos_dir = 0;
   if(rates[0].close > prior_high)
      bos_dir = 1;
   else if(rates[0].close < prior_low)
      bos_dir = -1;

   const double rsi = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   int momentum_dir = 0;
   if(rsi > 50.0)
      momentum_dir = 1;
   else if(rsi > 0.0 && rsi < 50.0)
      momentum_dir = -1;

   int mtf_dir = 0;
   if(strategy_mtf_trend_length > 1)
      mtf_dir = QM_Sig_Price_Above_MA(_Symbol, strategy_mtf_timeframe, strategy_mtf_trend_length, 0.0, 1);

   double volume_sum = 0.0;
   for(int i = 1; i <= strategy_volume_ma_period; ++i)
      volume_sum += (double)rates[i].tick_volume;
   const double volume_avg = volume_sum / (double)strategy_volume_ma_period;
   const bool volume_ok = (volume_avg > 0.0 && (double)rates[0].tick_volume >= volume_avg * strategy_volume_threshold);

   int sweep_dir = 0;
   if(rates[0].low < prior_low && rates[0].close > prior_low)
      sweep_dir = 1;
   else if(rates[0].high > prior_high && rates[0].close < prior_high)
      sweep_dir = -1;

   int smart_dir = 0;
   const double bar_range = rates[0].high - rates[0].low;
   if(bar_range > 0.0 && volume_ok)
     {
      const double close_pos = (rates[0].close - rates[0].low) / bar_range;
      if(close_pos >= 0.65)
         smart_dir = 1;
      else if(close_pos <= 0.35)
         smart_dir = -1;
     }

   int fvg_dir = 0;
   if(rates[0].low > rates[2].high)
      fvg_dir = 1;
   else if(rates[0].high < rates[2].low)
      fvg_dir = -1;

   bool regime_ok = true;
   if(strategy_adx_filter_enabled)
     {
      const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
      regime_ok = (adx >= strategy_adx_min);
     }
   if(!regime_ok)
      return false;

   int side = 0;
   if(strategy_enable_longs && structure_dir > 0)
      side = 1;
   else if(strategy_enable_shorts && structure_dir < 0)
      side = -1;
   else
      return false;

   if(strategy_require_bos && bos_dir != side)
      return false;
   if(strategy_require_fvg && fvg_dir != side)
      return false;

   const int opposite = -side;
   if(momentum_dir == opposite || mtf_dir == opposite || smart_dir == opposite)
      return false;

   int score = 0;
   if(structure_dir == side)
      ++score;
   if(momentum_dir == side)
      ++score;
   if(mtf_dir == side)
      ++score;
   if(volume_ok)
      ++score;
   if(sweep_dir == side)
      ++score;
   if(smart_dir == side)
      ++score;
   if(fvg_dir == side)
      ++score;
   if(regime_ok)
      ++score;
   if(score < strategy_min_score)
      return false;

   const QM_OrderType order_type = (side > 0) ? QM_BUY : QM_SELL;
   const double entry = (side > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double swing_low = DBL_MAX;
   double swing_high = -DBL_MAX;
   for(int i = 1; i <= strategy_swing_lookback; ++i)
     {
      swing_low = MathMin(swing_low, rates[i].low);
      swing_high = MathMax(swing_high, rates[i].high);
     }

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double atr_stop = QM_StopATR(_Symbol, order_type, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(atr <= 0.0 || atr_stop <= 0.0 || swing_low <= 0.0 || swing_high <= 0.0)
      return false;

   double structure_stop = 0.0;
   if(order_type == QM_BUY)
      structure_stop = NormalizeDouble(swing_low - atr * strategy_structure_atr_buffer, _Digits);
   else
      structure_stop = NormalizeDouble(swing_high + atr * strategy_structure_atr_buffer, _Digits);
   if(structure_stop <= 0.0)
      return false;

   const double sl = (order_type == QM_BUY) ? MathMax(atr_stop, structure_stop)
                                           : MathMin(atr_stop, structure_stop);
   if((order_type == QM_BUY && sl >= entry) || (order_type == QM_SELL && sl <= entry))
      return false;

   const double tp = QM_TakeRR(_Symbol, order_type, entry, sl, strategy_rr_target);
   if(tp <= 0.0)
      return false;

   req.type = order_type;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side > 0) ? "TV_VORTEX_LONG" : "TV_VORTEX_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   if(!strategy_trailing_enabled)
      return;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trailing_atr_mult);
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
