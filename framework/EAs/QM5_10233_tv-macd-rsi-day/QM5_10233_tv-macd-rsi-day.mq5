#property strict
#property version   "5.0"
#property description "QM5_10233 TradingView MACD RSI EMA Day Trade"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  - closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        - risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() - use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly -
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
input int    qm_ea_id                   = 10233;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 - Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 - only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_entry_tf            = PERIOD_M5;
input ENUM_TIMEFRAMES strategy_confirm_tf          = PERIOD_M15;
input int             strategy_ema_fast            = 9;
input int             strategy_ema_slow            = 21;
input int             strategy_macd_fast           = 12;
input int             strategy_macd_slow           = 26;
input int             strategy_macd_signal         = 9;
input int             strategy_rsi_period          = 14;
input double          strategy_long_rsi_min        = 40.0;
input double          strategy_long_rsi_max        = 70.0;
input double          strategy_short_rsi_min       = 30.0;
input double          strategy_short_rsi_max       = 60.0;
input int             strategy_volume_sma_period   = 20;
input double          strategy_volume_mult         = 1.2;
input int             strategy_atr_period          = 14;
input double          strategy_initial_atr_mult    = 2.0;
input double          strategy_trail_atr_mult      = 1.5;
input int             strategy_min_atr_points      = 1;
input int             strategy_entry_start_hhmm_ny = 930;
input int             strategy_entry_end_hhmm_ny   = 1130;
input int             strategy_eod_flat_hhmm_ny    = 1600;
input int             strategy_max_spread_points   = 0;

datetime Strategy_BrokerToNewYork(const datetime broker_time)
  {
   const datetime utc_time = QM_BrokerToUTC(broker_time);
   const int ny_offset_hours = QM_IsUSDSTUTC(utc_time) ? -4 : -5;
   return utc_time + ny_offset_hours * 3600;
  }

int Strategy_HHMM(const datetime value)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(value, dt);
   return dt.hour * 100 + dt.min;
  }

bool Strategy_HHMMInRange(const int value, const int start_hhmm, const int end_hhmm)
  {
   if(start_hhmm <= end_hhmm)
      return (value >= start_hhmm && value <= end_hhmm);
   return (value >= start_hhmm || value <= end_hhmm);
  }

int Strategy_NewYorkHHMM(const datetime broker_time)
  {
   return Strategy_HHMM(Strategy_BrokerToNewYork(broker_time));
  }

bool Strategy_IsEntryWindowNY(const datetime broker_time)
  {
   return Strategy_HHMMInRange(Strategy_NewYorkHHMM(broker_time),
                               strategy_entry_start_hhmm_ny,
                               strategy_entry_end_hhmm_ny);
  }

bool Strategy_IsEODFlatNY(const datetime broker_time)
  {
   return (Strategy_NewYorkHHMM(broker_time) >= strategy_eod_flat_hhmm_ny);
  }

bool Strategy_SelectOpenPosition(ulong &ticket)
  {
   ticket = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = t;
      return true;
     }

   return false;
  }

bool Strategy_HasOpenPosition()
  {
   ulong ticket = 0;
   return Strategy_SelectOpenPosition(ticket);
  }

double Strategy_Close(const ENUM_TIMEFRAMES tf, const int shift)
  {
   return iClose(_Symbol, tf, shift); // perf-allowed: single closed-bar close read; no framework close reader exists.
  }

double Strategy_VolumeSMA(const ENUM_TIMEFRAMES tf, const int period)
  {
   if(period <= 0)
      return 0.0;

   double sum = 0.0;
   for(int shift = 1; shift <= period; ++shift)
     {
      const long volume = iVolume(_Symbol, tf, shift); // perf-allowed: bounded tick-volume SMA, called from new-bar entry path or O(1) exit check.
      if(volume <= 0)
         return 0.0;
      sum += (double)volume;
     }

   return sum / (double)period;
  }

void Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_ParamsOK()
  {
   return (strategy_ema_fast > 0 &&
           strategy_ema_slow > strategy_ema_fast &&
           strategy_macd_fast > 0 &&
           strategy_macd_slow > strategy_macd_fast &&
           strategy_macd_signal > 0 &&
           strategy_rsi_period > 0 &&
           strategy_volume_sma_period > 0 &&
           strategy_volume_mult > 0.0 &&
           strategy_atr_period > 0 &&
           strategy_initial_atr_mult > 0.0 &&
           strategy_trail_atr_mult > 0.0 &&
           strategy_min_atr_points >= 0);
  }

