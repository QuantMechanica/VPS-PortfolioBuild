#ifndef QM_CONSOLEDATA_MQH
#define QM_CONSOLEDATA_MQH

#include <QM/QM_ConsoleModel.mqh>

// Read-only producer. Ownership follows the entry magic + position identifier,
// not the magic of a closing deal (manual and governor exits can differ).
#define QM_PANEL_REFRESH_SECONDS 30

struct QMPanelDeal
  {
   ulong position_id;
   long magic;
   datetime when;
   ENUM_DEAL_ENTRY entry;
   ENUM_DEAL_REASON reason;
   double profit;
   double swap;
   double commission;
   double fee;
  };

struct QMPanelTrade
  {
   ulong position_id;
   double pnl;
   datetime close_time;
   ENUM_DEAL_REASON close_reason;
   bool has_exit;
   bool ownership_conflict;
  };

struct QMPanelPerformance
  {
   bool valid;
   string error;
   int closed_today;
   int closed_since_attach;
   int closed_week;
   double today_net;
   double week_net;
   double today_gross;
   double week_gross;
   int closed_total;
   int wins;
   int losses;
   double gross_profit;
   double gross_loss;
   double net_profit;
   double average_win;
   double average_loss;
   double profit_factor;
   bool profit_factor_infinite;
   double expectancy;
   double max_drawdown_money;
   double max_drawdown_percent;
   int current_win_streak;
   int current_loss_streak;
   int longest_win_streak;
   int longest_loss_streak;
   double best_trade;
   double worst_trade;
   double last_trade;
   datetime last_trade_time;
   ENUM_DEAL_REASON last_trade_reason;
   double account_today_pnl;
  };

QM_ConsoleLocale g_qm_console_locale=QM_LOCALE_DE_DE;

string QM_PanelAscii(const string value)
  {
   string out = "";
   for(int i = 0; i < StringLen(value); ++i)
     {
      const ushort ch = StringGetCharacter(value, i);
      out += ShortToString((ushort)((ch >= 32 && ch <= 126) ? ch : 32));
     }
   return out;
  }

string QM_PanelTimeframeName(const ENUM_TIMEFRAMES value)
  {
   string name = EnumToString(value);
   if(StringFind(name, "PERIOD_") == 0)
      return StringSubstr(name, 7);
   return name;
  }

string QM_PanelFormatNumber(const double value, const int requested_decimals,
                            const bool show_plus = false)
  {
   const int decimals = (int)MathMax(0, MathMin(8, requested_decimals));
   long scale = 1;
   for(int i = 0; i < decimals; ++i)
      scale *= 10;
   const long scaled = (long)MathRound(MathAbs(value) * (double)scale);
   const long whole = scaled / scale;
   const long fraction = scaled % scale;
   string grouped = StringFormat("%I64d", whole);
   for(int at = StringLen(grouped) - 3; at > 0; at -= 3)
      grouped = StringSubstr(grouped, 0, at) + (g_qm_console_locale==QM_LOCALE_DE_DE ? "." : ",") + StringSubstr(grouped, at);
   if(decimals > 0)
     {
      string fraction_text = StringFormat("%I64d", fraction);
      while(StringLen(fraction_text) < decimals)
         fraction_text = "0" + fraction_text;
      grouped += (g_qm_console_locale==QM_LOCALE_DE_DE ? "," : ".") + fraction_text;
     }
   if(value < 0.0)
      return "-" + grouped;
   if(show_plus && value > 0.0)
      return "+" + grouped;
   return grouped;
  }

string QM_PanelMoney(const double value, const bool show_plus = false)
  {
   return AccountInfoString(ACCOUNT_CURRENCY) + " " +
          QM_PanelFormatNumber(value, 2, show_plus);
  }

string QM_PanelPercent(const double value, const bool show_plus = false)
  {
   return QM_PanelFormatNumber(value, 2, show_plus) + " %";
  }

string QM_PanelPips(const double value)
  {
   return QM_PanelFormatNumber(value, 1, false) + " pip";
  }

string QM_PanelDuration(const long raw_seconds)
  {
   const long seconds = (long)MathMax(0, raw_seconds);
   const long hours = seconds / 3600;
   const long minutes = (seconds % 3600) / 60;
   return StringFormat("%02d:%02d", hours, minutes);
  }

