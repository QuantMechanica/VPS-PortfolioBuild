#property strict
#property version   "5.0"
#property description "QM5_1355 Williams VIX-Fix on FX/Indices — Volatility-Spike Bottom (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_1355
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1355;
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
input int    strategy_wvf_lookback        = 22;
input int    strategy_wvf_ma_period       = 20;
input double strategy_wvf_devs            = 2.0;
input double strategy_wvf_range_pct       = 0.85;
input int    strategy_atr_period          = 14;
input int    strategy_ema_filter_period   = 200;
input double strategy_sl_atr_mult         = 1.5;
input double strategy_tp1_atr_mult        = 1.5;
input double strategy_tp2_atr_mult        = 3.0;
input int    strategy_time_stop_bars      = 24;
input double strategy_spread_mult         = 1.5;
input int    strategy_warmup_h4_bars      = 250;

// --- Closed-bar state ---
double g_wvf_1 = 0.0;
double g_wvf_2 = 0.0;
double g_wvf_ma_1 = 0.0;
double g_wvf_ma_2 = 0.0;
double g_wvf_sd_1 = 0.0;
double g_wvf_sd_2 = 0.0;
double g_wvf_range_high_1 = 0.0;
double g_wvf_range_high_2 = 0.0;

double g_ema200_h4_1 = 0.0;
double g_atr_1 = 0.0;
double g_spread_ema = 0.0;

int  g_bars_in_trade = 0;
bool g_tp1_taken = false;
bool g_spike_cycle_suppressed = false;

// Trade entry tracking
double g_entry_price = 0.0;
double g_atr_at_entry = 0.0;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

double WVF(int shift)
{
   double max_close = -DBL_MAX;
   for(int i = 0; i < 22; i++)
   {
      double c = iClose(_Symbol, PERIOD_H4, shift + i); // perf-allowed: range scan
      if(c > max_close) max_close = c;
   }
   if(max_close <= 0.0) return 0.0;
   double low = iLow(_Symbol, PERIOD_H4, shift); // perf-allowed: low value
   return 100.0 * (max_close - low) / max_close;
}

void GetWvfStats(int shift, double &ma, double &sd, double &range_high)
{
   double sum = 0.0;
   double wvf_values[20];
   for(int i = 0; i < 20; i++)
   {
      wvf_values[i] = WVF(shift + i);
      sum += wvf_values[i];
   }
   ma = sum / 20.0;

   double sum_sq = 0.0;
   for(int i = 0; i < 20; i++)
   {
      sum_sq += (wvf_values[i] - ma) * (wvf_values[i] - ma);
   }
   sd = MathSqrt(sum_sq / 20.0);

   double max_wvf_51 = -DBL_MAX;
   for(int i = 0; i < 51; i++)
   {
      double w = WVF(shift + i);
      if(w > max_wvf_51) max_wvf_51 = w;
   }
   range_high = 0.85 * max_wvf_51;
}

void AdvanceState_OnNewBar()
{
   g_wvf_1 = WVF(1);
   g_wvf_2 = WVF(2);

   GetWvfStats(1, g_wvf_ma_1, g_wvf_sd_1, g_wvf_range_high_1);
   GetWvfStats(2, g_wvf_ma_2, g_wvf_sd_2, g_wvf_range_high_2);

   g_ema200_h4_1 = QM_EMA(_Symbol, PERIOD_H4, 200, 1);
   g_atr_1 = QM_ATR(_Symbol, PERIOD_H4, 14, 1);

   const double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask_now  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double raw_sprd = (ask_now > 0.0 && bid > 0.0 && ask_now > bid)
                           ? (ask_now - bid) : 0.0;
   g_spread_ema = (g_spread_ema <= 0.0)
                  ? raw_sprd
                  : 0.095 * raw_sprd + 0.905 * g_spread_ema;

   const int magic = QM_FrameworkMagic();
   if(magic > 0 && QM_TM_OpenPositionCount(magic) > 0)
      g_bars_in_trade++;
   else
   {
      g_bars_in_trade = 0;
      g_tp1_taken = false;
   }

   // Reset suppression when WVF returns below WVF_MA
   if(g_spike_cycle_suppressed && g_wvf_1 < g_wvf_ma_1)
      g_spike_cycle_suppressed = false;
}

