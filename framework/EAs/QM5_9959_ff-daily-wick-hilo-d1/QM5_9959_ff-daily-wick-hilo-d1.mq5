#property strict
#property version   "5.0"
#property description "QM5_9959 ForexFactory Daily Wick High-Low D1"

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
input int    qm_ea_id                   = 9959;
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
input ENUM_TIMEFRAMES strategy_timeframe          = PERIOD_D1;
input int    strategy_atr_period                  = 14;
input double strategy_fx_entry_buffer_pips        = 5.0;
input double strategy_fx_sl_pips                  = 30.0;
input double strategy_fx_tp_pips                  = 100.0;
input double strategy_nonfx_entry_atr_mult        = 0.05;
input double strategy_sl_atr_mult                 = 0.8;
input double strategy_min_range_atr_mult          = 0.5;
input double strategy_rr_multiple                 = 2.0;
input double strategy_max_spread_stop_frac        = 0.10;
input int    strategy_pending_days                = 1;

string Strategy_BaseSymbol()
  {
   string symbol = _Symbol;
   const int dot_pos = StringFind(symbol, ".");
   if(dot_pos >= 0)
      symbol = StringSubstr(symbol, 0, dot_pos);
   return symbol;
  }

bool Strategy_IsFxSymbol()
  {
   const string base = Strategy_BaseSymbol();
   return (base == "EURUSD" || base == "GBPUSD" || base == "USDJPY");
  }

double Strategy_PipDistance()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   return (digits == 3 || digits == 5) ? point * 10.0 : point;
  }

bool Strategy_CurrentSpread(double &spread_price)
  {
   spread_price = 0.0;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;
   spread_price = ask - bid;
   return true;
  }

bool Strategy_IsStopOrderType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
  }

bool Strategy_HasOurOpenPosition()
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

int Strategy_OurPendingStopCount()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(Strategy_IsStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         ++count;
     }
   return count;
  }

void Strategy_DeleteOurPendingStops(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!Strategy_IsStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

double Strategy_StopDistance(const double atr)
  {
   if(atr <= 0.0 || strategy_sl_atr_mult <= 0.0)
      return 0.0;

   if(!Strategy_IsFxSymbol())
      return strategy_sl_atr_mult * atr;

   const double pip = Strategy_PipDistance();
   if(pip <= 0.0 || strategy_fx_sl_pips <= 0.0)
      return 0.0;

   const double fixed_stop = strategy_fx_sl_pips * pip;
   if(fixed_stop < 0.4 * atr || fixed_stop > 1.2 * atr)
      return strategy_sl_atr_mult * atr;
   return fixed_stop;
  }

bool Strategy_InitEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = MathMax(1, strategy_pending_days) * 86400;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(Strategy_HasOurOpenPosition() || Strategy_OurPendingStopCount() > 0)
      return false;

   double spread_price = 0.0;
   if(!Strategy_CurrentSpread(spread_price))
      return true;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, MathMax(1, strategy_atr_period), 1);
   const double stop_distance = Strategy_StopDistance(atr);
   if(stop_distance <= 0.0)
      return true;
   if(strategy_max_spread_stop_frac > 0.0 && spread_price > strategy_max_spread_stop_frac * stop_distance)
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitEntryRequest(req);
   Strategy_DeleteOurPendingStops("new_d1_bar_reset");

   if(strategy_timeframe != PERIOD_D1)
      return false;
   if(Strategy_HasOurOpenPosition() || Strategy_OurPendingStopCount() > 0)
      return false;
   if(strategy_atr_period <= 0 ||
      strategy_fx_entry_buffer_pips <= 0.0 ||
      strategy_nonfx_entry_atr_mult <= 0.0 ||
      strategy_min_range_atr_mult <= 0.0 ||
      strategy_rr_multiple <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   // perf-allowed: single closed D1 OHLC reads for previous-day wick geometry;
   // framework has no OHLC reader and this runs only behind the skeleton new-bar gate.
   const double prev_open = iOpen(_Symbol, strategy_timeframe, 1);
   const double prev_high = iHigh(_Symbol, strategy_timeframe, 1);
   const double prev_low = iLow(_Symbol, strategy_timeframe, 1);
   if(prev_open <= 0.0 || prev_high <= 0.0 || prev_low <= 0.0 || prev_high <= prev_low)
      return false;

   const double prev_range = prev_high - prev_low;
   if(prev_range < strategy_min_range_atr_mult * atr)
      return false;

   double spread_price = 0.0;
   if(!Strategy_CurrentSpread(spread_price))
      return false;

   const double stop_distance = Strategy_StopDistance(atr);
   if(stop_distance <= 0.0)
      return false;
   if(strategy_max_spread_stop_frac > 0.0 && spread_price > strategy_max_spread_stop_frac * stop_distance)
      return false;

   const double pip = Strategy_PipDistance();
   const bool is_fx = Strategy_IsFxSymbol();
   const double buffer = is_fx ? strategy_fx_entry_buffer_pips * pip
                               : strategy_nonfx_entry_atr_mult * atr;
   if(buffer <= 0.0)
      return false;

   const double rr_tp_distance = strategy_rr_multiple * stop_distance;
   double tp_distance = rr_tp_distance;
   if(is_fx && strategy_fx_tp_pips > 0.0 && pip > 0.0)
      tp_distance = MathMin(strategy_fx_tp_pips * pip, rr_tp_distance);
   if(tp_distance <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;
   const double min_dist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;

   const double wick_buy = prev_open - prev_low;
   const double wick_sell = prev_high - prev_open;

   if(wick_buy > wick_sell)
     {
      const double entry = prev_high + buffer;
      if(entry <= ask + min_dist || stop_distance <= min_dist || tp_distance <= min_dist)
         return false;
      req.type = QM_BUY_STOP;
      req.price = NormalizeDouble(entry, _Digits);
      req.sl = NormalizeDouble(entry - stop_distance, _Digits);
      req.tp = NormalizeDouble(entry + tp_distance, _Digits);
      req.reason = "FF_DAILY_WICK_BUY_STOP";
      return (req.sl < req.price && req.tp > req.price);
     }

   if(wick_sell > wick_buy)
     {
      const double entry = prev_low - buffer;
      if(entry >= bid - min_dist || stop_distance <= min_dist || tp_distance <= min_dist)
         return false;
      req.type = QM_SELL_STOP;
      req.price = NormalizeDouble(entry, _Digits);
      req.sl = NormalizeDouble(entry + stop_distance, _Digits);
      req.tp = NormalizeDouble(entry - tp_distance, _Digits);
      req.reason = "FF_DAILY_WICK_SELL_STOP";
      return (req.sl > req.price && req.tp < req.price);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(Strategy_HasOurOpenPosition())
      Strategy_DeleteOurPendingStops("position_open_cancel_stale_pending");
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   // perf-allowed: one current D1 bar-time read for the card's next-D1-open time stop.
   const datetime current_d1_open = iTime(_Symbol, strategy_timeframe, 0);
   if(current_d1_open <= 0)
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

      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened_at > 0 && current_d1_open > opened_at)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0)
      return false;
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
