#property strict
#property version   "5.0"
#property description "QM5_10899 Muranno MFI HMA Scalping Trend Filter"

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
input int    qm_ea_id                   = 10899;
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
input ENUM_TIMEFRAMES strategy_signal_tf       = PERIOD_M15;
input int             strategy_sma_period      = 200;
input int             strategy_mfi_period      = 21;
input int             strategy_mfi_sma_period  = 18;
input double          strategy_mfi_midline     = 50.0;
input int             strategy_hma_period      = 65;
input int             strategy_atr_period      = 14;
input double          strategy_atr_sl_mult     = 1.0;
input double          strategy_spread_stop_frac = 0.20;
input int             strategy_max_hold_bars   = 24;

bool Strategy_LoadMfiRates(MqlRates &rates[])
  {
   if(strategy_mfi_period <= 0 || strategy_mfi_sma_period <= 0)
      return false;

   const int needed = strategy_mfi_period + strategy_mfi_sma_period + 1;
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_signal_tf, 1, needed, rates); // perf-allowed: bounded closed-bar MFI/SMA window; callers are QM_IsNewBar-gated
   return (copied >= needed);
  }

double Strategy_MfiFromRates(const MqlRates &rates[], const int shift)
  {
   if(shift < 1 || strategy_mfi_period <= 0)
      return 50.0;

   const int offset = shift - 1;
   double positive_flow = 0.0;
   double negative_flow = 0.0;

   for(int i = 0; i < strategy_mfi_period; ++i)
     {
      const int now_idx = offset + i;
      const int prev_idx = now_idx + 1;
      if(prev_idx >= ArraySize(rates))
         break;

      const double typical_now = (rates[now_idx].high + rates[now_idx].low + rates[now_idx].close) / 3.0;
      const double typical_prev = (rates[prev_idx].high + rates[prev_idx].low + rates[prev_idx].close) / 3.0;
      const double raw_flow = typical_now * (double)rates[now_idx].tick_volume;

      if(typical_now > typical_prev)
         positive_flow += raw_flow;
      else if(typical_now < typical_prev)
         negative_flow += raw_flow;
     }

   if(negative_flow <= 0.0 && positive_flow > 0.0)
      return 100.0;
   if(positive_flow <= 0.0 && negative_flow > 0.0)
      return 0.0;
   if(positive_flow <= 0.0 && negative_flow <= 0.0)
      return 50.0;

   const double ratio = positive_flow / negative_flow;
   return 100.0 - (100.0 / (1.0 + ratio));
  }

double Strategy_MfiSmaFromRates(const MqlRates &rates[], const int shift)
  {
   if(strategy_mfi_sma_period <= 0)
      return 50.0;

   double sum = 0.0;
   for(int i = 0; i < strategy_mfi_sma_period; ++i)
      sum += Strategy_MfiFromRates(rates, shift + i);
   return sum / (double)strategy_mfi_sma_period;
  }

