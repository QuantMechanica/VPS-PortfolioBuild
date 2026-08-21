#property strict
#property version   "5.0"
#property description "QM5_37007 Cross-Sectional Momentum & Factor Dispersion"
// Strategy Card: QM5_37007 (cross-sectional-momentum-factor-dispersion), G0 APPROVED.
// Source: Jegadeesh & Titman (1993) & QuantConnect Multi-Asset Factor Suite.

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_37007 — Cross-Sectional Momentum & Factor Dispersion
// -----------------------------------------------------------------------------
// Evaluates relative momentum across 7 major currencies over 60 H4 closed bars:
//   - Rank_k = percentile((Close[1] - Close[1+60]) / Close[1+60])
//   - Long Entry:  Rank_k >= 85.0% (Top Decile Performer) -> BUY
//   - Short Entry: Rank_k <= 15.0% (Bottom Decile Performer) -> SELL
//   - SL = 2.0 * ATR(14, H4), TP = 2.0 * SL_Distance (1:2.0 R:R)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 37007;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_lookback_bars       = 60;     // Cross-sectional momentum lookback bars
input double strategy_top_percentile      = 85.0;   // Top decile threshold for long entry
input double strategy_bottom_percentile   = 15.0;   // Bottom decile threshold for short entry
input int    strategy_atr_period          = 14;     // ATR period for stop loss and spread filter
input double strategy_sl_atr_mult         = 2.00;   // Stop loss ATR multiplier
input double strategy_tp_rr_mult          = 2.00;   // Take profit R:R multiplier
input double strategy_spread_atr_mult     = 1.80;   // Spread filter ATR multiplier
input int    strategy_max_spread_points   = 100;    // Absolute spread cap in points

const int STRATEGY_UNIVERSE_SIZE = 7;
string g_universe_symbols[7] =
  {
   "EURUSD.DWX", "GBPUSD.DWX", "AUDUSD.DWX", "NZDUSD.DWX",
   "USDCAD.DWX", "USDCHF.DWX", "USDJPY.DWX"
  };
int g_universe_slots[7] = {0, 1, 2, 3, 4, 5, 6};

// -----------------------------------------------------------------------------
// Cached State
// -----------------------------------------------------------------------------

double g_cached_percentile = 50.0;
double g_cached_atr1       = 0.0;
bool   g_cached_valid      = false;

int Strategy_SymbolSlot()
{
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
   {
      if(g_universe_symbols[i] == _Symbol)
         return g_universe_slots[i];
   }
   return qm_magic_slot_offset;
}

bool Strategy_ReadSymbolReturn(const string symbol, const int lookback, double &out_ret)
{
   out_ret = 0.0;
   if(lookback < 1) return false;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(symbol, PERIOD_H4, 1, lookback + 1, closes);
   if(copied < lookback + 1) return false;

   const double c_recent = closes[0];
   const double c_past   = closes[lookback];
   if(c_recent <= 0.0 || c_past <= 0.0) return false;

   out_ret = (c_recent - c_past) / c_past;
   return true;
}

void AdvanceState_OnNewBar()
{
   g_cached_atr1 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(g_cached_atr1 <= 0.0)
   {
      g_cached_valid = false;
      return;
   }

   double returns[7];
   int valid_count = 0;
   int current_sym_idx = -1;
   double current_ret = 0.0;

   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
   {
      double ret = 0.0;
      if(Strategy_ReadSymbolReturn(g_universe_symbols[i], strategy_lookback_bars, ret))
      {
         returns[valid_count] = ret;
         if(g_universe_symbols[i] == _Symbol)
         {
            current_sym_idx = valid_count;
            current_ret = ret;
         }
         valid_count++;
      }
   }

   if(valid_count >= 2 && current_sym_idx >= 0)
   {
      int rank = 0;
      for(int i = 0; i < valid_count; ++i)
      {
         if(returns[i] < current_ret)
            rank++;
      }
      g_cached_percentile = ((double)rank / (double)(valid_count - 1)) * 100.0;
      g_cached_valid = true;
   }
   else
   {
      // Single symbol fallback: evaluate percentile against rolling return history
      double hist_closes[];
      ArraySetAsSeries(hist_closes, true);
      const int needed = strategy_lookback_bars + 60;
      const int copied = CopyClose(_Symbol, PERIOD_H4, 1, needed, hist_closes);
      if(copied >= needed)
      {
         const double cur_ret = (hist_closes[0] - hist_closes[strategy_lookback_bars]) / hist_closes[strategy_lookback_bars];
         int rank = 0;
         int total_obs = 0;
         for(int shift = 1; shift < 50 && (shift + strategy_lookback_bars) < copied; ++shift)
         {
            const double past_r = (hist_closes[shift] - hist_closes[shift + strategy_lookback_bars]) / hist_closes[shift + strategy_lookback_bars];
            if(past_r < cur_ret)
               rank++;
            total_obs++;
         }
         if(total_obs > 0)
         {
            g_cached_percentile = ((double)rank / (double)total_obs) * 100.0;
            g_cached_valid = true;
         }
         else
         {
            g_cached_valid = false;
         }
      }
      else
      {
         g_cached_valid = false;
      }
   }
}

bool IsRolloverBlackout()
{
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int minute_of_day = dt.hour * 60 + dt.min;
   if(minute_of_day >= 1435 || minute_of_day <= 5)
      return true;
   return false;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(IsRolloverBlackout())
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
   {
      if(g_cached_atr1 > 0.0 && (ask - bid) > (strategy_spread_atr_mult * g_cached_atr1))
         return true;
      if(point > 0.0 && strategy_max_spread_points > 0 && (ask - bid) > (strategy_max_spread_points * point))
         return true;
   }
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = Strategy_SymbolSlot();
   req.expiration_seconds = 0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_cached_valid)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double sl_dist = strategy_sl_atr_mult * g_cached_atr1;
   const double tp_dist = strategy_tp_rr_mult * sl_dist;
   if(sl_dist <= 0.0)
      return false;

   // Long: Rank >= 85.0% (Top decile momentum)
   if(g_cached_percentile >= strategy_top_percentile)
   {
      req.type   = QM_BUY;
      req.reason = "QM5_37007_XSMOM_BUY";
      req.sl     = ask - sl_dist;
      req.tp     = ask + tp_dist;
      return true;
   }

   // Short: Rank <= 15.0% (Bottom decile momentum)
   if(g_cached_percentile <= strategy_bottom_percentile)
   {
      req.type   = QM_SELL;
      req.reason = "QM5_37007_XSMOM_SELL";
      req.sl     = bid + sl_dist;
      req.tp     = bid - tp_dist;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
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
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id,
                        Strategy_SymbolSlot(),
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

   AdvanceState_OnNewBar();

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
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   AdvanceState_OnNewBar();

   QM_EquityStreamOnNewBar();

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
