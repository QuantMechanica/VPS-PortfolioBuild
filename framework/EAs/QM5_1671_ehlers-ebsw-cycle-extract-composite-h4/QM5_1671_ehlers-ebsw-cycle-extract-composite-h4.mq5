#property strict
#property version   "5.0"
#property description "QM5_1671 Ehlers EBSW + Cycle-Extraction Composite H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_1671
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1671;
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
input int    strategy_hp_period           = 48;
input int    strategy_lp_period           = 10;
input int    strategy_ebsw_hp_period      = 40;
input int    strategy_ebsw_lp_period      = 10;
input int    strategy_period_min          = 10;
input int    strategy_period_max          = 48;
input double strategy_amplitude_atr_mult  = 0.5;
input int    strategy_d1_sma_period       = 200;
input int    strategy_atr_period          = 14;
input double strategy_sl_amp_mult         = 1.5;
input double strategy_sl_atr_cap_mult     = 3.0;
input double strategy_time_stop_mult      = 1.5;
input double strategy_spread_atr_mult     = 0.3;

// -----------------------------------------------------------------------------
// Cached indicator & cycle state
// -----------------------------------------------------------------------------
bool     g_state_ready                = false;
datetime g_last_state_bar             = 0;
double   g_cycle_amplitude            = 0.0;
double   g_cycle_period_raw           = 0.0;
int      g_cycle_period_display       = 0;
bool     g_cycle_period_valid         = false;
double   g_ebsw_curr                  = 0.0;
double   g_ebsw_prev                  = 0.0;
int      g_amp_collapse_count         = 0;

QM_ExitReason g_strategy_exit_reason  = QM_EXIT_STRATEGY;

// Ehlers' fixed four-element, seven-sample Hilbert FIR (Cybernetic Analysis
// for Stocks and Futures, eq. 9.1).  The four non-zero taps are deliberately
// explicit: changing them changes phase, amplitude and every downstream rule.
bool EhlersHilbert4Tap(const double &signal[], const int shift, double &quadrature)
{
   quadrature = 0.0;
   const int size = ArraySize(signal);
   if(shift < 0 || size < 7 || shift + 6 >= size)
      return false;

   quadrature = 0.0962 * signal[shift]
                + 0.5769 * signal[shift + 2]
                - 0.5769 * signal[shift + 4]
                - 0.0962 * signal[shift + 6];
   return MathIsValidNumber(quadrature);
}

