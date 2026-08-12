#property strict
#property version   "5.0"
#property description "QM5_10629 Elite Trader Order Block BOS Imbalance Retest"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10629;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_FTMO;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;
// Transitional compatibility for the committed baseline setfiles.  -1 means
// "use the canonical two-axis inputs above"; old sets explicitly provide 3.
input bool   qm_filter_news_enabled       = true;
input int    qm_filter_news_mode          = -1;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_fractal_width       = 3;
input int    strategy_atr_period          = 14;
input double strategy_sweep_atr_mult      = 0.25;
input int    strategy_bos_max_bars        = 12;
input double strategy_bos_body_atr_mult   = 0.75;
input double strategy_ob_entry_fraction   = 0.50;
input double strategy_ob_max_atr_mult     = 1.50;
input double strategy_sl_atr_buffer_mult  = 0.20;
input double strategy_rr_target           = 2.00;
input int    strategy_pending_bars        = 10;
input int    strategy_time_exit_bars      = 36;
input int    strategy_structure_lookback  = 80;
// Execution-safety guard, not an alpha parameter.  The 0.20 default is bound
// to the card's existing 0.20*ATR stop-buffer scale rather than symbol points.
input double strategy_max_spread_atr_fraction = 0.20;

struct Strategy_SetupSnapshot
  {
   bool     valid;
   bool     for_long;
   datetime sweep_stamp;
   datetime bos_stamp;
   datetime ob_stamp;
   double   sweep_extreme;
   double   break_level;
   double   ob_low;
   double   ob_high;
   double   opposing_liquidity;
   int      bos_shift;
  };

QM_NewsTemporalMode       g_strategy_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
QM_NewsComplianceProfile  g_strategy_news_compliance = QM_NEWS_COMPLIANCE_FTMO;
QM_NewsMode                g_strategy_news_legacy     = QM_NEWS_OFF;
bool                       g_pending_remove_retry     = false;
string                     g_pending_remove_reason    = "";
bool                       g_position_close_retry     = false;
string                     g_position_close_reason    = "";

// perf-allowed: bespoke 3-left/3-right structure logic, called only from the
// framework-gated Strategy_EntrySignal() path once per completed H1 bar.
double BarOpen(const int shift)  { return iOpen(_Symbol, PERIOD_H1, shift); }   // perf-allowed
double BarHigh(const int shift)  { return iHigh(_Symbol, PERIOD_H1, shift); }   // perf-allowed
double BarLow(const int shift)   { return iLow(_Symbol, PERIOD_H1, shift); }    // perf-allowed
double BarClose(const int shift) { return iClose(_Symbol, PERIOD_H1, shift); }  // perf-allowed
datetime BarStamp(const int shift) { return iTime(_Symbol, PERIOD_H1, shift); } // perf-allowed

void Strategy_ResetSetup(Strategy_SetupSnapshot &setup)
  {
   setup.valid = false;
   setup.for_long = false;
   setup.sweep_stamp = 0;
   setup.bos_stamp = 0;
   setup.ob_stamp = 0;
   setup.sweep_extreme = 0.0;
   setup.break_level = 0.0;
   setup.ob_low = 0.0;
   setup.ob_high = 0.0;
   setup.opposing_liquidity = 0.0;
   setup.bos_shift = 0;
  }

bool Strategy_ResolveNewsConfig()
  {
   g_strategy_news_legacy = QM_NEWS_OFF;
   if(!qm_filter_news_enabled)
     {
      g_strategy_news_temporal = QM_NEWS_TEMPORAL_OFF;
      g_strategy_news_compliance = QM_NEWS_COMPLIANCE_NONE;
      return true;
     }

   if(qm_filter_news_mode >= 0)
     {
      if(qm_filter_news_mode > (int)QM_NEWS_NEWS_ONLY)
         return false;
      const QM_NewsMode compatibility_mode = (QM_NewsMode)qm_filter_news_mode;
      g_strategy_news_temporal = QM_NewsLegacyTemporal(compatibility_mode);
      g_strategy_news_compliance = QM_NewsLegacyCompliance(compatibility_mode);
      return QM_NewsAxesAreValid(g_strategy_news_temporal,
                                 g_strategy_news_compliance);
     }

   g_strategy_news_temporal = qm_news_temporal;
   g_strategy_news_compliance = qm_news_compliance;
   if(qm_news_mode_legacy != QM_NEWS_OFF)
     {
      g_strategy_news_temporal = QM_NewsLegacyTemporal(qm_news_mode_legacy);
      g_strategy_news_compliance = QM_NewsLegacyCompliance(qm_news_mode_legacy);
     }
   return QM_NewsAxesAreValid(g_strategy_news_temporal,
                              g_strategy_news_compliance);
  }

