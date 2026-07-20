//+------------------------------------------------------------------+
//| QM_AccountMonitor.mq5                                            |
//| QuantMechanica V5 - read-only account monitor                    |
//|                                                                  |
//| PURPOSE                                                          |
//|   The DXZ journal lacks per-trade $ attribution: server-side     |
//|   SL/TP fills emit no client events and the deal-history export  |
//|   template ships empty. This tool closes that gap. It NEVER      |
//|   trades - there is not a single OrderSend / trade call. It only |
//|   reads account + deal history and writes evidence files.        |
//|                                                                  |
//| OUTPUTS (all under <terminal>\MQL5\Files\<InpJournalDir>\)       |
//|   live_deals_normalized.csv  incremental, append-only deal rows  |
//|   account_snapshot.json      overwritten each timer tick         |
//|   monitor_state.json         last-exported deal checkpoint       |
//|                                                                  |
//| CSV HEADER matches the existing consumer template found at       |
//|   D:\QM\reports\portfolio\dxz_live_blend_v1_template_*\          |
//|      live_deals_normalized.csv                                   |
//|   (first 14 cols byte-identical). Extra deal fields the template |
//|   lacks are APPENDED additively (magic,type,volume,price,order,  |
//|   time_broker,comment) so the dxz_live_blend_reweight input      |
//|   loader (which needs type/volume/magic) is satisfied too.       |
//|   logical_magic / risk_percent_in_force / net_per_1pct_risk are  |
//|   left blank - they are computed downstream in python.           |
//|                                                                  |
//| TESTER-HARDENED (OWNER hard requirement): under MQL_TESTER,      |
//|   OnInit returns INIT_SUCCEEDED and arms NOTHING - no timer, no  |
//|   panel, no files, zero graphics objects. Every entry point      |
//|   early-returns in the tester.                                   |
//+------------------------------------------------------------------+
#property copyright "QuantMechanica V5"
#property version   "1.00"
#property strict
#property description "QM Account Monitor - read-only deal-history exporter + light panel. NOT a trading EA (zero OrderSend/trade calls)."

#include <Controls/Dialog.mqh>
#include <Controls/Label.mqh>
#include <QM/QM_ChartTheme.mqh>

//--- inputs
input int    InpTimerSeconds = 60;             // timer period (seconds, >=5)
input string InpJournalDir   = "QM\\journal";  // output dir under MQL5\Files
input bool   InpShowPanel    = true;           // draw the on-chart panel

//--- CSV contract (first 14 cols == existing template; rest additive)
#define QM_MON_CSV_HEADER "deal_id,position_id,time_utc,entry,deal_magic,logical_magic,symbol,profit,swap,commission,fee,net_actual,risk_percent_in_force,net_per_1pct_risk,magic,type,volume,price,order,time_broker,comment"

//--- state
bool     g_in_tester       = false;
bool     g_armed           = false;
bool     g_panel_ok        = false;
ulong    g_last_deal_ticket = 0;
datetime g_last_deal_time   = 0;   // broker/server time of last exported deal
datetime g_last_export_utc  = 0;
bool     g_last_write_ok    = true;
int      g_srv_utc_offset   = 0;   // seconds: server_time - gmt (see time caveat)
string   g_status           = "INIT";

//+------------------------------------------------------------------+
//| Small light panel (CAppDialog, standard-lib light frame).        |
//+------------------------------------------------------------------+
class CQMMonitorPanel : public CAppDialog
  {
private:
   CLabel            m_title;
   CLabel            m_k_equity,  m_v_equity;
   CLabel            m_k_balance, m_v_balance;
   CLabel            m_k_daily,   m_v_daily;
   CLabel            m_k_pos,     m_v_pos;
   CLabel            m_k_export,  m_v_export;
   CLabel            m_k_status,  m_v_status;
   double            m_scale;

   int               S(const int px) const { return (int)MathRound(px * m_scale); }
   bool              MakeLabel(CLabel &lbl, const string suffix, const int x1, const int y1,
                               const int x2, const int y2, const string text,
                               const color clr, const string font, const int fsize);
   bool              Row(CLabel &k, CLabel &v, const string suffix, const int y, const string ktext);

public:
                     CQMMonitorPanel(void) { m_scale = 1.0; }
   bool              BuildPanel(const long chart, const string name, const int subwin);
   void              SetEquity(const double v)          { m_v_equity.Text(Money2(v)); }
   void              SetBalance(const double v)         { m_v_balance.Text(Money2(v)); }
   void              SetDaily(const double v, const int trades);
   void              SetPositions(const int n)          { m_v_pos.Text(IntegerToString(n)); }
   void              SetExport(const string ts)         { m_v_export.Text(ts); }
   void              SetStatus(const string s, const bool ok);
  };

