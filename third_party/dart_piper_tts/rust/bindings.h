#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

typedef struct FFIResponse {
  void *ptr;
  char *error_message;
} FFIResponse;

typedef int64_t DartPort;

typedef void (*CompletionCallback)(DartPort port);

struct FFIResponse init(CompletionCallback completion_cb, bool is_debug);

struct FFIResponse create_instance(const char *model_path, const char *config_path);

struct FFIResponse speak(void *instance_ptr,
                         const char *text,
                         bool is_phonemes,
                         DartPort port,
                         const char *phonemization_strategy,
                         uint8_t phoneme_chunk_size);

struct FFIResponse pause(void *instance_ptr);

struct FFIResponse resume(void *instance_ptr);

struct FFIResponse stop(void *instance_ptr);

void dispose(void *instance_ptr);

void free_string(char *s);
