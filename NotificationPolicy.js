pragma library

// Require consecutive alert samples, then latch until consecutive normal samples.
// A cooldown suppresses rapid repeat alerts across brief episodes.
var DEFAULT_ALERT_SAMPLES = 3
var DEFAULT_CLEAR_SAMPLES = 3
var DEFAULT_COOLDOWN_MS = 10 * 60 * 1000

function advance(state, key, now, clearAllowed, options) {
  options = options || {}
  var alertSamples = Math.max(1, Number(options.alertSamples === undefined ? DEFAULT_ALERT_SAMPLES : options.alertSamples))
  var clearSamples = Math.max(1, Number(options.clearSamples === undefined ? DEFAULT_CLEAR_SAMPLES : options.clearSamples))
  var cooldownMs = Math.max(0, Number(options.cooldownMs === undefined ? DEFAULT_COOLDOWN_MS : options.cooldownMs))
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
    if (next.coolSamples >= clearSamples) next.latched = false
    return next
  }

  next.coolSamples = 0
  if (next.pendingKey === key) next.pendingSamples += 1
  else {
    next.pendingKey = key
    next.pendingSamples = 1
  }

  var cooldownPassed = next.lastSentAt === 0 || now - next.lastSentAt >= cooldownMs
  if (next.pendingSamples >= alertSamples && !next.latched && cooldownPassed) {
    next.notify = true
    next.latched = true
    next.lastSentAt = now
  }
  return next
}
