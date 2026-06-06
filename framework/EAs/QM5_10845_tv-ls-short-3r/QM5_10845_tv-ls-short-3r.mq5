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
input int    strategy_atr_period              = 14;
input double strategy_stop_buffer_atr_mult    = 0.10;
input double strategy_rr_target               = 3.0;
input double strategy_min_stop_spread_mult    = 3.0;
input double strategy_max_stop_atr_mult       = 2.5;
input int    strategy_fx_session_start_min    = 840;
input int    strategy_fx_session_end_min      = 1080;
input int    strategy_index_session_start_min = 570;
input int    strategy_index_session_end_min   = 1080;
input int    strategy_day_high_scan_bars      = 288;

// Return TRUE to BLOCK trading this tick (time, spread, news override).
bool Strategy_NoTradeFilter()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int minute = dt.hour * 60 + dt.min;

   const bool is_index = (StringFind(_Symbol, "NDX") >= 0 ||
                          StringFind(_Symbol, "WS30") >= 0 ||
                          StringFind(_Symbol, "GDAXI") >= 0 ||
                          StringFind(_Symbol, "GER40") >= 0 ||
                          StringFind(_Symbol, "UK100") >= 0 ||
                          StringFind(_Symbol, "SP500") >= 0);
   const int start_minute = is_index ? strategy_index_session_start_min : strategy_fx_session_start_min;
   const int end_minute = is_index ? strategy_index_session_end_min : strategy_fx_session_end_min;

   if(start_minute == end_minute)
      return false;
   if(start_minute < end_minute)
      return !(minute >= start_minute && minute < end_minute);
   return !(minute >= start_minute || minute < end_minute);
  }

// Short after a failed sweep above the broker-day high. Caller guarantees a new bar.
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
      strategy_stop_buffer_atr_mult < 0.0 || strategy_day_high_scan_bars < 2 ||
      strategy_min_stop_spread_mult <= 0.0 || strategy_max_stop_atr_mult <= 0.0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int bars_needed = MathMax(strategy_day_high_scan_bars + 3, 5);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, bars_needed, rates);
   if(copied < 3)
      return false;

   const MqlRates sweep = rates[1];
   const MqlRates prev = rates[2];
   if(prev.open <= 0.0 || prev.high <= 0.0 || prev.close <= 0.0 ||
      sweep.high <= 0.0 || sweep.close <= 0.0)
      return false;

   if(prev.close <= prev.open)
      return false;

   MqlDateTime day_anchor;
   TimeToStruct(prev.time, day_anchor);
   double day_high_before_sweep = -DBL_MAX;
   const int scan_limit = MathMin(copied, strategy_day_high_scan_bars + 2);
   for(int i = 2; i < scan_limit; ++i)
     {
      MqlDateTime bar_dt;
      TimeToStruct(rates[i].time, bar_dt);
      if(bar_dt.year != day_anchor.year || bar_dt.day_of_year != day_anchor.day_of_year)
         break;
      if(rates[i].high > day_high_before_sweep)
         day_high_before_sweep = rates[i].high;
     }
   if(day_high_before_sweep == -DBL_MAX)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   if(MathAbs(prev.high - day_high_before_sweep) > point * 0.5)
      return false;
   if(sweep.high <= prev.high || sweep.close >= prev.open)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   double spread = ask - bid;
   if(spread <= 0.0)
      spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * point;
   if(spread <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double buffer = MathMax(strategy_stop_buffer_atr_mult * atr, 2.0 * spread);
   const double sl = sweep.high + buffer;
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

// Card specifies fixed SL and fixed 3R TP only.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary strategy close; exits are SL, TP, and framework Friday close.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook for P8 News Impact phase.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line.
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
