#property strict
#property version   "5.0"
#property description "QM5_9274 MQL5 5 Drives Harmonic Pattern"

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
input int    qm_ea_id                   = 9274;
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
input int    strategy_pivot_left        = 5;
input int    strategy_pivot_right       = 5;
input int    strategy_min_span_bars     = 30;
input int    strategy_max_span_bars     = 160;
input int    strategy_pivot_scan_bars   = 190;
input double strategy_drive_min         = 1.13;
input double strategy_drive_max         = 1.618;
input double strategy_mid_ext_min       = 1.618;
input double strategy_mid_ext_max       = 2.24;
input double strategy_final_retrace     = 0.50;
input double strategy_ratio_tolerance   = 0.10;
input int    strategy_atr_period        = 14;
input double strategy_atr_cap_mult      = 3.0;
input double strategy_stop_fib_ext      = 1.618;
input double strategy_tp_fraction       = 0.6666666667;
input int    strategy_time_exit_bars    = 30;

struct FiveDrivesPattern
  {
   bool     bullish;
   int      a_shift;
   int      f_shift;
   double   b_price;
   double   e_price;
   double   f_price;
   datetime a_time;
   datetime f_time;
   string   key;
  };

string g_traded_pattern_key = "";

bool RatioInRange(const double value, const double reference, const double lo, const double hi)
  {
   if(value <= 0.0 || reference <= 0.0 || lo <= 0.0 || hi <= 0.0)
      return false;
   const double ratio = value / reference;
   return (ratio >= lo && ratio <= hi);
  }

bool RatioNear(const double value, const double reference, const double target, const double tolerance)
  {
   if(value <= 0.0 || reference <= 0.0 || target <= 0.0 || tolerance < 0.0)
      return false;
   const double ideal = target * reference;
   return (MathAbs(value - ideal) <= tolerance * reference);
  }

