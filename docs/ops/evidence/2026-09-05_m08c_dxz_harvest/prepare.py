"""Derive the bounded native-history measurement from the reviewed M08-B script."""
from pathlib import Path
import difflib
import hashlib
import json

out = Path(__file__).resolve().parent
prior = out.parent / '2026-09-05_m08b_dxz_harvest'
source = (prior / 'QM_M1_SpreadHarvest.mq5').read_text(encoding='utf-8-sig')
text = source.replace("D'2026.05.26 00:00'", "D'2026.05.20 00:00'").replace('#define QM_COPY_ATTEMPTS 40', '#define QM_COPY_ATTEMPTS 3')
text = text.replace('CopyRates(symbol, PERIOD_M1, 0, 2000000, rates)', 'CopyRates(symbol, PERIOD_M1, start_time, end_time, rates)')
start = text.index('datetime ResolveHistoryStart(')
end = text.index('\nbool HarvestSymbol(', start)
text = text[:start] + r'''datetime ResolveHistoryStart(const string symbol, const string output_tag)
  {
   const string path=QM_HARVEST_DIRECTORY+"\\"+output_tag+"_"+SafeSymbolToken(symbol)+"_download.json";
   const int handle=FileOpen(path,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(handle==INVALID_HANDLE) return 0;
   const ulong deadline=GetTickCount64()+240000;
   datetime first=0,last=0;
   string attempts="";
   const datetime before=(datetime)SeriesInfoInteger(symbol,PERIOD_M1,SERIES_LASTBAR_DATE);
   for(int attempt=0;attempt<6 && GetTickCount64()<deadline && !IsStopped();++attempt)
     {
      MqlRates rates[];
      ArraySetAsSeries(rates,false);
      ResetLastError();
      // A date-bounded native request initiates server downloading (MQL5 CopyRates contract).
      const int copied=CopyRates(symbol,PERIOD_M1,InpFromServer,InpToServer-60,rates);
      const int error=GetLastError();
      if(copied>0) { first=rates[0].time; last=rates[copied-1].time; }
      if(attempt>0) attempts+=",";
      attempts+=StringFormat("{\"attempt\":%d,\"copied\":%d,\"error\":%d,\"first_server\":\"%s\",\"last_server\":\"%s\",\"connected\":%d}",attempt+1,copied,error,IsoServerMinute(first),IsoServerMinute(last),(int)TerminalInfoInteger(TERMINAL_CONNECTED));
      FileFlush(handle);
      if(first>0 && first<InpFromServer+86400 && last>=D'2026.09.04 00:00') break;
      Sleep(2000);
     }
   string payload=StringFormat("{\"schema\":\"qm.m08c-native-download/v1\",\"symbol\":\"%s\",\"is_custom\":%d,\"before_last_server\":\"%s\",\"server_first\":\"%s\",\"cache_last_server\":\"%s\",\"window_start_server\":\"%s\",\"window_end_server\":\"%s\",\"point_size\":%.10f,\"attempts\":[%s]}",symbol,(int)SymbolInfoInteger(symbol,SYMBOL_CUSTOM),IsoServerMinute(before),IsoServerMinute((datetime)SeriesInfoInteger(symbol,PERIOD_M1,SERIES_SERVER_FIRSTDATE)),IsoServerMinute((datetime)SeriesInfoInteger(symbol,PERIOD_M1,SERIES_LASTBAR_DATE)),IsoServerMinute(InpFromServer),IsoServerMinute(InpToServer),SymbolInfoDouble(symbol,SYMBOL_POINT),attempts);
   FileWriteString(handle,payload+"\n"); FileFlush(handle); FileClose(handle);
   return first;
  }

''' + text[end:]
# Put refusals after artifact names are known, so every symbol has an explicit outcome.
select_start=text.index('   if(!SymbolSelect(',text.index('bool HarvestSymbol('))
select_end=text.index('   datetime end_time',select_start)
text=text[:select_start]+text[select_end:]
marker='   long bar_count = 0;'
where=text.index(marker,text.index('bool HarvestSymbol('))
text=text[:where]+'''   bool is_custom=false;
   if(!SymbolExist(symbol,is_custom))
      return WriteEmptyCoverage(symbol,output_tag,coverage_path,0,"NATIVE_SYMBOL_NOT_OFFERED_BY_CONNECTED_BROKER");
   if(is_custom)
      return WriteEmptyCoverage(symbol,output_tag,coverage_path,0,"CUSTOM_ARCHIVE_HAS_NO_BROKER_DOWNLOAD");
   if(!SymbolSelect(symbol,true))
      return WriteEmptyCoverage(symbol,output_tag,coverage_path,0,"BROKER_SYMBOL_SELECT_FAILED");
''' +text[where:]
text=text.replace('ResolveHistoryStart(symbol);','ResolveHistoryStart(symbol,output_tag);')
text=text.replace('"NO_CACHED_M1_IN_REQUESTED_WINDOW"','"BROKER_HISTORY_WINDOW_UNAVAILABLE_AFTER_BOUNDED_REQUEST"')
text=text.replace('      return false;\n     }\n   if(!WriteRawBars', '      return WriteEmptyCoverage(symbol,output_tag,coverage_path,cached_last,"BOUNDED_DOWNLOAD_NO_REQUESTED_BARS");\n     }\n   if(!WriteRawBars')
text=text.replace('         return;\n        }\n     }\n   PrintFormat("QM_M1_HARVEST_ALL_COMPLETE', '         continue;\n        }\n     }\n   PrintFormat("QM_M1_HARVEST_ALL_COMPLETE')
(out/'QM_M1_SpreadHarvest.mq5').write_text(text,encoding='utf-8')
(out/'native_download.patch').write_text(''.join(difflib.unified_diff(source.splitlines(True),text.splitlines(True),fromfile='M08B/QM_M1_SpreadHarvest.mq5',tofile='M08C/QM_M1_SpreadHarvest.mq5')),encoding='utf-8')
driver=(prior/'run_measurement.py').read_text(encoding='utf-8').replace('M08B_', 'M08C_').replace('qm.m08b-measurement/v1','qm.m08c-measurement/v1').replace('600','1800').replace('minutes=20','minutes=40')
driver=driver.replace("terminal = None", "SYMBOLS = ('GBPUSD','EURUSD','USDCAD','NZDUSD','XTIUSD','XAGUSD')\nterminal = None",1).replace('m.DXZ_SYMBOLS','SYMBOLS')
driver=driver.replace("receipt['reservation_release'] =", "for path in (m.MT5_ROOT/terminal/'MQL5/Files/QM/m1_harvest').glob(tag+'*_download.json'):\n                receipt['artifacts'].append(freeze(path))\n            receipt['reservation_release'] =")
(out/'run_measurement.py').write_text(driver,encoding='utf-8')
(out/'source_provenance.json').write_text(json.dumps({'source_sha256':hashlib.sha256((prior/'QM_M1_SpreadHarvest.mq5').read_bytes()).hexdigest(),'candidate_sha256':hashlib.sha256((out/'QM_M1_SpreadHarvest.mq5').read_bytes()).hexdigest(),'native_symbols':['GBPUSD','EURUSD','USDCAD','NZDUSD','XTIUSD','XAGUSD'],'request_window_server':['2026-05-20','2026-09-05'],'canonical_source_modified':False},indent=2)+'\n')
print('Prepared bounded native script and governed driver')
