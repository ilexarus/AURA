from __future__ import annotations

import logging
import os
import sys
from logging.handlers import RotatingFileHandler
from pathlib import Path

from PySide6.QtCore import QSettings, QUrl
from PySide6.QtGui import QAction, QGuiApplication, QIcon, QWindow
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle
from PySide6.QtNetwork import QLocalServer, QLocalSocket
from PySide6.QtWidgets import QApplication, QMenu, QSystemTrayIcon

from aura.backend import AssistantBackend
from aura.version import VERSION


def resource_path(relative: str) -> Path:
    base = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))
    return base / relative


def executable_dir() -> Path:
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent


def data_dir() -> Path:
    base = Path(os.getenv("APPDATA") or Path.home() / ".config") / "AURA"
    base.mkdir(parents=True, exist_ok=True)
    return base


def configure_logging() -> None:
    handler = RotatingFileHandler(
        data_dir() / "aura.log",
        maxBytes=1_500_000,
        backupCount=3,
        encoding="utf-8",
    )
    handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(name)s %(message)s"))
    root = logging.getLogger()
    root.setLevel(logging.INFO)
    root.handlers.clear()
    root.addHandler(handler)



INSTANCE_NAME = "AURA-Voice-Assistant-Single-Instance"


def create_single_instance_server(app: QApplication) -> tuple[QLocalServer | None, bool]:
    """Return a local server and whether this process is the primary instance."""
    probe = QLocalSocket(app)
    probe.connectToServer(INSTANCE_NAME)
    if probe.waitForConnected(180):
        probe.write(b"show")
        probe.flush()
        probe.waitForBytesWritten(180)
        probe.disconnectFromServer()
        return None, False

    QLocalServer.removeServer(INSTANCE_NAME)
    server = QLocalServer(app)
    if not server.listen(INSTANCE_NAME):
        logging.error("Unable to create single-instance server: %s", server.errorString())
        return None, True
    return server, True


def restore_window_geometry(window: object) -> None:
    settings = QSettings("AURA", "AURA")
    width = max(980, min(int(settings.value("window/width", 1180)), 2400))
    height = max(650, min(int(settings.value("window/height", 760)), 1600))
    screen = QGuiApplication.primaryScreen()
    if screen is None:
        window.resize(width, height)
        return
    available = screen.availableGeometry()
    width = min(width, available.width())
    height = min(height, available.height())
    x = int(settings.value("window/x", available.x() + (available.width() - width) // 2))
    y = int(settings.value("window/y", available.y() + (available.height() - height) // 2))
    x = max(available.x(), min(x, available.right() - width + 1))
    y = max(available.y(), min(y, available.bottom() - height + 1))
    window.setGeometry(x, y, width, height)


def save_window_geometry(window: object) -> None:
    if not window.isVisible() or window.visibility() == QWindow.FullScreen:
        return
    settings = QSettings("AURA", "AURA")
    settings.setValue("window/x", window.x())
    settings.setValue("window/y", window.y())
    settings.setValue("window/width", window.width())
    settings.setValue("window/height", window.height())
    settings.sync()


def install_tray(app: QApplication, window: object, backend: AssistantBackend, icon: QIcon) -> QSystemTrayIcon | None:
    if not QSystemTrayIcon.isSystemTrayAvailable():
        return None

    tray = QSystemTrayIcon(icon, app)
    tray.setToolTip(f"AURA {VERSION}")
    menu = QMenu()

    show_action = QAction("Открыть AURA", menu)
    listen_action = QAction("Начать слушать", menu)
    wake_action = QAction("Активация фразой «Аура»", menu)
    voice_action = QAction("Голосовые ответы", menu)
    wake_action.setCheckable(True)
    wake_action.setChecked(backend.wakeEnabled)
    voice_action.setCheckable(True)
    voice_action.setChecked(backend.voiceFeedbackEnabled)
    update_action = QAction("Проверить обновления", menu)
    exit_action = QAction("Выход", menu)

    def show_window() -> None:
        window.showNormal()
        window.raise_()
        window.requestActivate()

    show_action.triggered.connect(show_window)
    listen_action.triggered.connect(backend.toggleListening)
    wake_action.toggled.connect(backend.setWakeEnabled)
    voice_action.toggled.connect(backend.setVoiceFeedbackEnabled)
    backend.wakeStateChanged.connect(lambda: wake_action.setChecked(backend.wakeEnabled))
    backend.voiceStateChanged.connect(lambda: voice_action.setChecked(backend.voiceFeedbackEnabled))
    update_action.triggered.connect(backend.checkForUpdates)
    exit_action.triggered.connect(backend.quitApp)
    menu.addAction(show_action)
    menu.addAction(listen_action)
    menu.addAction(wake_action)
    menu.addAction(voice_action)
    menu.addSeparator()
    menu.addAction(update_action)
    menu.addSeparator()
    menu.addAction(exit_action)
    tray.setContextMenu(menu)
    tray.activated.connect(lambda reason: show_window() if reason == QSystemTrayIcon.Trigger else None)
    tray.show()
    return tray


def main() -> int:
    configure_logging()
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")
    QQuickStyle.setStyle("Basic")

    app = QApplication(sys.argv)
    instance_server, is_primary = create_single_instance_server(app)
    if not is_primary:
        logging.info("AURA is already running; activated the existing window")
        return 0

    app.setApplicationName("AURA")
    app.setApplicationVersion(VERSION)
    app.setOrganizationName("AURA")
    app.setQuitOnLastWindowClosed(False)
    icon = QIcon(str(resource_path("assets/icon.png")))
    app.setWindowIcon(icon)

    exe_dir = executable_dir()
    backend = AssistantBackend(
        current_version=VERSION,
        update_config_path=resource_path("update_config.json"),
        updater_path=exe_dir / "AURAUpdater.exe",
        application_path=Path(sys.executable).resolve() if getattr(sys, "frozen", False) else Path(__file__).resolve(),
        wake_model_path=resource_path("models/vosk-model-small-ru-0.22"),
        voice_assets_path=resource_path("assets/voice"),
    )
    app.aboutToQuit.connect(backend.shutdown)

    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", backend)
    engine.load(QUrl.fromLocalFile(str(resource_path("ui/Main.qml"))))
    if not engine.rootObjects():
        logging.error("QML root object was not created")
        return 1

    window = engine.rootObjects()[0]
    restore_window_geometry(window)

    def activate_existing_window() -> None:
        while instance_server is not None and instance_server.hasPendingConnections():
            connection = instance_server.nextPendingConnection()
            connection.waitForReadyRead(80)
            connection.deleteLater()
        window.showNormal()
        window.raise_()
        window.requestActivate()

    if instance_server is not None:
        instance_server.newConnection.connect(activate_existing_window)

    tray = install_tray(app, window, backend, icon)
    if "--minimized" in sys.argv:
        window.hide()
    app.aboutToQuit.connect(lambda: save_window_geometry(window))
    app._aura_tray = tray
    app._aura_backend = backend
    app._aura_instance_server = instance_server
    logging.info("AURA %s started", VERSION)
    return app.exec()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception:
        logging.exception("Fatal application error")
        raise