bool Strategy_IsSwingHigh(const int shift, const int width)
  {
   if(shift <= width)
      return false;
   const double center = BarHigh(shift);
   if(center <= 0.0)
      return false;

   for(int offset = 1; offset <= width; ++offset)
     {
      if(BarHigh(shift - offset) >= center)
         return false;
      if(BarHigh(shift + offset) >= center)
         return false;
     }
   return true;
  }

bool Strategy_IsSwingLow(const int shift, const int width)
  {
   if(shift <= width)
      return false;
   const double center = BarLow(shift);
   if(center <= 0.0)
      return false;

   for(int offset = 1; offset <= width; ++offset)
     {
      if(BarLow(shift - offset) <= center)
         return false;
      if(BarLow(shift + offset) <= center)
         return false;
     }
   return true;
  }

bool Strategy_FindRecentSwingAtEvent(const bool want_high,
                                     const int event_shift,
                                     double &price,
                                     datetime &stamp)
  {
   price = 0.0;
   stamp = 0;
   const int width = MathMax(1, strategy_fractal_width);
   // The full right wing must have closed strictly before the event bar.  A
   // historical scan may therefore never use event_shift itself to confirm a
   // swing; doing so would leak future information into the frozen level.
   const int first_shift = event_shift + width + 1;
   const int max_shift = event_shift + MathMax(strategy_structure_lookback,
                                                width * 2 + 3);
   for(int shift = first_shift; shift <= max_shift; ++shift)
     {
      const bool ok = want_high ? Strategy_IsSwingHigh(shift, width)
                                : Strategy_IsSwingLow(shift, width);
      if(!ok)
         continue;
      price = want_high ? BarHigh(shift) : BarLow(shift);
      stamp = BarStamp(shift);
      return (price > 0.0 && stamp > 0);
     }
   return false;
  }

double Strategy_NearestOpposingSwing(const bool for_long,
                                     const double entry_price,
                                     const int event_shift)
  {
   double best = 0.0;
   const int width = MathMax(1, strategy_fractal_width);
   const int first_shift = event_shift + width + 1;
   const int max_shift = event_shift + MathMax(strategy_structure_lookback,
                                                width * 2 + 3);
   for(int shift = first_shift; shift <= max_shift; ++shift)
     {
      if(for_long)
        {
         if(!Strategy_IsSwingHigh(shift, width))
            continue;
         const double level = BarHigh(shift);
         if(level > entry_price && (best <= 0.0 || level < best))
            best = level;
        }
      else
        {
         if(!Strategy_IsSwingLow(shift, width))
            continue;
         const double level = BarLow(shift);
         if(level > 0.0 && level < entry_price && (best <= 0.0 || level > best))
            best = level;
        }
     }
   return best;
  }

bool Strategy_FindOrderBlockBeforeBOS(const bool for_long,
                             const int bos_shift,
                             double &ob_low,
                             double &ob_high,
                             datetime &ob_stamp)
  {
   ob_low = 0.0;
   ob_high = 0.0;
   ob_stamp = 0;
   const int max_scan_shift = bos_shift + MathMax(strategy_structure_lookback, 2);
   // Only candles older than the BOS bar are eligible.  The first matching
   // candle is the last opposite candle known when the BOS closed.
   for(int shift = bos_shift + 1; shift <= max_scan_shift; ++shift)
     {
      const double open = BarOpen(shift);
      const double close = BarClose(shift);
      if(open <= 0.0 || close <= 0.0)
         continue;

      const bool candle_matches = for_long ? (close < open) : (close > open);
      if(!candle_matches)
         continue;

      ob_low = BarLow(shift);
      ob_high = BarHigh(shift);
      ob_stamp = BarStamp(shift);
      return (ob_low > 0.0 && ob_high > ob_low && ob_stamp > 0);
     }
   return false;
  }

double Strategy_TickSize()
  {
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0)
      tick_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return tick_size;
  }

