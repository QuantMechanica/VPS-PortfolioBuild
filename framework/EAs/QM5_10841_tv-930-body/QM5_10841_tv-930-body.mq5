#property strict
#property version   "5.0"
#property description "QM5_10841 TradingView 930 NY Body Breakout"

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
input int    qm_ea_id                   = 10841;
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
input int    strategy_range_start_hhmm_ny = 930;
input int    strategy_range_minutes       = 5;
input int    strategy_entry_cutoff_hhmm_ny = 1030;
input int    strategy_exit_cutoff_hhmm_ny = 1600;
input double strategy_rr_target           = 2.0;
input int    strategy_min_stop_forex_pips = 10;
input int    strategy_min_stop_nonfx_ticks = 1500;
input int    strategy_atr_period          = 14;
input double strategy_stop_atr_buffer_mult = 0.0;

int    g_ny_day_key = 0;
bool   g_range_ready = false;
bool   g_trade_taken_today = false;
double g_range_high = 0.0;
double g_range_low = 0.0;

datetime NYWallTimeToBroker(const int year,
                            const int mon,
                            const int day,
                            const int hhmm)
  {
   MqlDateTime wall;
   ZeroMemory(wall);
   wall.year = year;
   wall.mon  = mon;
   wall.day  = day;
   wall.hour = hhmm / 100;
   wall.min  = hhmm % 100;
   wall.sec  = 0;

   const datetime ny_wall = StructToTime(wall);
   const datetime standard_utc = ny_wall + 5 * 3600;
   const datetime utc = QM_IsUSDSTUTC(standard_utc) ? (ny_wall + 4 * 3600) : standard_utc;
   return QM_UTCToBroker(utc);
  }

datetime BrokerToNYWallTime(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   return utc - (QM_IsUSDSTUTC(utc) ? 4 * 3600 : 5 * 3600);
  }

int NYDayKey(const datetime broker_time)
  {
   MqlDateTime ny;
   ZeroMemory(ny);
   TimeToStruct(BrokerToNYWallTime(broker_time), ny);
   return ny.year * 10000 + ny.mon * 100 + ny.day;
  }

int NYHhmm(const datetime broker_time)
  {
   MqlDateTime ny;
   ZeroMemory(ny);
   TimeToStruct(BrokerToNYWallTime(broker_time), ny);
   return ny.hour * 100 + ny.min;
  }

void RefreshNYDayState(const datetime broker_time)
  {
   const int day_key = NYDayKey(broker_time);
   if(day_key == g_ny_day_key)
      return;

   g_ny_day_key = day_key;
   g_range_ready = false;
   g_trade_taken_today = false;
   g_range_high = 0.0;
   g_range_low = 0.0;
  }

int AddMinutesToHhmm(const int hhmm, const int minutes)
  {
   const int total = (hhmm / 100) * 60 + (hhmm % 100) + minutes;
   return (total / 60) * 100 + (total % 60);
  }

bool SymbolLooksForex(const string symbol)
  {
   const int dot = StringFind(symbol, ".");
   const string base = (dot >= 0) ? StringSubstr(symbol, 0, dot) : symbol;
   if(StringLen(base) != 6)
      return false;
   if(StringSubstr(base, 0, 3) == "XAU" ||
      StringSubstr(base, 0, 3) == "XAG" ||
      StringSubstr(base, 0, 3) == "XTI" ||
      StringSubstr(base, 0, 3) == "XNG")
      return false;
   return true;
  }

double MinStopFloorPrice()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(point <= 0.0 || tick_size <= 0.0)
      return 0.0;

   if(SymbolLooksForex(_Symbol))
     {
      const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      const double pip_size = ((digits == 3 || digits == 5) ? 10.0 : 1.0) * point;
      return strategy_min_stop_forex_pips * pip_size;
     }

   return strategy_min_stop_nonfx_ticks * tick_size;
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }

   return false;
  }