bool Strategy_HasOurPosition(ENUM_POSITION_TYPE &position_type, datetime &open_time)
  {
   position_type = POSITION_TYPE_BUY;
   open_time = 0;

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
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

int Strategy_EntryDirection()
  {
   if(_Period != strategy_signal_tf ||
      strategy_sma_period <= 0 ||
      strategy_hma_period <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_spread_stop_frac < 0.0 ||
      strategy_max_hold_bars <= 0)
      return 0;

   MqlRates rates[];
   if(!Strategy_LoadMfiRates(rates))
      return 0;

   const double mfi_now = Strategy_MfiFromRates(rates, 1);
   const double mfi_prev = Strategy_MfiFromRates(rates, 2);
   const double mfi_sma_now = Strategy_MfiSmaFromRates(rates, 1);
   const double mfi_sma_prev = Strategy_MfiSmaFromRates(rates, 2);

   const double close_1 = QM_SMA(_Symbol, strategy_signal_tf, 1, 1, PRICE_CLOSE);
   const double open_1 = QM_SMA(_Symbol, strategy_signal_tf, 1, 1, PRICE_OPEN);
   const double sma_1 = QM_SMA(_Symbol, strategy_signal_tf, strategy_sma_period, 1, PRICE_CLOSE);
   const double hma_1 = QM_HMA(_Symbol, strategy_signal_tf, strategy_hma_period, 1, PRICE_CLOSE);
   if(close_1 <= 0.0 || open_1 <= 0.0 || sma_1 <= 0.0 || hma_1 <= 0.0)
      return 0;

   const bool mfi_cross_up = (mfi_prev <= mfi_sma_prev && mfi_now > mfi_sma_now && mfi_now < strategy_mfi_midline);
   const bool mfi_cross_down = (mfi_prev >= mfi_sma_prev && mfi_now < mfi_sma_now && mfi_now > strategy_mfi_midline);
   const bool candle_cross_up = (open_1 <= hma_1 && close_1 > hma_1);
   const bool candle_cross_down = (open_1 >= hma_1 && close_1 < hma_1);

   if(close_1 > sma_1 && mfi_cross_up && candle_cross_up && close_1 > open_1)
      return 1;
   if(close_1 < sma_1 && mfi_cross_down && candle_cross_down && close_1 < open_1)
      return -1;

   return 0;
  }

bool Strategy_PositionExitTriggered(const ENUM_POSITION_TYPE position_type)
  {
   MqlRates rates[];
   if(!Strategy_LoadMfiRates(rates))
      return false;

   const double mfi_now = Strategy_MfiFromRates(rates, 1);
   const double mfi_prev = Strategy_MfiFromRates(rates, 2);
   const double mfi_sma_now = Strategy_MfiSmaFromRates(rates, 1);
   const double mfi_sma_prev = Strategy_MfiSmaFromRates(rates, 2);

   const double close_1 = QM_SMA(_Symbol, strategy_signal_tf, 1, 1, PRICE_CLOSE);
   const double open_1 = QM_SMA(_Symbol, strategy_signal_tf, 1, 1, PRICE_OPEN);
   const double hma_1 = QM_HMA(_Symbol, strategy_signal_tf, strategy_hma_period, 1, PRICE_CLOSE);
   if(close_1 <= 0.0 || open_1 <= 0.0 || hma_1 <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY)
     {
      const bool mfi_exit = (mfi_prev >= mfi_sma_prev && mfi_now < mfi_sma_now);
      return (mfi_exit || close_1 < hma_1 || close_1 < open_1);
     }

   if(position_type == POSITION_TYPE_SELL)
     {
      const bool mfi_exit = (mfi_prev <= mfi_sma_prev && mfi_now > mfi_sma_now);
      return (mfi_exit || close_1 > hma_1 || close_1 > open_1);
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter (time, spread, news): framework handles news/time gates;
   // card adds spread cap at 20% of ATR stop distance.
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0 || strategy_spread_stop_frac <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0)
      return false;

   const double stop_points = (atr * strategy_atr_sl_mult) / point;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(stop_points <= 0.0 || spread_points <= 0)
      return false;

   return ((double)spread_points > stop_points * strategy_spread_stop_frac);
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

   ENUM_POSITION_TYPE position_type;
   datetime open_time;
   if(Strategy_HasOurPosition(position_type, open_time))
      return false;

   const int direction = Strategy_EntryDirection();
   if(direction == 0)
      return false;

   const QM_OrderType side = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double sl_points = MathAbs(entry - sl) / point;
   if(QM_LotsForRisk(_Symbol, sl_points) <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "MURANNO_MFI_HMA_LONG" : "MURANNO_MFI_HMA_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Trade Management: no trailing stop, partial close, or break-even rule in
   // the card. Position protection is the initial ATR stop plus close rules.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   datetime open_time;
   if(!Strategy_HasOurPosition(position_type, open_time))
      return false;

   if(!QM_IsNewBar(_Symbol, strategy_signal_tf))
      return false;

   const int seconds_per_bar = PeriodSeconds(strategy_signal_tf);
   if(open_time > 0 && seconds_per_bar > 0)
     {
      const int max_hold_seconds = strategy_max_hold_bars * seconds_per_bar;
      if((TimeCurrent() - open_time) >= max_hold_seconds)
         return true;
     }

   return Strategy_PositionExitTriggered(position_type);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: no card-specific override; defer to framework P8 gate.
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
