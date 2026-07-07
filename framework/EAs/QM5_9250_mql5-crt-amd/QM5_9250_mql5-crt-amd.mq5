#property strict
#property version   "5.0"
#property description "QM5_9250 MQL5 CRT AMD"

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
input int    qm_ea_id                   = 9250;
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
input ENUM_TIMEFRAMES strategy_range_tf             = PERIOD_H1;
input int             strategy_atr_period           = 14;
input double          strategy_min_range_atr_mult   = 0.50;
input double          strategy_max_range_atr_mult   = 2.50;
input double          strategy_min_manip_depth_pct  = 10.0;
input int             strategy_confirm_bars         = 1;
input double          strategy_stop_atr_buffer      = 0.25;
input double          strategy_take_profit_r        = 2.0;
input int             strategy_max_hold_bars        = 48;
input int             strategy_scan_bars            = 16;
input double          strategy_max_spread_stop_pct  = 12.0;

datetime g_last_traded_range_time = 0;

bool Strategy_HasOpenPosition()
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
      return true;
     }

   return false;
  }

bool Strategy_InputsValid()
  {
   if(strategy_range_tf <= PERIOD_CURRENT)
      return false;
   if(strategy_atr_period <= 1)
      return false;
   if(strategy_min_range_atr_mult <= 0.0 ||
      strategy_max_range_atr_mult <= strategy_min_range_atr_mult)
      return false;
   if(strategy_min_manip_depth_pct <= 0.0 ||
      strategy_min_manip_depth_pct > 100.0)
      return false;
   if(strategy_confirm_bars < 1 || strategy_confirm_bars > 4)
      return false;
   if(strategy_stop_atr_buffer < 0.0 ||
      strategy_take_profit_r <= 0.0 ||
      strategy_max_hold_bars <= 0 ||
      strategy_scan_bars < 4 ||
      strategy_max_spread_stop_pct < 0.0)
      return false;
   return true;
  }

bool Strategy_ReadRangeBar(MqlRates &range_bar)
  {
   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied = CopyRates(_Symbol, strategy_range_tf, 1, 1, bars); // perf-allowed: one completed accumulation-range bar read inside framework new-bar entry hook.
   if(copied != 1)
      return false;

   range_bar = bars[0];
   if(range_bar.open <= 0.0 || range_bar.high <= 0.0 ||
      range_bar.low <= 0.0 || range_bar.close <= 0.0 ||
      range_bar.high <= range_bar.low)
      return false;
   return true;
  }

bool Strategy_SpreadAllowed(const double entry_price, const double stop_price)
  {
   if(strategy_max_spread_stop_pct <= 0.0)
      return true;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0 || ask < bid ||
      entry_price <= 0.0 || stop_price <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry_price - stop_price);
   if(stop_distance <= 0.0)
      return false;

   return ((ask - bid) <= stop_distance * strategy_max_spread_stop_pct / 100.0);
  }

bool Strategy_StopsMeetBrokerLevel(const QM_OrderType type,
                                   const double entry_price,
                                   const double sl_price,
                                   const double tp_price)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry_price <= 0.0 || sl_price <= 0.0 || tp_price <= 0.0)
      return false;

   const int stop_level_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stop_level_points <= 0)
      return true;

   const double min_distance = (double)stop_level_points * point;
   if(QM_OrderTypeIsBuy(type))
      return ((entry_price - sl_price) >= min_distance &&
              (tp_price - entry_price) >= min_distance);

   return ((sl_price - entry_price) >= min_distance &&
           (entry_price - tp_price) >= min_distance);
  }

bool Strategy_FindCrtSetup(const MqlRates &range_bar,
                           int &direction,
                           double &manip_extreme)
  {
   direction = 0;
   manip_extreme = 0.0;

   const int range_seconds = PeriodSeconds(strategy_range_tf);
   if(range_seconds <= 0)
      return false;

   const datetime range_end = range_bar.time + range_seconds;
   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied = CopyRates(_Symbol, PERIOD_M15, 1, strategy_scan_bars, bars); // perf-allowed: bounded M15 manipulation/confirmation scan inside framework new-bar entry hook.
   if(copied < strategy_confirm_bars)
      return false;
   if(bars[0].time < range_end)
      return false;

   const double range_height = range_bar.high - range_bar.low;
   if(range_height <= 0.0)
      return false;

   const double depth = range_height * strategy_min_manip_depth_pct / 100.0;
   if(depth <= 0.0)
      return false;

   const bool bullish_range = (range_bar.close > range_bar.open);
   const bool bearish_range = (range_bar.close < range_bar.open);
   if(!bullish_range && !bearish_range)
      return false;

   int confirm_count = 0;
   bool breached = false;
   bool latest_confirms = false;

   for(int i = copied - 1; i >= 0; --i)
     {
      if(bars[i].time < range_end)
         continue;

      if(bullish_range)
        {
         if(bars[i].low <= range_bar.low - depth)
           {
            breached = true;
            if(manip_extreme <= 0.0 || bars[i].low < manip_extreme)
               manip_extreme = bars[i].low;
           }

         if(breached && bars[i].close > range_bar.low)
            confirm_count++;
         else if(breached)
            confirm_count = 0;

         latest_confirms = (i == 0 && breached &&
                            bars[i].close > range_bar.low &&
                            confirm_count >= strategy_confirm_bars);
        }
      else if(bearish_range)
        {
         if(bars[i].high >= range_bar.high + depth)
           {
            breached = true;
            if(manip_extreme <= 0.0 || bars[i].high > manip_extreme)
               manip_extreme = bars[i].high;
           }

         if(breached && bars[i].close < range_bar.high)
            confirm_count++;
         else if(breached)
            confirm_count = 0;

         latest_confirms = (i == 0 && breached &&
                            bars[i].close < range_bar.high &&
                            confirm_count >= strategy_confirm_bars);
        }
     }

   if(!latest_confirms || manip_extreme <= 0.0)
      return false;

   direction = bullish_range ? 1 : -1;
   return true;
  }

