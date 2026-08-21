#property strict
#property version   "5.0"
#property description "QM5_41010 Developing Point of Control (d-POC) Migration Scalper"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_41010
// Developing Point of Control (d-POC) Migration Scalper
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 41010;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
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
input int    InpLookbackBars            = 4;      // POC migration lookback bars (delta = dPOC[1] - dPOC[1+Lookback])
input double InpMinVolumeMult           = 1.20;   // Minimum volume surge multiplier vs SMA(20)
input int    InpBufferTicks             = 4;      // Entry & SL buffer distance in ticks
input int    InpProfileWindowBars       = 32;     // Developing profile lookback window in bars
input int    InpBucketTicks             = 10;     // Price bucket granularity in ticks
input int    InpAtrPeriod               = 14;     // Volatility filter ATR period
input double InpSpreadAtrMult           = 1.8;    // Max spread as multiple of M15 ATR(14)
input double InpRrMultiplier            = 2.0;    // Take profit risk-reward multiplier (1:2.0)
input bool   InpEnableRatchetTrailing   = true;   // Ratchet stop loss with migrating d-POC

// -----------------------------------------------------------------------------
// Cached Bar State
// -----------------------------------------------------------------------------
double g_cached_atr_1     = 0.0;
double g_cached_dpoc_t    = 0.0;
double g_cached_dpoc_prev = 0.0;
double g_cached_vol_sma_1 = 0.0;
long   g_cached_vol_1     = 0;
double g_cached_close_1   = 0.0;

// -----------------------------------------------------------------------------
// Helper Functions
// -----------------------------------------------------------------------------

double CalculateVolumeSMA(const int period, const int shift)
{
   double sum = 0.0;
   for(int i = 0; i < period; ++i)
   {
      sum += (double)iVolume(_Symbol, PERIOD_M15, shift + i);
   }
   return (period > 0) ? (sum / (double)period) : 0.0;
}

double CalculateDPOC(const int start_shift, const int window_bars, const double bucket_size)
{
   if(bucket_size <= 0.0 || window_bars <= 0) return 0.0;

   double min_price = 99999999.0;
   double max_price = 0.0;

   for(int i = 0; i < window_bars; ++i)
   {
      const int s = start_shift + i;
      const double h = iHigh(_Symbol, PERIOD_M15, s);
      const double l = iLow(_Symbol, PERIOD_M15, s);
      if(h > 0.0 && h > max_price) max_price = h;
      if(l > 0.0 && l < min_price) min_price = l;
   }

   if(max_price <= min_price || min_price <= 0.0) return 0.0;

   const int n_buckets = (int)((max_price - min_price) / bucket_size) + 1;
   if(n_buckets <= 0 || n_buckets > 2000) return (max_price + min_price) * 0.5;

   double vol[];
   if(ArrayResize(vol, n_buckets) != n_buckets) return 0.0;
   ArrayInitialize(vol, 0.0);

   for(int i = 0; i < window_bars; ++i)
   {
      const int s = start_shift + i;
      const double h = iHigh(_Symbol, PERIOD_M15, s);
      const double l = iLow(_Symbol, PERIOD_M15, s);
      const long v   = iVolume(_Symbol, PERIOD_M15, s);
      if(v <= 0 || h <= l) continue;

      int b_start = (int)((l - min_price) / bucket_size);
      int b_end   = (int)((h - min_price) / bucket_size);
      if(b_start < 0) b_start = 0;
      if(b_end >= n_buckets) b_end = n_buckets - 1;

      int span = b_end - b_start + 1;
      if(span <= 0) span = 1;
      const double vol_per_bucket = (double)v / (double)span;
      for(int b = b_start; b <= b_end; ++b)
      {
         vol[b] += vol_per_bucket;
      }
   }

   double max_v = -1.0;
   int best_b = 0;
   for(int b = 0; b < n_buckets; ++b)
   {
      if(vol[b] > max_v)
      {
         max_v = vol[b];
         best_b = b;
      }
   }

   return min_price + ((double)best_b + 0.5) * bucket_size;
}

