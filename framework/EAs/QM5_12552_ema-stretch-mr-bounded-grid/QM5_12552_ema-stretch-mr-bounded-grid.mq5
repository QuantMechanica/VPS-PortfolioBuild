#property strict
#property version   "5.0"
#property description "QM5_12552 EMA-stretch mean reversion with bounded ATR grid"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12552 ema-stretch-mr-bounded-grid
// -----------------------------------------------------------------------------
// The framework owns tick orchestration, lifecycle guards, risk validation,
// magic resolution, order transport, logging, MAE evidence and Model-4 tester
// integration. Strategy code is confined to the five hooks below.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12552;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;      // live setfiles use 0.5
input double RISK_FIXED                 = 1000.0;   // tester default (HR4)
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

enum QM12552_TPMode
  {
   TP_SLOW_MA      = 0,
   TP_RSI_RECOVERY = 1,
   TP_VWAP_PIPS    = 2,
   TP_VWAP_ATR     = 3
  };

input group "Strategy"
input double         M_entry            = 10.0;
input int            rsi_offset         = 15;
input int            ema_period         = 200;
input int            rsi_period         = 14;
input int            atr_long_period    = 100;
input int            atr_short_period   = 14;
input int            grid_levels        = 5;
input double         lot_mult           = 1.15;
input double         grid_base_atr_mult = 1.0;
input int            grid_min_pips      = 5;
input int            grid_min_bars      = 1;
input double         stop_span_atr      = 14.0;
input double         risk_budget_pct    = 1.0;
input QM12552_TPMode tp_mode            = TP_SLOW_MA;
input int            vwap_target_pips   = 20;
input double         vwap_atr_mult      = 1.0;
input int            max_hold_hours     = 0;
input bool           use_trailing       = false;
input int            trail_step_pips    = 10;
input int            max_spread_pips    = 8;

// A level uses slot qm_magic_slot_offset + level_index*1000. The deterministic
// registry contains the host slot plus four add-level slots for every approved
// symbol. QM_MagicFor resolves and registers each context; magic integers are
// never computed in the EA.
#define QM12552_MAX_LEVELS 5

int      g_level_magic[QM12552_MAX_LEVELS] = {-1, -1, -1, -1, -1};
double   g_plan_price[QM12552_MAX_LEVELS] = {0.0, 0.0, 0.0, 0.0, 0.0};
double   g_leg_risk_base[QM12552_MAX_LEVELS] = {0.0, 0.0, 0.0, 0.0, 0.0};
bool     g_magic_context_ready = false;
bool     g_basket_active       = false;
int      g_basket_dir          = 0;
int      g_planned_levels      = 0;
int      g_fill_count          = 0;
double   g_shared_stop         = 0.0;
datetime g_last_fill_time      = 0;
datetime g_basket_open_time    = 0;
double   g_last_trail_price    = 0.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the APPROVED card.
// -----------------------------------------------------------------------------

// No Trade Filter (timeframe, input contract, price and spread).
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1 || qm_ea_id != 12552)
      return true;
   if(!g_magic_context_ready)
      return true;
   if(grid_levels < 1 || grid_levels > QM12552_MAX_LEVELS)
      return true;
   if(ema_period < 2 || rsi_period < 2 || atr_long_period < 2 || atr_short_period < 2)
      return true;
   if(M_entry <= 0.0 || rsi_offset <= 0 || rsi_offset >= 50)
      return true;
   if(lot_mult < 1.0 || lot_mult > 1.3)
      return true;
   if(grid_base_atr_mult <= 0.0 || grid_min_pips <= 0 || grid_min_bars < 0)
      return true;
   if(stop_span_atr <= 0.0 || risk_budget_pct <= 0.0 || risk_budget_pct > 1.0)
      return true;
   if(tp_mode < TP_SLOW_MA || tp_mode > TP_VWAP_ATR)
      return true;
   if(vwap_target_pips <= 0 || vwap_atr_mult <= 0.0 || max_hold_hours < 0)
      return true;
   if(use_trailing && trail_step_pips <= 0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   // .DWX Model-4 quotes may have ask==bid. Block only a genuinely wide,
   // positive spread; zero modeled spread is valid tester data.
   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, max_spread_pips);
   if(ask > bid && spread_cap > 0.0 && (ask - bid) > spread_cap)
      return true;
   return false;
  }

