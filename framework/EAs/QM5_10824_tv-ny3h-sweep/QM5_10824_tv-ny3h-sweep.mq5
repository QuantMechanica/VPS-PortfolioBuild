#property strict
#property version   "5.0"
#property description "QM5_10824 TradingView NY Open 3H Sweep Continuation"

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
input int    qm_ea_id                   = 10824;
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
input ENUM_TIMEFRAMES strategy_range_tf                 = PERIOD_H3;
input int             strategy_swing_lookback_bars      = 5;
input int             strategy_atr_period               = 14;
input double          strategy_stop_buffer_atr_fraction = 0.10;
input double          strategy_max_stop_range_mult      = 1.50;
input int             strategy_ny_open_start_hhmm       = 930;
input int             strategy_ny_open_end_hhmm         = 1030;
input int             strategy_ny_flat_hhmm             = 1100;
input bool            strategy_one_trade_per_day        = true;
input bool            strategy_breakeven_enabled        = true;
input double          strategy_max_spread_points        = 0.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

int      g_strategy_day_key = 0;
bool     g_strategy_trade_taken_today = false;
bool     g_strategy_long_swept = false;
bool     g_strategy_short_swept = false;
double   g_strategy_sweep_low = 0.0;
double   g_strategy_sweep_high = 0.0;

int Strategy_HhmmToMinutes(const int hhmm)
  {
   return (hhmm / 100) * 60 + (hhmm % 100);
  }

int Strategy_HhmmFromTime(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int Strategy_DayKeyFromTime(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

datetime Strategy_BrokerToNewYork(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   const int ny_offset_hours = QM_IsUSDSTUTC(utc) ? -4 : -5;
   return utc + ny_offset_hours * 3600;
  }

bool Strategy_HhmmInWindow(const int hhmm, const int start_hhmm, const int end_hhmm)
  {
   const int now_m = Strategy_HhmmToMinutes(hhmm);
   const int start_m = Strategy_HhmmToMinutes(start_hhmm);
   const int end_m = Strategy_HhmmToMinutes(end_hhmm);
   if(start_m == end_m)
      return true;
   if(start_m < end_m)
      return (now_m >= start_m && now_m < end_m);
   return (now_m >= start_m || now_m < end_m);
  }

void Strategy_ResetDay(const int day_key)
  {
   g_strategy_day_key = day_key;
   g_strategy_trade_taken_today = false;
   g_strategy_long_swept = false;
   g_strategy_short_swept = false;
   g_strategy_sweep_low = 0.0;
   g_strategy_sweep_high = 0.0;
  }

void Strategy_EnsureDay(const datetime broker_time)
  {
   const int day_key = Strategy_DayKeyFromTime(Strategy_BrokerToNewYork(broker_time));
   if(day_key != g_strategy_day_key)
      Strategy_ResetDay(day_key);
  }

bool Strategy_HasOurOpenPosition()
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
      return true;
     }
   return false;
  }

bool Strategy_SpreadAllows()
  {
   if(strategy_max_spread_points <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   return ((ask - bid) / point <= strategy_max_spread_points);
  }

bool Strategy_LoadClosedBarAndSwings(MqlRates &bar,
                                     double &swing_high,
                                     double &swing_low)
  {
   const int lookback = MathMax(1, MathMin(strategy_swing_lookback_bars, 32));
   const int need = lookback + 1;
   MqlRates bars[];
   ArraySetAsSeries(bars, true); // bars[0] = shift 1 (last closed bar), bars[i] = shift i+1
   if(CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, need, bars) != need) // perf-allowed: bounded M5 structural swing window, called only after QM_IsNewBar.
      return false;

   // bars[0] is the just-closed signal bar; the swing is the prior `lookback`
   // closed bars (shifts 2..lookback+1), excluding the signal bar itself.
   bar = bars[0];
   swing_high = bars[1].high;
   swing_low = bars[1].low;
   for(int i = 2; i < need; ++i)
     {
      swing_high = MathMax(swing_high, bars[i].high);
      swing_low = MathMin(swing_low, bars[i].low);
     }

   return (bar.time > 0 && swing_high > 0.0 && swing_low > 0.0);
  }

bool Strategy_LoadPreviousRange(double &range_high, double &range_low)
  {
   MqlRates range_bar[1];
   if(CopyRates(_Symbol, strategy_range_tf, 1, 1, range_bar) != 1) // perf-allowed: one closed H3 range bar, called only after QM_IsNewBar.
      return false;

   range_high = range_bar[0].high;
   range_low = range_bar[0].low;
   return (range_high > range_low && range_low > 0.0);
  }

