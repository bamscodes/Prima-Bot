use cmudict_fast::{Cmudict, Stress, Symbol};
use log::warn;
use std::{
    str::FromStr,
    sync::{Mutex, OnceLock},
};

const CMUDICT_DATA: &str = include_str!("../assets/cmudict.dict");

static SHARED: OnceLock<Mutex<CmudictPhonemizer>> = OnceLock::new();

pub struct CmudictPhonemizer {
    dict: Cmudict,
}

impl CmudictPhonemizer {
    pub(crate) fn init() {
        SHARED.get_or_init(|| {
            Mutex::new(CmudictPhonemizer {
                dict: Cmudict::from_str(CMUDICT_DATA).expect("Failed to load Cmudict data"),
            })
        });
    }

    pub(crate) fn lookup(word: &str) -> Option<String> {
        if SHARED.get().is_none() {
            warn!("CMUdict phonemizer not initialized");
            return None;
        }

        if let Some(rules) = SHARED
            .get()
            .unwrap()
            .lock()
            .unwrap()
            .dict
            .get(&word.to_lowercase())
        {
            let mut word_ipa = String::new();

            if let Some(primary_rule) = rules.first() {
                for symbol in primary_rule.pronunciation() {
                    let (ipa_char, is_primary_stress) = convert_symbol_to_ipa(symbol);

                    if is_primary_stress {
                        word_ipa.push('ˈ');
                    }

                    word_ipa.push_str(ipa_char);
                }
            }
            Some(word_ipa)
        } else {
            None
        }
    }
}

fn convert_symbol_to_ipa(symbol: &Symbol) -> (&'static str, bool) {
    match symbol {
        Symbol::AA(stress) => ("ɑ", matches!(stress, Stress::Primary)),
        Symbol::AE(stress) => ("æ", matches!(stress, Stress::Primary)),
        Symbol::AH(stress) => {
            if matches!(stress, Stress::None) {
                ("ə", false)
            } else {
                ("ʌ", matches!(stress, Stress::Primary))
            }
        }
        Symbol::AO(stress) => ("ɔ", matches!(stress, Stress::Primary)),
        Symbol::AW(stress) => ("aʊ", matches!(stress, Stress::Primary)),
        Symbol::AY(stress) => ("aɪ", matches!(stress, Stress::Primary)),
        Symbol::EH(stress) => ("ɛ", matches!(stress, Stress::Primary)),
        Symbol::ER(stress) => ("ɜɹ", matches!(stress, Stress::Primary)),
        Symbol::EY(stress) => ("eɪ", matches!(stress, Stress::Primary)),
        Symbol::IH(stress) => ("ɪ", matches!(stress, Stress::Primary)),
        Symbol::IY(stress) => {
            if matches!(stress, Stress::None) {
                ("ɪ", false)
            } else {
                ("i", matches!(stress, Stress::Primary))
            }
        }
        Symbol::OW(stress) => ("oʊ", matches!(stress, Stress::Primary)),
        Symbol::OY(stress) => ("ɔɪ", matches!(stress, Stress::Primary)),
        Symbol::UH(stress) => ("ʊ", matches!(stress, Stress::Primary)),
        Symbol::UW(stress) => ("u", matches!(stress, Stress::Primary)),
        Symbol::B => ("b", false),
        Symbol::CH => ("tʃ", false),
        Symbol::D => ("d", false),
        Symbol::DH => ("ð", false),
        Symbol::F => ("f", false),
        Symbol::G => ("ɡ", false),
        Symbol::HH => ("h", false),
        Symbol::JH => ("dʒ", false),
        Symbol::K => ("k", false),
        Symbol::L => ("l", false),
        Symbol::M => ("m", false),
        Symbol::N => ("n", false),
        Symbol::NG => ("ŋ", false),
        Symbol::P => ("p", false),
        Symbol::R => ("ɹ", false),
        Symbol::S => ("s", false),
        Symbol::SH => ("ʃ", false),
        Symbol::T => ("t", false),
        Symbol::TH => ("θ", false),
        Symbol::V => ("v", false),
        Symbol::W => ("w", false),
        Symbol::Y => ("j", false),
        Symbol::Z => ("z", false),
        Symbol::ZH => ("ʒ", false),
    }
}
