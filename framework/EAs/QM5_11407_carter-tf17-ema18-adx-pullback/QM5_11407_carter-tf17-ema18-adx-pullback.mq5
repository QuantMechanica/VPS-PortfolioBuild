#property strict
#property version   "5.0"
#property description "QM5_11407 Carter TF17 EMA18 ADX pullback"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11407 carter-tf17-ema18-adx-pullback
// -----------------------------------------------------------------------------
// Mechanised only from the APPROVED Strategy Card. Strategy-specific code is
// confined to the five hooks and the Strategy input group. Framework lifecycle,
// risk, magic, news, Friday-close, MAE, entry, and logging wiring stays canonical.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11407;
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
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault Q09 News Impact Mode.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_period          = 18;
input int    strategy_adx_period          = 12;
input double strategy_adx_threshold       = 25.0;
input int    strategy_touch_lookback_bars = 3;
input int    strategy_entry_buffer_pips   = 1;
input int    strategy_swing_lookback      = 3;
input int    strategy_sl_cap_pips         = 70;
input int    strategy_atr_period          = 14;
input double strategy_atr_tp_mult         = 2.0;
input double strategy_be_trigger_atr      = 1.0;
input int    strategy_spread_cap_pips     = 20;

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

// No Trade Filter: the card has no session restriction. The framework owns
// time/weekend/Friday and news gates; this hook applies only the 20-pip spread
// cap. A zero modelled .DWX spread is valid and therefore passes.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                              strategy_spread_cap_pips);
   if(spread_cap <= 0.0)
      return true;

   if(ask > bid && (ask - bid) > spread_cap)
      return true;

   return false;
  }

