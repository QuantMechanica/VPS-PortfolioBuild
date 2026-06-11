#property strict
#property version   "5.0"
#property description "QM5_9512 lt-mom-stack — Leveraged Trading Multi-Speed Momentum Stack"

#include <QM/QM_Common.mqh>

// ============================================================================
// QM5_9512 — Leveraged Trading Multi-Speed Momentum Stack
// Based on Robert Carver, Leveraged Trading (2019), Ch. 6/8/10.
// 6 SMA-crossover speed pairs combined into one forecast; enter when
// combined_forecast exceeds ±2, exit when it crosses zero.
// Emergency hard stop: 2.5 × ATR(20, D1). D1 rebalance cadence.
// ============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                      = 9512;
input int    qm_magic_slot_offset          = 0;
input uint   qm_rng_seed                   = 42;

input group "Risk"
input double RISK_PERCENT                  = 0.0;
input double RISK_FIXED                    = 1000.0;
input double PORTFOLIO_WEIGHT              = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance  = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = true;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_risk_atr_period      = 25;   // ATR period for InstrumentRiskPriceUnits
input int    strategy_sl_atr_period        = 20;   // ATR period for emergency stop
input double strategy_sl_atr_mult          = 2.5;  // Emergency stop = ATR × this
input double strategy_entry_threshold      = 2.0;  // Enter long/short if |forecast| > this
input int    strategy_min_forecasts        = 3;    // Minimum valid MA-pair forecasts required
input double strategy_spread_mult          = 2.0;  // Block entry if spread > mult × avg spread

// Carver (2019) SMA pair speeds and official scaling factors from book spreadsheet
int    g_fast_p[] = {2,    4,    8,   16,   32,   64};
int    g_slow_p[] = {8,   16,   32,   64,  128,  256};
double g_scalar[] = {180.8, 124.32, 83.84, 57.12, 38.24, 25.28};

// File-scope cached state — updated once per closed D1 bar
double g_combined_forecast = 0.0;
int    g_forecast_count    = 0;
double g_avg_spread_pts    = 0.0;

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

double FcClamp(double v)
  {
   return v < -20.0 ? -20.0 : (v > 20.0 ? 20.0 : v);
  }

void AdvanceState_OnNewBar()
  {
   double risk_units = QM_ATR(_Symbol, PERIOD_D1, strategy_risk_atr_period, 1);
   if(risk_units <= 0.0 || risk_units > 1e8)
     {
      g_combined_forecast = 0.0;
      g_forecast_count    = 0;
      return;
     }

   double fc_sum  = 0.0;
   int    n_valid = 0;
   for(int i = 0; i < 6; i++)
     {
      double sma_fast = QM_SMA(_Symbol, PERIOD_D1, g_fast_p[i], 1);
      double sma_slow = QM_SMA(_Symbol, PERIOD_D1, g_slow_p[i], 1);
      if(sma_fast <= 0.0 || sma_fast > 1e8 || sma_slow <= 0.0 || sma_slow > 1e8)
         continue;
      double raw = sma_fast - sma_slow;
      fc_sum += FcClamp(raw / risk_units * g_scalar[i]);
      n_valid++;
     }

   g_forecast_count    = n_valid;
   g_combined_forecast = (n_valid > 0) ? fc_sum / n_valid : 0.0;

   // EWMA of spread in points (alpha = 0.1 ≈ 10-bar half-life)
   double cur_sp = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(g_avg_spread_pts <= 0.0)
      g_avg_spread_pts = cur_sp;
   else
      g_avg_spread_pts = cur_sp * 0.1 + g_avg_spread_pts * 0.9;
  }

// ---------------------------------------------------------------------------
// Strategy hooks
// ---------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(g_forecast_count < strategy_min_forecasts)
      return false;

   // Spread guard — block new entry if current spread is unusually wide
   if(g_avg_spread_pts > 0.0)
     {
      double cur_sp = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(cur_sp > strategy_spread_mult * g_avg_spread_pts)
         return false;
     }

   // One position per magic — flat means eligible to enter
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic) return false;
     }

   if(g_combined_forecast > strategy_entry_threshold)
     {
      double atr  = QM_ATR(_Symbol, PERIOD_D1, strategy_sl_atr_period, 1);
      double dist = atr * strategy_sl_atr_mult;
      req.type             = QM_BUY;
      req.price            = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.sl               = req.price - dist;
      req.tp               = 0.0;
      req.reason           = "LT_MOM_LONG";
      req.symbol_slot      = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   if(g_combined_forecast < -strategy_entry_threshold)
     {
      double atr  = QM_ATR(_Symbol, PERIOD_D1, strategy_sl_atr_period, 1);
      double dist = atr * strategy_sl_atr_mult;
      req.type             = QM_SELL;
      req.price            = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.sl               = req.price + dist;
      req.tp               = 0.0;
      req.reason           = "LT_MOM_SHORT";
      req.symbol_slot      = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Emergency SL set at entry; no trailing per card.
  }

bool Strategy_ExitSignal()
  {
   // Close LONG when forecast <= 0; Close SHORT when forecast >= 0.
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY  && g_combined_forecast <= 0.0) return true;
      if(ptype == POSITION_TYPE_SELL && g_combined_forecast >= 0.0) return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// ---------------------------------------------------------------------------
// Framework wiring
// ---------------------------------------------------------------------------

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

   // Advance closed-bar state FIRST so ExitSignal sees current-bar forecast
   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
      AdvanceState_OnNewBar();

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
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
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