// -----------------------------------------------------------------------------
// State advance (cached once per closed H4 bar)
// -----------------------------------------------------------------------------
bool AdvanceCycleState()
{
   const datetime closed_bar = iTime(_Symbol, PERIOD_H4, 1); // perf-allowed: one cached H4 closed-bar identity read
   if(closed_bar <= 0)
      return false;
   if(g_state_ready && g_last_state_bar == closed_bar)
      return true;

   const int count = 120;
   if(Bars(_Symbol, PERIOD_H4) < count + 10) // perf-allowed: bounded H4 warmup guard, once per closed bar
      return false;

   double close[];
   ArraySetAsSeries(close, true);
   if(CopyClose(_Symbol, PERIOD_H4, 1, count, close) != count) // perf-allowed: cached once per closed H4 bar
      return false;
   if(ArraySize(close) < count)
      return false;

   const double pi = 3.14159265358979323846;

   // 1. Cycle Extraction Roofing Filter (hp=48, lp=10)
   const double hp_angle = 0.707 * 2.0 * pi / (double)MathMax(4, strategy_hp_period);
   const double alpha1 = (MathCos(hp_angle) + MathSin(hp_angle) - 1.0) / MathCos(hp_angle);
   const double hp_a = MathPow(1.0 - alpha1 / 2.0, 2.0);
   const double hp_b = 2.0 * (1.0 - alpha1);
   const double hp_c = -MathPow(1.0 - alpha1, 2.0);

   const double a1 = MathExp(-1.414 * pi / (double)MathMax(3, strategy_lp_period));
   const double b1 = 2.0 * a1 * MathCos(1.414 * pi / (double)MathMax(3, strategy_lp_period));
   const double c2 = b1;
   const double c3 = -a1 * a1;
   const double c1 = 1.0 - c2 - c3;

   double hp[256];
   double filt[256];
   ArrayInitialize(hp, 0.0);
   ArrayInitialize(filt, 0.0);

   for(int i = count - 3; i >= 0; --i)
   {
      hp[i] = hp_a * (close[i] - 2.0 * close[i + 1] + close[i + 2])
              + hp_b * hp[i + 1]
              + hp_c * hp[i + 2];
      filt[i] = c1 * (hp[i] + hp[i + 1]) / 2.0
                + c2 * filt[i + 1]
                + c3 * filt[i + 2];
   }

   // 2. EBSW Roofing Filter (hp=40, lp=10)
   const double ebsw_hp_angle = 0.707 * 2.0 * pi / (double)MathMax(4, strategy_ebsw_hp_period);
   const double ebsw_alpha1 = (MathCos(ebsw_hp_angle) + MathSin(ebsw_hp_angle) - 1.0) / MathCos(ebsw_hp_angle);
   const double ebsw_hp_a = MathPow(1.0 - ebsw_alpha1 / 2.0, 2.0);
   const double ebsw_hp_b = 2.0 * (1.0 - ebsw_alpha1);
   const double ebsw_hp_c = -MathPow(1.0 - ebsw_alpha1, 2.0);

   const double ebsw_a1 = MathExp(-1.414 * pi / (double)MathMax(3, strategy_ebsw_lp_period));
   const double ebsw_b1 = 2.0 * ebsw_a1 * MathCos(1.414 * pi / (double)MathMax(3, strategy_ebsw_lp_period));
   const double ebsw_c2 = ebsw_b1;
   const double ebsw_c3 = -ebsw_a1 * ebsw_a1;
   const double ebsw_c1 = 1.0 - ebsw_c2 - ebsw_c3;

   double ebsw_hp[256];
   double ebsw_filt[256];
   ArrayInitialize(ebsw_hp, 0.0);
   ArrayInitialize(ebsw_filt, 0.0);

   for(int i = count - 3; i >= 0; --i)
   {
      ebsw_hp[i] = ebsw_hp_a * (close[i] - 2.0 * close[i + 1] + close[i + 2])
                   + ebsw_hp_b * ebsw_hp[i + 1]
                   + ebsw_hp_c * ebsw_hp[i + 2];
      ebsw_filt[i] = ebsw_c1 * (ebsw_hp[i] + ebsw_hp[i + 1]) / 2.0
                     + ebsw_c2 * ebsw_filt[i + 1]
                     + ebsw_c3 * ebsw_filt[i + 2];
   }

   // 3. Fixed four-tap Hilbert analytic signal on the cycle extractor.
   // The real component is delayed by the FIR group delay (three bars).
   double quad0 = 0.0;
   double quad1 = 0.0;
   if(!EhlersHilbert4Tap(filt, 0, quad0) || !EhlersHilbert4Tap(filt, 1, quad1))
      return false;
   const double inphase0 = filt[3];
   const double inphase1 = filt[4];
   if(!MathIsValidNumber(inphase0) || !MathIsValidNumber(inphase1))
      return false;

   g_cycle_amplitude = MathSqrt(inphase0 * inphase0 + quad0 * quad0);

   // Phase unwrap for the dominant period.  Invalid or out-of-band raw
   // observations remain invalid; only the display integer is clamped.
   g_cycle_period_raw = 0.0;
   g_cycle_period_display = 0;
   g_cycle_period_valid = false;
   if((MathAbs(inphase0) > DBL_EPSILON || MathAbs(quad0) > DBL_EPSILON) &&
      (MathAbs(inphase1) > DBL_EPSILON || MathAbs(quad1) > DBL_EPSILON))
   {
      const double phase0 = MathArctan2(quad0, inphase0);
      const double phase1 = MathArctan2(quad1, inphase1);
      double delta_phase = phase1 - phase0;
      if(delta_phase <= 0.0)
         delta_phase += 2.0 * pi;
      if(delta_phase > 2.0 * pi)
         delta_phase -= 2.0 * pi;

      if(delta_phase > 0.01)
      {
         const double raw_period = 2.0 * pi / delta_phase;
         if(MathIsValidNumber(raw_period) && raw_period > 0.0)
         {
            g_cycle_period_raw = raw_period;
            g_cycle_period_display = (int)MathRound(raw_period);
            if(g_cycle_period_display < strategy_period_min)
               g_cycle_period_display = strategy_period_min;
            if(g_cycle_period_display > strategy_period_max)
               g_cycle_period_display = strategy_period_max;
            g_cycle_period_valid = (raw_period >= (double)strategy_period_min &&
                                    raw_period <= (double)strategy_period_max);
         }
      }
   }

   // 4. EBSW phase uses the same approved fixed four-tap transform.
   double quad_ebsw0 = 0.0;
   double quad_ebsw1 = 0.0;
   if(!EhlersHilbert4Tap(ebsw_filt, 0, quad_ebsw0) ||
      !EhlersHilbert4Tap(ebsw_filt, 1, quad_ebsw1))
      return false;
   const double inphase_ebsw0 = ebsw_filt[3];
   const double inphase_ebsw1 = ebsw_filt[4];
   if(!MathIsValidNumber(inphase_ebsw0) || !MathIsValidNumber(inphase_ebsw1))
      return false;

   const double ebsw_p0 = (MathAbs(inphase_ebsw0) > DBL_EPSILON || MathAbs(quad_ebsw0) > DBL_EPSILON)
                          ? MathArctan2(quad_ebsw0, inphase_ebsw0) : 0.0;
   const double ebsw_p1 = (MathAbs(inphase_ebsw1) > DBL_EPSILON || MathAbs(quad_ebsw1) > DBL_EPSILON)
                          ? MathArctan2(quad_ebsw1, inphase_ebsw1) : 0.0;

   g_ebsw_curr = MathSin(ebsw_p0);
   g_ebsw_prev = MathSin(ebsw_p1);

   // 5. Rebuild the three-bar amplitude-collapse state from closed data so a
   // news pause or EA restart cannot erase or fabricate the sequence.
   g_amp_collapse_count = 0;
   for(int shift = 0; shift < 3; ++shift)
   {
      double collapse_quad = 0.0;
      if(!EhlersHilbert4Tap(filt, shift, collapse_quad))
         break;
      const double collapse_inphase = filt[shift + 3];
      const double collapse_amp = MathSqrt(collapse_inphase * collapse_inphase +
                                           collapse_quad * collapse_quad);
      const double collapse_atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, shift + 1);
      const double collapse_threshold = strategy_amplitude_atr_mult * collapse_atr;
      if(collapse_atr > 0.0 && collapse_amp < 0.5 * collapse_threshold)
         g_amp_collapse_count++;
      else
         break;
   }

   g_state_ready = true;
   g_last_state_bar = closed_bar;
   return true;
}