// Trade Entry. The caller invokes this once per completed H1 bar. Level 1 and
// later adds are opened here through QM_TM_OpenPosition so every fill retains
// the framework risk, news, kill-switch, stress and broker-send rails.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_magic_context_ready)
      return false;

   int open_count = 0;
   int highest_open_level = -1;
   int detected_dir = 0;
   double total_volume = 0.0;
   double weighted_price = 0.0;
   datetime earliest_open = 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long position_magic = PositionGetInteger(POSITION_MAGIC);
      int own_level = -1;
      for(int level = 0; level < grid_levels; ++level)
        {
         if(position_magic == (long)g_level_magic[level])
           {
            own_level = level;
            break;
           }
        }
      if(own_level < 0)
         continue;

      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double entry  = PositionGetDouble(POSITION_PRICE_OPEN);
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(volume <= 0.0 || entry <= 0.0)
         continue;

      open_count++;
      if(own_level > highest_open_level)
         highest_open_level = own_level;
      detected_dir = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      total_volume += volume;
      weighted_price += entry * volume;
      if(earliest_open <= 0 || (opened > 0 && opened < earliest_open))
         earliest_open = opened;
     }

   if(open_count <= 0)
     {
      g_basket_active    = false;
      g_basket_dir       = 0;
      g_planned_levels   = 0;
      g_fill_count       = 0;
      g_shared_stop      = 0.0;
      g_last_fill_time   = 0;
      g_basket_open_time = 0;
      g_last_trail_price = 0.0;
      for(int level = 0; level < QM12552_MAX_LEVELS; ++level)
        {
         g_plan_price[level]   = 0.0;
         g_leg_risk_base[level] = 0.0;
        }
     }
   else
     {
      // Restart-safe protection: existing positions remain managed and may
      // exit, but a lost in-memory ladder plan is never improvised after reload.
      if(!g_basket_active)
        {
         g_basket_active    = true;
         g_basket_dir       = detected_dir;
         g_fill_count       = highest_open_level + 1;
         g_planned_levels   = g_fill_count;
         g_basket_open_time = earliest_open;
         g_last_fill_time   = earliest_open;
        }

      if(g_basket_dir == 0)
         g_basket_dir = detected_dir;

      // Level 2..N: same direction, fixed planned ATR spacing, and at least
      // grid_min_bars completed H1 periods since the preceding successful fill.
      if(g_fill_count < g_planned_levels &&
         g_fill_count < QM12552_MAX_LEVELS &&
         g_plan_price[g_fill_count] > 0.0 &&
         g_leg_risk_base[g_fill_count] > 0.0 &&
         g_shared_stop > 0.0)
        {
         const int elapsed_seconds = (g_last_fill_time > 0)
                                     ? (int)(TimeCurrent() - g_last_fill_time)
                                     : 0;
         const int required_seconds = grid_min_bars * PeriodSeconds(PERIOD_H1);
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         const int next_level = g_fill_count;
         const bool reached = (g_basket_dir > 0)
                              ? (ask > 0.0 && ask <= g_plan_price[next_level])
                              : (bid > 0.0 && bid >= g_plan_price[next_level]);

         if(reached && elapsed_seconds >= required_seconds)
           {
            const double basket_vwap = (total_volume > 0.0)
                                       ? (weighted_price / total_volume)
                                       : 0.0;
            double current_tp = 0.0;
            if(tp_mode == TP_VWAP_PIPS)
              {
               const double distance = QM_StopRulesPipsToPriceDistance(_Symbol, vwap_target_pips);
               current_tp = (g_basket_dir > 0) ? basket_vwap + distance
                                               : basket_vwap - distance;
              }
            else if(tp_mode == TP_VWAP_ATR)
              {
               const double atr_long = QM_ATR(_Symbol, PERIOD_H1, atr_long_period, 1);
               if(atr_long > 0.0)
                  current_tp = (g_basket_dir > 0) ? basket_vwap + vwap_atr_mult * atr_long
                                                  : basket_vwap - vwap_atr_mult * atr_long;
              }

            req.type = (g_basket_dir > 0) ? QM_BUY : QM_SELL;
            req.price = 0.0;
            req.sl = g_shared_stop;
            req.tp = (current_tp > 0.0) ? QM_StopRulesNormalizePrice(_Symbol, current_tp) : 0.0;
            req.reason = StringFormat("EMA_STRETCH_GRID_L%d", next_level + 1);
            req.symbol_slot = qm_magic_slot_offset + next_level * 1000;
            req.expiration_seconds = 0;

            ulong add_ticket = 0;
            if(QM_TM_OpenPosition(req,
                                  add_ticket,
                                  g_level_magic[next_level],
                                  QM_RISK_MODE_FIXED,
                                  g_leg_risk_base[next_level]))
              {
               g_fill_count++;
               g_last_fill_time = TimeCurrent();

               // Recompute the actual lot-weighted VWAP after the fill, then
               // stamp one common hard TP on every leg for modes 3 and 4.
               if(tp_mode == TP_VWAP_PIPS || tp_mode == TP_VWAP_ATR)
                 {
                  double filled_volume = 0.0;
                  double filled_weighted_price = 0.0;
                  for(int p = PositionsTotal() - 1; p >= 0; --p)
                    {
                     const ulong fill_ticket = PositionGetTicket(p);
                     if(fill_ticket == 0 || !PositionSelectByTicket(fill_ticket))
                        continue;
                     if(PositionGetString(POSITION_SYMBOL) != _Symbol)
                        continue;
                     const long fill_magic = PositionGetInteger(POSITION_MAGIC);
                     bool own = false;
                     for(int level = 0; level < grid_levels; ++level)
                        if(fill_magic == (long)g_level_magic[level])
                           own = true;
                     if(!own)
                        continue;
                     const double fill_volume = PositionGetDouble(POSITION_VOLUME);
                     const double fill_price  = PositionGetDouble(POSITION_PRICE_OPEN);
                     filled_volume += fill_volume;
                     filled_weighted_price += fill_volume * fill_price;
                    }

                  if(filled_volume > 0.0)
                    {
                     const double filled_vwap = filled_weighted_price / filled_volume;
                     double target_tp = 0.0;
                     if(tp_mode == TP_VWAP_PIPS)
                       {
                        const double distance = QM_StopRulesPipsToPriceDistance(_Symbol, vwap_target_pips);
                        target_tp = (g_basket_dir > 0) ? filled_vwap + distance
                                                      : filled_vwap - distance;
                       }
                     else
                       {
                        const double atr_long = QM_ATR(_Symbol, PERIOD_H1, atr_long_period, 1);
                        if(atr_long > 0.0)
                           target_tp = (g_basket_dir > 0) ? filled_vwap + vwap_atr_mult * atr_long
                                                         : filled_vwap - vwap_atr_mult * atr_long;
                       }
                     target_tp = QM_StopRulesNormalizePrice(_Symbol, target_tp);

                     if(target_tp > 0.0)
                       {
                        for(int p = PositionsTotal() - 1; p >= 0; --p)
                          {
                           const ulong fill_ticket = PositionGetTicket(p);
                           if(fill_ticket == 0 || !PositionSelectByTicket(fill_ticket))
                              continue;
                           if(PositionGetString(POSITION_SYMBOL) != _Symbol)
                              continue;
                           const long fill_magic = PositionGetInteger(POSITION_MAGIC);
                           bool own = false;
                           for(int level = 0; level < grid_levels; ++level)
                              if(fill_magic == (long)g_level_magic[level])
                                 own = true;
                           if(!own)
                              continue;
                           const double old_tp = PositionGetDouble(POSITION_TP);
                           const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                           if(MathAbs(old_tp - target_tp) > point * 0.5)
                              QM_TM_MoveTP(fill_ticket, target_tp, "bounded_grid_vwap_tp");
                          }
                       }
                    }
                 }
              }
           }
        }
      return false;
     }

   const double ema      = QM_EMA(_Symbol, PERIOD_H1, ema_period, 1);
   const double atr_long = QM_ATR(_Symbol, PERIOD_H1, atr_long_period, 1);
   const double atr_short = QM_ATR(_Symbol, PERIOD_H1, atr_short_period, 1);
   const double rsi      = QM_RSI(_Symbol, PERIOD_H1, rsi_period, 1, PRICE_CLOSE);
   const double ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ema <= 0.0 || atr_long <= 0.0 || atr_short <= 0.0 || rsi <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   int direction = 0;
   if(ask < ema - M_entry * atr_long && rsi < 50.0 - (double)rsi_offset)
      direction = 1;
   else if(bid > ema + M_entry * atr_long && rsi > 50.0 + (double)rsi_offset)
      direction = -1;
   if(direction == 0)
      return false;

   const double entry1 = (direction > 0) ? ask : bid;
   const double floor_distance = QM_StopRulesPipsToPriceDistance(_Symbol, grid_min_pips);
   const double step_distance = MathMax(floor_distance,
                                        grid_base_atr_mult * atr_short * (atr_short / atr_long));
   const double stop_distance = stop_span_atr * atr_long;
   const double grid_span = (double)(grid_levels - 1) * step_distance;
   if(step_distance <= 0.0 || stop_distance <= grid_span)
      return false; // the card requires S beyond the deepest planned level

   for(int level = 0; level < grid_levels; ++level)
     {
      const double offset = (double)level * step_distance;
      g_plan_price[level] = (direction > 0) ? entry1 - offset : entry1 + offset;
     }
   for(int level = grid_levels; level < QM12552_MAX_LEVELS; ++level)
      g_plan_price[level] = 0.0;

   const double raw_stop = (direction > 0) ? entry1 - stop_distance : entry1 + stop_distance;
   g_shared_stop = QM_StopRulesNormalizePrice(_Symbol, raw_stop);
   if(g_shared_stop <= 0.0)
      return false;
   if(direction > 0 && g_shared_stop >= g_plan_price[grid_levels - 1])
      return false;
   if(direction < 0 && g_shared_stop <= g_plan_price[grid_levels - 1])
      return false;

   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0 || PORTFOLIO_WEIGHT <= 0.0)
      return false;

   double actual_total_risk = 0.0;
   if(RISK_FIXED > 0.0 && RISK_PERCENT == 0.0)
      actual_total_risk = RISK_FIXED * PORTFOLIO_WEIGHT;
   else if(RISK_PERCENT > 0.0 && RISK_FIXED == 0.0)
      actual_total_risk = equity * (RISK_PERCENT / 100.0) * PORTFOLIO_WEIGHT;
   else
      return false;

   const double card_cap = equity * (risk_budget_pct / 100.0);
   actual_total_risk = MathMin(actual_total_risk, card_cap);
   if(actual_total_risk <= 0.0)
      return false;

   double denominator = 0.0;
   for(int level = 0; level < grid_levels; ++level)
     {
      const double multiplier = MathPow(lot_mult, (double)level);
      denominator += multiplier * MathAbs(g_plan_price[level] - g_shared_stop);
     }
   if(denominator <= 0.0)
      return false;

   for(int level = 0; level < grid_levels; ++level)
     {
      const double multiplier = MathPow(lot_mult, (double)level);
      const double share = multiplier * MathAbs(g_plan_price[level] - g_shared_stop) / denominator;
      // The explicit FIXED overload applies PORTFOLIO_WEIGHT once. Dividing
      // here makes the sum of actual leg risks equal actual_total_risk.
      g_leg_risk_base[level] = (actual_total_risk * share) / PORTFOLIO_WEIGHT;
     }
   for(int level = grid_levels; level < QM12552_MAX_LEVELS; ++level)
      g_leg_risk_base[level] = 0.0;

   double hard_tp = 0.0;
   if(tp_mode == TP_VWAP_PIPS)
     {
      const double distance = QM_StopRulesPipsToPriceDistance(_Symbol, vwap_target_pips);
      hard_tp = (direction > 0) ? entry1 + distance : entry1 - distance;
     }
   else if(tp_mode == TP_VWAP_ATR)
      hard_tp = (direction > 0) ? entry1 + vwap_atr_mult * atr_long
                                : entry1 - vwap_atr_mult * atr_long;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = g_shared_stop;
   req.tp = (hard_tp > 0.0) ? QM_StopRulesNormalizePrice(_Symbol, hard_tp) : 0.0;
   req.reason = (direction > 0) ? "EMA_STRETCH_MR_L1_LONG" : "EMA_STRETCH_MR_L1_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ulong first_ticket = 0;
   if(QM_TM_OpenPosition(req,
                         first_ticket,
                         g_level_magic[0],
                         QM_RISK_MODE_FIXED,
                         g_leg_risk_base[0]))
     {
      g_basket_active    = true;
      g_basket_dir       = direction;
      g_planned_levels   = grid_levels;
      g_fill_count       = 1;
      g_last_fill_time   = TimeCurrent();
      g_basket_open_time = TimeCurrent();
      g_last_trail_price = 0.0;
     }

   // This hook performs the framework-routed bounded fill itself because the
   // skeleton's default two-argument open call would allocate the whole risk
   // budget to level 1 instead of backward-splitting it over the full ladder.
   return false;
  }

