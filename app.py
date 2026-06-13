from __future__ import annotations

import logging
import os
import sys
from logging.handlers import RotatingFileHandler
from pathlib import Path

from PySide6.QtCore import QUrl
from PySide6.QtGui import QAction, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle
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
    tray = install_tray(app, window, backend, icon)
    app._aura_tray = tray
    app._aura_backend = backend
    logging.info("AURA %s started", VERSION)
    return app.exec()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception:
        logging.exception("Fatal application error")
        raise
