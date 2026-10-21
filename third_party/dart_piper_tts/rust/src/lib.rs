use std::{
    ffi::{CString, c_char, c_void},
    path::Path,
    str::FromStr,
    u8,
};

use crate::{
    audio::{AudioPlayer, AudioPlayerConfig, CompletionCallback, DartPort},
    ffi_helpers::c_char_to_str,
    ffi_response::FFIResponse,
    instance::Instance,
    logging::init_logger,
    phonemizer::phonemizer::{PhonemizationStrategy, Phonemizer},
};

pub mod audio;
pub mod config;
pub mod error;
pub mod ffi_helpers;
pub mod ffi_response;
pub mod inference;
pub mod instance;
pub mod logging;
pub mod phonemizer;

#[unsafe(no_mangle)]
pub extern "C" fn init(completion_cb: CompletionCallback, is_debug: bool) -> FFIResponse {
    init_logger(is_debug);

    AudioPlayer::init(AudioPlayerConfig::new(None, None, completion_cb));

    Phonemizer::init();

    FFIResponse::ok(std::ptr::null_mut())
}

#[unsafe(no_mangle)]
pub extern "C" fn create_instance(
    model_path: *const c_char,
    config_path: *const c_char,
) -> FFIResponse {
    let model_path = match c_char_to_str(model_path) {
        Ok(model_path) => model_path,
        Err(err) => return FFIResponse::err(err),
    };
    let config_path = match c_char_to_str(config_path) {
        Ok(config_path) => config_path,
        Err(err) => return FFIResponse::err(err),
    };
    let instance = match Instance::new(Path::new(model_path), Path::new(config_path)) {
        Ok(instance) => instance,
        Err(err) => return FFIResponse::err(err),
    };
    FFIResponse::ok(Box::into_raw(Box::new(instance)) as *mut c_void)
}

#[unsafe(no_mangle)]
pub extern "C" fn speak(
    instance_ptr: *mut c_void,
    text: *const c_char,
    is_phonemes: bool,
    port: DartPort,
    phonemization_strategy: *const c_char,
    phoneme_chunk_size: u8,
) -> FFIResponse {
    let text = match c_char_to_str(text) {
        Ok(text) => text,
        Err(err) => return FFIResponse::err(err),
    };
    let phonemization_strategy = match c_char_to_str(phonemization_strategy) {
        Ok(phonemization_strategy) => phonemization_strategy,
        Err(err) => return FFIResponse::err(err),
    };
    let instance = unsafe { &mut *(instance_ptr as *mut Instance) };
    match instance.speak(
        text,
        is_phonemes,
        port.clamp(-1, i64::MAX),
        PhonemizationStrategy::from_str(phonemization_strategy).unwrap(),
        Some(phoneme_chunk_size.clamp(u8::MIN, u8::MAX)),
    ) {
        Ok(_) => FFIResponse::ok(std::ptr::null_mut()),
        Err(err) => FFIResponse::err(err),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn pause(instance_ptr: *mut c_void) -> FFIResponse {
    let instance = unsafe { &mut *(instance_ptr as *mut Instance) };
    instance.pause();
    FFIResponse::ok(std::ptr::null_mut())
}

#[unsafe(no_mangle)]
pub extern "C" fn resume(instance_ptr: *mut c_void) -> FFIResponse {
    let instance = unsafe { &mut *(instance_ptr as *mut Instance) };
    instance.resume();
    FFIResponse::ok(std::ptr::null_mut())
}

#[unsafe(no_mangle)]
pub extern "C" fn stop(instance_ptr: *mut c_void) -> FFIResponse {
    let instance = unsafe { &mut *(instance_ptr as *mut Instance) };
    instance.stop();
    FFIResponse::ok(std::ptr::null_mut())
}

#[unsafe(no_mangle)]
pub extern "C" fn dispose(instance_ptr: *mut c_void) {
    if !instance_ptr.is_null() {
        let _ = unsafe { Box::from_raw(instance_ptr as *mut Instance) };
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn free_string(s: *mut c_char) {
    if !s.is_null() {
        unsafe {
            drop(CString::from_raw(s));
        }
    }
}
