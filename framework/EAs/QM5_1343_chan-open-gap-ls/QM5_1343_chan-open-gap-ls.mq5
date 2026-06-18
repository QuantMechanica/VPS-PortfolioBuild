#property strict
#property version   "5.0"
#property description "QM5_1343 Chan Opening-Gap Long/Short Cross-Sectional Reversion"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 — QM5_1343 chan-open-gap-ls (BASKET, host=_per_instance)
// -----------------------------------------------------------------------------
// Source: Ernest Chan, "Beware of Low Frequency Data" (2015-04-13), Opening-Gap
// Reversion section. Original: rank SPX-component opening gaps (prior close ->
// current open); LONG the strongest NEGATIVE gap, SHORT the strongest POSITIVE
// gap, liquidate at the same session close.
//
// DWX PORT (G0-approved index-basket mapping). The available index CFDs are the
// cross-sectional universe: SP500.DWX (backtest-only), NDX.DWX, WS30.DWX,
// GDAXI.DWX (DAX 40), UK100.DWX (FTSE 100 port — FTSE.DWX is not in the matrix).
//
// .DWX BACKTEST INVARIANT (build note 6): index/FX CFDs are GAPLESS —
// open[0] == close[1] at the session boundary, so a literal "open - prior_close"
// gap is ~0 and can never rank. We therefore reference the PRIOR CLOSE the build
// note prescribes: the OVERNIGHT GAP is the return of the latest completed D1
// session, gap_i = (close[1] - close[2]) / close[2], evaluated on the closed D1
// bar at the broker-time (NY-Close GMT+2/+3) session boundary. The D1 bar close
// IS the session close; the framework D1 new-bar gate fires once per session.
// Ranking these cross-sectionally and trading contrarian (LONG most-negative,
// SHORT most-positive) is the faithful, testable realization of the gap-reversion
// edge on gapless DWX index data.
//
// Per-instance basket: each terminal instance runs this EA on one basket symbol;
// every instance recomputes the FULL cross-section from foreign-symbol D1 reads
// (warmed by QM_BasketWarmupHistory) and acts only on its own _Symbol. One
// position per magic per symbol; session-close liquidation = exit when the symbol
// is no longer the selected long/short leg on the new session bar.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1343;
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
input int    strategy_gap_lookback_days   = 1;     // overnight gap = 1-session D1 return (close[1] vs close[1+lookback])
input int    strategy_min_basket_size     = 3;     // require >=N active index symbols to rank cross-section
input double strategy_min_abs_gap         = 0.0;   // |gap| floor; 0.0 = always rank the extremes
input int    strategy_atr_period          = 14;    // catastrophic stop ATR period (card: ATR(14, M15))
input double strategy_atr_stop_mult       = 1.25;  // card: 1.25 * ATR catastrophic stop
input int    strategy_spread_median_days  = 60;    // rolling-median spread window (card: skip if > 2x median)
input double strategy_spread_mult         = 2.0;   // card: skip if opening spread > 2x rolling median
input bool   strategy_skip_monday         = false; // optional filter: exclude Monday opens

#define STRATEGY_BASKET_COUNT 5

string g_strategy_basket[STRATEGY_BASKET_COUNT] =
  {
   "SP500.DWX",   // S&P 500 (backtest-only)
   "NDX.DWX",     // Nasdaq 100
   "WS30.DWX",    // Dow 30
   "GDAXI.DWX",   // DAX 40
   "UK100.DWX"    // FTSE 100 (FTSE.DWX port)
  };
int g_strategy_slots[STRATEGY_BASKET_COUNT] = {0, 1, 2, 3, 4};

int Strategy_BasketIndexForSymbol(const string symbol)
  {
   for(int i = 0; i < STRATEGY_BASKET_COUNT; ++i)
      if(g_strategy_basket[i] == symbol)
         return i;
   return -1;
  }

// Overnight gap = return of the latest completed D1 session: prior-close-referenced
// per build note 6 (gapless CFDs). close[1] vs close[1+lookback], both closed bars.
double Strategy_GapForSymbol(const string symbol, const int lookback)
  {
   if(lookback < 1)
      return 0.0;

   const double c_recent = iClose(symbol, PERIOD_D1, 1);            // perf-allowed: fixed closed D1 close, only after D1 new-bar gate.
   const double c_prior  = iClose(symbol, PERIOD_D1, 1 + lookback); // perf-allowed: fixed closed D1 close, only after D1 new-bar gate.
   if(c_recent <= 0.0 || c_prior <= 0.0)
      return 0.0;

   return (c_recent - c_prior) / c_prior;
  }

