#property strict
#property version   "5.0"
#property description "QM5_1357 AllocateSmartly Pragmatic Asset Allocation (monthly momentum rotation, D1-native)"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1357;
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
// 12-month momentum lookback in D1 bars (~252 trading days / year).
input int    strategy_momentum_lookback_days = 252;
// 12-month SMA absolute-momentum filter length in D1 bars.
input int    strategy_sma_filter_days        = 252;
// Number of top-ranked risk proxies to hold each rebalance (card: top two).
input int    strategy_top_n                  = 2;
// ATR-based protective stop length (D1) and multiple.
input int    strategy_atr_period             = 20;
input double strategy_atr_sl_mult            = 3.0;

// -----------------------------------------------------------------------------
// Asset-class proxy basket. Card universe (ACWI/QQQ/EEM risk, IEF/GLD/BIL
// defensive) is non-routable on .DWX. Realized via routable index/metal proxies:
//   - QQQ          -> NDX.DWX   (Nasdaq 100, equities)
//   - ACWI / broad -> WS30.DWX  (Dow 30, US large-cap equities)
//   - EEM / global -> GDAXI.DWX (DAX 40, ex-US developed-equity proxy)
//   - GLD          -> XAUUSD.DWX (gold, defensive asset class)
// The yield-curve regime branch (10y vs 3m Treasury) and the IEF/BIL bond/T-bill
// sleeves have NO .DWX rate/bond/yield feed and are dropped — see basket_manifest
// notes + SPEC. The strategy's mechanical core (dual-momentum rotation across
// asset-class proxies, monthly rebalance, 12-month SMA absolute-momentum filter)
// is preserved.
// -----------------------------------------------------------------------------
#define STRATEGY_BASKET_COUNT 4

string g_strategy_basket[STRATEGY_BASKET_COUNT] =
  {
   "NDX.DWX",
   "WS30.DWX",
   "GDAXI.DWX",
   "XAUUSD.DWX"
  };

// Per-leg magic slots (one position per magic per leg).
int g_strategy_slots[STRATEGY_BASKET_COUNT] = {0, 1, 2, 3};

bool     g_basket_scope_ready = false;
int      g_last_rebalance_month = -1;
int      g_last_rebalance_year  = -1;

int Strategy_BasketIndexForSymbol(const string symbol)
  {
   for(int i = 0; i < STRATEGY_BASKET_COUNT; ++i)
      if(g_strategy_basket[i] == symbol)
         return i;
   return -1;
  }

int Strategy_SlotForSymbol(const string symbol)
  {
   const int idx = Strategy_BasketIndexForSymbol(symbol);
   if(idx >= 0)
      return g_strategy_slots[idx];
   return qm_magic_slot_offset;
  }

bool Strategy_EnsureBasketScope()
  {
   if(g_basket_scope_ready)
      return true;

   for(int i = 0; i < STRATEGY_BASKET_COUNT; ++i)
      SymbolSelect(g_strategy_basket[i], true);

   QM_SymbolGuardInit(g_strategy_basket);
   const int warm = MathMax(strategy_momentum_lookback_days, strategy_sma_filter_days) + 20;
   QM_BasketWarmupHistory(g_strategy_basket, PERIOD_D1, warm);
   g_basket_scope_ready = true;
   return true;
  }

// 12-month price change (relative-momentum score) on the closed D1 bar.
double Strategy_MomentumForSymbol(const string symbol)
  {
   const double c0 = iClose(symbol, PERIOD_D1, 1);                                 // perf-allowed: fixed closed D1 close for card 12m momentum, only after D1 new-bar gate.
   const double c1 = iClose(symbol, PERIOD_D1, 1 + strategy_momentum_lookback_days);// perf-allowed: fixed closed D1 lookback close for card 12m momentum, only after D1 new-bar gate.
   if(c0 <= 0.0 || c1 <= 0.0)
      return 0.0;
   return (c0 - c1) / c1;
  }

// Absolute-momentum filter: close above its 12-month SMA (card qualification).
bool Strategy_AboveLongSMA(const string symbol)
  {
   const double c0 = iClose(symbol, PERIOD_D1, 1);                           // perf-allowed: fixed closed D1 close for SMA filter, only after D1 new-bar gate.
   const double sma = QM_SMA(symbol, PERIOD_D1, strategy_sma_filter_days, 1);
   if(c0 <= 0.0 || sma <= 0.0)
      return false;
   return (c0 > sma);
  }

