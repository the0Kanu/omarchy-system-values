pragma library

// Require 3 consecutive alert samples, then latch until 3 normal samples.
// A global cooldown also suppresses rapid repeat alerts across brief episodes.
var DEBOUNCE_SAMPLES = 3
var CLEAR_SAMPLES = 3
var COOLDOWN_MS = 10 * 60 * 1000

function advance(state, key, now, clearAllowed) {
  var next = {
    pendingKey: state.pendingKey || "",
    pendingSamples: Number(state.pendingSamples) || 0,
    coolSamples: Number(state.coolSamples) || 0,
    latched: Boolean(state.latched),
    lastSentAt: Number(state.lastSentAt) || 0,
    notify: false
  }

  if (!key) {
    next.pendingKey = ""
    next.pendingSamples = 0
    if (clearAllowed === false) {
      next.coolSamples = 0
      return next
    }
    next.coolSamples += 1
    if (next.coolSamples >= CLEAR_SAMPLES) next.latched = false
    return next
  }

  next.coolSamples = 0
  if (next.pendingKey === key) next.pendingSamples += 1
  else {
    next.pendingKey = key
    next.pendingSamples = 1
  }

  var cooldownPassed = next.lastSentAt === 0 || now - next.lastSentAt >= COOLDOWN_MS
  if (next.pendingSamples >= DEBOUNCE_SAMPLES && !next.latched && cooldownPassed) {
    next.notify = true
    next.latched = true
    next.lastSentAt = now
  }
  return next
}
