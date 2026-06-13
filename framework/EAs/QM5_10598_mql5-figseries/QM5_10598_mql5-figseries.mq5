#property strict
#property version   "5.0"
#property description "QM5_10598 mql5-figseries"

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
input int    qm_ea_id                   = 10598;
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
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
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
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_start_hour        = 8;
input int    strategy_start_minute      = 0;
input int    strategy_stop_hour         = 0;
input int    strategy_stop_minute       = 0;
input int    strategy_fig_start_period  = 6;
input int    strategy_fig_step          = 6;
input int    strategy_fig_total         = 36;
input ENUM_MA_METHOD strategy_fig_ma_type = MODE_EMA;
input ENUM_APPLIED_PRICE strategy_fig_price = PRICE_CLOSE;
input int    strategy_signal_shift      = 1;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

int g_cached_figurelli_signal = 0;

bool Strategy_TimeEquals(const datetime value, const int hour, const int minute)
  {
   if(hour < 0 || hour > 23 || minute < 0 || minute > 59)
      return false;

   MqlDateTime dt;
   TimeToStruct(value, dt);
   return (dt.hour == hour && dt.min == minute);
  }

bool Strategy_StopTimeReached(const datetime value)
  {
   if(strategy_stop_hour < 0)
      return false;
   if(strategy_stop_hour > 23 || strategy_stop_minute < 0 || strategy_stop_minute > 59)
      return false;

   MqlDateTime dt;
   TimeToStruct(value, dt);

   if(strategy_stop_hour < strategy_start_hour)
     {
      if(dt.hour < strategy_start_hour)
        {
         if(dt.hour > strategy_stop_hour)
            return true;
         if(dt.hour == strategy_stop_hour && dt.min >= strategy_stop_minute)
            return true;
        }
      return false;
     }

   if(dt.hour > strategy_stop_hour)
      return true;
   if(dt.hour == strategy_stop_hour && dt.min >= strategy_stop_minute)
      return true;
   return false;
  }

double Strategy_MAValue(const int period, const int shift)
  {
   if(period <= 0 || shift <= 0)
      return 0.0;

   switch(strategy_fig_ma_type)
     {
      case MODE_SMA:
         return QM_SMA(_Symbol, _Period, period, shift, strategy_fig_price);
      case MODE_EMA:
         return QM_EMA(_Symbol, _Period, period, shift, strategy_fig_price);
      case MODE_SMMA:
         return QM_SMMA(_Symbol, _Period, period, shift, strategy_fig_price);
      case MODE_LWMA:
         return QM_LWMA(_Symbol, _Period, period, shift, strategy_fig_price);
     }

   return QM_EMA(_Symbol, _Period, period, shift, strategy_fig_price);
  }

int Strategy_FigurelliSignal(const int shift)
  {
   if(strategy_fig_start_period <= 0 || strategy_fig_step <= 0 ||
      strategy_fig_total <= 0 || strategy_fig_total > 50 || shift <= 0)
      return 0;

   const double close_value = QM_SMA(_Symbol, _Period, 1, shift, PRICE_CLOSE);
   if(close_value <= 0.0)
      return 0;

   int above_count = 0;
   int below_count = 0;
   for(int index = 0; index < strategy_fig_total; ++index)
     {
      const int ma_period = strategy_fig_start_period + strategy_fig_step * index;
      const double ma_value = Strategy_MAValue(ma_period, shift);
      if(ma_value <= 0.0)
         return 0;

      if(close_value > ma_value)
         above_count++;
      else if(close_value < ma_value)
         below_count++;
     }

   const int histogram = above_count - below_count;
   if(histogram > 0)
      return 1;
   if(histogram < 0)
      return -1;
   return 0;
  }

bool Strategy_HasOurPosition()
  {
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }

   return false;
  }

bool Strategy_ReadOurPositionType(ENUM_POSITION_TYPE &position_type)
  {
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

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_signal_shift <= 0 || strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return false;

   g_cached_figurelli_signal = Strategy_FigurelliSignal(strategy_signal_shift);
   if(g_cached_figurelli_signal == 0)
      return false;
   if(Strategy_HasOurPosition())
      return false;
   if(!Strategy_TimeEquals(TimeCurrent(), strategy_start_hour, strategy_start_minute))
      return false;

   const QM_OrderType side = (g_cached_figurelli_signal > 0) ? QM_SELL : QM_BUY;
   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.type = side;
   req.sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "FIGURELLI_BELOW_ZERO_LONG" : "FIGURELLI_ABOVE_ZERO_SHORT";
   return (req.sl > 0.0);
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   if(!Strategy_ReadOurPositionType(position_type))
      return false;

   if(Strategy_StopTimeReached(TimeCurrent()))
      return true;

   if(position_type == POSITION_TYPE_BUY && g_cached_figurelli_signal > 0)
      return true;
   if(position_type == POSITION_TYPE_SELL && g_cached_figurelli_signal < 0)
      return true;

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
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
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
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
