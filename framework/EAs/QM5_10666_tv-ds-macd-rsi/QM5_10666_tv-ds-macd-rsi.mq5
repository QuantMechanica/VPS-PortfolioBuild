#property strict
#property version   "5.0"
#property description "QM5_10666 tv-ds-macd-rsi — TradingView Demand/Supply zone + MACD histogram + RSI/EMA200 confirmation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10666 tv-ds-macd-rsi
// -----------------------------------------------------------------------------
// Card: artifacts/cards_approved/QM5_10666_tv-ds-macd-rsi.md (g0_status APPROVED)
// Source: TradingView "RSI & MACD + D/S Zones" (abishek_philip24).
//
// Mechanics (mechanical reading of the card):
//   - Supply/Demand zones from a low-volatility "boring" base candle followed by
//     a high-volatility "explosive" candle. P2 fallback definitions:
//       boring    : body <= boring_body_atr_mult * ATR(14)
//       explosive : range >= explosive_range_atr_mult * ATR(14)
//     A bullish explosive (close>open) creates a DEMAND zone spanning the boring
//     candle [low..high]; a bearish explosive creates a SUPPLY zone.
//   - Zone is maintained dynamically: shrunk when a wick consumes part of it,
//     invalidated when a closed bar pierces fully through it.
//   - EMA(200) trend filter, RSI safe-range gate, MACD histogram 2-bar momentum.
//   - Long  : closed bar touches active demand zone, close>EMA200, RSI in [lo,hi],
//             MACD histogram bullish & rising 2 consecutive bars (the TRIGGER).
//   - Short : closed bar touches active supply zone, close<EMA200, RSI in [lo,hi],
//             MACD histogram bearish & falling 2 consecutive bars (the TRIGGER).
//   - Stop  : below demand-zone low (long) / above supply-zone high (short)
//             plus stop_atr_buffer_mult * ATR(14).
//   - Take  : fixed RR (1.5R) via QM_TakeRR.
//   - Exit  : opposite-zone break / EMA200 cross against trade / 36-bar time stop.
//
// .DWX invariants respected:
//   - MACD histogram cross is the single fresh TRIGGER; RSI/EMA200 are STATES.
//   - No degenerate periods; spread guard fails OPEN on zero spread (none used).
//   - Closed-bar reads only (shift>=1); zone state cached per new closed bar.
//   - QM_IsNewBar() consumed exactly ONCE per tick (in OnTick, framework-wired).
//   - Single bounded CopyRates per new bar inside the closed-bar gate.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10666;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// --- Trend / momentum confirmation ---
input int    ema_trend_period           = 200;   // EMA(200) directional gate
input int    rsi_period                 = 14;    // RSI confirmation period
input double rsi_safe_lo                = 35.0;  // RSI safe-range lower bound
input double rsi_safe_hi                = 65.0;  // RSI safe-range upper bound
input int    macd_fast                  = 12;    // MACD fast EMA
input int    macd_slow                  = 26;    // MACD slow EMA
input int    macd_signal                = 9;     // MACD signal EMA (histogram = main-signal)
// --- Zone construction ---
input int    atr_period                 = 14;    // ATR for boring/explosive + stop buffer
input double boring_body_atr_mult       = 0.5;   // boring body <= this * ATR(14)
input double explosive_range_atr_mult   = 1.25;  // explosive range >= this * ATR(14)
input int    zone_max_age_bars          = 60;    // discard zones older than this (bars)
// --- Stop / target / exit ---
input double stop_atr_buffer_mult       = 0.25;  // ATR buffer beyond zone edge
input double take_rr                    = 1.5;   // fixed RR target (1.5R)
input int    time_stop_bars             = 36;    // exit if no TP/SL/reversal by N bars

// -----------------------------------------------------------------------------
// File-scope cached zone state (advanced ONCE per closed bar)
// -----------------------------------------------------------------------------
// Active zone: type, price band, and the bar-time it was formed on.
// zone_type: 0 = none, +1 = demand (long bias), -1 = supply (short bias)
int      g_zone_type        = 0;
double   g_zone_low         = 0.0;   // lower edge of active zone (price)
double   g_zone_high        = 0.0;   // upper edge of active zone (price)
datetime g_zone_formed_time = 0;     // bar-open time the zone formed on

// Entry book-keeping for the time stop (bars elapsed since entry).
datetime g_entry_bar_time   = 0;     // bar-open time of the bar we entered on