// -----------------------------------------------------------------------------
// Spread filter
// -----------------------------------------------------------------------------
bool SpreadAllows(const double atr_val)
{
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;
   const double spread = ask - bid;
   if(spread < DBL_EPSILON)
      return true;
   if(atr_val <= 0.0)
      return true;
   return (spread <= strategy_spread_atr_mult * atr_val);
}

// -----------------------------------------------------------------------------
// Position lookup
// -----------------------------------------------------------------------------
bool SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype, datetime &open_time, double &open_price, double &sl_price)
{
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_time = 0;
   open_price = 0.0;
   sl_price = 0.0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong cand = PositionGetTicket(i);
      if(cand == 0 || !PositionSelectByTicket(cand))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = cand;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl_price = PositionGetDouble(POSITION_SL);
      return true;
   }
   return false;
}

int BarsHeld(const datetime open_time)
{
   if(open_time <= 0)
      return 0;
   const int shift = iBarShift(_Symbol, PERIOD_H4, open_time, false); // perf-allowed: one H4 position-age lookup
   return (shift > 0) ? shift : 0;
}

string Strategy_EntryComment(const int direction, const int entry_period)
{
   return StringFormat("EBSW:P=%d|D=%s", entry_period, (direction > 0) ? "L" : "S");
}

