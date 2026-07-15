#property strict
#property version   "5.0"
#property description "QM5_1556 Alpha Architect Zakamulin 12-month momentum timing"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1556;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;   // live-deploy: RISK_PERCENT=0.3 (Q13 min-lot) to 0.5 (full live) per card §7; backtests use RISK_FIXED
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
input int    strategy_momentum_lookback_d1 = 252;   // 12-month proxy: 21 D1 bars/month
input double strategy_momentum_trigger     = 100.0; // MT5 momentum ratio; >100 means positive 12m return
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_sl_mult          = 3.0;
input int    strategy_max_spread_points    = 0;     // retained for parameter-table compatibility; spread guard uses 20-day median×2.5 instead
input bool   strategy_first_d1_bar_only    = true;

int g_last_entry_rebalance_key = 0;
int g_last_exit_rebalance_key  = 0;

bool Strategy_RebalanceDue(const bool entry_path, int &month_key)
  {
   month_key = QM_CalendarPeriodKey(PERIOD_MN1);
   if(month_key <= 0)
      return false;

   if(entry_path)
      return (month_key != g_last_entry_rebalance_key);
   return (month_key != g_last_exit_rebalance_key);
  }

double Strategy_MomentumRatio()
  {
   if(strategy_momentum_lookback_d1 < 20)
      return 0.0;
   return QM_Momentum(_Symbol, PERIOD_D1, strategy_momentum_lookback_d1, 1, PRICE_CLOSE);
  }

bool Strategy_HasOpenPosition()
  {
   return (QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0);
  }

// Compute median D1 spread (in points) over the last `lookback` completed D1 bars.
// Returns 0 if insufficient data — callers treat 0 as "no cap available".
int MedianSpreadD1(const string sym, const int lookback)
  {
   if(lookback <= 0)
      return 0;

   MqlRates rates[];
   const int copied = CopyRates(sym, PERIOD_D1, 1, lookback, rates);
   if(copied <= 0)
      return 0;

   int spreads[];
   ArrayResize(spreads, copied);
   int n = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].spread < 0)
         continue;
      spreads[n] = rates[i].spread;
      n++;
     }
   if(n <= 0)
      return 0;

   // Insertion sort for small n (≤20 typical).
   for(int i = 1; i < n; ++i)
     {
      const int key = spreads[i];
      int j = i - 1;
      while(j >= 0 && spreads[j] > key)
        {
         spreads[j + 1] = spreads[j];
         j--;
        }
      spreads[j + 1] = key;
     }

   return spreads[n / 2];
  }

// Spread guard: block only a genuinely wide spread (card: D1 spread > 2.5 × 20-day median).
// Fail-OPEN on zero/negative spread — .DWX models ask==bid (0 spread).
bool Strategy_SpreadAllowsEntry()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;
   if(!(ask > bid))
      return true;   // zero or inverted spread — fail-open (.DWX invariant)

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const int current_spread = (int)MathRound((ask - bid) / point);
   if(current_spread <= 0)
      return true;   // fail-open

   const int median_spread = MedianSpreadD1(_Symbol, 20);
   if(median_spread <= 0)
      return true;   // insufficient history — fail-open (.DWX invariant)

   const int cap = (int)MathMax(1.0, MathRound(2.5 * median_spread));
   return (current_spread <= cap);
  }

// No Trade Filter (timeframe, parameter bounds, minimum warmup bars).
// Returns TRUE to block trading. Checked once per new D1 bar before any signal logic.
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;
   if(strategy_momentum_lookback_d1 < 20)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;

   // Card requires sufficient D1 history for the 12-month momentum lookback.
   // Need at least momentum_lookback + atr_period + 2 completed D1 bars.
   const int bars_needed = strategy_momentum_lookback_d1 + strategy_atr_period_d1 + 2;
   const int bars_avail  = iBars(_Symbol, PERIOD_D1);
   if(bars_avail < bars_needed)
      return true;

   return false;
  }

// Trade Entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1556_D1_12M_MOM_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   int month_key = 0;
   if(!Strategy_RebalanceDue(true, month_key))
      return false;
   g_last_entry_rebalance_key = month_key;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const double momentum = Strategy_MomentumRatio();
   if(momentum <= strategy_momentum_trigger)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period_d1, strategy_atr_sl_mult);
   req.tp = 0.0;
   return (req.sl > 0.0);
  }

// Trade Management.
void Strategy_ManageOpenPosition()
  {
   // Card specifies a fixed initial ATR stop and monthly signal-flip exit.
  }

// Trade Close.
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;

   int month_key = 0;
   if(!Strategy_RebalanceDue(false, month_key))
      return false;
   g_last_exit_rebalance_key = month_key;

   const double momentum = Strategy_MomentumRatio();
   if(momentum <= 0.0)
      return false;   // indicator not ready / warmup — fail-open, do not force-exit
   // Card: exit (go to cash) when the 12-month momentum ratio ≤ 100 (strategy_momentum_trigger).
   return (momentum <= strategy_momentum_trigger);
  }

// News Filter Hook (callable for P8 News Impact phase).
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

   if(!QM_FrameworkDeclareExecutionContract(PERIOD_D1,
                                             QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
                                             "DXZ_LEGACY_BOOK_POLICY_REQUAL_REQUIRED"))
      return INIT_FAILED;

   string warmup_symbols[1] = {_Symbol};
   QM_SymbolGuardInit(warmup_symbols);
   QM_BasketWarmupHistory(warmup_symbols, PERIOD_D1,
                          MathMax(300, strategy_momentum_lookback_d1 + strategy_atr_period_d1 + 10));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1556\",\"ea\":\"aa-zak-mom12\"}");
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

   const bool nb = QM_IsNewBar(_Symbol, PERIOD_D1);
   if(!nb)
      return;

   QM_EquityStreamOnNewBar();

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
