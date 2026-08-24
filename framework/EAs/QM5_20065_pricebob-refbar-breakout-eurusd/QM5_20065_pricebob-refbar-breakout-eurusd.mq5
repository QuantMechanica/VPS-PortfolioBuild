#property strict
#property version   "5.0"
#property description "QM5_20065 PriceBob Reference-Bar Breakout (EURUSD M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_20065
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20065;
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
input int    strategy_ref_bar_hour             = 8;
input int    strategy_ref_bar_minute           = 0;
input int    strategy_d1_atr_period            = 14;
input double strategy_min_range_d1_atr_mult    = 0.3;
input double strategy_max_range_d1_atr_mult    = 2.5;
input double strategy_max_spread_range_ratio   = 0.20;
input int    strategy_session_end_hour         = 21;

// -----------------------------------------------------------------------------
// Strategy State
// -----------------------------------------------------------------------------
int      g_handle_d1_atr       = INVALID_HANDLE;
int      g_current_day_key     = -1;
bool     g_ref_bar_captured    = false;
bool     g_ref_bar_valid       = false;
double   g_ref_high            = 0.0;
double   g_ref_low             = 0.0;
double   g_ref_range           = 0.0;
bool     g_traded_today        = false;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------
bool Strategy_GetOurPosition(ENUM_POSITION_TYPE &ptype, ulong &ticket)
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
   }
   return false;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return true;
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   ENUM_POSITION_TYPE ptype;
   ulong ticket = 0;
   if(Strategy_GetOurPosition(ptype, ticket))
      return false;

   if(g_traded_today || !g_ref_bar_captured || !g_ref_bar_valid)
      return false;

   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   if(dt.hour >= strategy_session_end_hour)
      return false;

   // Check spread filter
   const double cur_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   if(g_ref_range > 0.0 && cur_spread > strategy_max_spread_range_ratio * g_ref_range)
      return false;

   MqlRates rates[2];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M15, 0, 2, rates) < 2)
      return false;

   const double close1 = rates[1].close;

   // Breakout long
   if(close1 > g_ref_high)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl = g_ref_low;
      const double tp = ask + g_ref_range;

      req.cmd = QM_BUY;
      req.price = ask;
      req.sl = QM_NormalizePrice(_Symbol, sl);
      req.tp = QM_NormalizePrice(_Symbol, tp);
      req.reason = "PRICEBOB_REFBAR_BREAKOUT_LONG";
      g_traded_today = true;
      return (req.sl > 0.0 && req.sl < ask && req.tp > ask);
   }
   // Breakout short
   else if(close1 < g_ref_low)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl = g_ref_high;
      const double tp = bid - g_ref_range;

      req.cmd = QM_SELL;
      req.price = bid;
      req.sl = QM_NormalizePrice(_Symbol, sl);
      req.tp = QM_NormalizePrice(_Symbol, tp);
      req.reason = "PRICEBOB_REFBAR_BREAKOUT_SHORT";
      g_traded_today = true;
      return (req.sl > bid && req.tp > 0.0 && req.tp < bid);
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
}

bool Strategy_ExitSignal()
{
   ENUM_POSITION_TYPE ptype;
   ulong ticket = 0;
   if(!Strategy_GetOurPosition(ptype, ticket))
      return false;

   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   // Session end time stop: flatten at 21:00 broker time
   if(dt.hour >= strategy_session_end_hour)
      return true;

   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   g_handle_d1_atr = iATR(_Symbol, PERIOD_D1, strategy_d1_atr_period);
   if(g_handle_d1_atr == INVALID_HANDLE)
   {
      Print("Error initializing D1 ATR handle");
      return INIT_FAILED;
   }

   g_current_day_key  = -1;
   g_ref_bar_captured = false;
   g_ref_bar_valid    = false;
   g_ref_high         = 0.0;
   g_ref_low          = 0.0;
   g_ref_range        = 0.0;
   g_traded_today     = false;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_20065_pricebob-refbar-breakout-eurusd\"}");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_handle_d1_atr != INVALID_HANDLE) IndicatorRelease(g_handle_d1_atr);

   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
}

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   // Manage daily reset and reference bar capture on M15 bars
   MqlDateTime dt_now;
   TimeToStruct(broker_now, dt_now);
   const int day_key = dt_now.year * 1000 + dt_now.day_of_year;

   if(g_current_day_key != day_key)
   {
      g_current_day_key  = day_key;
      g_ref_bar_captured = false;
      g_ref_bar_valid    = false;
      g_ref_high         = 0.0;
      g_ref_low          = 0.0;
      g_ref_range        = 0.0;
      g_traded_today     = false;
   }

   // Reference bar is 08:00-08:15 M15 bar. When time is >= 08:15, capture closed reference bar
   if(!g_ref_bar_captured && (dt_now.hour > strategy_ref_bar_hour || (dt_now.hour == strategy_ref_bar_hour && dt_now.min >= 15)))
   {
      MqlDateTime target_dt = dt_now;
      target_dt.hour = strategy_ref_bar_hour;
      target_dt.min  = strategy_ref_bar_minute;
      target_dt.sec  = 0;
      datetime ref_target_time = StructToTime(target_dt);

      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      const int copied = CopyRates(_Symbol, PERIOD_M15, 0, 50, rates);
      for(int i = 0; i < copied; ++i)
      {
         if(rates[i].time == ref_target_time)
         {
            g_ref_high  = rates[i].high;
            g_ref_low   = rates[i].low;
            g_ref_range = g_ref_high - g_ref_low;
            g_ref_bar_captured = true;

            double d1_atr_buf[1];
            if(CopyBuffer(g_handle_d1_atr, 0, 1, 1, d1_atr_buf) > 0)
            {
               const double d1_atr = d1_atr_buf[0];
               if(d1_atr > 0.0 &&
                  g_ref_range >= strategy_min_range_d1_atr_mult * d1_atr &&
                  g_ref_range <= strategy_max_range_d1_atr_mult * d1_atr)
               {
                  g_ref_bar_valid = true;
               }
               else
               {
                  g_ref_bar_valid = false;
               }
            }
            break;
         }
      }
   }

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
