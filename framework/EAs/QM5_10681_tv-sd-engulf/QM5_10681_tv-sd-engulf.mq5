#property strict
#property version   "5.0"
#property description "QM5_10681 TradingView supply/demand engulfment"

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
input int    qm_ea_id                   = 10681;
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
input int      strategy_trade_mode              = 0;      // -1 short only, 0 both, 1 long only
input int      strategy_aggregation_factor      = 3;
input int      strategy_zone_lookback_groups    = 40;
input int      strategy_atr_period              = 14;
input double   strategy_max_zone_atr_mult       = 3.0;
input double   strategy_stop_atr_buffer_mult    = 0.10;
input double   strategy_take_profit_rr          = 2.0;
input int      strategy_min_exit_bars           = 3;
input bool     strategy_session_filter_enabled  = true;
input int      strategy_session_start_hour      = 7;
input int      strategy_session_end_hour        = 21;
input datetime strategy_start_date              = D'1970.01.01 00:00';
input datetime strategy_end_date                = D'2099.12.31 23:59';

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const datetime now = TimeCurrent();
   if(now < strategy_start_date || now > strategy_end_date)
      return true;

   if(!strategy_session_filter_enabled)
      return false;

   MqlDateTime dt;
   TimeToStruct(now, dt);
   int start_h = strategy_session_start_hour;
   int end_h = strategy_session_end_hour;
   if(start_h < 0)
      start_h = 0;
   if(start_h > 23)
      start_h = 23;
   if(end_h < 0)
      end_h = 0;
   if(end_h > 24)
      end_h = 24;

   if(start_h == end_h)
      return false;

   bool inside = false;
   if(start_h < end_h)
      inside = (dt.hour >= start_h && dt.hour < end_h);
   else
      inside = (dt.hour >= start_h || dt.hour < end_h);
   if(!inside)
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

   if(strategy_aggregation_factor < 1 ||
      strategy_zone_lookback_groups < 2 ||
      strategy_atr_period < 1 ||
      strategy_max_zone_atr_mult <= 0.0 ||
      strategy_take_profit_rr <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || atr <= 0.0)
      return false;

   const double o1 = iOpen(_Symbol, _Period, 1);
   const double c1 = iClose(_Symbol, _Period, 1);
   const double h1 = iHigh(_Symbol, _Period, 1);
   const double l1 = iLow(_Symbol, _Period, 1);
   const double o2 = iOpen(_Symbol, _Period, 2);
   const double c2 = iClose(_Symbol, _Period, 2);
   const double h2 = iHigh(_Symbol, _Period, 2);
   const double l2 = iLow(_Symbol, _Period, 2);
   if(o1 <= 0.0 || c1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 ||
      o2 <= 0.0 || c2 <= 0.0 || h2 <= 0.0 || l2 <= 0.0)
      return false;

   const bool bullish_engulf = (c1 > o1 && c2 < o2 && c1 >= o2 && o1 <= c2);
   const bool bearish_engulf = (c1 < o1 && c2 > o2 && c1 <= o2 && o1 >= c2);
   if(!bullish_engulf && !bearish_engulf)
      return false;

   static double used_demand_low[64];
   static double used_demand_high[64];
   static int used_demand_count = 0;
   static double used_supply_low[64];
   static double used_supply_high[64];
   static int used_supply_count = 0;

   const int agg = strategy_aggregation_factor;
   int max_groups = strategy_zone_lookback_groups;
   if(max_groups > 80)
      max_groups = 80;

   for(int g = 0; g < max_groups; ++g)
     {
      const int start_shift = 3 + g * agg;

      double group_high = -DBL_MAX;
      double group_low = DBL_MAX;
      for(int j = 0; j < agg; ++j)
        {
         const int sh = start_shift + j;
         const double hh = iHigh(_Symbol, _Period, sh);
         const double ll = iLow(_Symbol, _Period, sh);
         if(hh <= 0.0 || ll <= 0.0)
            return false;
         if(hh > group_high)
            group_high = hh;
         if(ll < group_low)
            group_low = ll;
        }

      double prev_high = -DBL_MAX;
      double prev_low = DBL_MAX;
      for(int j = 0; j < agg; ++j)
        {
         const int sh = start_shift + agg + j;
         const double hh = iHigh(_Symbol, _Period, sh);
         const double ll = iLow(_Symbol, _Period, sh);
         if(hh <= 0.0 || ll <= 0.0)
            return false;
         if(hh > prev_high)
            prev_high = hh;
         if(ll < prev_low)
            prev_low = ll;
        }

      const double group_open = iOpen(_Symbol, _Period, start_shift + agg - 1);
      const double group_close = iClose(_Symbol, _Period, start_shift);
      const double prev_open = iOpen(_Symbol, _Period, start_shift + (2 * agg) - 1);
      const double prev_close = iClose(_Symbol, _Period, start_shift + agg);
      if(group_open <= 0.0 || group_close <= 0.0 || prev_open <= 0.0 || prev_close <= 0.0)
         return false;

      const bool bullish_continuation = (group_close > group_open &&
                                         prev_close > prev_open &&
                                         group_high > prev_high &&
                                         group_low >= prev_low);
      const bool bearish_continuation = (group_close < group_open &&
                                         prev_close < prev_open &&
                                         group_low < prev_low &&
                                         group_high <= prev_high);

      if(bullish_engulf && strategy_trade_mode >= 0 && bullish_continuation)
        {
         const double zone_low = group_low;
         const double zone_high = MathMin(group_open, group_close);
         if(zone_high <= zone_low || (zone_high - zone_low) > atr * strategy_max_zone_atr_mult)
            continue;
         if(l1 > zone_high || h1 < zone_low)
            continue;

         bool already_used = false;
         for(int u = 0; u < used_demand_count; ++u)
           {
            if(MathAbs(used_demand_low[u] - zone_low) <= point * 2.0 &&
               MathAbs(used_demand_high[u] - zone_high) <= point * 2.0)
              {
               already_used = true;
               break;
              }
           }
         if(already_used)
            continue;

         req.type = QM_BUY;
         req.price = 0.0;
         req.sl = l2 - atr * strategy_stop_atr_buffer_mult;
         const double min_stop = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
         if((ask - req.sl) < min_stop)
            req.sl = ask - min_stop - point;
         req.tp = QM_TakeRR(_Symbol, req.type, ask, req.sl, strategy_take_profit_rr);
         req.reason = "tv_sd_engulf_long";

         if(req.sl > 0.0 && req.tp > 0.0 && req.sl < ask)
           {
            const int idx = used_demand_count % 64;
            used_demand_low[idx] = zone_low;
            used_demand_high[idx] = zone_high;
            used_demand_count++;
            return true;
           }
        }

      if(bearish_engulf && strategy_trade_mode <= 0 && bearish_continuation)
        {
         const double zone_low = MathMax(group_open, group_close);
         const double zone_high = group_high;
         if(zone_high <= zone_low || (zone_high - zone_low) > atr * strategy_max_zone_atr_mult)
            continue;
         if(l1 > zone_high || h1 < zone_low)
            continue;

         bool already_used = false;
         for(int u = 0; u < used_supply_count; ++u)
           {
            if(MathAbs(used_supply_low[u] - zone_low) <= point * 2.0 &&
               MathAbs(used_supply_high[u] - zone_high) <= point * 2.0)
              {
               already_used = true;
               break;
              }
           }
         if(already_used)
            continue;

         req.type = QM_SELL;
         req.price = 0.0;
         req.sl = h2 + atr * strategy_stop_atr_buffer_mult;
         const double min_stop = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
         if((req.sl - bid) < min_stop)
            req.sl = bid + min_stop + point;
         req.tp = QM_TakeRR(_Symbol, req.type, bid, req.sl, strategy_take_profit_rr);
         req.reason = "tv_sd_engulf_short";

         if(req.sl > 0.0 && req.tp > 0.0 && req.sl > bid)
           {
            const int idx = used_supply_count % 64;
            used_supply_low[idx] = zone_low;
            used_supply_high[idx] = zone_high;
            used_supply_count++;
            return true;
           }
        }
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card baseline has no trailing stop, break-even move, or partial close.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool have_position = false;
   ENUM_POSITION_TYPE pos_type = POSITION_TYPE_BUY;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      have_position = true;
      pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }

   if(!have_position)
      return false;

   if(!QM_IsNewBar())
      return false;

   const int bars_in_trade = iBarShift(_Symbol, _Period, open_time, false);
   if(bars_in_trade < strategy_min_exit_bars)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double o1 = iOpen(_Symbol, _Period, 1);
   const double c1 = iClose(_Symbol, _Period, 1);
   const double h1 = iHigh(_Symbol, _Period, 1);
   const double l1 = iLow(_Symbol, _Period, 1);
   const double o2 = iOpen(_Symbol, _Period, 2);
   const double c2 = iClose(_Symbol, _Period, 2);
   if(o1 <= 0.0 || c1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || o2 <= 0.0 || c2 <= 0.0)
      return false;

   const bool bullish_engulf = (c1 > o1 && c2 < o2 && c1 >= o2 && o1 <= c2);
   const bool bearish_engulf = (c1 < o1 && c2 > o2 && c1 <= o2 && o1 >= c2);
   const int agg = (strategy_aggregation_factor < 1) ? 1 : strategy_aggregation_factor;
   int max_groups = strategy_zone_lookback_groups;
   if(max_groups > 80)
      max_groups = 80;

   for(int g = 0; g < max_groups; ++g)
     {
      const int start_shift = 3 + g * agg;

      double group_high = -DBL_MAX;
      double group_low = DBL_MAX;
      double prev_high = -DBL_MAX;
      double prev_low = DBL_MAX;
      for(int j = 0; j < agg; ++j)
        {
         const double gh = iHigh(_Symbol, _Period, start_shift + j);
         const double gl = iLow(_Symbol, _Period, start_shift + j);
         const double ph = iHigh(_Symbol, _Period, start_shift + agg + j);
         const double pl = iLow(_Symbol, _Period, start_shift + agg + j);
         if(gh <= 0.0 || gl <= 0.0 || ph <= 0.0 || pl <= 0.0)
            return false;
         if(gh > group_high)
            group_high = gh;
         if(gl < group_low)
            group_low = gl;
         if(ph > prev_high)
            prev_high = ph;
         if(pl < prev_low)
            prev_low = pl;
        }

      const double group_open = iOpen(_Symbol, _Period, start_shift + agg - 1);
      const double group_close = iClose(_Symbol, _Period, start_shift);
      const double prev_open = iOpen(_Symbol, _Period, start_shift + (2 * agg) - 1);
      const double prev_close = iClose(_Symbol, _Period, start_shift + agg);
      if(group_open <= 0.0 || group_close <= 0.0 || prev_open <= 0.0 || prev_close <= 0.0)
         return false;

      const bool bullish_continuation = (group_close > group_open &&
                                         prev_close > prev_open &&
                                         group_high > prev_high &&
                                         group_low >= prev_low);
      const bool bearish_continuation = (group_close < group_open &&
                                         prev_close < prev_open &&
                                         group_low < prev_low &&
                                         group_high <= prev_high);

      if(pos_type == POSITION_TYPE_SELL && bullish_engulf && bullish_continuation)
        {
         const double zone_low = group_low;
         const double zone_high = MathMin(group_open, group_close);
         if(zone_high > zone_low &&
            (zone_high - zone_low) <= atr * strategy_max_zone_atr_mult &&
            l1 <= zone_high && h1 >= zone_low)
            return true;
        }

      if(pos_type == POSITION_TYPE_BUY && bearish_engulf && bearish_continuation)
        {
         const double zone_low = MathMax(group_open, group_close);
         const double zone_high = group_high;
         if(zone_high > zone_low &&
            (zone_high - zone_low) <= atr * strategy_max_zone_atr_mult &&
            l1 <= zone_high && h1 >= zone_low)
            return true;
        }
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