//--- fwd decls for helpers used by the panel inline methods
string Money2(const double v);
string SignedMoney2(const double v);

//+------------------------------------------------------------------+
bool CQMMonitorPanel::MakeLabel(CLabel &lbl, const string suffix, const int x1, const int y1,
                                const int x2, const int y2, const string text,
                                const color clr, const string font, const int fsize)
  {
   if(!lbl.Create(m_chart_id, m_name + suffix, m_subwin, x1, y1, x2, y2))
      return false;
   if(!Add(lbl))
      return false;
   lbl.Text(text);
   lbl.Color(clr);
   lbl.Font(font);
   lbl.FontSize(fsize);
   return true;
  }

//+------------------------------------------------------------------+
bool CQMMonitorPanel::Row(CLabel &k, CLabel &v, const string suffix, const int y, const string ktext)
  {
   if(!MakeLabel(k, "k_" + suffix, S(10),  S(y), S(112), S(y + 18), ktext, QM_THEME_MUTED,
                 QM_THEME_FONT, QM_THEME_FONT_SIZE_NORMAL))
      return false;
   if(!MakeLabel(v, "v_" + suffix, S(118), S(y), S(238), S(y + 18), "-", QM_THEME_TEXT,
                 QM_THEME_FONT_MONO, QM_THEME_FONT_SIZE_NORMAL))
      return false;
   return true;
  }

//+------------------------------------------------------------------+
bool CQMMonitorPanel::BuildPanel(const long chart, const string name, const int subwin)
  {
   m_scale = (double)TerminalInfoInteger(TERMINAL_SCREEN_DPI) / 96.0;
   if(m_scale < 1.0)
      m_scale = 1.0;

   const int w = S(250);
   const int h = S(218);
   if(!Create(chart, name, subwin, 20, 40, 20 + w, 40 + h))
      return false;

   if(!MakeLabel(m_title, "title", S(10), S(6), S(240), S(28), "QM Account Monitor",
                 QM_THEME_TEXT, QM_THEME_FONT, QM_THEME_FONT_SIZE_TITLE))
      return false;

   if(!Row(m_k_equity,  m_v_equity,  "eq",  36,  "Equity"))         return false;
   if(!Row(m_k_balance, m_v_balance, "bal", 60,  "Balance"))        return false;
   if(!Row(m_k_daily,   m_v_daily,   "day", 84,  "Daily P&L"))      return false;
   if(!Row(m_k_pos,     m_v_pos,     "pos", 108, "Open Positions")) return false;
   if(!Row(m_k_export,  m_v_export,  "exp", 132, "Last Export"))    return false;
   if(!Row(m_k_status,  m_v_status,  "st",  156, "Status"))         return false;

   return true;
  }

//+------------------------------------------------------------------+
void CQMMonitorPanel::SetDaily(const double v, const int trades)
  {
   m_v_daily.Text(SignedMoney2(v) + "  (" + IntegerToString(trades) + ")");
   m_v_daily.Color(QM_ThemePnlColor(v));
  }

//+------------------------------------------------------------------+
void CQMMonitorPanel::SetStatus(const string s, const bool ok)
  {
   m_v_status.Text(s);
   m_v_status.Color(ok ? QM_THEME_PROFIT : QM_THEME_LOSS);
  }

CQMMonitorPanel g_panel;

//+------------------------------------------------------------------+
//| Formatting helpers                                               |
//+------------------------------------------------------------------+
string Money2(const double v)       { return DoubleToString(v, 2); }
string SignedMoney2(const double v) { return (v > 0.0) ? "+" + DoubleToString(v, 2) : DoubleToString(v, 2); }