int Strategy_ParseEntryPeriod(const string comment)
{
   const string marker = "EBSW:P=";
   const int marker_pos = StringFind(comment, marker);
   if(marker_pos < 0)
      return 0;
   const int value_start = marker_pos + StringLen(marker);
   int value_end = StringFind(comment, "|", value_start);
   if(value_end < 0)
      value_end = StringLen(comment);
   if(value_end <= value_start)
      return 0;

   const int value = (int)StringToInteger(StringSubstr(comment, value_start,
                                                        value_end - value_start));
   if(value < strategy_period_min || value > strategy_period_max)
      return 0;
   return value;
}

int Strategy_PositionEntryPeriod(const ulong ticket)
{
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return 0;

   int entry_period = Strategy_ParseEntryPeriod(PositionGetString(POSITION_COMMENT));
   if(entry_period > 0)
      return entry_period;

   // Broker position comments can be truncated.  The position identifier binds
   // the immutable accepted entry deal and survives terminal/EA restarts.
   const long position_id = PositionGetInteger(POSITION_IDENTIFIER);
   if(position_id <= 0 || !HistorySelectByPosition((ulong)position_id))
      return 0;

   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
   {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_INOUT)
         continue;
      entry_period = Strategy_ParseEntryPeriod(HistoryDealGetString(deal, DEAL_COMMENT));
      if(entry_period > 0)
         return entry_period;
   }
   return 0;
}

