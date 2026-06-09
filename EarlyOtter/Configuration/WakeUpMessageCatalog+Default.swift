import Foundation

extension WakeUpMessageCatalog {
    /// 📝 Wake-up copy lives here — edit these lines to change what the alarm
    /// says. Each window needs at least one line; add as many as you like and
    /// they'll rotate day to day. Keep lines short so they don't truncate in
    /// the Dynamic Island / Live Activity.
    static let `default` = WakeUpMessageCatalog(
        // 5:00 AM or earlier — brutally early, so be kind about it.
        predawn: WakeUpMessages(
            "Yikes, it's early — you've got this.",
            "Before the sun? Respect.",
            "Brutal hour, but you're built for it."
        ),
        // 5:01–8:00 AM — the classic morning wake-up.
        earlyMorning: WakeUpMessages(
            "Rise and shine!",
            "Good morning — up and at 'em.",
            "Let's start the day."
        ),
        // 8:01–10:00 AM — a relaxed, comfortable start.
        midMorning: WakeUpMessages(
            "Morning! Easy start today.",
            "Time to get moving.",
            "Comfy wake-up — let's go."
        ),
        // 10:01 AM onward — running late, so have a little fun with it.
        lateMorning: WakeUpMessages(
            "Get ready — hopefully you're already awake!",
            "Late start, let's go.",
            "Rise and… well, it's basically lunch."
        )
    )
}
