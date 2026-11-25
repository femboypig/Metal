import Foundation
@main struct LyricsChecks {
 static func main() throws {
  let doc = LyricsParser.parse("[ar:Artist]\n[offset:500]\n[00:01.20][00:03.456]First\ncontinuation\n[00:05]Next\n[00:05]Translation\n[00:99]bad", source: "Test")
  precondition(doc.lines.count == 3)
  precondition(doc.lines[0].time == 1.2 && doc.lines[1].time == 3.456)
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
  print("Lyrics parser, offsets, seeking, malformed input, plain text, version safety and serialization passed")
 }
}
