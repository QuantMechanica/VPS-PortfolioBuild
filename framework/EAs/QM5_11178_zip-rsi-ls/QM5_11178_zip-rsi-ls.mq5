#property strict
#property version   "5.0"
#property description "QM5_11178 zip-rsi-ls — Cross-sectional RSI long/short basket (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_11178 — Zipline Daily RSI Top/Bottom Long-Short
// -----------------------------------------------------------------------------
// Source: Quantopian Zipline example momentum_pipeline.py (cross-sectional
// RSI ranking). Card: artifacts/cards_approved/QM5_11178_zip-rsi-ls.md (APPROVED).
//
// Cross-sectional (basket) RSI rank. Once per completed D1 bar the EA computes
// RSI(period) on the closed bar for EVERY symbol in a configured DWX basket,
// ranks them by RSI value (highest first), and trades the CHART symbol by its
// rank position:
//   * Long  if the chart symbol is in the TOP n_select by RSI  (strongest names).
//   * Short if the chart symbol is in the BOTTOM n_select by RSI (weakest names).
//
// RSI is used as a cross-sectional RANK (a STATE), not as a fixed
// overbought/oversold threshold and NOT as a fresh-cross EVENT. Entry fires the
// moment the chart symbol is inside its band; there is no double-cross
// requirement (that would be a zero-trade trap on a long-short ranker).
//
// Exit (daily rebalance):
//   * Close when the chart symbol leaves its selected band (no longer top/bottom).
//   * Close + reverse-eligible when the symbol flips from the long band to the
//     short band or vice versa (we close here; the opposite entry is allowed on
//     the next eligible closed bar — never both on the same bar).
//   * Emergency time stop: close after strategy_time_stop_d1_bars D1 bars even
//     if still ranked (re-entry only if still selected on the next rebalance).
// Safety stop: strategy_atr_sl_mult * ATR(atr_period) on D1 (card P2 stop).
//
// MULTI-SYMBOL basket EA: it reads foreign-symbol D1 closes/RSI. It MUST
// register its universe via QM_SymbolGuardInit + QM_BasketWarmupHistory in
// OnInit, or foreign-symbol reads return 0 in the tester -> 0 trades. P2
// distributes the universe across T1-T5 round-robin, so the long+short basket
// is realized one symbol per terminal, one position per symbol/magic.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11178;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = false;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_rsi_period          = 14;    // RSI lookback period (Zipline default 14)
input int    strategy_n_select            = 3;     // top/bottom N names traded (long top N, short bottom N)
input int    strategy_min_active_symbols  = 6;     // basket must have >= this many valid-RSI symbols
input int    strategy_time_stop_d1_bars   = 20;    // emergency time stop: close after this many D1 bars
input int    strategy_atr_period          = 20;    // D1 ATR period for the safety stop
input double strategy_atr_sl_mult         = 2.5;   // safety stop distance = mult * D1 ATR(period)
input double strategy_spread_atr_cap      = 0.50;  // skip entry if quoted spread / D1 ATR exceeds this

// -----------------------------------------------------------------------------
// Basket universe — registered in magic_numbers.csv with matching slots.
// GER40 ported to GDAXI.DWX (DAX 40, nearest matrix symbol); metals/oil and the
// FX/index legs use their .DWX matrix names. See SPEC.md §3.
// -----------------------------------------------------------------------------
const int STRATEGY_UNIVERSE_SIZE = 10;
string g_universe_symbols[10] =
  {
   "SP500.DWX", "NDX.DWX", "WS30.DWX", "GDAXI.DWX", "EURUSD.DWX",
   "GBPUSD.DWX", "USDJPY.DWX", "XAUUSD.DWX", "XAGUSD.DWX", "XTIUSD.DWX"
  };
int g_universe_slots[10] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      if(g_universe_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_CurrentSymbolSlot()
  {
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return qm_magic_slot_offset;
   return g_universe_slots[idx];
  }

// RSI on the closed D1 bar (shift 1). Returns false if the value is missing
// (foreign-symbol history not loaded yet).
bool Strategy_SymbolRSI(const string symbol, double &out_rsi)
  {
   out_rsi = 0.0;
   if(!QM_SymbolAssertOrLog(symbol))
      return false;
   const double rsi = QM_RSI(symbol, PERIOD_D1, strategy_rsi_period, 1);
   if(rsi <= 0.0)
      return false;        // 0/invalid -> treat as missing
   out_rsi = rsi;
   return true;
  }

// Build the RSI table for the whole basket; returns the count of valid symbols
// and (via out params) the chart symbol's RSI and its 0-based rank position
// (0 = highest RSI). Rank is only meaningful when the chart symbol is valid.
int Strategy_BuildRanking(double &out_self_rsi, int &out_self_rank)
  {
   out_self_rsi  = 0.0;
   out_self_rank = -1;

   double scores[10];
   int    indexes[10];
   int    count = 0;
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
     {
      double rsi = 0.0;
      if(!Strategy_SymbolRSI(g_universe_symbols[i], rsi))
         continue;
      scores[count]  = rsi;
      indexes[count] = i;
      ++count;
     }
   if(count <= 0)
      return 0;

   // Descending sort: highest RSI first.
   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(scores[j] > scores[i])
           {
            const double tmp_score = scores[i];
            scores[i] = scores[j];
            scores[j] = tmp_score;
            const int tmp_index = indexes[i];
            indexes[i] = indexes[j];
            indexes[j] = tmp_index;
           }

   const int self_index = Strategy_CurrentSymbolIndex();
   for(int i = 0; i < count; ++i)
      if(indexes[i] == self_index)
        {
         out_self_rank = i;
         out_self_rsi  = scores[i];
         break;
        }
   return count;
  }

// Effective number of names in each band: requested n_select, clamped so the
// long band and short band cannot overlap on a thin basket (>=1, <= count/2).
int Strategy_BandSize(const int count)
  {
   int band = strategy_n_select;
   if(band < 1)
      band = 1;
   const int half = count / 2;
   if(half >= 1 && band > half)
      band = half;
   return band;
  }

// Desired direction for the chart symbol given its rank: +1 long (top band),
// -1 short (bottom band), 0 not selected.
int Strategy_DesiredDirection(const int count, const int self_rank)
  {
   if(count <= 0 || self_rank < 0)
      return 0;
   const int band = Strategy_BandSize(count);
   if(self_rank < band)
      return 1;                         // top n_select by RSI -> long
   if(self_rank >= count - band)
      return -1;                        // bottom n_select by RSI -> short
   return 0;
  }

bool Strategy_HasOpenPosition()
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

// Direction of the current open position (+1 long, -1 short, 0 none).
int Strategy_OpenPositionDirection()
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
      return (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
     }
   return 0;
  }

