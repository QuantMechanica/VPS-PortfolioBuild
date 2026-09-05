// Option B, version 1. NEW include; never included by an active inventory EA.
// This is a scope prerequisite, not a replacement news filter. AVAILABLE only
// permits the existing filter to run. Unknown scope never becomes healthy NONE.
#ifndef QM_NEWS_SCOPE_V1_MQH
#define QM_NEWS_SCOPE_V1_MQH

enum QM_SCOPE_ENTRY_RESULT
  {
   QM_SCOPE_BLACKOUT_UNKNOWN = -1,
   QM_SCOPE_DEFER_TO_LEGACY = 0
  };
enum QM_SCOPE_BOUNDARY_RESULT
  {
   QM_SCOPE_DATA_ERROR = -1,
   QM_SCOPE_BOUNDARY_DEFER_TO_LEGACY = 0
  };

class QM_NewsScopeV1
  {
private:
   bool m_enabled;
   bool m_loaded;
   bool m_available;
   datetime m_from_utc;
   datetime m_to_utc;
   string m_symbols;
   string m_declaration_ids;
   string m_effective_identity;
   uchar m_primary[];
   uchar m_secondary[];

   bool HashValid(const string value)
     {
      if(StringLen(value)!=64) return false;
      for(int i=0;i<64;i++)
        {
         ushort ch=StringGetCharacter(value,i);
         if(!((ch>='0' && ch<='9') || (ch>='a' && ch<='f'))) return false;
        }
      return true;
     }

   bool SafePath(const string value)
     {
      if(StringLen(value)==0 || StringFind(value,":")>=0 ||
         StringFind(value,"..")>=0 || StringFind(value,"\\")>=0 ||
         StringGetCharacter(value,0)=='/') return false;
      return true;
     }

   bool ReadAndHash(const string relative_path,const string expected,uchar &bytes[])
     {
      if(!SafePath(relative_path) || !HashValid(expected)) return false;
      int handle=FileOpen(relative_path,FILE_READ|FILE_BIN|FILE_COMMON);
      if(handle==INVALID_HANDLE) return false;
      ulong size=FileSize(handle);
      if(size==0 || size>268435456)
        { FileClose(handle); return false; }
      if(ArrayResize(bytes,(int)size)!=(int)size)
        { FileClose(handle); return false; }
      uint got=FileReadArray(handle,bytes,0,(int)size);
      FileClose(handle);
      if(got!=(uint)size) return false;
      uchar key[],hashed[];
      if(CryptEncode(CRYPT_HASH_SHA256,bytes,key,hashed)!=32) return false;
      string actual="";
      for(int i=0;i<32;i++) actual+=StringFormat("%02x",hashed[i]);
      return actual==expected;
     }

   bool UIntText(const string value,long &number)
     {
      if(StringLen(value)==0 || StringLen(value)>12) return false;
      for(int i=0;i<StringLen(value);i++)
        {
         ushort ch=StringGetCharacter(value,i);
         if(ch<'0' || ch>'9') return false;
        }
      number=StringToInteger(value);
      return number>0;
     }

   bool Covered(const string symbol,const datetime utc_now)
     {
      if(!m_loaded || !m_available || utc_now<m_from_utc || utc_now>=m_to_utc ||
         StringLen(symbol)==0 || StringFind(symbol,",")>=0) return false;
      return StringFind(","+m_symbols+",",","+symbol+",")>=0;
     }

public:
   QM_NewsScopeV1(void)
     {
      m_enabled=false; m_loaded=false; m_available=false;
      m_from_utc=0; m_to_utc=0; m_symbols=""; m_declaration_ids="";
      m_effective_identity="";
     }

   // All expected identities originate in the sealed successor run plan.
   // The receipt is a conservative whole-experiment projection of the JSON
   // sidecar. It binds both CSVs, source proof, sealed timezone rules, symbol
   // exposures, full requested UTC window and the new implementation version.
   // No receipt can authorize entry: the ordinary news/risk filters still run.
   bool Load(const bool enabled,const string receipt_path,const string receipt_sha256,
             const string sidecar_path,const string primary_path,const string secondary_path,
             const string proof_path,const string timezone_path,
             const string expected_effective_identity,const string expected_implementation_sha256)
     {
      m_enabled=enabled; m_loaded=false; m_available=false; m_declaration_ids="";
      ArrayFree(m_primary); ArrayFree(m_secondary);
      if(!m_enabled) return true; // No file read or behavior change when disabled.
      if(!HashValid(expected_effective_identity) || !HashValid(expected_implementation_sha256)) return false;
      uchar receipt[];
      if(!ReadAndHash(receipt_path,receipt_sha256,receipt)) return false;
      string text=CharArrayToString(receipt,0,ArraySize(receipt),CP_UTF8);
      string lines[];
      int count=StringSplit(text,'\n',lines);
      if(count!=15 || lines[14]!="" || lines[0]!="QM_SCOPE_V1" ||
         StringFind(lines[1],"qmscopecal-v1-")!=0 || StringLen(lines[1])!=78 ||
         !HashValid(StringSubstr(lines[1],14)) || lines[2]!=expected_effective_identity ||
         lines[13]!=expected_implementation_sha256) return false;
      if(lines[10]!="AVAILABLE" && lines[10]!="UNCONFIRMED") return false;
      if(StringLen(lines[11])==0 || StringLen(lines[12])==0) return false;
      long first=0,last=0;
      if(!UIntText(lines[8],first) || !UIntText(lines[9],last) || first>=last) return false;
      uchar content[];
      if(!ReadAndHash(sidecar_path,lines[3],content) ||
         !ReadAndHash(primary_path,lines[4],m_primary) ||
         !ReadAndHash(secondary_path,lines[5],m_secondary) ||
         !ReadAndHash(proof_path,lines[6],content) ||
         !ReadAndHash(timezone_path,lines[7],content)) return false;
      // Re-read the receipt after all files: changed bytes invalidate the load.
      if(!ReadAndHash(receipt_path,receipt_sha256,receipt)) return false;
      m_from_utc=(datetime)first; m_to_utc=(datetime)last;
      m_symbols=lines[11]; m_declaration_ids=lines[12]=="-" ? "" : lines[12];
      m_effective_identity=lines[2]; m_available=lines[10]=="AVAILABLE";
      if(m_available && StringLen(m_declaration_ids)>0) return false;
      m_loaded=true;
      return true;
     }

   // utc_now must be UTC from the sealed tester-clock adapter, never TimeCurrent
   // interpreted as UTC. Binding that adapter requires the later cohort card.
   QM_SCOPE_ENTRY_RESULT Entry(const string symbol,const datetime utc_now,string &declaration_ids)
     {
      declaration_ids=m_declaration_ids;
      if(!m_enabled) return QM_SCOPE_DEFER_TO_LEGACY;
      if(!Covered(symbol,utc_now)) return QM_SCOPE_BLACKOUT_UNKNOWN;
      return QM_SCOPE_DEFER_TO_LEGACY;
     }

   QM_SCOPE_BOUNDARY_RESULT Boundary(const string symbol,const datetime from_utc,
                                     const datetime to_utc,string &declaration_ids)
     {
      declaration_ids=m_declaration_ids;
      if(!m_enabled) return QM_SCOPE_BOUNDARY_DEFER_TO_LEGACY;
      if(from_utc>=to_utc || !Covered(symbol,from_utc) || to_utc>m_to_utc)
         return QM_SCOPE_DATA_ERROR;
      return QM_SCOPE_BOUNDARY_DEFER_TO_LEGACY;
     }

   bool ScopeComplianceKnown(const string symbol,const datetime utc_now)
     {
      return !m_enabled || Covered(symbol,utc_now);
     }

   // A future compatible CSV parser must consume these verified snapshots.
   // Reopening mutable CSV paths after verification is not a compatible binding.
   bool CopyCalendarBytes(const bool primary,uchar &destination[])
     {
      if(!m_enabled || !m_loaded) return false;
      int size=primary ? ArraySize(m_primary) : ArraySize(m_secondary);
      if(ArrayResize(destination,size)!=size) return false;
      if(primary)
         return ArrayCopy(destination,m_primary)==ArraySize(m_primary);
      return ArrayCopy(destination,m_secondary)==ArraySize(m_secondary);
     }

   // Existing-position code must retain its normal emergency/risk-reduction
   // protections. This include intentionally exposes no forced-close time and
   // no order API; unknown scope cannot manufacture a safe close boundary.
  };
#endif
