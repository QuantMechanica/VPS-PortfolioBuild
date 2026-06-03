#property strict
#property version   "5.0"
#property description "QM5_9121_v2 Alpha Architect variable TMA close-cross"

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
input int    qm_ea_id                   = 9121;
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
input int    strategy_tma_period         = 10;
input int    strategy_atr_period         = 20;
input double strategy_atr_sl_mult        = 2.5;
input int    strategy_warmup_d1_bars     = 60;
input int    strategy_spread_median_days = 20;
input double strategy_spread_mult        = 2.5;

const int STRATEGY_UNIVERSE_SIZE = 9;
string    g_universe_symbols[9] =
  {
   "SP500.DWX", "NDX.DWX", "WS30.DWX", "GDAXI.DWX", "XAUUSD.DWX",
   "XTIUSD.DWX", "EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX"
  };
int       g_universe_slots[9] = {0, 1, 2, 3, 4, 5, 6, 7, 8};

datetime g_last_d1_bar_time              = 0;
bool     g_d1_state_ready                = false;
datetime g_last_entry_d1_bar_time        = 0;
double   g_close_1                       = 0.0;
double   g_close_2                       = 0.0;
double   g_tma_1                         = 0.0;
double   g_tma_2                         = 0.0;
double   g_median_spread_points          = 0.0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      if(g_universe_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int TMAWeight(const int offset)
  {
   int weight = 0;
   for(int a = 0; a < strategy_tma_period; ++a)
      for(int b = 0; b < strategy_tma_period; ++b)
        {
         const int c = offset - a - b;
         if(c >= 0 && c < strategy_tma_period)
            ++weight;
        }
   return weight;
  }

double TMAClose(const int shift)
  {
   if(strategy_tma_period < 2 || strategy_tma_period > 64)
      return 0.0;

   double weighted_sum = 0.0;
   const double divisor = (double)(strategy_tma_period * strategy_tma_period * strategy_tma_period);
   const int max_offset = 3 * (strategy_tma_period - 1);
   for(int offset = 0; offset <= max_offset; ++offset)
     {
      const double close_i = iClose(_Symbol, PERIOD_D1, shift + offset);
      if(close_i <= 0.0)
         return 0.0;
      weighted_sum += close_i * (double)TMAWeight(offset);
     }
   return weighted_sum / divisor;
  }

void RefreshSpreadMedian()
  {
   const int n = MathMin(strategy_spread_median_days, 64);
   if(n <= 0)
     {
      g_median_spread_points = 0.0;
      return;
     }

   double values[64];
   int count = 0;
   for(int shift = 1; shift <= n; ++shift)
     {
      const long spread = iSpread(_Symbol, PERIOD_D1, shift);
      if(spread <= 0)
         continue;
      values[count] = (double)spread;
      ++count;
     }

   if(count <= 0)
     {
      g_median_spread_points = 0.0;
      return;
     }

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(values[j] < values[i])
           {
            const double tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
           }

   g_median_spread_points = ((count % 2) == 1)
                            ? values[count / 2]
                            : 0.5 * (values[count / 2 - 1] + values[count / 2]);
  }

bool EnsureD1State()
  {
   g_d1_state_ready = false;
   if(strategy_tma_period < 2 || strategy_tma_period > 64 || strategy_warmup_d1_bars < 60)
      return false;
   if(Bars(_Symbol, PERIOD_D1) < strategy_warmup_d1_bars)
      return false;

   const datetime d1_bar_time = iTime(_Symbol, PERIOD_D1, 0);
   if(d1_bar_time <= 0)
      return false;

   if(d1_bar_time != g_last_d1_bar_time)
     {
      g_last_d1_bar_time = d1_bar_time;
      g_close_1 = iClose(_Symbol, PERIOD_D1, 1);
      g_close_2 = iClose(_Symbol, PERIOD_D1, 2);
      g_tma_1 = TMAClose(1);
      g_tma_2 = TMAClose(2);
      RefreshSpreadMedian();
     }

   g_d1_state_ready = (g_close_1 > 0.0 && g_close_2 > 0.0 && g_tma_1 > 0.0 && g_tma_2 > 0.0);
   return g_d1_state_ready;
  }

bool SpreadAllowsEntry()
  {
   if(g_median_spread_points <= 0.0 || strategy_spread_mult <= 0.0)
      return true;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;
   return ((double)current_spread <= g_median_spread_points * strategy_spread_mult);
  }

bool GetOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;

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
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return true;
   if(qm_magic_slot_offset != g_universe_slots[idx])
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

   if(!EnsureD1State())
      return false;
   if(g_last_entry_d1_bar_time == g_last_d1_bar_time)
      return false;
   if(!SpreadAllowsEntry())
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   if(GetOurPosition(ticket, ptype))
      return false;

   const bool bullish_cross = (g_close_1 > g_tma_1 && g_close_2 <= g_tma_2);
   const bool bearish_cross = (g_close_1 < g_tma_1 && g_close_2 >= g_tma_2);
   if(!bullish_cross && !bearish_cross)
      return false;

   req.type = bullish_cross ? QM_BUY : QM_SELL;
   const double entry = bullish_cross ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr_d1, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry)
      return false;
   if(req.type == QM_SELL && req.sl <= entry)
      return false;

   req.reason = bullish_cross ? "TMA10_D1_CLOSE_CROSS_LONG" : "TMA10_D1_CLOSE_CROSS_SHORT";
   g_last_entry_d1_bar_time = g_last_d1_bar_time;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!EnsureD1State())
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   if(!GetOurPosition(ticket, ptype))
      return false;

   if(ptype == POSITION_TYPE_BUY)
      return (g_close_1 <= g_tma_1);
   if(ptype == POSITION_TYPE_SELL)
      return (g_close_1 >= g_tma_1);
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9121\",\"ea\":\"aa-tma10-cross\"}");
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
