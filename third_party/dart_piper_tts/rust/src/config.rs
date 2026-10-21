use std::collections::HashMap;

use serde::Deserialize;

#[derive(Deserialize, Clone)]
pub struct InferenceConfig {
    pub noise_scale: f32,
    pub length_scale: f32,
    pub noise_w: f32,
}

#[derive(Deserialize)]
pub struct LanguageConfig {
    pub code: Option<String>,
}

#[derive(Deserialize)]
pub struct ModelConfig {
    pub language: LanguageConfig,
    pub inference: InferenceConfig,
    pub num_speakers: u32,
    pub phoneme_id_map: HashMap<char, Vec<i64>>,
}
