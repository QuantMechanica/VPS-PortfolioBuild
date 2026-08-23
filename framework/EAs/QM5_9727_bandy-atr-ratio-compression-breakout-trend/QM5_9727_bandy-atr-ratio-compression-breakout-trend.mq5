#property strict
#property version   "5.0"
#property description "QM5_9727 Bandy ATR-Ratio Compression Breakout Trend D1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_9727
// Bandy ATR-Ratio Compression Breakout (Trend, Long/Short)
// Source: Howard Bandy, "Quantitative Technical Analysis", 2015 (ISBN 978-0-9791037-7-1)
// Strategy:
//   - Calculate ATR(5)/ATR(20) ratio on D1.
//   - Compression flag: ratio <= 0.65 on prior/current closed bar.
//   - Donchian(20) breakout: Long if close[1] > Highest(High, 20 bars prior to bar 1).
//                           Short if close[1] < Lowest(Low, 20 bars prior to bar 1).
//   - Exit: 2.5x ATR(14) ratcheting trailing stop, 45-day hard time stop, reverse on opposite signal.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9727;
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
input int    strategy_atr_short_period      = 5;     // Short ATR Period (default 5)
input int    strategy_atr_long_period       = 20;    // Long ATR Period (default 20)
input double strategy_compression_threshold = 0.65;  // ATR Ratio Compression Threshold (default 0.65)
input int    strategy_donchian_period       = 20;    // Donchian Channel Lookback Period (default 20)
input int    strategy_trail_atr_period      = 14;    // ATR Period for Trailing Stop (default 14)
input double strategy_trail_atr_mult        = 2.5;   // ATR Multiplier for Trailing Stop (default 2.5)
input int    strategy_max_hold_days         = 45;    // Hard Time Stop in Trading Days (default 45)

// --- Cached closed-bar state (advanced once per D1 bar) ---
static double g_donch_hi     = -DBL_MAX;
static double g_donch_lo     = DBL_MAX;
static double g_last_close   = 0.0;
static double g_atr14        = 0.0;
static bool   g_compressed   = false;
static bool   g_state_valid  = false;

void AdvanceState_OnNewBar()
  {
   g_donch_hi    = -DBL_MAX;
   g_donch_lo    = DBL_MAX;
   g_last_close  = 0.0;
   g_atr14       = 0.0;
   g_compressed  = false;
   g_state_valid = false;

   const int required_bars = strategy_donchian_period + strategy_atr_long_period + 5;
   if(Bars(_Symbol, PERIOD_D1) < required_bars)
      return;

   // Read ATR values for compression filter
   const double atr_s1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_short_period, 1);
   const double atr_l1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_long_period, 1);
   const double atr_s2 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_short_period, 2);
   const double atr_l2 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_long_period, 2);

   if(atr_l1 <= 0.0 || atr_l2 <= 0.0)
      return;

   const bool comp1 = ((atr_s1 / atr_l1) <= strategy_compression_threshold);
   const bool comp2 = ((atr_s2 / atr_l2) <= strategy_compression_threshold);
   g_compressed = (comp1 || comp2);

   // Read 20-bar Donchian channel prior to closed bar 1 (shifts 2 to strategy_donchian_period + 1)
   for(int s = 2; s <= strategy_donchian_period + 1; ++s)
     {
      const double hi = iHigh(_Symbol, PERIOD_D1, s);
      const double lo = iLow(_Symbol, PERIOD_D1, s);
      if(hi <= 0.0 || lo <= 0.0 || hi < lo)
        {
         g_donch_hi = -DBL_MAX;
         return;
        }
      if(hi > g_donch_hi) g_donch_hi = hi;
      if(lo < g_donch_lo) g_donch_lo = lo;
     }

   g_last_close = iClose(_Symbol, PERIOD_D1, 1);
   g_atr14      = QM_ATR(_Symbol, PERIOD_D1, strategy_trail_atr_period, 1);

   g_state_valid = (g_donch_hi > 0.0 && g_donch_lo > 0.0 &&
                    g_donch_hi > g_donch_lo && g_last_close > 0.0 &&
                    g_atr14 > 0.0);
  }

// =============================================================================
// Strategy hooks
// =============================================================================

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(strategy_atr_short_period <= 0 || strategy_atr_long_period <= 0 ||
      strategy_donchian_period <= 0 || strategy_trail_atr_period <= 0 ||
      strategy_trail_atr_mult <= 0.0 || strategy_compression_threshold <= 0.0)
      return true;
   return (!g_state_valid);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_state_valid || !g_compressed)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   // One position per magic
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   int direction = 0;
   if(g_last_close > g_donch_hi)
      direction = 1;
   else if(g_last_close < g_donch_lo)
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
   req.reason             = (direction > 0) ? "BANDY_ATR_RATIO_LONG" : "BANDY_ATR_RATIO_SHORT";
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

      // 1. Hard Time Stop (45 trading days)
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int held_days = QM_TM_HeldPeriods(_Symbol, PERIOD_D1, open_time);
      if(held_days >= strategy_max_hold_days)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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
            QM_TM_MoveSL(ticket, target_sl, "BANDY_RATCHET_TRAIL_LONG");
           }
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double target_sl = QM_TM_NormalizePrice(_Symbol, g_last_close + g_atr14 * strategy_trail_atr_mult);
         if(target_sl > 0.0 && (current_sl <= 0.0 || target_sl < current_sl - point * 0.5))
           {
            QM_TM_MoveSL(ticket, target_sl, "BANDY_RATCHET_TRAIL_SHORT");
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
      // Close long on opposite channel breakout or short on opposite channel breakout
      if(ptype == POSITION_TYPE_BUY && g_last_close < g_donch_lo)
         return true;
      if(ptype == POSITION_TYPE_SELL && g_last_close > g_donch_hi)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"bandy-atr-ratio-compression-breakout-trend\",\"ea\":\"QM5_9727_bandy-atr-ratio-compression-breakout-trend\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   // Q08 evidence lifecycle: this must precede every early return.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

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