void AdvanceState_OnNewBar()
{
   g_cached_atr_1 = QM_ATR(_Symbol, PERIOD_M15, InpAtrPeriod, 1);
   g_cached_close_1 = iClose(_Symbol, PERIOD_M15, 1);
   g_cached_vol_1 = iVolume(_Symbol, PERIOD_M15, 1);
   g_cached_vol_sma_1 = CalculateVolumeSMA(20, 1);

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double bucket_size = point * (double)InpBucketTicks;

   g_cached_dpoc_t    = CalculateDPOC(1, InpProfileWindowBars, bucket_size);
   g_cached_dpoc_prev = CalculateDPOC(1 + InpLookbackBars, InpProfileWindowBars, bucket_size);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid && g_cached_atr_1 > 0.0)
   {
      if((ask - bid) > InpSpreadAtrMult * g_cached_atr_1)
         return true;
   }

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int minute_of_day = dt.hour * 60 + dt.min;
   if(minute_of_day >= 1435 || minute_of_day < 5) // 23:55 to 00:05 GMT rollover blackout
      return true;

   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(g_cached_atr_1 <= 0.0 || g_cached_dpoc_t <= 0.0 || g_cached_dpoc_prev <= 0.0)
      return false;

   // Volume confirmation: Volume[1] > InpMinVolumeMult * SMA(Vol, 20)[1]
   if(g_cached_vol_sma_1 <= 0.0 || (double)g_cached_vol_1 <= InpMinVolumeMult * g_cached_vol_sma_1)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double buffer = point * (double)InpBufferTicks;
   const double delta_dpoc = g_cached_dpoc_t - g_cached_dpoc_prev;

   // Long entry condition: delta_dPOC > 0 AND Close[1] > dPOC_t + buffer
   if(delta_dpoc > 0.0 && g_cached_close_1 > (g_cached_dpoc_t + buffer))
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0) return false;

      double sl = g_cached_dpoc_t - buffer;
      if(ask - sl < 0.5 * g_cached_atr_1) sl = ask - 0.5 * g_cached_atr_1;
      if(ask - sl > 4.0 * g_cached_atr_1) sl = ask - 4.0 * g_cached_atr_1;

      const double sl_dist = ask - sl;
      if(sl_dist <= 0.0) return false;

      const double tp = ask + InpRrMultiplier * sl_dist;

      req.type               = QM_BUY;
      req.price              = ask;
      req.sl                 = sl;
      req.tp                 = tp;
      req.reason             = "41010_dpoc_mig_buy";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   // Short entry condition: delta_dPOC < 0 AND Close[1] < dPOC_t - buffer
   if(delta_dpoc < 0.0 && g_cached_close_1 < (g_cached_dpoc_t - buffer))
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0) return false;

      double sl = g_cached_dpoc_t + buffer;
      if(sl - bid < 0.5 * g_cached_atr_1) sl = bid + 0.5 * g_cached_atr_1;
      if(sl - bid > 4.0 * g_cached_atr_1) sl = bid + 4.0 * g_cached_atr_1;

      const double sl_dist = sl - bid;
      if(sl_dist <= 0.0) return false;

      const double tp = bid - InpRrMultiplier * sl_dist;

      req.type               = QM_SELL;
      req.price              = bid;
      req.sl                 = sl;
      req.tp                 = tp;
      req.reason             = "41010_dpoc_mig_sell";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   if(!InpEnableRatchetTrailing) return;
   if(g_cached_dpoc_t <= 0.0) return;

   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double buffer = point * (double)InpBufferTicks;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);

      if(pos_type == POSITION_TYPE_BUY)
      {
         const double proposed_sl = g_cached_dpoc_t - buffer;
         if(proposed_sl > current_sl && proposed_sl < current_price - 2.0 * point)
         {
            QM_TM_MoveSL(ticket, proposed_sl, "41010_dpoc_ratchet");
         }
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         const double proposed_sl = g_cached_dpoc_t + buffer;
         if((current_sl <= 0.0 || proposed_sl < current_sl) && proposed_sl > current_price + 2.0 * point)
         {
            QM_TM_MoveSL(ticket, proposed_sl, "41010_dpoc_ratchet");
         }
      }
   }
}

bool Strategy_ExitSignal()
{
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

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

   if(!QM_IsNewBar(_Symbol, PERIOD_M15)) return;
   QM_EquityStreamOnNewBar();
   AdvanceState_OnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
