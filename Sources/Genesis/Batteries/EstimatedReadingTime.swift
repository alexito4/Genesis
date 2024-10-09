import Foundation

public struct EstimatedReadingTime: Equatable, Sendable {
    /// Estimated words contained in the provided `String` given the used strategy
    public let words: Int

    /// A rough estimate of how many minutes it takes to read.
    public let timeMinutes: Double

    /// Rounded estimation of how many minutes it takes to read.
    public let minutes: Int

    init(words: Int, timeMinutes: Double, minutes: Int) {
        self.words = words
        self.timeMinutes = timeMinutes
        self.minutes = minutes
    }

    public init(
        for string: String,
        strategy: WordsEstimationStrategy = .regexWords,
        wordsPerMinute: Int = 250
    ) {
        let words = strategy.countWords(string)
        let minutes = Double(words) / Double(wordsPerMinute)
        self.init(
            words: words,
            timeMinutes: minutes,
            minutes: Int(minutes.rounded())
        )
    }

    public struct WordsEstimationStrategy: Sendable {
        let countWords: @Sendable (String) -> Int
    }
}

public extension EstimatedReadingTime.WordsEstimationStrategy {
    /// The original strategy used in https://github.com/alexito4/ReadingTimePublishPlugin
    /// Tried to strip out html tags to find only the words.
    /// Good for when the input is HTML.
    static let html: Self = .init { string in
        let plain = string.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression, range: nil)
        let separators = CharacterSet
            .whitespacesAndNewlines
            .union(.punctuationCharacters)
        let words = plain.components(separatedBy: separators)
            .filter { !$0.isEmpty }
        return words.count
    }

    /// Used by https://github.com/twostraws/Ignite
    /// Uses regex engine to count the words.
    static let regexWords: Self = .init { string in
        string.matches(of: #/[\w-]+/#).count
    }
}
