import QtQuick

// Fixed-profile RandR boundary for this workstation. The service accepts only
// known profile IDs and delegates one argv-safe request through CommandTransport.
Item {
  id: root

  required property QtObject transport

  readonly property string internalOutput: "eDP-1-1"
  readonly property string externalOutput: "HDMI-0"
  readonly property string backendPath: "/home/alikebrahim/.config/scripts/x11-display-profile.sh"
  readonly property bool actionsEnabled: transport !== null && transport.allowMutations
  readonly property var profiles: [
    {
      id: "dual",
      label: "Dual monitor",
      detail: "Extended desktop · external primary",
      lines: [
        "eDP-1-1  ·  1920×1080  ·  (0, 0)  ·  secondary",
        "HDMI-0   ·  1920×1080  ·  (1920, 0)  ·  primary"
      ]
    },
    {
      id: "external",
      label: "External only",
      detail: "Laptop panel off",
      lines: [
        "HDMI-0   ·  1920×1080  ·  (0, 0)  ·  primary",
        "eDP-1-1  ·  off"
      ]
    },
    {
      id: "laptop",
      label: "Laptop only",
      detail: "External display off",
      lines: [
        "eDP-1-1  ·  1920×1080  ·  (0, 0)  ·  primary",
        "HDMI-0   ·  off"
      ]
    },
    {
      id: "mirror",
      label: "Mirror displays",
      detail: "Both outputs share one 1080p image",
      lines: [
        "HDMI-0   ·  1920×1080  ·  (0, 0)  ·  primary",
        "eDP-1-1  ·  1920×1080  ·  (0, 0)  ·  mirrored"
      ]
    }
  ]

  property string armedProfile: ""
  property string pendingProfile: ""
  property string lastAppliedProfile: ""
  property string error: ""
  property bool busy: false

  signal actionFinished(string profile, bool ok, string message)

  visible: false

  function profileFor(profileId) {
    var requested = String(profileId || "")
    for (var i = 0; i < profiles.length; i++)
      if (profiles[i].id === requested) return profiles[i]
    return null
  }

  function profileLabel(profileId) {
    var profile = profileFor(profileId)
    return profile ? profile.label : ""
  }

  function arm(profileId) {
    var profile = profileFor(profileId)
    if (busy || !profile) return false
    armedProfile = profile.id
    error = ""
    return true
  }

  function cancelConfirmation() {
    armedProfile = ""
    return true
  }

  function clearError() {
    error = ""
  }

  function applyConfirmed(profileId) {
    var profile = profileFor(profileId)
    if (busy || !profile || armedProfile !== profile.id) {
      error = "Display profile is not confirmed"
      return false
    }
    if (!actionsEnabled) {
      error = "Native display changes are disabled"
      return false
    }

    armedProfile = ""
    pendingProfile = profile.id
    error = ""
    busy = true
    transport.request(
      "display.apply." + profile.id,
      [backendPath, "--apply", profile.id],
      true,
      false
    )
    return true
  }

  Connections {
    target: root.transport

    function onFinished(requestId, key, ok, output, message) {
      var prefix = "display.apply."
      if (key.indexOf(prefix) !== 0) return

      var profileId = key.substring(prefix.length)
      if (profileId !== root.pendingProfile) return

      var detail = ok ? "" : String(message || output || "Display profile failed").trim()
      root.busy = false
      root.pendingProfile = ""
      root.error = detail
      if (ok) root.lastAppliedProfile = profileId
      root.actionFinished(profileId, ok, detail)
    }
  }
}