// Number of completed D1 bars elapsed since the position opened.
int Strategy_OpenPositionDaysHeld()
  {
   const int magic = QM_FrameworkMagic();
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
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }
   if(open_time <= 0)
      return 0;

   int days = 0;
   for(int shift = 1; shift <= strategy_time_stop_d1_bars + 2; ++shift)
     {
      const datetime bar_open = iTime(_Symbol, PERIOD_D1, shift); // perf-allowed: daily hold-count, called only after framework new-bar gate.
      if(bar_open <= 0)
         break;
      if(bar_open >= open_time)
         days = shift;        // this closed D1 bar started at/after entry
      else
         break;               // bars are time-ordered; older bars precede entry
     }
   return days;
  }

double Strategy_D1ATR()
  {
   return QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_spread_atr_cap <= 0.0)
      return true;

   // .DWX invariant #1: tester quotes ask==bid (0 modeled spread). Never
   // fail-closed on zero spread — only block a genuinely wide quoted spread.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return true; // zero/invalid modeled spread -> allow

   const double atr = Strategy_D1ATR();
   if(atr <= 0.0)
      return true; // cannot scale -> do not block

   const double spread = ask - bid;
   return (spread <= atr * strategy_spread_atr_cap);
  }

// Cheap O(1) per-tick gate: only host the strategy on a D1 chart of a universe
// symbol. All ranking work runs on the closed-bar path in Strategy_EntrySignal.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_11178_ZIPRSI";
   req.symbol_slot = Strategy_CurrentSymbolSlot();
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   double self_rsi  = 0.0;
   int    self_rank = -1;
   const int count = Strategy_BuildRanking(self_rsi, self_rank);
   if(count < strategy_min_active_symbols)
      return false;           // basket too thin to rebalance (card filter)
   if(self_rank < 0)
      return false;           // chart symbol has no valid RSI this bar

   const int direction = Strategy_DesiredDirection(count, self_rank);
   if(direction == 0)
      return false;           // not in a selected band

   if(!Strategy_SpreadAllowsEntry())
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr = Strategy_D1ATR();
   if(atr <= 0.0)
      return false;

   const double sl_distance = atr * strategy_atr_sl_mult;
   req.sl = QM_StopRulesStopFromDistance(_Symbol, req.type, entry, sl_distance);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry)
      return false;
   if(req.type == QM_SELL && req.sl <= entry)
      return false;

   req.reason = (direction > 0) ? "QM5_11178_ZIPRSI_LONG_TOP"
                                : "QM5_11178_ZIPRSI_SHORT_BOTTOM";
   return true;
  }

// No active trade management beyond the fixed ATR safety stop. Exits are
// handled by the daily-rebalance rank logic in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_D1)
      return false;

   const int dir = Strategy_OpenPositionDirection();
   if(dir == 0)
      return false;

   // Emergency time stop: close after N completed D1 bars regardless of rank.
   if(strategy_time_stop_d1_bars > 0 &&
      Strategy_OpenPositionDaysHeld() >= strategy_time_stop_d1_bars)
      return true;

   double self_rsi  = 0.0;
   int    self_rank = -1;
   const int count = Strategy_BuildRanking(self_rsi, self_rank);
   if(count <= 0 || self_rank < 0)
      return false;            // no ranking info this bar -> hold

   // Close on any departure from the held band. A flip to the OPPOSITE band is
   // also a "no longer in my band" exit; the opposite entry is allowed on the
   // next eligible closed bar (never close + reopen on the same bar).
   const int desired = Strategy_DesiredDirection(count, self_rank);
   if(dir > 0 && desired != 1)
      return true;             // long but no longer top n_select
   if(dir < 0 && desired != -1)
      return true;             // short but no longer bottom n_select
   return false;
  }

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
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   // Basket EA: register the universe and pre-load D1 history so foreign-symbol
   // RSI/iTime reads return real data in the tester (FW7/FW9).
   QM_SymbolGuardInit(g_universe_symbols);
   const int warmup = strategy_rsi_period + strategy_atr_period + strategy_time_stop_d1_bars + 10;
   QM_BasketWarmupHistory(g_universe_symbols, PERIOD_D1, warmup);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11178\",\"ea\":\"zip-rsi-ls\"}");
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

   Strategy_ManageOpenPosition();

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

   if(!QM_IsNewBar())
      return;

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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
