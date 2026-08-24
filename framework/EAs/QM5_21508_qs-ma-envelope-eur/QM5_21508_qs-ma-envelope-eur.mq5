#property strict
#property version   "5.0"
#property description "QM5_21508 EURUSD D1 moving-average envelope mean reversion"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 21508;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal        = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_DXZ;
input int                      qm_news_stale_max_hours = 336;
input string                   qm_news_min_impact      = "high";
input QM_NewsMode              qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = true;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_ma_period            = 20;
input double strategy_envelope_pct         = 0.015;
input int    strategy_atr_period           = 14;
input double strategy_atr_sl_mult          = 2.0;
input int    strategy_max_hold_bars        = 20;
input double strategy_max_spread_points    = 20.0;

// Return TRUE to block new entries. The framework still runs position
// management, strategy exits, and Friday close before the central news gate.
bool Strategy_NoTradeFilter()
  {
   if(_Symbol != "EURUSD.DWX" || (ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;

   if(strategy_ma_period < 2 || strategy_envelope_pct <= 0.0 || strategy_envelope_pct >= 1.0 ||
      strategy_atr_period < 1 || strategy_atr_sl_mult <= 0.0 ||
      strategy_max_hold_bars < 1 || strategy_max_spread_points < 0.0)
      return true;

   const int completed_bars = Bars(_Symbol, PERIOD_D1); // perf-allowed: O(1) card-required D1 history-depth guard; the framework has no bar-count reader.
   if(completed_bars < strategy_ma_period + 5)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   // Spread is an entry-only card filter. .DWX tests legitimately model
   // ask == bid, so only a genuinely positive, over-cap spread blocks entry.
   if(ask > bid && (ask - bid) / point > strategy_max_spread_points)
      return false;

   // The card permits one open position per magic, with no pyramiding or
   // opposite-side overlap.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const double close_1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: fixed closed-bar read inside the framework's once-per-D1-bar entry hook; no QM close reader exists.
   const double close_2 = iClose(_Symbol, PERIOD_D1, 2); // perf-allowed: fixed closed-bar read required to prove a fresh envelope breach.
   const double sma_1 = QM_SMA(_Symbol, PERIOD_D1, strategy_ma_period, 1);
   const double sma_2 = QM_SMA(_Symbol, PERIOD_D1, strategy_ma_period, 2);
   const double atr_1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(close_1 <= 0.0 || close_2 <= 0.0 || sma_1 <= 0.0 || sma_2 <= 0.0 || atr_1 <= 0.0)
      return false;

   const double upper_1 = sma_1 * (1.0 + strategy_envelope_pct);
   const double lower_1 = sma_1 * (1.0 - strategy_envelope_pct);
   const double upper_2 = sma_2 * (1.0 + strategy_envelope_pct);
   const double lower_2 = sma_2 * (1.0 - strategy_envelope_pct);
   // Exact touches do not enter. Requiring the prior close to be inside/on
   // its band makes this a fresh breach and prevents re-entry during one
   // extended excursion after a stop or other exit.
   if(close_1 < lower_1 && close_2 >= lower_2)
     {
      req.type = QM_BUY;
      req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr_1, strategy_atr_sl_mult);
      req.reason = "ma_envelope_fresh_lower_breach";
      return (req.sl > 0.0 && req.sl < ask);
     }

   if(close_1 > upper_1 && close_2 <= upper_2)
     {
      req.type = QM_SELL;
      req.sl = QM_StopATRFromValue(_Symbol, QM_SELL, bid, atr_1, strategy_atr_sl_mult);
      req.reason = "ma_envelope_fresh_upper_breach";
      return (req.sl > bid);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // The card specifies a server-side ATR hard SL and forbids trailing,
   // break-even, partial close, pyramiding, and scale-in management.
  }

bool Strategy_ExitSignal()
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

      const double close_1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: O(1) completed-D1-bar exit value; no QM close reader exists.
      const double sma_1 = QM_SMA(_Symbol, PERIOD_D1, strategy_ma_period, 1);
      if(close_1 <= 0.0 || sma_1 <= 0.0)
         return false;

      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY && close_1 >= sma_1)
         return true;
      if(position_type == POSITION_TYPE_SELL && close_1 <= sma_1)
         return true;

      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      const int completed_since_entry = iBarShift(_Symbol, PERIOD_D1, opened_at, false); // perf-allowed: O(1) completed-bar count for the card's D1 max-hold rule.
      if(completed_since_entry >= strategy_max_hold_bars)
         return true;
     }

   return false;
  }

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

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

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