string FormatIsoUtc(const datetime t)
  {
   MqlDateTime s;
   TimeToStruct(t, s);
   return StringFormat("%04d-%02d-%02dT%02d:%02d:%02dZ", s.year, s.mon, s.day, s.hour, s.min, s.sec);
  }

// panel-only short form: full ISO overflows the 250px dialog (labels don't clip)
string FormatPanelUtc(const datetime t)
  {
   MqlDateTime s;
   TimeToStruct(t, s);
   return StringFormat("%02d.%02d %02d:%02d:%02dZ", s.day, s.mon, s.hour, s.min, s.sec);
  }

string FormatBroker(const datetime t)
  {
   MqlDateTime s;
   TimeToStruct(t, s);
   return StringFormat("%04d-%02d-%02d %02d:%02d:%02d", s.year, s.mon, s.day, s.hour, s.min, s.sec);
  }

datetime BrokerToUtc(const datetime broker_time)
  {
   return broker_time - g_srv_utc_offset;
  }

string EntryToStr(const long e)
  {
   switch((int)e)
     {
      case DEAL_ENTRY_IN:     return "IN";
      case DEAL_ENTRY_OUT:    return "OUT";
      case DEAL_ENTRY_INOUT:  return "INOUT";
      case DEAL_ENTRY_OUT_BY: return "OUT_BY";
     }
   return "IN";   // non-trade deals report DEAL_ENTRY_IN(0); ignored downstream by type
  }

string TypeToStr(const long t)
  {
   switch((int)t)
     {
      case DEAL_TYPE_BUY:                      return "BUY";
      case DEAL_TYPE_SELL:                     return "SELL";
      case DEAL_TYPE_BALANCE:                  return "BALANCE";
      case DEAL_TYPE_CREDIT:                   return "CREDIT";
      case DEAL_TYPE_CHARGE:                   return "CHARGE";
      case DEAL_TYPE_CORRECTION:               return "CORRECTION";
      case DEAL_TYPE_BONUS:                    return "BONUS";
      case DEAL_TYPE_COMMISSION:               return "COMMISSION";
      case DEAL_TYPE_COMMISSION_DAILY:         return "COMMISSION_DAILY";
      case DEAL_TYPE_COMMISSION_MONTHLY:       return "COMMISSION_MONTHLY";
      case DEAL_TYPE_COMMISSION_AGENT_DAILY:   return "COMMISSION_AGENT_DAILY";
      case DEAL_TYPE_COMMISSION_AGENT_MONTHLY: return "COMMISSION_AGENT_MONTHLY";
      case DEAL_TYPE_INTEREST:                 return "INTEREST";
      case DEAL_TYPE_BUY_CANCELED:             return "BUY_CANCELED";
      case DEAL_TYPE_SELL_CANCELED:            return "SELL_CANCELED";
      case DEAL_DIVIDEND:                      return "DIVIDEND";
      case DEAL_DIVIDEND_FRANKED:              return "DIVIDEND_FRANKED";
      case DEAL_TAX:                           return "TAX";
     }
   return StringFormat("DEAL_TYPE_%d", (int)t);
  }

//--- CSV-escape a free-text field (ASCII-only, quote if needed)
string CsvEsc(const string in)
  {
   string out = "";
   bool   need_quote = false;
   const int n = StringLen(in);
   for(int i = 0; i < n; ++i)
     {
      ushort c = StringGetCharacter(in, i);
      if(c < 32 || c > 126)
         c = 32;                       // control / non-ascii -> space
      if(c == '"')
        {
         out += "\"\"";                // escape embedded quote
         need_quote = true;
         continue;
        }
      if(c == ',')
         need_quote = true;
      out += ShortToString(c);
     }
   if(need_quote)
      return "\"" + out + "\"";
   return out;
  }