// -----------------------------------------------------------------------------
// Zone maintenance — runs once per new closed bar (called from EntrySignal,
// which the framework only invokes after QM_IsNewBar()==true). Reads the last
// closed bars at fixed shifts; one bounded CopyRates for the boring/explosive
// pair. No unbounded history scan.
// -----------------------------------------------------------------------------
void AdvanceZoneState_OnNewBar()
  {
   const string sym = _Symbol;
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;

   // Pull the last 3 closed bars: shift 1 (most recent closed), 2 (explosive
   // candidate), 3 (boring candidate). MqlRates is time-series indexed when
   // ArraySetAsSeries(true): index 0 == shift 1 here because we start at pos 1.
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(sym, tf, 1, 3, rates) != 3)
      return;

   const double atr = QM_ATR(sym, tf, atr_period, 1);
   if(atr <= 0.0)
      return;

   // rates[0] = shift1 (most recent closed), rates[1] = shift2, rates[2] = shift3.
   // Zone forms from a boring base (shift3) followed by an explosive (shift2).
   const double boring_open  = rates[2].open;
   const double boring_close = rates[2].close;
   const double boring_high  = rates[2].high;
   const double boring_low   = rates[2].low;
   const double boring_body  = MathAbs(boring_close - boring_open);

   const double exp_open  = rates[1].open;
   const double exp_close = rates[1].close;
   const double exp_range = rates[1].high - rates[1].low;

   const bool is_boring    = (boring_body <= boring_body_atr_mult * atr);
   const bool is_explosive = (exp_range >= explosive_range_atr_mult * atr);

   // Form a fresh zone when the boring->explosive pair qualifies. The explosive
   // direction sets the zone polarity; the zone band is the boring candle range.
   if(is_boring && is_explosive)
     {
      if(exp_close > exp_open)
        {
         g_zone_type        = +1;            // bullish explosive -> demand zone
         g_zone_low         = boring_low;
         g_zone_high        = boring_high;
         g_zone_formed_time = rates[1].time; // formed on the explosive bar
        }
      else if(exp_close < exp_open)
        {
         g_zone_type        = -1;            // bearish explosive -> supply zone
         g_zone_low         = boring_low;
         g_zone_high        = boring_high;
         g_zone_formed_time = rates[1].time;
        }
     }

   if(g_zone_type == 0)
      return;

   // --- Maintain the active zone using the most recent closed bar (shift1). ---
   const double last_high  = rates[0].high;
   const double last_low   = rates[0].low;
   const double last_close = rates[0].close;

   // Shrink the zone when a wick consumes part of it (the zone yields toward the
   // penetrating side but stays valid as long as a closed price remains beyond).
   if(g_zone_type == +1)
     {
      // Demand zone: a dip wick into the zone consumes from the top down.
      if(last_low < g_zone_high && last_low > g_zone_low)
         g_zone_high = MathMax(g_zone_low, MathMin(g_zone_high, last_low));
      // Full break: a closed bar below the zone low invalidates the demand zone.
      if(last_close < g_zone_low)
         g_zone_type = 0;
     }
   else // g_zone_type == -1 (supply)
     {
      if(last_high > g_zone_low && last_high < g_zone_high)
         g_zone_low = MathMin(g_zone_high, MathMax(g_zone_low, last_high));
      if(last_close > g_zone_high)
         g_zone_type = 0;
     }

   // Age-out stale zones so price can't "touch" a zone from months ago.
   if(g_zone_type != 0 && zone_max_age_bars > 0)
     {
      const datetime now_bar = iTime(sym, tf, 1);
      const int sec_per_bar  = PeriodSeconds(tf);
      if(sec_per_bar > 0 && now_bar > 0 && g_zone_formed_time > 0)
        {
         const int age_bars = (int)((now_bar - g_zone_formed_time) / sec_per_bar);
         if(age_bars > zone_max_age_bars)
            g_zone_type = 0;
        }
     }
  }

