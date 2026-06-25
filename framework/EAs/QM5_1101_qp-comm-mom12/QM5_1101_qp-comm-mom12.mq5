#property strict
#property version   "5.0"
#property description "QM5_1101 Quantpedia Commodity Momentum 12-Month Cross-Sectional Rank"
// rework v3 2026-06-25 — upgraded framework wiring to current FW1 (2-axis news,
// stress, seed); kept the v2 lesson: cross-sectional rank needs QM_SymbolGuardInit
// + QM_BasketWarmupHistory in OnInit, else the tester returns 0 foreign-symbol
// D1 bars (SymbolSelect only adds to Market Watch) -> rank never resolves -> 0
// trades / Q02 MIN_TRADES fail. Mirrors sibling QM5_1246 basket warmup.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1101_qp-comm-mom12
// -----------------------------------------------------------------------------
// Cross-sectional commodity momentum (Miffre/Rallis JBF 2007, via Quantpedia).
// At each month-end, rank the DWX commodity universe by trailing 252-bar D1
// return. Each universe member runs as its own chart/magic (single-position-
// per-magic framework). This instance goes LONG if _Symbol is in the top-2 of
// the universe, SHORT if in the bottom-2, and exits at the next month-end
// rebalance when _Symbol leaves its bucket. ATR(20) D1 hard stop at 5.0x.
//
// The rank reads other members' closed D1 bars via iClose (shift>=1, closed
// bars only) — never the current forming bar.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1101;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_lookback_d1_bars      = 252;   // 12-month trailing return window
input int    strategy_min_history_d1_bars   = 270;   // rank-eligibility minimum D1 bars
input int    strategy_rank_slots_each_side  = 2;     // long top-N, short bottom-N
input int    strategy_atr_period            = 20;    // ATR(20) D1
input double strategy_atr_sl_mult           = 5.0;   // 5.0x ATR hard stop
input int    strategy_spread_median_days    = 20;    // median spread lookback window
input double strategy_spread_mult           = 3.0;   // skip if spread > N x median D1 spread

const int STRATEGY_UNIVERSE_SIZE = 4;
string    g_universe_symbols[4] = {"XAUUSD.DWX", "XAGUSD.DWX", "XTIUSD.DWX", "XNGUSD.DWX"};
int       g_last_entry_rebalance_key = 0;
int       g_last_exit_rebalance_key  = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      if(g_universe_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_RebalanceKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

// True on the first closed D1 bar of a new calendar month — i.e. the current
// (forming) D1 bar belongs to a different month than the last closed bar.
bool Strategy_IsMonthEndClosedBar()
  {
   const datetime closed_bar = iTime(_Symbol, PERIOD_D1, 1);
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0);
   if(closed_bar <= 0 || current_bar <= 0)
      return false;

   MqlDateTime closed_dt;
   MqlDateTime current_dt;
   TimeToStruct(closed_bar, closed_dt);
   TimeToStruct(current_bar, current_dt);
   return (closed_dt.mon != current_dt.mon || closed_dt.year != current_dt.year);
  }

bool Strategy_HasOpenPosition()
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

double Strategy_MedianDailySpreadPoints()
  {
   const int n = strategy_spread_median_days;
   if(n <= 0 || n > 64)
      return 0.0;

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
      return 0.0;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(values[j] < values[i])
           {
            const double tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
           }

   if((count % 2) == 1)
      return values[count / 2];
   return 0.5 * (values[(count / 2) - 1] + values[count / 2]);
  }

bool Strategy_SpreadAllowsEntry()
  {
   const double median_spread = Strategy_MedianDailySpreadPoints();
   if(median_spread <= 0.0 || strategy_spread_mult <= 0.0)
      return true;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;
   return ((double)current_spread <= median_spread * strategy_spread_mult);
  }

// Trailing return over `strategy_lookback_d1_bars` closed D1 bars for `symbol`.
// Closed bars only (shift 1 = most recent closed bar). Returns false when the
// symbol lacks enough history to be rank-eligible.
bool Strategy_SymbolReturn(const string symbol, double &out_return)
  {
   out_return = 0.0;
   if(strategy_lookback_d1_bars <= 0 || strategy_min_history_d1_bars <= 0)
      return false;

   SymbolSelect(symbol, true);
   if(iBars(symbol, PERIOD_D1) < strategy_min_history_d1_bars)
      return false;

   const double recent_close = iClose(symbol, PERIOD_D1, 1);
   const double lookback_close = iClose(symbol, PERIOD_D1, 1 + strategy_lookback_d1_bars);
   if(recent_close <= 0.0 || lookback_close <= 0.0)
      return false;

   out_return = (recent_close / lookback_close) - 1.0;
   return true;
  }

