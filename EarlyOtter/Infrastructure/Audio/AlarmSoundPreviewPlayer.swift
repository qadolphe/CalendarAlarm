import AVFoundation
import Foundation
import Observation

// Auditions a bundled alarm tone while the user browses the sound list, the way
// the Clock app plays a tone the moment you tap it.
@MainActor
@Observable
final class AlarmSoundPreviewPlayer {
    private(set) var playingOption: AlarmSoundOption?

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var delegate: PlaybackDelegate?

    deinit {
        player?.stop()
    }

    // Restarts from the top when the same tone is tapped twice, matching the
    // Clock app's behaviour.
    func play(_ option: AlarmSoundOption) {
        stop()

        // The system alarm sound is resolved inside the system alarm process
        // when the alarm fires; there is no file here to audition.
        guard let resourceName = option.resourceName else { return }

        let name = (resourceName as NSString).deletingPathExtension
        let ext = (resourceName as NSString).pathExtension

        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            assertionFailure("Missing bundled alarm tone: \(resourceName)")
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            let delegate = PlaybackDelegate { [weak self] in
                self?.stop()
            }

            player.delegate = delegate
            player.numberOfLoops = Self.loopCount(forDuration: player.duration)
            player.prepareToPlay()
            player.play()

            self.player = player
            self.delegate = delegate
            playingOption = option
        } catch {
            player = nil
            delegate = nil
            playingOption = nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
        delegate = nil
        playingOption = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // Most of these tones are under a second, and one pass is too brief to
    // judge. Repeat short tones until the audition covers a few seconds, while
    // leaving anything already long enough to play once.
    private static func loopCount(forDuration duration: TimeInterval) -> Int {
        let targetDuration: TimeInterval = 4
        let maximumRepeats = 4

        guard duration > 0 else { return 0 }

        let repeats = Int((targetDuration / duration).rounded(.up))
        return min(max(repeats, 1), maximumRepeats) - 1
    }

    private final class PlaybackDelegate: NSObject, AVAudioPlayerDelegate {
        private let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            Task { @MainActor in self.onFinish() }
        }
    }
}
