#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA skeleton template"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12935;
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
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_tlb_lines         = 3;
input int    strategy_2b_lookback       = 50;
input int    strategy_regime_sma_period = 200;
input int    strategy_atr_period        = 14;
input double strategy_stop_atr_cap_mult = 3.0;
input double strategy_be_trigger_atr_mult = 1.5;
input int    strategy_be_buffer_pips    = 1;
input double strategy_spread_atr_mult   = 0.5;
input int    strategy_time_stop_bars    = 40;

double H4High(const int shift)
  {
   return iHigh(_Symbol, PERIOD_H4, shift); // perf-allowed: bespoke TLB structural OHLC primitive.
  }

double H4Low(const int shift)
  {
   return iLow(_Symbol, PERIOD_H4, shift); // perf-allowed: bespoke TLB structural OHLC primitive.
  }

double H4Close(const int shift)
  {
   return iClose(_Symbol, PERIOD_H4, shift); // perf-allowed: bespoke TLB structural OHLC primitive.
  }

double D1Close(const int shift)
  {
   return iClose(_Symbol, PERIOD_D1, shift); // perf-allowed: D1 regime close paired with QM_SMA.
  }

int TLBEventAtShift(const int shift)
  {
   if(strategy_tlb_lines < 2 || shift < 1)
      return 0;

   const double close_value = H4Close(shift);
   if(close_value <= 0.0)
      return 0;

   double prior_high = -DBL_MAX;
   double prior_low = DBL_MAX;
   for(int i = 1; i <= strategy_tlb_lines; ++i)
     {
      const double high_value = H4High(shift + i);
      const double low_value = H4Low(shift + i);
      if(high_value <= 0.0 || low_value <= 0.0)
         return 0;
      if(high_value > prior_high)
         prior_high = high_value;
      if(low_value < prior_low)
         prior_low = low_value;
     }

   if(close_value > prior_high)
      return 1;
   if(close_value < prior_low)
      return -1;
   return 0;
  }

int LastTLBDirectionBefore(const int shift)
  {
   const int max_shift = shift + strategy_2b_lookback + strategy_tlb_lines;
   for(int s = shift + 1; s <= max_shift; ++s)
     {
      const int event_dir = TLBEventAtShift(s);
      if(event_dir != 0)
         return event_dir;
     }
   return 0;
  }

int CurrentTLBFlip()
  {
   const int current_dir = TLBEventAtShift(1);
   if(current_dir == 0)
      return 0;

   const int prior_dir = LastTLBDirectionBefore(1);
   if(current_dir > 0 && prior_dir < 0)
      return 1;
   if(current_dir < 0 && prior_dir > 0)
      return -1;
   return 0;
  }

bool IsLocalSwingLow(const int shift)
  {
   if(shift < 3)
      return false;

   const double low_value = H4Low(shift);
   const double older_low = H4Low(shift + 1);
   const double newer_low = H4Low(shift - 1);
   return (low_value > 0.0 && older_low > 0.0 && newer_low > 0.0 &&
           low_value < older_low && low_value <= newer_low);
  }

bool IsLocalSwingHigh(const int shift)
  {
   if(shift < 3)
      return false;

   const double high_value = H4High(shift);
   const double older_high = H4High(shift + 1);
   const double newer_high = H4High(shift - 1);
   return (high_value > 0.0 && older_high > 0.0 && newer_high > 0.0 &&
           high_value > older_high && high_value >= newer_high);
  }

bool FindLong2BPivot(double &anchor_low, double &anchor_close)
  {
   anchor_low = 0.0;
   anchor_close = 0.0;
   const double trigger_close = H4Close(1);
   if(trigger_close <= 0.0 || strategy_2b_lookback < 5)
      return false;

   const int max_a_shift = strategy_2b_lookback + 2;
   for(int a = 3; a <= max_a_shift; ++a)
     {
      if(!IsLocalSwingLow(a))
         continue;

      const double low_a = H4Low(a);
      const double close_a = H4Close(a);
      if(low_a <= 0.0 || close_a <= 0.0 || trigger_close <= close_a)
         continue;

      bool false_break_seen = false;
      for(int b = a - 1; b >= 2; --b)
        {
         const double low_b = H4Low(b);
         if(low_b > 0.0 && low_b < low_a)
           {
            false_break_seen = true;
            break;
           }
        }

      if(false_break_seen)
        {
         anchor_low = low_a;
         anchor_close = close_a;
         return true;
        }
     }

   return false;
  }

bool FindShort2BPivot(double &anchor_high, double &anchor_close)
  {
   anchor_high = 0.0;
   anchor_close = 0.0;
   const double trigger_close = H4Close(1);
   if(trigger_close <= 0.0 || strategy_2b_lookback < 5)
      return false;

   const int max_a_shift = strategy_2b_lookback + 2;
   for(int a = 3; a <= max_a_shift; ++a)
     {
      if(!IsLocalSwingHigh(a))
         continue;

      const double high_a = H4High(a);
      const double close_a = H4Close(a);
      if(high_a <= 0.0 || close_a <= 0.0 || trigger_close >= close_a)
         continue;

      bool false_break_seen = false;
      for(int b = a - 1; b >= 2; --b)
        {
         const double high_b = H4High(b);
         if(high_b > 0.0 && high_b > high_a)
           {
            false_break_seen = true;
            break;
           }
        }

      if(false_break_seen)
        {
         anchor_high = high_a;
         anchor_close = close_a;
         return true;
        }
     }

   return false;
  }

