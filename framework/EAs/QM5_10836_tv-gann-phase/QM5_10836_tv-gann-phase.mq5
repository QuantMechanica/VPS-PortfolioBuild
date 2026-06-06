#property strict
#property version   "5.0"
#property description "QM5_10836 tv-gann-phase"

#include <QM/QM_Common.mqh>

enum StrategyEntryMode
  {
   ENTRY_EASY   = 0,
   ENTRY_MEDIUM = 1,
   ENTRY_STRICT = 2
  };

enum StrategyPhase
  {
   PHASE_ACCUM = 0,
   PHASE_MODER = 1,
   PHASE_EXPAN = 2,
   PHASE_ACCEL = 3
  };

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10836;
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
input int               strategy_pivot_lookback      = 5;
input int               strategy_pivot_scan_bars     = 50;
input int               strategy_atr_period          = 14;
input int               strategy_ema_fast            = 8;
input int               strategy_ema_slow            = 21;
input double            strategy_angle_weak_deg      = 5.0;
input double            strategy_angle_expansion_deg = 15.0;
input double            strategy_angle_accel_deg     = 30.0;
input double            strategy_atr_sl_mult         = 1.5;
input double            strategy_tp_rr               = 2.0;
input StrategyEntryMode strategy_entry_mode          = ENTRY_MEDIUM;

// -----------------------------------------------------------------------------
// Strategy helpers for the card's automatic pivot and phase logic.
// Raw OHLC reads are perf-allowed because pivot structure is bespoke and
// Strategy_EntrySignal is called only behind the framework QM_IsNewBar gate.
// -----------------------------------------------------------------------------

void Strategy_InitEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_IsPivotHigh(const int shift, const int radius)
  {
   if(shift <= radius || radius <= 0)
      return false;

   const double center = iHigh(_Symbol, _Period, shift); // perf-allowed
   if(center <= 0.0)
      return false;

   for(int j = 1; j <= radius; ++j)
     {
      const double newer = iHigh(_Symbol, _Period, shift - j); // perf-allowed
      const double older = iHigh(_Symbol, _Period, shift + j); // perf-allowed
      if(newer <= 0.0 || older <= 0.0)
         return false;
      if(center <= newer || center <= older)
         return false;
     }

   return true;
  }

bool Strategy_IsPivotLow(const int shift, const int radius)
  {
   if(shift <= radius || radius <= 0)
      return false;

   const double center = iLow(_Symbol, _Period, shift); // perf-allowed
   if(center <= 0.0)
      return false;

   for(int j = 1; j <= radius; ++j)
     {
      const double newer = iLow(_Symbol, _Period, shift - j); // perf-allowed
      const double older = iLow(_Symbol, _Period, shift + j); // perf-allowed
      if(newer <= 0.0 || older <= 0.0)
         return false;
      if(center >= newer || center >= older)
         return false;
     }

   return true;
  }

bool Strategy_FindPivot(const bool want_high,
                        const int min_shift,
                        int &pivot_shift,
                        double &pivot_price)
  {
   pivot_shift = 0;
   pivot_price = 0.0;

   const int radius = (strategy_pivot_lookback > 1) ? strategy_pivot_lookback : 1;
   const int min_scan = radius + 2;
   const int scan = (strategy_pivot_scan_bars > min_scan) ? strategy_pivot_scan_bars : min_scan;
   const int min_start = radius + 1;
   const int start_shift = (min_shift > min_start) ? min_shift : min_start;

   for(int shift = start_shift; shift <= scan; ++shift)
     {
      if(want_high)
        {
         if(!Strategy_IsPivotHigh(shift, radius))
            continue;
         pivot_shift = shift;
         pivot_price = iHigh(_Symbol, _Period, shift); // perf-allowed
         return (pivot_price > 0.0);
        }

      if(!Strategy_IsPivotLow(shift, radius))
         continue;
      pivot_shift = shift;
      pivot_price = iLow(_Symbol, _Period, shift); // perf-allowed
      return (pivot_price > 0.0);
     }

   return false;
  }

StrategyPhase Strategy_ClassifyPhase(const double angle_degrees)
  {
   if(angle_degrees < strategy_angle_weak_deg)
      return PHASE_ACCUM;
   if(angle_degrees < strategy_angle_expansion_deg)
      return PHASE_MODER;
   if(angle_degrees < strategy_angle_accel_deg)
      return PHASE_EXPAN;
   return PHASE_ACCEL;
  }