double Strategy_NormalizeNearestTick(const double price)
  {
   const double tick_size = Strategy_TickSize();
   if(tick_size <= 0.0 || price <= 0.0)
      return 0.0;
   return NormalizeDouble(MathRound(price / tick_size) * tick_size, _Digits);
  }

double Strategy_NormalizeDownTick(const double price)
  {
   const double tick_size = Strategy_TickSize();
   if(tick_size <= 0.0 || price <= 0.0)
      return 0.0;
   return NormalizeDouble(MathFloor(price / tick_size) * tick_size, _Digits);
  }

double Strategy_NormalizeUpTick(const double price)
  {
   const double tick_size = Strategy_TickSize();
   if(tick_size <= 0.0 || price <= 0.0)
      return 0.0;
   return NormalizeDouble(MathCeil(price / tick_size) * tick_size, _Digits);
  }

bool Strategy_SpreadAllowed()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(strategy_max_spread_atr_fraction <= 0.0 || atr <= 0.0 ||
      ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;
   return ((ask - bid) <= atr * strategy_max_spread_atr_fraction);
  }

bool Strategy_HasOurPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_HasOurWorkingOrder()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

long Strategy_ZoneFingerprint(const Strategy_SetupSnapshot &setup)
  {
   const double tick_size = Strategy_TickSize();
   if(tick_size <= 0.0 || setup.ob_low <= 0.0 || setup.ob_high <= setup.ob_low)
      return -1;
   const long low_ticks = (long)MathRound(setup.ob_low / tick_size);
   const long high_ticks = (long)MathRound(setup.ob_high / tick_size);
   long fingerprint = (low_ticks * 1000003 + high_ticks * 9176) % 1000000007;
   if(fingerprint < 0)
      fingerprint = -fingerprint;
   return fingerprint;
  }

string Strategy_SetupId(const Strategy_SetupSnapshot &setup)
  {
   const long zone_fingerprint = Strategy_ZoneFingerprint(setup);
   if(setup.ob_stamp <= 0 || zone_fingerprint < 0)
      return "";
   if(setup.for_long)
      return StringFormat("Q10629L_%I64d_%I64d", (long)setup.ob_stamp, zone_fingerprint);
   return StringFormat("Q10629S_%I64d_%I64d", (long)setup.ob_stamp, zone_fingerprint);
  }

bool Strategy_SetupPreviouslyUsed(const Strategy_SetupSnapshot &setup,
                                  bool &history_ready)
  {
   history_ready = false;
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   if(magic <= 0 || now <= 0 || setup.ob_stamp <= 0)
      return false;

   const string setup_id = Strategy_SetupId(setup);
   if(StringLen(setup_id) <= 0 || StringLen(setup_id) > 31)
      return false;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_COMMENT) == setup_id)
        {
         history_ready = true;
         return true;
        }
     }

   datetime history_from = setup.ob_stamp - 86400;
   if(history_from < 0)
      history_from = 0;
   if(!HistorySelect(history_from, now))
      return false;
   history_ready = true;

   const int total_orders = HistoryOrdersTotal();
   for(int i = 0; i < total_orders; ++i)
     {
      const ulong ticket = HistoryOrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(HistoryOrderGetString(ticket, ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryOrderGetInteger(ticket, ORDER_MAGIC) != magic)
         continue;
      if(HistoryOrderGetString(ticket, ORDER_COMMENT) == setup_id)
         return true;
     }

   // Some brokers rewrite the historical order comment but preserve it on the
   // opening deal.  Check both ledgers before declaring a setup unused.
   const int total_deals = HistoryDealsTotal();
   for(int i = 0; i < total_deals; ++i)
     {
      const ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic)
         continue;
      if(HistoryDealGetString(ticket, DEAL_COMMENT) == setup_id)
         return true;
     }

   return false;
  }

