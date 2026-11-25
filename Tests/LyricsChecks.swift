import Foundation
@main struct LyricsChecks {
 static func main() async throws {
  let doc = LyricsParser.parse("[ar:Artist]\n[offset:500]\n[00:01.20][00:03.456]First\ncontinuation\n[00:05]Next\n[00:05]Translation\n[00:99]bad", source: "Test")
  precondition(doc.lines.count == 3)
  precondition(doc.lines[0].time == 1.2 && doc.lines[1].time == 3.456)
  precondition(doc.lines[0].text == "First\ncontinuation" && doc.lines[1].text == "First\ncontinuation")
  precondition(doc.lines[2].text == "Next\nTranslation")
  precondition(doc.active(at: 0) == nil && doc.active(at: 1) == 0 && doc.active(at: 4.6) == 2)
  precondition(doc.active(at: 2) == 0 && doc.active(at: 0) == nil)
  let plain = LyricsParser.parse("One\nTwo\n\nThree", source: "Imported")
  precondition(!plain.synchronized && plain.lines.count == 3 && plain.active(at: 99) == nil)
  precondition(LyricsParser.parse("[garbage]\n", source: "Bad").lines.isEmpty)
  let q = LyricsQuery(title: "Song slowed", artist: "Artist", album: "", duration: 200)
  let candidate = LyricsCandidate(id: 1, trackName: q.title, artistName: q.artist, duration: 200, instrumental: false, plainLyrics: "Text", syncedLyrics: "[00:01]Text")
  precondition(!candidate.document(q).synchronized)
  precondition(candidate.score(LyricsQuery(title: "Other", artist: q.artist, album: "", duration: 200)) == 0)
  let decorated = LyricsQuery(title: "Artist - Song (Official Audio)", artist: "Unknown Artist", album: "", duration: 200)
  precondition(decorated.searchArtist == "Artist" && decorated.searchTitle == "Song")
  precondition(!LyricsQuery(title: "Credits", artist: "Artist", album: "", duration: 200).altered)
  let recording = LyricsQuery(title: "Song", artist: "Artist", album: "", duration: 200)
  let good = LyricsCandidate(id: 2, trackName: "Song", artistName: "Artist, Artist", duration: 200, instrumental: false, plainLyrics: nil, syncedLyrics: "[00:01]Text")
  let wrong = LyricsCandidate(id: 3, trackName: "Song", artistName: "Other", duration: 200, instrumental: false, plainLyrics: nil, syncedLyrics: "[00:01]Text")
  precondition(LyricsCandidateMatcher.score(good, recording) > LyricsCandidateMatcher.score(wrong, recording))
  let noDuration = LyricsQuery(title: "Song", artist: "Artist", album: "", duration: 0)
  precondition(LyricsCandidateMatcher.best([good], query: noDuration)?.lines.isEmpty == false)
  precondition(LyricsCandidateMatcher.best([good], query: noDuration)?.synchronized == false)
  let differentRecording = LyricsQuery(title: "Song", artist: "Artist", album: "", duration: 300)
  precondition(LyricsCandidateMatcher.best([good], query: differentRecording)?.lines.isEmpty == false,
      "A duration mismatch must downgrade timing, not hide matched text")
  precondition(LyricsCandidateMatcher.best([good], query: differentRecording)?.synchronized == false)
  precondition(LyricsCandidateMatcher.best([wrong], query: recording) == nil)
  let emptyCandidate = LyricsCandidate(id: 0, trackName: "Song", artistName: "Artist", duration: 200,
      instrumental: false, plainLyrics: nil, syncedLyrics: nil)
  precondition(LyricsCandidateMatcher.best([emptyCandidate, good], query: recording)?.lines.isEmpty == false)
  precondition(LyricsQuery(title: "Puzzle - Loose Cannon", artist: "Puzzle", album: "", duration: 0).searchTitle == "Loose Cannon")
  precondition(LyricsQuery(title: "Loose Cannon — Puzzle", artist: "Puzzle", album: "", duration: 0).searchTitle == "Loose Cannon")
  let data = try JSONEncoder().encode(doc)
  let restored = try JSONDecoder().decode(LyricsDocument.self, from: data)
  precondition(restored.lines == doc.lines)
  let yrc = LyricsFormats.parse("[1000,1000](1000,500,0)Hi(1500,500,0) there", format: "yrc", source: "Fixture")
  precondition(yrc.lines[0].words?[1].start == 1.5 && yrc.lines[0].end == 2)
  let krc = LyricsFormats.parse("[1000,1000]<0,500,0>Hi<500,500,0> there", format: "krc", source: "Fixture")
  precondition(krc.lines[0].words == yrc.lines[0].words)
  let qrc = LyricsFormats.parse("[1000,1000]Hi(1000,500) there(1500,500)", format: "qrc", source: "Fixture")
  precondition(qrc.lines[0].words == yrc.lines[0].words)
  let ttml = LyricsFormats.parse("<tt><body><p begin=\"1s\" end=\"2000ms\"><span begin=\"00:01.000\" end=\"00:01.500\">Hi</span><span begin=\"00:01.500\" end=\"00:02.000\"> there</span></p></body></tt>", format: "ttml", source: "Fixture")
  precondition(ttml.lines[0].words == yrc.lines[0].words && ttml.active(at: 2.1) == nil)
  precondition(LyricsFormats.parse("krc1protected", format: "krc", source: "Fixture").lines.isEmpty)
  let enhanced = LyricsFormats.parse("[00:01]<00:01.000>Hi<00:01.500> there\n[00:02]Next", format: "lrc", source: "Fixture")
  precondition(enhanced.lines[0].words == yrc.lines[0].words)
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: directory) }
  let store = LyricsStore(directory: directory)
  try await store.install(plain, id: "track")
  try await store.cache(doc, id: "track")
  try await store.adjust(-1.5, id: "track")
  let reopened = LyricsStore(directory: directory)
  let entry = await reopened.read("track")
  precondition(entry.imported?.lines == plain.lines && entry.cached?.lines == doc.lines && entry.offsets?["imported"] == -1.5)
  try await reopened.install(nil, id: "track")
  let removed = await reopened.read("track")
  precondition(removed.imported == nil && removed.cached != nil)
  let audio = directory.appendingPathComponent("original.dat")
  try Data("fingerprint fixture".utf8).write(to: audio)
  let provider = TestLyricsProvider()
  let service = LyricsService(provider: provider, directory: directory.appendingPathComponent("cache"))
  let query = LyricsQuery(title: "Song", artist: "Artist", album: "", duration: 200)
  async let first = service.load(url: audio, query: query)
  async let second = service.load(url: audio, query: query)
  let id = await service.identifier(url: audio)
  await provider.waitUntilStarted()
  await service.imported(plain, id: id)
  let responses = await (first, second)
  precondition(responses.0.1?.source == "Imported" && responses.1.1?.source == "Imported")
  let count = await provider.calls
  precondition(count == 1, "Concurrent requests must be coalesced; late results cannot replace an import")
  let renamed = directory.appendingPathComponent("renamed.dat")
  try FileManager.default.moveItem(at: audio, to: renamed)
  let renamedID = await service.identifier(url: renamed)
  precondition(id == renamedID, "Renaming must preserve imported lyrics")
  let offline = LyricsService(provider: OfflineLyricsProvider(), directory: directory.appendingPathComponent("cache"))
  let cached = await offline.load(url: renamed, query: query)
  precondition(cached.1?.source == "Imported")
  await offline.imported(nil, id: id)
  let cachedOnline = await offline.load(url: renamed, query: query)
  precondition(cachedOnline.1?.synchronized == true, "Removing an import must retain the offline provider cache")
  var sourceA = doc; sourceA.resultKey = "A:1:lrc"
  var sourceB = doc; sourceB.resultKey = "B:1:ttml"
  try await store.cache(sourceA, id: "sources")
  try await store.select(sourceA, id: "sources")
  try await store.adjust(0.5, id: "sources")
  try await store.cache(sourceB, id: "sources")
  let stillSelected = await store.resolved("sources")
  precondition(stillSelected?.resultKey == sourceA.resultKey && stillSelected?.offset == doc.offset + 0.5)
  try await store.select(sourceB, id: "sources")
  try await store.adjust(-1, id: "sources")
  try await store.select(sourceA, id: "sources")
  let sourceRestored = await store.resolved("sources")
  precondition(sourceRestored?.offset == doc.offset + 0.5)
  let fallback = LyricsProviderManager(providers: [("Offline", OfflineLyricsProvider()), ("Fixture", TestLyricsProvider())])
  let fallbackResults = try await fallback.search(query)
  precondition(fallbackResults.count == 1)
  let nullable = Data(#"[{"id":101,"trackName":"Song","artistName":"Artist","duration":null,"instrumental":false,"plainLyrics":"One","syncedLyrics":"[00:01]One"},{"id":102,"trackName":"Song","artistName":"Artist","duration":200,"instrumental":false,"plainLyrics":"Two","syncedLyrics":"[00:02]Two"},{"id":"broken","trackName":"Song"}]"#.utf8)
  let tolerant = try LRCLIBProvider.candidates(nullable)
  precondition(tolerant.count == 2 && tolerant[0].duration == 0 && tolerant[1].duration == 200,
      "A nullable duration or one malformed record must not discard the whole search response")
  precondition(!tolerant[0].document(query).synchronized && tolerant[1].document(query).synchronized)
  let emptySync = Data(#"[{"id":103,"trackName":"Song","artistName":"Artist","duration":200,"plainLyrics":"Plain words","syncedLyrics":""}]"#.utf8)
  let plainOnly = try LRCLIBProvider.candidates(emptySync)
  precondition(plainOnly.first?.document(query).lines.first?.text == "Plain words")
  for duration in [0.0, 177.0, 400.0] {
   let fallbackService = LyricsService(provider: FixedLyricsProvider(candidates: [good]),
       directory: directory.appendingPathComponent("duration-\(duration)"))
   let variant = LyricsQuery(title: "Song", artist: "Artist", album: "", duration: duration)
   let result = await fallbackService.load(url: renamed, query: variant)
   precondition(result.2 == .ready && result.1?.lines.isEmpty == false,
       "The complete fetch/select/cache path must keep exact-metadata lyrics visible")
   precondition(result.1?.synchronized == false)
  }
  let recoveryProvider = RecoveringLyricsProvider()
  let recoveryDirectory = directory.appendingPathComponent("recovery")
  let recovery = LyricsService(provider: recoveryProvider, directory: recoveryDirectory)
  let failure = await recovery.load(url: renamed, query: query)
  precondition(failure.1 == nil && failure.2 == .unavailable)
  let failedEntry = await recovery.store.read(id)
  precondition(failedEntry.checked == nil, "Network failures must never be stored as missing lyrics")
  let recovered = await recovery.load(url: renamed, query: query, force: true)
  precondition(recovered.1 != nil && recovered.2 == .ready, "Service-level cooldown must not suppress a healthy retry")
  let legacyDirectory = directory.appendingPathComponent("legacy-negative")
  let legacyStore = LyricsStore(directory: legacyDirectory)
  try await legacyStore.cache(nil, id: id)
  let legacyService = LyricsService(provider: TestLyricsProvider(), directory: legacyDirectory)
  let retriedLegacy = await legacyService.load(url: renamed, query: query)
  precondition(retriedLegacy.1 != nil, "Legacy negative cache must not hide newly available results")
  let config = URLSessionConfiguration.ephemeral
  config.protocolClasses = [LyricsFixtureProtocol.self]
  let session = URLSession(configuration: config)
  defer { session.invalidateAndCancel() }
  let lrclibHTTP = try await LRCLIBProvider(session: session).search(query)
  precondition(lrclibHTTP.count == 2 && lrclibHTTP[0].duration == 200,
      "Nullable LRCLIB responses must survive the real provider request/decode/ranking path")
  let liriqo = try await LiriQoProvider(session: session).search(query)
  precondition(liriqo.count == 1)
  let native = liriqo[0].document(query)
  precondition(native.synchronizationLevel == "Word synced")
  precondition(native.lines[0].time == 1.25 && native.lines[0].end == 3.75)
  precondition(native.lines[0].words?[1].start == 2.125 && native.lines[0].words?[1].end == 3.5)
  precondition(native.active(at: 1.24) == nil && native.active(at: 2) == 0 && native.active(at: 4) == nil)
  precondition(native.active(at: 9) == 1 && native.active(at: 1.3) == 0)
  precondition(native.attribution?.contains("Fixture Source") == true)
  precondition(!liriqo[0].document(q).synchronized, "Edited recordings cannot inherit original timing")
  let better = try await BetterLyricsProvider(session: session).search(query)
  precondition(better.count == 1 && better[0].duration == 0)
  precondition(!better[0].document(query).synchronized, "Metadata-free TTML needs recording confirmation")
  precondition(better[0].nativeDocument?.lines[0].words?.first?.start == 1.25)
  let locked = LyricsQuery(title: "Locked", artist: "Artist", album: "", duration: 200)
  do {
   _ = try await BetterLyricsProvider(session: session).search(locked)
   preconditionFailure("A cache miss must remain distinguishable from a catalog with no lyrics")
  } catch let error as LyricsHTTPError { precondition(error.statusCode == 401) }
  do {
   _ = try await LiriQoProvider(session: session).search(LyricsQuery(title: "Rate", artist: "Artist", album: "", duration: 200))
   preconditionFailure("Rate limiting must propagate backoff")
  } catch let error as LyricsHTTPError { precondition(error.retryAfter == 123) }
  let malformed = Data(#"{"metadata":{},"error":"temporarily unavailable"}"#.utf8)
  do { _ = try LiriQoProvider.candidates(malformed, query: query); preconditionFailure("API errors are not empty searches") }
  catch { }
  let unsynced = Data(#"{"tracks":[{"provider":"test","title":"Song","artist":"Artist","plain":"One\nTwo"}]}"#.utf8)
  let plainResult = try LiriQoProvider.candidates(unsynced, query: query)
  precondition(plainResult.count == 1 && !plainResult[0].document(query).synchronized)
  var duplicate = liriqo[0]
  duplicate.providerID = "Fixture Mirror"
  duplicate.nativeDocument?.resultKey = "mirror:1:json"
  duplicate.nativeDocument?.attribution = "https://mirror.example"
  let merged = LyricsResultIdentity.deduplicate([liriqo[0], duplicate], query: query, preferredKey: duplicate.key)
  precondition(merged.count == 1 && merged[0].key == duplicate.key)
  precondition(merged[0].nativeDocument?.sourceAttributions?.count == 2)
  var unknownMetadata = duplicate
  unknownMetadata.duration = 0
  unknownMetadata.nativeDocument?.timingTrusted = false
  precondition(LyricsResultIdentity.deduplicate([liriqo[0], unknownMetadata], query: query).count == 1,
      "Identical payloads from cache-only and metadata-rich providers must merge")
  var anotherRecording = duplicate; anotherRecording.duration = 240
  precondition(LyricsResultIdentity.deduplicate([liriqo[0], anotherRecording], query: query).count == 2)
  var differentTiming = duplicate
  differentTiming.nativeDocument?.lines[0].words?[0].start = 1.3
  precondition(LyricsResultIdentity.deduplicate([liriqo[0], differentTiming], query: query).count == 2)
  await service.choose(liriqo[0], query: query, id: id)
  await service.adjust(0.125, id: id, key: liriqo[0].key)
  await service.choose(better[0], query: query, id: id)
  await service.adjust(-0.75, id: id, key: better[0].key)
  await service.choose(liriqo[0], query: query, id: id)
  let saved = await offline.load(url: renamed, query: query)
  precondition(saved.1?.resultKey == liriqo[0].key && saved.1?.offset == 0.125)
  let offlineChoices = try await offline.alternatives(query, id: id)
  precondition(offlineChoices.contains { $0.key == better[0].key })
  let sharedProvider = TestLyricsProvider()
  let sharedManager = LyricsProviderManager(providers: [("Fixture", sharedProvider)])
  async let sharedFirst = sharedManager.search(query)
  async let sharedSecond = sharedManager.search(query)
  _ = try await (sharedFirst, sharedSecond)
  let sharedCalls = await sharedProvider.calls
  precondition(sharedCalls == 1, "Provider searches for the same recording must be coalesced")
  do {
   _ = try await LyricsProviderManager(providers: []).searchDetailed(query)
   preconditionFailure("An empty registry must never look like a successful search with no lyrics")
  } catch LyricsProviderConfigurationError.noProviders { }
  let thirdProvider = TestLyricsProvider()
  let fourthProvider = TestLyricsProvider()
  let allSources = LyricsProviderManager(providers: [("Rejected", OfflineLyricsProvider()), ("Empty", EmptyLyricsProvider()), ("Third", thirdProvider), ("Fourth", fourthProvider)])
  _ = try await allSources.search(query)
  let allAttempts = await allSources.report(query)
  precondition(allAttempts.map(\.name) == ["Rejected", "Empty", "Third", "Fourth"])
  precondition(allAttempts[0].failed && allAttempts[2].matchCount > 0 && allAttempts[3].matchCount > 0,
      "An empty or rejected provider must never prevent later providers from running")
  let cacheOnly = PublicCacheFixtureProvider()
  let cacheFallback = LyricsProviderManager(providers: [("Better Lyrics", cacheOnly), ("Fallback", TestLyricsProvider())])
  _ = try await cacheFallback.search(LyricsQuery(title: "Missing", artist: "Artist", album: "", duration: 200))
  _ = try await cacheFallback.search(query)
  let cacheCalls = await cacheOnly.calls
  precondition(cacheCalls == 2, "One public cache miss must not suppress another song")
  for title in ["Artist - Song", "Song - Artist", "Artist -- Song", "Song -- Artist", "Artist—Song", "Song – Artist"] {
   let filename = LyricsQuery(title: title, artist: "Unknown Artist", album: "", duration: 200)
   let untitledService = LyricsService(provider: LRCLIBProvider(session: session), directory: directory.appendingPathComponent(UUID().uuidString))
   let result = await untitledService.load(url: renamed, query: filename)
   precondition(result.2 == .ready && result.1?.lines.isEmpty == false, "Both filename orders must reach displayable lyrics")
  }
  precondition(LyricsQuery(title: "Loose Cannon -- Puzzle", artist: "Puzzle", album: "", duration: 177).searchTitle == "Loose Cannon")
  precondition(LyricsQuery(title: "Loose Cannon — Puzzle", artist: "Puzzle", album: "", duration: 177).searchTitle == "Loose Cannon")
  precondition(LyricsQuery(title: "Thunderstruck", artist: "AC-DC", album: "", duration: 292).searchArtist == "AC-DC")
  let titleOnly = LyricsQuery(title: "Song", artist: "Unknown Artist", album: "", duration: 200)
  let titleCandidates = try await LRCLIBProvider(session: session).search(titleOnly)
  let titleText = LyricsCandidateMatcher.best(titleCandidates, query: titleOnly)
  precondition(titleText?.lines.isEmpty == false && titleText?.synchronized == false)
  precondition(LyricsCandidateMatcher.best([good, wrong], query: titleOnly) == nil,
      "Ambiguous title-only recordings must not silently pick an artist")
  let searchDirectory = directory.appendingPathComponent("search-override")
  let editable = LyricsService(provider: TestLyricsProvider(), directory: searchDirectory)
  await editable.updateSearch(LyricsSearchMetadata(title: "Song", artist: "Artist"), id: id)
  let reopenedSearch = LyricsService(provider: TestLyricsProvider(), directory: searchDirectory)
  let repaired = await reopenedSearch.load(url: renamed, query: LyricsQuery(title: "wrong filename", artist: "Unknown Artist", album: "", duration: 200))
  precondition(repaired.1?.provenance?.title == "Song" && repaired.2 == .ready)
  precondition(!LyricsFollowPolicy.intentionallyMoved(5) && LyricsFollowPolicy.intentionallyMoved(40))
  precondition(!LyricsFollowPolicy.awayFromCurrent(distance: 10, viewport: 300))
  precondition(LyricsFollowPolicy.awayFromCurrent(distance: 100, viewport: 300))
  if ProcessInfo.processInfo.arguments.contains("--live-lyrics") { try await verifyLiveLyrics(directory: directory) }
  print("Lyrics parser, offsets, seeking, malformed input, plain text, version safety and serialization passed")
 }
 static func verifyLiveLyrics(directory: URL) async throws {
  for (title, artist, album, duration) in [("Lovefool", "The Cardigans", "", 197.0), ("Espresso", "Sabrina Carpenter", "", 175.0), ("Loose Cannon", "Puzzle", "X Hail", 177.02893424036282), ("Oh Klahoma", "Jack Stauber", "Pop food", 185.33875)] {
   let query = LyricsQuery(title: title, artist: artist, album: album, duration: duration)
   let candidates = try await LRCLIBProvider().search(query)
   precondition(candidates.contains { $0.matchesMetadata(query) }, "Live LRCLIB metadata match missing")
   let onlineManager = LyricsProviderManager()
   let onlinePath = directory.appendingPathComponent("all-providers-" + title)
   try Data(("provider file " + title).utf8).write(to: onlinePath)
   let onlineService = LyricsService(provider: onlineManager, directory: directory.appendingPathComponent(UUID().uuidString))
   let atomic = try await onlineManager.searchDetailed(query)
   precondition(atomic.attempts.count == 4 && !atomic.candidates.isEmpty, "One atomic result must contain both candidates and all provider statuses")
   let live = await onlineService.load(url: onlinePath, query: query)
   precondition(live.2 == .ready && live.1?.lines.isEmpty == false, "All-provider pipeline failed despite available lyrics")
   let catalog = await onlineService.sourceCatalog(url: onlinePath, query: query)
   precondition(!catalog.2.isEmpty && catalog.3.count == 4, "Source selection must contain real choices and all provider attempts")
   for attempt in catalog.3 { print("Live provider: \(title), \(attempt.name), \(attempt.summary), HTTP \(attempt.statusCode ?? 200)") }
   let defaultService = LyricsService(directory: directory.appendingPathComponent(UUID().uuidString))
   let defaultCatalog = await defaultService.sourceCatalog(url: onlinePath, query: query)
   precondition(defaultCatalog.3.count == 4 && !defaultCatalog.2.isEmpty,
       "Default service must expose the same provider results as the injected manager")
   let sharedLoad = await LyricsService.shared.load(url: onlinePath, query: query, force: true)
   precondition(sharedLoad.2 == .ready && sharedLoad.1?.lines.isEmpty == false,
       "Production shared loader must produce displayable lyrics before source selection")
   let sharedCatalog = await LyricsService.shared.sourceCatalog(url: onlinePath, query: query)
   precondition(sharedCatalog.3.count == 4 && !sharedCatalog.2.isEmpty,
       "Production shared service must show all provider states and actual source choices")
   print("Production source catalog: \(title), choices \(sharedCatalog.2.count), providers \(sharedCatalog.3.count)")
   for filename in [artist + " - " + title, title + " - " + artist, title + " -- " + artist, artist + "—" + title] {
    let fileQuery = LyricsQuery(title: filename, artist: "Unknown Artist", album: "", duration: duration)
    let fileResults = try await LRCLIBProvider().search(fileQuery)
    precondition(LyricsCandidateMatcher.best(fileResults, query: fileQuery)?.lines.isEmpty == false, "Live filename search failed")
   }
   for localDuration in [0.0, duration, duration + 10000] {
    let path = directory.appendingPathComponent("live-\(title)-\(localDuration)")
    try Data("local fixture \(title) \(localDuration)".utf8).write(to: path)
    let cacheDirectory = directory.appendingPathComponent(UUID().uuidString)
    let service = LyricsService(provider: FixedLyricsProvider(candidates: candidates), directory: cacheDirectory)
    var localQuery = query; localQuery.duration = localDuration
    let result = await service.load(url: path, query: localQuery)
    precondition(result.2 == .ready && result.1?.lines.isEmpty == false, "Live lyrics were lost after retrieval")
    if localDuration != duration { precondition(result.1?.synchronized == false) }
    let offline = LyricsService(provider: OfflineLyricsProvider(), directory: cacheDirectory)
    let saved = await offline.load(url: path, query: localQuery)
    precondition(saved.2 == .ready && saved.1?.lines.isEmpty == false, "Live lyrics did not survive offline storage")
    print("Live lyrics: \(title), local duration \(localDuration), candidates \(candidates.count), saved lines \(result.1!.lines.count), sync \(result.1!.synchronized)")
   }
  }
 }
}

actor TestLyricsProvider: LyricsProvider {
 var calls = 0
 private var startWaiters: [CheckedContinuation<Void, Never>] = []
 func waitUntilStarted() async {
  if calls > 0 { return }
  await withCheckedContinuation { startWaiters.append($0) }
 }
 func search(_ query: LyricsQuery) async throws -> [LyricsCandidate] {
  calls += 1
  let waiters = startWaiters; startWaiters = []
  for waiter in waiters { waiter.resume() }
  try await Task.sleep(nanoseconds: 150_000_000)
  return [LyricsCandidate(id: 1, trackName: query.title, artistName: query.artist, duration: query.duration,
      instrumental: false, plainLyrics: "Text", syncedLyrics: "[00:01]Text")]
 }
}
struct OfflineLyricsProvider: LyricsProvider {
 func search(_ query: LyricsQuery) async throws -> [LyricsCandidate] { throw URLError(.notConnectedToInternet) }
}

// Synthetic, original text only. Default CI checks do not depend on live services.
final class LyricsFixtureProtocol: URLProtocol {
 static let liriqo = #"{"metadata":{"title":"Song","artist":"Artist","album":"Album","duration":200},"tracks":[{"provider":"fixture","upstreamProvider":"Fixture Source","title":"Song","artist":"Artist","duration":200,"nativeWordTiming":true,"syncLevel":"word","plain":"One two\nNext","timed":[{"text":"One two","start":1250,"end":3750,"words":[{"text":"One ","start":1250,"end":2000},{"text":"two","start":2125,"end":3500}]},{"text":"Next","start":9000,"end":10000}]}]}"#
 override class func canInit(with request: URLRequest) -> Bool { true }
 override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
 override func startLoading() {
  precondition(request.cachePolicy == .reloadIgnoringLocalCacheData, "Lyrics HTTP searches must not replay stale URLCache responses")
  let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
  precondition(!items.contains { $0.name == "q" && ($0.value ?? "").contains("Unknown Artist") }, "Placeholder artists must never be sent as search keywords")
  let title = items.first { $0.name == "title" || $0.name == "s" }?.value
  let status = title == "Rate" ? 429 : title == "Locked" ? 401 : 200
  let payload: Data
  if request.url?.host == "lrclib.net" {
   payload = Data(#"[{"id":1,"trackName":"Song","artistName":"Artist","duration":null,"plainLyrics":"One","syncedLyrics":"[00:01]One"},{"id":2,"trackName":"Song","artistName":"Artist","duration":200,"plainLyrics":"Two","syncedLyrics":"[00:02]Two"}]"#.utf8)
  } else if request.url?.host == "api.betterlyrics.org" {
   let xml = "<tt><body><p begin=\"1.25s\" end=\"3.75s\"><span begin=\"00:01.250\" end=\"00:02.000\">One</span></p></body></tt>"
   payload = try! JSONSerialization.data(withJSONObject: ["ttml": xml])
  } else {
   precondition(!items.contains { $0.name == "album" && ($0.value ?? "").isEmpty }, "Unknown album must be omitted from LiriQo requests")
   payload = Data(Self.liriqo.utf8)
  }
  let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Retry-After": "123"])!
  client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
  client?.urlProtocol(self, didLoad: payload)
  client?.urlProtocolDidFinishLoading(self)
 }
 override func stopLoading() { }
}

actor RecoveringLyricsProvider: LyricsProvider {
 private var failed = false
 func search(_ query: LyricsQuery) async throws -> [LyricsCandidate] {
  if !failed { failed = true; throw URLError(.notConnectedToInternet) }
  return [LyricsCandidate(id: 1, trackName: query.title, artistName: query.artist, duration: query.duration,
      instrumental: false, plainLyrics: "One", syncedLyrics: "[00:01]One")]
 }
}

struct FixedLyricsProvider: LyricsProvider {
 var candidates: [LyricsCandidate]
 func search(_ query: LyricsQuery) async throws -> [LyricsCandidate] { candidates }
}

struct EmptyLyricsProvider: LyricsProvider {
 func search(_ query: LyricsQuery) async throws -> [LyricsCandidate] { [] }
}
actor PublicCacheFixtureProvider: LyricsProvider {
 var calls = 0
 func search(_ query: LyricsQuery) async throws -> [LyricsCandidate] {
  calls += 1
  if query.title == "Missing" { throw LyricsHTTPError(retryAfter: 60, statusCode: 401) }
  return [LyricsCandidate(id: 9, trackName: query.title, artistName: query.artist, duration: query.duration, instrumental: false, plainLyrics: "One", syncedLyrics: "[00:01]One")]
 }
}