string QM_PanelDateTime(const datetime value)
  {
   if(value <= 0)
      return "N/A";
   MqlDateTime parts;
   TimeToStruct(value, parts);
   return StringFormat("%04d-%02d-%02d %02d:%02d",
                       parts.year, parts.mon, parts.day, parts.hour, parts.min);
  }

bool QM_PanelFormatterSelfTest()
  {
   const QM_ConsoleLocale saved=g_qm_console_locale;
   g_qm_console_locale=QM_LOCALE_DE_DE;
   bool ok=QM_PanelFormatNumber(100000.0,2)=="100.000,00" &&
      QM_PanelFormatNumber(-1234.5,2)=="-1.234,50" &&
      QM_PanelPercent(0.31)=="0,31 %" && QM_PanelDuration(3720)=="01:02";
   g_qm_console_locale=QM_LOCALE_EN_US;
   ok=ok && QM_PanelFormatNumber(100000.0,2)=="100,000.00" &&
      QM_PanelFormatNumber(-1234.5,2)=="-1,234.50" &&
      QM_PanelPercent(0.31)=="0.31 %";
   g_qm_console_locale=saved;
   return ok;
  }

string QM_PanelEnvironment()
  {
   const long mode = AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if(mode == ACCOUNT_TRADE_MODE_REAL)
      return "LIVE";
   if(mode == ACCOUNT_TRADE_MODE_DEMO)
      return "DEMO";
   if(mode == ACCOUNT_TRADE_MODE_CONTEST)
      return "CONTEST";
   return "UNKNOWN";
  }

string QM_PanelNextBar()
  {
   const int seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   const datetime bar = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 0);
   if(seconds <= 0 || bar <= 0)
      return "N/A (bar clock unavailable)";
   const datetime next = bar + seconds;
   return QM_PanelDateTime(next) + " BT | " +
          QM_PanelDuration((long)(next - TimeCurrent()));
  }

int QM_PanelFindTrade(QMPanelTrade &trades[], const ulong position_id)
  {
   for(int i = 0; i < ArraySize(trades); ++i)
      if(trades[i].position_id == position_id)
         return i;
   const int index = ArraySize(trades);
   if(ArrayResize(trades,index+1)!=index+1) return -1;
   trades[index].position_id = position_id;
   trades[index].pnl = 0.0;
   trades[index].close_time = 0;
   trades[index].close_reason = DEAL_REASON_CLIENT;
   trades[index].has_exit = false;
   trades[index].ownership_conflict = false;
   return index;
  }

int QM_PanelTradeIndex(const QMPanelTrade &trades[],const ulong position_id)
  {
   for(int i=0;i<ArraySize(trades);++i)
      if(trades[i].position_id==position_id) return i;
   return -1;
  }

bool QM_PanelIdentifierInSnapshot(const ulong &open_ids[],const ulong position_id)
  {
   for(int i=0;i<ArraySize(open_ids);++i)
      if(open_ids[i]==position_id) return true;
   return false;
  }

bool QM_PanelPositionIdentifierOpen(const ulong position_id)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket != 0 && PositionSelectByTicket(ticket) &&
         (ulong)PositionGetInteger(POSITION_IDENTIFIER) == position_id)
         return true;
     }
   return false;
  }

double QM_PanelFloatingForMagic(const long magic)
  {
   double floating = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         (long)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      floating += PositionGetDouble(POSITION_PROFIT) +
                  PositionGetDouble(POSITION_SWAP);
     }
   return floating;
  }

void QM_PanelResetPerformance(QMPanelPerformance &stats)
  {
   stats.valid = false;
   stats.error = "N/A (history unavailable)";
   stats.closed_today = 0;
   stats.closed_since_attach = 0;
   stats.closed_week=0; stats.today_net=0.0; stats.week_net=0.0;
   stats.today_gross=0.0; stats.week_gross=0.0;
   stats.closed_total = 0;
   stats.wins = 0;
   stats.losses = 0;
   stats.gross_profit = 0.0;
   stats.gross_loss = 0.0;
   stats.net_profit = 0.0;
   stats.average_win = 0.0;
   stats.average_loss = 0.0;
   stats.profit_factor = 0.0;
   stats.profit_factor_infinite = false;
   stats.expectancy = 0.0;
   stats.max_drawdown_money = 0.0;
   stats.max_drawdown_percent = 0.0;
   stats.current_win_streak = 0;
   stats.current_loss_streak = 0;
   stats.longest_win_streak = 0;
   stats.longest_loss_streak = 0;
   stats.best_trade = 0.0;
   stats.worst_trade = 0.0;
   stats.last_trade = 0.0;
   stats.last_trade_time = 0;
   stats.last_trade_reason = DEAL_REASON_CLIENT;
   stats.account_today_pnl = 0.0;
  }

