#property strict
#property version   "5.0"
#property description "QM5_10631 Elite Trader OB ChoCh Retest"

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
input int    qm_ea_id                   = 10631;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
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
input int             strategy_atr_period              = 14;
input int             strategy_swing_width             = 3;
input double          strategy_choch_break_atr         = 0.10;
input double          strategy_ob_entry_fraction       = 0.50;
input double          strategy_ob_sl_atr               = 0.20;
input double          strategy_rr                      = 2.00;
input double          strategy_ob_max_height_atr       = 1.40;
input double          strategy_impulse_min_range_atr   = 0.80;
input int             strategy_same_dir_lookback_bars  = 20;
input int             strategy_pending_expiry_bars     = 10;
input int             strategy_time_exit_bars          = 40;
input int             strategy_ob_search_bars          = 12;
input int             strategy_history_bars            = 140;
input ENUM_TIMEFRAMES strategy_timeframe               = PERIOD_M30;

double   g_last_closed_close = 0.0;
datetime g_last_closed_time = 0;

double NormalizeStrategyPrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, _Digits);
  }

bool LoadStrategyRates(MqlRates &rates[], const int requested)
  {
   const int bars_to_copy = MathMax(requested, strategy_same_dir_lookback_bars + strategy_ob_search_bars + strategy_swing_width * 4 + 20);
   ArrayResize(rates, bars_to_copy);
   const int copied = CopyRates(_Symbol, strategy_timeframe, 0, bars_to_copy, rates); // perf-allowed: structural ChoCh/OB scan runs only inside closed-bar hook.
   if(copied < strategy_swing_width * 4 + 20)
      return false;
   ArraySetAsSeries(rates, true);
   return true;
  }

bool IsSwingHigh(MqlRates &rates[], const int total, const int shift, const int width)
  {
   if(width < 1 || shift - width < 0 || shift + width >= total)
      return false;

   const double pivot = rates[shift].high;
   for(int i = shift - width; i <= shift + width; ++i)
     {
      if(i == shift)
         continue;
      if(rates[i].high >= pivot)
         return false;
     }
   return true;
  }

bool IsSwingLow(MqlRates &rates[], const int total, const int shift, const int width)
  {
   if(width < 1 || shift - width < 0 || shift + width >= total)
      return false;

   const double pivot = rates[shift].low;
   for(int i = shift - width; i <= shift + width; ++i)
     {
      if(i == shift)
         continue;
      if(rates[i].low <= pivot)
         return false;
     }
   return true;
  }

bool FindTwoSwingHighs(MqlRates &rates[],
                       const int total,
                       const int start_shift,
                       const int max_shift,
                       const int width,
                       int &recent_shift,
                       double &recent_price,
                       int &prior_shift,
                       double &prior_price)
  {
   recent_shift = -1;
   prior_shift = -1;
   recent_price = 0.0;
   prior_price = 0.0;

   const int capped_max = MathMin(max_shift, total - width - 1);
   for(int s = MathMax(start_shift, width); s <= capped_max; ++s)
     {
      if(!IsSwingHigh(rates, total, s, width))
         continue;
      if(recent_shift < 0)
        {
         recent_shift = s;
         recent_price = rates[s].high;
        }
      else
        {
         prior_shift = s;
         prior_price = rates[s].high;
         return true;
        }
     }
   return false;
  }

bool FindTwoSwingLows(MqlRates &rates[],
                      const int total,
                      const int start_shift,
                      const int max_shift,
                      const int width,
                      int &recent_shift,
                      double &recent_price,
                      int &prior_shift,
                      double &prior_price)
  {
   recent_shift = -1;
   prior_shift = -1;
   recent_price = 0.0;
   prior_price = 0.0;

   const int capped_max = MathMin(max_shift, total - width - 1);
   for(int s = MathMax(start_shift, width); s <= capped_max; ++s)
     {
      if(!IsSwingLow(rates, total, s, width))
         continue;
      if(recent_shift < 0)
        {
         recent_shift = s;
         recent_price = rates[s].low;
        }
      else
        {
         prior_shift = s;
         prior_price = rates[s].low;
         return true;
        }
     }
   return false;
  }