//+------------------------------------------------------------------+
//| Atomic-ish write: temp file then FileMove(overwrite).            |
//+------------------------------------------------------------------+
bool WriteAllAtomic(const string tmp, const string dst, const string content)
  {
   int h = FileOpen(tmp, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
   if(h == INVALID_HANDLE)
      return false;
   FileWriteString(h, content);
   FileFlush(h);
   FileClose(h);

   if(FileMove(tmp, 0, dst, FILE_REWRITE))
      return true;

   // Fallback: direct overwrite if move failed for any reason.
   if(FileIsExist(tmp))
      FileDelete(tmp);
   int h2 = FileOpen(dst, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
   if(h2 == INVALID_HANDLE)
      return false;
   FileWriteString(h2, content);
   FileFlush(h2);
   FileClose(h2);
   return true;
  }

//--- minimal JSON integer extractor for our own state format
string JsonNum(const string js, const string key)
  {
   const string pat = "\"" + key + "\"";
   int p = StringFind(js, pat);
   if(p < 0)
      return "0";
   p = StringFind(js, ":", p);
   if(p < 0)
      return "0";
   p++;
   const int n = StringLen(js);
   string num = "";
   while(p < n)
     {
      ushort c = StringGetCharacter(js, p);
      if(c == ' ' || c == '\t') { p++; continue; }
      break;
     }
   while(p < n)
     {
      ushort c = StringGetCharacter(js, p);
      if((c >= '0' && c <= '9') || c == '-')
        {
         num += ShortToString(c);
         p++;
        }
      else
         break;
     }
   return (StringLen(num) == 0) ? "0" : num;
  }

//+------------------------------------------------------------------+
//| Checkpoint persistence                                           |
//+------------------------------------------------------------------+
void LoadState()
  {
   const string path = InpJournalDir + "\\monitor_state.json";
   if(!FileIsExist(path))
      return;
   int h = FileOpen(path, FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
   if(h == INVALID_HANDLE)
      return;
   string content = "";
   while(!FileIsEnding(h))
      content += FileReadString(h);
   FileClose(h);

   g_last_deal_ticket = (ulong)StringToInteger(JsonNum(content, "last_deal_ticket"));
   g_last_deal_time   = (datetime)StringToInteger(JsonNum(content, "last_deal_time_broker"));
  }

bool SaveState()
  {
   const string js = StringFormat(
      "{\n  \"last_deal_ticket\": %I64u,\n  \"last_deal_time_broker\": %I64d,\n  \"last_export_utc\": \"%s\",\n  \"updated_utc\": \"%s\"\n}\n",
      g_last_deal_ticket, (long)g_last_deal_time,
      (g_last_export_utc > 0 ? FormatIsoUtc(g_last_export_utc) : ""), FormatIsoUtc(TimeGMT()));
   return WriteAllAtomic(InpJournalDir + "\\monitor_state.json.tmp",
                         InpJournalDir + "\\monitor_state.json", js);
  }

//+------------------------------------------------------------------+
//| Append newly-collected deal rows to the CSV (header if new).     |
//+------------------------------------------------------------------+
bool AppendCsv(const string rows)
  {
   const string path = InpJournalDir + "\\live_deals_normalized.csv";
   int h = FileOpen(path, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ | FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE)
      return false;
   const ulong sz = FileSize(h);
   if(sz == 0)
      FileWriteString(h, QM_MON_CSV_HEADER + "\r\n");
   else
      FileSeek(h, 0, SEEK_END);
   FileWriteString(h, rows);
   FileFlush(h);
   FileClose(h);
   return true;
  }

//+------------------------------------------------------------------+
//| Incremental deal export.                                         |
//+------------------------------------------------------------------+
void ExportNewDeals()
  {
   const datetime from = (g_last_deal_time > 0) ? g_last_deal_time : 0;
   const datetime to   = TimeCurrent() + 3600;   // small forward buffer
   if(!HistorySelect(from, to))
     {
      g_last_write_ok = false;
      return;
     }

   const int total = HistoryDealsTotal();
   if(total <= 0)
      return;

   string  rows       = "";
   int     appended   = 0;
   ulong   max_ticket = g_last_deal_ticket;
   datetime max_time  = g_last_deal_time;

   for(int i = 0; i < total; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(deal <= g_last_deal_ticket)
         continue;   // already exported (ticket filter dedups the boundary window)

      const long     d_order  = (long)HistoryDealGetInteger(deal, DEAL_ORDER);
      const datetime d_time   = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);   // broker time
      const long     d_type   = (long)HistoryDealGetInteger(deal, DEAL_TYPE);
      const long     d_entry  = (long)HistoryDealGetInteger(deal, DEAL_ENTRY);
      const long     d_magic  = (long)HistoryDealGetInteger(deal, DEAL_MAGIC);
      const long     d_posid  = (long)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      const string   d_symbol = HistoryDealGetString(deal, DEAL_SYMBOL);
      const string   d_comm_s = HistoryDealGetString(deal, DEAL_COMMENT);
      const double   d_vol    = HistoryDealGetDouble(deal, DEAL_VOLUME);
      const double   d_price  = HistoryDealGetDouble(deal, DEAL_PRICE);
      const double   d_comm   = HistoryDealGetDouble(deal, DEAL_COMMISSION);
      const double   d_swap   = HistoryDealGetDouble(deal, DEAL_SWAP);
      const double   d_profit = HistoryDealGetDouble(deal, DEAL_PROFIT);
      const double   d_fee    = HistoryDealGetDouble(deal, DEAL_FEE);
      const double   d_net    = d_profit + d_swap + d_comm + d_fee;

      string row = "";
      row += (string)deal + ",";                       // deal_id
      row += (string)d_posid + ",";                    // position_id
      row += FormatIsoUtc(BrokerToUtc(d_time)) + ",";  // time_utc
      row += EntryToStr(d_entry) + ",";                // entry
      row += (string)d_magic + ",";                    // deal_magic (raw)
      row += ",";                                      // logical_magic (downstream)
      row += CsvEsc(d_symbol) + ",";                   // symbol
      row += DoubleToString(d_profit, 2) + ",";        // profit
      row += DoubleToString(d_swap, 2) + ",";          // swap
      row += DoubleToString(d_comm, 2) + ",";          // commission
      row += DoubleToString(d_fee, 2) + ",";           // fee
      row += DoubleToString(d_net, 2) + ",";           // net_actual
      row += ",";                                      // risk_percent_in_force (downstream)
      row += ",";                                      // net_per_1pct_risk (downstream)
      row += (string)d_magic + ",";                    // magic (alias for reweight loader)
      row += TypeToStr(d_type) + ",";                  // type
      row += DoubleToString(d_vol, 2) + ",";           // volume
      row += DoubleToString(d_price, 5) + ",";         // price
      row += (string)d_order + ",";                    // order
      row += FormatBroker(d_time) + ",";               // time_broker
      row += CsvEsc(d_comm_s);                         // comment
      rows += row + "\r\n";

      appended++;
      if(deal > max_ticket)
         max_ticket = deal;
      if(d_time > max_time)
         max_time = d_time;
     }

   if(appended == 0)
      return;

   if(!AppendCsv(rows))
     {
      g_last_write_ok = false;   // retry next tick; checkpoint intentionally NOT advanced
      return;
     }

   g_last_deal_ticket = max_ticket;
   g_last_deal_time   = max_time;
   g_last_export_utc  = TimeGMT();
   g_last_write_ok    = true;
   SaveState();
  }

//+------------------------------------------------------------------+
//| Daily realized P&L, the Account-Protector way.                   |
//+------------------------------------------------------------------+
double DailyRealizedPnl(int &trades)
  {
   trades = 0;
   const datetime srv = TimeTradeServer();
   MqlDateTime st;
   TimeToStruct(srv, st);
   st.hour = 0;
   st.min  = 0;
   st.sec  = 0;
   const datetime day_start = StructToTime(st);   // broker-day midnight

   if(!HistorySelect(day_start, srv + 3600))
      return 0.0;

   double pnl = 0.0;
   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      const long type = (long)HistoryDealGetInteger(deal, DEAL_TYPE);
      if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL)
         continue;
      pnl += HistoryDealGetDouble(deal, DEAL_PROFIT);
      pnl += HistoryDealGetDouble(deal, DEAL_COMMISSION);
      pnl += HistoryDealGetDouble(deal, DEAL_SWAP);
      trades++;
     }
   return pnl;
  }

