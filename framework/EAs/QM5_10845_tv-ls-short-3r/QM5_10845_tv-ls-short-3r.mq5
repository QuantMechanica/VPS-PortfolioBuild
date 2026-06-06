#property strict
#property version   "5.0"
#property description "QM5_10845 TradingView five-minute liquidity sweep short"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10845;
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
input int    strategy_atr_period             = 14;
input double strategy_stop_buffer_atr_mult   = 0.10;
input double strategy_rr_target              = 3.0;
input double strategy_min_stop_spread_mult   = 3.0;
input double strategy_max_stop_atr_mult      = 2.5;
input int    strategy_fx_session_start_min   = 840;
input int    strategy_fx_session_end_min     = 1080;
input int    strategy_index_session_start_min = 570;
input int    strategy_index_session_end_min   = 1080;
input int    strategy_day_high_scan_bars     = 288;

int MinuteOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

bool MinuteInWindow(const int minute, const int start_minute, const int end_minute)
  {
   if(start_minute == end_minute)
      return true;
   if(start_minute < end_minute)
      return (minute >= start_minute && minute < end_minute);
   return (minute >= start_minute || minute < end_minute);
  }

bool SameBrokerDay(const datetime a, const datetime b)
  {
   MqlDateTime da;
   MqlDateTime db;
   TimeToStruct(a, da);
   TimeToStruct(b, db);
   return (da.year == db.year && da.day_of_year == db.day_of_year);
  }

bool IsIndexSymbol()
  {
   return (StringFind(_Symbol, "NDX") >= 0 ||
           StringFind(_Symbol, "WS30") >= 0 ||
           StringFind(_Symbol, "GDAXI") >= 0 ||
           StringFind(_Symbol, "GER40") >= 0 ||
           StringFind(_Symbol, "UK100") >= 0 ||
           StringFind(_Symbol, "SP500") >= 0);
  }

double CurrentSpreadPrice()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
      return ask - bid;
   return (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * point;
  }

double DayHighThroughShift(const int start_shift, const int max_scan_bars)
  {
   const datetime anchor = iTime(_Symbol, _Period, start_shift); // perf-allowed: bespoke broker-day sweep structure, called only inside framework new-bar entry hook.
   if(anchor <= 0)
      return 0.0;

   double high = -DBL_MAX;
   const int limit = MathMax(1, max_scan_bars);
   for(int shift = start_shift; shift < start_shift + limit; ++shift)
     {
      const datetime t = iTime(_Symbol, _Period, shift); // perf-allowed: bounded broker-day scan for current-day high.
      if(t <= 0 || !SameBrokerDay(t, anchor))
         break;
      const double h = iHigh(_Symbol, _Period, shift); // perf-allowed: bounded broker-day scan for current-day high.
      if(h > high)
         high = h;
     }

   return (high == -DBL_MAX) ? 0.0 : high;
  }

bool Strategy_NoTradeFilter()
  {
   const int minute = MinuteOfDay(TimeCurrent());
   if(IsIndexSymbol())
      return !MinuteInWindow(minute, strategy_index_session_start_min, strategy_index_session_end_min);
   return !MinuteInWindow(minute, strategy_fx_session_start_min, strategy_fx_session_end_min);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_atr_period < 1 || strategy_rr_target <= 0.0 ||
      strategy_stop_buffer_atr_mult < 0.0 || strategy_day_high_scan_bars < 2)
      return false;

   const double prev_open = iOpen(_Symbol, _Period, 2); // perf-allowed: two-candle OHLC source pattern.
   const double prev_high = iHigh(_Symbol, _Period, 2); // perf-allowed: two-candle OHLC source pattern.
   const double prev_close = iClose(_Symbol, _Period, 2); // perf-allowed: two-candle OHLC source pattern.
   const double sweep_high = iHigh(_Symbol, _Period, 1); // perf-allowed: two-candle OHLC source pattern.
   const double sweep_close = iClose(_Symbol, _Period, 1); // perf-allowed: two-candle OHLC source pattern.
   if(prev_open <= 0.0 || prev_high <= 0.0 || prev_close <= 0.0 ||
      sweep_high <= 0.0 || sweep_close <= 0.0)
      return false;

   if(prev_close <= prev_open)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double day_high_before_sweep = DayHighThroughShift(2, strategy_day_high_scan_bars);
   if(day_high_before_sweep <= 0.0 || prev_high < day_high_before_sweep - point * 0.5)
      return false;

   if(sweep_high <= prev_high || sweep_close >= prev_open)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double spread = CurrentSpreadPrice();
   if(atr <= 0.0 || spread <= 0.0)
      return false;

   const double buffer = MathMax(strategy_stop_buffer_atr_mult * atr, 2.0 * spread);
   const double sl = sweep_high + buffer;
   const double stop_dist = sl - bid;
   if(stop_dist <= 0.0)
      return false;

   if(stop_dist < strategy_min_stop_spread_mult * spread)
      return false;
   if(stop_dist > strategy_max_stop_atr_mult * atr)
      return false;

   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = NormalizeDouble(sl, _Digits);
   req.tp = NormalizeDouble(bid - strategy_rr_target * stop_dist, _Digits);
   req.reason = "TV_LS_SHORT_3R";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL and fixed 3R TP only.
  }

bool Strategy_ExitSignal()
  {
   // No discretionary strategy close in the card; exits are SL, TP, and framework Friday close.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10845_tv_ls_short_3r\"}");
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
