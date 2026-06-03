#property strict
#property version   "5.0"
#property description "QM5_10705 TradingView PDH PDL Liquidity Trap"

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
input int    qm_ea_id                   = 10705;
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
input int    strategy_atr_period             = 14;
input double strategy_atr_buffer_mult        = 1.0;
input double strategy_min_atr_buffer_mult    = 0.5;
input double strategy_rr_target              = 2.0;
input int    strategy_trade_window           = 0;      // 0 all day, 1 London/NY overlap, 2 NY only.
input int    strategy_london_ny_start_minute = 780;
input int    strategy_london_ny_end_minute   = 1020;
input int    strategy_ny_start_minute        = 870;
input int    strategy_ny_end_minute          = 1260;
input int    strategy_skip_cash_open_minutes = 0;
input int    strategy_london_open_minute     = 480;
input int    strategy_ny_cash_open_minute    = 870;
input int    strategy_max_spread_points      = 0;

// -----------------------------------------------------------------------------
// Strategy hooks - implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
         return true;
      if((ask - bid) / point > (double)strategy_max_spread_points)
         return true;
     }

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int minute = dt.hour * 60 + dt.min;

   if(strategy_trade_window == 1)
     {
      int start_minute = strategy_london_ny_start_minute;
      int end_minute = strategy_london_ny_end_minute;
      if(start_minute < 0) start_minute = 0;
      if(start_minute > 1439) start_minute = 1439;
      if(end_minute < 0) end_minute = 0;
      if(end_minute > 1439) end_minute = 1439;

      bool inside = true;
      if(start_minute != end_minute)
        {
         if(start_minute < end_minute)
            inside = (minute >= start_minute && minute < end_minute);
         else
            inside = (minute >= start_minute || minute < end_minute);
        }
      if(!inside)
         return true;
     }

   if(strategy_trade_window == 2)
     {
      int start_minute = strategy_ny_start_minute;
      int end_minute = strategy_ny_end_minute;
      if(start_minute < 0) start_minute = 0;
      if(start_minute > 1439) start_minute = 1439;
      if(end_minute < 0) end_minute = 0;
      if(end_minute > 1439) end_minute = 1439;

      bool inside = true;
      if(start_minute != end_minute)
        {
         if(start_minute < end_minute)
            inside = (minute >= start_minute && minute < end_minute);
         else
            inside = (minute >= start_minute || minute < end_minute);
        }
      if(!inside)
         return true;
     }

   if(strategy_trade_window < 0 || strategy_trade_window > 2)
      return true;

   if(strategy_skip_cash_open_minutes > 0)
     {
      int london_open = strategy_london_open_minute;
      int ny_open = strategy_ny_cash_open_minute;
      if(london_open < 0) london_open = 0;
      if(london_open > 1439) london_open = 1439;
      if(ny_open < 0) ny_open = 0;
      if(ny_open > 1439) ny_open = 1439;

      int london_end = london_open + strategy_skip_cash_open_minutes;
      int ny_end = ny_open + strategy_skip_cash_open_minutes;
      if(london_end > 1440) london_end = 1440;
      if(ny_end > 1440) ny_end = 1440;

      if(minute >= london_open && minute < london_end)
         return true;
      if(minute >= ny_open && minute < ny_end)
         return true;
     }

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

   if(strategy_atr_period < 1 || strategy_rr_target <= 0.0 ||
      strategy_atr_buffer_mult <= 0.0 || strategy_min_atr_buffer_mult <= 0.0)
      return false;

   if(Bars(_Symbol, _Period) < strategy_atr_period + 5 || Bars(_Symbol, PERIOD_D1) < 2)
      return false;

   const datetime trap_bar_time = iTime(_Symbol, _Period, 1);
   if(trap_bar_time <= 0)
      return false;

   static int last_trade_day_key = 0;
   MqlDateTime trap_dt;
   TimeToStruct(trap_bar_time, trap_dt);
   const int day_key = trap_dt.year * 10000 + trap_dt.mon * 100 + trap_dt.day;
   if(last_trade_day_key == day_key)
      return false;

   const double pdh = iHigh(_Symbol, PERIOD_D1, 1);
   const double pdl = iLow(_Symbol, PERIOD_D1, 1);
   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1 = iLow(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(pdh <= 0.0 || pdl <= 0.0 || high1 <= 0.0 || low1 <= 0.0 ||
      close1 <= 0.0 || ask <= 0.0 || bid <= 0.0 || atr <= 0.0)
      return false;

   const double buffer_mult = MathMax(strategy_atr_buffer_mult, strategy_min_atr_buffer_mult);
   const double buffer = atr * buffer_mult;

   if(high1 > pdh && close1 < pdh)
     {
      const double entry = bid;
      const double sl = NormalizeDouble(high1 + buffer, _Digits);
      if(sl <= entry)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_rr_target);
      req.reason = "PDH_TRAP_SHORT";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      if(req.tp <= 0.0 || req.tp >= entry)
         return false;

      last_trade_day_key = day_key;
      return true;
     }

   if(low1 < pdl && close1 > pdl)
     {
      const double entry = ask;
      const double sl = NormalizeDouble(low1 - buffer, _Digits);
      if(sl <= 0.0 || sl >= entry)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_rr_target);
      req.reason = "PDL_TRAP_LONG";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      if(req.tp <= entry)
         return false;

      last_trade_day_key = day_key;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card has no trailing, break-even, partial close, or scale-out rule.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Card exits through fixed 2R TP, ATR-buffered SL, and framework Friday close.
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0)
      return true;
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