//+------------------------------------------------------------------+
//| Snapshot JSON + panel refresh.                                   |
//+------------------------------------------------------------------+
void RefreshSnapshotAndPanel()
  {
   const double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   const double margin  = AccountInfoDouble(ACCOUNT_MARGIN);
   const double freem   = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   const double mlevel  = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   const long   login   = AccountInfoInteger(ACCOUNT_LOGIN);
   const string ccy     = AccountInfoString(ACCOUNT_CURRENCY);

   double floating = 0.0;
   const int openpos = PositionsTotal();
   for(int i = 0; i < openpos; ++i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      floating += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }

   int    daily_trades = 0;
   const double daily  = DailyRealizedPnl(daily_trades);

   const datetime srv = TimeTradeServer();
   const datetime utc = TimeGMT();

   const string js = StringFormat(
      "{\n"
      "  \"account_login\": %I64d,\n"
      "  \"currency\": \"%s\",\n"
      "  \"time_utc\": \"%s\",\n"
      "  \"server_time_broker\": \"%s\",\n"
      "  \"equity\": %.2f,\n"
      "  \"balance\": %.2f,\n"
      "  \"margin\": %.2f,\n"
      "  \"free_margin\": %.2f,\n"
      "  \"margin_level\": %.2f,\n"
      "  \"floating_pnl\": %.2f,\n"
      "  \"open_positions\": %d,\n"
      "  \"daily_pnl\": %.2f,\n"
      "  \"daily_trades\": %d,\n"
      "  \"last_export_utc\": \"%s\",\n"
      "  \"last_deal_ticket\": %I64u,\n"
      "  \"write_ok\": %s\n"
      "}\n",
      login, ccy, FormatIsoUtc(utc), FormatBroker(srv),
      equity, balance, margin, freem, mlevel, floating, openpos,
      daily, daily_trades,
      (g_last_export_utc > 0 ? FormatIsoUtc(g_last_export_utc) : ""),
      g_last_deal_ticket, (g_last_write_ok ? "true" : "false"));

   const bool snap_ok = WriteAllAtomic(InpJournalDir + "\\account_snapshot.json.tmp",
                                       InpJournalDir + "\\account_snapshot.json", js);
   if(!snap_ok)
      g_last_write_ok = false;

   g_status = g_last_write_ok ? "OK" : "WRITE ERROR (retry)";

   if(g_panel_ok)
     {
      g_panel.SetEquity(equity);
      g_panel.SetBalance(balance);
      g_panel.SetDaily(daily, daily_trades);
      g_panel.SetPositions(openpos);
      g_panel.SetExport(g_last_export_utc > 0 ? FormatPanelUtc(g_last_export_utc) : "-");
      g_panel.SetStatus(g_status, g_last_write_ok);
     }
  }

