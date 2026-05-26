'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter_bootstrap.js": "8f9b2a60278cc3a18130b1220755548f",
"version.json": "312682b31934528177e6388a31469784",
"index.html": "154533560166141a738e4a61dff24924",
"/": "154533560166141a738e4a61dff24924",
"firebase-messaging-sw.js": "a449775687e72d232ba03f04e21a7ac8",
"main.dart.js": "95882cb74a77e6071d3d9052b3eacdb1",
"adaptive_foreground_icon.png": "30c3ac80141fdae1e1a6e2a723019c35",
"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"app_launcher_icon.png": "30c3ac80141fdae1e1a6e2a723019c35",
"favicon.png": "2704101cb06ce66e2000356a312be25c",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/app_launcher_icon.png": "30c3ac80141fdae1e1a6e2a723019c35",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/error_image.png": "30c3ac80141fdae1e1a6e2a723019c35",
"manifest.json": "8111eda83e57c66dd627918939f19a48",
"assets/AssetManifest.json": "f65730a57df0fd78f07fa51ef38fa4fb",
"assets/NOTICES": "362a9ecc5d9dc86037ea72f80ae75859",
"assets/FontManifest.json": "ad4b182c241315f949b5da92bcfaaa5b",
"assets/AssetManifest.bin.json": "8b147044b6fb1541a04cbacd4f18bfa9",
"assets/packages/oc_liquid_glass/shaders/liquid_glass.frag": "87be90df2858cf01a23d5a136d4d0740",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "71881478b769e152b8ab9c6a8dcd9442",
"assets/packages/zego_express_engine/assets/ZegoExpressWebFlutterWrapper.js": "e14b613464ec05296d29c3b7d1ebe0bb",
"assets/packages/zego_express_engine/assets/copyrighted-music.js": "f37b9c647f3d29938051cd3f0f621beb",
"assets/packages/zego_express_engine/assets/voice-changer.js": "72119a28733353c028e1ced5950cb1c2",
"assets/packages/font_awesome_flutter/lib/fonts/fa-solid-900.ttf": "b6a9bd2b6750f830e1d618f847206f9b",
"assets/packages/font_awesome_flutter/lib/fonts/fa-regular-400.ttf": "f23db3e1d30cccda3eca4b6e04dd0f56",
"assets/packages/font_awesome_flutter/lib/fonts/fa-brands-400.ttf": "dea630d9672e2c1b86fffc9ed9db1c30",
"assets/packages/liquid_glass_renderer/lib/assets/shaders/liquid_glass_filter.frag": "7a69a481c4b01af713dc9d1ba40463fa",
"assets/packages/liquid_glass_renderer/lib/assets/shaders/liquid_glass_final_render.frag": "77416b256a173eb8a39a26e00899bc1a",
"assets/packages/liquid_glass_renderer/lib/assets/shaders/liquid_glass_arbitrary.frag": "165123cf809bb7cea0f60cdb8658f67a",
"assets/packages/liquid_glass_renderer/lib/assets/shaders/liquid_glass_geometry_blended.frag": "884d38ba3a7ab0ab72a463611f229e53",
"assets/packages/flutter_google_places/assets/google_white.png": "40bc3ae5444eae0b9228d83bfd865158",
"assets/packages/flutter_google_places/assets/google_black.png": "97f2acfb6e993a0c4134d9d04dff21e2",
"assets/packages/flutter_inappwebview_web/assets/web/web_support.js": "509ae636cfdd93e49b5a6eaf0f06d79f",
"assets/packages/flutter_inappwebview/assets/t_rex_runner/t-rex.css": "5a8d0222407e388155d7d1395a75d5b9",
"assets/packages/flutter_inappwebview/assets/t_rex_runner/t-rex.html": "16911fcc170c8af1c5457940bd0bf055",
"assets/packages/record_web/assets/js/record.fixwebmduration.js": "1f0108ea80c8951ba702ced40cf8cdce",
"assets/packages/record_web/assets/js/record.worklet.js": "356bcfeddb8a625e3e2ba43ddf1cc13e",
"assets/packages/wakelock_plus/assets/no_sleep.js": "7748a45cd593f33280669b29c2c8919a",
"assets/packages/branchio_dynamic_linking_akp5u6/assets/audios/favicon.png": "5dcef449791fa27946b3d35ad8803796",
"assets/packages/branchio_dynamic_linking_akp5u6/assets/jsons/favicon.png": "5dcef449791fa27946b3d35ad8803796",
"assets/packages/branchio_dynamic_linking_akp5u6/assets/rive_animations/favicon.png": "5dcef449791fa27946b3d35ad8803796",
"assets/packages/branchio_dynamic_linking_akp5u6/assets/images/favicon.png": "5dcef449791fa27946b3d35ad8803796",
"assets/packages/branchio_dynamic_linking_akp5u6/assets/videos/favicon.png": "5dcef449791fa27946b3d35ad8803796",
"assets/packages/branchio_dynamic_linking_akp5u6/assets/pdfs/favicon.png": "5dcef449791fa27946b3d35ad8803796",
"assets/packages/branchio_dynamic_linking_akp5u6/assets/fonts/favicon.png": "5dcef449791fa27946b3d35ad8803796",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"assets/AssetManifest.bin": "87fbff55246c12ae05b5d15aa030b4ab",
"assets/fonts/MaterialIcons-Regular.otf": "588b1e8f4b1f7fc9bd76c217b7638650",
"assets/assets/audios/favicon.png": "5dcef449791fa27946b3d35ad8803796",
"assets/assets/audios/new-notification-3-398649.mp3": "386725dd55412a7d59cb97d5a5cae711",
"assets/assets/audios/mac_os_glass.mp3": "d3c49fa3a525baebf761000d8e941f45",
"assets/assets/audios/notification_sound.mp3": "f705bb215690e40bca7cd9faeb1fcca1",
"assets/assets/jsons/favicon.png": "5dcef449791fa27946b3d35ad8803796",
"assets/assets/rive_animations/favicon.png": "5dcef449791fa27946b3d35ad8803796",
"assets/assets/images/email-5-512.png": "dd846793eb89e17fa2ae6e4cd119460d",
"assets/assets/images/ac223b5163821230e58fbb86c4f9ddd0d1772771.png": "9cfaf7a2cf89fcdf039ee55adb00373d",
"assets/assets/images/00315368875b4683939ad1b231c721a5cc3c7227.png": "5df3587379f6ca2c099057365381f3f4",
"assets/assets/images/envelope.png": "0dd5090c26dbc8e90b273e485f0c6a1b",
"assets/assets/images/google-calendar.png": "c1378bb190ea0e64c9b76ed47c0c956a",
"assets/assets/images/adaptive_foreground_icon.png": "30c3ac80141fdae1e1a6e2a723019c35",
"assets/assets/images/67b27b2cda06e9c69e5d000615c1153f80b09576.png": "8156c6193d98d980b292ecc646109f86",
"assets/assets/images/div.png": "7f867c4d5ce4bc4622c53ff3abe8b6c6",
"assets/assets/images/app_launcher_icon.png": "30c3ac80141fdae1e1a6e2a723019c35",
"assets/assets/images/lona-workspace.png": "ac603a4ae1a90b846b2c475cf0a423bc",
"assets/assets/images/favicon.png": "5dcef449791fa27946b3d35ad8803796",
"assets/assets/images/idjU1WbcfM_logos.svg": "09a2656a03d6b88c8ef1b440dbe5e95d",
"assets/assets/images/gmeet.png": "787811a1d40d9624249aa3806f3395ac",
"assets/assets/images/software-agent.png": "4cc6e6755b3173fb016ab93573809974",
"assets/assets/images/9939941067409a27e7334f498969c725da0ae11a.png": "9a72938a672f88e1c010f4548a625bb7",
"assets/assets/images/google.png": "c0e9477d27fb9189c80cc9c384466d9d",
"assets/assets/images/Logo_2.png": "09ee7dd41e886f24a8540067c216ff30",
"assets/assets/images/3e5cbd419c5eeea9116da22d9e39b5bfa4785a4d.png": "13daf430057b9e14b307cf1648aa35d0",
"assets/assets/images/svg.png": "2f35e15fa054a62e537d57a032042f29",
"assets/assets/images/eventbrite-logo.png": "cda111285fd925c3fd22109a6bc0958a",
"assets/assets/images/mail-512.png": "40d05b625651a3fa6f42df847359231e",
"assets/assets/images/error_image.png": "30c3ac80141fdae1e1a6e2a723019c35",
"assets/assets/videos/favicon.png": "5dcef449791fa27946b3d35ad8803796",
"assets/assets/pdfs/favicon.png": "5dcef449791fa27946b3d35ad8803796",
"assets/assets/fonts/Inter-Medium.ttf": "a473e623af12065b4b9cb8db4068fb9c",
"assets/assets/fonts/Inter-Light.ttf": "ff5fdc6f42c720a3ebd7b60f6d605888",
"assets/assets/fonts/Inter-Bold.ttf": "8f2869a84ad71f156a17bb66611ebe22",
"assets/assets/fonts/Inter-Regular.ttf": "fdb50e0d48cdcf775fa1ac0dc3c33bd4",
"assets/assets/fonts/favicon.png": "5dcef449791fa27946b3d35ad8803796",
"assets/assets/fonts/Inter-Italic.ttf": "118abbe34a2979b66d6838805c56b7cd",
"assets/assets/fonts/Inter-SemiBold.ttf": "4d24f378e7f8656a5bccb128265a6c3d",
"mac_os_glass.mp3": "d3c49fa3a525baebf761000d8e941f45",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
