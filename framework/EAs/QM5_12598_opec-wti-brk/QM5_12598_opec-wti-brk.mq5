#property strict
#property version   "5.0"
#property description "QM5_12598 OPEC WTI Conference Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12598 - OPEC WTI Conference Breakout
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - trades only around fixed June/December OPEC ordinary-meeting windows
//   - follows confirmed D1 Donchian-channel breakouts in either direction
//   - exits on window end, failed breakout, SMA failure, or fixed max hold
// Runtime uses MT5 OHLC/broker calendar only; no OPEC, EIA, news, or API feed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12598;
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
input int    strategy_entry_channel       = 10;
input int    strategy_exit_channel        = 5;
input int    strategy_trend_period        = 50;
input int    strategy_atr_period          = 20;
input double strategy_min_range_atr       = 0.70;
input double strategy_min_close_location  = 0.65;
input double strategy_atr_sl_mult         = 3.0;
input int    strategy_max_hold_days       = 8;
input int    strategy_event_month_a       = 6;
input int    strategy_event_month_b       = 12;
input int    strategy_window_start_day    = 1;
input int    strategy_window_end_day      = 14;
input int    strategy_max_spread_points   = 1000;

// -----------------------------------------------------------------------------
// Cached per-closed-bar state. Refreshed exactly once per new D1 bar in
// Strategy_AdvanceStateOnNewBar(); every other function only reads it. This
// keeps Strategy_ManageOpenPosition() safe to run on every tick (required by
// the 2026-07-02 OnTick-ordering audit fix) without re-running CopyRates.
// -----------------------------------------------------------------------------
bool     g_state_valid       = false;
double   g_close_last        = 0.0;
double   g_entry_high        = 0.0;
double   g_entry_low         = 0.0;
double   g_exit_high         = 0.0;
double   g_exit_low          = 0.0;
double   g_atr_last          = 0.0;
double   g_sma_last          = 0.0;
double   g_range_last        = 0.0;
double   g_close_location    = 0.0;
bool     g_in_entry_window   = false;

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool Strategy_DateInEventWindow(const datetime t)
  {
   if(t <= 0)
      return false;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   const bool event_month = (dt.mon == strategy_event_month_a || dt.mon == strategy_event_month_b);
   return (event_month && dt.day >= strategy_window_start_day && dt.day <= strategy_window_end_day);
  }

bool Strategy_TodayInEventWindow()
  {
   return Strategy_DateInEventWindow(TimeCurrent());
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

// Refreshes the Donchian-channel / ATR / SMA / close-location cache from the
// last CLOSED D1 bar. Called at most once per new bar (see OnTick).
void Strategy_AdvanceStateOnNewBar()
  {
   g_state_valid = false;

   const int max_channel = MathMax(strategy_entry_channel, strategy_exit_channel);
   const int bars_needed = max_channel + 1;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_D1, 1, bars_needed, rates) < bars_needed) // perf-allowed: bespoke D1 Donchian-channel state, once per new closed bar (Strategy_AdvanceStateOnNewBar is only called when is_new_bar==true)
      return;

   const datetime signal_time = rates[0].time;
   g_close_last = rates[0].close;
   const double high_last = rates[0].high;
   const double low_last  = rates[0].low;
   g_range_last = high_last - low_last;

   g_entry_high = rates[1].high;
   g_entry_low  = rates[1].low;
   for(int i = 2; i <= strategy_entry_channel; ++i)
     {
      if(rates[i].high > g_entry_high) g_entry_high = rates[i].high;
      if(rates[i].low  < g_entry_low)  g_entry_low  = rates[i].low;
     }

   g_exit_high = rates[1].high;
   g_exit_low  = rates[1].low;
   for(int j = 2; j <= strategy_exit_channel; ++j)
     {
      if(rates[j].high > g_exit_high) g_exit_high = rates[j].high;
      if(rates[j].low  < g_exit_low)  g_exit_low  = rates[j].low;
     }

   g_atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   g_sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);

   if(g_close_last <= 0.0 || g_entry_high <= 0.0 || g_entry_low <= 0.0 ||
      g_exit_high <= 0.0 || g_exit_low <= 0.0 || g_atr_last <= 0.0 ||
      g_sma_last <= 0.0 || g_range_last <= 0.0)
      return;

   g_close_location = (g_close_last - low_last) / g_range_last;
   if(!MathIsValidNumber(g_close_location))
      return;

   g_in_entry_window = Strategy_DateInEventWindow(signal_time);
   g_state_valid = true;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != "XTIUSD.DWX" || _Period != PERIOD_D1)
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_entry_channel < 2 || strategy_exit_channel < 2 || strategy_exit_channel > strategy_entry_channel)
      return true;
   if(strategy_trend_period <= 1 || strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_min_range_atr <= 0.0 || strategy_min_close_location <= 0.5 || strategy_min_close_location > 1.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   if(strategy_event_month_a < 1 || strategy_event_month_a > 12 ||
      strategy_event_month_b < 1 || strategy_event_month_b > 12)
      return true;
   if(strategy_window_start_day < 1 || strategy_window_start_day > strategy_window_end_day ||
      strategy_window_end_day > 31)
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

   if(!g_state_valid)
      return false;
   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   if(!g_in_entry_window)
      return false;
   if(g_range_last < strategy_min_range_atr * g_atr_last)
      return false;

   int direction = 0;
   if(g_close_last > g_entry_high && g_close_last > g_sma_last &&
      g_close_location >= strategy_min_close_location)
      direction = 1;
   else if(g_close_last < g_entry_low && g_close_last < g_sma_last &&
           g_close_location <= (1.0 - strategy_min_close_location))
      direction = -1;
   else
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = (direction > 0) ? "OPEC_WTI_BREAKOUT_LONG" : "OPEC_WTI_BREAKOUT_SHORT";
   return true;
  }

// Runs every tick (2026-07-02 ordering fix): closes are driven off the cached
// per-bar state above, never by re-reading history, so this stays O(open
// positions) per tick regardless of news-gate state.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const bool in_window_now = Strategy_TodayInEventWindow();
   const datetime now = TimeCurrent();
   const long hold_seconds = (long)MathMax(1, strategy_max_hold_days) * 86400;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(!in_window_now)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
        }

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && (now - opened) >= hold_seconds)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
         continue;
        }

      if(!g_state_valid)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && (g_close_last < g_exit_low || g_close_last < g_sma_last))
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
        }
      if(pos_type == POSITION_TYPE_SELL && (g_close_last > g_exit_high || g_close_last > g_sma_last))
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
        }
     }
  }

bool Strategy_ExitSignal()
  {
   // All exits (window-end, time-stop, channel/SMA failure) are handled per-
   // position inside Strategy_ManageOpenPosition() above, since different
   // open positions can need different exit reasons on the same tick.
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to the 2-axis QM_NewsAllowsTrade2/QM_NewsAllowsTrade gate
  }

// -----------------------------------------------------------------------------
// Framework wiring.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12598\",\"ea\":\"opec-wti-brk\"}");
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

   // DWX invariant #3: QM_IsNewBar() is single-consume per tick. Latch once,
   // reuse below both to refresh cached state and to gate entry evaluation.
   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
      Strategy_AdvanceStateOnNewBar();

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // 2026-07-02 audit fix: management/exit must keep running through news
   // windows. The news gate below blocks NEW entries only. Canonical order:
   // kill-switch -> Friday-close -> NoTradeFilter -> ManageOpenPosition ->
   // ExitSignal -> news gate -> IsNewBar -> EntrySignal.
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!is_new_bar)
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
