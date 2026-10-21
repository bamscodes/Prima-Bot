use std::{
    fs::File,
    path::Path,
    sync::{
        Arc,
        atomic::{AtomicU8, Ordering},
        mpsc::{self, Sender},
    },
};

use log::{debug, error};
use ort::session::builder::SessionBuilder;

use crate::{
    audio::AudioPlayer,
    config::ModelConfig,
    error::TTSError,
    inference::infer,
    phonemizer::phonemizer::{PhonemizationStrategy, Phonemizer},
};

struct SpeechTask {
    text: String,
    dart_port: i64,
    is_phonemes: bool,
    phonemization_strategy: PhonemizationStrategy,
    phoneme_chunk_size: Option<u8>,
}

enum InstanceState {
    Play = 1,
    Pause = 2,
    Stop = 3,
}

pub(crate) struct Instance {
    speech_tasks: Sender<SpeechTask>,
    state: Arc<AtomicU8>,
}

unsafe impl Send for Instance {}
unsafe impl Sync for Instance {}

impl Instance {
    pub(crate) fn new(model_path: &Path, config_path: &Path) -> Result<Self, TTSError> {
        let config_file = File::open(config_path)?;
        let config: ModelConfig = serde_json::from_reader(config_file)?;

        debug!("config loaded from {}", config_path.display());

        let mut ort_session = SessionBuilder::new()?.commit_from_file(model_path)?;

        debug!("ort session created from {}", model_path.display());

        let lang = config
            .language
            .code
            .clone()
            .or_else(|| Some("en".to_string()))
            .unwrap()
            .replace("_", "-");

        debug!("language: {}", lang);

        let (tx, rx) = mpsc::channel::<SpeechTask>();

        let state = Arc::new(AtomicU8::new(InstanceState::Stop as u8));
        let state_cb = Arc::clone(&state);

        std::thread::spawn(move || {
            while let Ok(task) = rx.recv() {
                match state_cb.load(Ordering::Acquire) {
                    state if state == InstanceState::Stop as u8 => {
                        continue;
                    }
                    state if state == InstanceState::Pause as u8 => {
                        std::thread::yield_now();
                    }
                    _ => (),
                }

                let SpeechTask {
                    text,
                    is_phonemes,
                    phonemization_strategy,
                    dart_port,
                    phoneme_chunk_size,
                } = task;

                let phonemes = if is_phonemes {
                    text
                } else {
                    match Phonemizer::phonemize(&lang, &text, phonemization_strategy) {
                        Ok(p) => p,
                        Err(e) => {
                            error!("phonemization failed: {}", e);
                            continue;
                        }
                    }
                };

                debug!("phonemes: {}", phonemes);

                let chunk_size = phoneme_chunk_size.unwrap_or(80) as usize;
                debug!("chunk size: {}", chunk_size);

                let phoneme_chunks = if chunk_size == 0 {
                    vec![phonemes]
                } else {
                    split_into_chunks(&phonemes, chunk_size)
                };

                'chunks: for chunk in phoneme_chunks {
                    let samples = match infer(&mut ort_session, &config, &chunk) {
                        Ok(s) => s,
                        Err(e) => {
                            error!("inference failed: {}", e);
                            continue;
                        }
                    };

                    match state_cb.load(Ordering::Acquire) {
                        state if state == InstanceState::Stop as u8 => {
                            break 'chunks;
                        }
                        state if state == InstanceState::Pause as u8 => {
                            std::thread::yield_now();
                        }
                        _ => (),
                    }

                    AudioPlayer::play(&samples);
                }

                AudioPlayer::mark_end_of_speech(dart_port);
            }

            debug!("speech task worker exiting");
        });

        Ok(Instance {
            speech_tasks: tx,
            state,
        })
    }

    pub(crate) fn speak(
        &mut self,
        text: &str,
        is_phonemes: bool,
        dart_port: i64,
        phonemization_strategy: PhonemizationStrategy,
        phoneme_chunk_size: Option<u8>,
    ) -> Result<(), TTSError> {
        self.resume();

        self.speech_tasks
            .send(SpeechTask {
                text: text.to_string(),
                is_phonemes,
                dart_port,
                phonemization_strategy,
                phoneme_chunk_size,
            })
            .map_err(|err| TTSError {
                message: format!("failed to send play speech task: {}", err),
            })?;

        Ok(())
    }

    pub(crate) fn pause(&self) {
        self.state
            .store(InstanceState::Pause as u8, Ordering::SeqCst);

        AudioPlayer::pause();
    }

    pub(crate) fn resume(&self) {
        self.state
            .store(InstanceState::Play as u8, Ordering::SeqCst);

        AudioPlayer::resume();
    }

    pub(crate) fn stop(&self) {
        self.state
            .store(InstanceState::Stop as u8, Ordering::SeqCst);

        AudioPlayer::stop();
    }
}

fn split_into_chunks(text: &str, max_chars: usize) -> Vec<String> {
    let mut chunks = Vec::new();
    let mut current = String::new();

    for piece in text.split_inclusive(|c: char| matches!(c, ' ')) {
        current.push_str(piece);
        let ends_sentence = piece.trim_end().ends_with(['.', '!', '?']);
        if (ends_sentence || current.len() >= max_chars) && !current.trim().is_empty() {
            chunks.push(current.trim().to_string());
            current.clear();
        }
    }
    if !current.trim().is_empty() {
        chunks.push(current.trim().to_string());
    }
    chunks
}
