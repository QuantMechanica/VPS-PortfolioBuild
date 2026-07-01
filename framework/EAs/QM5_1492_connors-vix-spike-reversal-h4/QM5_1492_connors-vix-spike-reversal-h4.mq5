#property strict
#property version   "5.0"
#property description "QM5_1492 Connors VIX-Spike Reversal H4 (ATR-Stretch Port)"

#include <QM/QM_Common.mqh>

// ============================================================================
// QM5_1492 connors-vix-spike-reversal-h4
// Source: 6e967762-b26d-59a3-b076-35c17f2e7c36
// Connors/Alvarez Short Term Trading Strategies That Work (2008) ch.9
// ATR-stretch port of VIX-spike reversal for index CFDs (card G0 APPROVED)
// ============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1492;
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
input int    strategy_atr_period          = 14;
input int    strategy_atr_baseline_period = 50;
input double strategy_stretch_entry       = 1.5;
input double strategy_stretch_confirm     = 1.3;
input int    strategy_sma_long_h4         = 200;
input int    strategy_sma_long_slope_bars = 10;
input int    strategy_sma_pullback_h4     = 5;
input int    strategy_sma_exit_slow       = 10;
input int    strategy_sma_d1              = 50;
input int    strategy_sma_d1_slope_bars   = 5;
input int    strategy_cooldown_bars       = 12;
input int    strategy_time_stop_bars      = 16;
input double strategy_sl_atr_mult         = 2.0;
input int    strategy_warmup_h4_bars      = 250;
input double strategy_spread_mult         = 1.5;

// --- Closed-bar cached state (advanced once per new H4 bar) ---
double g_atr_1        = 0.0;
double g_atr_2        = 0.0;
double g_atr_3        = 0.0;
double g_atr_long     = 0.0;
double g_sma200_h4_1  = 0.0;
double g_sma200_h4_11 = 0.0;
double g_sma5_h4_1    = 0.0;
double g_sma5_h4_2    = 0.0;
double g_sma10_h4_1   = 0.0;
double g_sma50_d1_1   = 0.0;
double g_sma50_d1_6   = 0.0;
double g_close_h4_1   = 0.0;
double g_close_h4_2   = 0.0;
double g_close_d1_1   = 0.0;
double g_spread_ema   = 0.0;

// --- Trade lifecycle state ---
int  g_bars_in_trade      = 0;
bool g_tp1_taken          = false;
int  g_cooldown_remaining = 0;

// =============================================================================

void AdvanceState_OnNewBar()
  {
   g_close_h4_1 = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed: no QM_Close() helper; fixed shift, once per bar
   g_close_h4_2 = iClose(_Symbol, PERIOD_H4, 2); // perf-allowed: no QM_Close() helper; fixed shift, once per bar
   g_close_d1_1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: no QM_Close() helper; fixed shift, once per bar

   g_atr_1 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   g_atr_2 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 2);
   g_atr_3 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 3);

   // SMA(ATR(14), 50) baseline: bounded 50-iteration loop, runs once per bar
   double atr_sum = 0.0;
   for(int i = 1; i <= strategy_atr_baseline_period; i++)
      atr_sum += QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, i);
   g_atr_long = (strategy_atr_baseline_period > 0)
                ? atr_sum / strategy_atr_baseline_period
                : 1e-10;

   g_sma200_h4_1  = QM_SMA(_Symbol, PERIOD_H4, strategy_sma_long_h4, 1);
   g_sma200_h4_11 = QM_SMA(_Symbol, PERIOD_H4, strategy_sma_long_h4,
                            strategy_sma_long_slope_bars + 1);
   g_sma5_h4_1    = QM_SMA(_Symbol, PERIOD_H4, strategy_sma_pullback_h4, 1);
   g_sma5_h4_2    = QM_SMA(_Symbol, PERIOD_H4, strategy_sma_pullback_h4, 2);
   g_sma10_h4_1   = QM_SMA(_Symbol, PERIOD_H4, strategy_sma_exit_slow, 1);
   g_sma50_d1_1   = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_d1, 1);
   g_sma50_d1_6   = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_d1,
                            strategy_sma_d1_slope_bars + 1);

   // Spread EMA (alpha=0.095, ~20-bar); DWX zero spread is normal, never a block
   const double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask_now  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double raw_sprd = (ask_now > 0.0 && bid > 0.0 && ask_now > bid)
                           ? (ask_now - bid) : 0.0;
   g_spread_ema = (g_spread_ema <= 0.0)
                  ? raw_sprd
                  : 0.095 * raw_sprd + 0.905 * g_spread_ema;

   // Trade counters
   const int magic = QM_FrameworkMagic();
   if(magic > 0 && QM_TM_OpenPositionCount(magic) > 0)
      g_bars_in_trade++;
   else
      g_bars_in_trade = 0;

   if(g_cooldown_remaining > 0)
      g_cooldown_remaining--;
  }

