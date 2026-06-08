#property strict
#property version   "5.0"
#property description "QM5_11271 Quant-Trading Shooting Star"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11271;
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
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input double strategy_lower_wick_bound   = 0.20;
input double strategy_body_size_mult     = 0.50;
input int    strategy_body_mean_lookback = 20;
input int    strategy_uptrend_lookback   = 2;
input double strategy_exit_pct           = 0.05;
input int    strategy_holding_bars       = 7;
input int    strategy_atr_period         = 14;
input double strategy_gap_atr_mult       = 0.75;
input bool   strategy_use_atr_threshold  = false;
input double strategy_atr_exit_mult      = 2.0;

// -----------------------------------------------------------------------------
// Strategy hooks - implement these against the card mechanically.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   // Card-level filters are news blackout, confirmation-gap, and Friday close.
   // The framework handles news and Friday close; EntrySignal handles the gap.
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QT_SHOOTING_STAR_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_lower_wick_bound < 0.0 ||
      strategy_body_size_mult <= 0.0 ||
      strategy_body_mean_lookback <= 0 ||
      strategy_uptrend_lookback <= 0 ||
      strategy_exit_pct <= 0.0 ||
      strategy_holding_bars <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_gap_atr_mult < 0.0 ||
      strategy_atr_exit_mult <= 0.0)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int star_shift = 2;
   const int confirm_shift = 1;
   const int max_lookback = MathMax(strategy_body_mean_lookback, strategy_uptrend_lookback);
   const int bars_needed = star_shift + max_lookback + 2;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, bars_needed, rates); // perf-allowed: bounded candlestick OHLC, called only after framework QM_IsNewBar gate.
   if(copied < bars_needed)
      return false;

   const double star_open = rates[star_shift].open;
   const double star_high = rates[star_shift].high;
   const double star_low = rates[star_shift].low;
   const double star_close = rates[star_shift].close;
   const double confirm_open = rates[confirm_shift].open;
   const double confirm_high = rates[confirm_shift].high;
   const double confirm_close = rates[confirm_shift].close;

   if(star_open <= 0.0 || star_high <= 0.0 || star_low <= 0.0 || star_close <= 0.0 ||
      confirm_open <= 0.0 || confirm_high <= 0.0 || confirm_close <= 0.0)
      return false;

   const double body = MathAbs(star_close - star_open);
   if(body <= 0.0)
      return false;

   double body_sum = 0.0;
   for(int i = star_shift + 1; i <= star_shift + strategy_body_mean_lookback; ++i)
      body_sum += MathAbs(rates[i].close - rates[i].open);
   const double mean_body = body_sum / (double)strategy_body_mean_lookback;
   if(mean_body <= 0.0)
      return false;

   const double lower_wick = MathMin(star_open, star_close) - star_low;
   const double upper_wick = star_high - MathMax(star_open, star_close);

   if(star_open < star_close)
      return false;
   if(lower_wick >= strategy_lower_wick_bound * body)
      return false;
   if(body >= mean_body * strategy_body_size_mult)
      return false;
   if(upper_wick < 2.0 * body)
      return false;

   for(int i = star_shift + strategy_uptrend_lookback; i > star_shift; --i)
      if(rates[i].close > rates[i - 1].close)
         return false;

   if(confirm_high > star_high)
      return false;
   if(confirm_close > star_close)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, star_shift);
   if(atr <= 0.0)
      return false;
   if(MathAbs(confirm_open - star_close) > strategy_gap_atr_mult * atr)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0)
      return false;

   const double stop_distance = strategy_use_atr_threshold ? atr * strategy_atr_exit_mult
                                                           : bid * strategy_exit_pct;
   if(stop_distance <= 0.0)
      return false;

   req.price = NormalizeDouble(bid, _Digits);
   req.sl = NormalizeDouble(req.price + stop_distance, _Digits);
   req.tp = NormalizeDouble(req.price - stop_distance, _Digits);
   if(req.price <= 0.0 || req.sl <= req.price || req.tp >= req.price || req.tp <= 0.0)
      return false;

   req.reason = StringFormat("QT_SHOOT_STAR lb=%.2f body=%.2f up=%d",
                             strategy_lower_wick_bound,
                             strategy_body_size_mult,
                             strategy_uptrend_lookback);
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial close, break-even, or add-on logic.
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

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_since_entry = iBarShift(_Symbol, (ENUM_TIMEFRAMES)_Period, open_time, false); // perf-allowed: O(1) bar-age lookup for card holding-period exit.
      return (bars_since_entry >= strategy_holding_bars);
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do not edit below this line.
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