bool Strategy_InDirectionCooldown(const int direction)
{
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int h4_seconds = PeriodSeconds(PERIOD_H4);
   if(magic <= 0 || now <= 0 || h4_seconds <= 0)
      return true;

   // Full max-period lookback is twice the required 0.5-period cooldown and
   // keeps the history scan bounded on every new H4 entry evaluation.
   const int lookback_bars = MathMax(strategy_period_max, strategy_period_min) + 4;
   const datetime since = now - (datetime)(lookback_bars * h4_seconds);
   if(!HistorySelect(since, now))
      return true;

   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
   {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;

      const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_INOUT)
         continue;
      const ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal, DEAL_TYPE);
      if((direction > 0 && deal_type != DEAL_TYPE_BUY) ||
         (direction < 0 && deal_type != DEAL_TYPE_SELL))
         continue;

      int accepted_period = Strategy_ParseEntryPeriod(HistoryDealGetString(deal, DEAL_COMMENT));
      if(accepted_period <= 0)
         accepted_period = strategy_period_max; // fail closed for a recent legacy entry
      const int cooldown_bars = MathMax(2, (int)MathRound(0.5 * accepted_period));
      const datetime accepted_at = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      const int bars_since = iBarShift(_Symbol, PERIOD_H4, accepted_at, false); // perf-allowed: newest accepted-entry cooldown lookup
      return (bars_since >= 0 && bars_since < cooldown_bars);
   }
   return false;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(!AdvanceCycleState())
      return true;
   const double atr_val = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(!SpreadAllows(atr_val))
      return true;
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   ZeroMemory(req);

   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   datetime open_time = 0;
   double open_price = 0.0;
   double sl_price = 0.0;
   if(SelectOurPosition(ticket, ptype, open_time, open_price, sl_price))
      return false;

   if(!AdvanceCycleState())
      return false;

   const double atr_h4 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double amp_thresh = strategy_amplitude_atr_mult * atr_h4;

   const bool amplitude_ok = (g_cycle_amplitude > amp_thresh);
   const bool period_ok = (g_cycle_period_valid &&
                           g_cycle_period_raw >= (double)strategy_period_min &&
                           g_cycle_period_raw <= (double)strategy_period_max);
   if(!amplitude_ok || !period_ok)
      return false;

   const double d1_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 1);
   const double close_d1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: one closed-D1 regime read per H4 entry evaluation
   if(d1_sma <= 0.0 || close_d1 <= 0.0)
      return false;

   const bool d1_trend_long = (close_d1 > d1_sma);
   const bool d1_trend_short = (close_d1 < d1_sma);

   // EBSW zero crossings
   const bool ebsw_cross_up = (g_ebsw_prev < 0.0 && g_ebsw_curr >= 0.0);
   const bool ebsw_cross_down = (g_ebsw_prev > 0.0 && g_ebsw_curr <= 0.0);

   if(ebsw_cross_up && d1_trend_long)
   {
      if(Strategy_InDirectionCooldown(1))
         return false;

      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0)
         return false;

      const double sl_dist = MathMin(strategy_sl_amp_mult * g_cycle_amplitude, strategy_sl_atr_cap_mult * atr_h4);
      const double sl_target = QM_StopRulesNormalizePrice(_Symbol, ask - sl_dist);

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl_target;
      req.tp = 0.0;
      req.reason = Strategy_EntryComment(1, g_cycle_period_display);
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }
   else if(ebsw_cross_down && d1_trend_short)
   {
      if(Strategy_InDirectionCooldown(-1))
         return false;

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         return false;

      const double sl_dist = MathMin(strategy_sl_amp_mult * g_cycle_amplitude, strategy_sl_atr_cap_mult * atr_h4);
      const double sl_target = QM_StopRulesNormalizePrice(_Symbol, bid + sl_dist);

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl_target;
      req.tp = 0.0;
      req.reason = Strategy_EntryComment(-1, g_cycle_period_display);
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   datetime open_time = 0;
   double open_price = 0.0;
   double sl_price = 0.0;
   if(!SelectOurPosition(ticket, ptype, open_time, open_price, sl_price))
      return;

   if(!AdvanceCycleState())
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return;

   const double amp = MathMax(g_cycle_amplitude, 10.0 * SymbolInfoDouble(_Symbol, SYMBOL_POINT));
   const double be_trigger = 1.0 * amp;
   const double trail_trigger = 2.0 * amp;

   if(ptype == POSITION_TYPE_BUY)
   {
      const double profit_pts = bid - open_price;
      if(profit_pts >= trail_trigger)
      {
         const double new_sl = QM_StopRulesNormalizePrice(_Symbol, bid - amp);
         if(new_sl > sl_price + SymbolInfoDouble(_Symbol, SYMBOL_POINT))
            QM_TM_MoveSL(ticket, new_sl, "Trail 1.0x cycle amplitude");
      }
      else if(profit_pts >= be_trigger)
      {
         const double spread = ask - bid;
         const double be_sl = QM_StopRulesNormalizePrice(_Symbol, open_price + spread);
         if(be_sl > sl_price + SymbolInfoDouble(_Symbol, SYMBOL_POINT))
            QM_TM_MoveSL(ticket, be_sl, "Break-even at 1.0x cycle amplitude");
      }
   }
   else
   {
      const double profit_pts = open_price - ask;
      if(profit_pts >= trail_trigger)
      {
         const double new_sl = QM_StopRulesNormalizePrice(_Symbol, ask + amp);
         if(sl_price <= 0.0 || new_sl < sl_price - SymbolInfoDouble(_Symbol, SYMBOL_POINT))
            QM_TM_MoveSL(ticket, new_sl, "Trail 1.0x cycle amplitude");
      }
      else if(profit_pts >= be_trigger)
      {
         const double spread = ask - bid;
         const double be_sl = QM_StopRulesNormalizePrice(_Symbol, open_price - spread);
         if(sl_price <= 0.0 || be_sl < sl_price - SymbolInfoDouble(_Symbol, SYMBOL_POINT))
            QM_TM_MoveSL(ticket, be_sl, "Break-even at 1.0x cycle amplitude");
      }
   }
}