bool Strategy_FreezeSetupForBOS(const bool for_long,
                                const int bos_shift,
                                Strategy_SetupSnapshot &setup)
  {
   Strategy_ResetSetup(setup);
   const datetime bos_stamp = BarStamp(bos_shift);
   const double bos_open = BarOpen(bos_shift);
   const double bos_high = BarHigh(bos_shift);
   const double bos_low = BarLow(bos_shift);
   const double bos_close = BarClose(bos_shift);
   const double fvg_reference_high = BarHigh(bos_shift + 2);
   const double fvg_reference_low = BarLow(bos_shift + 2);
   const double bos_atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, bos_shift);
   if(bos_stamp <= 0 || bos_open <= 0.0 || bos_high <= 0.0 || bos_low <= 0.0 ||
      bos_high < bos_low || bos_close <= 0.0 || fvg_reference_high <= 0.0 ||
      fvg_reference_low <= 0.0 || bos_atr <= 0.0)
      return false;
   if(MathAbs(bos_close - bos_open) < strategy_bos_body_atr_mult * bos_atr)
      return false;
   if(for_long && bos_close <= bos_open)
      return false;
   if(!for_long && bos_close >= bos_open)
      return false;

   const bool fvg = for_long ? (bos_low > fvg_reference_high)
                             : (bos_high < fvg_reference_low);
   if(!fvg)
      return false;

   const int last_sweep_shift = bos_shift + MathMax(1, strategy_bos_max_bars);
   for(int sweep_shift = bos_shift + 1; sweep_shift <= last_sweep_shift; ++sweep_shift)
     {
      double frozen_high = 0.0;
      double frozen_low = 0.0;
      datetime high_stamp = 0;
      datetime low_stamp = 0;
      if(!Strategy_FindRecentSwingAtEvent(true, sweep_shift, frozen_high, high_stamp) ||
         !Strategy_FindRecentSwingAtEvent(false, sweep_shift, frozen_low, low_stamp))
         continue;

      const double sweep_atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, sweep_shift);
      const datetime sweep_stamp = BarStamp(sweep_shift);
      const double sweep_high = BarHigh(sweep_shift);
      const double sweep_low = BarLow(sweep_shift);
      const double sweep_close = BarClose(sweep_shift);
      const double previous_close = BarClose(bos_shift + 1);
      if(sweep_atr <= 0.0 || sweep_stamp <= 0 || sweep_stamp >= bos_stamp ||
         sweep_high <= 0.0 || sweep_low <= 0.0 || sweep_close <= 0.0 ||
         previous_close <= 0.0)
         continue;

      const double sweep_depth = strategy_sweep_atr_mult * sweep_atr;
      const bool swept = for_long
                         ? (sweep_low <= frozen_low - sweep_depth && sweep_close > frozen_low)
                         : (sweep_high >= frozen_high + sweep_depth && sweep_close < frozen_high);
      const double break_level = for_long ? frozen_high : frozen_low;
      const bool fresh_bos = for_long
                             ? (bos_close > break_level && previous_close <= break_level)
                             : (bos_close < break_level && previous_close >= break_level);
      if(!swept || !fresh_bos)
         continue;

      double ob_low = 0.0;
      double ob_high = 0.0;
      datetime ob_stamp = 0;
      if(!Strategy_FindOrderBlockBeforeBOS(for_long, bos_shift,
                                           ob_low, ob_high, ob_stamp))
         continue;
      const double ob_height = ob_high - ob_low;
      if(ob_height <= 0.0 || ob_height > strategy_ob_max_atr_mult * bos_atr)
         continue;

      const double frac = MathMax(0.0, MathMin(1.0, strategy_ob_entry_fraction));
      const double entry = ob_low + ob_height * frac;
      if(entry <= 0.0)
         continue;

      setup.valid = true;
      setup.for_long = for_long;
      setup.sweep_stamp = sweep_stamp;
      setup.bos_stamp = bos_stamp;
      setup.ob_stamp = ob_stamp;
      setup.sweep_extreme = for_long ? sweep_low : sweep_high;
      setup.break_level = break_level;
      setup.ob_low = ob_low;
      setup.ob_high = ob_high;
      setup.opposing_liquidity = Strategy_NearestOpposingSwing(for_long,
                                                               entry,
                                                               bos_shift);
      setup.bos_shift = bos_shift;
      return true;
     }

   return false;
  }

bool Strategy_FindLatestSetup(const bool for_long,
                              Strategy_SetupSnapshot &setup)
  {
   Strategy_ResetSetup(setup);
   // The BOS is the just-closed bar (shift 1); the limit decision happens on
   // the strictly later current bar (shift 0).  A restart mid-bar may invoke
   // the first-call new-bar edge, so Strategy_SetupStillPristine also inspects
   // the fully reconstructed shift-0 high/low before any order is allowed.
   return Strategy_FreezeSetupForBOS(for_long, 1, setup);
  }

