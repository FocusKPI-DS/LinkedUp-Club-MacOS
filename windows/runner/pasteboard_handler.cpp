#include "pasteboard_handler.h"

#include <windows.h>
#include <shellapi.h>
#include <objidl.h>
#include <gdiplus.h>

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <vector>

#pragma comment(lib, "gdiplus.lib")

namespace {

using namespace Gdiplus;

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_pasteboard_channel;
HWND g_clipboard_hwnd = nullptr;
ULONG_PTR g_gdiplus_token = 0;

bool OpenAppClipboard() {
  return OpenClipboard(g_clipboard_hwnd != nullptr ? g_clipboard_hwnd : nullptr);
}

int GetEncoderClsid(const WCHAR* format, CLSID* pClsid) {
  UINT num = 0;
  UINT size = 0;
  GetImageEncodersSize(&num, &size);
  if (size == 0) {
    return -1;
  }

  auto* codecs = static_cast<ImageCodecInfo*>(malloc(size));
  if (!codecs) {
    return -1;
  }

  GetImageEncoders(num, size, codecs);
  for (UINT i = 0; i < num; ++i) {
    if (wcscmp(codecs[i].MimeType, format) == 0) {
      *pClsid = codecs[i].Clsid;
      free(codecs);
      return static_cast<int>(i);
    }
  }

  free(codecs);
  return -1;
}

std::vector<uint8_t> SaveBitmapToPng(Bitmap* bitmap) {
  if (!bitmap || bitmap->GetLastStatus() != Ok) {
    return {};
  }

  CLSID png_clsid;
  if (GetEncoderClsid(L"image/png", &png_clsid) < 0) {
    return {};
  }

  IStream* stream = nullptr;
  if (CreateStreamOnHGlobal(nullptr, TRUE, &stream) != S_OK) {
    return {};
  }

  if (bitmap->Save(stream, &png_clsid, nullptr) != Ok) {
    stream->Release();
    return {};
  }

  STATSTG stat = {};
  if (stream->Stat(&stat, STATFLAG_NONAME) != S_OK) {
    stream->Release();
    return {};
  }

  HGLOBAL hg = nullptr;
  if (GetHGlobalFromStream(stream, &hg) != S_OK) {
    stream->Release();
    return {};
  }

  const SIZE_T size = GlobalSize(hg);
  void* data = GlobalLock(hg);
  std::vector<uint8_t> result;
  if (data && size > 0) {
    const auto* bytes = static_cast<const uint8_t*>(data);
    result.assign(bytes, bytes + size);
  }
  GlobalUnlock(hg);
  stream->Release();
  return result;
}

int DibColorTableSize(const BITMAPINFOHEADER* header) {
  if (header->biBitCount > 8) {
    return 0;
  }
  if (header->biClrUsed > 0) {
    return static_cast<int>(header->biClrUsed * sizeof(RGBQUAD));
  }
  return static_cast<int>(sizeof(RGBQUAD) * (size_t{1} << header->biBitCount));
}

std::vector<uint8_t> HBitmapToPng(HBITMAP hbitmap) {
  Bitmap bitmap(hbitmap, nullptr);
  return SaveBitmapToPng(&bitmap);
}

std::vector<uint8_t> DibToPng(const void* dib, size_t dib_size) {
  if (dib_size < sizeof(BITMAPINFOHEADER)) {
    return {};
  }

  const auto* header = static_cast<const BITMAPINFOHEADER*>(dib);
  if (header->biSize < sizeof(BITMAPINFOHEADER)) {
    return {};
  }

  const int header_size = static_cast<int>(header->biSize) + DibColorTableSize(header);
  if (static_cast<size_t>(header_size) > dib_size) {
    return {};
  }

  const void* bits = static_cast<const uint8_t*>(dib) + header_size;
  HDC dc = GetDC(nullptr);
  if (!dc) {
    return {};
  }

  HBITMAP hbmp = CreateDIBitmap(
      dc, header, CBM_INIT, bits, reinterpret_cast<const BITMAPINFO*>(dib),
      DIB_RGB_COLORS);
  ReleaseDC(nullptr, dc);
  if (!hbmp) {
    return {};
  }

  const auto png = HBitmapToPng(hbmp);
  DeleteObject(hbmp);
  return png;
}

std::vector<uint8_t> ReadClipboardFormatBytes(UINT format) {
  std::vector<uint8_t> result;
  HANDLE memory = GetClipboardData(format);
  if (!memory) {
    return result;
  }

  const void* data = GlobalLock(memory);
  const SIZE_T size = GlobalSize(memory);
  if (data && size > 0) {
    const auto* bytes = static_cast<const uint8_t*>(data);
    result.assign(bytes, bytes + size);
  }
  GlobalUnlock(memory);
  return result;
}

bool IsPngBytes(const std::vector<uint8_t>& bytes) {
  return bytes.size() >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 &&
         bytes[2] == 0x4E && bytes[3] == 0x47;
}

bool IsJpegBytes(const std::vector<uint8_t>& bytes) {
  return bytes.size() >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
}

std::vector<uint8_t> GetClipboardImageBytes() {
  if (!OpenAppClipboard()) {
    return {};
  }

  std::vector<uint8_t> result;
  const UINT png_format = RegisterClipboardFormatA("PNG");
  const UINT jfif_format = RegisterClipboardFormatA("JFIF");
  const UINT jpeg_format = RegisterClipboardFormatA("JPEG");

  if (IsClipboardFormatAvailable(png_format)) {
    result = ReadClipboardFormatBytes(png_format);
  }

  if (result.empty() && IsClipboardFormatAvailable(jfif_format)) {
    result = ReadClipboardFormatBytes(jfif_format);
  }

  if (result.empty() && IsClipboardFormatAvailable(jpeg_format)) {
    result = ReadClipboardFormatBytes(jpeg_format);
  }

  if (!result.empty() && (IsPngBytes(result) || IsJpegBytes(result))) {
    CloseClipboard();
    return result;
  }
  result.clear();

  if (IsClipboardFormatAvailable(CF_DIB)) {
    const HANDLE dib_mem = GetClipboardData(CF_DIB);
    if (dib_mem) {
      const void* dib = GlobalLock(dib_mem);
      const SIZE_T dib_size = GlobalSize(dib_mem);
      if (dib && dib_size > 0) {
        result = DibToPng(dib, dib_size);
      }
      GlobalUnlock(dib_mem);
    }
  }

  if (result.empty() && IsClipboardFormatAvailable(CF_DIBV5)) {
    const HANDLE dib_mem = GetClipboardData(CF_DIBV5);
    if (dib_mem) {
      const void* dib = GlobalLock(dib_mem);
      const SIZE_T dib_size = GlobalSize(dib_mem);
      if (dib && dib_size > sizeof(BITMAPV5HEADER)) {
        result = DibToPng(dib, dib_size);
      }
      GlobalUnlock(dib_mem);
    }
  }

  if (result.empty() && IsClipboardFormatAvailable(CF_BITMAP)) {
    HBITMAP bitmap = static_cast<HBITMAP>(GetClipboardData(CF_BITMAP));
    if (bitmap) {
      result = HBitmapToPng(bitmap);
    }
  }

  CloseClipboard();
  return result;
}

std::vector<std::string> GetClipboardFilePaths() {
  std::vector<std::string> paths;
  if (!OpenAppClipboard()) {
    return paths;
  }

  if (IsClipboardFormatAvailable(CF_HDROP)) {
    HDROP drop = static_cast<HDROP>(GetClipboardData(CF_HDROP));
    if (drop) {
      const UINT count = DragQueryFileA(drop, 0xFFFFFFFF, nullptr, 0);
      paths.reserve(count);
      for (UINT i = 0; i < count; ++i) {
        char path[MAX_PATH] = {};
        if (DragQueryFileA(drop, i, path, MAX_PATH) > 0) {
          paths.emplace_back(path);
        }
      }
    }
  }

  CloseClipboard();
  return paths;
}

flutter::EncodableMap ClipboardAvailability() {
  flutter::EncodableMap map;
  bool has_image = false;
  bool has_file = false;

  if (OpenAppClipboard()) {
    const UINT png_format = RegisterClipboardFormatA("PNG");
    has_image = IsClipboardFormatAvailable(CF_DIB) ||
                IsClipboardFormatAvailable(CF_DIBV5) ||
                IsClipboardFormatAvailable(CF_BITMAP) ||
                IsClipboardFormatAvailable(png_format);
    has_file = IsClipboardFormatAvailable(CF_HDROP);
    CloseClipboard();
  }

  map[flutter::EncodableValue("hasImage")] = flutter::EncodableValue(has_image);
  map[flutter::EncodableValue("hasFile")] = flutter::EncodableValue(has_file);
  return map;
}

}  // namespace

void RegisterPasteboardChannel(flutter::BinaryMessenger* messenger,
                               void* window_handle) {
  if (g_gdiplus_token == 0) {
    GdiplusStartupInput input;
    GdiplusStartup(&g_gdiplus_token, &input, nullptr);
  }

  g_clipboard_hwnd = static_cast<HWND>(window_handle);
  g_pasteboard_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "com.focuskpi.linkedup/pasteboard",
          &flutter::StandardMethodCodec::GetInstance());

  g_pasteboard_channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "getImageData") {
          const auto bytes = GetClipboardImageBytes();
          if (bytes.empty()) {
            result->Success();
          } else {
            result->Success(flutter::EncodableValue(bytes));
          }
          return;
        }

        if (call.method_name() == "getFileURLs") {
          flutter::EncodableList paths;
          for (const auto& path : GetClipboardFilePaths()) {
            paths.push_back(flutter::EncodableValue(path));
          }
          result->Success(flutter::EncodableValue(paths));
          return;
        }

        if (call.method_name() == "hasImageOrFile") {
          result->Success(flutter::EncodableValue(ClipboardAvailability()));
          return;
        }

        result->NotImplemented();
      });
}
