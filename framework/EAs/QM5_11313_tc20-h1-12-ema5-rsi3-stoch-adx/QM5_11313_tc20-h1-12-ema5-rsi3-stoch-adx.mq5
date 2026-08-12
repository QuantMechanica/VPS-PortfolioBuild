#property strict
#property version   "5.0"
#property description "QM5_11313 TC20 #12 EMA/RSI/Stoch/ADX H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11313 tc20-h1-12-ema5-rsi3-stoch-adx
// -----------------------------------------------------------------------------
// Approved card: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time
// Frame)", Strategy #12. The EMA(3, close)/EMA(5, open) cross is the one fresh
// entry event. RSI(3), Stochastic(5,3,3), ADX DI direction and EMA(34/89) are
// simultaneous closed-bar states, avoiding the two-cross-same-bar DWX trap.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11313;
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
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_macro_fast     = 34;    // macro trend EMA on close
input int    strategy_ema_macro_slow     = 89;    // macro trend EMA on close
input int    strategy_ema_trigger_fast   = 3;     // micro trigger EMA on close
input int    strategy_ema_trigger_slow   = 5;     // micro trigger EMA on open
input int    strategy_rsi_period         = 3;     // momentum-burst RSI period
input double strategy_rsi_long_level     = 80.0;  // long burst state threshold
input double strategy_rsi_short_level    = 20.0;  // short burst state threshold
input int    strategy_stoch_k            = 5;     // Stochastic K period
input int    strategy_stoch_d            = 3;     // Stochastic D period
input int    strategy_stoch_slowing      = 3;     // Stochastic slowing
input bool   strategy_adx_enabled        = true;  // P3 card sweep: ADX filter on/off
input int    strategy_adx_period         = 14;    // ADX DI period
input int    strategy_structure_lookback = 5;     // prior bars for stop extreme
input int    strategy_sl_buffer_pips     = 2;     // buffer beyond EMA/structure
input int    strategy_sl_min_pips        = 20;    // minimum distance before ATR cap
input int    strategy_atr_period         = 14;    // ATR period for P2 stop cap
input double strategy_atr_cap_mult       = 1.5;   // maximum stop distance in ATR
input double strategy_take_profit_rr     = 2.0;   // TP distance divided by SL distance
input int    strategy_spread_cap_pips    = 20;    // card spread ceiling

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

// No Trade Filter: block only invalid quotes or a genuinely wide spread.
// Zero modeled spread on .DWX remains tradeable.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(spread_cap > 0.0 && ask > bid && (ask - bid) > spread_cap)
      return true;

   return false;
  }

