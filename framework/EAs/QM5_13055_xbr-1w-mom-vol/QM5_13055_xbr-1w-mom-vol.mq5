#property strict
#property version   "5.0"
#property description "QM5_13055 XBR one-week low-volatility momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13055 - XBR One-Week Low-Volatility Momentum
// -----------------------------------------------------------------------------
// D1 structural Brent sleeve:
//   - direction follows the prior 5 closed D1 return
//   - current 20-D1 realized volatility must rank below a configured percentile
//   - one entry per broker week; ATR stop, time exit, opposite-return exit
// Runtime uses MT5 OHLC/broker calendar only; no EIA, CFTC, curve, API, CSV,
// roll schedule, inventory, external feed, or ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13055;
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
input int    strategy_momentum_lookback_days = 5;
input double strategy_min_week_return_pct    = 1.25;
input int    strategy_vol_window_d1          = 20;
input int    strategy_vol_rank_lookback_d1   = 120;
input double strategy_max_vol_pctile         = 55.0;
input int    strategy_atr_period             = 20;
input double strategy_atr_sl_mult            = 2.50;
input int    strategy_hold_days              = 7;
input double strategy_exit_reverse_pct       = 0.50;
input int    strategy_max_spread_points      = 1200;

int g_last_entry_week_key = 0;

bool Strategy_IsXbrD1()
  {
   return (_Symbol == "XBRUSD.DWX" && _Period == PERIOD_D1);
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_CopyClosedD1Closes(double &closes[], const int bars_needed)
  {
   if(bars_needed < 2)
      return false;
   ArrayResize(closes, bars_needed);
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, bars_needed, closes); // perf-allowed: bounded D1 vector behind QM_IsNewBar for structural weekly momentum and volatility rank.
   return (copied >= bars_needed);
  }

double Strategy_ReturnPctFromCloses(const double &closes[], const int lookback)
  {
   if(lookback < 1 || ArraySize(closes) <= lookback)
      return 0.0;
   const double close_last = closes[0];
   const double close_old = closes[lookback];
   if(close_last <= 0.0 || close_old <= 0.0)
      return 0.0;
   const double ret = 100.0 * ((close_last / close_old) - 1.0);
   if(!MathIsValidNumber(ret))
      return 0.0;
   return ret;
  }

double Strategy_RealizedVolFromCloses(const double &closes[],
                                      const int start_index,
                                      const int window)
  {
   if(start_index < 0 || window < 2)
      return 0.0;
   if(ArraySize(closes) <= start_index + window)
      return 0.0;

   double sum = 0.0;
   double sum2 = 0.0;
   int n = 0;
   for(int i = start_index; i < start_index + window; ++i)
     {
      const double c0 = closes[i];
      const double c1 = closes[i + 1];
      if(c0 <= 0.0 || c1 <= 0.0)
         return 0.0;
      const double r = MathLog(c0 / c1);
      if(!MathIsValidNumber(r))
         return 0.0;
      sum += r;
      sum2 += r * r;
      ++n;
     }

   if(n < 2)
      return 0.0;
   const double mean = sum / (double)n;
   double variance = (sum2 / (double)n) - mean * mean;
   if(variance < 0.0 && variance > -0.000000000001)
      variance = 0.0;
   if(variance < 0.0)
      return 0.0;
   const double vol = MathSqrt(variance);
   return MathIsValidNumber(vol) ? vol : 0.0;
  }

bool Strategy_VolPercentile(const double &closes[],
                            const double current_vol,
                            double &pctile)
  {
   pctile = 0.0;
   if(current_vol <= 0.0 || !MathIsValidNumber(current_vol))
      return false;

   const int obs_target = MathMax(40, strategy_vol_rank_lookback_d1);
   int valid = 0;
   int less_equal = 0;
   for(int start_index = 1; start_index <= obs_target; ++start_index)
     {
      const double prior_vol = Strategy_RealizedVolFromCloses(closes, start_index, strategy_vol_window_d1);
      if(prior_vol <= 0.0 || !MathIsValidNumber(prior_vol))
         continue;
      ++valid;
      if(prior_vol <= current_vol)
         ++less_equal;
     }

   if(valid < MathMax(20, obs_target / 2))
      return false;

   pctile = 100.0 * (double)less_equal / (double)valid;
   return MathIsValidNumber(pctile);
  }

