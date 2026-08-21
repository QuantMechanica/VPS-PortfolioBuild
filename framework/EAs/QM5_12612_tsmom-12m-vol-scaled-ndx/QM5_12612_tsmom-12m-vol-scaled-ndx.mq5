#property strict
#property version   "5.0"
#property description "QM5_12612 TSMOM 12M Vol-Scaled NDX"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12612 - NDX 12-Month Volatility-Scaled Time-Series Momentum
// -----------------------------------------------------------------------------
// D1 structural equity-index sleeve:
//   - evaluated on the first D1 bar of each broker-calendar month
//   - signal direction = sign of prior completed D1 close vs 252 D1 bars ago
//   - volatility scaling = target_vol (10%) / realized_vol (63 D1 bars log-returns std * sqrt(252))
//   - clamped between 0.10 and 2.00
//   - rebalance: reverse on sign change; resize on > 20% vol_scalar change; hold otherwise
//   - protective hard stop = ATR(14, D1) * 3.0
// Runtime uses MT5 OHLC/broker calendar only; no macro feed, API, ML, or grid.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 12612;
input int    qm_magic_slot_offset        = 1; // NDX.DWX is slot 1 in magic_numbers.csv
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_lookback_d1_bars   = 252;
input int    strategy_vol_window         = 63;
input double strategy_target_vol         = 0.10;
input double strategy_vol_resize_threshold = 0.20;
input int    strategy_min_d1_bars        = 275;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 3.0;
input int    strategy_spread_days        = 20;
input double strategy_spread_mult        = 3.0;

int    g_last_entry_rebalance_key = 0;
double g_last_pos_vol_scalar      = 1.0;

bool Strategy_IsNdxD1()
{
   return (_Symbol == "NDX.DWX" && _Period == PERIOD_D1 && qm_magic_slot_offset == 1);
}

int Strategy_MonthKey(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
}

bool Strategy_IsMonthlyRebalanceBar()
{
   if(_Period != PERIOD_D1)
      return false;

   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0);
   const datetime prior_bar = iTime(_Symbol, PERIOD_D1, 1);
   if(current_bar <= 0 || prior_bar <= 0)
      return false;
   return Strategy_MonthKey(current_bar) != Strategy_MonthKey(prior_bar);
}

bool Strategy_CurrentPosition(ulong &ticket, int &direction, double &volume)
{
   ticket = 0;
   direction = 0;
   volume = 0.0;
   const int magic = QM_FrameworkMagic();

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      const long pos_type = PositionGetInteger(POSITION_TYPE);
      direction = (pos_type == POSITION_TYPE_BUY) ? 1 : -1;
      volume = PositionGetDouble(POSITION_VOLUME);
      return true;
   }
   return false;
}

double Strategy_MedianDailySpreadPoints()
{
   const int n = strategy_spread_days;
   if(n <= 0 || n > 64)
      return 0.0;

   double values[64];
   int count = 0;
   for(int shift = 1; shift <= n; ++shift)
   {
      const long spread = iSpread(_Symbol, PERIOD_D1, shift);
      if(spread > 0)
      {
         values[count] = (double)spread;
         ++count;
      }
   }

   if(count <= 0)
      return 0.0;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(values[j] < values[i])
         {
            const double tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
         }

   if((count % 2) == 1)
      return values[count / 2];
   return 0.5 * (values[(count / 2) - 1] + values[count / 2]);
}

bool Strategy_SpreadAllowsEntry()
{
   const double median_spread = Strategy_MedianDailySpreadPoints();
   if(median_spread <= 0.0 || strategy_spread_mult <= 0.0)
      return true;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread > 0 && (double)current_spread > median_spread * strategy_spread_mult)
      return false;
   return true;
}

int Strategy_TsmomDirection()
{
   if(strategy_lookback_d1_bars <= 0)
      return 0;

   const int min_bars = MathMax(strategy_min_d1_bars, strategy_lookback_d1_bars + 5);
   if(Bars(_Symbol, PERIOD_D1) < min_bars)
      return 0;

   const double recent_close = iClose(_Symbol, PERIOD_D1, 1);
   const double lookback_close = iClose(_Symbol, PERIOD_D1, 1 + strategy_lookback_d1_bars);
   if(recent_close <= 0.0 || lookback_close <= 0.0)
      return 0;

   if(recent_close > lookback_close)
      return 1;
   if(recent_close < lookback_close)
      return -1;
   return 0;
}

