// =====================================================================
// Speech delivery metrics calculated from Deepgram word-level timestamps.
// Pure functions (no I/O) so they are easy to unit test.
// =====================================================================

export type DeepgramWord = {
  word: string;
  start: number; // seconds
  end: number;   // seconds
  confidence?: number;
  punctuated_word?: string;
};

export type SpeechMetrics = {
  durationSeconds: number;         // whole recording length
  speakingSeconds: number;         // first word start -> last word end
  responseLatencySeconds: number;  // silence before the first word
  totalWords: number;              // including fillers
  wordCount: number;               // excluding fillers
  wordsPerMinute: number;          // wordCount / speaking minutes
  paceLabel: "no speech" | "slow" | "good" | "fast";
  fillerWordCount: number;         // vocal fillers + filler phrases
  vocalFillerCount: number;        // um, uh, erm ...
  fillerPhraseCount: number;       // "you know", "basically," ...
  soundFillerCount: number;        // voiced sounds between words with no transcribed word (erm/aaa)
  soundFillerSeconds: number;
  fillerRate: number;              // fillers per 100 words
  fillersPerMinute: number;
  fillerWordsUsed: Record<string, number>;
  pauseCount: number;              // gaps >= PAUSE_SECONDS
  longPauseCount: number;          // gaps >= LONG_PAUSE_SECONDS
  longestPauseSeconds: number;
  repetitionCount: number;         // "I I", "the the"
  hesitationCount: number;         // pauseCount + repetitionCount
  pauseRatio: number;              // share of speaking time spent in pauses (0-1)
};

// Vocal fillers. Deepgram (filler_words=true) writes: uh, um, mhmm, mm-mm, uh-uh, uh-huh, nuh-uh.
// normalise() removes hyphens, so "mm-mm" -> "mmmm", "uh-huh" -> "uhhuh".
export const FILLER_WORDS = new Set([
  "um", "umm", "uh", "uhh", "uhm", "er", "erm", "ah", "eh", "hmm", "mm", "mhm",
  "mhmm", "mmmm", "uhuh", "uhhuh", "nuhuh",
]);

// Real words used as fillers. Only counted when followed by a comma (or ?/.) in Deepgram's
// punctuated output, e.g. "Basically, I ..." or "it was, like, hard" - so normal use isn't counted.
export const FILLER_DISCOURSE_WORDS = new Set([
  "like", "basically", "actually", "literally", "so", "well", "right", "okay", "ok",
]);
export const FILLER_PHRASES: string[][] = [
  ["you", "know"],
  ["i", "mean"],
  ["kind", "of"],
  ["sort", "of"],
];

/** Microphone level samples (dBFS) recorded by the app every `intervalMs`. */
export type AmplitudeTrack = { intervalMs: number; db: number[] };

export const SOUND_FILLER_MIN_GAP = 0.4;      // only look at gaps of at least this length (s)
export const SOUND_FILLER_MIN_SECONDS = 0.25; // a voiced run this long counts as one filler
const EDGE_MARGIN = 0.15;                     // ignore the edges of words (s)

function percentile(sorted: number[], p: number): number {
  if (sorted.length === 0) return 0;
  const i = Math.min(sorted.length - 1, Math.max(0, Math.round((p / 100) * (sorted.length - 1))));
  return sorted[i];
}

/**
 * Speech-to-text often drops hesitation sounds ("erm", "aaa", "ah"), especially with accents.
 * They still show up as loud audio in the gaps between transcribed words.
 * We count voiced runs inside those gaps as untranscribed fillers.
 */
export function detectSoundFillers(
  words: DeepgramWord[],
  track: AmplitudeTrack | null | undefined,
): { count: number; seconds: number } {
  if (!track || !Array.isArray(track.db) || track.db.length < 10 || !(track.intervalMs > 0)) {
    return { count: 0, seconds: 0 };
  }
  const step = track.intervalMs / 1000;
  const db = track.db.map((v) => (Number.isFinite(v) ? Math.max(v, -100) : -100));
  const timeOf = (i: number) => i * step;

  // Loudness while words are being spoken vs. background noise
  const inWord = (t: number) => words.some((w) => t >= w.start && t <= w.end);
  const speech = db.filter((_, i) => inWord(timeOf(i))).sort((a, b) => a - b);
  if (speech.length < 3) return { count: 0, seconds: 0 };
  const speechLevel = percentile(speech, 50);
  const noiseFloor = percentile([...db].sort((a, b) => a - b), 10);
  if (speechLevel - noiseFloor < 10) return { count: 0, seconds: 0 }; // too noisy to tell apart

  const threshold = Math.max(noiseFloor + 8, speechLevel - 12);

  // Gaps: before the first word (people often start with "erm") and between words
  const gaps: [number, number][] = [];
  if (words.length > 0) gaps.push([0.5, words[0].start]);
  for (let i = 1; i < words.length; i++) gaps.push([words[i - 1].end, words[i].start]);

  let count = 0;
  let seconds = 0;
  for (const [gapStart, gapEnd] of gaps) {
    if (gapEnd - gapStart < SOUND_FILLER_MIN_GAP) continue;
    const from = Math.ceil((gapStart + EDGE_MARGIN) / step);
    const to = Math.floor((gapEnd - EDGE_MARGIN) / step);

    let run = 0;
    const flush = () => {
      const len = run * step;
      if (len >= SOUND_FILLER_MIN_SECONDS) {
        count++;
        seconds += len;
      }
      run = 0;
    };
    for (let i = from; i <= to && i < db.length; i++) {
      if (db[i] >= threshold) run++;
      else flush();
    }
    flush();
  }
  return { count, seconds: round(seconds) };
}

