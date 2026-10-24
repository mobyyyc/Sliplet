"""macOS Keychain storage. No secret subprocess arguments or plaintext files."""
import ctypes as C
import sys

SERVICE='com.sliplet.development.groq'
ACCOUNT='personal-api-key'

class KeychainError(Exception):pass

def operation(mode, secret=None):
    if sys.platform!='darwin':raise KeychainError('keychain_requires_macos')
    cf=C.CDLL('/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation')
    sec=C.CDLL('/System/Library/Frameworks/Security.framework/Security')
    ptr=C.c_void_p
    cf.CFStringCreateWithCString.argtypes=[ptr,C.c_char_p,C.c_uint32];cf.CFStringCreateWithCString.restype=ptr
    cf.CFDataCreate.argtypes=[ptr,ptr,C.c_long];cf.CFDataCreate.restype=ptr
    cf.CFDictionaryCreate.argtypes=[ptr,ptr,ptr,C.c_long,ptr,ptr];cf.CFDictionaryCreate.restype=ptr
    cf.CFRelease.argtypes=[ptr]
    cf.CFDataGetLength.argtypes=[ptr];cf.CFDataGetLength.restype=C.c_long
    cf.CFDataGetBytePtr.argtypes=[ptr];cf.CFDataGetBytePtr.restype=ptr
    sec.SecItemCopyMatching.argtypes=[ptr,C.POINTER(ptr)];sec.SecItemCopyMatching.restype=C.c_int32
    sec.SecItemAdd.argtypes=[ptr,ptr];sec.SecItemAdd.restype=C.c_int32
    sec.SecItemUpdate.argtypes=[ptr,ptr];sec.SecItemUpdate.restype=C.c_int32
    sec.SecItemDelete.argtypes=[ptr];sec.SecItemDelete.restype=C.c_int32
    owned=[]
    def constant(name,library=sec):return ptr.in_dll(library,name).value
    def string(value):
        value=cf.CFStringCreateWithCString(None,value.encode(),0x08000100);owned.append(value);return value
    def dictionary(values):
        keys=(ptr*len(values))(*[constant(k) for k in values]);vals=(ptr*len(values))(*values.values())
        d=cf.CFDictionaryCreate(None,keys,vals,len(values),None,None);owned.append(d);return d
    base={'kSecClass':constant('kSecClassGenericPassword'),'kSecAttrService':string(SERVICE),
          'kSecAttrAccount':string(ACCOUNT),'kSecAttrSynchronizable':constant('kCFBooleanFalse',cf)}
    try:
        if mode=='read':
            query=dictionary(dict(base,kSecReturnData=constant('kCFBooleanTrue',cf),kSecMatchLimit=constant('kSecMatchLimitOne')))
            result=ptr();status=sec.SecItemCopyMatching(query,C.byref(result))
            if status==-25300:return None
            if status!=0:raise KeychainError('keychain_read_denied')
            try:
                n=cf.CFDataGetLength(result)
                if not 1<=n<=512:raise KeychainError('keychain_value_invalid')
                return C.string_at(cf.CFDataGetBytePtr(result),n).decode('ascii')
            finally:cf.CFRelease(result)
        if mode=='delete':
            status=sec.SecItemDelete(dictionary(base))
            if status not in (0,-25300):raise KeychainError('keychain_delete_denied')
            return
        if mode!='save' or not secret:raise KeychainError('keychain_operation_invalid')
        data=secret.encode('ascii')
        if len(data)>512 or '\n' in secret or '\r' in secret:raise KeychainError('keychain_value_invalid')
        buffer=C.create_string_buffer(data)
        value=cf.CFDataCreate(None,buffer,len(data));owned.append(value)
        attrs={'kSecValueData':value,'kSecAttrAccessible':constant('kSecAttrAccessibleWhenUnlockedThisDeviceOnly')}
        status=sec.SecItemAdd(dictionary(dict(base,**attrs)),None)
        if status==-25299:status=sec.SecItemUpdate(dictionary(base),dictionary(attrs))
        if status!=0:raise KeychainError('keychain_save_denied')
    finally:
        for item in reversed(owned):cf.CFRelease(item)

def read_key():return operation('read')
def save_key(secret):operation('save',secret)
def delete_key():operation('delete')