bool Strategy_LoadReturnOnly(double &return_pct)
  {
   return_pct = 0.0;
   const int lookback = MathMax(2, strategy_momentum_lookback_days);
   double closes[];
   if(!Strategy_CopyClosedD1Closes(closes, lookback + 1))
      return false;
   return_pct = Strategy_ReturnPctFromCloses(closes, lookback);
   return MathIsValidNumber(return_pct);
  }

bool Strategy_LoadSignalState(int &direction,
                              double &return_pct,
                              double &vol_pctile,
                              double &atr_last,
                              int &week_key)
  {
   direction = 0;
   return_pct = 0.0;
   vol_pctile = 0.0;
   atr_last = 0.0;
   week_key = QM_CalendarPeriodKey(PERIOD_W1, _Symbol, 0);
   if(week_key <= 0)
      return false;

   const int lookback = MathMax(2, strategy_momentum_lookback_days);
   const int vol_window = MathMax(5, strategy_vol_window_d1);
   const int vol_rank = MathMax(40, strategy_vol_rank_lookback_d1);
   const int bars_needed = MathMax(lookback + 1, vol_rank + vol_window + 2);
   double closes[];
   if(!Strategy_CopyClosedD1Closes(closes, bars_needed))
      return false;

   return_pct = Strategy_ReturnPctFromCloses(closes, lookback);
   if(!MathIsValidNumber(return_pct))
      return false;
   if(MathAbs(return_pct) < strategy_min_week_return_pct)
      return false;

   const double current_vol = Strategy_RealizedVolFromCloses(closes, 0, vol_window);
   if(!Strategy_VolPercentile(closes, current_vol, vol_pctile))
      return false;
   if(vol_pctile > strategy_max_vol_pctile)
      return false;

   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_last <= 0.0 || !MathIsValidNumber(atr_last))
      return false;

   direction = (return_pct > 0.0) ? 1 : -1;
   return true;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   double return_pct = 0.0;
   const bool has_return = Strategy_LoadReturnOnly(return_pct);
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_hold_days) * 86400;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool should_close = false;

      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;
      if(pos_type != POSITION_TYPE_BUY && pos_type != POSITION_TYPE_SELL)
         should_close = true;
      if(has_return && pos_type == POSITION_TYPE_BUY && return_pct <= -strategy_exit_reverse_pct)
         should_close = true;
      if(has_return && pos_type == POSITION_TYPE_SELL && return_pct >= strategy_exit_reverse_pct)
         should_close = true;

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXbrD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_momentum_lookback_days < 2 || strategy_momentum_lookback_days > 30)
      return true;
   if(strategy_min_week_return_pct <= 0.0 || strategy_min_week_return_pct > 20.0)
      return true;
   if(strategy_vol_window_d1 < 5 || strategy_vol_window_d1 > 80)
      return true;
   if(strategy_vol_rank_lookback_d1 < 40 || strategy_vol_rank_lookback_d1 > 260)
      return true;
   if(strategy_max_vol_pctile <= 0.0 || strategy_max_vol_pctile >= 100.0)
      return true;
   if(strategy_atr_period <= 1 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_hold_days <= 0)
      return true;
   if(strategy_exit_reverse_pct < 0.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_13055_XBR_1W_MOM_VOL";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   int direction = 0;
   double return_pct = 0.0;
   double vol_pctile = 0.0;
   double atr_last = 0.0;
   int week_key = 0;
   if(!Strategy_LoadSignalState(direction, return_pct, vol_pctile, atr_last, week_key))
      return false;
   if(week_key <= 0 || week_key == g_last_entry_week_key)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr_last, strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry_price)
      return false;
   if(req.type == QM_SELL && req.sl <= entry_price)
      return false;

   req.tp = 0.0;
   req.reason = (direction > 0) ? "XBR_1W_LOWVOL_MOM_LONG" : "XBR_1W_LOWVOL_MOM_SHORT";
   g_last_entry_week_key = week_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseOpenPositionsIfNeeded();
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13055\",\"ea\":\"xbr-1w-mom-vol\"}");
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

   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

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