// Trade Management. Every leg already has the shared server-side catastrophic
// stop. Optional trailing tightens that shared stop one pip-step at a time once
// aggregate basket P/L is positive; it never loosens or crosses break-even.
void Strategy_ManageOpenPosition()
  {
   int open_count = 0;
   int detected_dir = 0;
   double total_volume = 0.0;
   double weighted_price = 0.0;
   double aggregate_profit = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const long position_magic = PositionGetInteger(POSITION_MAGIC);
      bool own = false;
      for(int level = 0; level < grid_levels; ++level)
         if(position_magic == (long)g_level_magic[level])
            own = true;
      if(!own)
         continue;

      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double entry  = PositionGetDouble(POSITION_PRICE_OPEN);
      open_count++;
      detected_dir = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      total_volume += volume;
      weighted_price += volume * entry;
      aggregate_profit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(g_shared_stop <= 0.0 && PositionGetDouble(POSITION_SL) > 0.0)
         g_shared_stop = PositionGetDouble(POSITION_SL);
     }

   if(open_count <= 0)
     {
      if(g_basket_active)
        {
         g_basket_active    = false;
         g_basket_dir       = 0;
         g_planned_levels   = 0;
         g_fill_count       = 0;
         g_shared_stop      = 0.0;
         g_last_fill_time   = 0;
         g_basket_open_time = 0;
         g_last_trail_price = 0.0;
         for(int level = 0; level < QM12552_MAX_LEVELS; ++level)
           {
            g_plan_price[level] = 0.0;
            g_leg_risk_base[level] = 0.0;
           }
        }
      return;
     }

   if(g_basket_dir == 0)
      g_basket_dir = detected_dir;
   if(!use_trailing || trail_step_pips <= 0 || aggregate_profit <= 0.0 ||
      total_volume <= 0.0 || g_shared_stop <= 0.0)
      return;

   const double basket_vwap = weighted_price / total_volume;
   const double step = QM_StopRulesPipsToPriceDistance(_Symbol, trail_step_pips);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(step <= 0.0 || point <= 0.0 || bid <= 0.0 || ask <= 0.0)
      return;

   bool advance = false;
   double candidate = g_shared_stop;
   if(g_basket_dir > 0)
     {
      if(g_last_trail_price <= 0.0)
         g_last_trail_price = bid - step;
      advance = (bid >= g_last_trail_price + step);
      candidate = MathMin(basket_vwap, g_shared_stop + step);
      advance = advance && candidate > g_shared_stop + point * 0.5 && candidate < bid;
     }
   else
     {
      if(g_last_trail_price <= 0.0)
         g_last_trail_price = ask + step;
      advance = (ask <= g_last_trail_price - step);
      candidate = MathMax(basket_vwap, g_shared_stop - step);
      advance = advance && candidate < g_shared_stop - point * 0.5 && candidate > ask;
     }
   if(!advance)
      return;

   candidate = QM_StopRulesNormalizePrice(_Symbol, candidate);
   bool moved_any = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const long position_magic = PositionGetInteger(POSITION_MAGIC);
      bool own = false;
      for(int level = 0; level < grid_levels; ++level)
         if(position_magic == (long)g_level_magic[level])
            own = true;
      if(own && QM_TM_MoveSL(ticket, candidate, "bounded_grid_trail_to_be"))
         moved_any = true;
     }

   if(moved_any)
     {
      g_shared_stop = candidate;
      g_last_trail_price = (g_basket_dir > 0) ? bid : ask;
     }
  }

