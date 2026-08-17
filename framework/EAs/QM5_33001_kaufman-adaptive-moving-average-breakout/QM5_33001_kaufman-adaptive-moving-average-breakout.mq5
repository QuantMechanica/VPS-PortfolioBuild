#property strict
#property version   "5.0"
#property description "QM5_33001 Kaufman adaptive moving-average breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — Perry Kaufman KAMA breakout, H4.
// Card: QM5_33001_kaufman-adaptive-moving-average-breakout
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 33001;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_er_period          = 10;
input int    strategy_fast_period        = 2;
input int    strategy_slow_period        = 30;
input double strategy_er_threshold       = 0.40;
input int    strategy_atr_period         = 14;
input double strategy_entry_atr_mult     = 0.50;
input double strategy_initial_sl_atr_mult = 1.00;
input double strategy_max_spread_atr_mult = 1.80;

// KAMA is a recursive indicator, so its closed-bar value is rebuilt from a
// bounded warm-up window once per H4 bar. Per-tick hooks read only this cache.
#define STRATEGY_KAMA_WARMUP_BARS 300

double   g_closed_bar_close = 0.0;
datetime g_closed_bar_time  = 0;
double   g_kama             = 0.0;
double   g_efficiency_ratio = 0.0;
double   g_atr              = 0.0;
bool     g_state_valid      = false;

bool Strategy_RebuildKamaState()
  {
   g_closed_bar_close = 0.0;
   g_closed_bar_time  = 0;
   g_kama             = 0.0;
   g_efficiency_ratio = 0.0;
   g_atr              = 0.0;

   if(strategy_er_period < 2 ||
      strategy_fast_period < 1 ||
      strategy_slow_period <= strategy_fast_period ||
      strategy_er_threshold < 0.0 || strategy_er_threshold > 1.0 ||
      strategy_atr_period < 1 ||
      strategy_entry_atr_mult < 0.0 ||
      strategy_initial_sl_atr_mult <= 0.0 ||
      strategy_max_spread_atr_mult <= 0.0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   // perf-allowed: one bounded CopyRates call behind the framework new-bar
   // gate is required for the card's recursive KAMA calculation.
   const int copied = CopyRates(_Symbol,
                                PERIOD_H4,
                                1,
                                STRATEGY_KAMA_WARMUP_BARS,
                                rates);
   if(copied < strategy_er_period + 2)
      return false;

   const double fast_sc = 2.0 / (strategy_fast_period + 1.0);
   const double slow_sc = 2.0 / (strategy_slow_period + 1.0);
   double kama = rates[strategy_er_period - 1].close;
   double rolling_volatility = 0.0;
   for(int i = 1; i <= strategy_er_period; ++i)
      rolling_volatility += MathAbs(rates[i].close - rates[i - 1].close);

   double latest_er = 0.0;
   for(int i = strategy_er_period; i < copied; ++i)
     {
      if(i > strategy_er_period)
        {
         rolling_volatility += MathAbs(rates[i].close - rates[i - 1].close);
         rolling_volatility -= MathAbs(rates[i - strategy_er_period].close -
                                       rates[i - strategy_er_period - 1].close);
        }

      const double direction = MathAbs(rates[i].close -
                                       rates[i - strategy_er_period].close);
      const double er = (rolling_volatility > 0.0)
                        ? direction / rolling_volatility
                        : 0.0;
      double smoothing = er * (fast_sc - slow_sc) + slow_sc;
      smoothing *= smoothing;
      kama += smoothing * (rates[i].close - kama);
      latest_er = er;
     }

   const MqlRates latest = rates[copied - 1];
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(latest.time <= 0 || latest.close <= 0.0 || kama <= 0.0 || atr <= 0.0)
      return false;

   g_closed_bar_close = latest.close;
   g_closed_bar_time  = latest.time;
   g_kama             = kama;
   g_efficiency_ratio = latest_er;
   g_atr              = atr;
   return true;
  }

void AdvanceState_OnNewBar()
  {
   g_state_valid = Strategy_RebuildKamaState();
  }

// -----------------------------------------------------------------------------
// No Trade Filter
// -----------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_H4)
      return true;

   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   MqlDateTime utc_parts;
   TimeToStruct(utc_now, utc_parts);
   if((utc_parts.hour == 23 && utc_parts.min >= 55) ||
      (utc_parts.hour == 0 && utc_parts.min <= 5))
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return true;
   // .DWX Model-4 runs legitimately model ask == bid. Block only a genuinely
   // positive spread wider than the card's 1.8 x closed-bar ATR ceiling.
   if(g_atr > 0.0 && ask > bid &&
      (ask - bid) > strategy_max_spread_atr_mult * g_atr)
      return true;

   return false;
  }

// -----------------------------------------------------------------------------
// Trade Entry
// -----------------------------------------------------------------------------
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = 0;       // relative host identity resolved by the framework
   req.expiration_seconds = 0;

   if(!g_state_valid || g_efficiency_ratio < strategy_er_threshold)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;

   const double entry_band = strategy_entry_atr_mult * g_atr;
   if(g_closed_bar_close > g_kama + entry_band)
     {
      const double sl = QM_StopRulesNormalizePrice(
         _Symbol,
         g_kama - strategy_initial_sl_atr_mult * g_atr);
      if(sl <= 0.0 || sl >= ask)
         return false;
      req.type = QM_BUY;
      req.sl = sl;
      req.reason = "KAMA_BREAKOUT_LONG_ER";
      return true;
     }

   if(g_closed_bar_close < g_kama - entry_band)
     {
      const double sl = QM_StopRulesNormalizePrice(
         _Symbol,
         g_kama + strategy_initial_sl_atr_mult * g_atr);
      if(sl <= bid)
         return false;
      req.type = QM_SELL;
      req.sl = sl;
      req.reason = "KAMA_BREAKOUT_SHORT_ER";
      return true;
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Trade Management
// -----------------------------------------------------------------------------
void Strategy_ManageOpenPosition()
  {
   if(!g_state_valid)
      return;

   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(magic <= 0 || point <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid)
      return;

   const double trail = QM_StopRulesNormalizePrice(_Symbol, g_kama);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(type == POSITION_TYPE_BUY && trail > 0.0 && trail < bid &&
         (current_sl <= 0.0 || trail > current_sl + 0.5 * point))
         QM_TM_MoveSL(ticket, trail, "KAMA_LINE_TRAIL_LONG");
      else if(type == POSITION_TYPE_SELL && trail > ask &&
              (current_sl <= 0.0 || trail < current_sl - 0.5 * point))
         QM_TM_MoveSL(ticket, trail, "KAMA_LINE_TRAIL_SHORT");
     }
  }

// -----------------------------------------------------------------------------
// Trade Close
// -----------------------------------------------------------------------------
bool Strategy_ExitSignal()
  {
   if(!g_state_valid)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY && g_closed_bar_close <= g_kama)
         return true;
      if(type == POSITION_TYPE_SELL && g_closed_bar_close >= g_kama)
         return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_33001_kaufman-adaptive-moving-average-breakout\",\"timeframe\":\"H4\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   // Latch the single framework new-bar event once. This lets the recursive
   // KAMA cache advance before management and exits, including during news
   // blackouts, while the later news gate still blocks entries only.
   const bool is_new_bar = QM_IsNewBar(_Symbol, PERIOD_H4);
   if(is_new_bar)
     {
      AdvanceState_OnNewBar();
      QM_EquityStreamOnNewBar();
     }

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
            (int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol,
                                        broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol,
                                       broker_now,
                                       qm_news_mode_legacy);
   if(!news_allows || !is_new_bar || !g_state_valid)
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
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
