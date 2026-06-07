#property strict
#property version   "5.0"
#property description "QM5_11201 ft-fott"

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
input int    qm_ea_id                   = 11201;
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
input int    strategy_ott_pds                  = 2;
input double strategy_ott_percent              = 1.4;
input int    strategy_cmo_period               = 9;
input int    strategy_ott_lookback_bars        = 200;
input int    strategy_adx_period               = 14;
input double strategy_adx_exit                 = 60.0;
input int    strategy_atr_period               = 14;
input double strategy_atr_stop_mult            = 2.5;
input double strategy_roi_0_min_pct            = 10.0;
input double strategy_roi_30_min_pct           = 10.0;
input double strategy_roi_60_min_pct           = 5.0;
input double strategy_roi_120_min_pct          = 2.5;
input double strategy_trailing_percent         = 5.0;
input double strategy_trailing_offset_percent  = 10.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

bool Strategy_CopyClosedCloses(double &closes[])
  {
   const int min_bars = MathMax(strategy_cmo_period + 8, strategy_ott_pds + 8);
   const int bars = MathMax(strategy_ott_lookback_bars, min_bars);
   if(bars <= min_bars)
      return false;

   ArrayResize(closes, bars);
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, _Period, 1, bars, closes); // perf-allowed: bounded closed-bar OTT source port, EntrySignal is called after QM_IsNewBar().
   if(copied < min_bars)
      return false;
   if(copied < bars)
      ArrayResize(closes, copied);
   return true;
  }

bool Strategy_ComputeOttSnapshot(double &var_curr,
                                 double &ott_curr,
                                 double &var_prev,
                                 double &ott_prev)
  {
   var_curr = 0.0;
   ott_curr = 0.0;
   var_prev = 0.0;
   ott_prev = 0.0;

   if(strategy_ott_pds <= 0 || strategy_cmo_period <= 0 || strategy_ott_percent <= 0.0)
      return false;

   double series_closes[];
   if(!Strategy_CopyClosedCloses(series_closes))
      return false;

   const int n = ArraySize(series_closes);
   if(n < strategy_cmo_period + strategy_ott_pds + 8)
      return false;

   double close_chron[];
   double ud1[];
   double dd1[];
   double cmo[];
   double var_line[];
   double longstop[];
   double shortstop[];
   double raw_ott[];
   double ott_line[];
   ArrayResize(close_chron, n);
   ArrayResize(ud1, n);
   ArrayResize(dd1, n);
   ArrayResize(cmo, n);
   ArrayResize(var_line, n);
   ArrayResize(longstop, n);
   ArrayResize(shortstop, n);
   ArrayResize(raw_ott, n);
   ArrayResize(ott_line, n);

   for(int i = 0; i < n; ++i)
     {
      close_chron[i] = series_closes[n - 1 - i];
      ud1[i] = 0.0;
      dd1[i] = 0.0;
      cmo[i] = 0.0;
      var_line[i] = 0.0;
      longstop[i] = 0.0;
      shortstop[i] = 999999999999.0;
      raw_ott[i] = 0.0;
      ott_line[i] = 0.0;
     }

   for(int i = 1; i < n; ++i)
     {
      if(close_chron[i] > close_chron[i - 1])
         ud1[i] = close_chron[i] - close_chron[i - 1];
      else if(close_chron[i] < close_chron[i - 1])
         dd1[i] = close_chron[i - 1] - close_chron[i];
     }

   const double alpha = 2.0 / ((double)strategy_ott_pds + 1.0);
   int dir = 1;
   for(int i = 1; i < n; ++i)
     {
      if(i >= strategy_cmo_period)
        {
         double ud_sum = 0.0;
         double dd_sum = 0.0;
         for(int k = i - strategy_cmo_period + 1; k <= i; ++k)
           {
            ud_sum += ud1[k];
            dd_sum += dd1[k];
           }
         const double denom = ud_sum + dd_sum;
         if(denom > 0.0)
            cmo[i] = MathAbs((ud_sum - dd_sum) / denom);
        }

      if(i >= strategy_ott_pds)
         var_line[i] = (alpha * cmo[i] * close_chron[i]) +
                       ((1.0 - alpha * cmo[i]) * var_line[i - 1]);

      const double fark = var_line[i] * strategy_ott_percent * 0.01;
      const double new_longstop = var_line[i] - fark;
      const double new_shortstop = var_line[i] + fark;

      if(var_line[i] > longstop[i - 1])
         longstop[i] = MathMax(new_longstop, longstop[i - 1]);
      else
         longstop[i] = new_longstop;

      if(var_line[i] < shortstop[i - 1])
         shortstop[i] = MathMin(new_shortstop, shortstop[i - 1]);
      else
         shortstop[i] = new_shortstop;

      const bool xlongstop = (var_line[i - 1] > longstop[i - 1] && var_line[i] < longstop[i - 1]);
      const bool xshortstop = (var_line[i - 1] < shortstop[i - 1] && var_line[i] > shortstop[i - 1]);
      if(xshortstop)
         dir = 1;
      else if(xlongstop)
         dir = -1;

      const double mt = (dir == 1) ? longstop[i] : shortstop[i];
      raw_ott[i] = (var_line[i] > mt)
                   ? (mt * (200.0 + strategy_ott_percent) / 200.0)
                   : (mt * (200.0 - strategy_ott_percent) / 200.0);
      if(i >= 2)
         ott_line[i] = raw_ott[i - 2];
     }

   var_curr = var_line[n - 1];
   ott_curr = ott_line[n - 1];
   var_prev = var_line[n - 2];
   ott_prev = ott_line[n - 2];
   return (var_curr > 0.0 && ott_curr > 0.0 && var_prev > 0.0 && ott_prev > 0.0);
  }

