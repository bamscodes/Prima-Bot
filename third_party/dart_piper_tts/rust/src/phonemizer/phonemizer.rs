use std::{collections::HashMap, str::FromStr, sync::OnceLock};

use regex::Regex;
use unaccent::unaccent;

use crate::{
    error::TTSError,
    phonemizer::{
        cmudict::CmudictPhonemizer, epitran::EpitranPhonemizer, neural::NeuralPhonemizer,
    },
};

pub(crate) struct Phonemizer {}

impl Phonemizer {
    pub(crate) fn init() {
        CmudictPhonemizer::init();
        EpitranPhonemizer::init();
        NeuralPhonemizer::init();
    }

    pub(crate) fn phonemize(
        lang: &str,
        text: &str,
        strategy: PhonemizationStrategy,
    ) -> Result<String, TTSError> {
        // TODO: not sure about the unaccent part
        let tokens = Phonemizer::tokenize(&unaccent(text));

        match strategy {
            PhonemizationStrategy::NeuralSentence => {
                let mut clean_words = Vec::new();
                let mut word_mapping = Vec::new();

                for (token_idx, token) in tokens.iter().enumerate() {
                    match token {
                        TextToken::Word(w) => {
                            clean_words.push(w.clone());
                            word_mapping.push(token_idx);
                        }
                        TextToken::Symbol(_) => {}
                    }
                }

                if clean_words.is_empty() {
                    let fallback: String = tokens
                        .into_iter()
                        .map(|t| match t {
                            TextToken::Symbol(s) => s,
                            _ => "".to_string(),
                        })
                        .collect();
                    return Ok(fallback);
                }

                let neural_input = clean_words.join(" ");
                let neural_output_raw =
                    NeuralPhonemizer::phonemize(lang, &neural_input, None, None)?;

                let ipa_blocks: Vec<&str> = neural_output_raw.split_whitespace().collect();

                let mut reconstructed_ipa_slots: HashMap<usize, Vec<String>> = HashMap::new();

                for (&original_idx, &ipa_chunk) in word_mapping.iter().zip(&ipa_blocks) {
                    reconstructed_ipa_slots
                        .entry(original_idx)
                        .or_insert_with(Vec::new)
                        .push(ipa_chunk.to_string());
                }

                let mut final_ipa_string = String::new();

                for (token_idx, token) in tokens.into_iter().enumerate() {
                    match token {
                        TextToken::Symbol(sym) => {
                            final_ipa_string.push_str(&sym);
                        }
                        _ => {
                            if let Some(chunks) = reconstructed_ipa_slots.get(&token_idx) {
                                final_ipa_string.push_str(&chunks.join(" "));
                            }
                        }
                    }
                }

                Ok(final_ipa_string)
            }
            _ => {
                let mut result: Vec<String> = Vec::new();

                for token in tokens {
                    match token {
                        TextToken::Word(word) => {
                            if matches!(strategy, PhonemizationStrategy::NeuralWord) {
                                result.push(NeuralPhonemizer::phonemize(lang, &word, None, None)?);
                            } else if lang.to_lowercase()[..2] == *"en"
                                && let Some(lookup) = CmudictPhonemizer::lookup(&word)
                            {
                                result.push(lookup);
                            } else if lang.to_lowercase()[..2] != *"en"
                                && let Some(lookup) = EpitranPhonemizer::lookup(lang, &word)
                            {
                                result.push(lookup);
                            } else if matches!(
                                strategy,
                                PhonemizationStrategy::DictionaryWithNeuralFallback
                            ) {
                                result.push(NeuralPhonemizer::phonemize(lang, &word, None, None)?);
                            } else {
                                result.push("".to_string());
                            }
                        }
                        TextToken::Symbol(symbol) => result.push(symbol),
                    }
                }

                Ok(result.join(""))
            }
        }
    }

    fn tokenizer_regex() -> &'static Regex {
        let patterns = vec![
            r"(?P<word>[\p{L}\p{M}]+)",
            r"(?P<single_sym>[^\p{L}\p{M}\d\s])",
            r"(?P<whitespace>\s+)",
        ];
        static RE: OnceLock<Regex> = OnceLock::new();
        RE.get_or_init(|| Regex::new(&patterns.join("|")).unwrap())
    }

    fn tokenize(text: &str) -> Vec<TextToken> {
        let tokenizer_regex = Phonemizer::tokenizer_regex();

        let mut tokens = Vec::new();
        let mut last_idx = 0;

        for captures in tokenizer_regex.captures_iter(text) {
            let full_match = captures.get(0).unwrap();

            if full_match.start() > last_idx {
                tokens.push(TextToken::Symbol(
                    text[last_idx..full_match.start()].to_string(),
                ));
            }

            if let Some(mat) = captures.name("word") {
                tokens.push(TextToken::Word(mat.as_str().to_string()));
            } else if let Some(mat) = captures.name("single_sym") {
                let symbol = mat.as_str();
                if symbol.contains(".")
                    || symbol.contains(",")
                    || symbol.contains("?")
                    || symbol.contains("!")
                {
                    tokens.push(TextToken::Symbol(mat.as_str().to_string()));
                }
            } else if let Some(mat) = captures.name("whitespace") {
                tokens.push(TextToken::Symbol(mat.as_str().to_string()));
            }

            last_idx = full_match.end();
        }

        if last_idx < text.len() {
            tokens.push(TextToken::Symbol(text[last_idx..].to_string()));
        }

        tokens
    }
}

pub enum PhonemizationStrategy {
    NeuralSentence,
    NeuralWord,
    DictionaryWithNeuralFallback,
    DictionaryWithOmitUnknown,
}

impl FromStr for PhonemizationStrategy {
    type Err = std::convert::Infallible;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "neural_sentence" => Ok(PhonemizationStrategy::NeuralSentence),
            "neural_word" => Ok(PhonemizationStrategy::NeuralWord),
            "dict_neural" => Ok(PhonemizationStrategy::DictionaryWithNeuralFallback),
            "dict_omit" => Ok(PhonemizationStrategy::DictionaryWithOmitUnknown),
            _ => Ok(PhonemizationStrategy::DictionaryWithNeuralFallback),
        }
    }
}

enum TextToken {
    Word(String),
    Symbol(String),
}
