import Testing
import Foundation
@testable import Hydrophone

/// Queue / transport logic in PlayerModel (engine-independent for now).
/// See docs/03-playback-engine.md, docs/08-testing.md.
@MainActor
struct PlayerQueueTests {
    private func songs(_ ids: [String]) -> [Song] {
        ids.map { Song(id: $0, title: "Title \($0)", duration: 100) }
    }

    @Test func playSetsCurrentTrackAndState() {
        let player = PlayerModel()
        player.play(tracks: songs(["1", "2", "3"]), startAt: 1)
        #expect(player.currentTrack?.id == "2")
        #expect(player.isPlaying)
        #expect(player.duration == 100)
    }

    @Test func nextAdvancesAndStopsAtEnd() {
        let player = PlayerModel()
        player.play(tracks: songs(["1", "2"]), startAt: 0)
        player.next()
        #expect(player.currentTrack?.id == "2")
        player.next()
        #expect(player.state == .stopped)
    }

    @Test func nextWrapsWhenRepeatAll() {
        let player = PlayerModel()
        player.play(tracks: songs(["1", "2"]), startAt: 1)
        player.repeatMode = .all
        player.next()
        #expect(player.currentTrack?.id == "1")
    }

    @Test func previousRestartsTrackWhenPastThreshold() {
        let player = PlayerModel()
        player.play(tracks: songs(["1", "2"]), startAt: 1)
        player.position = 10
        player.previous()
        #expect(player.currentTrack?.id == "2") // restarts, doesn't go back
        #expect(player.position == 0)
    }

    @Test func playNextInsertsAfterCurrent() {
        let player = PlayerModel()
        player.play(tracks: songs(["1", "2"]), startAt: 0)
        player.playNext(songs(["9"]))
        #expect(player.queue.map(\.id) == ["1", "9", "2"])
    }

    /// The manual-start and gapless-advance paths share one `becomeCurrent`
    /// transition — arriving at the same track either way must leave
    /// identical current-track state.
    @Test func manualStartAndGaplessAdvanceAgreeOnCurrentState() {
        let direct = PlayerModel()
        direct.play(tracks: songs(["1", "2"]), startAt: 1)

        let gapless = PlayerModel()
        gapless.play(tracks: songs(["1", "2"]), startAt: 0)
        gapless.handle(.wantNext(afterIndex: 0))   // engine pre-buffers "2"
        gapless.handle(.trackChanged(index: 1))    // …and crosses into it

        #expect(gapless.currentTrack == direct.currentTrack)
        #expect(gapless.currentIndex == direct.currentIndex)
        #expect(gapless.duration == direct.duration)
        #expect(gapless.position == direct.position)
    }

    @Test func seekClampsToDuration() {
        let player = PlayerModel()
        player.play(tracks: songs(["1"]), startAt: 0)
        player.seek(to: 999)
        #expect(player.position == 100)
        player.seek(to: -5)
        #expect(player.position == 0)
    }
}
