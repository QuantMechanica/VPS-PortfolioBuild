#property strict
#property version   "5.0"
#property description "QM5_9720 Bandy ADX-Regime-Filter Trend D1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_9720
// Bandy ADX-Regime-Filter Trend (FX/XAU/Index/Oil, Long+Short MA-Cross)
// Source: Howard Bandy, "Quantitative Technical Analysis", 2015 (ISBN 978-0-9791037-7-1)
// Strategy:
//   - Fast SMA(20) and Slow SMA(50) crossover on D1.
//   - Regime Gate: Wilder ADX(14) >= 25.0 on closed bar 1.
//   - Entry: Long on bullish cross + ADX >= 25; Short on bearish cross + ADX >= 25.
//   - Exit: 2.5x ATR(14) ratcheting trailing stop, 60-day hard time stop, reverse on opposite signal.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9720;
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
input int    strategy_sma_fast_period   = 20;    // Fast SMA Period (default 20)
input int    strategy_sma_slow_period   = 50;    // Slow SMA Period (default 50)
input int    strategy_adx_period        = 14;    // ADX Period (default 14)
input double strategy_adx_threshold     = 25.0;  // ADX Regime Threshold (default 25.0)
input int    strategy_trail_atr_period  = 14;    // ATR Period for Trailing Stop (default 14)
input double strategy_trail_atr_mult    = 2.5;   // ATR Multiplier for Trailing Stop (default 2.5)
input int    strategy_max_hold_days     = 60;    // Hard Time Stop in Trading Days (default 60)

// --- Cached closed-bar state (advanced once per D1 bar) ---
static double g_fast1        = 0.0;
static double g_slow1        = 0.0;
static double g_fast2        = 0.0;
static double g_slow2        = 0.0;
static double g_adx1         = 0.0;
static double g_last_close   = 0.0;
static double g_atr14        = 0.0;
static bool   g_state_valid  = false;

void AdvanceState_OnNewBar()
  {
   g_fast1       = 0.0;
   g_slow1       = 0.0;
   g_fast2       = 0.0;
   g_slow2       = 0.0;
   g_adx1        = 0.0;
   g_last_close  = 0.0;
   g_atr14       = 0.0;
   g_state_valid = false;

   const int required_bars = strategy_sma_slow_period + strategy_adx_period + 5;
   if(Bars(_Symbol, PERIOD_D1) < required_bars)
      return;

   g_fast1 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_fast_period, 1);
   g_slow1 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_slow_period, 1);
   g_fast2 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_fast_period, 2);
   g_slow2 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_slow_period, 2);
   g_adx1  = QM_ADX(_Symbol, PERIOD_D1, strategy_adx_period, 1);
   g_atr14 = QM_ATR(_Symbol, PERIOD_D1, strategy_trail_atr_period, 1);
   g_last_close = iClose(_Symbol, PERIOD_D1, 1);

   g_state_valid = (g_fast1 > 0.0 && g_slow1 > 0.0 &&
                    g_fast2 > 0.0 && g_slow2 > 0.0 &&
                    g_adx1 >= 0.0 && g_atr14 > 0.0 &&
                    g_last_close > 0.0);
  }

// =============================================================================
// Strategy hooks
// =============================================================================

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(strategy_sma_fast_period <= 0 || strategy_sma_slow_period <= 0 ||
      strategy_sma_fast_period >= strategy_sma_slow_period ||
      strategy_adx_period <= 0 || strategy_adx_threshold <= 0.0 ||
      strategy_trail_atr_period <= 0 || strategy_trail_atr_mult <= 0.0)
      return true;
   return (!g_state_valid);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_state_valid)
      return false;

   // ADX Regime Gate
   if(g_adx1 < strategy_adx_threshold)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   // One position per magic
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   int direction = 0;
   // Bullish crossover
   if(g_fast1 > g_slow1 && g_fast2 <= g_slow2)
      direction = 1;
   // Bearish crossover
   else if(g_fast1 < g_slow1 && g_fast2 >= g_slow2)
      direction = -1;
   else
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, g_atr14, strategy_trail_atr_mult);
   if(req.sl <= 0.0)
      return false;

   req.price              = 0.0;
   req.tp                 = 0.0;
   req.expiration_seconds = 0;
   req.reason             = (direction > 0) ? "BANDY_ADX_TREND_LONG" : "BANDY_ADX_TREND_SHORT";
   req.symbol_slot        = qm_magic_slot_offset;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   if(!g_state_valid)
      return;

   const long magic = (long)QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int total = PositionsTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      // 1. Hard Time Stop (60 trading days)
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int held_days = QM_TM_HeldPeriods(_Symbol, PERIOD_D1, open_time);
      if(held_days >= strategy_max_hold_days)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME);
         continue;
        }

      // 2. Ratcheting ATR Trailing Stop
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);

      if(ptype == POSITION_TYPE_BUY)
        {
         const double target_sl = QM_TM_NormalizePrice(_Symbol, g_last_close - g_atr14 * strategy_trail_atr_mult);
         if(target_sl > 0.0 && (current_sl <= 0.0 || target_sl > current_sl + point * 0.5))
           {
            QM_TM_MoveSL(ticket, target_sl, "BANDY_ADX_TRAIL_LONG");
           }
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double target_sl = QM_TM_NormalizePrice(_Symbol, g_last_close + g_atr14 * strategy_trail_atr_mult);
         if(target_sl > 0.0 && (current_sl <= 0.0 || target_sl < current_sl - point * 0.5))
           {
            QM_TM_MoveSL(ticket, target_sl, "BANDY_ADX_TRAIL_SHORT");
           }
        }
     }
  }

bool Strategy_ExitSignal()
  {
   if(!g_state_valid)
      return false;

   const long magic = (long)QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int total = PositionsTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      // Reverse on opposite crossover + ADX gate
      if(ptype == POSITION_TYPE_BUY && g_fast1 < g_slow1 && g_fast2 >= g_slow2 && g_adx1 >= strategy_adx_threshold)
         return true;
      if(ptype == POSITION_TYPE_SELL && g_fast1 > g_slow1 && g_fast2 <= g_slow2 && g_adx1 >= strategy_adx_threshold)
         return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// =============================================================================
// Framework wiring
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"bandy-adx-regime-filter-trend\",\"ea\":\"QM5_9720_bandy-adx-regime-filter-trend\"}");
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

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
