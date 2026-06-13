#property strict
#property version   "5.0"
#property description "QM5_10614 MQL5 3rdGenerationXMA Direction Change"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10614;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_xma_length        = 50;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.5;
input int    strategy_time_stop_h4_bars = 18;
input bool   strategy_close_on_opposite = true;

int      g_strategy_cached_signal = 0;
datetime g_strategy_cached_bar_time = 0;

double Strategy_TypicalPrice(const MqlRates &bar)
  {
   return (bar.high + bar.low + bar.close) / 3.0;
  }

bool Strategy_HasOurPosition(ENUM_POSITION_TYPE &type, datetime &opened)
  {
   type = POSITION_TYPE_BUY;
   opened = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      opened = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_RefreshSignalCache()
  {
   g_strategy_cached_signal = 0;
   g_strategy_cached_bar_time = 0;

   if(strategy_xma_length < 2)
      return false;

   const int sampling_period = strategy_xma_length * 2;
   const int bars_needed = MathMax(220, sampling_period + strategy_xma_length + 40);

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, bars_needed, rates); // perf-allowed: source custom XMA calculation is run only from Strategy_EntrySignal after the framework QM_IsNewBar() gate.
   if(copied < sampling_period + strategy_xma_length + 3)
      return false;

   const double ema1_k = 2.0 / (sampling_period + 1.0);
   const double ema2_k = 2.0 / (strategy_xma_length + 1.0);
   const double lambda = (double)sampling_period / (double)strategy_xma_length;
   const double third_alpha = lambda * (sampling_period - 1.0) / (sampling_period - lambda);

   double ema1 = 0.0;
   double ema2 = 0.0;
   double xma_shift1 = 0.0;
   double xma_shift2 = 0.0;
   double xma_shift3 = 0.0;

   for(int i = copied - 1; i >= 0; --i)
     {
      const double price = Strategy_TypicalPrice(rates[i]);
      if(price <= 0.0)
         continue;

      if(ema1 <= 0.0)
         ema1 = price;
      else
         ema1 = ema1 + ema1_k * (price - ema1);

      if(ema2 <= 0.0)
         ema2 = ema1;
      else
         ema2 = ema2 + ema2_k * (ema1 - ema2);

      const double xma = (third_alpha + 1.0) * ema1 - third_alpha * ema2;
      if(i == 1)
         xma_shift1 = xma;
      else if(i == 2)
         xma_shift2 = xma;
      else if(i == 3)
         xma_shift3 = xma;
     }

   if(xma_shift1 <= 0.0 || xma_shift2 <= 0.0 || xma_shift3 <= 0.0)
      return false;

   const int dir_now = (xma_shift1 > xma_shift2) ? 1 : ((xma_shift1 < xma_shift2) ? -1 : 0);
   const int dir_prev = (xma_shift2 > xma_shift3) ? 1 : ((xma_shift2 < xma_shift3) ? -1 : 0);

   if(dir_prev <= 0 && dir_now > 0)
      g_strategy_cached_signal = 1;
   else if(dir_prev >= 0 && dir_now < 0)
      g_strategy_cached_signal = -1;

   g_strategy_cached_bar_time = rates[1].time;
   return true;
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_RefreshSignalCache())
      return false;

   ENUM_POSITION_TYPE pos_type;
   datetime opened = 0;
   if(Strategy_HasOurPosition(pos_type, opened))
      return false;

   if(g_strategy_cached_signal == 0)
      return false;

   const QM_OrderType side = (g_strategy_cached_signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (g_strategy_cached_signal > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                       : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (g_strategy_cached_signal > 0) ? "3GENXMA_DIR_LONG" : "3GENXMA_DIR_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card baseline has no trailing, partial close, or break-even management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE pos_type;
   datetime opened = 0;
   if(!Strategy_HasOurPosition(pos_type, opened))
      return false;

   if(strategy_time_stop_h4_bars > 0 && opened > 0)
     {
      const int seconds = PeriodSeconds(PERIOD_H4);
      if(seconds > 0 && TimeCurrent() >= opened + (datetime)(seconds * strategy_time_stop_h4_bars))
         return true;
     }

   if(!strategy_close_on_opposite || g_strategy_cached_signal == 0 || g_strategy_cached_bar_time <= opened)
      return false;

   if(pos_type == POSITION_TYPE_BUY && g_strategy_cached_signal < 0)
      return true;
   if(pos_type == POSITION_TYPE_SELL && g_strategy_cached_signal > 0)
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
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

