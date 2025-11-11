#ifndef CWHISPER_H
#define CWHISPER_H

// whisper.cpp 和 ggml 的核心头文件
// 由于 Package.swift 中已经设置了 headerSearchPath，这里可以直接引用
#define GGML_USE_METAL
#define GGML_USE_ACCELERATE

// 先包含 ggml（whisper 依赖它）
// 由于设置了 headerSearchPath("external/whisper.cpp/ggml/include")，可以直接引用
#include <ggml.h>

// 再包含 whisper
// 由于设置了 headerSearchPath("external/whisper.cpp/include")，可以直接引用  
#include <whisper.h>

#endif // CWHISPER_H