bool Strategy_SelectOurPosition(ulong &ticket,
                                ENUM_POSITION_TYPE &position_type,
                                double &open_price,
                                datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   open_time = 0;

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
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

double Strategy_NormalizedRoiTargetPct(const int elapsed_minutes)
  {
   double target = strategy_roi_0_min_pct;
   if(elapsed_minutes >= 30)
      target = MathMin(target, strategy_roi_30_min_pct);
   if(elapsed_minutes >= 60)
      target = MathMin(target, strategy_roi_60_min_pct);
   if(elapsed_minutes >= 120)
      target = MathMin(target, strategy_roi_120_min_pct);
   return target;
  }

double Strategy_PositionProfitPct(const ENUM_POSITION_TYPE position_type,
                                  const double open_price)
  {
   if(open_price <= 0.0)
      return 0.0;
   if(position_type == POSITION_TYPE_BUY)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return (bid - open_price) / open_price * 100.0;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return (open_price - ask) / open_price * 100.0;
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   const double planned_stop_distance = atr * strategy_atr_stop_mult;
   if(ask <= 0.0 || bid <= 0.0 || planned_stop_distance <= 0.0)
      return true;
   if((ask - bid) > planned_stop_distance * 0.08)
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

   double var_curr = 0.0;
   double ott_curr = 0.0;
   double var_prev = 0.0;
   double ott_prev = 0.0;
   if(!Strategy_ComputeOttSnapshot(var_curr, ott_curr, var_prev, ott_prev))
      return false;

   QM_OrderType side = QM_BUY;
   bool has_signal = false;
   if(var_prev <= ott_prev && var_curr > ott_curr)
     {
      side = QM_BUY;
      has_signal = true;
     }
   else if(var_prev >= ott_prev && var_curr < ott_curr)
     {
      side = QM_SELL;
      has_signal = true;
     }

   if(!has_signal)
      return false;

   const double entry = QM_EntryMarketPrice(side);
   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_stop_mult);
   if(entry <= 0.0 || sl <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "FT_FOTT_VAR_CROSS_ABOVE_OTT" : "FT_FOTT_VAR_CROSS_BELOW_OTT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(strategy_trailing_percent <= 0.0 || strategy_trailing_offset_percent <= 0.0)
      return;

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   datetime open_time = 0;
   if(!Strategy_SelectOurPosition(ticket, position_type, open_price, open_time))
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || open_price <= 0.0)
      return;

   if(position_type == POSITION_TYPE_BUY)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid < open_price * (1.0 + strategy_trailing_offset_percent / 100.0))
         return;
      const double target_sl = QM_TM_NormalizePrice(_Symbol, bid * (1.0 - strategy_trailing_percent / 100.0));
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(target_sl > 0.0 && (current_sl <= 0.0 || target_sl > current_sl + point * 0.5))
         QM_TM_MoveSL(ticket, target_sl, "FT_FOTT_TRAIL_LONG");
     }
   else
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask > open_price * (1.0 - strategy_trailing_offset_percent / 100.0))
         return;
      const double target_sl = QM_TM_NormalizePrice(_Symbol, ask * (1.0 + strategy_trailing_percent / 100.0));
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(target_sl > 0.0 && (current_sl <= 0.0 || target_sl < current_sl - point * 0.5))
         QM_TM_MoveSL(ticket, target_sl, "FT_FOTT_TRAIL_SHORT");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const double adx = QM_ADX(_Symbol, PERIOD_CURRENT, strategy_adx_period, 1);
   if(adx > strategy_adx_exit)
      return true;

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   datetime open_time = 0;
   if(!Strategy_SelectOurPosition(ticket, position_type, open_price, open_time))
      return false;

   const int elapsed_minutes = (int)((TimeCurrent() - open_time) / 60);
   const double roi_target = Strategy_NormalizedRoiTargetPct(elapsed_minutes);
   if(roi_target <= 0.0)
      return false;

   return (Strategy_PositionProfitPct(position_type, open_price) >= roi_target);
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