void Strategy_ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_BuildRequest(const bool want_long,
                           const double prev3h_high,
                           const double prev3h_low,
                           QM_EntryRequest &req)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, MathMax(1, strategy_atr_period), 1);
   const double entry = want_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || atr <= 0.0 || entry <= 0.0 || prev3h_high <= prev3h_low)
      return false;

   const double buffer = atr * MathMax(0.0, strategy_stop_buffer_atr_fraction);
   const double sl = want_long ? g_strategy_sweep_low - buffer
                               : g_strategy_sweep_high + buffer;
   const double tp = want_long ? prev3h_high : prev3h_low;
   const double stop_distance = MathAbs(entry - sl);
   const double range_distance = prev3h_high - prev3h_low;

   if(sl <= 0.0 || tp <= 0.0 || stop_distance < point * 10.0)
      return false;
   if(stop_distance > range_distance * MathMax(0.1, strategy_max_stop_range_mult))
      return false;
   if(want_long && (sl >= entry || tp <= entry))
      return false;
   if(!want_long && (sl <= entry || tp >= entry))
      return false;

   req.type = want_long ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = NormalizeDouble(sl, _Digits);
   req.tp = NormalizeDouble(tp, _Digits);
   req.reason = want_long ? "TV_NY3H_SWEEP_LONG" : "TV_NY3H_SWEEP_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// No Trade Filter (time, spread, news)
// Return TRUE to BLOCK new trading this tick. News is handled by the framework
// and Strategy_NewsFilterHook; this hook adds the card's NY window and spread gate.
bool Strategy_NoTradeFilter()
  {
   Strategy_EnsureDay(TimeCurrent());
   if(Strategy_HasOurOpenPosition())
      return false;

   if(!Strategy_SpreadAllows())
      return true;

   const int ny_hhmm = Strategy_HhmmFromTime(Strategy_BrokerToNewYork(TimeCurrent()));
   if(!Strategy_HhmmInWindow(ny_hhmm, strategy_ny_open_start_hhmm, strategy_ny_open_end_hhmm))
      return true;

   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetRequest(req);

   MqlRates bar;
   double swing_high = 0.0;
   double swing_low = 0.0;
   if(!Strategy_LoadClosedBarAndSwings(bar, swing_high, swing_low))
      return false;

   Strategy_EnsureDay(bar.time);

   if(Strategy_HasOurOpenPosition())
     {
      g_strategy_trade_taken_today = true;
      return false;
     }
   if(strategy_one_trade_per_day && g_strategy_trade_taken_today)
      return false;

   const datetime ny_bar_time = Strategy_BrokerToNewYork(bar.time);
   const int ny_hhmm = Strategy_HhmmFromTime(ny_bar_time);
   if(!Strategy_HhmmInWindow(ny_hhmm, strategy_ny_open_start_hhmm, strategy_ny_open_end_hhmm))
      return false;

   double prev3h_high = 0.0;
   double prev3h_low = 0.0;
   if(!Strategy_LoadPreviousRange(prev3h_high, prev3h_low))
      return false;

   if(bar.low < prev3h_low)
     {
      g_strategy_long_swept = true;
      g_strategy_sweep_low = (g_strategy_sweep_low <= 0.0) ? bar.low : MathMin(g_strategy_sweep_low, bar.low);
     }
   if(bar.high > prev3h_high)
     {
      g_strategy_short_swept = true;
      g_strategy_sweep_high = MathMax(g_strategy_sweep_high, bar.high);
     }

   if(g_strategy_long_swept && bar.close > swing_high &&
      Strategy_BuildRequest(true, prev3h_high, prev3h_low, req))
     {
      g_strategy_trade_taken_today = true;
      return true;
     }

   if(g_strategy_short_swept && bar.close < swing_low &&
      Strategy_BuildRequest(false, prev3h_high, prev3h_low, req))
     {
      g_strategy_trade_taken_today = true;
      return true;
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   if(!strategy_breakeven_enabled)
      return;

   const int magic = QM_FrameworkMagic();
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
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

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      if(pos_type == POSITION_TYPE_BUY)
        {
         const double initial_r = open_price - current_sl;
         if(initial_r > 0.0 && bid >= open_price + initial_r && current_sl < open_price)
            QM_TM_MoveSL(ticket, NormalizeDouble(open_price, _Digits), "TV_NY3H_BE_1R");
        }
      else if(pos_type == POSITION_TYPE_SELL)
        {
         const double initial_r = current_sl - open_price;
         if(initial_r > 0.0 && ask <= open_price - initial_r && current_sl > open_price)
            QM_TM_MoveSL(ticket, NormalizeDouble(open_price, _Digits), "TV_NY3H_BE_1R");
        }
     }
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const int ny_hhmm = Strategy_HhmmFromTime(Strategy_BrokerToNewYork(TimeCurrent()));
   if(ny_hhmm < strategy_ny_flat_hhmm)
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

// News Filter Hook
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
