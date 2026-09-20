import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "user.system-values"

  property var components: []
  property var gpus: []
  property var cpu: ({ temperature: "--", source: "", status: "error" })
  property string queryError: ""
  property string lastNotificationKey: ""
  property bool popupOpen: false
  property bool refreshing: false
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  readonly property int refreshIntervalSec: setting("refreshIntervalSec", 10)
  readonly property color foreground: "#cacccc"
  readonly property color urgent: "#a55555"
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") !== ""
    ? Quickshell.env("XDG_CONFIG_HOME")
    : Quickshell.env("HOME") + "/.config"
  readonly property string helperPath: root.configHome + "/omarchy/plugins/user.system-values/system-values.sh"

  function open() { popupOpen = true }
  function close() { popupOpen = false }
  function toggle() { popupOpen = !popupOpen }

  function refresh() {
    if (refreshing || !statusProcess) return
    refreshing = true
    statusProcess.running = true
  }

  function sendNotification(headline, body) {
    if (!root.omarchyPath) return
    Quickshell.execDetached([
      root.omarchyPath + "/bin/omarchy-notification-send",
      "--app-name", "Hardware Values",
      "--urgency", "low",
      "--expire-time", "5000",
      headline,
      body
    ])
  }

  function evaluateNotification() {
    var key = ""
    var body = ""
    if (root.queryError !== "") {
      key = "query-error"
      body = root.queryError
    } else if (root.cpu.status !== "ok") {
      key = "cpu-error"
      body = "CPU temperature is unavailable."
    } else if (root.hottestComponentTemperature >= 90) {
      key = "high-temperature"
      body = "Hardware temperature is high: " + root.hottestComponentTemperature.toFixed(1) + " °C"
    } else {
      root.lastNotificationKey = ""
      return
    }
    if (key === root.lastNotificationKey) return
    root.lastNotificationKey = key
    root.sendNotification("Hardware Values", body)
  }

  function parseStatus(raw) {
    var all = []
    var next = []
    String(raw || "").split(/\r?\n/).forEach(function(line) {
      if (!line.trim()) return
      var fields = line.split("\t")
      if (fields[0] === "CPU") {
        if (fields.length >= 7) all.push({
          kind: "cpu",
          name: fields[1],
          temperature: fields[2],
          utilization: fields[3],
          load: fields[4],
          source: fields[5],
          status: fields[6]
        })
        return
      }
      if (fields[0] !== "GPU" || fields.length < 10) return
      var gpu = {
        kind: "gpu",
        index: fields[1],
        name: fields[2],
        temperature: fields[3],
        utilization: fields[4],
        memoryUsed: fields[5],
        memoryTotal: fields[6],
        pstate: fields[7],
        status: fields[8],
        vendor: fields[9]
      }
      all.push(gpu)
      next.push(gpu)
    })
    var detectedCpu = all.find(function(item) { return item.kind === "cpu" })
    cpu = detectedCpu || ({ temperature: "--", source: "", status: "error" })
    components = all
    gpus = next
    root.evaluateNotification()
  }

  function cpuTempNumber() {
    var value = parseFloat(String(cpu.temperature || ""))
    return isFinite(value) ? value : -1
  }

  function tempNumber(gpu) {
    var value = parseFloat(String(gpu && gpu.temperature || ""))
    return isFinite(value) ? value : -1
  }

  readonly property real hottestTemperature: {
    var hottest = -1
    for (var i = 0; i < gpus.length; i++) hottest = Math.max(hottest, tempNumber(gpus[i]))
    return hottest
  }

  readonly property real hottestComponentTemperature: Math.max(hottestTemperature, cpuTempNumber())

  readonly property bool hasError: {
    if (queryError !== "") return true
    if (cpu.status !== "ok") return true
    for (var i = 0; i < gpus.length; i++) if (gpus[i].status !== "ok") return true
    return false
  }

  readonly property color indicatorColor: hasError
    ? urgent
    : hottestComponentTemperature >= 90
      ? urgent
      : hottestComponentTemperature >= 85
        ? Color.accent
        : foreground

  readonly property string summaryText: {
    if (hasError) return "SYS !"
    if (cpuTempNumber() >= 0) return "CPU " + cpu.temperature + "°C"
    return "SYS"
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: refresh()

  Process {
    id: statusProcess
    command: ["bash", root.helperPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.queryError = ""
        root.parseStatus(text)
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.queryError = String(text || "").trim()
        root.evaluateNotification()
      }
    }
    onExited: {
      root.refreshing = false
    }
  }

  Timer {
    interval: Math.max(5000, root.refreshIntervalSec * 1000)
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.summaryText
    labelVisible: true
    hasVisualContent: true
    foreground: root.indicatorColor
    tooltipText: root.hasError
      ? "Hardware Values: at least one component reports an error"
      : "Open Hardware Values"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.refresh()
      else root.toggle()
    }

  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(390))
    contentHeight: popup.fittedContentHeight(contentColumn.implicitHeight)
    onOpenChanged: {
      if (root.popupOpen !== open) root.popupOpen = open
      if (open) root.refresh()
    }

    Column {
      id: contentColumn
      anchors.fill: parent
      spacing: Style.space(10)

      Column {
        width: parent.width
        spacing: Style.space(2)

        Text {
          text: "Hardware Values"
          color: root.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.heading
          font.bold: true
        }

        Text {
          text: root.components.length + " components detected"
          color: Qt.darker(root.foreground, 1.5)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      Text {
        width: parent.width
        visible: root.queryError !== ""
        text: "Driver notice: " + root.queryError
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: root.urgent
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
      }

      Column {
        width: parent.width
        spacing: Style.space(3)

        Text {
          text: "CPU"
          color: root.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.heading
          font.bold: true
        }

        Text {
          width: parent.width
          text: root.cpu.status === "ok"
            ? "Model: " + root.cpu.name
              + "\nTemperature: " + root.cpu.temperature + " °C   Utilization: " + root.cpu.utilization + " %"
              + "\nLoad (1 min): " + root.cpu.load + "   Source: " + root.cpu.source
            : "Temperature unavailable"
          textFormat: Text.PlainText
          color: root.cpu.status === "ok" ? Qt.darker(root.foreground, 1.25) : root.urgent
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
        }
      }

      Repeater {
        model: root.gpus

        delegate: Column {
          required property var modelData
          width: contentColumn.width
          spacing: Style.space(3)

          Rectangle {
            width: parent.width
            height: 1
            color: Qt.darker(root.foreground, 2.5)
            opacity: 0.45
          }

          Column {
            width: parent.width
            spacing: Style.space(2)

            Text {
              width: parent.width
              text: modelData.vendor + " GPU " + modelData.index + "  " + modelData.name
              textFormat: Text.PlainText
              elide: Text.ElideRight
              color: root.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
            }

            Text {
              id: stateText
              text: modelData.status === "ok" ? modelData.pstate : "ERROR"
              color: modelData.status === "ok" ? root.foreground : root.urgent
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          Text {
            width: parent.width
            text: modelData.status === "ok"
              ? "Temperature: " + modelData.temperature + " °C   Utilization: " + modelData.utilization + " %"
                + "\nMemory: " + modelData.memoryUsed + " / " + modelData.memoryTotal + " MiB"
              : "Temperature unavailable\nGPU does not provide a valid device status"
            textFormat: Text.PlainText
            color: modelData.status === "ok" ? Qt.darker(root.foreground, 1.25) : root.urgent
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
        }
      }

      Text {
        visible: root.gpus.length === 0
        text: "No GPU detected"
        color: root.urgent
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
      }
    }
  }
}