// =============================================================================

bool Strategy_NoTradeFilter()
  {
   if(Bars(_Symbol, PERIOD_H4) < strategy_warmup_h4_bars) // perf-allowed: O(1) bar count for warmup gate
      return true;
   if(Bars(_Symbol, PERIOD_D1) < strategy_sma_d1 + strategy_sma_d1_slope_bars + 1) // perf-allowed: O(1) bar count for D1 warmup
      return true;

   // Spread: only block if genuinely wide vs EMA; zero spread (DWX) is valid
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
   if(g_atr_long <= 0.0 || g_sma200_h4_1 <= 0.0 || g_close_h4_1 <= 0.0)
      return false;

   // Gate 6: cooldown
   if(g_cooldown_remaining > 0)
      return false;

   // Single position per magic
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Gate 1: current ATR stretch exceeds entry threshold
   const double stretch_1 = g_atr_1 / g_atr_long;
   if(stretch_1 <= strategy_stretch_entry)
      return false;

   // Gate 2: stretch persisted at least one prior bar
   const double stretch_2 = g_atr_2 / g_atr_long;
   const double stretch_3 = g_atr_3 / g_atr_long;
   if(stretch_2 <= strategy_stretch_confirm && stretch_3 <= strategy_stretch_confirm)
      return false;

   // Gate 3: H4 long-term uptrend and SMA200 rising
   if(g_close_h4_1 <= g_sma200_h4_1)
      return false;
   if(g_sma200_h4_1 <= g_sma200_h4_11)
      return false;

   // Gate 4: short-term pullback on both recent bars
   if(g_close_h4_1 >= g_sma5_h4_1)
      return false;
   if(g_close_h4_2 >= g_sma5_h4_2)
      return false;

   // Gate 5: D1 uptrend confirmed and D1 SMA50 rising
   if(g_close_d1_1 <= g_sma50_d1_1)
      return false;
   if(g_sma50_d1_1 <= g_sma50_d1_6)
      return false;

   const double ask_now = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask_now <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask_now, g_atr_1, strategy_sl_atr_mult);
   if(sl <= 0.0 || sl >= ask_now)
      return false;

   req.type             = QM_BUY;
   req.price            = 0.0;
   req.sl               = sl;
   req.tp               = 0.0;
   req.reason           = "CONNORS_VIX_STRETCH_LONG";
   req.symbol_slot      = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_cooldown_remaining = strategy_cooldown_bars;
   g_bars_in_trade      = 0;
   g_tp1_taken          = false;

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // TP1: partial close 60% when H4 bar closes above SMA5
   if(g_tp1_taken || g_close_h4_1 <= 0.0 || g_sma5_h4_1 <= 0.0)
      return;
   if(g_close_h4_1 <= g_sma5_h4_1)
      return;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const double vol      = PositionGetDouble(POSITION_VOLUME);
      const double close_vol = QM_TM_NormalizeVolume(_Symbol, vol * 0.6);
      if(close_vol > 0.0)
        {
         QM_TM_PartialClose(ticket, close_vol, QM_EXIT_STRATEGY);
         g_tp1_taken = true;
        }
      break;
     }
  }

bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) == 0)
      return false;

   // Time stop
   if(g_bars_in_trade >= strategy_time_stop_bars)
      return true;

   // TP2: close remaining 40% when H4 bar closes above SMA10
   if(g_tp1_taken && g_sma10_h4_1 > 0.0 && g_close_h4_1 > g_sma10_h4_1)
      return true;

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// =============================================================================
// Framework wiring — AdvanceState called before exits so bar-close conditions
// in ManageOpenPosition and ExitSignal see current H4 data
// =============================================================================

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

   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"ea\":\"QM5_1492\",\"slug\":\"connors-vix-spike-reversal-h4\"}");
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

   // Advance closed-bar state before exits so TP1/TP2/time-stop see current data
   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
      AdvanceState_OnNewBar();

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!is_new_bar)
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
