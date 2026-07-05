#property strict
#property version   "5.1"
#property description "QM5_12594 Yang WTI Medium-Term Reversal"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QM5_12594 - Yang WTI Medium-Term Reversal
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve, evaluated only on the Monday D1 bar:
//   - fades a fixed medium-term (strategy_lookback_days) return extreme once
//     price is stretched away from SMA(strategy_mean_period) by at least
//     strategy_min_stretch_atr * ATR, confirmed by a short D1 reversal versus
//     the close strategy_confirm_days bars earlier.
//   - exits at SMA mean reversion, max hold, or the ATR hard stop.
// Runtime uses MT5 OHLC only; no futures curve, inventory, API, CSV, or ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12594;
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
input int    strategy_lookback_days        = 63;
input int    strategy_confirm_days         = 5;
input int    strategy_mean_period          = 63;
input int    strategy_atr_period           = 20;
input double strategy_min_abs_return_pct   = 6.0;
input double strategy_min_stretch_atr      = 0.75;
input double strategy_atr_sl_mult          = 3.5;
input int    strategy_max_hold_days        = 15;
input int    strategy_max_spread_points    = 1000;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
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

void Strategy_CloseOpenPositionsIfNeeded()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;

   // Prior D1 close and mean, read via the pooled QM_SMA reader (period=1
   // returns the raw closed-bar price) -- never a direct iClose call.
   const double close_prior = QM_SMA(_Symbol, PERIOD_D1, 1, 1);
   const double sma_mean    = QM_SMA(_Symbol, PERIOD_D1, strategy_mean_period, 1);
   const bool mean_ready = (close_prior > 0.0 && sma_mean > 0.0);

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
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(mean_ready)
        {
         if(pos_type == POSITION_TYPE_BUY && close_prior >= sma_mean)
            should_close = true;
         if(pos_type == POSITION_TYPE_SELL && close_prior <= sma_mean)
            should_close = true;
        }

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_lookback_days <= 0 || strategy_confirm_days <= 0 || strategy_mean_period <= 0)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_min_abs_return_pct <= 0.0 || strategy_min_stretch_atr < 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
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

   if(Strategy_HasOpenPosition())
      return false;

   // Card: "Evaluate entries only on the first D1 bar of the trading week."
   // QM_IsNewBar() already limits OnTick's call into this hook to once per
   // closed D1 bar; this day-of-week mixin further restricts it to Monday.
   // No separate stored week-key latch is needed (that would be the forbidden
   // hand-rolled calendar-cadence pattern) -- IsNewBar + Monday-only already
   // caps evaluation at exactly one D1 bar per week.
   bool monday_only[7] = {true, false, false, false, false, false, false};
   if(QM_Sig_DayOfWeek(TimeCurrent(), monday_only) <= 0)
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   // All price reads go through the pooled QM_SMA reader (period=1 = raw
   // closed-bar price at that shift) -- never a direct iClose call.
   const double close_prior    = QM_SMA(_Symbol, PERIOD_D1, 1, 1);
   const double close_lookback = QM_SMA(_Symbol, PERIOD_D1, 1, 1 + strategy_lookback_days);
   const double close_confirm  = QM_SMA(_Symbol, PERIOD_D1, 1, 1 + strategy_confirm_days);
   const double sma_mean       = QM_SMA(_Symbol, PERIOD_D1, strategy_mean_period, 1);
   const double atr_last       = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(close_prior <= 0.0 || close_lookback <= 0.0 || close_confirm <= 0.0 ||
      sma_mean <= 0.0 || atr_last <= 0.0)
      return false;

   const double return_pct = (close_prior / close_lookback - 1.0) * 100.0;
   const double stretch = strategy_min_stretch_atr * atr_last;

   const bool long_setup  = (return_pct <= -strategy_min_abs_return_pct) &&
                            (close_prior < sma_mean - stretch) &&
                            (close_prior > close_confirm);
   const bool short_setup = (return_pct >= strategy_min_abs_return_pct) &&
                            (close_prior > sma_mean + stretch) &&
                            (close_prior < close_confirm);
   if(!long_setup && !short_setup)
      return false;

   req.type = long_setup ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   // Reuse the already-fetched pooled ATR reading instead of QM_StopATR,
   // whose internal helper (QM_StopRules.mqh) creates a fresh raw iATR
   // handle, CopyBuffer()s it, then releases it in the same call -- that
   // handle never back-calculates in the tester, so every call after the
   // first returns an invalid/zero ATR and permanently blocks re-entry.
   // See project_qm_calendar_fade_family_1trade_bug_2026-07-05 (root-caused
   // + fixed fleet-wide via QM_StopATRFromValue on the pooled value).
   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr_last, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = long_setup ? "YANG_WTI_REVERSAL_LONG" : "YANG_WTI_REVERSAL_SHORT";
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12594\",\"ea\":\"yang-wti-reversal\"}");
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

   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // 2026-07-02 audit rule: management/exit run every tick, ungated by the
   // news blackout below -- the news gate must suspend NEW entries only.
   // See QM5_12821 OnTick (commit dc418a720) for the canonical reference.
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
