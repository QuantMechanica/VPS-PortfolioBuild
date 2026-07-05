#property strict
#property version   "5.0"
#property description "QM5_13000 Baker Hughes rig-count Friday XNG fade"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13000 - Baker Hughes Rig-Count Friday XNG Fade
// -----------------------------------------------------------------------------
// D1 structural natural-gas sleeve:
//   - host/traded symbol: XNGUSD.DWX
//   - first new-week bar entry after large final-workday displacement
//   - enter opposite the final-workday displacement
//   - short time stop plus ATR hard stop and closed-bar reversion/adverse exits
// Runtime uses MT5 OHLC/broker calendar only; no Baker Hughes/EIA feed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13000;
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
input double strategy_min_signal_return_pct     = 1.40;
input double strategy_min_atr_return_mult       = 0.55;
input double strategy_max_signal_return_pct     = 14.0;
input double strategy_close_location_min        = 0.68;
input int    strategy_signal_min_dow            = 4;
input int    strategy_atr_period                = 20;
input double strategy_atr_sl_mult               = 3.00;
input int    strategy_max_hold_days             = 3;
input double strategy_reversion_close_atr_mult  = 0.90;
input double strategy_adverse_close_atr_mult    = 0.90;
input int    strategy_max_spread_points         = 2500;

// Cached per-bar state, advanced ONCE per new closed D1 bar (see
// Strategy_AdvanceCachedState, called from OnTick behind the single
// QM_IsNewBar() consumption). Strategy_ManageOpenPosition / LoadFadeSignal
// read only these cached fields on the per-tick path - no CopyRates/CopyClose
// there.
bool   g_cached_week_rollover = false;
bool   g_cached_signal_valid  = false;
double g_cached_signal_close  = 0.0;
double g_cached_signal_high   = 0.0;
double g_cached_signal_low    = 0.0;
double g_cached_prev2_close   = 0.0;
double g_cached_atr           = 0.0;
int    g_cached_signal_dow    = -1;

bool Strategy_IsHostD1()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_D1);
  }

void Strategy_AdvanceCachedState()
  {
   // Calendar-cadence edge via the framework helper (never a hand-rolled
   // iTime week key) - latches internally, so this call must happen exactly
   // once per new closed D1 bar.
   g_cached_week_rollover = QM_IsNewCalendarPeriod(PERIOD_W1);
   g_cached_signal_valid  = false;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, 2, bars); // perf-allowed: bounded 2-bar D1 sample, cached once per new bar.
   if(copied < 2)
      return;

   g_cached_signal_close = bars[0].close;
   g_cached_signal_high  = bars[0].high;
   g_cached_signal_low   = bars[0].low;
   g_cached_prev2_close  = bars[1].close;
   g_cached_atr          = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);

   const datetime signal_bar_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: single closed-bar weekday read (not a calendar-period key), cached once per new bar.
   if(signal_bar_time > 0)
     {
      MqlDateTime dt;
      TimeToStruct(signal_bar_time, dt);
      g_cached_signal_dow = dt.day_of_week;
     }
   else
      g_cached_signal_dow = -1;

   g_cached_signal_valid = (g_cached_signal_close > 0.0 && g_cached_prev2_close > 0.0 && g_cached_atr > 0.0);
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

bool Strategy_LoadFadeSignal(QM_OrderType &entry_type, double &signal_return_pct)
  {
   entry_type = QM_BUY;
   signal_return_pct = 0.0;

   if(!g_cached_week_rollover)
      return false;
   if(!g_cached_signal_valid)
      return false;

   if(g_cached_signal_dow < strategy_signal_min_dow || g_cached_signal_dow > 5)
      return false;

   const double signal_close = g_cached_signal_close;
   const double prev_close = g_cached_prev2_close;

   signal_return_pct = 100.0 * MathLog(signal_close / prev_close);
   if(!MathIsValidNumber(signal_return_pct))
      return false;

   const double abs_ret = MathAbs(signal_return_pct);
   if(abs_ret < strategy_min_signal_return_pct)
      return false;
   if(abs_ret > strategy_max_signal_return_pct)
      return false;

   const double atr_pct = 100.0 * g_cached_atr / signal_close;
   if(abs_ret < strategy_min_atr_return_mult * atr_pct)
      return false;

   const double range = g_cached_signal_high - g_cached_signal_low;
   if(range <= 0.0)
      return false;
   const double close_location = (signal_close - g_cached_signal_low) / range;
   const double loc_min = MathMax(0.50, MathMin(0.95, strategy_close_location_min));

   if(signal_return_pct > 0.0)
     {
      if(close_location < loc_min)
         return false;
      entry_type = QM_SELL;
      return true;
     }

   if(signal_return_pct < 0.0)
     {
      if(close_location > (1.0 - loc_min))
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

   const double prior_close = g_cached_signal_valid ? g_cached_signal_close : 0.0;
   const double atr_last = g_cached_signal_valid ? g_cached_atr : 0.0;

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

      if(prior_close > 0.0 && atr_last > 0.0)
        {
         const double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
         const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
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
   if(strategy_signal_min_dow < 4 || strategy_signal_min_dow > 5)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
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
   req.reason = "QM5_13000_XNG_RIGCOUNT_FRI_FADE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

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

   req.reason = (entry_type == QM_BUY) ? "XNG_RIGCOUNT_FRI_FADE_LONG" : "XNG_RIGCOUNT_FRI_FADE_SHORT";
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13000\",\"ea\":\"xng-rig-fri-fade\"}");
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

   // QM_IsNewBar() is single-consume per tick; latch it once and reuse for
   // both the cached-state advance below and the entry-only gate further
   // down, so per-tick management/exit never repeats the CopyRates/CopyClose
   // work that Strategy_AdvanceCachedState does once per closed bar.
   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
      Strategy_AdvanceCachedState();

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
   // management path above so the ATR stop / time-stop keep enforcing through
   // news windows. Fail-closed init in OnInit is unchanged.
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