// Trade Entry: identify the first EMA touch within the card's three-bar scan.
// The preceding closed bar supplies the pre-pullback trend and ADX state; the
// touch bar must retain ADX > threshold. The break of that bar is the one event.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0; // card gives no cancellation rule: literal GTC

   if(strategy_ema_period <= 0 ||
      strategy_adx_period <= 0 ||
      strategy_adx_threshold <= 0.0 ||
      strategy_touch_lookback_bars <= 0 ||
      strategy_entry_buffer_pips <= 0 ||
      strategy_swing_lookback <= 0 ||
      strategy_sl_cap_pips <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_tp_mult <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   // Keep at most one resting stop order for this EA/symbol. The card does not
   // authorize replacing or cancelling an untriggered order on later signals.
   for(int order_index = OrdersTotal() - 1; order_index >= 0; --order_index)
     {
      const ulong ticket = OrderGetTicket(order_index);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      return false;
     }

   int touch_shift = 0;
   bool long_setup = false;
   bool short_setup = false;
   double touch_high = 0.0;
   double touch_low = 0.0;
   double touch_atr = 0.0;

   // The card's Implementation Notes explicitly specify scan i=1..3. The
   // configurable upper bound defaults to three so P3 can reproduce the card.
   for(int shift = 1; shift <= strategy_touch_lookback_bars; ++shift)
     {
      const double ema_touch = QM_EMA(_Symbol, PERIOD_H4,
                                      strategy_ema_period, shift);
      const double ema_before = QM_EMA(_Symbol, PERIOD_H4,
                                       strategy_ema_period, shift + 1);
      const double adx_touch = QM_ADX(_Symbol, PERIOD_H4,
                                      strategy_adx_period, shift);
      const double adx_before = QM_ADX(_Symbol, PERIOD_H4,
                                       strategy_adx_period, shift + 1);

      const double high_touch = iHigh(_Symbol, PERIOD_H4, shift); // perf-allowed: card-authorized three-bar first-touch scan behind the framework closed-bar gate.
      const double low_touch = iLow(_Symbol, PERIOD_H4, shift); // perf-allowed: card-authorized three-bar first-touch scan behind the framework closed-bar gate.
      const double close_before = iClose(_Symbol, PERIOD_H4, shift + 1); // perf-allowed: card-authorized pre-pullback trend state behind the framework closed-bar gate.
      const double high_before = iHigh(_Symbol, PERIOD_H4, shift + 1); // perf-allowed: confirms the short setup's first EMA touch in the bounded scan.
      const double low_before = iLow(_Symbol, PERIOD_H4, shift + 1); // perf-allowed: confirms the long setup's first EMA touch in the bounded scan.

      if(ema_touch <= 0.0 || ema_before <= 0.0 ||
         adx_touch <= 0.0 || adx_before <= 0.0 ||
         high_touch <= 0.0 || low_touch <= 0.0 ||
         close_before <= 0.0 || high_before <= 0.0 || low_before <= 0.0)
         continue;

      if(adx_before <= strategy_adx_threshold ||
         adx_touch <= strategy_adx_threshold)
         continue;

      const bool first_long_touch = (close_before > ema_before &&
                                     low_before > ema_before &&
                                     low_touch <= ema_touch);
      const bool first_short_touch = (close_before < ema_before &&
                                      high_before < ema_before &&
                                      high_touch >= ema_touch);

      if(first_long_touch)
        {
         touch_shift = shift;
         long_setup = true;
         touch_high = high_touch;
         touch_low = low_touch;
         break;
        }
      if(first_short_touch)
        {
         touch_shift = shift;
         short_setup = true;
         touch_high = high_touch;
         touch_low = low_touch;
         break;
        }
     }

   if(touch_shift <= 0 || (!long_setup && !short_setup))
      return false;

   touch_atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, touch_shift);
   if(touch_atr <= 0.0)
      return false;

   const double entry_buffer = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                                strategy_entry_buffer_pips);
   if(entry_buffer <= 0.0)
      return false;

   const QM_OrderType side = long_setup ? QM_BUY : QM_SELL;
   const QM_OrderType pending_type = long_setup ? QM_BUY_STOP : QM_SELL_STOP;
   const double trigger_raw = long_setup
                              ? (touch_high + entry_buffer)
                              : (touch_low - entry_buffer);
   const double trigger = QM_StopRulesNormalizePrice(_Symbol, trigger_raw);
   if(trigger <= 0.0)
      return false;

   // A historical touch whose break already happened is no longer a valid
   // resting stop placement. Zero spread remains valid here.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(long_setup && ask > 0.0 && trigger <= ask)
      return false;
   if(short_setup && bid > 0.0 && trigger >= bid)
      return false;

   double sl = QM_StopStructure(_Symbol,
                                side,
                                trigger,
                                strategy_swing_lookback);
   if(sl <= 0.0)
      return false;

   const double sl_cap = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                          strategy_sl_cap_pips);
   if(sl_cap <= 0.0)
      return false;

   if(long_setup)
     {
      if(sl >= trigger)
         return false;
      if((trigger - sl) > sl_cap)
         sl = trigger - sl_cap;
     }
   else
     {
      if(sl <= trigger)
         return false;
      if((sl - trigger) > sl_cap)
         sl = trigger + sl_cap;
     }
   sl = QM_StopRulesNormalizePrice(_Symbol, sl);

   const double tp = QM_TakeATRFromValue(_Symbol,
                                          side,
                                          trigger,
                                          touch_atr,
                                          strategy_atr_tp_mult);
   if(tp <= 0.0)
      return false;

   req.type               = pending_type;
   req.price              = trigger;
   req.sl                 = sl;
   req.tp                 = tp;
   req.reason             = long_setup
                            ? "carter_tf17_ema18_adx_long"
                            : "carter_tf17_ema18_adx_short";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Trade Management: move the stop to exact break-even at +1 entry ATR. The
// entry ATR is recovered from the fixed ATR target, avoiding per-tick indicator
// reads while preserving the card's entry-time volatility scale.
void Strategy_ManageOpenPosition()
  {
   if(strategy_atr_tp_mult <= 0.0 || strategy_be_trigger_atr <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) <= 0)
      return;

   const double one_pip = QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   if(one_pip <= 0.0)
      return;

   for(int position_index = PositionsTotal() - 1; position_index >= 0; --position_index)
     {
      const ulong ticket = PositionGetTicket(position_index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double take_price = PositionGetDouble(POSITION_TP);
      if(open_price <= 0.0 || take_price <= 0.0)
         continue;

      const double entry_atr = MathAbs(take_price - open_price) /
                               strategy_atr_tp_mult;
      const int trigger_pips = (int)MathRound(strategy_be_trigger_atr *
                                               entry_atr / one_pip);
      if(trigger_pips <= 0)
         continue;

      QM_TM_MoveToBreakEven(ticket, trigger_pips, 0);
     }
  }

// Trade Close: no discretionary close beyond the card's SL, ATR target, and
// break-even management. The framework still enforces kill-switch and Friday.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook: no card-specific override. P8 can call this hook while the
// central two-axis news filter remains the authoritative entry gate.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

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
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule).
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

   // FW1 — the two-axis news check gates new entries only.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol,
                                        broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
