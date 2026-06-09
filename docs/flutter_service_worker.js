'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"version.json": "8492b47bf08a65ef95c81b421a39d45f",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"canvaskit/canvaskit.js": "728b2d477d9b8c14593d4f9b82b484f3",
"canvaskit/skwasm.js": "ea559890a088fe28b4ddf70e17e60052",
"canvaskit/skwasm.wasm": "39dd80367a4e71582d234948adc521c0",
"canvaskit/skwasm.js.symbols": "e72c79950c8a8483d826a7f0560573a1",
"canvaskit/chromium/canvaskit.js": "8191e843020c832c9cf8852a4b909d4c",
"canvaskit/chromium/canvaskit.js.symbols": "b61b5f4673c9698029fa0a746a9ad581",
"canvaskit/chromium/canvaskit.wasm": "f504de372e31c8031018a9ec0a9ef5f0",
"canvaskit/canvaskit.js.symbols": "bdcd3835edf8586b6d6edfce8749fb77",
"canvaskit/canvaskit.wasm": "7a3f4ae7d65fc1de6a6e7ddd3224bc93",
"flutter.js": "83d881c1dbb6d6bcd6b42e274605b69c",
"flutter_bootstrap.js": "ab1685ff81de7a7aecb54d2aba60d947",
"manifest.json": "15189f610220365682b3cd13d4091a17",
"index.html": "7efd205def57ca801b1f32e3b5e46463",
"/": "7efd205def57ca801b1f32e3b5e46463",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"main.dart.js": "749c3d0f075078571fe8e40200265192",
"assets/NOTICES": "07188dbf05b349470bbaa10947c40c7c",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/AssetManifest.bin": "61a0d3e1f0395392855ee5c4c3052953",
"assets/AssetManifest.bin.json": "dd26e99fe15db917cf1a2ed49cd632ac",
"assets/AssetManifest.json": "8c7b19749eb75475e66bd94f087c3e3a",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/fonts/MaterialIcons-Regular.otf": "8e681fabd9fc380b92cea2ae5ae12f24",
"assets/assets/images/landmark_selfie.png": "54af374f9a71e7c3e319c07aaca9427d",
"assets/assets/images/AgoraF2i.png": "59188425eb27260c02ae7711cc62ff8a",
"assets/assets/images/flower_bush.png": "14119287a1ddfbd8302c71625cca2189",
"assets/assets/images/cypress.png": "3c5e2415b6f435a7f0a7059b9ae702b6",
"assets/assets/images/olive_bush.png": "7ffee2028d55f6375115822a94115f6d",
"assets/assets/images/ghost_aristotle_copper.png": "3453c60de809afde0aabcb06189df7d1",
"assets/assets/images/Sym2.png": "f49ca5beeeec25b836c1628337b5a717",
"assets/assets/images/stoaback.png": "c213611cd1c6b278edccde9f2bcdad7e",
"assets/assets/images/road_vertical.png": "2f341b7a9be9570d5fda2f4e3a006354",
"assets/assets/images/Stoa2.png": "1980d4180fa5688c94f7efa2ea714fa3",
"assets/assets/images/broken_column.png": "68b4d738d508c46c2bfb3031fd0cbd01",
"assets/assets/images/herm.png": "3b125ddb2616878140fe1a8afaddd2f5",
"assets/assets/images/landmark_column.png": "52f2c3dfb8338573df8491332daef7d8",
"assets/assets/images/statue.png": "6ce99247ce8c586755ee9c8423370ad0",
"assets/assets/images/clouds.png": "d1e3ca2ce55719e13288820b4c0d8133",
"assets/assets/images/amphora.png": "eb0a37a3686f1a5898c0fffa86ac8142",
"assets/assets/images/Stoa1.png": "7e916918ff994225f70705e30905c685",
"assets/assets/images/brazier.png": "ca3c888f36c89edb9e071f54d3ae7230",
"assets/assets/images/ghost_socrates_gold.png": "a3a8156a3d15442a518b139ca1b4f719",
"assets/assets/images/landmark_thinker.png": "6234328936c7c35d0c91c23aec64ebd7",
"assets/assets/images/earth_tile.png": "bee100c4083659fdeb1282d293035072",
"assets/assets/images/Sym1.png": "08ebedb3625a768397d093ac8e308fa5",
"assets/assets/images/greek_market_compound.png": "86e6506793a628e1e761d09b3fa8fa20",
"assets/assets/images/road_tile.png": "1d2d511ee688e1bc0b0aaf73f59aaa11",
"assets/assets/images/ghost_plato_silver.png": "4b021bbdaf3776f19bbe541c873e04f8",
"assets/assets/images/vine_asset.png": "4e22829d75bd108d0a3a1264eae2f9c8"};
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
