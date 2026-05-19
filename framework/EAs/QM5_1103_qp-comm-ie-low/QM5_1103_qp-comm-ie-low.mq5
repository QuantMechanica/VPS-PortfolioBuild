#property strict
#property version   "5.0"
#property description "QM5_1103 Quantpedia Commodity Return Asymmetry IE Low"

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
input int    qm_ea_id                   = 1103;
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
input int    strategy_return_lookback_d1 = 260;
input int    strategy_min_bars_d1        = 270;
input int    strategy_bucket_size        = 2;
input int    strategy_atr_period_d1      = 20;
input double strategy_atr_sl_mult        = 5.0;

#define STRATEGY_UNIVERSE_COUNT 4

string   g_universe[STRATEGY_UNIVERSE_COUNT] = {"XAUUSD.DWX", "XAGUSD.DWX", "XTIUSD.DWX", "XNGUSD.DWX"};
int      g_last_entry_rebalance_day = 0;
int      g_last_exit_rebalance_day = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

int DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool DifferentMonth(const datetime a, const datetime b)
  {
   MqlDateTime da;
   MqlDateTime db;
   TimeToStruct(a, da);
   TimeToStruct(b, db);
   return (da.year != db.year || da.mon != db.mon);
  }

bool IsMonthlyRebalanceDay(int &rebalance_day_key)
  {
   rebalance_day_key = 0;
   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0);
   const datetime last_closed_d1 = iTime(_Symbol, PERIOD_D1, 1);
   if(current_d1 <= 0 || last_closed_d1 <= 0)
      return false;
   if(!DifferentMonth(current_d1, last_closed_d1))
      return false;

   rebalance_day_key = DayKey(last_closed_d1);
   return (rebalance_day_key > 0);
  }

bool ComputeIE(const string symbol, double &out_ie)
  {
   out_ie = 0.0;
   if(strategy_return_lookback_d1 <= 1 || strategy_min_bars_d1 < strategy_return_lookback_d1 + 1)
      return false;
   if(Bars(symbol, PERIOD_D1) < strategy_min_bars_d1)
      return false;

   double returns[260];
   if(strategy_return_lookback_d1 > 260)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int needed = strategy_return_lookback_d1 + 1;
   const int copied = CopyRates(symbol, PERIOD_D1, 1, needed, rates);
   if(copied != needed)
      return false;

   double sum = 0.0;
   int samples = 0;
   for(int i = 0; i < strategy_return_lookback_d1; ++i)
     {
      const double c0 = rates[i].close;
      const double c1 = rates[i + 1].close;
      if(c0 <= 0.0 || c1 <= 0.0)
         return false;
      const double r = (c0 / c1) - 1.0;
      returns[samples] = r;
      sum += r;
      samples++;
     }

   if(samples != strategy_return_lookback_d1)
      return false;

   const double mu = sum / (double)samples;
   double var_sum = 0.0;
   for(int i = 0; i < samples; ++i)
     {
      const double d = returns[i] - mu;
      var_sum += d * d;
     }

   const double sigma = MathSqrt(var_sum / (double)samples);
   if(sigma <= 0.0)
      return false;

   const double upper = mu + 2.0 * sigma;
   const double lower = mu - 2.0 * sigma;
   int high_tail = 0;
   int low_tail = 0;
   for(int i = 0; i < samples; ++i)
     {
      if(returns[i] > upper)
         high_tail++;
      else if(returns[i] < lower)
         low_tail++;
     }

   out_ie = (double)(high_tail - low_tail);
   return true;
  }

int CurrentSymbolSlot()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_COUNT; ++i)
      if(_Symbol == g_universe[i])
         return i;
   return qm_magic_slot_offset;
  }

int CurrentSymbolRankDirection()
  {
   string symbols[STRATEGY_UNIVERSE_COUNT];
   double ie[STRATEGY_UNIVERSE_COUNT];
   int eligible = 0;

   for(int i = 0; i < STRATEGY_UNIVERSE_COUNT; ++i)
     {
      SymbolSelect(g_universe[i], true);
      double value = 0.0;
      if(!ComputeIE(g_universe[i], value))
         continue;
      symbols[eligible] = g_universe[i];
      ie[eligible] = value;
      eligible++;
     }

   if(eligible < STRATEGY_UNIVERSE_COUNT)
      return 0;

   for(int i = 0; i < eligible - 1; ++i)
     {
      for(int j = i + 1; j < eligible; ++j)
        {
         if(ie[j] < ie[i])
           {
            const double tmp_ie = ie[i];
            ie[i] = ie[j];
            ie[j] = tmp_ie;
            const string tmp_symbol = symbols[i];
            symbols[i] = symbols[j];
            symbols[j] = tmp_symbol;
           }
        }
     }

   const int bucket = MathMax(1, MathMin(strategy_bucket_size, eligible / 2));
   for(int i = 0; i < bucket; ++i)
      if(symbols[i] == _Symbol)
         return 1;
   for(int i = eligible - bucket; i < eligible; ++i)
      if(symbols[i] == _Symbol)
         return -1;

   return 0;
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
   req.symbol_slot = CurrentSymbolSlot();
   req.expiration_seconds = 0;

   int rebalance_day_key = 0;
   if(!IsMonthlyRebalanceDay(rebalance_day_key))
      return false;
   if(g_last_entry_rebalance_day == rebalance_day_key)
      return false;
   g_last_entry_rebalance_day = rebalance_day_key;

   const int direction = CurrentSymbolRankDirection();
   if(direction == 0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (req.type == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                             : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr, strategy_atr_sl_mult);
   if(entry <= 0.0 || req.sl <= 0.0)
      return false;

   req.reason = (direction > 0) ? "QM5_1103_IE_LOW_LONG" : "QM5_1103_IE_HIGH_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, or partial management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   int rebalance_day_key = 0;
   if(!IsMonthlyRebalanceDay(rebalance_day_key))
      return false;
   if(g_last_exit_rebalance_day == rebalance_day_key)
      return false;

   g_last_exit_rebalance_day = rebalance_day_key;
   return true;
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