double Strategy_RealizedAnnualizedVol()
{
   const int n = strategy_vol_window;
   if(n <= 1)
      return strategy_target_vol;

   if(Bars(_Symbol, PERIOD_D1) < n + 2)
      return strategy_target_vol;

   double log_returns[];
   ArrayResize(log_returns, n);
   double sum = 0.0;

   for(int i = 1; i <= n; ++i)
   {
      const double c0 = iClose(_Symbol, PERIOD_D1, i);
      const double c1 = iClose(_Symbol, PERIOD_D1, i + 1);
      if(c0 <= 0.0 || c1 <= 0.0)
         return strategy_target_vol;
      const double r = MathLog(c0 / c1);
      log_returns[i - 1] = r;
      sum += r;
   }

   const double mean = sum / (double)n;
   double sum_sq_diff = 0.0;
   for(int i = 0; i < n; ++i)
   {
      const double diff = log_returns[i] - mean;
      sum_sq_diff += diff * diff;
   }

   const double variance = sum_sq_diff / (double)(n - 1);
   const double stddev = MathSqrt(variance);
   const double realized_vol = stddev * MathSqrt(252.0);
   return realized_vol;
}

double Strategy_VolScalar()
{
   const double realized_vol = Strategy_RealizedAnnualizedVol();
   const double safe_vol = MathMax(realized_vol, 0.01);
   double scalar = strategy_target_vol / safe_vol;
   scalar = MathMin(scalar, 2.0);
   scalar = MathMax(scalar, 0.10);
   return scalar;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(!Strategy_IsNdxD1())
      return true;
   if(strategy_lookback_d1_bars < 21)
      return true;
   if(strategy_vol_window < 5)
      return true;
   if(strategy_target_vol <= 0.0)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_spread_days < 0 || strategy_spread_mult < 0.0)
      return true;
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

   if(!Strategy_IsMonthlyRebalanceBar())
      return false;

   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0);
   const int rebalance_key = Strategy_MonthKey(current_bar);
   if(rebalance_key <= 0 || rebalance_key == g_last_entry_rebalance_key)
      return false;

   if(!Strategy_SpreadAllowsEntry())
      return false;

   const int direction = Strategy_TsmomDirection();
   if(direction == 0)
      return false;

   const double vol_scalar = Strategy_VolScalar();

   ulong existing_ticket = 0;
   int existing_direction = 0;
   double existing_volume = 0.0;
   const bool has_pos = Strategy_CurrentPosition(existing_ticket, existing_direction, existing_volume);

   if(has_pos)
   {
      bool needs_reopen = false;
      if(existing_direction != direction)
      {
         needs_reopen = true;
      }
      else if(g_last_pos_vol_scalar > 0.0)
      {
         const double rel_change = MathAbs(vol_scalar - g_last_pos_vol_scalar) / g_last_pos_vol_scalar;
         if(rel_change > strategy_vol_resize_threshold)
            needs_reopen = true;
      }

      if(!needs_reopen)
      {
         g_last_entry_rebalance_key = rebalance_key;
         return false; // Hold existing position
      }

      if(!QM_TM_ClosePosition(existing_ticket, QM_EXIT_STRATEGY))
         return false;
   }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = (direction > 0) ? ask : bid;
   req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = 0.0;
   req.symbol_slot = qm_magic_slot_offset;
   req.reason = (direction > 0) ? "NDX_TSMOM12M_VOL_LONG" : "NDX_TSMOM12M_VOL_SHORT";

   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= req.price)
      return false;
   if(req.type == QM_SELL && req.sl <= req.price)
      return false;

   g_last_entry_rebalance_key = rebalance_key;
   g_last_pos_vol_scalar = vol_scalar;

   const QM_RiskMode rmode = (RISK_FIXED > 0.0) ? QM_RISK_MODE_FIXED : QM_RISK_MODE_PERCENT;
   const double base_val = (RISK_FIXED > 0.0) ? RISK_FIXED : RISK_PERCENT;
   const double scaled_val = base_val * vol_scalar;

   ulong out_ticket = 0;
   QM_TM_OpenPosition(req, out_ticket, QM_FrameworkMagic(), rmode, scaled_val);

   return false;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12612\",\"ea\":\"tsmom-12m-vol-scaled-ndx\"}");
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
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
