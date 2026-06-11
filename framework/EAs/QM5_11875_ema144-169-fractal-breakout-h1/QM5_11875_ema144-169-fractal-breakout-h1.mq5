#property strict
#property version   "5.0"
#property description "QM5_11875 EMA144/169 Fractal Breakout H1"

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
input int    qm_ea_id                   = 11875;
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
input int    strategy_ema_fast_period          = 144;
input int    strategy_ema_slow_period          = 169;
input int    strategy_fractal_side_bars        = 2;
input int    strategy_atr_period               = 14;
input double strategy_sl_atr_mult              = 2.0;
input double strategy_tp_atr_mult              = 4.0;
input double strategy_be_trigger_fraction      = 0.50;
input int    strategy_be_buffer_points         = 0;
input int    strategy_session_start_utc_hour   = 7;
input int    strategy_session_end_utc_hour     = 18;
input int    strategy_max_spread_points        = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   if(_Symbol != "EURUSD.DWX" && _Symbol != "GBPUSD.DWX")
      return false;

   MqlDateTime utc;
   TimeToStruct(TimeGMT(), utc);
   const int start_h = MathMax(0, MathMin(23, strategy_session_start_utc_hour));
   const int end_h = MathMax(0, MathMin(24, strategy_session_end_utc_hour));
   if(start_h == end_h)
      return false;
   if(start_h < end_h)
      return (utc.hour < start_h || utc.hour >= end_h);
   return (utc.hour < start_h && utc.hour >= end_h);
  }

bool Strategy_HasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return true;

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
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         return true;
     }
   return false;
  }

bool Strategy_GetConfirmedFractal(const bool want_upper, const int center_shift, double &out_price)
  {
   out_price = 0.0;
   if(strategy_fractal_side_bars < 1 || center_shift <= strategy_fractal_side_bars)
      return false;

   const double center = want_upper
                         ? iHigh(_Symbol, _Period, center_shift)  // perf-allowed: Williams fractal structural read, EntrySignal is QM_IsNewBar-gated
                         : iLow(_Symbol, _Period, center_shift);  // perf-allowed: Williams fractal structural read, EntrySignal is QM_IsNewBar-gated
   if(center <= 0.0)
      return false;

   for(int offset = 1; offset <= strategy_fractal_side_bars; ++offset)
     {
      const double left = want_upper
                          ? iHigh(_Symbol, _Period, center_shift + offset)  // perf-allowed: bounded 5-bar fractal structural read
                          : iLow(_Symbol, _Period, center_shift + offset);  // perf-allowed: bounded 5-bar fractal structural read
      const double right = want_upper
                           ? iHigh(_Symbol, _Period, center_shift - offset)  // perf-allowed: bounded 5-bar fractal structural read
                           : iLow(_Symbol, _Period, center_shift - offset);  // perf-allowed: bounded 5-bar fractal structural read
      if(left <= 0.0 || right <= 0.0)
         return false;
      if(want_upper && (center < left || center < right))
         return false;
      if(!want_upper && (center > left || center > right))
         return false;
     }

   out_price = center;
   return true;
  }

bool Strategy_GetOurPosition(ulong &ticket)
  {
   ticket = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      return true;
     }
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOurPendingOrder())
      return false;
   if(strategy_ema_fast_period <= 0 || strategy_ema_slow_period <= 0 ||
      strategy_atr_period <= 0 || strategy_sl_atr_mult <= 0.0 ||
      strategy_tp_atr_mult <= 0.0)
      return false;

   const int center_shift = strategy_fractal_side_bars + 1;
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, center_shift);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, center_shift);
   const double bar_close = iClose(_Symbol, _Period, center_shift); // perf-allowed: channel-zone structural read, EntrySignal is QM_IsNewBar-gated
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, center_shift);
   if(ema_fast <= 0.0 || ema_slow <= 0.0 || bar_close <= 0.0 || atr <= 0.0)
      return false;

   const double channel_top = MathMax(ema_fast, ema_slow);
   const double channel_bottom = MathMin(ema_fast, ema_slow);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double spread = MathMax(ask - bid, point);
   if(bid <= 0.0 || ask <= 0.0 || point <= 0.0 || spread <= 0.0)
      return false;

   double fractal_price = 0.0;
   if(bar_close > channel_top && Strategy_GetConfirmedFractal(true, center_shift, fractal_price))
     {
      if(fractal_price < channel_top)
         return false;
      const double entry = NormalizeDouble(fractal_price + spread, _Digits);
      if(entry <= ask)
         return false;

      req.type = QM_BUY_STOP;
      req.price = entry;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, req.price, atr, strategy_sl_atr_mult);
      req.tp = QM_TakeATRFromValue(_Symbol, req.type, req.price, atr, strategy_tp_atr_mult);
      req.reason = "EMA144_169_UP_FRACTAL_BREAKOUT";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   if(bar_close < channel_bottom && Strategy_GetConfirmedFractal(false, center_shift, fractal_price))
     {
      if(fractal_price > channel_bottom)
         return false;
      const double entry = NormalizeDouble(fractal_price - spread, _Digits);
      if(entry >= bid)
         return false;

      req.type = QM_SELL_STOP;
      req.price = entry;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, req.price, atr, strategy_sl_atr_mult);
      req.tp = QM_TakeATRFromValue(_Symbol, req.type, req.price, atr, strategy_tp_atr_mult);
      req.reason = "EMA144_169_DOWN_FRACTAL_BREAKOUT";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   if(!Strategy_GetOurPosition(ticket) || !PositionSelectByTicket(ticket))
      return;

   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double current_tp = PositionGetDouble(POSITION_TP);
   const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   if(open_price <= 0.0 || current_tp <= 0.0 || strategy_be_trigger_fraction <= 0.0)
      return;

   const bool is_buy = (pos_type == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(market <= 0.0 || point <= 0.0)
      return;

   const double tp_distance = MathAbs(current_tp - open_price);
   const double moved = is_buy ? (market - open_price) : (open_price - market);
   if(tp_distance <= 0.0 || moved < tp_distance * strategy_be_trigger_fraction)
      return;

   const double buffer = MathMax(0, strategy_be_buffer_points) * point;
   const double target_sl = NormalizeDouble(is_buy ? open_price + buffer : open_price - buffer, _Digits);
   const bool improves = (current_sl <= 0.0) ||
                         (is_buy ? (target_sl > current_sl + point * 0.5)
                                 : (target_sl < current_sl - point * 0.5));
   if(improves)
      QM_TM_MoveSL(ticket, target_sl, "move_sl_to_breakeven_at_half_tp");
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Card exits are broker SL/TP, break-even management, and framework Friday close.
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
