#property strict
#property version   "5.0"
#property description "QM5_13033 CFTC COT Friday XNG positioning fade"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13033 - XNG COT Friday Positioning Fade
// -----------------------------------------------------------------------------
// D1 structural natural-gas sleeve:
//   - host/traded symbol: XNGUSD.DWX
//   - first new-week bar entry after large Friday COT-release-window displacement
//   - enter opposite the Friday displacement only after SMA stretch confirmation
//   - ATR hard stop plus SMA mean, closed-bar reversion/adverse, and time exits
// Runtime uses MT5 OHLC/broker calendar only; no CFTC feed, CSV, API, or ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13033;
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
input double strategy_min_signal_return_pct     = 1.60;
input double strategy_min_atr_return_mult       = 0.55;
input double strategy_max_signal_return_pct     = 16.0;
input double strategy_close_location_min        = 0.62;
input int    strategy_signal_dow                = 5;
input int    strategy_atr_period                = 20;
input int    strategy_mean_period               = 80;
input double strategy_min_stretch_atr           = 0.65;
input double strategy_atr_sl_mult               = 3.00;
input int    strategy_max_hold_days             = 5;
input double strategy_reversion_close_atr_mult  = 1.10;
input double strategy_adverse_close_atr_mult    = 1.10;
input int    strategy_max_spread_points         = 2500;

int g_last_entry_week_key = 0;

bool Strategy_IsHostD1()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_WeekKey(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + (dt.day_of_year / 7);
  }

int Strategy_DayOfWeek(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.day_of_week;
  }

