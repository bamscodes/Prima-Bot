use std::fmt;
use std::str::FromStr;
use std::sync::{Mutex, OnceLock};

use log::warn;
use rsepitran::Epitran;

static SHARED: OnceLock<Mutex<EpitranPhonemizer>> = OnceLock::new();

pub struct EpitranPhonemizer {
    epitran: Epitran,
}

impl EpitranPhonemizer {
    pub(crate) fn init() {
        SHARED.get_or_init(|| {
            Mutex::new(EpitranPhonemizer {
                epitran: Epitran::new(),
            })
        });
    }

    pub(crate) fn lookup(lang: &str, word: &str) -> Option<String> {
        let lang = match EpitranLang::from_str(lang) {
            Ok(l) => l,
            Err(_) => {
                warn!("Unknown epitran lang: {}", lang);
                return None;
            }
        };

        if SHARED.get().is_none() {
            warn!("Epitran phonemizer not initialized");
            return None;
        }

        match SHARED
            .get()
            .unwrap()
            .lock()
            .unwrap()
            .epitran
            .transliterate_simple(lang.as_str(), word)
        {
            Ok(ipa) => Some(ipa),
            Err(_) => {
                warn!("Lookup failed for lang: {}, word: {}", lang, word);
                None
            }
        }
    }
}

pub enum EpitranLang {
    AmhEthi, // Amharic (Ethiopic)
    AraArab, // Arabic (Perso-Arabic)
    AzeCyrl, // Azerbaijani (Cyrillic)
    // AzeLatn, // Azerbaijani (Latin)
    BenBeng, // Bengali (Bengali)
    CmnHans, // Mandarin Chinese (Simplified)
    // CmnHant, // Mandarin Chinese (Traditional)
    DeuLatn, // German
    EllGrek, // Greek
    EngLatn, // English
    FasArab, // Farsi/Persian (Perso-Arabic)
    FraLatn, // French
    GujGujr, // Gujarati
    HauLatn, // Hausa
    HinDeva, // Hindi (Devanagari)
    HunLatn, // Hungarian
    IndLatn, // Indonesian
    ItaLatn, // Italian
    JavLatn, // Javanese
    KanKnda, // Kannada
    KazCyrl, // Kazakh (Cyrillic)
    KhmKhmr, // Khmer
    KinLatn, // Kinyarwanda
    KirCyrl, // Kyrgyz
    LaoLaoo, // Lao
    MarDeva, // Marathi
    MsaLatn, // Malay
    MyaMymr, // Burmese
    NepDeva, // Nepali
    OriOrya, // Odia
    PanGuru, // Punjabi
    PolLatn, // Polish
    PorLatn, // Portuguese
    RonLatn, // Romanian
    RusCyrl, // Russian
    SinSinh, // Sinhala
    SomLatn, // Somali
    SpaLatn, // Spanish
    SwaLatn, // Swahili
    TamTaml, // Tamil
    TelTelu, // Telugu
    TglLatn, // Tagalog
    ThaThai, // Thai
    TurLatn, // Turkish
    UigArab, // Uyghur
    UkrCyrl, // Ukrainian
    UrdArab, // Urdu
    UzbLatn, // Uzbek
    VieLatn, // Vietnamese
    YorLatn, // Yoruba
    ZulLatn, // Zulu
}