bool FindOrderBlock(MqlRates &rates[],
                    const int total,
                    const int choch_shift,
                    const bool bullish,
                    int &ob_shift,
                    double &ob_low,
                    double &ob_high)
  {
   ob_shift = -1;
   ob_low = 0.0;
   ob_high = 0.0;

   const int end_shift = MathMin(choch_shift + MathMax(strategy_ob_search_bars, 1), total - 1);
   for(int s = choch_shift + 1; s <= end_shift; ++s)
     {
      const bool bearish_candle = (rates[s].close < rates[s].open);
      const bool bullish_candle = (rates[s].close > rates[s].open);
      if((bullish && !bearish_candle) || (!bullish && !bullish_candle))
         continue;

      ob_shift = s;
      ob_low = rates[s].low;
      ob_high = rates[s].high;
      return true;
     }
   return false;
  }

bool DetectChoChAtShift(MqlRates &rates[],
                        const int total,
                        const int shift,
                        const int direction,
                        const double atr,
                        double &entry,
                        double &sl,
                        double &tp,
                        double &choch_level)
  {
   entry = 0.0;
   sl = 0.0;
   tp = 0.0;
   choch_level = 0.0;

   if(direction == 0 || atr <= 0.0 || shift + strategy_swing_width + 4 >= total || shift + 2 >= total)
      return false;

   int high_recent_shift, high_prior_shift, low_recent_shift, low_prior_shift;
   double high_recent, high_prior, low_recent, low_prior;
   const int swing_start = shift + strategy_swing_width;
   const int swing_end = MathMin(total - strategy_swing_width - 1, shift + strategy_history_bars - 1);
   if(!FindTwoSwingHighs(rates, total, swing_start, swing_end, strategy_swing_width,
                         high_recent_shift, high_recent, high_prior_shift, high_prior))
      return false;
   if(!FindTwoSwingLows(rates, total, swing_start, swing_end, strategy_swing_width,
                        low_recent_shift, low_recent, low_prior_shift, low_prior))
      return false;

   const bool prior_bearish = (high_recent < high_prior && low_recent < low_prior);
   const bool prior_bullish = (high_recent > high_prior && low_recent > low_prior);
   const double break_buffer = strategy_choch_break_atr * atr;
   const double candle_range = rates[shift].high - rates[shift].low;
   if(candle_range < strategy_impulse_min_range_atr * atr)
      return false;

   const bool bullish_fvg = (rates[shift].low > rates[shift + 2].high);
   const bool bearish_fvg = (rates[shift].high < rates[shift + 2].low);
   if(direction > 0)
     {
      if(!prior_bearish || !bullish_fvg || rates[shift].close <= high_recent + break_buffer)
         return false;
      choch_level = high_recent;
     }
   else
     {
      if(!prior_bullish || !bearish_fvg || rates[shift].close >= low_recent - break_buffer)
         return false;
      choch_level = low_recent;
     }

   int ob_shift;
   double ob_low, ob_high;
   if(!FindOrderBlock(rates, total, shift, direction > 0, ob_shift, ob_low, ob_high))
      return false;
   const double ob_height = ob_high - ob_low;
   if(ob_height <= 0.0 || ob_height > strategy_ob_max_height_atr * atr)
      return false;

   entry = ob_low + MathMax(0.0, MathMin(strategy_ob_entry_fraction, 1.0)) * ob_height;
   if(direction > 0)
     {
      sl = ob_low - strategy_ob_sl_atr * atr;
      const double rr_tp = entry + (entry - sl) * strategy_rr;
      tp = (high_recent > entry && high_recent < rr_tp) ? high_recent : rr_tp;
     }
   else
     {
      sl = ob_high + strategy_ob_sl_atr * atr;
      const double rr_tp = entry - (sl - entry) * strategy_rr;
      tp = (low_recent < entry && low_recent > rr_tp) ? low_recent : rr_tp;
     }

   entry = NormalizeStrategyPrice(entry);
   sl = NormalizeStrategyPrice(sl);
   tp = NormalizeStrategyPrice(tp);
   choch_level = NormalizeStrategyPrice(choch_level);
   if(entry <= 0.0 || sl <= 0.0 || tp <= 0.0 || choch_level <= 0.0)
      return false;
   if(direction > 0 && !(sl < entry && tp > entry))
      return false;
   if(direction < 0 && !(sl > entry && tp < entry))
      return false;

   return true;
  }

bool HasRecentSameDirectionChoCh(MqlRates &rates[], const int total, const int direction, const double atr)
  {
   const int max_shift = MathMin(strategy_same_dir_lookback_bars + 1, total - strategy_swing_width - 4);
   for(int s = 2; s <= max_shift; ++s)
     {
      double entry, sl, tp, level;
      if(DetectChoChAtShift(rates, total, s, direction, atr, entry, sl, tp, level))
         return true;
     }
   return false;
  }

bool HasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_SELL_LIMIT)
         return true;
     }
   return false;
  }

bool HasOurOpenPosition()
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

double ChochLevelFromComment(const string comment)
  {
   const int sep = StringFind(comment, ":");
   if(sep < 0)
      return 0.0;
   if(StringFind(comment, "OBCHL:") != 0 && StringFind(comment, "OBCHS:") != 0)
      return 0.0;
   return StringToDouble(StringSubstr(comment, sep + 1));
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return ((ENUM_TIMEFRAMES)_Period != strategy_timeframe);
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_LIMIT;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(HasOurOpenPosition() || HasOurPendingOrder())
      return false;

   MqlRates rates[];
   if(!LoadStrategyRates(rates, strategy_history_bars))
      return false;
   const int total = ArraySize(rates);
   if(total <= 0)
      return false;

   g_last_closed_close = rates[1].close;
   g_last_closed_time = rates[1].time;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   double entry, sl, tp, choch_level;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const int expiry_seconds = MathMax(strategy_pending_expiry_bars, 1) * PeriodSeconds(strategy_timeframe);

   if(DetectChoChAtShift(rates, total, 1, 1, atr, entry, sl, tp, choch_level) &&
      !HasRecentSameDirectionChoCh(rates, total, 1, atr) &&
      ask > 0.0 && entry < ask)
     {
      req.type = QM_BUY_LIMIT;
      req.price = entry;
      req.sl = sl;
      req.tp = tp;
      req.reason = StringFormat("OBCHL:%s", DoubleToString(choch_level, _Digits));
      req.expiration_seconds = expiry_seconds;
      return true;
     }

   if(DetectChoChAtShift(rates, total, 1, -1, atr, entry, sl, tp, choch_level) &&
      !HasRecentSameDirectionChoCh(rates, total, -1, atr) &&
      bid > 0.0 && entry > bid)
     {
      req.type = QM_SELL_LIMIT;
      req.price = entry;
      req.sl = sl;
      req.tp = tp;
      req.reason = StringFormat("OBCHS:%s", DoubleToString(choch_level, _Digits));
      req.expiration_seconds = expiry_seconds;
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
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const double last_closed_close = iClose(_Symbol, strategy_timeframe, 1);  // perf-allowed: O(1) closed-bar ChoCh invalidation read.
   const datetime last_closed_time = iTime(_Symbol, strategy_timeframe, 1);  // perf-allowed: O(1) closed-bar ChoCh invalidation read.
   const int max_hold_seconds = MathMax(strategy_time_exit_bars, 1) * PeriodSeconds(strategy_timeframe);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time > 0 && TimeCurrent() - open_time >= max_hold_seconds)
         return true;

      const double choch_level = ChochLevelFromComment(PositionGetString(POSITION_COMMENT));
      if(choch_level <= 0.0 || last_closed_close <= 0.0 || last_closed_time <= 0)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY && last_closed_close < choch_level)
         return true;
      if(position_type == POSITION_TYPE_SELL && last_closed_close > choch_level)
         return true;
     }

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