bool Strategy_OppositeCrtSignal(const long position_type)
  {
   MqlRates range_bar;
   if(!Strategy_ReadRangeBar(range_bar))
      return false;

   int direction = 0;
   double manip_extreme = 0.0;
   if(!Strategy_FindCrtSetup(range_bar, direction, manip_extreme))
      return false;

   if(position_type == POSITION_TYPE_BUY && direction < 0)
      return true;
   if(position_type == POSITION_TYPE_SELL && direction > 0)
      return true;
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Keep management and time exits alive even if the chart timeframe changes.
   if(Strategy_HasOpenPosition())
      return false;

   if(!Strategy_InputsValid())
      return true;
   if(_Period != PERIOD_M15)
      return true;
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

   if(_Period != PERIOD_M15 || !Strategy_InputsValid() || Strategy_HasOpenPosition())
      return false;

   MqlRates range_bar;
   if(!Strategy_ReadRangeBar(range_bar))
      return false;
   if(g_last_traded_range_time == range_bar.time)
      return false;

   const double range_height = range_bar.high - range_bar.low;
   const double range_atr = QM_ATR(_Symbol, strategy_range_tf, strategy_atr_period, 1);
   if(range_atr <= 0.0 ||
      range_height < strategy_min_range_atr_mult * range_atr ||
      range_height > strategy_max_range_atr_mult * range_atr)
      return false;

   int direction = 0;
   double manip_extreme = 0.0;
   if(!Strategy_FindCrtSetup(range_bar, direction, manip_extreme))
      return false;

   const double stop_atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   if(stop_atr <= 0.0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0 || ask < bid)
      return false;

   const double buffer = strategy_stop_atr_buffer * stop_atr;
   if(direction > 0)
     {
      const double entry_price = ask;
      const double raw_sl = manip_extreme - buffer;
      if(raw_sl <= 0.0 || raw_sl >= entry_price)
         return false;

      req.type = QM_BUY;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, raw_sl);
      req.tp = QM_StopRulesTakeFromDistance(_Symbol, req.type, entry_price,
                                            strategy_take_profit_r * (entry_price - req.sl));
      req.reason = "CRT_AMD_LONG";
      if(!Strategy_SpreadAllowed(entry_price, req.sl))
         return false;
      if(!Strategy_StopsMeetBrokerLevel(req.type, entry_price, req.sl, req.tp))
         return false;
      g_last_traded_range_time = range_bar.time;
      return true;
     }

   if(direction < 0)
     {
      const double entry_price = bid;
      const double raw_sl = manip_extreme + buffer;
      if(raw_sl <= entry_price)
         return false;

      req.type = QM_SELL;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, raw_sl);
      req.tp = QM_StopRulesTakeFromDistance(_Symbol, req.type, entry_price,
                                            strategy_take_profit_r * (req.sl - entry_price));
      req.reason = "CRT_AMD_SHORT";
      if(!Strategy_SpreadAllowed(entry_price, req.sl))
         return false;
      if(!Strategy_StopsMeetBrokerLevel(req.type, entry_price, req.sl, req.tp))
         return false;
      g_last_traded_range_time = range_bar.time;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card pins fixed structural SL/2R TP and a time stop; no trailing or scaling.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(strategy_max_hold_bars <= 0)
      return false;

   const int hold_seconds = strategy_max_hold_bars * PeriodSeconds(PERIOD_M15);
   if(hold_seconds <= 0)
      return false;

   const int magic = QM_FrameworkMagic();
   const datetime broker_now = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && broker_now - opened >= hold_seconds)
         return true;

      const long position_type = PositionGetInteger(POSITION_TYPE);
      if(Strategy_OppositeCrtSignal(position_type))
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
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