bool DetectFiveDrivesPattern(FiveDrivesPattern &pattern)
  {
   pattern.bullish = true;
   pattern.a_shift = 0;
   pattern.f_shift = 0;
   pattern.b_price = 0.0;
   pattern.e_price = 0.0;
   pattern.f_price = 0.0;
   pattern.a_time = 0;
   pattern.f_time = 0;
   pattern.key = "";

   if(strategy_pivot_left < 1 || strategy_pivot_right < 1 ||
      strategy_min_span_bars < 1 || strategy_max_span_bars < strategy_min_span_bars)
      return false;

   int scan_bars = strategy_pivot_scan_bars;
   const int min_scan = strategy_max_span_bars + strategy_pivot_left + strategy_pivot_right + 20;
   if(scan_bars < min_scan)
      scan_bars = min_scan;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 1, scan_bars, rates); // perf-allowed: closed-bar harmonic pivot scan; caller gates EntrySignal with QM_IsNewBar().
   if(copied < strategy_pivot_left + strategy_pivot_right + strategy_min_span_bars)
      return false;

   int piv_type[64];
   int piv_shift[64];
   double piv_price[64];
   datetime piv_time[64];
   int piv_count = 0;

   const int oldest_idx = copied - strategy_pivot_left - 1;
   const int newest_idx = strategy_pivot_right + 1;
   for(int idx = oldest_idx; idx >= newest_idx; --idx)
     {
      bool is_high = true;
      bool is_low = true;
      const double current_high = rates[idx].high;
      const double current_low = rates[idx].low;
      if(current_high <= 0.0 || current_low <= 0.0)
         continue;

      for(int j = 1; j <= strategy_pivot_left; ++j)
        {
         if(rates[idx + j].high > current_high)
            is_high = false;
         if(rates[idx + j].low < current_low)
            is_low = false;
        }
      for(int j = 1; j <= strategy_pivot_right; ++j)
        {
         if(rates[idx - j].high > current_high)
            is_high = false;
         if(rates[idx - j].low < current_low)
            is_low = false;
        }

      if(is_high == is_low)
         continue;

      const int ptype = is_high ? 1 : -1;
      const double price = is_high ? current_high : current_low;
      if(piv_count > 0 && piv_type[piv_count - 1] == ptype)
        {
         const bool replace = (ptype == 1 && price > piv_price[piv_count - 1]) ||
                              (ptype == -1 && price < piv_price[piv_count - 1]);
         if(replace)
           {
            piv_shift[piv_count - 1] = idx + 1;
            piv_price[piv_count - 1] = price;
            piv_time[piv_count - 1] = rates[idx].time;
           }
         continue;
        }

      if(piv_count >= 64)
         break;
      piv_type[piv_count] = ptype;
      piv_shift[piv_count] = idx + 1;
      piv_price[piv_count] = price;
      piv_time[piv_count] = rates[idx].time;
      piv_count++;
     }

   if(piv_count < 6)
      return false;

   const int s = piv_count - 6;
   const int type_a = piv_type[s];
   const int type_b = piv_type[s + 1];
   const int type_c = piv_type[s + 2];
   const int type_d = piv_type[s + 3];
   const int type_e = piv_type[s + 4];
   const int type_f = piv_type[s + 5];

   const double price_b = piv_price[s + 1];
   const double price_c = piv_price[s + 2];
   const double price_d = piv_price[s + 3];
   const double price_e = piv_price[s + 4];
   const double price_f = piv_price[s + 5];
   const int span_bars = piv_shift[s] - piv_shift[s + 5];
   if(span_bars < strategy_min_span_bars || span_bars > strategy_max_span_bars)
      return false;

   bool found = false;
   bool bullish = false;
   if(type_a == 1 && type_b == -1 && type_c == 1 && type_d == -1 && type_e == 1 && type_f == -1)
     {
      const double xa_length = price_c - price_b;
      const double ab_length = price_c - price_d;
      const double bc_length = price_e - price_d;
      const double cd_length = price_e - price_f;
      found = RatioInRange(ab_length, xa_length, strategy_drive_min, strategy_drive_max) &&
              RatioInRange(bc_length, ab_length, strategy_mid_ext_min, strategy_mid_ext_max) &&
              RatioNear(cd_length, bc_length, strategy_final_retrace, strategy_ratio_tolerance) &&
              RatioNear(cd_length, ab_length, 1.0, strategy_ratio_tolerance) &&
              price_e > price_c &&
              price_f > price_b;
      bullish = found;
     }
   else if(type_a == -1 && type_b == 1 && type_c == -1 && type_d == 1 && type_e == -1 && type_f == 1)
     {
      const double xa_length = price_b - price_c;
      const double ab_length = price_d - price_c;
      const double bc_length = price_d - price_e;
      const double cd_length = price_f - price_e;
      found = RatioInRange(ab_length, xa_length, strategy_drive_min, strategy_drive_max) &&
              RatioInRange(bc_length, ab_length, strategy_mid_ext_min, strategy_mid_ext_max) &&
              RatioNear(cd_length, bc_length, strategy_final_retrace, strategy_ratio_tolerance) &&
              RatioNear(cd_length, ab_length, 1.0, strategy_ratio_tolerance) &&
              price_e < price_c &&
              price_f < price_b;
      bullish = false;
     }

   if(!found)
      return false;

   pattern.bullish = bullish;
   pattern.a_shift = piv_shift[s];
   pattern.f_shift = piv_shift[s + 5];
   pattern.b_price = price_b;
   pattern.e_price = price_e;
   pattern.f_price = price_f;
   pattern.a_time = piv_time[s];
   pattern.f_time = piv_time[s + 5];
   pattern.key = IntegerToString((long)pattern.a_time) + "_" + IntegerToString((long)pattern.f_time);
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
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

   FiveDrivesPattern pattern;
   if(!DetectFiveDrivesPattern(pattern))
      return false;
   if(pattern.key == g_traded_pattern_key)
      return false;

   const bool is_buy = pattern.bullish;
   req.type = is_buy ? QM_BUY : QM_SELL;
   const double entry = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                               : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double final_drive = MathAbs(pattern.e_price - pattern.f_price);
   const double stop_offset = (strategy_stop_fib_ext - 1.0) * final_drive;
   if(final_drive <= 0.0 || stop_offset <= 0.0)
      return false;

   const double raw_sl = is_buy ? (pattern.f_price - stop_offset)
                                : (pattern.f_price + stop_offset);
   const double raw_tp = is_buy ? (entry + strategy_tp_fraction * (pattern.e_price - entry))
                                : (entry - strategy_tp_fraction * (entry - pattern.e_price));
   req.sl = QM_StopRulesNormalizePrice(_Symbol, raw_sl);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, raw_tp);
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;
   if(is_buy && (req.sl >= entry || req.tp <= entry))
      return false;
   if(!is_buy && (req.sl <= entry || req.tp >= entry))
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double stop_distance = MathAbs(entry - req.sl);
   if(atr <= 0.0 || stop_distance <= 0.0 || stop_distance > strategy_atr_cap_mult * atr)
      return false;

   req.reason = is_buy ? "5DRIVES_BULLISH_TP2" : "5DRIVES_BEARISH_TP2";
   g_traded_pattern_key = pattern.key;
   return true;
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
   if(strategy_time_exit_bars <= 0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int seconds_per_bar = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(seconds_per_bar <= 0)
      return false;
   const datetime now = TimeCurrent();
   const long max_seconds = (long)strategy_time_exit_bars * seconds_per_bar;

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
      if(opened > 0 && (long)(now - opened) >= max_seconds)
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
