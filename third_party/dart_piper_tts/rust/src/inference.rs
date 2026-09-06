//! "Special thanks to https://github.com/thewh1teagle/piper-rs for the implementation."

use ndarray::{Array1, Array2};
use ort::session::Session;
use ort::value::Tensor;

use crate::config::ModelConfig;
use crate::error::TTSError;

const BOS: char = '^';
const EOS: char = '$';
const PAD: char = '_';

fn phonemes_to_ids(config: &ModelConfig, phonemes: &str) -> Vec<i64> {
    let map = &config.phoneme_id_map;
    let pad_id = *map.get(&PAD).and_then(|v| v.first()).unwrap_or(&0);
    let bos_id = *map.get(&BOS).and_then(|v| v.first()).unwrap_or(&0);
    let eos_id = *map.get(&EOS).and_then(|v| v.first()).unwrap_or(&0);

    let mut ids = Vec::with_capacity((phonemes.len() + 1) * 2);
    ids.push(bos_id);
    for ch in phonemes.chars() {
        if let Some(id) = map.get(&ch).and_then(|v| v.first()) {
            ids.push(*id);
            ids.push(pad_id);
        }
    }
    ids.push(eos_id);
    ids
}

pub(crate) fn infer(
    session: &mut Session,
    config: &ModelConfig,
    phonemes: &str,
) -> Result<Vec<f32>, TTSError> {
    let ids = phonemes_to_ids(config, phonemes);
    let input_len = ids.len();
    let input = Array2::<i64>::from_shape_vec((1, input_len), ids)?;
    let input_lengths = Array1::<i64>::from_iter([input_len as i64]);
    let scales = Array1::<f32>::from_iter([
        config.inference.noise_scale,
        config.inference.length_scale,
        config.inference.noise_w,
    ]);

    let input_t = Tensor::<i64>::from_array((
        [1, input_len],
        input.into_raw_vec_and_offset().0.into_boxed_slice(),
    ))?;
    let lengths_t = Tensor::<i64>::from_array((
        [1],
        input_lengths.into_raw_vec_and_offset().0.into_boxed_slice(),
    ))?;
    let scales_t =
        Tensor::<f32>::from_array(([3], scales.into_raw_vec_and_offset().0.into_boxed_slice()))?;

    let outputs = if config.num_speakers > 1 {
        let sid = Array1::<i64>::from_iter([0]);
        let sid_t =
            Tensor::<i64>::from_array(([1], sid.into_raw_vec_and_offset().0.into_boxed_slice()))?;
        session.run(ort::inputs![input_t, lengths_t, scales_t, sid_t])
    } else {
        session.run(ort::inputs![input_t, lengths_t, scales_t])
    }
    .map_err(TTSError::from)?;

    let (_, audio) = outputs[0]
        .try_extract_tensor::<f32>()
        .map_err(TTSError::from)?;

    Ok(audio.to_vec())
}
