.pragma library

function bounded(value, limit) {
  var text = String(value === undefined || value === null ? "" : value)
    .replace(/[\r\n\t]+/g, " ")
    .replace(/\s+/g, " ")
    .trim()
  var maximum = Math.max(1, Number(limit) || 128)
  return text.length <= maximum ? text : text.substring(0, maximum - 1) + "…"
}

function cleanDnsName(value) {
  return bounded(value, 253).replace(/\.+$/, "")
}

function firstIpv4(values) {
  if (!Array.isArray(values)) return ""
  for (var i = 0; i < values.length; i++) {
    var candidate = String(values[i] || "")
    if (/^(?:\d{1,3}\.){3}\d{1,3}$/.test(candidate)) return candidate
  }
  return ""
}

function displayName(hostName, dnsName, ipv4) {
  var host = bounded(hostName, 96)
  if (host) return host
  var dns = cleanDnsName(dnsName)
  if (dns) return bounded(dns.split(".")[0], 96)
  return ipv4 || "Unknown peer"
}

function peerSnapshot(raw, fallbackKey) {
  if (!raw || typeof raw !== "object") return null
  var ipv4 = firstIpv4(raw.TailscaleIPs)
  var dnsName = cleanDnsName(raw.DNSName)
  var hostName = bounded(raw.HostName, 96)
  var key = bounded(raw.ID || fallbackKey || raw.PublicKey, 180)
  if (!key) return null
  return {
    key: key,
    name: displayName(hostName, dnsName, ipv4),
    hostName: hostName,
    dnsName: dnsName,
    ipv4: ipv4,
    os: bounded(raw.OS, 32),
    online: raw.Online === true,
    active: raw.Active === true,
    exitNode: raw.ExitNode === true,
    exitNodeOption: raw.ExitNodeOption === true,
    target: ipv4 || hostName || dnsName
  }
}

function peerSort(left, right) {
  if (left.exitNode !== right.exitNode) return left.exitNode ? -1 : 1
  if (left.online !== right.online) return left.online ? -1 : 1
  var byName = left.name.localeCompare(right.name)
  return byName !== 0 ? byName : left.key.localeCompare(right.key)
}

function parseStatus(raw, maximumPeers) {
  var parsed
  try {
    parsed = JSON.parse(String(raw || ""))
  } catch (error) {
    return { ok: false, error: "Malformed Tailscale status JSON" }
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed))
    return { ok: false, error: "Invalid Tailscale status object" }

  var backendState = bounded(parsed.BackendState || "Unknown", 48)
  if (!backendState) return { ok: false, error: "Missing Tailscale backend state" }

  var selfRaw = parsed.Self && typeof parsed.Self === "object" ? parsed.Self : {}
  var selfIpv4 = firstIpv4(selfRaw.TailscaleIPs)
    || firstIpv4(parsed.TailscaleIPs)
  var tailnetRaw = parsed.CurrentTailnet && typeof parsed.CurrentTailnet === "object"
    ? parsed.CurrentTailnet : {}
  var peersRaw = parsed.Peer && typeof parsed.Peer === "object" ? parsed.Peer : {}
  var peerKeys = Object.keys(peersRaw)
  var peers = []
  var cap = Math.max(1, Math.min(200, Number(maximumPeers) || 100))
  for (var i = 0; i < peerKeys.length && peers.length < cap; i++) {
    var snapshot = peerSnapshot(peersRaw[peerKeys[i]], peerKeys[i])
    if (snapshot) peers.push(snapshot)
  }
  peers.sort(peerSort)

  var exitNodes = []
  var currentExitNodeKey = ""
  var currentExitNodeName = ""
  var onlineCount = 0
  for (var peerIndex = 0; peerIndex < peers.length; peerIndex++) {
    var peer = peers[peerIndex]
    if (peer.online) onlineCount++
    if (peer.exitNodeOption) exitNodes.push(peer)
    if (peer.exitNode) {
      currentExitNodeKey = peer.key
      currentExitNodeName = peer.name
    }
  }

  var health = Array.isArray(parsed.Health) ? parsed.Health : []
  return {
    ok: true,
    backendState: backendState,
    connected: backendState === "Running",
    needsLogin: backendState === "NeedsLogin",
    tailnetName: bounded(tailnetRaw.Name, 128),
    selfName: displayName(selfRaw.HostName, selfRaw.DNSName, selfIpv4),
    selfDnsName: cleanDnsName(selfRaw.DNSName),
    selfIpv4: selfIpv4,
    selfOnline: selfRaw.Online === true,
    peers: peers,
    onlineCount: onlineCount,
    exitNodes: exitNodes,
    currentExitNodeKey: currentExitNodeKey,
    currentExitNodeName: currentExitNodeName,
    healthCount: health.length
  }
}