bool Strategy_SetupStillPristine(const Strategy_SetupSnapshot &setup,
                                 const double entry)
  {
   if(!setup.valid || entry <= 0.0 || setup.bos_shift < 1)
      return false;

   // Every bar checked here closed after the BOS.  If midpoint mitigation or
   // full invalidation already occurred before the limit existed, the setup is
   // permanently consumed and deterministic reconstruction will keep rejecting
   // it after a restart.
   for(int shift = setup.bos_shift - 1; shift >= 1; --shift)
     {
      const datetime stamp = BarStamp(shift);
      const double high = BarHigh(shift);
      const double low = BarLow(shift);
      const double close = BarClose(shift);
      if(stamp <= setup.bos_stamp || high <= 0.0 || low <= 0.0 || high < low || close <= 0.0)
         return false;
      if(setup.for_long && (low <= entry || close < setup.ob_low))
         return false;
      if(!setup.for_long && (high >= entry || close > setup.ob_high))
         return false;
     }

   const datetime current_stamp = BarStamp(0);
   const double current_high = BarHigh(0);
   const double current_low = BarLow(0);
   if(current_stamp <= setup.bos_stamp || current_high <= 0.0 ||
      current_low <= 0.0 || current_high < current_low)
      return false;
   if(setup.for_long && current_low <= entry)
      return false;
   if(!setup.for_long && current_high >= entry)
      return false;
   return true;
  }

bool Strategy_BuildRetestOrder(const Strategy_SetupSnapshot &setup,
                               QM_EntryRequest &req)
  {
   const double bos_atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, setup.bos_shift);
   const double ob_height = setup.ob_high - setup.ob_low;
   const double frac = MathMax(0.0, MathMin(1.0, strategy_ob_entry_fraction));
   const double entry = Strategy_NormalizeNearestTick(setup.ob_low + ob_height * frac);
   const double buffer = bos_atr * strategy_sl_atr_buffer_mult;
   const double tick_size = Strategy_TickSize();
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bos_atr <= 0.0 || ob_height <= 0.0 || entry <= 0.0 || buffer < 0.0 ||
      tick_size <= 0.0 || bid <= 0.0 || ask <= 0.0 || ask < bid)
      return false;
   if(!Strategy_SetupStillPristine(setup, entry))
      return false;

   const string setup_id = Strategy_SetupId(setup);
   if(StringLen(setup_id) <= 0 || StringLen(setup_id) > 31)
      return false;

   req.symbol_slot = qm_magic_slot_offset;
   // GTC is deliberate.  Exactly strategy_pending_bars actually closed H1
   // bars are enforced by Strategy_ManagePendingOrders, not wall-clock time.
   req.expiration_seconds = 0;
   req.reason = setup_id;

   if(setup.for_long)
     {
      if(ask <= entry)
         return false;
      const double sl = Strategy_NormalizeDownTick(MathMin(setup.ob_low,
                                                           setup.sweep_extreme) - buffer);
      const double risk = entry - sl;
      if(sl <= 0.0 || risk < tick_size)
         return false;
      const double rr_tp = entry + risk * strategy_rr_target;
      const double raw_tp = (setup.opposing_liquidity > entry)
                            ? MathMin(rr_tp, setup.opposing_liquidity)
                            : rr_tp;
      req.type = QM_BUY_LIMIT;
      req.price = entry;
      req.sl = sl;
      req.tp = Strategy_NormalizeDownTick(raw_tp);
      return (req.tp >= req.price + tick_size);
     }

   if(bid >= entry)
      return false;
   const double sl = Strategy_NormalizeUpTick(MathMax(setup.ob_high,
                                                      setup.sweep_extreme) + buffer);
   const double risk = sl - entry;
   if(sl <= 0.0 || risk < tick_size)
      return false;
   const double rr_tp = entry - risk * strategy_rr_target;
   const double raw_tp = (setup.opposing_liquidity > 0.0 &&
                          setup.opposing_liquidity < entry)
                         ? MathMax(rr_tp, setup.opposing_liquidity)
                         : rr_tp;
   req.type = QM_SELL_LIMIT;
   req.price = entry;
   req.sl = sl;
   req.tp = Strategy_NormalizeUpTick(raw_tp);
   return (req.tp > 0.0 && req.tp <= req.price - tick_size);
  }

bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_H1)
      return true;
   if(!Strategy_SpreadAllowed())
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

   if(strategy_fractal_width < 1 || strategy_atr_period < 1 ||
      strategy_bos_max_bars < 1 || strategy_pending_bars < 1 ||
      strategy_structure_lookback < strategy_fractal_width * 2 + 3 ||
      strategy_sweep_atr_mult <= 0.0 || strategy_bos_body_atr_mult <= 0.0 ||
      strategy_ob_max_atr_mult <= 0.0 || strategy_sl_atr_buffer_mult < 0.0 ||
      strategy_rr_target <= 0.0 || strategy_max_spread_atr_fraction <= 0.0)
      return false;
   if(!Strategy_SpreadAllowed() || Strategy_HasOurPosition() || Strategy_HasOurWorkingOrder())
      return false;

   Strategy_SetupSnapshot long_setup;
   Strategy_SetupSnapshot short_setup;
   const bool have_long = Strategy_FindLatestSetup(true, long_setup);
   const bool have_short = Strategy_FindLatestSetup(false, short_setup);
   if(!have_long && !have_short)
      return false;

   Strategy_SetupSnapshot selected;
   Strategy_ResetSetup(selected);
   if(have_long && (!have_short || long_setup.bos_stamp >= short_setup.bos_stamp))
      selected = long_setup;
   else
      selected = short_setup;

   const double raw_entry = selected.ob_low +
                            (selected.ob_high - selected.ob_low) *
                            MathMax(0.0, MathMin(1.0, strategy_ob_entry_fraction));
   const double entry = Strategy_NormalizeNearestTick(raw_entry);
   if(!Strategy_SetupStillPristine(selected, entry))
      return false;

   bool history_ready = false;
   const bool already_used = Strategy_SetupPreviouslyUsed(selected, history_ready);
   if(!history_ready || already_used)
      return false;

   return Strategy_BuildRetestOrder(selected, req);
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, partial close, or pyramiding.
  }

bool Strategy_TryClosedH1BarsSince(const datetime opened_at,
                                   int &closed_bars)
  {
   closed_bars = 0;
   if(opened_at <= 0)
      return false;

   // Called only from Strategy_ExitSignal after the QM_IsNewBar gate.  The
   // shift counts actual H1 bars present in the symbol series, so weekends or
   // feed gaps do not masquerade as held bars.
   const int open_shift = iBarShift(_Symbol, PERIOD_H1, opened_at, false); // perf-allowed: once per new H1 bar.
   if(open_shift < 0)
      return false;

   MqlRates opening_rate[1];
   if(CopyRates(_Symbol, PERIOD_H1, open_shift, 1, opening_rate) != 1) // perf-allowed: bounded new-bar validation.
      return false;
   if(opening_rate[0].time <= 0 || opening_rate[0].time > opened_at)
      return false;

   if(open_shift == 0)
     {
      const datetime current_h1_open = BarStamp(0);
      if(current_h1_open <= 0 || opening_rate[0].time != current_h1_open ||
         opened_at > TimeCurrent())
         return false;
      return true;
     }

   // Prove that iBarShift resolved the bar which actually contains the deal
   // timestamp rather than merely returning an older nearest bar.
   MqlRates newer_rate[1];
   if(CopyRates(_Symbol, PERIOD_H1, open_shift - 1, 1, newer_rate) != 1) // perf-allowed: bounded new-bar validation.
      return false;
   if(newer_rate[0].time <= opening_rate[0].time || opened_at >= newer_rate[0].time)
      return false;

   // Copy the bars needed for the threshold as an availability proof.  An
   // incomplete series is fail-closed: no time-exit assertion is emitted.
   const int required_window = MathMax(MathMax(1, strategy_time_exit_bars),
                                       MathMax(1, strategy_pending_bars));
   const int verify_count = MathMin(open_shift, required_window);
   MqlRates closed_rates[];
   if(CopyRates(_Symbol, PERIOD_H1, 1, verify_count, closed_rates) != verify_count) // perf-allowed: max card hold window.
      return false;
   if(BarStamp(1) <= 0)
      return false;

   closed_bars = open_shift;
   return true;
  }

bool Strategy_IsFridayCutoff(const datetime broker_time)
  {
   if(!qm_friday_close_enabled || broker_time <= 0 ||
      qm_friday_close_hour_broker < 0 || qm_friday_close_hour_broker > 23)
      return false;
   MqlDateTime broker_parts;
   ZeroMemory(broker_parts);
   TimeToStruct(broker_time, broker_parts);
   return (broker_parts.day_of_week == 5 &&
           broker_parts.hour >= qm_friday_close_hour_broker);
  }