// Pure aggregation over a read-only snapshot; also used by native fixtures.
// Day/week cashflow uses each deal's broker timestamp, including entry costs
// and partial exits. Counts refer to completely closed position identifiers.
// DD is the closed-position NET curve only, never reconstructed equity DD.
bool QM_PanelAggregatePerformance(const QMPanelDeal &deals[],const ulong &open_ids[],
                                  const long magic,const datetime now,
                                  const datetime attached_at,const double start_equity,
                                  QMPanelPerformance &stats)
  {
   QM_PanelResetPerformance(stats);
   if(now<=0) { stats.error="N/A (broker clock unavailable)"; return false; }

   MqlDateTime day;
   TimeToStruct(now, day);
   day.hour = 0;
   day.min = 0;
   day.sec = 0;
   const datetime today_start = StructToTime(day);
   const datetime week_start=today_start-(day.day_of_week==0 ? 6 : day.day_of_week-1)*86400;
   QMPanelTrade trades[];
   const int deals_total = ArraySize(deals);
   // Establish ownership first. OUT deals alone cannot establish provenance.
   for(int i = 0; i < deals_total; ++i)
     {
      if(deals[i].position_id>0 && deals[i].magic==magic && deals[i].when<=now &&
         (deals[i].entry==DEAL_ENTRY_IN || deals[i].entry==DEAL_ENTRY_INOUT))
         if(QM_PanelFindTrade(trades,deals[i].position_id)<0)
           { stats.error="N/A (history allocation failed)"; return false; }
     }
   for(int i = 0; i < deals_total; ++i)
     {
      const QMPanelDeal deal=deals[i];
      const datetime when=deal.when;
      if(when>now) continue;
      const double value=deal.profit+deal.swap+deal.commission+deal.fee;
      if(!MathIsValidNumber(value))
        { QM_PanelResetPerformance(stats); stats.error="N/A (invalid deal value)"; return false; }
      if(when >= today_start)
         stats.account_today_pnl += value;
      const int index=QM_PanelTradeIndex(trades,deal.position_id);
      if(index<0) continue;
      if(deal.magic!=magic && (deal.entry==DEAL_ENTRY_IN || deal.entry==DEAL_ENTRY_INOUT))
         trades[index].ownership_conflict=true;
      if(when>=today_start) { stats.today_net+=value; stats.today_gross+=deal.profit; }
      if(when>=week_start) { stats.week_net+=value; stats.week_gross+=deal.profit; }
      trades[index].pnl += value;
      const ENUM_DEAL_ENTRY entry=deal.entry;
      if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY || entry == DEAL_ENTRY_INOUT)
        {
         trades[index].has_exit = true;
         if(when >= trades[index].close_time)
           {
            trades[index].close_time = when;
            trades[index].close_reason=deal.reason;
           }
        }
     }

   QMPanelTrade closed[];
   for(int i = 0; i < ArraySize(trades); ++i)
     {
      if(trades[i].ownership_conflict)
        {
         QM_PanelResetPerformance(stats);
         stats.error="N/A (mixed-magic netting history)";
         return false;
        }
      if(!trades[i].has_exit || QM_PanelIdentifierInSnapshot(open_ids,trades[i].position_id))
         continue;
      const int index = ArraySize(closed);
      if(ArrayResize(closed,index+1)!=index+1)
        { QM_PanelResetPerformance(stats); stats.error="N/A (history allocation failed)"; return false; }
      closed[index] = trades[i];
     }
   for(int i = 0; i < ArraySize(closed) - 1; ++i)
      for(int j = i + 1; j < ArraySize(closed); ++j)
         if(closed[j].close_time < closed[i].close_time ||
            (closed[j].close_time==closed[i].close_time && closed[j].position_id<closed[i].position_id))
           {
            QMPanelTrade swap = closed[i];
            closed[i] = closed[j];
            closed[j] = swap;
           }

   double curve = 0.0;
   double peak = 0.0;
   int run_wins = 0;
   int run_losses = 0;
   for(int i = 0; i < ArraySize(closed); ++i)
     {
      const double pnl = closed[i].pnl;
      ++stats.closed_total;
      if(closed[i].close_time >= today_start)
         ++stats.closed_today;
      if(closed[i].close_time>=week_start)
         ++stats.closed_week;
      if(closed[i].close_time >= attached_at)
         ++stats.closed_since_attach;
      stats.net_profit += pnl;
      if(stats.closed_total == 1 || pnl > stats.best_trade)
         stats.best_trade = pnl;
      if(stats.closed_total == 1 || pnl < stats.worst_trade)
         stats.worst_trade = pnl;
      if(pnl > 0.0)
        {
         ++stats.wins;
         stats.gross_profit += pnl;
         ++run_wins;
         run_losses = 0;
         stats.longest_win_streak = (int)MathMax(stats.longest_win_streak, run_wins);
        }
      else if(pnl < 0.0)
        {
         ++stats.losses;
         stats.gross_loss += pnl;
         ++run_losses;
         run_wins = 0;
         stats.longest_loss_streak = (int)MathMax(stats.longest_loss_streak, run_losses);
        }
      else
        {
         run_wins = 0;
         run_losses = 0;
        }
      curve += pnl;
      peak = MathMax(peak, curve);
      stats.max_drawdown_money = MathMax(stats.max_drawdown_money, peak - curve);
     }
   stats.max_drawdown_percent = start_equity > 0.0
      ? stats.max_drawdown_money / start_equity * 100.0 : 0.0;
   stats.current_win_streak = run_wins;
   stats.current_loss_streak = run_losses;
   stats.average_win = stats.wins > 0 ? stats.gross_profit / stats.wins : 0.0;
   stats.average_loss = stats.losses > 0 ? stats.gross_loss / stats.losses : 0.0;
   stats.profit_factor_infinite = stats.gross_profit > 0.0 && stats.gross_loss == 0.0;
   stats.profit_factor = stats.gross_loss < 0.0
      ? stats.gross_profit / MathAbs(stats.gross_loss) : 0.0;
   stats.expectancy = stats.closed_total > 0 ? stats.net_profit / stats.closed_total : 0.0;
   if(stats.closed_total > 0)
     {
      const int last = stats.closed_total - 1;
      stats.last_trade = closed[last].pnl;
      stats.last_trade_time = closed[last].close_time;
      stats.last_trade_reason = closed[last].close_reason;
     }
   stats.valid = true;
   stats.error = "";
   return true;
  }