const endsWithPause = (w: DeepgramWord) => /[,?.!]$/.test((w.punctuated_word ?? "").trim());

export const PAUSE_SECONDS = 1.0;
export const LONG_PAUSE_SECONDS = 2.5;
export const SLOW_WPM = 110;
export const FAST_WPM = 165;

const round = (n: number, dp = 1) => {
  const f = 10 ** dp;
  return Math.round(n * f) / f;
};

export function normalise(word: string): string {
  return word.toLowerCase().replace(/[^a-z0-9']/g, "");
}

export function calculateSpeechMetrics(
  words: DeepgramWord[],
  durationSeconds: number,
  amplitude?: AmplitudeTrack | null,
): SpeechMetrics {
  const clean = words
    .filter((w) => normalise(w.word).length > 0)
    .sort((a, b) => a.start - b.start);

  if (clean.length === 0) {
    return {
      durationSeconds: round(durationSeconds),
      speakingSeconds: 0,
      responseLatencySeconds: round(durationSeconds),
      totalWords: 0,
      wordCount: 0,
      wordsPerMinute: 0,
      paceLabel: "no speech",
      fillerWordCount: 0,
      vocalFillerCount: 0,
      fillerPhraseCount: 0,
      soundFillerCount: 0,
      soundFillerSeconds: 0,
      fillerRate: 0,
      fillersPerMinute: 0,
      fillerWordsUsed: {},
      pauseCount: 0,
      longPauseCount: 0,
      longestPauseSeconds: 0,
      repetitionCount: 0,
      hesitationCount: 0,
      pauseRatio: 0,
    };
  }

  const first = clean[0];
  const last = clean[clean.length - 1];
  const speakingSeconds = Math.max(last.end - first.start, 0.1);

  // Fillers
  const fillerWordsUsed: Record<string, number> = {};
  const addFiller = (key: string) => (fillerWordsUsed[key] = (fillerWordsUsed[key] ?? 0) + 1);
  let vocalFillerCount = 0;
  let fillerPhraseCount = 0;

  for (let i = 0; i < clean.length; i++) {
    const n = normalise(clean[i].word);

    if (FILLER_WORDS.has(n)) {
      vocalFillerCount++;
      addFiller(n);
      continue;
    }

    // Two-word phrases like "you know," / "I mean,"
    const next = clean[i + 1];
    const phrase = next && FILLER_PHRASES.find(([a, b]) => a === n && b === normalise(next.word));
    if (phrase && endsWithPause(next)) {
      fillerPhraseCount++;
      addFiller(phrase.join(" "));
      i++; // skip the second word
      continue;
    }

    if (FILLER_DISCOURSE_WORDS.has(n) && endsWithPause(clean[i])) {
      fillerPhraseCount++;
      addFiller(n);
    }
  }
  const soundFillers = detectSoundFillers(clean, amplitude);
  if (soundFillers.count > 0) fillerWordsUsed["erm/ah (heard, not transcribed)"] = soundFillers.count;
  const fillerWordCount = vocalFillerCount + fillerPhraseCount + soundFillers.count;
  const wordCount = clean.length - vocalFillerCount; // filler phrases are still real spoken words

  // Pauses + repetitions
  let pauseCount = 0;
  let longPauseCount = 0;
  let longestPause = 0;
  let totalPause = 0;
  let repetitionCount = 0;

  for (let i = 1; i < clean.length; i++) {
    const gap = clean[i].start - clean[i - 1].end;
    if (gap >= PAUSE_SECONDS) {
      pauseCount++;
      totalPause += gap;
      if (gap >= LONG_PAUSE_SECONDS) longPauseCount++;
    }
    if (gap > longestPause) longestPause = gap;

    const prev = normalise(clean[i - 1].word);
    const cur = normalise(clean[i].word);
    if (cur === prev && !FILLER_WORDS.has(cur)) repetitionCount++;
  }

  const speakingMinutes = speakingSeconds / 60;
  const wordsPerMinute = wordCount / speakingMinutes;

  let paceLabel: SpeechMetrics["paceLabel"] = "good";
  if (wordsPerMinute < SLOW_WPM) paceLabel = "slow";
  else if (wordsPerMinute > FAST_WPM) paceLabel = "fast";

  return {
    durationSeconds: round(durationSeconds),
    speakingSeconds: round(speakingSeconds),
    responseLatencySeconds: round(first.start),
    totalWords: clean.length,
    wordCount,
    wordsPerMinute: round(wordsPerMinute),
    paceLabel,
    fillerWordCount,
    vocalFillerCount,
    fillerPhraseCount,
    soundFillerCount: soundFillers.count,
    soundFillerSeconds: soundFillers.seconds,
    fillerRate: round((fillerWordCount / (clean.length + soundFillers.count)) * 100, 2),
    fillersPerMinute: round(fillerWordCount / speakingMinutes),
    fillerWordsUsed,
    pauseCount,
    longPauseCount,
    longestPauseSeconds: round(longestPause),
    repetitionCount,
    hesitationCount: pauseCount + repetitionCount,
    pauseRatio: round(Math.min(totalPause / speakingSeconds, 1), 2),
  };
}