impl EpitranLang {
    pub(crate) fn as_str(&self) -> &'static str {
        match self {
            Self::AmhEthi => "amh_Ethi",
            Self::AraArab => "ara_Arab",
            Self::AzeCyrl => "aze_Cyrl",
            // Self::AzeLatn => "aze_Latn",
            Self::BenBeng => "ben_Beng",
            Self::CmnHans => "cmn_Hans",
            // Self::CmnHant => "cmn_Hant",
            Self::DeuLatn => "deu_Latn",
            Self::EllGrek => "ell_Grek",
            Self::EngLatn => "eng_Latn",
            Self::FasArab => "fas_Arab",
            Self::FraLatn => "fra_Latn",
            Self::GujGujr => "guj_Gujr",
            Self::HauLatn => "hau_Latn",
            Self::HinDeva => "hin_Deva",
            Self::HunLatn => "hun_Latn",
            Self::IndLatn => "ind_Latn",
            Self::ItaLatn => "ita_Latn",
            Self::JavLatn => "jav_Latn",
            Self::KanKnda => "kan_Knda",
            Self::KazCyrl => "kaz_Cyrl",
            Self::KhmKhmr => "khm_Khmr",
            Self::KinLatn => "kin_Latn",
            Self::KirCyrl => "kir_Cyrl",
            Self::LaoLaoo => "lao_Laoo",
            Self::MarDeva => "mar_Deva",
            Self::MsaLatn => "msa_Latn",
            Self::MyaMymr => "mya_Mymr",
            Self::NepDeva => "nep_Deva",
            Self::OriOrya => "ori_Orya",
            Self::PanGuru => "pan_Guru",
            Self::PolLatn => "pol_Latn",
            Self::PorLatn => "por_Latn",
            Self::RonLatn => "ron_Latn",
            Self::RusCyrl => "rus_Cyrl",
            Self::SinSinh => "sin_Sinh",
            Self::SomLatn => "som_Latn",
            Self::SpaLatn => "spa_Latn",
            Self::SwaLatn => "swa_Latn",
            Self::TamTaml => "tam_Taml",
            Self::TelTelu => "tel_Telu",
            Self::TglLatn => "tgl_Latn",
            Self::ThaThai => "tha_Thai",
            Self::TurLatn => "tur_Latn",
            Self::UigArab => "uig_Arab",
            Self::UkrCyrl => "ukr_Cyrl",
            Self::UrdArab => "urd_Arab",
            Self::UzbLatn => "uzb_Latn",
            Self::VieLatn => "vie_Latn",
            Self::YorLatn => "yor_Latn",
            Self::ZulLatn => "zul_Latn",
        }
    }
}

impl fmt::Display for EpitranLang {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.as_str())
    }
}

impl FromStr for EpitranLang {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match &s.to_lowercase().replace('_', "-")[..2] {
            "am" => Ok(Self::AmhEthi),
            "ar" => Ok(Self::AraArab),
            "az" => Ok(Self::AzeCyrl),
            "bn" => Ok(Self::BenBeng),
            "zh" => Ok(Self::CmnHans),
            "de" => Ok(Self::DeuLatn),
            "el" => Ok(Self::EllGrek),
            "en" => Ok(Self::EngLatn),
            "fa" => Ok(Self::FasArab),
            "fr" => Ok(Self::FraLatn),
            "gu" => Ok(Self::GujGujr),
            "ha" => Ok(Self::HauLatn),
            "hi" => Ok(Self::HinDeva),
            "hu" => Ok(Self::HunLatn),
            "id" => Ok(Self::IndLatn),
            "it" => Ok(Self::ItaLatn),
            "jv" => Ok(Self::JavLatn),
            "kn" => Ok(Self::KanKnda),
            "kk" => Ok(Self::KazCyrl),
            "km" => Ok(Self::KhmKhmr),
            "rw" => Ok(Self::KinLatn),
            "ky" => Ok(Self::KirCyrl),
            "lo" => Ok(Self::LaoLaoo),
            "mr" => Ok(Self::MarDeva),
            "ms" => Ok(Self::MsaLatn),
            "my" => Ok(Self::MyaMymr),
            "ne" => Ok(Self::NepDeva),
            "or" => Ok(Self::OriOrya),
            "pa" => Ok(Self::PanGuru),
            "pl" => Ok(Self::PolLatn),
            "pt" => Ok(Self::PorLatn),
            "ro" => Ok(Self::RonLatn),
            "ru" => Ok(Self::RusCyrl),
            "si" => Ok(Self::SinSinh),
            "so" => Ok(Self::SomLatn),
            "es" => Ok(Self::SpaLatn),
            "sw" => Ok(Self::SwaLatn),
            "ta" => Ok(Self::TamTaml),
            "te" => Ok(Self::TelTelu),
            "tl" => Ok(Self::TglLatn),
            "th" => Ok(Self::ThaThai),
            "tr" => Ok(Self::TurLatn),
            "ug" => Ok(Self::UigArab),
            "uk" => Ok(Self::UkrCyrl),
            "ur" => Ok(Self::UrdArab),
            "uz" => Ok(Self::UzbLatn),
            "vi" => Ok(Self::VieLatn),
            "yo" => Ok(Self::YorLatn),
            "zu" => Ok(Self::ZulLatn),
            _ => Err(format!("Unknown Epitran code representation entry: {}", s)),
        }
    }
}