bool QM_PanelBuildPerformance(const long magic,const datetime attached_at,
                              const double start_equity,QMPanelPerformance &stats)
  {
   QM_PanelResetPerformance(stats);
   const datetime now=TimeCurrent();
   if(!HistorySelect(0,now)) return false;
   const int count=HistoryDealsTotal();
   QMPanelDeal deals[];
   if(ArrayResize(deals,count)!=count) { stats.error="N/A (history allocation failed)"; return false; }
   int collected=0;
   for(int i=0;i<count;++i)
     {
      const ulong ticket=HistoryDealGetTicket(i);
      if(ticket==0) { stats.error="N/A (incomplete deal history)"; return false; }
      const long type=HistoryDealGetInteger(ticket,DEAL_TYPE);
      if(type!=DEAL_TYPE_BUY && type!=DEAL_TYPE_SELL) continue;
      QMPanelDeal item;
      item.position_id=(ulong)HistoryDealGetInteger(ticket,DEAL_POSITION_ID);
      item.magic=(long)HistoryDealGetInteger(ticket,DEAL_MAGIC);
      item.when=(datetime)HistoryDealGetInteger(ticket,DEAL_TIME);
      item.entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket,DEAL_ENTRY);
      item.reason=(ENUM_DEAL_REASON)HistoryDealGetInteger(ticket,DEAL_REASON);
      item.profit=HistoryDealGetDouble(ticket,DEAL_PROFIT);
      item.swap=HistoryDealGetDouble(ticket,DEAL_SWAP);
      item.commission=HistoryDealGetDouble(ticket,DEAL_COMMISSION);
      item.fee=HistoryDealGetDouble(ticket,DEAL_FEE);
      deals[collected++]=item;
     }
   ArrayResize(deals,collected);
   // Standalone balance/commission records without position provenance are
   // not guessed into this EA; trade-deal commission, swap and fee are included.
   ulong open_ids[];
   const int positions=PositionsTotal();
   if(ArrayResize(open_ids,positions)!=positions)
     { stats.error="N/A (position snapshot allocation failed)"; return false; }
   int open_count=0;
   for(int i=0;i<positions;++i)
     {
      const ulong ticket=PositionGetTicket(i);
      if(ticket>0 && PositionSelectByTicket(ticket))
         open_ids[open_count++]=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
     }
   ArrayResize(open_ids,open_count);
   return QM_PanelAggregatePerformance(deals,open_ids,magic,now,attached_at,start_equity,stats);
  }

