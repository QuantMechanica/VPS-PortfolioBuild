#property strict
#property version   "5.0"
#property description "QM5_12702 XNG Winter Withdrawal Long"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12702 - XNG Winter Withdrawal Long
// D1 structural natural-gas sleeve: long-only in the November-March
// winter withdrawal/heating-demand window. Monthly entry only, with D1 SMA
// confirmation. Exits on season end, SMA failure, max hold, Friday close,
// or ATR stop. No EIA, weather, storage, forecast, or futures-curve data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12702;
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
input int    strategy_trend_period        = 42;
input int    strategy_atr_period          = 20;
input double strategy_atr_sl_mult         = 3.0;
input int    strategy_max_hold_days       = 35;
input int    strategy_max_spread_points   = 2500;

// Tracks which calendar month has already been processed for entry.
// Restart-safe: 0 means "no month processed yet".
int g_last_entry_month_key = 0;

// Returns true when month is in the November-March winter withdrawal window.
bool Strategy_IsWinterWithdrawalMonth(const int month)
  {
   return (month == 11 || month == 12 || month == 1 || month == 2 || month == 3);
  }

// Reads the prior-completed D1 close and the SMA at shift=1.
bool Strategy_GetCloseSma(double &out_close, double &out_sma)
  {
   out_close = QM_SMA(_Symbol, PERIOD_D1, 1, 1, PRICE_CLOSE);
   out_sma   = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   return (out_close > 0.0 && out_sma > 0.0);
  }

// --------------------------------------------------------------------------
// No-Trade Filter
// --------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   if(_Symbol != "XNGUSD.DWX" || _Period != PERIOD_D1)
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_trend_period <= 1 || strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   return false;
  }

// --------------------------------------------------------------------------
// Trade Management — season end, SMA failure, and max-hold exits.
// Runs every tick (canonical order: before news gate and IsNewBar).
// Early-return if no position to avoid unnecessary indicator reads.
// --------------------------------------------------------------------------
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) == 0)
      return;

   double close_last = 0.0, sma_last = 0.0;
   if(!Strategy_GetCloseSma(close_last, sma_last))
      return;

   // Determine current month from calendar key (D1-derived; no MN1 bars needed).
   const int month_key = QM_CalendarPeriodKey(PERIOD_MN1);
   const int month     = (month_key > 0) ? (month_key % 100) : 0;
   const bool in_winter = (month > 0) && Strategy_IsWinterWithdrawalMonth(month);

   const datetime now          = TimeCurrent();
   const int      hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);

      bool should_close = false;
      if(pos_type != POSITION_TYPE_BUY)         should_close = true;
      if(!in_winter)                             should_close = true;
      if(close_last < sma_last)                 should_close = true;
      if(opened > 0 && now - opened >= hold_seconds) should_close = true;

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

// --------------------------------------------------------------------------
// Entry Signal — first D1 bar of a new month, during Nov-Mar, close > SMA.
// Called only when QM_IsNewBar() is true.
// --------------------------------------------------------------------------
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type              = QM_BUY;
   req.price             = 0.0;
   req.sl                = 0.0;
   req.tp                = 0.0;
   req.reason            = "XNG_WINTER_WITHDRAWAL_LONG";
   req.symbol_slot       = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One entry attempt per calendar month (restart-safe key comparison).
   // Setting g_last_entry_month_key here regardless of later conditions
   // ensures we attempt entry only on the first D1 bar of each month.
   const int month_key = QM_CalendarPeriodKey(PERIOD_MN1);
   if(month_key <= 0 || month_key == g_last_entry_month_key)
      return false;
   g_last_entry_month_key = month_key;

   // No pyramiding.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Only in the winter withdrawal season (Nov through Mar).
   const int month = month_key % 100;
   if(!Strategy_IsWinterWithdrawalMonth(month))
      return false;

   // Spread cap. Zero spread is normal on .DWX; block only a genuinely wide spread.
   if(strategy_max_spread_points > 0)
     {
      const long spread_pts = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_pts > 0 && spread_pts > (long)strategy_max_spread_points)
         return false;
     }

   // SMA trend confirmation: prior D1 close must be above slow SMA.
   double close_last = 0.0, sma_last = 0.0;
   if(!Strategy_GetCloseSma(close_last, sma_last))
      return false;
   if(close_last <= sma_last)
      return false;

   // Build market BUY entry.
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   return true;
  }

// --------------------------------------------------------------------------
// Exit Signal — deterministic exits handled entirely in ManageOpenPosition.
// --------------------------------------------------------------------------
bool Strategy_ExitSignal()
  {
   return false;
  }

// --------------------------------------------------------------------------
// News Filter Hook — defer to framework axes.
// --------------------------------------------------------------------------
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// --------------------------------------------------------------------------
// Framework wiring
// --------------------------------------------------------------------------
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_12702\",\"slug\":\"xngusd-winter-withdrawal-long\"}");
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

   // Position management and time/season exits run unconditionally —
   // not blocked by the news gate — so risk management keeps running
   // during news windows (2026-07-02 canonical order).
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

   // News gate: gates only the entry path.
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

   // Per-closed-bar: entry signal (QM_IsNewBar consumed once).
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
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