bool Strategy_NewsAllowsOrders(const datetime broker_now)
  {
   if(g_strategy_news_temporal == QM_NEWS_TEMPORAL_OFF &&
      g_strategy_news_compliance == QM_NEWS_COMPLIANCE_NONE)
      return true;
   if(broker_now <= 0 || Strategy_NewsFilterHook(broker_now))
      return false;
   if(!QM_NewsAllowsTrade2(_Symbol, broker_now,
                           g_strategy_news_temporal,
                           g_strategy_news_compliance))
      return false;

   // A pending order can fill before OnTick gets a chance to cancel it on the
   // first blackout tick.  Query through the end of the current H1 bar and
   // remove/block now when the first boundary lies in that interval.
   const datetime current_h1_open = BarStamp(0);
   const int h1_seconds = PeriodSeconds(PERIOD_H1);
   if(current_h1_open <= 0 || h1_seconds <= 0)
      return false;
   const datetime broker_deadline = current_h1_open + h1_seconds;
   if(broker_deadline < broker_now)
      return false;

   datetime next_block_start = 0;
   const QM_NewsBlockStartResult boundary =
      QM_NewsNextBlockStart(_Symbol,
                            broker_now,
                            broker_deadline,
                            g_strategy_news_temporal,
                            g_strategy_news_compliance,
                            next_block_start);
   if(boundary == QM_NEWS_BLOCKSTART_DATA_ERROR)
      return false;
   if(boundary == QM_NEWS_BLOCKSTART_FOUND)
      return false;
   return (boundary == QM_NEWS_BLOCKSTART_NONE && next_block_start == 0);
  }

bool Strategy_CloseOurPositions(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool requests_ok = true;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
        {
         requests_ok = false;
         continue;
        }
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(!QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY))
         requests_ok = false;
     }
   return (requests_ok && !Strategy_HasOurPosition());
  }

bool Strategy_RetryPositionClose()
  {
   if(!g_position_close_retry)
      return true;
   if(!Strategy_HasOurPosition())
     {
      g_position_close_retry = false;
      g_position_close_reason = "";
      return true;
     }
   if(!Strategy_CloseOurPositions(g_position_close_reason))
      return false;
   g_position_close_retry = false;
   g_position_close_reason = "";
   return true;
  }

bool Strategy_RemoveOurWorkingOrders(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool requests_ok = true;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
        {
         requests_ok = false;
         continue;
        }
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!QM_TM_RemovePendingOrder(ticket, reason))
         requests_ok = false;
     }
   return (requests_ok && !Strategy_HasOurWorkingOrder());
  }

bool Strategy_PendingExpiryReason(string &reason)
  {
   reason = "";
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
     {
      reason = "pending_magic_unavailable";
      return true;
     }

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
        {
         reason = "pending_order_select_failed";
         return true;
        }
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      int closed_bars = 0;
      if(!Strategy_TryClosedH1BarsSince(setup_time, closed_bars))
        {
         reason = "pending_age_data_missing";
         return true;
        }
      if(closed_bars >= MathMax(1, strategy_pending_bars))
        {
         reason = "pending_closed_h1_expiry";
         return true;
        }
     }
   return false;
  }

