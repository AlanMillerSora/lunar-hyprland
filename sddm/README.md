# SDDM — экран входа

Монохромная тема входа **Lunar Eclipse** — продолжение заставки Plymouth:
то же затмение и надпись `LUNAR ECLIPSE`, часы и дата, круглый аватар, поля
логина/пароля, кнопка `ВОЙТИ`, селектор сессии, кнопки питания и имя хоста.
JetBrains Mono, палитра риса, фон `#050505`.

```
sddm/
└── lunar/                 тема SDDM (QML, QtQuick 2.0)
    ├── Main.qml           сцена экрана входа
    ├── theme.conf         конфиг темы (заглушка)
    ├── metadata.desktop   описание темы
    ├── assets/            logo.png, wordmark.png, chevron.png, avatar.png
    └── fonts/             JetBrains Mono (Regular, Bold)
```

Установка и управление — общий `install.sh` (флаг `--sddm`).

## Заметки по реализации

- Greeter SDDM собран на **Qt5** (`libQt5Quick`), поэтому тема — `QtQuick 2.0`
  + `import SddmComponents 2.0` (компоненты в `/usr/lib/qt/qml/SddmComponents`).
- **Круглый аватар** сделан `ShaderEffect` (в Qt5 GLSL-строки работают):
  `Rectangle.radius` в этой сборке greeter'а не скругляет. Важно: Qt5
  ShaderEffect ждёт **премноженную** альфу — `gl_FragColor = vec4(rgb*a, a)`.
- **Дата по-русски** считается вручную (дни/месяцы в `Main.qml`) — не зависит
  от локали greeter'а.
- Стрелка селектора сессии: у `ComboBox` `arrowColor: "transparent"` +
  `arrowIcon: assets/chevron.png`, иначе рисуется белый квадрат.
- Масштаб под разрешение: `k = min(width/1920, height/1080)`.

## Быстро

```bash
./install.sh --sddm               # поставить и включить тему lunar
sudo ./install.sh --status        # состояние SDDM / Plymouth / zapret
sudo ./install.sh --disable-sddm  # вернуть штатную тему
```

Аватар — из **Hub → User → СМЕНИТЬ АВАТАР** или скриптом
`~/.config/hypr/scripts/eclipse-avatar.sh` (синк в тему SDDM — root-хелпером `avatar-sync.sh`).

## Безопасный предпросмотр

SDDM трогать не нужно — greeter умеет тестовый режим в окне:
```bash
sddm-greeter --test-mode --theme /usr/share/sddm/themes/lunar
```

## Откат, если тема не пустит в граф.вход

1. `Ctrl+Alt+F3` (TTY), войти.
2. `sudo ~/rice/install.sh --disable-sddm`
3. `sudo systemctl restart sddm`

Файл, который включает тему, — `/etc/sddm.conf.d/10-lunar-theme.conf`;
его удаления достаточно, чтобы вернуться к штатной теме.
