#ifndef RUNNER_PASTEBOARD_HANDLER_H_
#define RUNNER_PASTEBOARD_HANDLER_H_

#include <flutter/binary_messenger.h>

void RegisterPasteboardChannel(flutter::BinaryMessenger* messenger,
                               void* window_handle);

#endif  // RUNNER_PASTEBOARD_HANDLER_H_