bool Strategy_NoTradeFilter()
{
   if(Bars(_Symbol, PERIOD_H4) < strategy_warmup_h4_bars) // perf-allowed: O(1) bar count for warmup
      return true;

   const double bid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask_now = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask_now > 0.0 && bid > 0.0 && ask_now > bid && g_spread_ema > 0.0)
   {
      if((ask_now - bid) > strategy_spread_mult * g_spread_ema)
         return true;
   }
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(g_spike_cycle_suppressed)
      return false;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double ask_now = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask_now <= 0.0)
      return false;

   double close1 = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed: close check
   double open1  = iOpen(_Symbol, PERIOD_H4, 1); // perf-allowed: open check
   
   if(close1 <= open1)
      return false;

   if(close1 <= g_ema200_h4_1)
      return false;

   double upper2 = g_wvf_ma_2 + strategy_wvf_devs * g_wvf_sd_2;
   double max_thresh2 = MathMax(upper2, g_wvf_range_high_2);
   if(g_wvf_2 <= max_thresh2)
      return false;

   double wvf3 = WVF(3);
   if(g_wvf_1 >= g_wvf_2 || g_wvf_2 <= wvf3)
      return false;

   double low1 = iLow(_Symbol, PERIOD_H4, 1); // perf-allowed: low check
   double sl = MathMin(low1, ask_now - strategy_sl_atr_mult * g_atr_1);
   if(sl <= 0.0 || sl >= ask_now)
      return false;

   req.type             = QM_BUY;
   req.price            = 0.0;
   req.sl               = sl;
   req.tp               = 0.0;
   req.reason           = "WILLIAMS_VIX_FIX_BUY";
   req.symbol_slot      = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_spike_cycle_suppressed = true;
   g_bars_in_trade      = 0;
   g_tp1_taken          = false;

   g_entry_price        = ask_now;
   g_atr_at_entry       = g_atr_1;

   return true;
}

void Strategy_ManageOpenPosition()
{
   if(g_tp1_taken)
      return;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) == 0)
      return;

   double close1 = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed: close check
   if(close1 <= 0.0 || g_atr_at_entry <= 0.0)
      return;

   double tp1_level = g_entry_price + strategy_tp1_atr_mult * g_atr_at_entry;
   if(close1 >= tp1_level)
   {
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;

         const double vol = PositionGetDouble(POSITION_VOLUME);
         const double close_vol = QM_TM_NormalizeVolume(_Symbol, vol * 0.5);
         if(close_vol > 0.0)
         {
            QM_TM_PartialClose(ticket, close_vol, QM_EXIT_STRATEGY);
            g_tp1_taken = true;
         }
         break;
      }
   }
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) == 0)
      return false;

   if(g_bars_in_trade >= strategy_time_stop_bars)
      return true;

   double close1 = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed: close check

   if(close1 < g_ema200_h4_1)
      return true;

   if(g_tp1_taken && g_atr_at_entry > 0.0)
   {
      double tp2_level = g_entry_price + strategy_tp2_atr_mult * g_atr_at_entry;
      if(close1 >= tp2_level)
         return true;
   }

   if(g_bars_in_trade <= 5)
   {
      double upper1 = g_wvf_ma_1 + strategy_wvf_devs * g_wvf_sd_1;
      if(g_wvf_1 > upper1)
         return true;
   }

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
   
   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"ea\":\"QM5_1355\",\"slug\":\"williams-vix-fix-fx-h4\"}");
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

   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
      AdvanceState_OnNewBar();

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!is_new_bar) return;
   QM_EquityStreamOnNewBar();

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