bool LoadOpeningRange(const datetime broker_time)
  {
   if(g_range_ready)
      return true;
   if(strategy_range_minutes <= 0)
      return false;

   const int range_end_hhmm = AddMinutesToHhmm(strategy_range_start_hhmm_ny,
                                               strategy_range_minutes);
   if(NYHhmm(broker_time) < range_end_hhmm)
      return false;

   MqlDateTime ny;
   ZeroMemory(ny);
   TimeToStruct(BrokerToNYWallTime(broker_time), ny);

   const datetime start_broker = NYWallTimeToBroker(ny.year, ny.mon, ny.day,
                                                    strategy_range_start_hhmm_ny);
   const datetime end_broker = NYWallTimeToBroker(ny.year, ny.mon, ny.day,
                                                  range_end_hhmm);

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   const int copied = CopyRates(_Symbol, PERIOD_M1, start_broker, end_broker - 1, rates); // perf-allowed: one closed NY opening-range load per day.
   if(copied < strategy_range_minutes)
      return false;

   double hi = -DBL_MAX;
   double lo = DBL_MAX;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].high > hi)
         hi = rates[i].high;
      if(rates[i].low < lo)
         lo = rates[i].low;
     }

   if(hi <= 0.0 || lo <= 0.0 || hi <= lo)
      return false;

   g_range_high = hi;
   g_range_low = lo;
   g_range_ready = true;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   if(tf != PERIOD_M1 && tf != PERIOD_M5)
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

   const datetime broker_now = TimeCurrent();
   RefreshNYDayState(broker_now);

   if(g_trade_taken_today || HasOurOpenPosition())
     {
      g_trade_taken_today = true;
      return false;
     }

   const int now_hhmm = NYHhmm(broker_now);
   if(now_hhmm <= AddMinutesToHhmm(strategy_range_start_hhmm_ny,
                                   strategy_range_minutes) ||
      now_hhmm > strategy_entry_cutoff_hhmm_ny)
      return false;

   if(!LoadOpeningRange(broker_now))
      return false;

   MqlRates closed_bar[];
   ArraySetAsSeries(closed_bar, true);
   if(CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 1, closed_bar) != 1) // perf-allowed: current closed signal candle only.
      return false;

   MqlDateTime ny;
   ZeroMemory(ny);
   TimeToStruct(BrokerToNYWallTime(broker_now), ny);
   const datetime range_end_broker = NYWallTimeToBroker(ny.year, ny.mon, ny.day,
                                                        AddMinutesToHhmm(strategy_range_start_hhmm_ny,
                                                                         strategy_range_minutes));
   if(closed_bar[0].time < range_end_broker)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double spread = MathMax(ask - bid, 0.0);
   const double min_stop = MinStopFloorPrice() + spread;
   const double atr_buffer = (strategy_stop_atr_buffer_mult > 0.0)
                             ? QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                      strategy_atr_period, 1) * strategy_stop_atr_buffer_mult
                             : 0.0;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(strategy_rr_target <= 0.0 || min_stop <= 0.0)
      return false;

   if(closed_bar[0].close > g_range_high)
     {
      const double entry = ask;
      const double stop = g_range_low - atr_buffer;
      const double dist = entry - stop;
      if(entry <= 0.0 || stop <= 0.0 || dist < min_stop)
         return false;

      req.type = QM_BUY;
      req.sl = NormalizeDouble(stop, digits);
      req.tp = NormalizeDouble(entry + dist * strategy_rr_target, digits);
      req.reason = "TV930_BODY_LONG";
      g_trade_taken_today = true;
      return true;
     }

   if(closed_bar[0].close < g_range_low)
     {
      const double entry = bid;
      const double stop = g_range_high + atr_buffer;
      const double dist = stop - entry;
      if(entry <= 0.0 || stop <= 0.0 || dist < min_stop)
         return false;

      req.type = QM_SELL;
      req.sl = NormalizeDouble(stop, digits);
      req.tp = NormalizeDouble(entry - dist * strategy_rr_target, digits);
      req.reason = "TV930_BODY_SHORT";
      g_trade_taken_today = true;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card baseline has no trailing, break-even, partial close, or add-on logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   RefreshNYDayState(TimeCurrent());
   return (HasOurOpenPosition() && NYHhmm(TimeCurrent()) >= strategy_exit_cutoff_hhmm_ny);
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
