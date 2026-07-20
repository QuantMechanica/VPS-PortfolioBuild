Set-StrictMode -Version Latest

function Initialize-QmDev2LsaRightsType {
    if ('Qm.Dev2.LsaRights' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.Principal;

namespace Qm.Dev2 {
    public static class LsaRights {
        [StructLayout(LayoutKind.Sequential)]
        private struct LSA_OBJECT_ATTRIBUTES {
            public int Length;
            public IntPtr RootDirectory;
            public int Attributes;
            public IntPtr SecurityDescriptor;
            public IntPtr SecurityQualityOfService;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct LSA_UNICODE_STRING {
            public ushort Length;
            public ushort MaximumLength;
            public IntPtr Buffer;
        }

        [DllImport("advapi32.dll")]
        private static extern uint LsaOpenPolicy(
            IntPtr systemName,
            ref LSA_OBJECT_ATTRIBUTES objectAttributes,
            uint desiredAccess,
            out IntPtr policyHandle);

        [DllImport("advapi32.dll")]
        private static extern uint LsaAddAccountRights(
            IntPtr policyHandle,
            IntPtr accountSid,
            LSA_UNICODE_STRING[] userRights,
            uint countOfRights);

        [DllImport("advapi32.dll")]
        private static extern uint LsaEnumerateAccountRights(
            IntPtr policyHandle,
            IntPtr accountSid,
            out IntPtr userRights,
            out uint countOfRights);

        [DllImport("advapi32.dll")]
        private static extern uint LsaNtStatusToWinError(uint status);

        [DllImport("advapi32.dll")]
        private static extern uint LsaClose(IntPtr policyHandle);

        [DllImport("advapi32.dll")]
        private static extern uint LsaFreeMemory(IntPtr buffer);

        private const uint POLICY_CREATE_ACCOUNT = 0x00000010;
        private const uint POLICY_LOOKUP_NAMES = 0x00000800;

        private static IntPtr OpenPolicy() {
            LSA_OBJECT_ATTRIBUTES attributes = new LSA_OBJECT_ATTRIBUTES();
            attributes.Length = Marshal.SizeOf(typeof(LSA_OBJECT_ATTRIBUTES));
            IntPtr handle;
            uint status = LsaOpenPolicy(IntPtr.Zero, ref attributes,
                POLICY_CREATE_ACCOUNT | POLICY_LOOKUP_NAMES, out handle);
            ThrowIfError(status, "LsaOpenPolicy");
            return handle;
        }

        private static byte[] GetSidBytes(string sidText) {
            SecurityIdentifier sid = new SecurityIdentifier(sidText);
            byte[] bytes = new byte[sid.BinaryLength];
            sid.GetBinaryForm(bytes, 0);
            return bytes;
        }

        private static LSA_UNICODE_STRING MakeString(string value) {
            LSA_UNICODE_STRING text = new LSA_UNICODE_STRING();
            text.Buffer = Marshal.StringToHGlobalUni(value);
            text.Length = checked((ushort)(value.Length * 2));
            text.MaximumLength = checked((ushort)(text.Length + 2));
            return text;
        }

        private static void ThrowIfError(uint status, string operation) {
            if (status == 0) return;
            int error = unchecked((int)LsaNtStatusToWinError(status));
            throw new Win32Exception(error, operation + " failed");
        }

        public static string[] Enumerate(string sidText) {
            IntPtr policy = IntPtr.Zero;
            IntPtr rightsBuffer = IntPtr.Zero;
            GCHandle sidHandle = default(GCHandle);
            try {
                policy = OpenPolicy();
                byte[] sidBytes = GetSidBytes(sidText);
                sidHandle = GCHandle.Alloc(sidBytes, GCHandleType.Pinned);
                uint count;
                uint status = LsaEnumerateAccountRights(policy, sidHandle.AddrOfPinnedObject(),
                    out rightsBuffer, out count);
                if (status != 0) {
                    int error = unchecked((int)LsaNtStatusToWinError(status));
                    if (error == 2) return new string[0];
                    throw new Win32Exception(error, "LsaEnumerateAccountRights failed");
                }
                List<string> result = new List<string>();
                int size = Marshal.SizeOf(typeof(LSA_UNICODE_STRING));
                for (int i = 0; i < count; i++) {
                    IntPtr current = IntPtr.Add(rightsBuffer, checked(i * size));
                    LSA_UNICODE_STRING item = (LSA_UNICODE_STRING)Marshal.PtrToStructure(
                        current, typeof(LSA_UNICODE_STRING));
                    result.Add(Marshal.PtrToStringUni(item.Buffer, item.Length / 2));
                }
                result.Sort(StringComparer.Ordinal);
                return result.ToArray();
            } finally {
                if (rightsBuffer != IntPtr.Zero) LsaFreeMemory(rightsBuffer);
                if (sidHandle.IsAllocated) sidHandle.Free();
                if (policy != IntPtr.Zero) LsaClose(policy);
            }
        }

        public static void Add(string sidText, string rightName) {
            IntPtr policy = IntPtr.Zero;
            GCHandle sidHandle = default(GCHandle);
            LSA_UNICODE_STRING right = default(LSA_UNICODE_STRING);
            try {
                policy = OpenPolicy();
                byte[] sidBytes = GetSidBytes(sidText);
                sidHandle = GCHandle.Alloc(sidBytes, GCHandleType.Pinned);
                right = MakeString(rightName);
                uint status = LsaAddAccountRights(policy, sidHandle.AddrOfPinnedObject(),
                    new LSA_UNICODE_STRING[] { right }, 1);
                ThrowIfError(status, "LsaAddAccountRights");
            } finally {
                if (right.Buffer != IntPtr.Zero) Marshal.FreeHGlobal(right.Buffer);
                if (sidHandle.IsAllocated) sidHandle.Free();
                if (policy != IntPtr.Zero) LsaClose(policy);
            }
        }
    }
}
'@ -Language CSharp -ErrorAction Stop
}

function Get-QmDev2AccountRights {
    param([Parameter(Mandatory = $true)][string]$Sid)
    Initialize-QmDev2LsaRightsType
    return @([Qm.Dev2.LsaRights]::Enumerate($Sid) | Sort-Object)
}

function Grant-QmDev2BatchLogonRight {
    param([Parameter(Mandatory = $true)][string]$Sid)
    $before = @(Get-QmDev2AccountRights -Sid $Sid)
    if ($before -contains 'SeDenyBatchLogonRight') {
        throw 'QMDev2 has SeDenyBatchLogonRight; refusing to weaken a deny policy.'
    }
    [Qm.Dev2.LsaRights]::Add($Sid, 'SeBatchLogonRight')
    $after = @(Get-QmDev2AccountRights -Sid $Sid)
    $expected = @($before + 'SeBatchLogonRight' | Sort-Object -Unique)
    if ([string]::Join('|', $after) -cne [string]::Join('|', $expected)) {
        throw "QMDev2 account-right drift after grant. Before=$([string]::Join(',', $before)); after=$([string]::Join(',', $after))"
    }
    return [pscustomobject]@{
        before = $before
        after = $after
        added = @($after | Where-Object { $_ -notin $before })
    }
}
