#property strict
#property version   "5.0"
#property description "QuantMechanica V5 — QM5_9199 Liquidity Sweep with Moving Average Filter"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9199 — mql5-liq-ma-sweep
// Source: Christian Benjamin, MQL5 Articles Part 20, 2025-06-11
// Logic: Detect a price sweep below/above the prior 20-bar liquidity low/high
//        that closes back inside. Enter on the next bar open with an MA-filter
//        confirmation. Exit when the closed bar crosses back through the MA.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9199;
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
input int    strategy_liq_lookback   = 20;    // Bars for liquidity high/low window (prior to sweep bar)
input int    strategy_ma_period      = 50;    // SMA period for trend/direction filter
input int    strategy_atr_period     = 14;    // ATR period for stop-loss sizing
input double strategy_atr_sl_mult   = 0.25;  // ATR multiplier applied below/above sweep extreme

// -----------------------------------------------------------------------------
// Strategy state — cooldown timestamps (strategy logic, not new-bar detection)
// -----------------------------------------------------------------------------
datetime g_last_long_entry_time  = 0;
datetime g_last_short_entry_time = 0;

// -----------------------------------------------------------------------------
// No Trade Filter
// -----------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   return false; // framework news + Friday-close guards are sufficient
  }

// -----------------------------------------------------------------------------
// Entry Signal
// Called once per closed bar (framework guarantees QM_IsNewBar() == true).
// Detects a liquidity sweep: prior 20-bar low/high swept then closed back inside.
// Confirms with SMA-slope or price-vs-MA filter.
// -----------------------------------------------------------------------------
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Compute prior 20-bar liquidity range (bars 2..21, excluding the sweep bar itself)
   double liq_high = -1e10;
   double liq_low  =  1e10;
   for(int b = 2; b <= strategy_liq_lookback + 1; ++b)
     {
      double h = iHigh(_Symbol, _Period, b);  // perf-allowed: bespoke structural sweep detection
      double l = iLow(_Symbol, _Period, b);   // perf-allowed: bespoke structural sweep detection
      if(h > liq_high) liq_high = h;
      if(l < liq_low)  liq_low  = l;
     }

   // Bar 1 = the just-closed sweep candidate bar
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: bespoke sweep close-back check
   const double high1  = iHigh(_Symbol, _Period, 1);  // perf-allowed: bespoke sweep high detection
   const double low1   = iLow(_Symbol, _Period, 1);   // perf-allowed: bespoke sweep low detection

   // SMA for direction filter and slope
   const double sma1 = QM_SMA(_Symbol, _Period, strategy_ma_period, 1);
   const double sma2 = QM_SMA(_Symbol, _Period, strategy_ma_period, 2);
   if(sma1 <= 0.0 || sma2 <= 0.0)
      return false;

   // ATR for stop-loss sizing
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   // Cooldown: enforce one sweep trade per direction per strategy_liq_lookback bars
   const datetime cooldown_seconds = (datetime)(strategy_liq_lookback * PeriodSeconds(_Period));
   const datetime now = TimeCurrent();

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = _Point;

   // ------ LONG sweep -------------------------------------------------------
   // Condition: bar 1 trades below the prior 20-bar low AND closes back above it
   if(low1 < liq_low && close1 > liq_low)
     {
      // MA filter: price closed above MA, OR MA slope is positive
      if(close1 > sma1 || sma1 > sma2)
        {
         // Cooldown check
         if(now - g_last_long_entry_time >= cooldown_seconds)
           {
            const double sl_price = liq_low - atr * strategy_atr_sl_mult;
            if(sl_price >= ask) return false; // degenerate: SL above entry

            const double r        = ask - sl_price;
            const double tp_2r    = ask + 2.0 * r;
            const double tp_range = liq_high;
            const double tp_price = (tp_range < tp_2r) ? tp_range : tp_2r; // closer to entry

            if(tp_price <= ask) return false; // no valid upside target

            const double sl_pts = (ask - sl_price) / point;
            if(sl_pts <= 0.0) return false;

            req.type         = QM_BUY;
            req.price        = 0.0; // market order
            req.sl           = NormalizeDouble(sl_price, _Digits);
            req.tp           = NormalizeDouble(tp_price, _Digits);
            req.reason       = "liq_sweep_long";
            req.symbol_slot  = 0; // resolved by framework magic resolver

            g_last_long_entry_time = now;
            return true;
           }
        }
     }

   // ------ SHORT sweep ------------------------------------------------------
   // Condition: bar 1 trades above the prior 20-bar high AND closes back below it
   if(high1 > liq_high && close1 < liq_high)
     {
      // MA filter: price closed below MA, OR MA slope is negative
      if(close1 < sma1 || sma1 < sma2)
        {
         // Cooldown check
         if(now - g_last_short_entry_time >= cooldown_seconds)
           {
            const double sl_price = liq_high + atr * strategy_atr_sl_mult;
            if(sl_price <= bid) return false; // degenerate: SL below entry

            const double r        = sl_price - bid;
            const double tp_2r    = bid - 2.0 * r;
            const double tp_range = liq_low;
            const double tp_price = (tp_range > tp_2r) ? tp_range : tp_2r; // closer to entry

            if(tp_price >= bid) return false; // no valid downside target

            const double sl_pts = (sl_price - bid) / point;
            if(sl_pts <= 0.0) return false;

            req.type         = QM_SELL;
            req.price        = 0.0; // market order
            req.sl           = NormalizeDouble(sl_price, _Digits);
            req.tp           = NormalizeDouble(tp_price, _Digits);
            req.reason       = "liq_sweep_short";
            req.symbol_slot  = 0;

            g_last_short_entry_time = now;
            return true;
           }
        }
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Trade Management — no trailing or break-even; SL/TP are fixed at entry
// -----------------------------------------------------------------------------
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP at entry; no intra-trade management required.
  }

// -----------------------------------------------------------------------------
// Exit Signal
// Close if the most recently closed bar (shift 1) has crossed back through the
// SMA against the position direction.  Uses closed-bar values (shift 1 is
// stable within a bar) so this fires on the first tick of the bar after the
// MA cross — effectively a bar-close exit with no QM_IsNewBar consumption.
// -----------------------------------------------------------------------------
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(PositionsTotal() == 0) return false;

   const double sma1   = QM_SMA(_Symbol, _Period, strategy_ma_period, 1);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: bar-close MA-cross exit rule
   if(sma1 <= 0.0 || close1 <= 0.0) return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pt == POSITION_TYPE_BUY  && close1 < sma1) return true;
      if(pt == POSITION_TYPE_SELL && close1 > sma1) return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// News Filter Hook — defer to framework
// -----------------------------------------------------------------------------
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line
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
