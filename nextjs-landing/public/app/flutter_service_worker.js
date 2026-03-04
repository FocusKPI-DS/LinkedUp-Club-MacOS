'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter_bootstrap.js": "2bd8138ca86cf350a1622d183bc22e8b",
"version.json": "d0e270959704f5d49f343bca738b6e6d",
"index.html": "93b8ec2831c1a7918bd32dabf03c15cd",
"/": "93b8ec2831c1a7918bd32dabf03c15cd",
"firebase-messaging-sw.js": "a449775687e72d232ba03f04e21a7ac8",
"main.dart.js": "1ebcc45b97c524ec322f88065edda6d9",
"adaptive_foreground_icon.png": "30c3ac80141fdae1e1a6e2a723019c35",
"flutter.js": "888483df48293866f9f41d3d9274a779",
"app_launcher_icon.png": "30c3ac80141fdae1e1a6e2a723019c35",
"favicon.png": "2704101cb06ce66e2000356a312be25c",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/app_launcher_icon.png": "30c3ac80141fdae1e1a6e2a723019c35",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/error_image.png": "30c3ac80141fdae1e1a6e2a723019c35",
"manifest.json": "8111eda83e57c66dd627918939f19a48",
"assets/AssetManifest.json": "113f4433a310e4cd8b1ff0e11c292d56",
"assets/NOTICES": "b1500f6297d1524aaec52e436d5b1c6e",
"assets/FontManifest.json": "67a28da3784fc091c2f816d615fbf08a",
"assets/AssetManifest.bin.json": "5d385d6b0c31bdb59ac6e30554636b7c",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "d7d83bd9ee909f8a9b348f56ca7b68c6",
"assets/packages/font_awesome_flutter/lib/fonts/fa-solid-900.ttf": "b6a9bd2b6750f830e1d618f847206f9b",
"assets/packages/font_awesome_flutter/lib/fonts/fa-regular-400.ttf": "f23db3e1d30cccda3eca4b6e04dd0f56",
"assets/packages/font_awesome_flutter/lib/fonts/fa-brands-400.ttf": "eafdfd1fe143602951db6ff91b4e5b4e",
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
"assets/AssetManifest.bin": "04b83bc70dceae22a5200c11256196fa",
"assets/fonts/MaterialIcons-Regular.otf": "1fe05892c9f3e8995892eeaf4a3546c6",
"assets/assets/audios/favicon.png": "5dcef449791fa27946b3d35ad8803796",
"assets/assets/audios/new-notification-3-398649.mp3": "386725dd55412a7d59cb97d5a5cae711",
"assets/assets/audios/mac_os_glass.mp3": "d3c49fa3a525baebf761000d8e941f45",
"assets/assets/audios/notification_sound.mp3": "f705bb215690e40bca7cd9faeb1fcca1",
"assets/assets/jsons/favicon.png": "5dcef449791fa27946b3d35ad8803796",
"assets/assets/rive_animations/favicon.png": "5dcef449791fa27946b3d35ad8803796",
"assets/assets/images/ac223b5163821230e58fbb86c4f9ddd0d1772771.png": "9cfaf7a2cf89fcdf039ee55adb00373d",
"assets/assets/images/00315368875b4683939ad1b231c721a5cc3c7227.png": "5df3587379f6ca2c099057365381f3f4",
"assets/assets/images/google-calendar.png": "c1378bb190ea0e64c9b76ed47c0c956a",
"assets/assets/images/adaptive_foreground_icon.png": "30c3ac80141fdae1e1a6e2a723019c35",
"assets/assets/images/67b27b2cda06e9c69e5d000615c1153f80b09576.png": "8156c6193d98d980b292ecc646109f86",
"assets/assets/images/div.png": "7f867c4d5ce4bc4622c53ff3abe8b6c6",
"assets/assets/images/app_launcher_icon.png": "30c3ac80141fdae1e1a6e2a723019c35",
"assets/assets/images/favicon.png": "5dcef449791fa27946b3d35ad8803796",
"assets/assets/images/software-agent.png": "4cc6e6755b3173fb016ab93573809974",
"assets/assets/images/9939941067409a27e7334f498969c725da0ae11a.png": "9a72938a672f88e1c010f4548a625bb7",
"assets/assets/images/google.png": "c0e9477d27fb9189c80cc9c384466d9d",
"assets/assets/images/Logo_2.png": "09ee7dd41e886f24a8540067c216ff30",
"assets/assets/images/3e5cbd419c5eeea9116da22d9e39b5bfa4785a4d.png": "13daf430057b9e14b307cf1648aa35d0",
"assets/assets/images/svg.png": "2f35e15fa054a62e537d57a032042f29",
"assets/assets/images/eventbrite-logo.png": "cda111285fd925c3fd22109a6bc0958a",
"assets/assets/images/error_image.png": "30c3ac80141fdae1e1a6e2a723019c35",
"assets/assets/videos/favicon.png": "5dcef449791fa27946b3d35ad8803796",
"assets/assets/pdfs/favicon.png": "5dcef449791fa27946b3d35ad8803796",
"assets/assets/fonts/favicon.png": "5dcef449791fa27946b3d35ad8803796",
"mac_os_glass.mp3": "d3c49fa3a525baebf761000d8e941f45",
"canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b"};
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