// -----------------------------------------------------------------------------
// MACD histogram helpers — histogram = MACD main - signal at a given closed shift.
// -----------------------------------------------------------------------------
double MacdHist(const int shift)
  {
   const string sym = _Symbol;
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double main_v   = QM_MACD_Main(sym, tf, macd_fast, macd_slow, macd_signal, shift);
   const double signal_v = QM_MACD_Signal(sym, tf, macd_fast, macd_slow, macd_signal, shift);
   return main_v - signal_v;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// O(1) per-tick filter only. Zone work happens in EntrySignal (new-bar gated).
bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One entry per symbol/magic — never stack.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const string sym = _Symbol;
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;

   // Advance cached zone state once for this new closed bar.
   AdvanceZoneState_OnNewBar();
   if(g_zone_type == 0)
      return false;

   // Confirming STATES (read on the last closed bar, shift 1).
   const double close1 = iClose(sym, tf, 1);
   if(close1 <= 0.0)
      return false;
   const double ema    = QM_EMA(sym, tf, ema_trend_period, 1);
   const double rsi    = QM_RSI(sym, tf, rsi_period, 1);
   if(ema <= 0.0 || rsi <= 0.0)
      return false;
   const bool rsi_in_band = (rsi >= rsi_safe_lo && rsi <= rsi_safe_hi);

   // MACD histogram momentum across the last two closed bars.
   const double hist1 = MacdHist(1);
   const double hist2 = MacdHist(2);
   const double hist3 = MacdHist(3);

   const double atr = QM_ATR(sym, tf, atr_period, 1);
   if(atr <= 0.0)
      return false;
   const double buffer = stop_atr_buffer_mult * atr;

   // Did the most recent closed bar TOUCH the active zone band?
   const double low1  = iLow(sym, tf, 1);
   const double high1 = iHigh(sym, tf, 1);

   // --- LONG: demand zone touch + close>EMA200 + RSI band + MACD hist bullish
   //     and rising for two consecutive bars (the TRIGGER). ---
   if(g_zone_type == +1)
     {
      const bool touched   = (low1 <= g_zone_high && high1 >= g_zone_low);
      const bool above_ema = (close1 > ema);
      // Histogram bullish & rising two bars: hist1>hist2>hist3 and hist1>0.
      const bool macd_ok   = (hist1 > 0.0 && hist1 > hist2 && hist2 > hist3);
      if(touched && above_ema && rsi_in_band && macd_ok)
        {
         const double entry = SymbolInfoDouble(sym, SYMBOL_ASK);
         double sl = g_zone_low - buffer;
         sl = QM_StopRulesNormalizePrice(sym, sl);
         if(sl <= 0.0 || sl >= entry)
            return false;
         req.type   = QM_BUY;
         req.price  = 0.0;                 // market fill
         req.sl     = sl;
         req.tp     = QM_TakeRR(sym, QM_BUY, entry, sl, take_rr);
         req.reason = "ds_demand_macd_long";
         g_entry_bar_time = iTime(sym, tf, 0);
         return true;
        }
     }
   // --- SHORT: supply zone touch + close<EMA200 + RSI band + MACD hist bearish
   //     and falling for two consecutive bars (the TRIGGER). ---
   else if(g_zone_type == -1)
     {
      const bool touched   = (high1 >= g_zone_low && low1 <= g_zone_high);
      const bool below_ema = (close1 < ema);
      const bool macd_ok   = (hist1 < 0.0 && hist1 < hist2 && hist2 < hist3);
      if(touched && below_ema && rsi_in_band && macd_ok)
        {
         const double entry = SymbolInfoDouble(sym, SYMBOL_BID);
         double sl = g_zone_high + buffer;
         sl = QM_StopRulesNormalizePrice(sym, sl);
         if(sl <= 0.0 || sl <= entry)
            return false;
         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = sl;
         req.tp     = QM_TakeRR(sym, QM_SELL, entry, sl, take_rr);
         req.reason = "ds_supply_macd_short";
         g_entry_bar_time = iTime(sym, tf, 0);
         return true;
        }
     }

   return false;
  }

// No active SL/TP modification — fixed bracket from entry. (Trade management is
// the fixed-RR target + structural stop set at entry.)
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: opposite-side zone break, EMA200 cross against the trade,
// or 36-bar time stop. Evaluated per tick but reads closed-bar values only.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const string sym = _Symbol;
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;

   // Resolve the open position's direction for this magic.
   bool is_long = false;
   bool found   = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != sym)
         continue;
      is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      found   = true;
      break;
     }
   if(!found)
      return false;

   const double close1 = iClose(sym, tf, 1);
   const double ema    = QM_EMA(sym, tf, ema_trend_period, 1);
   if(close1 <= 0.0 || ema <= 0.0)
      return false;

   // EMA200 cross against the trade.
   if(is_long && close1 < ema)
      return true;
   if(!is_long && close1 > ema)
      return true;

   // Opposite-side zone break: a flipped active zone against the position.
   if(g_zone_type != 0)
     {
      if(is_long && g_zone_type == -1)
         return true;
      if(!is_long && g_zone_type == +1)
         return true;
     }

   // 36-bar time stop.
   if(time_stop_bars > 0 && g_entry_bar_time > 0)
     {
      const datetime now_bar = iTime(sym, tf, 0);
      const int sec_per_bar  = PeriodSeconds(tf);
      if(sec_per_bar > 0 && now_bar > 0)
        {
         const int held_bars = (int)((now_bar - g_entry_bar_time) / sec_per_bar);
         if(held_bars >= time_stop_bars)
            return true;
        }
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line.
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
