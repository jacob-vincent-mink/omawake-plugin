import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "jacob.omawake"
  ipcTarget: "omawake"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property bool binaryFound: false
  property bool checking: false
  property bool unitInstalled: false
  property var statusData: null
  property var wakeWords: []
  property bool actionBusy: false
  property string actionError: ""

  readonly property bool daemonRunning: Model.isDaemonRunning(statusData)
  readonly property bool daemonPaused: Model.isDaemonPaused(statusData)
  readonly property string modelName: Model.modelName(statusData)
  readonly property string backendName: Model.backendName(statusData)

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: {
    if (opened) {
      refreshTimer.start()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    } else {
      refreshTimer.stop()
      actionError = ""
    }
  }

  Component.onCompleted: checkBinary()

  function checkBinary() {
    checking = true
    binaryCheck.running = true
  }

  function checkUnit() {
    if (!binaryFound) return
    unitCheck.running = true
  }

  function refreshStatus() {
    if (!binaryFound) return
    statusProc.running = true
  }

  function refreshWakeWords() {
    if (!binaryFound) return
    wakeWordProc.running = true
  }

  function doAction(args) {
    actionBusy = true
    actionError = ""
    actionProc.command = ["omawake"].concat(args)
    actionProc.running = true
  }

  function doSystemctl(args) {
    actionBusy = true
    actionError = ""
    systemctlProc.command = ["systemctl", "--user"].concat(args)
    systemctlProc.running = true
  }

  function launchTerminal(args) {
    launchProc.command = ["omarchy", "launch", "terminal"].concat(args)
    launchProc.running = true
    root.close()
  }

  function removeWakeWord(id) {
    if (!id) return
    actionBusy = true
    actionError = ""
    rmWwProc.command = ["omawake", "wake-word", "remove", id]
    rmWwProc.running = true
  }

  function refreshAfterDelay(ms) {
    delayTimer.interval = ms || 800
    delayTimer.start()
  }

  Process {
    id: binaryCheck
    command: ["sh", "-c", "command -v omawake"]
    running: false
    onExited: function(code) {
      binaryFound = (code === 0)
      checking = false
      if (binaryFound) {
        checkUnit()
        refreshStatus()
        refreshWakeWords()
      }
    }
  }

  Process {
    id: unitCheck
    command: ["systemctl", "--user", "show", "omawake", "--property=LoadState", "--value"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        unitInstalled = Model.parseUnitLoadState(text)
      }
    }
    onExited: function(code) {
      if (code !== 0) unitInstalled = false
    }
  }

  Process {
    id: statusProc
    command: ["omawake", "status", "--json"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        statusData = Model.parseStatus(text)
      }
    }
    onExited: function(code) {
      if (code !== 0) statusData = null
    }
  }

  Process {
    id: wakeWordProc
    command: ["omawake", "wake-word", "list", "--json"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        wakeWords = Model.parseWakeWords(text)
      }
    }
    onExited: function(code) {
      if (code !== 0) wakeWords = []
    }
  }

  Process {
    id: actionProc
    command: []
    running: false
    onExited: function(code) {
      actionBusy = false
      refreshStatus()
      refreshWakeWords()
    }
  }

  Process {
    id: systemctlProc
    command: []
    running: false
    onExited: function(code) {
      actionBusy = false
      checkUnit()
      refreshAfterDelay(800)
    }
  }

  Process {
    id: rmWwProc
    command: []
    running: false
    onExited: function(code) {
      actionBusy = false
      if (code !== 0) actionError = "Could not remove wake word"
      refreshWakeWords()
    }
  }

  Process {
    id: launchProc
    command: []
    running: false
  }

  Timer {
    id: bgRefreshTimer
    interval: 10000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      if (!checking) checkBinary()
    }
  }

  Timer {
    id: refreshTimer
    interval: 5000
    repeat: true
    onTriggered: {
      if (binaryFound) {
        refreshStatus()
        refreshWakeWords()
      }
    }
  }

  Timer {
    id: delayTimer
    interval: 800
    repeat: false
    onTriggered: {
      refreshStatus()
      refreshWakeWords()
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf2a2"
    active: daemonRunning && !daemonPaused
    tooltipText: "Omawake" + (daemonRunning ? (daemonPaused ? " · paused" : " · running") : " · stopped")
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) {
        if (daemonRunning || daemonPaused) doSystemctl(["stop", "omawake"])
        else root.toggle()
      } else {
        root.toggle()
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(600))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentColumn.implicitHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: contentColumn
          width: panelFlick.width
          spacing: Style.space(14)

          PanelHero {
            width: parent.width
            title: "Omawake"
            meta: checking
              ? "Checking…"
              : (binaryFound
                ? (daemonRunning
                  ? (daemonPaused ? "Paused" : "Running")
                  : "Stopped")
                : "Not installed")
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: "\uf2a2"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }
            }
          }

          BorderSurface {
            visible: !binaryFound && !checking
            width: parent.width
            implicitHeight: installColumn.implicitHeight + Style.space(20)
            color: Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.08)
            borderSpec: Border.flat(Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.3), 1)
            radius: Style.cornerRadius

            Column {
              id: installColumn
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.space(10)
              spacing: Style.space(6)

              Text {
                width: parent.width
                text: "Omawake is not installed."
                textFormat: Text.PlainText
                color: root.urgent
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                wrapMode: Text.WordWrap
              }
              Text {
                width: parent.width
                text: "Install it with:  pacman -S omawake-bin"
                textFormat: Text.PlainText
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }
            }
          }

          Column {
            visible: binaryFound
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "STATUS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Column {
              width: parent.width
              spacing: Style.space(4)

              Text {
                width: parent.width
                text: "Daemon: " + (daemonRunning
                  ? (daemonPaused ? "Paused" : "Running")
                  : "Stopped")
                textFormat: Text.PlainText
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }
              Text {
                visible: modelName !== ""
                width: parent.width
                text: "Model: " + modelName
                textFormat: Text.PlainText
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
              Text {
                visible: backendName !== ""
                width: parent.width
                text: "Backend: " + backendName
                textFormat: Text.PlainText
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
            }
          }

          Row {
            visible: binaryFound
            width: parent.width
            spacing: Style.space(6)

            Button {
              visible: !unitInstalled
              text: "Install daemon"
              enabled: !actionBusy
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              onClicked: launchTerminal(["omawake", "setup", "systemd"])
            }
            Button {
              visible: unitInstalled && !daemonRunning && !daemonPaused
              text: "Start"
              enabled: !actionBusy
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              onClicked: doSystemctl(["start", "omawake"])
            }
            Button {
              visible: daemonRunning && !daemonPaused
              text: "Pause"
              enabled: !actionBusy
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              onClicked: doAction(["pause"])
            }
            Button {
              visible: daemonPaused
              text: "Resume"
              enabled: !actionBusy
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              onClicked: doAction(["resume"])
            }
            Button {
              visible: (daemonRunning || daemonPaused) && unitInstalled
              text: "Stop"
              enabled: !actionBusy
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              onClicked: doSystemctl(["stop", "omawake"])
            }
          }

          PanelSeparator {
            visible: binaryFound
            foreground: root.foreground
          }

          Column {
            visible: binaryFound
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "WAKE WORDS  " + wakeWords.length
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              visible: actionError !== ""
              width: parent.width
              text: actionError
              textFormat: Text.PlainText
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }

            Text {
              visible: wakeWords.length === 0
              width: parent.width
              text: "No wake words configured."
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Column {
              width: parent.width
              spacing: Style.space(2)
              Repeater {
                model: wakeWords
                delegate: CursorSurface {
                  required property var modelData
                  width: parent.width
                  foreground: root.foreground
                  implicitHeight: wwRow.implicitHeight + Style.space(10)

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                  }

                  RowLayout {
                    id: wwRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Style.space(8)
                    anchors.rightMargin: Style.space(8)
                    spacing: Style.space(8)

                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(1)

                      Text {
                        text: modelData.phrase || modelData.id || "?"
                        textFormat: Text.PlainText
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                      }
                      Text {
                        visible: modelData.command && modelData.command.length > 0
                        text: Array.isArray(modelData.command) ? modelData.command.join(" ") : String(modelData.command)
                        textFormat: Text.PlainText
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                      }
                    }

                    Text {
                      text: modelData.enabled === false ? "off" : "on"
                      textFormat: Text.PlainText
                      color: modelData.enabled === false ? root.dim : Color.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                    }

                    PanelActionButton {
                      iconText: "\uf1f8"
                      tooltipText: "Remove"
                      foreground: root.urgent
                      hoverColor: root.urgent
                      fontFamily: root.fontFamily
                      bordered: false
                      onClicked: root.removeWakeWord(modelData.id)
                    }
                  }
                }
              }
            }
          }

          PanelSeparator {
            visible: binaryFound
            foreground: root.foreground
          }

          Column {
            visible: binaryFound
            width: parent.width
            spacing: Style.space(6)

            Button {
              width: parent.width
              text: "Onboard wake word"
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.body
              onClicked: launchTerminal(["omawake", "word", "onboard"])
            }
            Button {
              width: parent.width
              text: "Open setup"
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.body
              onClicked: launchTerminal(["omawake", "setup"])
            }
          }
        }
      }
    }
  }
}
