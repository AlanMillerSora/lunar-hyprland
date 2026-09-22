// ════════════════════════════════════════════════════════════════
//  Lunar Eclipse — настройки Firefox (user.js)
//  Кладётся в профиль и применяется при каждом запуске.
//  Тёмная тема, своя страница, без рекламы и телеметрии.
// ════════════════════════════════════════════════════════════════

// ── кастомные стили (userChrome.css / userContent.css) ──────────
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// ── тёмная тема везде ───────────────────────────────────────────
user_pref("browser.theme.toolbar-theme", 0);
user_pref("browser.theme.content-theme", 0);
user_pref("extensions.activeThemeID", "firefox-compact-dark@mozilla.org");
user_pref("layout.css.prefers-color-scheme.content-override", 0);
user_pref("ui.systemUsesDarkTheme", 1);

// ── домашняя страница — своя (путь подставит install.sh) ─────────
user_pref("browser.startup.page", 1);
user_pref("browser.startup.homepage", "__LUNAR_HOME__");
user_pref("browser.newtabpage.enabled", false);
// без приветственного экрана при первом запуске
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.startup.homepage_welcome_url", "");
user_pref("browser.startup.homepage_welcome_url.additional", "");
user_pref("startup.homepage_welcome_url", "");
user_pref("startup.homepage_welcome_url.additional", "");
user_pref("browser.messaging-system.whatsNewPanel.enabled", false);

// ── интерфейс: компактно и по-системному ────────────────────────
user_pref("browser.uidensity", 1);
user_pref("browser.compactmode.show", true);
user_pref("browser.toolbars.bookmarks.visibility", "never");
user_pref("browser.tabs.inTitlebar", 0);
user_pref("widget.gtk.overlay-scrollbars.enabled", false);
user_pref("browser.startup.blankWindow", false);
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("browser.sessionstore.max_resumed_crashes", 0);

// ── вертикальные вкладки (нативные, в боковой панели) ───────────
user_pref("sidebar.revamp", true);
user_pref("sidebar.verticalTabs", true);
user_pref("sidebar.visibility", "always-show");

// ── без рекламы, рекомендаций и «поделиться» ────────────────────
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.feeds.system.topstories", false);
user_pref("browser.newtabpage.activity-stream.showWeather", false);
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.newtabpage.activity-stream.telemetry", false);
user_pref("browser.discovery.enabled", false);

// ── телеметрия и «наблюдения» выключены ─────────────────────────
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("browser.crashReports.unsubmittedCheck.autoSubmit2", false);

// ── всякая мелочь, чтобы не мешало ──────────────────────────────
user_pref("browser.tabs.warnOnClose", false);
user_pref("browser.bookmarks.addedImportButton", false);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("extensions.getAddons.showPane", false);
user_pref("extensions.pocket.enabled", false);
