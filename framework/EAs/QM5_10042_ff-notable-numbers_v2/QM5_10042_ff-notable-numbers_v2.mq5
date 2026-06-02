#property strict
#property version   "5.0"
#property description "QM5_10042 ForexFactory Notable Numbers _v2"

#include <QM/QM_Common.mqh>

// v2: source unchanged. Root cause: Q03 ONINIT_FAILED on GBPUSD.DWX
// _v2 forces fresh pipeline entry with distinct artifact for Q02 retest.

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
input int    qm_ea_id                   = 10042;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_sydney_start_hhmm = 2200;
input int    strategy_sydney_end_hhmm   = 700;
input int    strategy_tokyo_start_hhmm  = 0;
input int    strategy_london_end_hhmm   = 1700;
input int    strategy_min_spread_mult   = 3;

int      g_traded_day_keys[16];
int      g_traded_level_keys[16];
int      g_traded_slots_used = 0;

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
   InitRequest(req);

   if(_Period != PERIOD_M15)
      return false;
   if(!IsWithinSourceSession(iTime(_Symbol, _Period, 1))) // perf-allowed: structural/indicator read; called from QM_IsNewBar-gated context
      return false;

   int lookback = 0;
   int pattern = 0;
   double tp_pct = 0.0;
   double sl_pct = 0.0;
   if(!LoadSymbolSpec(lookback, pattern, tp_pct, sl_pct))
      return false;
   const double bar_open = iOpen(_Symbol, _Period, 1); // perf-allowed: structural/indicator read; called from QM_IsNewBar-gated context
   const double bar_high = iHigh(_Symbol, _Period, 1); // perf-allowed: structural/indicator read; called from QM_IsNewBar-gated context
   const double bar_low = iLow(_Symbol, _Period, 1); // perf-allowed: structural/indicator read; called from QM_IsNewBar-gated context
   if(bar_open <= 0.0 || bar_high <= 0.0 || bar_low <= 0.0)
      return false;

   double level = 0.0;
   if(FindTouchedLevel(pattern, bar_low, bar_high, level))
     {
      const int today = Yyyymmdd(iTime(_Symbol, _Period, 1)); // perf-allowed: structural/indicator read; called from QM_IsNewBar-gated context
      const int level_key = LevelKey(level);
      if(LevelTradedToday(today, level_key))
         return false;

      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double spread_points = (ask - bid) / _Point;

      if(bar_open > level && bar_low <= level && DailyAllAbove(level, lookback))
        {
         const double entry = ask;
         const double sl_dist = entry * sl_pct / 100.0;
         if(sl_dist / _Point < strategy_min_spread_mult * spread_points)
            return false;
         req.type = QM_BUY;
         req.price = 0.0;
         req.sl = NormalizeDouble(entry - sl_dist, _Digits);
         req.tp = NormalizeDouble(entry + entry * tp_pct / 100.0, _Digits);
         req.reason = StringFormat("FF_NOTABLE_LONG_%.8f", level);
         MarkLevelTradedToday(today, level_key);
         return true;
        }

      if(bar_open < level && bar_high >= level && DailyAllBelow(level, lookback))
        {
         const double entry = bid;
         const double sl_dist = entry * sl_pct / 100.0;
         if(sl_dist / _Point < strategy_min_spread_mult * spread_points)
            return false;
         req.type = QM_SELL;
         req.price = 0.0;
         req.sl = NormalizeDouble(entry + sl_dist, _Digits);
         req.tp = NormalizeDouble(entry - entry * tp_pct / 100.0, _Digits);
         req.reason = StringFormat("FF_NOTABLE_SHORT_%.8f", level);
         MarkLevelTradedToday(today, level_key);
         return true;
        }
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, or partial-close management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!HasOpenPosition())
      return false;
   return !IsWithinSourceSession(TimeCurrent());
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
  }

void InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

string BaseSymbol()
  {
   string s = _Symbol;
   const int dot = StringFind(s, ".");
   if(dot > 0)
      s = StringSubstr(s, 0, dot);
   return s;
  }

bool LoadSymbolSpec(int &lookback, int &pattern, double &tp_pct, double &sl_pct)
  {
   const string s = BaseSymbol();
   if(s == "GBPUSD")
     {
      lookback = 22;
      pattern = 0;
      tp_pct = 0.4;
      sl_pct = 0.4;
      return true;
     }
   if(s == "USDJPY")
     {
      lookback = 20;
      pattern = 444;
      tp_pct = 0.25;
      sl_pct = 0.25;
      return true;
     }
   if(s == "EURGBP")
     {
      lookback = 13;
      pattern = 66;
      tp_pct = 0.35;
      sl_pct = 0.9;
      return true;
     }
   if(s == "AUDUSD")
     {
      lookback = 42;
      pattern = 33;
      tp_pct = 0.85;
      sl_pct = 0.55;
      return true;
     }
   return false;
  }