string QM_PanelProfitFactorText(const QMPanelPerformance &stats)
  {
   if(stats.closed_total==0 || (stats.gross_profit==0.0 && stats.gross_loss==0.0)) return "N/A";
   return stats.profit_factor_infinite?"INF":QM_PanelFormatNumber(stats.profit_factor,2);
  }

string QM_PanelWinRateText(const QMPanelPerformance &stats)
  {
   return stats.closed_total>0?QM_PanelPercent((double)stats.wins/stats.closed_total*100.0):"N/A";
  }

string QM_PanelSLRiskText(const double money,const int unpriced,const double equity)
  {
   if(unpriced>0) return "UNPRICED - "+IntegerToString(unpriced)+" missing SL / contract";
   return (equity>0.0?QM_PanelPercent(money/equity*100.0):"N/A")+" | "+QM_PanelMoney(money);
  }


class CQMConsoleData
  {
private:
   long m_magic;
   datetime m_attached;
   double m_start_equity;
   ulong m_last_scan_ms;
   bool m_scanned;
   bool m_dirty;
   QMPanelPerformance m_stats;

   void AddExposure(QM_ConsoleSnapshot &snapshot,const ulong ticket,const bool pending)
     {
      const int i=ArraySize(snapshot.exposure);
      ArrayResize(snapshot.exposure,i+1);
      QM_ConsoleExposure item;
      item.ticket=ticket; item.pending=pending;
      if(pending)
        {
         const ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         item.buy=type==ORDER_TYPE_BUY_LIMIT || type==ORDER_TYPE_BUY_STOP || type==ORDER_TYPE_BUY_STOP_LIMIT;
         item.symbol=OrderGetString(ORDER_SYMBOL);
         item.opened=(datetime)OrderGetInteger(ORDER_TIME_SETUP);
         item.expires=(datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
         item.entry=OrderGetDouble(ORDER_PRICE_OPEN); item.sl=OrderGetDouble(ORDER_SL);
         item.tp=OrderGetDouble(ORDER_TP); item.lots=OrderGetDouble(ORDER_VOLUME_CURRENT);
         item.pnl=0.0;
        }
      else
        {
         item.buy=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
         item.symbol=PositionGetString(POSITION_SYMBOL);
         item.opened=(datetime)PositionGetInteger(POSITION_TIME); item.expires=0;
         item.entry=PositionGetDouble(POSITION_PRICE_OPEN); item.sl=PositionGetDouble(POSITION_SL);
         item.tp=PositionGetDouble(POSITION_TP); item.lots=PositionGetDouble(POSITION_VOLUME);
         item.pnl=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
        }
      const int digits=(int)SymbolInfoInteger(item.symbol,SYMBOL_DIGITS);
      item.entry_text=QM_PanelFormatNumber(item.entry,digits);
      item.sl_text=QM_PanelFormatNumber(item.sl,digits);
      item.tp_text=QM_PanelFormatNumber(item.tp,digits);
      snapshot.exposure[i]=item;
      // Adapt to actual exposure. No fixed empty position/order slots.
      if(i>=3) return;
      const string label=(pending?"Pending ":"Position ")+IntegerToString(i+1);
      QM_ConsoleAddLine(snapshot.live,label,item.symbol+" "+(item.buy?"BUY ":"SELL ")+
         QM_PanelFormatNumber(item.lots,2)+" lot",QM_GATE_WAIT);
      QM_ConsoleAddLine(snapshot.live,"Entry / SL / TP",
         QM_PanelFormatNumber(item.entry,digits)+" / "+
         (item.sl>0.0?QM_PanelFormatNumber(item.sl,digits):"N/A")+" / "+
         (item.tp>0.0?QM_PanelFormatNumber(item.tp,digits):"N/A"));
      QM_ConsoleAddLine(snapshot.live,pending?"Expiry":"Floating / duration",
         pending?(item.expires>0?QM_PanelDateTime(item.expires)+" BT":"GTC"):
         QM_PanelMoney(item.pnl,true)+" | "+QM_PanelDuration((long)(TimeCurrent()-item.opened)),
         pending?QM_GATE_NA:(item.pnl<0.0?QM_GATE_BLOCK:QM_GATE_PASS));
     }

public:
   CQMConsoleData() { m_magic=0; m_attached=0; m_start_equity=0.0; m_last_scan_ms=0;
      m_scanned=false; m_dirty=true; QM_PanelResetPerformance(m_stats); }
   void Initialize(const long magic)
     {
      m_magic=magic; m_attached=TimeCurrent(); m_start_equity=AccountInfoDouble(ACCOUNT_EQUITY);
      m_scanned=false; m_dirty=true; m_last_scan_ms=0;
     }
   void Invalidate() { m_dirty=true; }
   void Populate(QM_ConsoleSnapshot &snapshot)
     {
      if(MQLInfoInteger(MQL_TESTER)!=0 || MQLInfoInteger(MQL_OPTIMIZATION)!=0) return;
      const ulong now_ms=GetTickCount64();
      // Invalidation never bypasses the hard minimum, including a burst of deals.
      if(!m_scanned || now_ms-m_last_scan_ms>=QM_PANEL_REFRESH_SECONDS*1000)
        {
         QM_PanelBuildPerformance(m_magic,m_attached,m_start_equity,m_stats);
         m_last_scan_ms=now_ms; m_scanned=true; m_dirty=false;
        }
      double open_risk=0.0,pending_risk=0.0;
      int unpriced=0,pending_unpriced=0;
      for(int i=PositionsTotal()-1;i>=0;--i)
        {
         const ulong ticket=PositionGetTicket(i);
         if(ticket==0 || !PositionSelectByTicket(ticket) ||
            (long)PositionGetInteger(POSITION_MAGIC)!=m_magic) continue;
         ++snapshot.positions;
         const double sl=PositionGetDouble(POSITION_SL);
         double projected=0.0;
         const ENUM_ORDER_TYPE type=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
         if(sl<=0.0 || !OrderCalcProfit(type,PositionGetString(POSITION_SYMBOL),
            PositionGetDouble(POSITION_VOLUME),PositionGetDouble(POSITION_PRICE_OPEN),sl,projected))
            ++unpriced;
         else open_risk+=MathMax(0.0,-projected);
         AddExposure(snapshot,ticket,false);
        }
      for(int i=OrdersTotal()-1;i>=0;--i)
        {
         const ulong ticket=OrderGetTicket(i);
         if(ticket==0 || !OrderSelect(ticket) || (long)OrderGetInteger(ORDER_MAGIC)!=m_magic) continue;
         const ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         const datetime expiry=(datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
          if(type<ORDER_TYPE_BUY_LIMIT || type>ORDER_TYPE_SELL_STOP_LIMIT ||
             OrderGetDouble(ORDER_VOLUME_CURRENT)<=0.0 || (expiry>0 && expiry<=TimeCurrent())) continue;
          ++snapshot.pending_orders;
          const bool buy=type==ORDER_TYPE_BUY_LIMIT || type==ORDER_TYPE_BUY_STOP || type==ORDER_TYPE_BUY_STOP_LIMIT;
          const double sl=OrderGetDouble(ORDER_SL);
          double projected=0.0;
          if(sl<=0.0 || !OrderCalcProfit(buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,
             OrderGetString(ORDER_SYMBOL),OrderGetDouble(ORDER_VOLUME_CURRENT),
             OrderGetDouble(ORDER_PRICE_OPEN),sl,projected)) ++pending_unpriced;
          else pending_risk+=MathMax(0.0,-projected);
          AddExposure(snapshot,ticket,true);
        }
      if(ArraySize(snapshot.exposure)>3)
         QM_ConsoleAddLine(snapshot.live,"Additional exposure",IntegerToString(ArraySize(snapshot.exposure)-3)+" more");
      const double equity=AccountInfoDouble(ACCOUNT_EQUITY);
      // Entry-to-SL price risk, excluding future slippage and commission. This
      // is not current-equity-to-stop drawdown and not an FTMO loss allowance.
      QM_ConsoleAddLine(snapshot.risk,"Position SL risk",QM_PanelSLRiskText(open_risk,unpriced,equity),
         unpriced>0?QM_GATE_WARN:QM_GATE_NA);
      if(snapshot.pending_orders>0)
         QM_ConsoleAddLine(snapshot.risk,"Pending SL risk",QM_PanelSLRiskText(pending_risk,pending_unpriced,equity),
            pending_unpriced>0?QM_GATE_WARN:QM_GATE_NA);
      if(!m_stats.valid)
        {
         snapshot.today=m_stats.error; snapshot.week=snapshot.today;
         QM_ConsoleAddLine(snapshot.performance,"History",m_stats.error,QM_GATE_WARN);
         return;
        }
      snapshot.today=IntegerToString(m_stats.closed_today)+" closed | net "+QM_PanelMoney(m_stats.today_net,true);
      snapshot.week=IntegerToString(m_stats.closed_week)+" closed | net "+QM_PanelMoney(m_stats.week_net,true);
      const double net_pct=m_start_equity>0.0?m_stats.net_profit/m_start_equity*100.0:0.0;
      QM_ConsoleAddLine(snapshot.performance,"History scope","Closed positions | available history");
      QM_ConsoleAddLine(snapshot.performance,"Closed today / attach / all",StringFormat("%d / %d / %d",m_stats.closed_today,m_stats.closed_since_attach,m_stats.closed_total));
      QM_ConsoleAddLine(snapshot.performance,"Wins / losses | win rate",StringFormat("%d / %d | %s",m_stats.wins,m_stats.losses,QM_PanelWinRateText(m_stats)));
      QM_ConsoleAddLine(snapshot.performance,"Net closed P/L | attach equity",QM_PanelMoney(m_stats.net_profit,true)+" | "+
         (m_start_equity>0.0?QM_PanelPercent(net_pct,true):"N/A"),
         m_stats.net_profit<0.0?QM_GATE_BLOCK:(m_stats.net_profit>0.0?QM_GATE_PASS:QM_GATE_NA));
      QM_ConsoleAddLine(snapshot.performance,"Winning / losing net P/L",QM_PanelMoney(m_stats.gross_profit,true)+" / "+QM_PanelMoney(m_stats.gross_loss));
      QM_ConsoleAddLine(snapshot.performance,"Profit factor / expectancy",QM_PanelProfitFactorText(m_stats)+" / "+
         (m_stats.closed_total>0?QM_PanelMoney(m_stats.expectancy,true):"N/A"));
      QM_ConsoleAddLine(snapshot.performance,"Average win / loss",(m_stats.wins>0?QM_PanelMoney(m_stats.average_win,true):"N/A")+" / "+
         (m_stats.losses>0?QM_PanelMoney(m_stats.average_loss):"N/A"));
      QM_ConsoleAddLine(snapshot.performance,"Closed-trade DD | attach equity",m_stats.closed_total>0?
         QM_PanelMoney(m_stats.max_drawdown_money)+" | "+(m_start_equity>0.0?QM_PanelPercent(m_stats.max_drawdown_percent):"N/A"):"N/A");
      QM_ConsoleAddLine(snapshot.performance,"Streaks now / longest",StringFormat("W%d L%d / W%d L%d",m_stats.current_win_streak,m_stats.current_loss_streak,m_stats.longest_win_streak,m_stats.longest_loss_streak));
      QM_ConsoleAddLine(snapshot.performance,"Best / worst",m_stats.closed_total>0?
         QM_PanelMoney(m_stats.best_trade,true)+" / "+QM_PanelMoney(m_stats.worst_trade):"N/A");
      QM_ConsoleAddLine(snapshot.performance,"Last closed trade",m_stats.closed_total>0?QM_PanelMoney(m_stats.last_trade,true)+" | "+QM_PanelDateTime(m_stats.last_trade_time)+" BT":"No closed trades");
      QM_ConsoleAddLine(snapshot.performance,"Account balance / equity",QM_PanelMoney(AccountInfoDouble(ACCOUNT_BALANCE))+" / "+QM_PanelMoney(equity));
     }
  };

#endif