int Strategy_DirectionSignal(const bool require_volume_atr)
  {
   if(!Strategy_ParamsOK())
      return 0;

   const ENUM_TIMEFRAMES entry_tf = (strategy_entry_tf == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)_Period : strategy_entry_tf;
   const ENUM_TIMEFRAMES confirm_tf = (strategy_confirm_tf == PERIOD_CURRENT) ? entry_tf : strategy_confirm_tf;

   const double close_1 = Strategy_Close(entry_tf, 1);
   const double ema_fast_1 = QM_EMA(_Symbol, entry_tf, strategy_ema_fast, 1);
   const double ema_slow_1 = QM_EMA(_Symbol, entry_tf, strategy_ema_slow, 1);
   const double confirm_fast_1 = QM_EMA(_Symbol, confirm_tf, strategy_ema_fast, 1);
   const double confirm_slow_1 = QM_EMA(_Symbol, confirm_tf, strategy_ema_slow, 1);
   if(close_1 <= 0.0 || ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 ||
      confirm_fast_1 <= 0.0 || confirm_slow_1 <= 0.0)
      return 0;

   const double macd_main_1 = QM_MACD_Main(_Symbol, entry_tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_sig_1 = QM_MACD_Signal(_Symbol, entry_tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double rsi_1 = QM_RSI(_Symbol, entry_tf, strategy_rsi_period, 1);
   if(rsi_1 <= 0.0)
      return 0;

   if(require_volume_atr)
     {
      const long volume_1 = iVolume(_Symbol, entry_tf, 1); // perf-allowed: single closed-bar tick volume read in framework new-bar-gated signal.
      const double volume_sma = Strategy_VolumeSMA(entry_tf, strategy_volume_sma_period);
      if(volume_1 <= 0 || volume_sma <= 0.0 || (double)volume_1 <= volume_sma * strategy_volume_mult)
         return 0;

      const double atr_1 = QM_ATR(_Symbol, entry_tf, strategy_atr_period, 1);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(atr_1 <= 0.0 || point <= 0.0 || atr_1 < (double)strategy_min_atr_points * point)
         return 0;
     }

   if(ema_fast_1 > ema_slow_1 &&
      close_1 > ema_fast_1 &&
      confirm_fast_1 > confirm_slow_1 &&
      macd_main_1 > macd_sig_1 &&
      rsi_1 >= strategy_long_rsi_min &&
      rsi_1 <= strategy_long_rsi_max)
      return 1;

   if(ema_fast_1 < ema_slow_1 &&
      close_1 < ema_fast_1 &&
      confirm_fast_1 < confirm_slow_1 &&
      macd_main_1 < macd_sig_1 &&
      rsi_1 >= strategy_short_rsi_min &&
      rsi_1 <= strategy_short_rsi_max)
      return -1;

   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks - implement these against the card mechanically.
// -----------------------------------------------------------------------------

// No Trade Filter: time and spread gates for new entries only. Open positions
// remain manageable so EOD flat and ATR trailing cannot be blocked.
bool Strategy_NoTradeFilter()
  {
   if(!Strategy_ParamsOK())
      return true;

   if(Strategy_HasOpenPosition())
      return false;

   if(!Strategy_IsEntryWindowNY(TimeCurrent()))
      return true;

   if(strategy_max_spread_points > 0 &&
      SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > strategy_max_spread_points)
      return true;

   return false;
  }

// Trade Entry: M5 EMA/MACD/RSI/tick-volume momentum signal with M15 trend confirmation.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);

   if(Strategy_HasOpenPosition())
      return false;

   if(!Strategy_IsEntryWindowNY(TimeCurrent()))
      return false;

   const int direction = Strategy_DirectionSignal(true);
   if(direction == 0)
      return false;

   const ENUM_TIMEFRAMES entry_tf = (strategy_entry_tf == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)_Period : strategy_entry_tf;
   const double atr_1 = QM_ATR(_Symbol, entry_tf, strategy_atr_period, 1);
   if(atr_1 <= 0.0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr_1, strategy_initial_atr_mult);
   if(req.sl <= 0.0)
      return false;

   req.tp = 0.0;
   req.reason = (direction > 0) ? "MACD_RSI_EMA_DAY_LONG" : "MACD_RSI_EMA_DAY_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   return true;
  }

// Trade Management: ATR trailing stop after entry.
void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   if(Strategy_SelectOpenPosition(ticket))
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
  }

// Trade Close: New York 16:00 flat, or opposite closed-bar signal.
bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   if(!Strategy_SelectOpenPosition(ticket))
      return false;

   if(Strategy_IsEODFlatNY(TimeCurrent()))
      return true;

   const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const int direction = Strategy_DirectionSignal(false);
   if(pos_type == POSITION_TYPE_BUY && direction < 0)
      return true;
   if(pos_type == POSITION_TYPE_SELL && direction > 0)
      return true;

   return false;
  }

// News Filter Hook: no card-specific override; framework news filter remains active.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
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
   // FW1 - 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes - EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 - emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
