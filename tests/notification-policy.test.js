const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

const context = {}
const policySource = fs.readFileSync(path.join(__dirname, "..", "NotificationPolicy.js"), "utf8")
vm.runInNewContext(policySource.replace(/^pragma library\s*/, ""), context)
const advance = context.advance
const blank = () => ({ pendingKey: "", pendingSamples: 0, coolSamples: 0, latched: false, lastSentAt: 0 })

let state = blank()
state = advance(state, "high-temperature", 1000)
assert.equal(state.notify, false, "single high sample must not alert")
state = advance(state, "high-temperature", 11000)
assert.equal(state.notify, false, "two high samples must not alert")
state = advance(state, "high-temperature", 21000)
assert.equal(state.notify, true, "third consecutive high sample should alert")

state = advance(state, "", 31000, false)
assert.equal(state.latched, true, "temperature in hysteresis band must keep alert latched")
state = advance(state, "high-temperature", 41000)
state = advance(state, "high-temperature", 51000)
state = advance(state, "high-temperature", 61000)
assert.equal(state.notify, false, "brief repeated episode must stay latched")

state = advance(state, "", 71000, true)
state = advance(state, "", 81000, true)
state = advance(state, "", 91000, true)
assert.equal(state.latched, false, "three cool samples should re-arm alerts")
state = advance(state, "high-temperature", 101000)
state = advance(state, "high-temperature", 111000)
state = advance(state, "high-temperature", 121000)
assert.equal(state.notify, false, "new episode inside cooldown must not alert")

state = advance(state, "", 131000, true)
state = advance(state, "", 141000, true)
state = advance(state, "", 151000, true)
const afterCooldown = 21000 + 10 * 60 * 1000 + 1
state = advance(state, "high-temperature", afterCooldown)
state = advance(state, "high-temperature", afterCooldown + 10000)
state = advance(state, "high-temperature", afterCooldown + 20000)
assert.equal(state.notify, true, "sustained alert after cooldown should notify again")

console.log("Notification policy tests passed")
