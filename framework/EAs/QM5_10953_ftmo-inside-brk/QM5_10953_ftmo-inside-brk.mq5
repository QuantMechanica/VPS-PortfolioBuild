#property strict
#property version   "5.0"
#property description "QM5_10953 FTMO Inside-Bar Breakout"

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
input int    qm_ea_id                   = 10953;
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
input int    strategy_atr_period              = 14;
input int    strategy_ema_period              = 50;
input double strategy_mother_atr_mult         = 1.20;
input double strategy_entry_atr_buffer        = 0.10;
input double strategy_stop_atr_buffer         = 0.05;
input double strategy_tp_rr                   = 2.00;
input bool   strategy_trailing_enabled        = true;
input double strategy_trail_trigger_rr        = 1.50;
input double strategy_trail_atr_mult          = 1.00;
input int    strategy_pending_expiry_bars     = 3;
input int    strategy_range_lookback_bars     = 20;
input double strategy_min_range_atr_mult      = 1.50;
input double strategy_max_spread_stop_pct     = 0.10;

int g_cached_opposite_exit_direction = 0;

int Strategy_CurrentPositionDirection()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return (type == POSITION_TYPE_BUY) ? 1 : -1;
     }

   return 0;
  }

bool Strategy_IsOurStopOrderType(const ENUM_ORDER_TYPE type)
  {
   return (type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP);
  }

bool Strategy_HasPendingStopOrder()
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
      if(Strategy_IsOurStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }

   return false;
  }

void Strategy_RemoveExpiredPendingStops()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_pending_expiry_bars <= 0)
      return;

   const int expiry_seconds = strategy_pending_expiry_bars * PeriodSeconds(PERIOD_H4);
   if(expiry_seconds <= 0)
      return;

   const datetime now = TimeCurrent();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!Strategy_IsOurStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;

      const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(setup_time > 0 && now - setup_time >= expiry_seconds)
         QM_TM_RemovePendingOrder(ticket, "inside_bar_pending_expired");
     }
  }

bool Strategy_BuildInsideBarRequest(QM_EntryRequest &req,
                                    int &signal_direction,
                                    const bool require_orderable = true)
  {
   signal_direction = 0;
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_atr_period <= 0 || strategy_ema_period <= 0 ||
      strategy_range_lookback_bars < 2 || strategy_pending_expiry_bars <= 0)
      return false;

   const int bars_needed = MathMax(strategy_range_lookback_bars, 2);
   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   // perf-allowed: structural inside-bar/range math has no framework OHLC reader.
   // Strategy_EntrySignal is called only after the skeleton's QM_IsNewBar gate.
   if(CopyRates(_Symbol, PERIOD_H4, 1, bars_needed, bars) < bars_needed)
      return false;

   const double inside_high = bars[0].high;
   const double inside_low = bars[0].low;
   const double inside_close = bars[0].close;
   const double mother_high = bars[1].high;
   const double mother_low = bars[1].low;
   if(inside_high <= 0.0 || inside_low <= 0.0 || inside_close <= 0.0 ||
      mother_high <= 0.0 || mother_low <= 0.0)
      return false;

   if(!(inside_high < mother_high && inside_low > mother_low))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double ema = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_period, 1);
   if(atr <= 0.0 || ema <= 0.0)
      return false;

   if(mother_high - mother_low <= strategy_mother_atr_mult * atr)
      return false;

   double recent_high = -DBL_MAX;
   double recent_low = DBL_MAX;
   for(int i = 0; i < strategy_range_lookback_bars; ++i)
     {
      recent_high = MathMax(recent_high, bars[i].high);
      recent_low = MathMin(recent_low, bars[i].low);
     }
   if(recent_high <= recent_low)
      return false;
   if(recent_high - recent_low < strategy_min_range_atr_mult * atr)
      return false;

   const bool long_signal = (inside_close > ema);
   const bool short_signal = (inside_close < ema);
   if(!long_signal && !short_signal)
      return false;

   const double entry = long_signal ? (inside_high + strategy_entry_atr_buffer * atr)
                                    : (inside_low - strategy_entry_atr_buffer * atr);
   const double sl = long_signal ? (inside_low - strategy_stop_atr_buffer * atr)
                                 : (inside_high + strategy_stop_atr_buffer * atr);
   const double stop_distance = MathAbs(entry - sl);
   if(entry <= 0.0 || sl <= 0.0 || stop_distance <= 0.0)
      return false;

   if(require_orderable)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
         return false;

      if(ask - bid > strategy_max_spread_stop_pct * stop_distance)
         return false;

      if(long_signal && ask >= entry)
         return false;
      if(short_signal && bid <= entry)
         return false;
     }

   req.type = long_signal ? QM_BUY_STOP : QM_SELL_STOP;
   req.price = QM_StopRulesNormalizePrice(_Symbol, entry);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_tp_rr);
   req.reason = long_signal ? "FTMO_INSIDE_BRK_LONG" : "FTMO_INSIDE_BRK_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = strategy_pending_expiry_bars * PeriodSeconds(PERIOD_H4);
   signal_direction = long_signal ? 1 : -1;
   return (req.price > 0.0 && req.sl > 0.0 && req.tp > 0.0 && req.expiration_seconds > 0);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card filter: keep at most one position or pending order per symbol/magic.
   // The entry hook also enforces this before submitting a new stop order.
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   g_cached_opposite_exit_direction = 0;

   int signal_direction = 0;
   if(!Strategy_BuildInsideBarRequest(req, signal_direction, false))
      return false;

   const int position_direction = Strategy_CurrentPositionDirection();
   if(position_direction != 0)
     {
      if(signal_direction == -position_direction)
         g_cached_opposite_exit_direction = signal_direction;
      return false;
     }

   if(Strategy_HasPendingStopOrder())
      return false;

   return Strategy_BuildInsideBarRequest(req, signal_direction, true);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   Strategy_RemoveExpiredPendingStops();

   if(!strategy_trailing_enabled)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double market = (type == POSITION_TYPE_BUY) ? bid : ask;
      const double initial_risk = MathAbs(open_price - sl);
      const double open_profit_distance = (type == POSITION_TYPE_BUY) ? (market - open_price)
                                                                      : (open_price - market);
      if(initial_risk > 0.0 && open_profit_distance >= strategy_trail_trigger_rr * initial_risk)
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(g_cached_opposite_exit_direction == 0)
      return false;

   const int position_direction = Strategy_CurrentPositionDirection();
   if(position_direction != 0 && g_cached_opposite_exit_direction == -position_direction)
     {
      g_cached_opposite_exit_direction = 0;
      return true;
     }

   g_cached_opposite_exit_direction = 0;
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
