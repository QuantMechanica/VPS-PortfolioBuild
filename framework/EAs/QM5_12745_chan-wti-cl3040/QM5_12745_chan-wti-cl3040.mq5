#property strict
#property version   "5.0"
#property description "QM5_12745 WTI Chan 30/40-Day CL Filter"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12745 - WTI Chan 30/40-Day CL Structural Filter
// Chan AT Chapter 6: crude-oil 30/40-day combination variant (SRC05_S07_CL3040)
// Long  when close < 30-day ref AND close > 40-day ref.
// Short when close > 30-day ref AND close < 40-day ref.
// ATR hard stop, max-hold stale guard, symmetric long/short, one position/magic.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12745;
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
input int    strategy_short_lookback_d1  = 30;
input int    strategy_long_lookback_d1   = 40;
input int    strategy_atr_period         = 20;
input double strategy_atr_sl_mult        = 2.75;
input int    strategy_max_hold_days      = 20;
input int    strategy_max_spread_points  = 1000;

// -----------------------------------------------------------------------------
// Internal helpers
// -----------------------------------------------------------------------------

// Returns the current Chan signal from the last closed D1 bar.
// direction: +1 = long, -1 = short, 0 = flat.
bool Strategy_LoadChanSignal(int &direction)
  {
   direction = 0;

   int short_lb = strategy_short_lookback_d1;
   if(short_lb < 5) short_lb = 5;
   int long_lb = strategy_long_lookback_d1;
   if(long_lb <= short_lb) long_lb = short_lb + 1;

   double closes[];
   ArraySetAsSeries(closes, true);
   // perf-allowed: bounded D1 close series read; only called when position is
   // open (in ManageOpenPosition) or on a new closed bar (in EntrySignal).
   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, long_lb + 1, closes);
   if(copied < long_lb + 1) return false;

   const double c0      = closes[0];
   const double c_short = closes[short_lb];
   const double c_long  = closes[long_lb];
   if(c0 <= 0.0 || c_short <= 0.0 || c_long <= 0.0) return false;

   if(c0 < c_short && c0 > c_long)
      direction = 1;
   else if(c0 > c_short && c0 < c_long)
      direction = -1;
   else
      direction = 0;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != "XTIUSD.DWX" || _Period != PERIOD_D1) return true;
   if(qm_magic_slot_offset != 0) return true;
   if(strategy_short_lookback_d1 < 5) return true;
   if(strategy_long_lookback_d1 <= strategy_short_lookback_d1) return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0) return true;
   if(strategy_max_hold_days <= 0) return true;
   return false;
  }

// Called every tick (before the news gate per 2026-07-02 OnTick ordering rule).
// Handles both time-stop and signal-based exit so risk management runs through
// news windows.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) == 0) return;

   const datetime now = TimeCurrent();
   const int hold_seconds = (strategy_max_hold_days > 0 ? strategy_max_hold_days : 1) * 86400;

   int signal_direction = 0;
   // CopyClose is bounded (short_lb+1 bars max) and only runs when a position
   // is open; D1 tick rate is low so per-tick overhead is acceptable.
   const bool signal_loaded = Strategy_LoadChanSignal(signal_direction);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const int pos_direction = (pos_type == POSITION_TYPE_BUY) ? 1 : -1;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const bool time_up = (opened > 0 && (now - opened) >= hold_seconds);

      // Exit on signal disappears/reverses, or on max-hold expiry.
      bool should_close = time_up;
      if(!should_close && signal_loaded && (signal_direction == 0 || signal_direction != pos_direction))
         should_close = true;

      if(should_close)
         QM_TM_ClosePosition(ticket, time_up ? QM_EXIT_TIME_STOP : QM_EXIT_STRATEGY);
     }
  }

// Exits are fully handled in ManageOpenPosition to ensure management continues
// through news windows; ExitSignal returns false.
bool Strategy_ExitSignal()
  {
   return false;
  }

// Called once per new closed D1 bar (gated by QM_IsNewBar in OnTick).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0) return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_pts = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      // Zero spread in .DWX tester is tradeable; only block genuinely wide spread.
      if(spread_pts > (long)strategy_max_spread_points) return false;
     }

   int direction = 0;
   if(!Strategy_LoadChanSignal(direction)) return false;
   if(direction == 0) return false;

   const double atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_last <= 0.0) return false;

   req.type   = (direction > 0) ? QM_BUY : QM_SELL;
   req.price  = 0.0;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0) return false;

   req.sl     = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0) return false;

   req.tp              = 0.0;
   req.reason          = (direction > 0) ? "WTI_CHAN_3040_LONG" : "WTI_CHAN_3040_SHORT";
   req.symbol_slot     = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Defer news filtering to the framework axes; no custom override needed.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12745\",\"ea\":\"chan-wti-cl3040\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

// Canonical OnTick ordering (2026-07-02 binding rule):
//   kill-switch → Friday-close → NoTradeFilter → ManageOpenPosition →
//   ExitSignal → news gate → IsNewBar → EntrySignal
void OnTick()
  {
   if(!QM_KillSwitchCheck()) return;
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   // Management and exit run every tick, before the news gate, so that SL
   // enforcement and condition-based exits continue through news blackouts.
   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   // News gate — guards entry path only.
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(!QM_IsNewBar()) return;

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