bool RegimeAllowsLong()
  {
   const double d1_close = D1Close(1);
   const double d1_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_regime_sma_period, 1, PRICE_CLOSE);
   return (d1_close > 0.0 && d1_sma > 0.0 && d1_close > d1_sma);
  }

bool RegimeAllowsShort()
  {
   const double d1_close = D1Close(1);
   const double d1_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_regime_sma_period, 1, PRICE_CLOSE);
   return (d1_close > 0.0 && d1_sma > 0.0 && d1_close < d1_sma);
  }

bool BuildEntryRequest(const QM_OrderType side,
                       const double pivot_anchor,
                       const string reason,
                       QM_EntryRequest &req)
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double entry_price = (side == QM_BUY) ? ask : bid;
   if(entry_price <= 0.0)
      entry_price = H4Close(1);
   if(entry_price <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr_value <= 0.0 || pivot_anchor <= 0.0 || strategy_stop_atr_cap_mult <= 0.0)
      return false;

   double stop_price = 0.0;
   if(side == QM_BUY)
     {
      const double atr_cap_stop = entry_price - (atr_value * strategy_stop_atr_cap_mult);
      stop_price = MathMax(pivot_anchor, atr_cap_stop);
      if(stop_price <= 0.0 || stop_price >= entry_price)
         return false;
     }
   else
     {
      const double atr_cap_stop = entry_price + (atr_value * strategy_stop_atr_cap_mult);
      stop_price = MathMin(pivot_anchor, atr_cap_stop);
      if(stop_price <= entry_price)
         return false;
     }

   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopRulesNormalizePrice(_Symbol, stop_price);
   req.tp = 0.0;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H4)
      return true;

   const double atr_value = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(atr_value > 0.0 && strategy_spread_atr_mult > 0.0 &&
      bid > 0.0 && ask > 0.0 && ask > bid &&
      (ask - bid) > (atr_value * strategy_spread_atr_mult))
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_tlb_lines < 2 ||
      strategy_2b_lookback < 5 ||
      strategy_regime_sma_period < 20 ||
      strategy_atr_period < 2)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const int tlb_flip = CurrentTLBFlip();
   if(tlb_flip > 0 && RegimeAllowsLong())
     {
      double anchor_low = 0.0;
      double anchor_close = 0.0;
      if(FindLong2BPivot(anchor_low, anchor_close))
         return BuildEntryRequest(QM_BUY, anchor_low, "tlb_up_2b_regime", req);
     }

   if(tlb_flip < 0 && RegimeAllowsShort())
     {
      double anchor_high = 0.0;
      double anchor_close = 0.0;
      if(FindShort2BPivot(anchor_high, anchor_close))
         return BuildEntryRequest(QM_SELL, anchor_high, "tlb_down_2b_regime", req);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double atr_value = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr_value <= 0.0 || strategy_be_trigger_atr_mult <= 0.0)
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double spread = (bid > 0.0 && ask > 0.0 && ask > bid) ?
                         (ask - bid) :
                         QM_StopRulesPipsToPriceDistance(_Symbol, strategy_be_buffer_pips);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0)
         continue;

      if(position_type == POSITION_TYPE_BUY)
        {
         if(bid <= 0.0 || (bid - open_price) < (atr_value * strategy_be_trigger_atr_mult))
            continue;
         const double target_sl = QM_StopRulesNormalizePrice(_Symbol, open_price + spread);
         if(target_sl > 0.0 && (current_sl <= 0.0 || target_sl > current_sl))
            QM_TM_MoveSL(ticket, target_sl, "sperandeo_be_atr");
        }
      else if(position_type == POSITION_TYPE_SELL)
        {
         if(ask <= 0.0 || (open_price - ask) < (atr_value * strategy_be_trigger_atr_mult))
            continue;
         const double target_sl = QM_StopRulesNormalizePrice(_Symbol, open_price - spread);
         if(target_sl > 0.0 && (current_sl <= 0.0 || target_sl < current_sl))
            QM_TM_MoveSL(ticket, target_sl, "sperandeo_be_atr");
        }
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int period_seconds = PeriodSeconds(PERIOD_H4);
   const int max_hold_seconds = (strategy_time_stop_bars > 0 && period_seconds > 0) ?
                                strategy_time_stop_bars * period_seconds :
                                0;
   const datetime now_time = TimeCurrent();
   const int tlb_flip = CurrentTLBFlip();

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime entry_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(max_hold_seconds > 0 && entry_time > 0 && (now_time - entry_time) >= max_hold_seconds)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
         continue;
        }

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY && tlb_flip < 0)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
         continue;
        }
      if(position_type == POSITION_TYPE_SELL && tlb_flip > 0)
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