// Trade Close. Virtual EMA/RSI exits use completed H1 bars. The optional time
// stop applies to every TP mode. Extra level magics are closed here; returning
// true lets the skeleton close the host magic through the same framework path.
bool Strategy_ExitSignal()
  {
   int open_count = 0;
   int detected_dir = 0;
   datetime earliest_open = 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const long position_magic = PositionGetInteger(POSITION_MAGIC);
      bool own = false;
      for(int level = 0; level < grid_levels; ++level)
         if(position_magic == (long)g_level_magic[level])
            own = true;
      if(!own)
         continue;

      open_count++;
      detected_dir = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(earliest_open <= 0 || (opened > 0 && opened < earliest_open))
         earliest_open = opened;
     }
   if(open_count <= 0)
      return false;

   const int direction = (g_basket_dir != 0) ? g_basket_dir : detected_dir;
   bool exit_now = false;

   const datetime opened_at = (g_basket_open_time > 0) ? g_basket_open_time : earliest_open;
   if(max_hold_hours > 0 && opened_at > 0 &&
      (TimeCurrent() - opened_at) >= (long)max_hold_hours * 3600L)
      exit_now = true;

   if(!exit_now && tp_mode == TP_SLOW_MA)
     {
      MqlRates bar1;
      MqlRates bar2;
      const double ema1 = QM_EMA(_Symbol, PERIOD_H1, ema_period, 1);
      const double ema2 = QM_EMA(_Symbol, PERIOD_H1, ema_period, 2);
      if(ema1 > 0.0 && ema2 > 0.0 &&
         QM_ReadBar(_Symbol, PERIOD_H1, 1, bar1) &&
         QM_ReadBar(_Symbol, PERIOD_H1, 2, bar2))
        {
         if(direction > 0 && bar2.close < ema2 && bar1.close >= ema1)
            exit_now = true;
         if(direction < 0 && bar2.close > ema2 && bar1.close <= ema1)
            exit_now = true;
        }
     }
   else if(!exit_now && tp_mode == TP_RSI_RECOVERY)
     {
      const double rsi = QM_RSI(_Symbol, PERIOD_H1, rsi_period, 1, PRICE_CLOSE);
      if(direction > 0 && rsi >= 50.0 + (double)rsi_offset)
         exit_now = true;
      if(direction < 0 && rsi <= 50.0 - (double)rsi_offset)
         exit_now = true;
     }

   if(!exit_now)
      return false;

   const int host_magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const long position_magic = PositionGetInteger(POSITION_MAGIC);
      bool own = false;
      for(int level = 0; level < grid_levels; ++level)
         if(position_magic == (long)g_level_magic[level])
            own = true;
      if(own && position_magic != (long)host_magic)
         QM_TM_ClosePosition(ticket,
                             (max_hold_hours > 0 && opened_at > 0 &&
                              (TimeCurrent() - opened_at) >= (long)max_hold_hours * 3600L)
                             ? QM_EXIT_TIME_STOP
                             : QM_EXIT_STRATEGY);
     }
   return true;
  }

// News Filter Hook. It does not add a private news rule. Its only side effect
// is idempotent framework registration of the preallocated level magics, so
// Friday close, kill-switch and Q08 MAE ownership cover every open grid leg.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(g_magic_context_ready)
      return false;
   if(grid_levels < 1 || grid_levels > QM12552_MAX_LEVELS ||
      qm_magic_slot_offset < 0 || qm_magic_slot_offset > 999)
      return false;

   bool all_ready = true;
   for(int level = 0; level < grid_levels; ++level)
     {
      const int slot = qm_magic_slot_offset + level * 1000;
      g_level_magic[level] = QM_MagicFor(qm_ea_id, slot);
      if(g_level_magic[level] <= 0)
         all_ready = false;
     }
   for(int level = grid_levels; level < QM12552_MAX_LEVELS; ++level)
      g_level_magic[level] = -1;
   g_magic_context_ready = all_ready;
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — canonical skeleton; do not edit.
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
