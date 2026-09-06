use std::{env, process::Command};

fn main() {
    let target_os = std::env::var("CARGO_CFG_TARGET_OS").unwrap();

    if target_os == "ios" {
        println!("cargo:rustc-link-lib=framework=Foundation");
    }

            if target_os == "android" {
        let target_arch = env::var("CARGO_CFG_TARGET_ARCH").unwrap_or_else(|_| "aarch64".to_string());
        let arch_str = match target_arch.as_str() {
            "arm" => "arm",
            "x86" => "i386",
            "x86_64" => "x86_64",
            _ => "aarch64",
        };
        let lib_dir_str = format!("C:/MAD/android/Sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/windows-x86_64/lib/clang/19/lib/linux/{}", arch_str);
        let lib_dir = std::path::Path::new(&lib_dir_str);
        println!("cargo:rustc-link-search=native={}", lib_dir.display());
        println!("cargo:rustc-link-lib=static=unwind");
    }

    let crate_dir = env::var("CARGO_MANIFEST_DIR").unwrap();

    cbindgen::Builder::new()
        .with_crate(crate_dir)
        .with_language(cbindgen::Language::C)
        .generate()
        .expect("Unable to generate bindings")
        .write_to_file("bindings.h");
}