// Determine the selected direction for `symbol`:
//   +1  -> LONG  (symbol holds the most-NEGATIVE gap in the cross-section)
//   -1  -> SHORT (symbol holds the most-POSITIVE gap in the cross-section)
//    0  -> not selected this session
// Ties / insufficient breadth -> 0.
int Strategy_DirectionForSymbol(const string symbol)
  {
   const int target_index = Strategy_BasketIndexForSymbol(symbol);
   if(target_index < 0)
      return 0;

   double gaps[STRATEGY_BASKET_COUNT];
   bool   active[STRATEGY_BASKET_COUNT];
   ArrayInitialize(gaps, 0.0);
   ArrayInitialize(active, false);

   const int lookback = MathMax(1, strategy_gap_lookback_days);
   int active_count = 0;
   for(int i = 0; i < STRATEGY_BASKET_COUNT; ++i)
     {
      const double g = Strategy_GapForSymbol(g_strategy_basket[i], lookback);
      if(g == 0.0)
         continue;
      gaps[i] = g;
      active[i] = true;
      ++active_count;
     }

   if(active_count < MathMax(2, strategy_min_basket_size))
      return 0;
   if(!active[target_index])
      return 0;

   // Find the most-negative (LONG leg) and most-positive (SHORT leg) gaps.
   int    long_idx = -1, short_idx = -1;
   double min_gap = 0.0, max_gap = 0.0;
   for(int i = 0; i < STRATEGY_BASKET_COUNT; ++i)
     {
      if(!active[i])
         continue;
      if(long_idx < 0 || gaps[i] < min_gap)
        {
         min_gap = gaps[i];
         long_idx = i;
        }
      if(short_idx < 0 || gaps[i] > max_gap)
        {
         max_gap = gaps[i];
         short_idx = i;
        }
     }

   if(long_idx < 0 || short_idx < 0 || long_idx == short_idx)
      return 0; // degenerate cross-section (all-equal) -> no trade

   // LONG leg only if the strongest negative gap is genuinely negative; SHORT
   // leg only if the strongest positive gap is genuinely positive, each beyond
   // the optional |gap| floor.
   if(target_index == long_idx && min_gap < -strategy_min_abs_gap && min_gap < 0.0)
      return +1;
   if(target_index == short_idx && max_gap > strategy_min_abs_gap && max_gap > 0.0)
      return -1;

   return 0;
  }

bool Strategy_HasOpenPosition(ENUM_POSITION_TYPE &position_type)
  {
   position_type = POSITION_TYPE_BUY;
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

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

// Card filter: skip if the opening spread is > 2x rolling-median spread.
// .DWX INVARIANT (build note 1): .DWX quotes ask==bid (0 modeled spread); a
// fail-closed spread guard would block every trade. We only block a genuinely
// wide spread and fail OPEN on zero/degenerate data.
bool Strategy_SpreadBlocked()
  {
   if(strategy_spread_median_days <= 1 || strategy_spread_mult <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;          // degenerate price -> fail OPEN
   if(!(ask > bid))
      return false;          // zero/inverted spread (DWX tester) -> fail OPEN

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int requested = MathMax(2, strategy_spread_median_days);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, requested, rates); // perf-allowed: bounded 60D spread-history read, only after D1 new-bar gate.
   if(copied <= 0)
      return false;          // no history -> fail OPEN

   double spreads[];
   ArrayResize(spreads, copied);
   int used = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].spread <= 0)
         continue;
      spreads[used] = (double)rates[i].spread;
      ++used;
     }
   if(used <= 0)
      return false;          // DWX zero-spread history -> fail OPEN

   ArrayResize(spreads, used);
   ArraySort(spreads);
   const int mid = used / 2;
   double median_spread = spreads[mid];
   if((used % 2) == 0)
      median_spread = 0.5 * (spreads[mid - 1] + spreads[mid]);
   if(median_spread <= 0.0)
      return false;

   const double current_spread_points = (ask - bid) / point;
   return (current_spread_points > strategy_spread_mult * median_spread);
  }

// No Trade Filter (time, spread, news) — block non-basket symbols and the
// optional Monday-open exclusion. News + Friday close are framework gates.
bool Strategy_NoTradeFilter()
  {
   if(Strategy_BasketIndexForSymbol(_Symbol) < 0)
      return true;
   if(strategy_skip_monday)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 1) // Monday in broker time
         return true;
     }
   return false;
  }

// Trade Entry — cross-sectional opening-gap reversion: LONG the most-negative
// gap leg, SHORT the most-positive gap leg, one position per magic per symbol.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ENUM_POSITION_TYPE position_type;
   if(Strategy_HasOpenPosition(position_type))
      return false;
   if(Strategy_SpreadBlocked())
      return false;

   const int dir = Strategy_DirectionForSymbol(_Symbol);
   if(dir == 0)
      return false;

   QM_OrderType side = (dir > 0) ? QM_BUY : QM_SELL;
   double entry = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                            : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_stop_mult);
   if(sl <= 0.0)
      return false;
   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;

   const int slot = g_strategy_slots[Strategy_BasketIndexForSymbol(_Symbol)];

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (dir > 0) ? "CHAN_OPEN_GAP_LONG" : "CHAN_OPEN_GAP_SHORT";
   req.symbol_slot = slot;
   req.expiration_seconds = 0;
   return true;
  }

// Trade Management — card specifies no trailing / partial / break-even.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close — session-close liquidation: at the next D1 session boundary,
// exit if this symbol is no longer the selected leg in its held direction
// (the gap-reversion holding period is a single overnight session).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   if(!Strategy_HasOpenPosition(position_type))
      return false;

   const int dir = Strategy_DirectionForSymbol(_Symbol);

   if(position_type == POSITION_TYPE_BUY)
      return (dir <= 0);   // no longer the long leg -> liquidate at session close
   if(position_type == POSITION_TYPE_SELL)
      return (dir >= 0);   // no longer the short leg -> liquidate at session close

   return false;
  }

// News Filter Hook — defer to the framework two-axis news filter.
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

   QM_SymbolGuardInit(g_strategy_basket);
   QM_BasketWarmupHistory(g_strategy_basket, PERIOD_D1,
                          MathMax(strategy_atr_period + 10, strategy_spread_median_days + 10));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1343\",\"ea\":\"QM5_1343_chan-open-gap-ls\"}");
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

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

   QM_EquityStreamOnNewBar();

   if(Strategy_ExitSignal())
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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

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
