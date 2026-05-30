#property strict
#property version   "5.0"
#property description "QM5_1009 lien-fade-double-zeros"

#include <QM/QM_Common.mqh>
input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1009;
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
input int    trend_ma_period         = 20;
input int    entry_offset_pips       = 12;
input int    stop_offset_pips        = 20;
input int    max_spread_points       = 20;

string QM_ConfigStrategyName() { return "lien-fade-double-zeros"; }
int    QM_ConfigEaId() { return 1009; }

bool HasPosition()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      return true;
   }
   return false;
}


// Round-number helpers
double NearestRoundNumber(const double price, const string symbol)
{
   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(digits >= 4) // non-JPY major
      return NormalizeDouble(MathRound(price * 100) / 100, digits);
   else // JPY pair
      return NormalizeDouble(MathRound(price * 1) / 1, digits);
}

double RoundPips(const double price1, const double price2, const string symbol)
{
   return MathAbs(price1 - price2) / _Point;
}


bool Strategy_NoTradeFilter()
{

   if(max_spread_points > 0)
   {
      const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > max_spread_points) return true;
   }
   return false;

}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{

   if(HasPosition()) return false;

   const double close1 = iClose(_Symbol, PERIOD_M15, 1);
   if(close1 <= 0) return false;

   const double ma20 = QM_SMA(_Symbol, PERIOD_M15, trend_ma_period, 1);
   if(ma20 <= 0) return false;

   // Round number nearest to current price
   const double round_num = NearestRoundNumber(close1, _Symbol);
   const double dist_pips = RoundPips(close1, round_num);

   // Staging proximity check
   if(dist_pips > 50 * _Point) return false;

   bool long_signal = false, short_signal = false;

   // LONG: price below MA, round number above, fade the stop-gun
   if(close1 < ma20 && close1 < round_num)
   {
      const double entry_price = round_num + entry_offset_pips * _Point;
      if(entry_price > SymbolInfoDouble(_Symbol, SYMBOL_ASK))
      {
         long_signal = true;
         req.type = QM_BUY;
         req.price = entry_price;  // stop-buy
         req.sl = round_num - stop_offset_pips * _Point;
         req.tp = 0;
         req.reason = "FADE_DZ_LONG";
      }
   }

   // SHORT: price above MA, round number below
   if(!long_signal && close1 > ma20 && close1 > round_num)
   {
      const double entry_price = round_num - entry_offset_pips * _Point;
      if(entry_price < SymbolInfoDouble(_Symbol, SYMBOL_BID))
      {
         short_signal = true;
         req.type = QM_SELL;
         req.price = entry_price;  // stop-sell
         req.sl = round_num + stop_offset_pips * _Point;
         req.tp = 0;
         req.reason = "FADE_DZ_SHORT";
      }
   }

   if(!long_signal && !short_signal) return false;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 86400;
   return true;

}

void Strategy_ManageOpenPosition()
{

}

bool Strategy_ExitSignal()
{
return false;
}

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30,
                        qm_news_stale_max_hours, qm_news_min_impact,
                        qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance))
     return INIT_FAILED;
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1009\",\"strategy\":\"lien-fade-double-zeros\"}");
   return INIT_SUCCEEDED;
  }


void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{{\"reason\":%d}}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {{
   if(!QM_KillSwitchCheck()) return;
   if(!QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;
   Strategy_ManageOpenPosition();
   Strategy_ExitSignal();
   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();
   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {{
    ulong out_ticket = 0;
    QM_TM_OpenPosition(req, out_ticket);
   }}
  }}


void OnTimer() {{ QM_FrameworkOnTimer(); }}
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {{ QM_FrameworkOnTradeTransaction(trans, request, result); }}
double OnTester() {{ QM_ChartUI_Refresh(); return QM_DefaultObjective(); }}