bool Strategy_SwingPhase(const int high_shift,
                         const double high_price,
                         const int low_shift,
                         const double low_price,
                         StrategyPhase &phase)
  {
   phase = PHASE_ACCUM;

   const int bars_between = MathAbs(high_shift - low_shift);
   if(bars_between <= 0 || high_price <= 0.0 || low_price <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double atr_slope = MathAbs(high_price - low_price) / ((double)bars_between * atr);
   const double angle_degrees = MathArctan(atr_slope) * 57.29577951308232;
   phase = Strategy_ClassifyPhase(angle_degrees);
   return true;
  }

bool Strategy_ModeAllowsPhase(const StrategyPhase current_phase,
                              const StrategyPhase previous_phase)
  {
   if(strategy_entry_mode == ENTRY_EASY)
      return true;

   if(strategy_entry_mode == ENTRY_STRICT)
      return ((previous_phase == PHASE_ACCUM || previous_phase == PHASE_MODER) &&
              (current_phase == PHASE_EXPAN || current_phase == PHASE_ACCEL));

   return (current_phase == PHASE_MODER ||
           current_phase == PHASE_EXPAN ||
           current_phase == PHASE_ACCEL);
  }

bool Strategy_GetSignalContext(bool &bullish_swing,
                               StrategyPhase &current_phase,
                               StrategyPhase &previous_phase)
  {
   bullish_swing = false;
   current_phase = PHASE_ACCUM;
   previous_phase = PHASE_ACCUM;

   int high_shift = 0;
   int low_shift = 0;
   double high_price = 0.0;
   double low_price = 0.0;

   if(!Strategy_FindPivot(true, 0, high_shift, high_price))
      return false;
   if(!Strategy_FindPivot(false, 0, low_shift, low_price))
      return false;
   if(!Strategy_SwingPhase(high_shift, high_price, low_shift, low_price, current_phase))
      return false;

   bullish_swing = (high_shift < low_shift);

   int prev_high_shift = 0;
   int prev_low_shift = 0;
   double prev_high_price = 0.0;
   double prev_low_price = 0.0;
   const int latest_older_anchor = (high_shift > low_shift) ? high_shift : low_shift;
   const int older_than_current = latest_older_anchor + strategy_pivot_lookback + 1;
   if(Strategy_FindPivot(true, older_than_current, prev_high_shift, prev_high_price) &&
      Strategy_FindPivot(false, older_than_current, prev_low_shift, prev_low_price))
     {
      Strategy_SwingPhase(prev_high_shift, prev_high_price, prev_low_shift, prev_low_price, previous_phase);
     }

   return true;
  }

// -----------------------------------------------------------------------------
// No Trade Filter (time, spread, news)
// -----------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   // Card specifies no additional time or spread filter. Framework news,
   // Friday-close, and kill-switch gates remain active in OnTick.
   return false;
  }

// -----------------------------------------------------------------------------
// Trade Entry
// -----------------------------------------------------------------------------
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitEntryRequest(req);

   if(strategy_atr_period <= 0 ||
      strategy_ema_fast <= 0 ||
      strategy_ema_slow <= 0 ||
      strategy_ema_fast >= strategy_ema_slow ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_tp_rr <= 0.0)
      return false;

   bool bullish_swing = false;
   StrategyPhase phase = PHASE_ACCUM;
   StrategyPhase previous_phase = PHASE_ACCUM;
   if(!Strategy_GetSignalContext(bullish_swing, phase, previous_phase))
      return false;
   if(!Strategy_ModeAllowsPhase(phase, previous_phase))
      return false;

   const double ema_fast = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_fast, 1);
   const double ema_slow = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_slow, 1);
   const double open1 = iOpen(_Symbol, _Period, 1); // perf-allowed
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed
   if(ema_fast <= 0.0 || ema_slow <= 0.0 || open1 <= 0.0 || close1 <= 0.0)
      return false;

   if(bullish_swing && ema_fast > ema_slow && close1 > open1)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type = QM_BUY;
      req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
      req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_tp_rr);
      req.reason = "TV_GANN_PHASE_LONG";
      return (req.sl > 0.0 && req.tp > 0.0 && req.sl < entry && req.tp > entry);
     }

   if(!bullish_swing && ema_fast < ema_slow && close1 < open1)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.type = QM_SELL;
      req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
      req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_tp_rr);
      req.reason = "TV_GANN_PHASE_SHORT";
      return (req.sl > 0.0 && req.tp > 0.0 && req.sl > entry && req.tp < entry);
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Trade Management
// -----------------------------------------------------------------------------
void Strategy_ManageOpenPosition()
  {
   // Card disables source trailing and open-profit protection for the baseline.
  }

// -----------------------------------------------------------------------------
// Trade Close
// -----------------------------------------------------------------------------
bool Strategy_ExitSignal()
  {
   // Card baseline exits only through the fixed SL/TP bracket and framework close gates.
   return false;
  }

// -----------------------------------------------------------------------------
// News Filter Hook
// -----------------------------------------------------------------------------
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless the framework changes.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10836_tv-gann-phase\"}");
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
