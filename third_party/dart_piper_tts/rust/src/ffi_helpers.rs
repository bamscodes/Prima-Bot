use std::ffi::{CStr, c_char};

use crate::error::TTSError;

pub fn c_char_to_str<'a>(ptr: *const c_char) -> Result<&'a str, TTSError> {
    if ptr.is_null() {
        return Err(TTSError {
            message: "null pointer argument".into(),
        });
    }
    unsafe { CStr::from_ptr(ptr) }
        .to_str()
        .map_err(|e| TTSError {
            message: e.to_string(),
        })
}
