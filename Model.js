.pragma library

function parseStatus(raw) {
  try {
    var text = raw === null || raw === undefined ? "{}" : String(raw)
    return JSON.parse(text || "{}")
  } catch (e) { return null }
}

function parseWakeWords(raw) {
  try {
    var parsed = JSON.parse(String(raw || "[]"))
    return Array.isArray(parsed) ? parsed : []
  } catch (e) { return [] }
}

function isDaemonRunning(statusData) {
  if (!statusData) return false
  // Old format (daemon object with running flag)
  if (statusData.daemon && statusData.daemon.running === true) return true
  // New IPC format (type: "state" means daemon is active)
  if (statusData.type === "state") return true
  return false
}

function isDaemonPaused(statusData) {
  if (!statusData) return false
  // Old format
  if (statusData.daemon && statusData.daemon.state === "paused") return true
  // New IPC format
  if (statusData.type === "state" && statusData.state === "paused") return true
  return false
}

function modelName(statusData) {
  return statusData && statusData.model ? statusData.model.name : ""
}

function backendName(statusData) {
  if (!statusData || !statusData.backend) return ""
  if (statusData.backend.requested) {
    return statusData.backend.requested.runtime + " / " + statusData.backend.requested.device
  }
  return statusData.backend.kind || ""
}

function parseUnitLoadState(raw) {
  return String(raw || "").trim() === "loaded"
}