// Rank the basket by 12-month momentum and return whether `symbol` is a held
// (top-N, above-SMA-qualified) sleeve this rebalance. Cash if it fails either gate.
bool Strategy_IsSelected(const string symbol)
  {
   const int target_index = Strategy_BasketIndexForSymbol(symbol);
   if(target_index < 0)
      return false;

   double mom[STRATEGY_BASKET_COUNT];
   bool   qualified[STRATEGY_BASKET_COUNT];
   bool   valid[STRATEGY_BASKET_COUNT];
   ArrayInitialize(mom, 0.0);
   ArrayInitialize(qualified, false);
   ArrayInitialize(valid, false);

   for(int i = 0; i < STRATEGY_BASKET_COUNT; ++i)
     {
      const double c0 = iClose(g_strategy_basket[i], PERIOD_D1, 1);                                  // perf-allowed: validity probe, only after D1 new-bar gate.
      const double c1 = iClose(g_strategy_basket[i], PERIOD_D1, 1 + strategy_momentum_lookback_days);// perf-allowed: validity probe, only after D1 new-bar gate.
      if(c0 <= 0.0 || c1 <= 0.0 || !MathIsValidNumber(c0) || !MathIsValidNumber(c1))
         continue;
      valid[i] = true;
      mom[i] = (c0 - c1) / c1;
      // Absolute momentum: only hold if above its 12-month SMA (else -> cash).
      qualified[i] = Strategy_AboveLongSMA(g_strategy_basket[i]);
     }

   if(!valid[target_index] || !qualified[target_index])
      return false;

   // Relative momentum: count how many qualified proxies outrank the target.
   // Target is selected if it is within the top-N qualified ranks.
   const double target_mom = mom[target_index];
   int better = 0;
   for(int i = 0; i < STRATEGY_BASKET_COUNT; ++i)
     {
      if(i == target_index || !valid[i] || !qualified[i])
         continue;
      // Strictly-greater momentum outranks; deterministic tie-break by basket index.
      if(mom[i] > target_mom || (mom[i] == target_mom && i < target_index))
         better++;
     }

   return (better < strategy_top_n);
  }

bool Strategy_HasOpenPosition(ENUM_POSITION_TYPE &position_type)
  {
   position_type = POSITION_TYPE_BUY;
   const int magic = QM_MagicChecked(qm_ea_id, Strategy_SlotForSymbol(_Symbol), _Symbol);
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

// Monthly rebalance gate: fire once on the first new D1 bar of a new broker-time
// calendar month (card: monthly portfolio maintenance, signals from prior month).
bool Strategy_IsRebalanceBar()
  {
   MqlDateTime dt;
   TimeToStruct(iTime(_Symbol, PERIOD_D1, 0), dt); // perf-allowed: current D1 bar-open time for month-roll gate, only after D1 new-bar gate.
   if(dt.mon != g_last_rebalance_month || dt.year != g_last_rebalance_year)
     {
      g_last_rebalance_month = dt.mon;
      g_last_rebalance_year = dt.year;
      return true;
     }
   return false;
  }

// No Trade Filter — block non-basket symbols + wrong slot; news/Friday = framework.
bool Strategy_NoTradeFilter()
  {
   Strategy_EnsureBasketScope();

   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;
   if(Strategy_BasketIndexForSymbol(_Symbol) < 0)
      return true;
   if(qm_magic_slot_offset != Strategy_SlotForSymbol(_Symbol))
      return true;
   return false;
  }

// Trade Entry — long-only momentum rotation; open the sleeve if selected this month.
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

   if(!Strategy_IsSelected(_Symbol))
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   req.type = QM_BUY;
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_sl_mult);
   req.tp = 0.0;
   req.reason = "AS_PRAGMATIC_AA_ROTATION_LONG";

   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   return true;
  }

// Trade Management — card uses no trailing/partial/break-even; held to rebalance.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close — exit a held sleeve when it loses selection (rank or SMA filter).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   if(!Strategy_HasOpenPosition(position_type))
      return false;

   // Monthly stop / rebalance: drop the sleeve if it no longer qualifies.
   return (!Strategy_IsSelected(_Symbol));
  }

// News Filter Hook — defer to the framework two-axis news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

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

   Strategy_EnsureBasketScope();

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1357\",\"ea\":\"QM5_1357_as-pragmatic-aa\"}");
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

   // Monthly rebalance cadence: only evaluate selections on the month-roll bar.
   if(!Strategy_IsRebalanceBar())
      return;

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
