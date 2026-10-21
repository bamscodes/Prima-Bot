use std::ffi::{CString, c_char, c_void};

use crate::error::TTSError;

#[repr(C)]
pub struct FFIResponse {
    pub ptr: *mut c_void,
    pub error_message: *mut c_char,
}

impl FFIResponse {
    pub fn ok(ptr: *mut c_void) -> FFIResponse {
        FFIResponse {
            ptr,
            error_message: std::ptr::null_mut(),
        }
    }

    pub fn err(e: TTSError) -> FFIResponse {
        FFIResponse {
            ptr: std::ptr::null_mut(),
            error_message: CString::new(e.message).unwrap().into_raw(),
        }
    }
}