bool Strategy_ExitSignal()
{
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   datetime open_time = 0;
   double open_price = 0.0;
   double sl_price = 0.0;
   if(!SelectOurPosition(ticket, ptype, open_time, open_price, sl_price))
      return false;

   if(!AdvanceCycleState())
      return false;

   // 1. Time stop is sealed to the immutable accepted-entry period.  Missing
   // provenance is fail-closed rather than silently substituting live state.
   const int entry_period = Strategy_PositionEntryPeriod(ticket);
   if(entry_period <= 0)
   {
      g_strategy_exit_reason = QM_EXIT_TIME_STOP;
      return true;
   }
   const int max_bars = MathMax(1, (int)MathRound(strategy_time_stop_mult * entry_period));
   if(BarsHeld(open_time) >= max_bars)
   {
      g_strategy_exit_reason = QM_EXIT_TIME_STOP;
      return true;
   }

   // 2. Amplitude collapse: 3 consecutive bars below 0.5 * threshold
   if(g_amp_collapse_count >= 3)
   {
      g_strategy_exit_reason = QM_EXIT_STRATEGY;
      return true;
   }

   // 3. Macro trend reversal
   const double d1_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 1);
   const double close_d1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: one closed-D1 exit regime read per tick

   if(ptype == POSITION_TYPE_BUY)
   {
      // EBSW phase exit: cross below 0 or extreme cycle peak > 0.95
      if((g_ebsw_prev > 0.0 && g_ebsw_curr <= 0.0) || g_ebsw_curr > 0.95)
      {
         g_strategy_exit_reason = QM_EXIT_STRATEGY;
         return true;
      }
      if(d1_sma > 0.0 && close_d1 > 0.0 && close_d1 < d1_sma)
      {
         g_strategy_exit_reason = QM_EXIT_REGIME;
         return true;
      }
   }
   else
   {
      // EBSW phase exit: cross above 0 or extreme cycle peak < -0.95
      if((g_ebsw_prev < 0.0 && g_ebsw_curr >= 0.0) || g_ebsw_curr < -0.95)
      {
         g_strategy_exit_reason = QM_EXIT_STRATEGY;
         return true;
      }
      if(d1_sma > 0.0 && close_d1 > 0.0 && close_d1 > d1_sma)
      {
         g_strategy_exit_reason = QM_EXIT_REGIME;
         return true;
      }
   }

   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(_Period != PERIOD_H4)
   {
      Print("QM5_1671 requires an H4 chart; initialization refused");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(strategy_hp_period < 4 || strategy_lp_period < 3 ||
      strategy_ebsw_hp_period < 4 || strategy_ebsw_lp_period < 3 ||
      strategy_period_min < 2 || strategy_period_max < strategy_period_min ||
      strategy_amplitude_atr_mult <= 0.0 || strategy_d1_sma_period < 2 ||
      strategy_atr_period < 2 || strategy_sl_amp_mult <= 0.0 ||
      strategy_sl_atr_cap_mult <= 0.0 || strategy_time_stop_mult <= 0.0 ||
      strategy_spread_atr_mult < 0.0)
   {
      Print("QM5_1671 invalid strategy input contract");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck()) return;

   // Friday, position management, strategy exits and closed-bar exit state are
   // never suppressed by an entry-only news blackout.
   if(QM_FrameworkHandleFridayClose()) return;
   const bool cycle_state_ready = AdvanceCycleState();
   if(cycle_state_ready)
   {
      Strategy_ManageOpenPosition();

      if(Strategy_ExitSignal())
      {
         const int magic = QM_FrameworkMagic();
         for(int i = PositionsTotal() - 1; i >= 0; --i)
         {
            const ulong ticket = PositionGetTicket(i);
            if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
            if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            QM_TM_ClosePosition(ticket, g_strategy_exit_reason);
         }
      }
   }

   if(!QM_IsNewBar(_Symbol, PERIOD_H4)) return;
   QM_EquityStreamOnNewBar();
   if(!cycle_state_ready) return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   if(Strategy_NoTradeFilter()) return;

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      if(QM_TM_OpenPosition(req, out_ticket))
         PrintFormat("QM5_1671 accepted entry ticket=%I64u provenance=%s", out_ticket, req.reason);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}