// Direction for _Symbol given its cross-sectional rank: +1 long (top-N),
// -1 short (bottom-N), 0 flat.
int Strategy_RankDirection()
  {
   const int current_index = Strategy_CurrentSymbolIndex();
   if(current_index < 0)
      return 0;

   double scores[4];
   int indexes[4];
   int count = 0;
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
     {
      double score = 0.0;
      if(!Strategy_SymbolReturn(g_universe_symbols[i], score))
         continue;
      scores[count] = score;
      indexes[count] = i;
      ++count;
     }

   const int slots = MathMin(strategy_rank_slots_each_side, count / 2);
   if(slots <= 0)
      return 0;

   // Sort ascending by return.
   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(scores[j] < scores[i])
           {
            const double tmp_score = scores[i];
            scores[i] = scores[j];
            scores[j] = tmp_score;
            const int tmp_index = indexes[i];
            indexes[i] = indexes[j];
            indexes[j] = tmp_index;
           }

   // Bottom-N (weakest) → short.
   for(int i = 0; i < slots; ++i)
      if(indexes[i] == current_index)
         return -1;

   // Top-N (strongest) → long.
   for(int i = count - slots; i < count; ++i)
      if(indexes[i] == current_index)
         return 1;

   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks.
// -----------------------------------------------------------------------------

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
   req.reason = "QM5_1101_COMM_MOM12";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_lookback_d1_bars <= 0 ||
      strategy_min_history_d1_bars <= 0 ||
      strategy_rank_slots_each_side <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0)
      return false;

   // Monthly-rebalance only.
   if(!Strategy_IsMonthEndClosedBar())
      return false;

   const int rebalance_key = Strategy_RebalanceKey(iTime(_Symbol, PERIOD_D1, 1));
   if(rebalance_key <= 0 || rebalance_key == g_last_entry_rebalance_key)
      return false;
   g_last_entry_rebalance_key = rebalance_key;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const int direction = Strategy_RankDirection();
   if(direction == 0)
      return false;

   const QM_OrderType side = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = QM_EntryMarketPrice(side);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;
   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;

   req.type = side;
   req.sl = sl;
   req.reason = (direction > 0) ? "QM5_1101_COMM_MOM12_LONG_TOP2" : "QM5_1101_COMM_MOM12_SHORT_BOTTOM2";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies hard ATR stop only; no trailing, BE, or partial management.
  }

bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_D1)
      return false;
   if(!Strategy_HasOpenPosition())
      return false;
   if(!Strategy_IsMonthEndClosedBar())
      return false;

   const int rebalance_key = Strategy_RebalanceKey(iTime(_Symbol, PERIOD_D1, 1));
   if(rebalance_key <= 0 || rebalance_key == g_last_exit_rebalance_key)
      return false;
   g_last_exit_rebalance_key = rebalance_key;

   // Close-and-rebalance: exit if _Symbol left its bucket at month-end.
   const int direction = Strategy_RankDirection();
   const ENUM_POSITION_TYPE held = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   if(held == POSITION_TYPE_BUY && direction != 1)
      return true;
   if(held == POSITION_TYPE_SELL && direction != -1)
      return true;
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

   // Basket universe: register the allowed set and force the tester to load each
   // foreign symbol's D1 history. SymbolSelect alone only adds to Market Watch —
   // without the CopyClose warmup the tester returns 0 bars for foreign symbols
   // and the cross-sectional rank never resolves (0 trades).
   string universe_dyn[];
   ArrayResize(universe_dyn, STRATEGY_UNIVERSE_SIZE);
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      universe_dyn[i] = g_universe_symbols[i];
   QM_SymbolGuardInit(universe_dyn);
   QM_BasketWarmupHistory(universe_dyn, PERIOD_D1,
                          strategy_min_history_d1_bars + strategy_lookback_d1_bars + 10);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1101_qp-comm-mom12\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
