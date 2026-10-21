#[derive(Debug)]
pub struct TTSError {
    pub message: String,
}

impl std::fmt::Display for TTSError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.message)
    }
}

impl std::error::Error for TTSError {}

impl From<String> for TTSError {
    fn from(e: String) -> Self {
        TTSError { message: e }
    }
}

impl From<std::io::Error> for TTSError {
    fn from(e: std::io::Error) -> Self {
        TTSError {
            message: e.to_string(),
        }
    }
}

impl From<serde_json::Error> for TTSError {
    fn from(e: serde_json::Error) -> Self {
        TTSError {
            message: e.to_string(),
        }
    }
}

impl From<ort::Error> for TTSError {
    fn from(e: ort::Error) -> Self {
        TTSError {
            message: e.to_string(),
        }
    }
}

impl From<ndarray::ShapeError> for TTSError {
    fn from(e: ndarray::ShapeError) -> Self {
        TTSError {
            message: e.to_string(),
        }
    }
}

impl From<cmudict_fast::Error> for TTSError {
    fn from(e: cmudict_fast::Error) -> Self {
        TTSError {
            message: e.to_string(),
        }
    }
}
