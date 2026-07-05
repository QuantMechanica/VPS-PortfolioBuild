#property strict
#property version   "5.0"
#property description "QM5_12591 EIA WTI Hurricane Season Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12591 - EIA WTI Hurricane Season Breakout
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - trades only inside the Atlantic hurricane-season petroleum-risk window
//   - long-only upside breakout on XTIUSD.DWX with trend/range/close confirmation
//   - exits on failed breakout, trend failure, season end, or fixed max hold
// Runtime uses MT5 OHLC only; no weather feed, EIA feed, or external API.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12591;
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
input int    strategy_entry_channel       = 12;
input int    strategy_exit_channel        = 6;
input int    strategy_trend_period        = 50;
input int    strategy_atr_period          = 20;
input double strategy_min_range_atr       = 0.80;
input double strategy_min_close_location  = 0.65;
input double strategy_atr_sl_mult         = 3.0;
input int    strategy_max_hold_days       = 12;
input int    strategy_start_month         = 6;
input int    strategy_end_month           = 11;
input int    strategy_max_spread_points   = 1000;

// Cached per-closed-bar state. Refreshed exactly once per new D1 bar by
// Strategy_AdvanceCachedState() (called after the QM_IsNewBar() gate) so the
// per-tick path (ManageOpenPosition / ExitSignal / EntrySignal) never calls
// CopyRates or re-derives the channel/trend/range state on every tick.
bool   g_state_valid       = false;
double g_close_last        = 0.0;
double g_entry_high        = 0.0;
double g_exit_low          = 0.0;
double g_atr_last          = 0.0;
double g_sma_last          = 0.0;
double g_range_last        = 0.0;
double g_close_location    = 0.0;
bool   g_in_season         = false;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

// Derives the current calendar month from the QM calendar-period primitive
// (yyyymm) instead of a hand-rolled iTime()+TimeToStruct() month key.
int Strategy_CurrentMonth()
  {
   const int cal_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0); // yyyymm
   if(cal_key <= 0)
      return 0;
   return cal_key % 100;
  }

bool Strategy_MonthInWindow(const int month)
  {
   if(month < 1 || month > 12)
      return false;
   if(strategy_start_month <= strategy_end_month)
      return (month >= strategy_start_month && month <= strategy_end_month);
   return (month >= strategy_start_month || month <= strategy_end_month);
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

// Called once per new closed D1 bar (caller guarantees QM_IsNewBar()==true).
// Single CopyRates call for the channel state; QM_ATR / QM_SMA are handle-
// pooled readers. Populates the g_* cache consumed by the per-tick hooks.
void Strategy_AdvanceCachedState()
  {
   g_state_valid = false;
   g_in_season = Strategy_MonthInWindow(Strategy_CurrentMonth());

   const int max_channel = MathMax(strategy_entry_channel, strategy_exit_channel);
   const int bars_needed = max_channel + 2;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_D1, 1, bars_needed, rates) < bars_needed)
      return;

   const double close_last = rates[0].close;
   const double high_last = rates[0].high;
   const double low_last = rates[0].low;

   double entry_high = rates[1].high;
   for(int i = 2; i <= strategy_entry_channel; ++i)
     {
      if(rates[i].high > entry_high)
         entry_high = rates[i].high;
     }

   double exit_low = rates[1].low;
   for(int j = 2; j <= strategy_exit_channel; ++j)
     {
      if(rates[j].low < exit_low)
         exit_low = rates[j].low;
     }

   const double atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   const double range_last = high_last - low_last;
   if(close_last <= 0.0 || entry_high <= 0.0 || exit_low <= 0.0 || atr_last <= 0.0 || sma_last <= 0.0)
      return;
   if(range_last <= 0.0)
      return;

   const double close_location = (close_last - low_last) / range_last;
   if(!MathIsValidNumber(close_location))
      return;

   g_close_last = close_last;
   g_entry_high = entry_high;
   g_exit_low = exit_low;
   g_atr_last = atr_last;
   g_sma_last = sma_last;
   g_range_last = range_last;
   g_close_location = close_location;
   g_state_valid = true;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
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
   if(strategy_start_month < 1 || strategy_start_month > 12 || strategy_end_month < 1 || strategy_end_month > 12)
      return true;
   return false;
  }

// Called every tick when an open position exists for this EA's magic. This
// strategy carries a fixed hard SL (no trailing, no BE shift, no partials in
// v1 per the card), so there is nothing to actively adjust here.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary close, evaluated every tick against cached per-bar state plus
// a live max-hold-duration check. Only one position per magic/symbol can
// exist (enforced at entry), so a single boolean is sufficient.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   datetime opened = 0;
   bool have_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      opened = (datetime)PositionGetInteger(POSITION_TIME);
      have_position = true;
      break;
     }
   if(!have_position)
      return false;

   if(opened > 0)
     {
      const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;
      if(TimeCurrent() - opened >= hold_seconds)
         return true;
     }

   if(!g_in_season)
      return true;

   if(!g_state_valid)
      return false;

   if(g_close_last < g_exit_low)
      return true;
   if(g_close_last < g_sma_last)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12591_EIA_WTI_HURR_BRK";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_in_season)
      return false;
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

   if(g_close_last <= g_entry_high)
      return false;
   if(g_close_last <= g_sma_last)
      return false;
   if(g_range_last < strategy_min_range_atr * g_atr_last)
      return false;
   if(g_close_location < strategy_min_close_location)
      return false;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = "EIA_WTI_HURRICANE_BREAKOUT_LONG";
   return true;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12591\",\"ea\":\"eia-wti-hurr-brk\"}");
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

   // News blackout gates NEW entries only (below). It must not sit above the
   // management path so stop enforcement / time exits keep running through
   // news windows. Fail-closed init in OnInit is unchanged.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
   Strategy_AdvanceCachedState();

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
