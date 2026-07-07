#property strict
#property version   "5.0"
#property description "QM5_11565 Connors 3 Down Days SMA200 D1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_11565_connors-3down-days-sma200-d1
// -----------------------------------------------------------------------------
// Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_11565_connors-3down-days-sma200-d1.md
// Source: Larry Connors & Cesar Alvarez, Short-Term Trading Strategies That Work
// Mechanics:
//   LONG  when D1 close[1] > SMA200 and close[1]<close[2]<close[3]<close[4].
//   SHORT when D1 close[1] < SMA200 and close[1]>close[2]>close[3]>close[4]>close[5].
//   LONG exit when RSI(2) on the last closed D1 bar is > 65.
//   SHORT exit when the last closed D1 close is below SMA5.
//   Protective stop is 2*ATR(14), capped at 150 pips.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11565;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 - Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 - only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_signal_sma_period  = 200;
input int    strategy_long_down_days     = 3;
input int    strategy_short_up_days      = 4;
input int    strategy_rsi_period         = 2;
input double strategy_long_rsi_exit      = 65.0;
input int    strategy_short_exit_sma     = 5;
input int    strategy_atr_period         = 14;
input double strategy_atr_stop_mult      = 2.0;
input int    strategy_stop_cap_pips      = 150;
input int    strategy_spread_cap_pips    = 15;
input bool   strategy_block_friday_entry = true;

// -----------------------------------------------------------------------------
// Strategy hooks - implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick. Keep this to configuration validation;
// card entry-only filters (spread and Friday) are checked in Strategy_EntrySignal
// so open-position management and exits continue to run.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;

   if(qm_magic_slot_offset == 0 && _Symbol != "EURUSD.DWX")
      return true;
   if(qm_magic_slot_offset == 1 && _Symbol != "GBPUSD.DWX")
      return true;
   if(qm_magic_slot_offset == 2 && _Symbol != "USDJPY.DWX")
      return true;
   if(qm_magic_slot_offset < 0 || qm_magic_slot_offset > 2)
      return true;

   if(strategy_signal_sma_period <= 1 ||
      strategy_long_down_days < 1 ||
      strategy_short_up_days < 1 ||
      strategy_rsi_period <= 1 ||
      strategy_short_exit_sma <= 1 ||
      strategy_atr_period <= 1 ||
      strategy_atr_stop_mult <= 0.0 ||
      strategy_stop_cap_pips <= 0 ||
      strategy_spread_cap_pips <= 0)
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(strategy_block_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5)
         return false;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(ask > bid && spread_cap > 0.0 && (ask - bid) > spread_cap)
      return false;

   double closes[16];
   for(int i = 0; i < 16; ++i)
      closes[i] = 0.0;

   int closes_needed = strategy_long_down_days + 1;
   const int short_closes_needed = strategy_short_up_days + 1;
   if(short_closes_needed > closes_needed)
      closes_needed = short_closes_needed;
   if(closes_needed > 15)
      return false;

   for(int shift = 1; shift <= closes_needed; ++shift)
     {
      double close_buf[1];
      const int got = CopyClose(_Symbol, PERIOD_D1, shift, 1, close_buf); // perf-allowed: fixed single closed D1 close read behind framework new-bar gate.
      if(got != 1 || close_buf[0] <= 0.0)
         return false;
      closes[shift] = close_buf[0];
     }

   const double sma200 = QM_SMA(_Symbol, PERIOD_D1, strategy_signal_sma_period, 1, PRICE_CLOSE);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(sma200 <= 0.0 || atr <= 0.0 || closes[1] <= 0.0)
      return false;

   bool long_run = true;
   for(int long_shift = 1; long_shift <= strategy_long_down_days; ++long_shift)
     {
      if(!(closes[long_shift] < closes[long_shift + 1]))
        {
         long_run = false;
         break;
        }
     }

   bool short_run = true;
   for(int short_shift = 1; short_shift <= strategy_short_up_days; ++short_shift)
     {
      if(!(closes[short_shift] > closes[short_shift + 1]))
        {
         short_run = false;
         break;
        }
     }

   const double atr_distance = atr * strategy_atr_stop_mult;
   const double cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_stop_cap_pips);
   const bool use_cap = (cap_distance > 0.0 && atr_distance > cap_distance);

   if(closes[1] > sma200 && long_run)
     {
      const double sl = use_cap
                        ? QM_StopFixedPips(_Symbol, QM_BUY, ask, strategy_stop_cap_pips)
                        : QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr, strategy_atr_stop_mult);
      if(sl <= 0.0 || sl >= ask)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "CONNORS_3DOWN_SMA200_LONG";
      return true;
     }

   if(closes[1] < sma200 && short_run)
     {
      const double sl = use_cap
                        ? QM_StopFixedPips(_Symbol, QM_SELL, bid, strategy_stop_cap_pips)
                        : QM_StopATRFromValue(_Symbol, QM_SELL, bid, atr, strategy_atr_stop_mult);
      if(sl <= 0.0 || sl <= bid)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "CONNORS_4UP_SMA200_SHORT";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

// Return TRUE to close the open position now. Exits are evaluated from the last
// closed D1 bar so the close occurs on the next D1 open.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   bool have_position = false;
   bool is_long = true;
   datetime opened_at = 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      is_long = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      have_position = true;
      break;
     }

   if(!have_position)
      return false;

   const int d1_seconds = PeriodSeconds(PERIOD_D1);
   if(opened_at > 0 && d1_seconds > 0 && (TimeCurrent() - opened_at) < d1_seconds)
      return false;

   if(is_long)
     {
      const double rsi2 = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 1, PRICE_CLOSE);
      if(rsi2 <= 0.0)
         return false;
      return (rsi2 > strategy_long_rsi_exit);
     }

   double close_buf[1];
   const int got = CopyClose(_Symbol, PERIOD_D1, 1, 1, close_buf); // perf-allowed: fixed single closed D1 close read for short exit.
   if(got != 1 || close_buf[0] <= 0.0)
      return false;

   const double sma5 = QM_SMA(_Symbol, PERIOD_D1, strategy_short_exit_sma, 1, PRICE_CLOSE);
   if(sma5 <= 0.0)
      return false;

   return (close_buf[0] < sma5);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework").
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
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
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows - the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes - EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   // FW1 - 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only -
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 - emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
