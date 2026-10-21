use std::sync::{Mutex, OnceLock};

use log::debug;
use ndarray::ArrayViewD;
use ort::{session::Session, value::Value};
use unicode_segmentation::UnicodeSegmentation;

use crate::error::TTSError;

const ONNX_BYTES: &[u8] =
    include_bytes!("../assets/phonemizer/g2p-mbyt5-12l-ipa-childes-espeak-onnx-quantized.onnx");

static SHARED: OnceLock<Mutex<NeuralPhonemizer>> = OnceLock::new();

pub(crate) struct NeuralPhonemizer {
    session: Session,
}

impl NeuralPhonemizer {
    pub(crate) fn init() {
        SHARED.get_or_init(|| {
            Mutex::new(NeuralPhonemizer {
                session: Session::builder()
                    .unwrap()
                    .commit_from_memory(ONNX_BYTES)
                    .expect("Failed to initialize static ONNX G2P session"),
            })
        });
    }

    pub(crate) fn phonemize(
        lang: &str,
        text: &str,
        chunk_size: Option<usize>,
        max_len: Option<usize>,
    ) -> Result<String, TTSError> {
        if SHARED.get().is_none() {
            return Err(TTSError::from(
                "Neural phonemizer not initialized".to_string(),
            ));
        }

        let chunks = chunk_text(text, chunk_size.unwrap_or(100));

        let mut phonemes: Vec<String> = Vec::new();

        let mut guard = SHARED
            .get()
            .ok_or_else(|| TTSError::from("Neural phonemizer not initialized".to_string()))?
            .lock()
            .unwrap();

        for chunk in chunks {
            debug!("phonemize chunk: {}", chunk);
            let input_ids = encode(lang, chunk.as_str());
            let seq_len = input_ids.len();
            let input_ids_arr =
                Value::from_array(ndarray::Array2::from_shape_vec((1, seq_len), input_ids)?)?;
            let attention_mask_arr = Value::from_array(ndarray::Array2::<i64>::ones((1, seq_len)))?;

            let mut decoder_ids: Vec<i64> = vec![PAD_TOKEN_ID];
            let mut generated: Vec<i64> = Vec::new();

            for _ in 0..max_len.unwrap_or(512).clamp(1, 512) {
                let decoder_ids_arr = Value::from_array(ndarray::Array2::from_shape_vec(
                    (1, decoder_ids.len()),
                    decoder_ids.clone(),
                )?)?;

                let outputs = guard.session.run(ort::inputs![
                    "input_ids"         => input_ids_arr.view(),
                    "attention_mask"    => attention_mask_arr.view(),
                    "decoder_input_ids" => decoder_ids_arr
                ])?;

                let (shape, data) = outputs[0].try_extract_tensor::<f32>()?;

                let dims: Vec<usize> = shape.iter().map(|&d| d as usize).collect();

                let logits_view = ArrayViewD::from_shape(dims, data)?;

                let shape = logits_view.shape();
                let seq_len = shape[1];

                let next_token_id = logits_view
                    .slice(ndarray::s![0, seq_len - 1, ..])
                    .iter()
                    .enumerate()
                    .max_by(|a, b| a.1.partial_cmp(b.1).unwrap_or(std::cmp::Ordering::Equal))
                    .map(|(i, _)| i as i64)
                    .ok_or_else(|| TTSError::from("No next token".to_string()))?;

                if next_token_id == EOS_TOKEN_ID {
                    break;
                }

                generated.push(next_token_id);
                decoder_ids.push(next_token_id);
            }

            let decoded_ipa = decode(&generated);
            phonemes.push(decoded_ipa);
        }

        Ok(phonemes.join(" "))
    }
}

fn chunk_text(text: &str, max_chars: usize) -> Vec<String> {
    let mut chunks = Vec::new();
    let mut current_chunk = String::new();

    for sentence in text.unicode_sentences() {
        if current_chunk.len() + sentence.len() > max_chars && !current_chunk.is_empty() {
            chunks.push(current_chunk.trim().to_string());
            current_chunk = String::new();
        }
        current_chunk.push_str(sentence);
        current_chunk.push(' ');
    }

    if !current_chunk.is_empty() {
        chunks.push(current_chunk.trim().to_string());
    }

    chunks
}

/// ByT5 tokenizer
/// Token IDs: 0=PAD, 1=EOS, 2=UNK, 3..258 = UTF-8 byte values 0..255

const PAD_TOKEN_ID: i64 = 0;
const EOS_TOKEN_ID: i64 = 1;

/// Encode "<lang>: text" into ByT5 token IDs.
fn encode(lang: &str, text: &str) -> Vec<i64> {
    let input = format!("<{lang}>: {text}");
    input.bytes().map(|b| b as i64 + 3).collect()
}

/// Decode ByT5 token IDs back to a UTF-8 string.
fn decode(token_ids: &[i64]) -> String {
    let bytes: Vec<u8> = token_ids
        .iter()
        .filter(|&&t| t >= 3)
        .map(|&t| (t - 3) as u8)
        .collect();
    String::from_utf8_lossy(&bytes).into_owned()
}