int Yyyymmdd(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int LevelKey(const double level)
  {
   return (int)MathRound(level / _Point);
  }

bool LevelTradedToday(const int day_key, const int level_key)
  {
   for(int i = 0; i < g_traded_slots_used; ++i)
     {
      if(g_traded_day_keys[i] == day_key && g_traded_level_keys[i] == level_key)
         return true;
     }
   return false;
  }

void MarkLevelTradedToday(const int day_key, const int level_key)
  {
   if(LevelTradedToday(day_key, level_key))
      return;

   if(g_traded_slots_used < 16)
     {
      g_traded_day_keys[g_traded_slots_used] = day_key;
      g_traded_level_keys[g_traded_slots_used] = level_key;
      ++g_traded_slots_used;
      return;
     }

   for(int i = 1; i < 16; ++i)
     {
      g_traded_day_keys[i - 1] = g_traded_day_keys[i];
      g_traded_level_keys[i - 1] = g_traded_level_keys[i];
     }
   g_traded_day_keys[15] = day_key;
   g_traded_level_keys[15] = level_key;
  }

int Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

bool HhmmInWindow(const int hhmm, const int start_hhmm, const int end_hhmm)
  {
   if(start_hhmm == end_hhmm)
      return true;
   if(start_hhmm < end_hhmm)
      return (hhmm >= start_hhmm && hhmm < end_hhmm);
   return (hhmm >= start_hhmm || hhmm < end_hhmm);
  }

bool IsWithinSourceSession(const datetime t)
  {
   const string s = BaseSymbol();
   const int hhmm = Hhmm(t);
   if(s == "USDJPY")
      return true;
   if(s == "GBPUSD")
      return HhmmInWindow(hhmm, strategy_sydney_start_hhmm, strategy_sydney_end_hhmm);
   if(s == "EURGBP")
      return HhmmInWindow(hhmm, strategy_tokyo_start_hhmm, strategy_sydney_end_hhmm);
   if(s == "AUDUSD")
      return HhmmInWindow(hhmm, strategy_tokyo_start_hhmm, strategy_london_end_hhmm);
   return false;
  }

bool HasOpenPosition()
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

double PatternUnit(const int pattern)
  {
   if(BaseSymbol() == "USDJPY" && pattern == 444)
      return _Point;
   return (StringFind(BaseSymbol(), "JPY") >= 0) ? 0.01 : 0.0001;
  }

int PatternDigits(const int pattern)
  {
   if(pattern >= 100)
      return 3;
   if(pattern >= 10)
      return 2;
   return 2;
  }

double Pow10Int(const int n)
  {
   double v = 1.0;
   for(int i = 0; i < n; ++i)
      v *= 10.0;
   return v;
  }

bool FindTouchedLevel(const int pattern, const double low, const double high, double &level)
  {
   const double unit = PatternUnit(pattern);
   const int digits = PatternDigits(pattern);
   const double step = unit * Pow10Int(digits);
   const double offset = pattern * unit;
   if(unit <= 0.0 || step <= 0.0 || high < low)
      return false;

   double candidate = MathFloor((low - offset) / step) * step + offset;
   while(candidate < low - (_Point * 0.5))
      candidate += step;

   if(candidate <= high + (_Point * 0.5))
     {
      level = NormalizeDouble(candidate, _Digits);
      return true;
     }
   return false;
  }

bool DailyAllAbove(const double level, const int lookback)
  {
   for(int i = 1; i <= lookback; ++i)
     {
      const double hi = iHigh(_Symbol, PERIOD_D1, i); // perf-allowed: structural/indicator read; called from QM_IsNewBar-gated context
      const double lo = iLow(_Symbol, PERIOD_D1, i); // perf-allowed: structural/indicator read; called from QM_IsNewBar-gated context
      if(hi <= 0.0 || lo <= 0.0 || hi <= level || lo <= level)
         return false;
     }
   return true;
  }

bool DailyAllBelow(const double level, const int lookback)
  {
   for(int i = 1; i <= lookback; ++i)
     {
      const double hi = iHigh(_Symbol, PERIOD_D1, i); // perf-allowed: structural/indicator read; called from QM_IsNewBar-gated context
      const double lo = iLow(_Symbol, PERIOD_D1, i); // perf-allowed: structural/indicator read; called from QM_IsNewBar-gated context
      if(hi <= 0.0 || lo <= 0.0 || hi >= level || lo >= level)
         return false;
     }
   return true;
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }

