#property strict
#property version   "5.0"
#property description "QM5_10305 Narang Cross-Asset Relative Momentum (weekly cross-sectional)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_10305 — Narang Cross-Asset Relative Momentum
// -----------------------------------------------------------------------------
// Cross-sectional (basket) momentum. Once per completed W1 bar the EA computes a
// 13-week rate-of-change for every symbol in a configured DWX basket, ranks them,
// and trades the CHART symbol by its rank percentile:
//   * Long  if chart symbol is in the top entry-percentile  AND its 13w ROC > 0.
//   * Short if chart symbol is in the bottom entry-percentile AND its 13w ROC < 0.
// Exits when the chart symbol falls out of the rank-exit band, when its 13w ROC
// flips sign, or after a configured number of W1 bars (time exit). Initial stop
// and weekly trail use D1 ATR(14) per the card.
//
// This is a MULTI-SYMBOL basket EA: it reads foreign-symbol W1 closes. It MUST
// register its universe via QM_SymbolGuardInit + QM_BasketWarmupHistory in OnInit
// or foreign-symbol iClose returns 0 in the tester -> 0 trades.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10305;
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
input int    strategy_roc_lookback_w1     = 13;    // 13-week rate-of-change lookback (W1 bars)
input double strategy_entry_percentile    = 0.30;  // top/bottom fraction of basket that triggers entry
input double strategy_exit_percentile     = 0.50;  // rank-exit band fraction (long exits below top 50%)
input int    strategy_time_exit_w1_bars   = 8;     // close after this many W1 bars if no rank exit fired
input int    strategy_min_active_symbols  = 8;     // basket must have >= this many valid-ROC symbols
input int    strategy_atr_period          = 14;    // D1 ATR period for stop + trail
input double strategy_atr_sl_mult         = 3.0;   // initial stop = mult * D1 ATR
input double strategy_trail_atr_mult      = 3.0;   // weekly trail distance = mult * D1 ATR
input double strategy_trail_trigger_r     = 1.5;   // begin trailing after this many R of open profit
input double strategy_spread_atr_cap      = 0.50;  // skip entry if weekly spread / D1 ATR exceeds this

// -----------------------------------------------------------------------------
// Basket universe — registered in magic_numbers.csv with matching slots.
// -----------------------------------------------------------------------------
const int STRATEGY_UNIVERSE_SIZE = 10;
string g_universe_symbols[10] =
  {
   "EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX", "AUDUSD.DWX", "USDCAD.DWX",
   "XAUUSD.DWX", "GDAXI.DWX", "NDX.DWX", "WS30.DWX", "XTIUSD.DWX"
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

// 13-week rate-of-change on the closed W1 bar. Returns false if either close
// is missing (foreign-symbol history not loaded yet).
bool Strategy_SymbolROC(const string symbol, double &out_roc)
  {
   out_roc = 0.0;
   if(strategy_roc_lookback_w1 <= 0)
      return false;
   if(!QM_SymbolAssertOrLog(symbol))
      return false;

   const double recent_close   = iClose(symbol, PERIOD_W1, 1);                          // perf-allowed: weekly closed-bar ROC for explicit basket, called only after framework new-bar gate.
   const double lookback_close = iClose(symbol, PERIOD_W1, 1 + strategy_roc_lookback_w1); // perf-allowed: weekly closed-bar ROC for explicit basket, called only after framework new-bar gate.
   if(recent_close <= 0.0 || lookback_close <= 0.0)
      return false;

   out_roc = (recent_close / lookback_close) - 1.0;
   return true;
  }

// Build the ROC table for the whole basket; returns the count of valid symbols
// and (via out params) the chart symbol's ROC and its 0-based rank position
// (0 = highest ROC). Rank is only meaningful when the chart symbol is valid.
int Strategy_BuildRanking(double &out_self_roc, int &out_self_rank)
  {
   out_self_roc  = 0.0;
   out_self_rank = -1;

   double scores[10];
   int    indexes[10];
   int    count = 0;
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
     {
      double roc = 0.0;
      if(!Strategy_SymbolROC(g_universe_symbols[i], roc))
         continue;
      scores[count]  = roc;
      indexes[count] = i;
      ++count;
     }
   if(count <= 0)
      return 0;

   // Descending sort: highest ROC first.
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
         out_self_roc  = scores[i];
         break;
        }
   return count;
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

// Number of completed W1 bars elapsed since the position opened.
int Strategy_OpenPositionWeeksHeld()
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

   int weeks = 0;
   for(int shift = 1; shift <= strategy_time_exit_w1_bars + 2; ++shift)
     {
      const datetime bar_open = iTime(_Symbol, PERIOD_W1, shift); // perf-allowed: weekly hold-count, called only after framework new-bar gate.
      if(bar_open <= 0)
         break;
      if(bar_open >= open_time)
         weeks = shift;        // this closed W1 bar started at/after entry
      else
         break;                // bars are time-ordered; older bars precede entry
     }
   return weeks;
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

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_W1)
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
   req.reason = "QM5_10305_XMOM";
   req.symbol_slot = Strategy_CurrentSymbolSlot();
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   double self_roc = 0.0;
   int    self_rank = -1;
   const int count = Strategy_BuildRanking(self_roc, self_rank);
   if(count < strategy_min_active_symbols)
      return false;           // basket too thin
   if(self_rank < 0)
      return false;           // chart symbol has no valid ROC this bar

   // Rank thresholds (count of symbols in each entry band; >=1).
   int entry_band = (int)MathFloor(count * strategy_entry_percentile);
   if(entry_band < 1)
      entry_band = 1;

   int direction = 0;
   if(self_rank < entry_band && self_roc > 0.0)
      direction = 1;                                  // top band, positive own ROC -> long
   else if(self_rank >= count - entry_band && self_roc < 0.0)
      direction = -1;                                 // bottom band, negative own ROC -> short
   if(direction == 0)
      return false;

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

   req.reason = (direction > 0) ? "QM5_10305_XMOM_LONG_TOP" : "QM5_10305_XMOM_SHORT_BOTTOM";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   if(strategy_trail_atr_mult <= 0.0)
      return;

   const double atr = Strategy_D1ATR();
   if(atr <= 0.0)
      return;
   const double trail_distance = atr * strategy_trail_atr_mult;

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

      const bool   is_buy     = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double init_sl    = PositionGetDouble(POSITION_SL);
      const double market     = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                       : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || init_sl <= 0.0 || market <= 0.0)
         continue;

      // R distance = original stop distance from entry. Only trail after the
      // position is +trail_trigger_r in open profit.
      const double r_distance = MathAbs(open_price - init_sl);
      if(r_distance <= 0.0)
         continue;
      const double open_profit = is_buy ? (market - open_price) : (open_price - market);
      if(open_profit < r_distance * strategy_trail_trigger_r)
         continue;

      const double raw_sl    = is_buy ? (market - trail_distance) : (market + trail_distance);
      const double target_sl = QM_StopRulesNormalizePrice(_Symbol, raw_sl);
      if(target_sl <= 0.0)
         continue;

      // Improve-only (monotonic) — never loosen the stop.
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const bool improves = is_buy ? (target_sl > init_sl + point * 0.5)
                                   : (target_sl < init_sl - point * 0.5);
      if(!improves)
         continue;

      QM_TM_MoveSL(ticket, target_sl, StringFormat("QM5_10305_TRAIL atr_mult=%.2f after_%.2fR",
                                                   strategy_trail_atr_mult, strategy_trail_trigger_r));
     }
  }

bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_W1)
      return false;

   const int dir = Strategy_OpenPositionDirection();
   if(dir == 0)
      return false;

   // Time exit: close after N completed W1 bars regardless of rank.
   if(strategy_time_exit_w1_bars > 0 &&
      Strategy_OpenPositionWeeksHeld() >= strategy_time_exit_w1_bars)
      return true;

   double self_roc = 0.0;
   int    self_rank = -1;
   const int count = Strategy_BuildRanking(self_roc, self_rank);
   if(count <= 0 || self_rank < 0)
      return false;            // no ranking info this bar -> hold

   int exit_band = (int)MathFloor(count * strategy_exit_percentile);
   if(exit_band < 1)
      exit_band = 1;

   if(dir > 0)
     {
      // Long exits when it leaves the top exit-band OR its ROC turns negative.
      if(self_rank >= exit_band || self_roc < 0.0)
         return true;
     }
   else
     {
      // Short exits when it leaves the bottom exit-band OR its ROC turns positive.
      if(self_rank < count - exit_band || self_roc > 0.0)
         return true;
     }
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

   // Basket EA: register the universe and pre-load W1 history so foreign-symbol
   // iClose returns real data in the tester (FW7/FW9).
   QM_SymbolGuardInit(g_universe_symbols);
   QM_BasketWarmupHistory(g_universe_symbols, PERIOD_W1, strategy_roc_lookback_w1 + 5);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10305\",\"ea\":\"narang-xmom\"}");
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
