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
  let data = try JSONEncoder().encode(doc)
  let restored = try JSONDecoder().decode(LyricsDocument.self, from: data)
  precondition(restored.lines == doc.lines)
  let yrc = LyricsFormats.parse("[1000,1000](1000,500,0)Hi(1500,500,0) there", format: "yrc", source: "Fixture")
  precondition(yrc.lines[0].words?[1].start == 1.5 && yrc.lines[0].end == 2)
  let krc = LyricsFormats.parse("[1000,1000]<0,500,0>Hi<500,500,0> there", format: "krc", source: "Fixture")
  precondition(krc.lines[0].words == yrc.lines[0].words)
  let qrc = LyricsFormats.parse("[1000,1000]Hi(1000,500) there(1500,500)", format: "qrc", source: "Fixture")
  precondition(qrc.lines[0].words == yrc.lines[0].words)
  let ttml = LyricsFormats.parse("<tt><body><p begin=\"1s\" end=\"2000ms\"><span begin=\"1s\" end=\"1.5s\">Hi</span><span begin=\"1.5s\" end=\"2s\"> there</span></p></body></tt>", format: "ttml", source: "Fixture")
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
  try await Task.sleep(nanoseconds: 30_000_000)
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
  precondition(!LyricsFollowPolicy.intentionallyMoved(5) && LyricsFollowPolicy.intentionallyMoved(40))
  precondition(!LyricsFollowPolicy.awayFromCurrent(distance: 10, viewport: 300))
  precondition(LyricsFollowPolicy.awayFromCurrent(distance: 100, viewport: 300))
  print("Lyrics parser, offsets, seeking, malformed input, plain text, version safety and serialization passed")
 }
}

actor TestLyricsProvider: LyricsProvider {
 var calls = 0
 func search(_ query: LyricsQuery) async throws -> [LyricsCandidate] {
  calls += 1
  try await Task.sleep(nanoseconds: 150_000_000)
  return [LyricsCandidate(id: 1, trackName: query.title, artistName: query.artist, duration: query.duration,
      instrumental: false, plainLyrics: "Text", syncedLyrics: "[00:01]Text")]
 }
}
struct OfflineLyricsProvider: LyricsProvider {
 func search(_ query: LyricsQuery) async throws -> [LyricsCandidate] { throw URLError(.notConnectedToInternet) }
}
