#property strict
#property version   "5.0"
#property description "QM5_11545 carter-t-h1-ema18-28-wma5-12-rsi21"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11545 carter-t-h1-ema18-28-wma5-12-rsi21
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
//         System #20, self-published 2014.
// Card: artifacts/cards_approved/QM5_11545_carter-t-h1-ema18-28-wma5-12-rsi21.md
//
// Strategy mechanics:
//   - EMA(18) and EMA(28) form a narrow red tunnel:
//       abs(EMA18 - EMA28) <= strategy_tunnel_narrow_pips.
//   - Long entry when WMA(5) and WMA(12) transition from not-both-above to
//     both above the tunnel on the latest closed H1 bar and RSI(21) > 50.
//   - Short entry is the mirror below the tunnel with RSI(21) < 50.
//   - Fixed 50-pip SL and 50-pip TP. Exit early when both WMAs cross back to
//     the opposite side of the tunnel.
//   - Spread filter fails open on .DWX zero spread and only blocks genuine
//     wide spreads. No Friday entries.
//
// Only Strategy inputs and the five Strategy_* hooks are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11545;
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
input int    strategy_ema_fast_period    = 18;
input int    strategy_ema_slow_period    = 28;
input int    strategy_wma_fast_period    = 5;
input int    strategy_wma_slow_period    = 12;
input int    strategy_rsi_period         = 21;
input double strategy_rsi_mid            = 50.0;
input int    strategy_tunnel_narrow_pips = 5;
input int    strategy_sl_pips            = 50;
input int    strategy_tp_pips            = 50;
input double strategy_spread_cap_pips    = 15.0;
input bool   strategy_no_friday_entry    = true;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter: spread. Time/news are handled by EntrySignal and the
// framework News Filter Hook so open-position exits remain available.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   const double spread = ask - bid;
   if(spread > 0.0 && spread_cap > 0.0 && spread > spread_cap)
      return true;

   return false;
  }

// Trade Entry: closed-bar EMA tunnel, WMA transition, RSI bias.
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

   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5)
         return false;
     }

   const double ema18_1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema28_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema18_2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema28_2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   const double wma5_1  = QM_WMA(_Symbol, _Period, strategy_wma_fast_period, 1);
   const double wma12_1 = QM_WMA(_Symbol, _Period, strategy_wma_slow_period, 1);
   const double wma5_2  = QM_WMA(_Symbol, _Period, strategy_wma_fast_period, 2);
   const double wma12_2 = QM_WMA(_Symbol, _Period, strategy_wma_slow_period, 2);
   const double rsi1    = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);

   if(ema18_1 <= 0.0 || ema28_1 <= 0.0 || ema18_2 <= 0.0 || ema28_2 <= 0.0 ||
      wma5_1 <= 0.0 || wma12_1 <= 0.0 || wma5_2 <= 0.0 || wma12_2 <= 0.0 ||
      rsi1 <= 0.0)
      return false;

   const double tunnel_width = MathAbs(ema18_1 - ema28_1);
   const double narrow_limit = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tunnel_narrow_pips);
   if(narrow_limit <= 0.0 || tunnel_width > narrow_limit)
      return false;

   const bool now_above_tunnel = (wma5_1 > ema18_1 && wma12_1 > ema28_1);
   const bool was_above_tunnel = (wma5_2 > ema18_2 && wma12_2 > ema28_2);
   const bool now_below_tunnel = (wma5_1 < ema28_1 && wma12_1 < ema18_1);
   const bool was_below_tunnel = (wma5_2 < ema28_2 && wma12_2 < ema18_2);

   if(now_above_tunnel && !was_above_tunnel && rsi1 > strategy_rsi_mid)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_sl_pips);
      const double tp = QM_TakeFixedPips(_Symbol, QM_BUY, entry, strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "carter_tunnel_wma_long";
      return true;
     }

   if(now_below_tunnel && !was_below_tunnel && rsi1 < strategy_rsi_mid)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_sl_pips);
      const double tp = QM_TakeFixedPips(_Symbol, QM_SELL, entry, strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "carter_tunnel_wma_short";
      return true;
     }

   return false;
  }

// Trade Management: fixed SL/TP only.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: WMA pair crosses back to the opposite side of the tunnel.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ema18_1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema28_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double wma5_1  = QM_WMA(_Symbol, _Period, strategy_wma_fast_period, 1);
   const double wma12_1 = QM_WMA(_Symbol, _Period, strategy_wma_slow_period, 1);
   if(ema18_1 <= 0.0 || ema28_1 <= 0.0 || wma5_1 <= 0.0 || wma12_1 <= 0.0)
      return false;

   const bool below_tunnel = (wma5_1 < ema28_1 && wma12_1 < ema18_1);
   const bool above_tunnel = (wma5_1 > ema18_1 && wma12_1 > ema28_1);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && below_tunnel)
         return true;
      if(ptype == POSITION_TYPE_SELL && above_tunnel)
         return true;
     }

   return false;
  }

// News Filter Hook: defer to the central V5 two-axis news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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