//+------------------------------------------------------------------+
//| Core work unit (timer + initial refresh share this).            |
//+------------------------------------------------------------------+
void DoWork()
  {
   const datetime srv = TimeTradeServer();
   const datetime gmt = TimeGMT();
   g_srv_utc_offset = (srv > 0 && gmt > 0) ? (int)(srv - gmt) : 0;

   ExportNewDeals();
   RefreshSnapshotAndPanel();
  }

//+------------------------------------------------------------------+
//| Entry points                                                     |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_in_tester = (MQLInfoInteger(MQL_TESTER) != 0);
   if(g_in_tester)
      return INIT_SUCCEEDED;   // TESTER-HARDENED: arm nothing, touch nothing.

   g_armed = true;

   // Light scheme on the host chart (helper self-guards against tester).
   QM_ThemeApplyChart(ChartID());

   LoadState();

   if(InpShowPanel)
     {
      if(g_panel.BuildPanel(ChartID(), "QM_AcctMon", 0))
        {
         g_panel.Run();
         g_panel_ok = true;
        }
      else
        {
         Print("QM_AccountMonitor: panel build failed, err=", GetLastError());
        }
     }

   int secs = InpTimerSeconds;
   if(secs < 5)
      secs = 5;
   EventSetTimer(secs);

   DoWork();   // immediate first export + snapshot
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(g_in_tester)
      return;
   EventKillTimer();
   if(g_panel_ok)
      g_panel.Destroy(reason);
   ChartRedraw();
  }

void OnTimer()
  {
   if(g_in_tester)
      return;
   DoWork();
  }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(g_in_tester)
      return;
   if(g_panel_ok)
      g_panel.ChartEvent(id, lparam, dparam, sparam);
  }
//+------------------------------------------------------------------+
