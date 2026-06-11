#property strict
#property version   "5.0"
#property description "QM5_9700 ForexFactory Roadmap Channel-Cross M15"

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
input int    qm_ea_id                   = 9700;
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
input int    strategy_channel_ema_period       = 34;
input int    strategy_trend_ema_period         = 200;
input int    strategy_slope_lookback_bars      = 8;
input int    strategy_prior_inside_bars        = 3;
input int    strategy_rsi_period               = 14;
input double strategy_rsi_long_threshold       = 52.0;
input double strategy_rsi_short_threshold      = 48.0;
input int    strategy_atr_period               = 14;
input double strategy_min_channel_width_atr    = 0.35;
input double strategy_sl_atr_buffer            = 0.25;
input double strategy_tp_r_multiple            = 1.70;
input int    strategy_time_stop_bars           = 20;
input int    strategy_late_friday_cutoff_hour  = 16;

double Strategy_Close(const int shift)
  {
   // perf-allowed: bounded closed-bar price read for bespoke channel-cross logic.
   return iClose(_Symbol, _Period, shift);
  }

bool Strategy_LateFridayEntryWindow()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.day_of_week == 5 && dt.hour >= strategy_late_friday_cutoff_hour);
  }

bool Strategy_ChannelValues(const int shift,
                            double &upper,
                            double &middle,
                            double &lower,
                            double &atr)
  {
   upper = QM_EMA(_Symbol, _Period, strategy_channel_ema_period, shift, PRICE_HIGH);
   middle = QM_EMA(_Symbol, _Period, strategy_channel_ema_period, shift, PRICE_CLOSE);
   lower = QM_EMA(_Symbol, _Period, strategy_channel_ema_period, shift, PRICE_LOW);
   atr = QM_ATR(_Symbol, _Period, strategy_atr_period, shift);
   return (upper > 0.0 && middle > 0.0 && lower > 0.0 && atr > 0.0 && upper > lower);
  }

bool Strategy_ChannelWideEnough()
  {
   double upper, middle, lower, atr;
   if(!Strategy_ChannelValues(1, upper, middle, lower, atr))
      return false;
   return ((upper - lower) >= strategy_min_channel_width_atr * atr);
  }

bool Strategy_PriorClosesInsideOrBelow()
  {
   for(int i = 2; i < 2 + strategy_prior_inside_bars; ++i)
     {
      const double close_i = Strategy_Close(i);
      const double upper_i = QM_EMA(_Symbol, _Period, strategy_channel_ema_period, i, PRICE_HIGH);
      if(close_i <= 0.0 || upper_i <= 0.0)
         return false;
      if(close_i > upper_i)
         return false;
     }
   return true;
  }

bool Strategy_PriorClosesInsideOrAbove()
  {
   for(int i = 2; i < 2 + strategy_prior_inside_bars; ++i)
     {
      const double close_i = Strategy_Close(i);
      const double lower_i = QM_EMA(_Symbol, _Period, strategy_channel_ema_period, i, PRICE_LOW);
      if(close_i <= 0.0 || lower_i <= 0.0)
         return false;
      if(close_i < lower_i)
         return false;
     }
   return true;
  }

bool Strategy_SelectOurPosition(ENUM_POSITION_TYPE &position_type, datetime &opened_at)
  {
   const int magic = QM_FrameworkMagic();
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
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
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
   // Card entry filters are evaluated inside Strategy_EntrySignal so open
   // positions can still be managed and closed during filtered windows.
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

   if(strategy_channel_ema_period < 2 ||
      strategy_trend_ema_period < 2 ||
      strategy_slope_lookback_bars < 1 ||
      strategy_prior_inside_bars < 1 ||
      strategy_rsi_period < 2 ||
      strategy_atr_period < 1 ||
      strategy_tp_r_multiple <= 0.0)
      return false;

   if(Strategy_LateFridayEntryWindow())
      return false;
   if(!Strategy_ChannelWideEnough())
      return false;

   double upper_1, middle_1, lower_1, atr_1;
   double upper_2, middle_2, lower_2, atr_2;
   double upper_slope, middle_slope, lower_slope, atr_slope;
   if(!Strategy_ChannelValues(1, upper_1, middle_1, lower_1, atr_1) ||
      !Strategy_ChannelValues(2, upper_2, middle_2, lower_2, atr_2) ||
      !Strategy_ChannelValues(1 + strategy_slope_lookback_bars,
                              upper_slope, middle_slope, lower_slope, atr_slope))
      return false;

   const double close_1 = Strategy_Close(1);
   const double close_2 = Strategy_Close(2);
   if(close_1 <= 0.0 || close_2 <= 0.0)
      return false;

   const double rsi_1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1, PRICE_CLOSE);
   const double rsi_2 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2, PRICE_CLOSE);
   const double ema_200 = QM_EMA(_Symbol, _Period, strategy_trend_ema_period, 1, PRICE_CLOSE);
   if(rsi_1 <= 0.0 || rsi_2 <= 0.0 || ema_200 <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   if(middle_1 > middle_slope &&
      close_2 <= upper_2 &&
      close_1 > upper_1 &&
      Strategy_PriorClosesInsideOrBelow() &&
      rsi_1 > strategy_rsi_long_threshold &&
      rsi_1 > rsi_2 &&
      close_1 > ema_200)
     {
      const double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl = lower_1 - strategy_sl_atr_buffer * atr_1;
      if(entry_price <= 0.0 || sl <= 0.0 || sl >= entry_price)
         return false;
      const double risk = entry_price - sl;
      req.type = QM_BUY;
      req.sl = sl;
      req.tp = entry_price + strategy_tp_r_multiple * risk;
      req.reason = "ROADMAP_CHANNEL_LONG";
      return true;
     }

   if(middle_1 < middle_slope &&
      close_2 >= lower_2 &&
      close_1 < lower_1 &&
      Strategy_PriorClosesInsideOrAbove() &&
      rsi_1 < strategy_rsi_short_threshold &&
      rsi_1 < rsi_2 &&
      close_1 < ema_200)
     {
      const double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl = upper_1 + strategy_sl_atr_buffer * atr_1;
      if(entry_price <= 0.0 || sl <= 0.0 || sl <= entry_price)
         return false;
      const double risk = sl - entry_price;
      req.type = QM_SELL;
      req.sl = sl;
      req.tp = entry_price - strategy_tp_r_multiple * risk;
      req.reason = "ROADMAP_CHANNEL_SHORT";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, partial close, or pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   datetime opened_at;
   if(!Strategy_SelectOurPosition(position_type, opened_at))
      return false;

   if(strategy_time_stop_bars > 0)
     {
      const int seconds_per_bar = PeriodSeconds(PERIOD_M15);
      if(seconds_per_bar > 0 && TimeCurrent() - opened_at >= strategy_time_stop_bars * seconds_per_bar)
         return true;
     }

   double upper, middle, lower, atr;
   if(!Strategy_ChannelValues(1, upper, middle, lower, atr))
      return false;

   const double close_1 = Strategy_Close(1);
   if(close_1 <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY && close_1 <= upper && close_1 >= lower)
      return true;
   if(position_type == POSITION_TYPE_SELL && close_1 >= lower && close_1 <= upper)
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