// Trade Entry: caller guarantees one evaluation per new closed H1 bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(strategy_ema_macro_fast <= 0 || strategy_ema_macro_slow <= 0 ||
      strategy_ema_trigger_fast <= 0 || strategy_ema_trigger_slow <= 0 ||
      strategy_rsi_period <= 0 || strategy_stoch_k <= 0 ||
      strategy_stoch_d <= 0 || strategy_stoch_slowing <= 0 ||
      strategy_adx_period <= 0 || strategy_structure_lookback <= 0 ||
      strategy_atr_period <= 0 || strategy_take_profit_rr <= 0.0)
      return false;

   const double macro_fast = QM_EMA(_Symbol, _Period, strategy_ema_macro_fast, 1, PRICE_CLOSE);
   const double macro_slow = QM_EMA(_Symbol, _Period, strategy_ema_macro_slow, 1, PRICE_CLOSE);
   const double trigger_fast_now = QM_EMA(_Symbol, _Period, strategy_ema_trigger_fast, 1, PRICE_CLOSE);
   const double trigger_fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_trigger_fast, 2, PRICE_CLOSE);
   const double trigger_slow_now = QM_EMA(_Symbol, _Period, strategy_ema_trigger_slow, 1, PRICE_OPEN);
   const double trigger_slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_trigger_slow, 2, PRICE_OPEN);
   const double rsi_now = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1, PRICE_CLOSE);
   const double stoch_k_now = QM_Stoch_K(_Symbol, _Period,
                                         strategy_stoch_k,
                                         strategy_stoch_d,
                                         strategy_stoch_slowing,
                                         1);
   const double stoch_d_now = QM_Stoch_D(_Symbol, _Period,
                                         strategy_stoch_k,
                                         strategy_stoch_d,
                                         strategy_stoch_slowing,
                                         1);
   const double atr_now = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);

   if(macro_fast <= 0.0 || macro_slow <= 0.0 ||
      trigger_fast_now <= 0.0 || trigger_fast_prev <= 0.0 ||
      trigger_slow_now <= 0.0 || trigger_slow_prev <= 0.0 ||
      atr_now <= 0.0)
      return false;

   double plus_di = 0.0;
   double minus_di = 0.0;
   if(strategy_adx_enabled)
     {
      plus_di = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 1);
      minus_di = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 1);
     }

   const bool macro_long = (macro_fast > macro_slow);
   const bool macro_short = (macro_fast < macro_slow);
   const bool rsi_long = (rsi_now >= strategy_rsi_long_level);
   const bool rsi_short = (rsi_now <= strategy_rsi_short_level);
   const bool stoch_long = (stoch_k_now > stoch_d_now);
   const bool stoch_short = (stoch_k_now < stoch_d_now);
   const bool adx_long = (!strategy_adx_enabled || plus_di > minus_di);
   const bool adx_short = (!strategy_adx_enabled || minus_di > plus_di);
   const bool trigger_long = (trigger_fast_prev <= trigger_slow_prev &&
                              trigger_fast_now > trigger_slow_now);
   const bool trigger_short = (trigger_fast_prev >= trigger_slow_prev &&
                               trigger_fast_now < trigger_slow_now);

   int direction = 0;
   if(macro_long && rsi_long && stoch_long && adx_long && trigger_long)
      direction = 1;
   else if(macro_short && rsi_short && stoch_short && adx_short && trigger_short)
      direction = -1;
   if(direction == 0)
      return false;

   const double entry = (direction > 0)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   QM_OrderType side = QM_BUY;
   if(direction < 0)
      side = QM_SELL;

   const double structure_stop = QM_StopStructure(_Symbol,
                                                   side,
                                                   entry,
                                                   strategy_structure_lookback);
   const double buffer_distance = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                                   strategy_sl_buffer_pips);
   const double minimum_distance = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                                    strategy_sl_min_pips);
   const double cap_distance = atr_now * strategy_atr_cap_mult;
   if(structure_stop <= 0.0 || buffer_distance <= 0.0 ||
      minimum_distance <= 0.0 || cap_distance <= 0.0)
      return false;

   double raw_stop = 0.0;
   double stop_distance = 0.0;
   if(direction > 0)
     {
      raw_stop = MathMin(macro_fast, structure_stop) - buffer_distance;
      stop_distance = entry - raw_stop;
     }
   else
     {
      raw_stop = MathMax(macro_fast, structure_stop) + buffer_distance;
      stop_distance = raw_stop - entry;
     }

   if(stop_distance < minimum_distance)
      stop_distance = minimum_distance;
   if(stop_distance > cap_distance)
      stop_distance = cap_distance;
   if(stop_distance <= 0.0)
      return false;

   double stop_price = (direction > 0)
                       ? entry - stop_distance
                       : entry + stop_distance;
   stop_price = QM_StopRulesNormalizePrice(_Symbol, stop_price);
   const double take_price = QM_TakeRR(_Symbol,
                                       side,
                                       entry,
                                       stop_price,
                                       strategy_take_profit_rr);
   if(stop_price <= 0.0 || take_price <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;
   req.sl     = stop_price;
   req.tp     = take_price;
   req.reason = (direction > 0) ? "tc20_12_long" : "tc20_12_short";
   return true;
  }

// Trade Management: the card specifies fixed SL/TP only.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: reverse EMA(3,close)/EMA(5,open) cross.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double trigger_fast_now = QM_EMA(_Symbol, _Period, strategy_ema_trigger_fast, 1, PRICE_CLOSE);
   const double trigger_fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_trigger_fast, 2, PRICE_CLOSE);
   const double trigger_slow_now = QM_EMA(_Symbol, _Period, strategy_ema_trigger_slow, 1, PRICE_OPEN);
   const double trigger_slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_trigger_slow, 2, PRICE_OPEN);
   if(trigger_fast_now <= 0.0 || trigger_fast_prev <= 0.0 ||
      trigger_slow_now <= 0.0 || trigger_slow_prev <= 0.0)
      return false;

   const bool reverse_down = (trigger_fast_prev >= trigger_slow_prev &&
                              trigger_fast_now < trigger_slow_now);
   const bool reverse_up = (trigger_fast_prev <= trigger_slow_prev &&
                            trigger_fast_now > trigger_slow_now);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY && reverse_down)
         return true;
      if(position_type == POSITION_TYPE_SELL && reverse_up)
         return true;
     }

   return false;
  }

// News Filter Hook: no card-specific override; central framework filter applies.
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
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
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

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
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