bool Strategy_ManagePendingOrders(const bool new_bar,
                                  const bool force_remove,
                                  const string force_reason)
  {
   if(!Strategy_HasOurWorkingOrder())
     {
      if(g_pending_remove_retry && Strategy_HasOurPosition())
        {
         g_position_close_retry = true;
         g_position_close_reason = "pending_cancel_fill_race";
        }
      g_pending_remove_retry = false;
      g_pending_remove_reason = "";
      return true;
     }

   string removal_reason = "";
   bool must_remove = false;
   if(g_pending_remove_retry)
     {
      must_remove = true;
      removal_reason = g_pending_remove_reason;
     }
   else if(force_remove)
     {
      must_remove = true;
      removal_reason = force_reason;
     }
   else if(new_bar)
      must_remove = Strategy_PendingExpiryReason(removal_reason);

   if(!must_remove)
      return false;
   if(StringLen(removal_reason) <= 0)
      removal_reason = "pending_fail_closed_remove";

   g_pending_remove_retry = true;
   g_pending_remove_reason = removal_reason;
   if(!Strategy_RemoveOurWorkingOrders(removal_reason))
      return false;

   if(Strategy_HasOurPosition())
     {
      g_position_close_retry = true;
      g_position_close_reason = "pending_cancel_fill_race";
     }
   g_pending_remove_retry = false;
   g_pending_remove_reason = "";
   return true;
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int max_hold_bars = MathMax(1, strategy_time_exit_bars);
   const double close1 = BarClose(1);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      int closed_bars = 0;
      if(Strategy_TryClosedH1BarsSince(opened_at, closed_bars) &&
         closed_bars >= max_hold_bars)
         return true;
      if(close1 <= 0.0)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double opposing_level = 0.0;
      datetime opposing_stamp = 0;
      if(type == POSITION_TYPE_BUY &&
         Strategy_FindRecentSwingAtEvent(false, 1, opposing_level, opposing_stamp) &&
         close1 < opposing_level)
         return true;
      if(type == POSITION_TYPE_SELL &&
         Strategy_FindRecentSwingAtEvent(true, 1, opposing_level, opposing_stamp) &&
         close1 > opposing_level)
         return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   g_pending_remove_retry = false;
   g_pending_remove_reason = "";
   g_position_close_retry = false;
   g_position_close_reason = "";
   if(!Strategy_ResolveNewsConfig() ||
      qm_friday_close_hour_broker < 0 || qm_friday_close_hour_broker > 23)
      return INIT_PARAMETERS_INCORRECT;

   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        g_strategy_news_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        g_strategy_news_temporal,
                        g_strategy_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10629_et-ob-bos-imb\"}");
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
   if(broker_now <= 0)
      return;
   const bool new_bar = QM_IsNewBar();
   if(new_bar)
      QM_EquityStreamOnNewBar();

   // Framework Friday close is position-only and once-per-day.  The strategy
   // adds pending-order cancellation and retries both failed paths every tick.
   const bool framework_friday_handled = QM_FrameworkHandleFridayClose();
   const bool friday_cutoff = Strategy_IsFridayCutoff(broker_now);
   if(friday_cutoff)
     {
      Strategy_ManagePendingOrders(new_bar, true, "friday_cutoff_pending");
      if(Strategy_HasOurPosition())
        {
         g_position_close_retry = true;
         g_position_close_reason = "friday_cutoff_position";
        }
      Strategy_RetryPositionClose();
      return;
     }
   if(framework_friday_handled)
      return;

   bool spread_allows_orders = true;
   bool news_allows_orders = true;
   const bool had_working_order = Strategy_HasOurWorkingOrder();
   if(had_working_order || new_bar)
     {
      spread_allows_orders = Strategy_SpreadAllowed();
      news_allows_orders = Strategy_NewsAllowsOrders(broker_now);
     }

   bool pending_blocks = false;
   if(had_working_order)
     {
      const bool force_remove = (!spread_allows_orders || !news_allows_orders);
      string removal_reason = "";
      if(!news_allows_orders)
         removal_reason = "pending_news_blackout_or_boundary";
      else if(!spread_allows_orders)
         removal_reason = "pending_spread_block";
      pending_blocks = !Strategy_ManagePendingOrders(new_bar,
                                                     force_remove,
                                                     removal_reason);
     }

   if(g_position_close_retry)
     {
      Strategy_RetryPositionClose();
      return;
     }
   if(pending_blocks || Strategy_HasOurWorkingOrder())
      return;

   Strategy_ManageOpenPosition();

   // Only a new-bar edge creates the close intent; subsequent ticks merely
   // retry the same intent.  On restart, QM_IsNewBar's first-call edge safely
   // reconstructs the decision from the still-closed shift-1 bar.
   if(new_bar && Strategy_ExitSignal())
     {
      g_position_close_retry = true;
      g_position_close_reason = "closed_h1_strategy_exit";
     }
   if(g_position_close_retry)
     {
      Strategy_RetryPositionClose();
      return;
     }

   if(!new_bar)
      return;

   if(Strategy_NoTradeFilter())
      return;

   // News is entry/pending authorization only.  Current blackout, proactive
   // next-boundary DATA_ERROR/FOUND, and stale calendar all fail closed.
   if(!news_allows_orders)
      return;

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