bool Strategy_IsFirstNewWeekBar(datetime &current_bar, datetime &signal_bar)
  {
   current_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 calendar gate behind framework new-bar.
   signal_bar = iTime(_Symbol, PERIOD_D1, 1);  // perf-allowed: D1 calendar gate behind framework new-bar.
   if(current_bar <= 0 || signal_bar <= 0)
      return false;
   return Strategy_WeekKey(current_bar) != Strategy_WeekKey(signal_bar);
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

bool Strategy_SpreadAllowed()
  {
   if(strategy_max_spread_points <= 0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return true;
   if(ask < bid)
      return false;

   const double spread_points = (ask - bid) / point;
   return (spread_points <= strategy_max_spread_points);
  }

bool Strategy_LoadFadeSignal(QM_OrderType &entry_type, double &signal_return_pct)
  {
   entry_type = QM_BUY;
   signal_return_pct = 0.0;

   datetime current_bar = 0;
   datetime signal_bar_time = 0;
   if(!Strategy_IsFirstNewWeekBar(current_bar, signal_bar_time))
      return false;

   const int signal_dow = Strategy_DayOfWeek(signal_bar_time);
   if(signal_dow != strategy_signal_dow)
      return false;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, 2, bars); // perf-allowed: bounded D1 signal sample behind new-bar gate.
   if(copied < 2)
      return false;

   const double signal_close = bars[0].close;
   const double prev_close = bars[1].close;
   if(signal_close <= 0.0 || prev_close <= 0.0)
      return false;

   signal_return_pct = 100.0 * MathLog(signal_close / prev_close);
   if(!MathIsValidNumber(signal_return_pct))
      return false;

   const double abs_ret = MathAbs(signal_return_pct);
   if(abs_ret < strategy_min_signal_return_pct)
      return false;
   if(abs_ret > strategy_max_signal_return_pct)
      return false;

   const double atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_mean_period, 1, PRICE_CLOSE);
   if(atr_last <= 0.0 || sma_last <= 0.0)
      return false;

   const double atr_pct = 100.0 * atr_last / signal_close;
   if(abs_ret < strategy_min_atr_return_mult * atr_pct)
      return false;

   const double range = bars[0].high - bars[0].low;
   if(range <= 0.0)
      return false;
   const double close_location = (signal_close - bars[0].low) / range;
   const double loc_min = MathMax(0.50, MathMin(0.95, strategy_close_location_min));
   const double stretch_atr = (signal_close - sma_last) / atr_last;

   if(signal_return_pct > 0.0)
     {
      if(close_location < loc_min)
         return false;
      if(stretch_atr < strategy_min_stretch_atr)
         return false;
      entry_type = QM_SELL;
      return true;
     }

   if(signal_return_pct < 0.0)
     {
      if(close_location > (1.0 - loc_min))
         return false;
      if(stretch_atr > -strategy_min_stretch_atr)
         return false;
      entry_type = QM_BUY;
      return true;
     }

   return false;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;

   double prior_close = 0.0;
   double close_buffer[];
   ArraySetAsSeries(close_buffer, true);
   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, 1, close_buffer); // perf-allowed: single closed D1 close behind new-bar gate.
   if(copied >= 1)
      prior_close = close_buffer[0];

   const double atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_mean_period, 1, PRICE_CLOSE);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      bool should_close = false;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;

      if(prior_close > 0.0)
        {
         const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(sma_last > 0.0)
           {
            if(pos_type == POSITION_TYPE_BUY && prior_close >= sma_last)
               should_close = true;
            if(pos_type == POSITION_TYPE_SELL && prior_close <= sma_last)
               should_close = true;
           }

         if(atr_last > 0.0)
           {
            const double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
            const double favorable = MathMax(0.0, strategy_reversion_close_atr_mult) * atr_last;
            const double adverse = MathMax(0.0, strategy_adverse_close_atr_mult) * atr_last;

            if(pos_type == POSITION_TYPE_BUY)
              {
               if(favorable > 0.0 && prior_close >= entry_price + favorable)
                  should_close = true;
               if(adverse > 0.0 && prior_close <= entry_price - adverse)
                  should_close = true;
              }
            if(pos_type == POSITION_TYPE_SELL)
              {
               if(favorable > 0.0 && prior_close <= entry_price - favorable)
                  should_close = true;
               if(adverse > 0.0 && prior_close >= entry_price + adverse)
                  should_close = true;
              }
           }
        }

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_min_signal_return_pct <= 0.0)
      return true;
   if(strategy_min_atr_return_mult <= 0.0)
      return true;
   if(strategy_max_signal_return_pct <= strategy_min_signal_return_pct)
      return true;
   if(strategy_close_location_min < 0.50 || strategy_close_location_min > 0.95)
      return true;
   if(strategy_signal_dow < 1 || strategy_signal_dow > 5)
      return true;
   if(strategy_atr_period <= 0 || strategy_mean_period <= 1)
      return true;
   if(strategy_min_stretch_atr <= 0.0)
      return true;
   if(strategy_atr_sl_mult <= 0.0 || strategy_max_hold_days <= 0)
      return true;
   if(strategy_reversion_close_atr_mult < 0.0)
      return true;
   if(strategy_adverse_close_atr_mult < 0.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_13033_XNG_COT_FRI_FADE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowed())
      return false;

   datetime current_bar = 0;
   datetime signal_bar = 0;
   if(!Strategy_IsFirstNewWeekBar(current_bar, signal_bar))
      return false;

   const int week_key = Strategy_WeekKey(current_bar);
   if(week_key <= 0 || week_key == g_last_entry_week_key)
      return false;

   QM_OrderType entry_type = QM_BUY;
   double signal_return_pct = 0.0;
   if(!Strategy_LoadFadeSignal(entry_type, signal_return_pct))
      return false;

   const double entry_price = QM_EntryMarketPrice(entry_type);
   if(entry_price <= 0.0)
      return false;

   req.type = entry_type;
   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = (entry_type == QM_BUY) ? "XNG_COT_FRI_FADE_LONG" : "XNG_COT_FRI_FADE_SHORT";
   g_last_entry_week_key = week_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseOpenPositionsIfNeeded();
  }

bool Strategy_ExitSignal()
  {
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13033\",\"ea\":\"xng-cot-fade\"}");
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

   if(!QM_IsNewBar())
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
