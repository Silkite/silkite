#include "theme_manager.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>

namespace {
ThemeManager::Palette palette(const char *window, const char *panel,
                              const char *elevated, const char *control,
                              const char *text, const char *secondary,
                              const char *accent, const char *accentText,
                              const char *divider) {
  return {QColor(window), QColor(panel), QColor(elevated), QColor(control),
          QColor(text), QColor(secondary), QColor(accent), QColor(accentText),
          QColor(divider)};
}
}

ThemeManager::ThemeManager(QObject *parent) : QObject(parent) {
  m_availableThemes = {"Silicone", "Pastel Dream", "Gruvbox", "Tokyo Night", "Everforest", "Nord",
                       "Solarized Osaka"};
  m_palettes.insert("Silicone", palette("#050505", "#101010", "#0D0D0D", "#141414", "#D2D2D2", "#696969", "#A3A3A3", "#050505", "#2A2A2A"));
  m_palettes.insert("Pastel Dream", palette("#F5F3EF", "#EFECE6", "#E8E3DA", "#DDD7CD", "#2D2B38", "#787389", "#FF8FAB", "#FFFFFF", "#E2DCD3"));
  m_palettes.insert("Gruvbox", palette("#1D2021", "#282828", "#32302F", "#3C3836", "#FBF1C7", "#BDAE93", "#FABD2F", "#1D2021", "#504945"));
  m_palettes.insert("Tokyo Night", palette("#101014", "#16161E", "#1E2233", "#282E47", "#E6EAFB", "#A9B1D6", "#7AA2F7", "#101014", "#343B58"));
  m_palettes.insert("Everforest", palette("#232A2E", "#2D353B", "#343E44", "#404C53", "#F3EAD3", "#B7C5B5", "#A7C080", "#232A2E", "#4C565A"));
  m_palettes.insert("Nord", palette("#242933", "#2E3440", "#384152", "#434C5E", "#F8FAFC", "#D8DEE9", "#88C0D0", "#242933", "#4C566A"));
  m_palettes.insert("Solarized Osaka", palette("#001419", "#063540", "#0A4652", "#0D5362", "#FDF5E2", "#839395", "#29A298", "#001419", "#1A6397"));
  load();
}

QString ThemeManager::configFilePath() const {
  return QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/themes.json";
}

void ThemeManager::load() {
  const auto path = configFilePath();
  QFile file(path);
  if (!file.exists()) {
    m_currentTheme = "Silicone";
    m_currentPalette = m_palettes.value(m_currentTheme);
    createDefaultConfig();
    return;
  }
  if (file.open(QIODevice::ReadOnly)) {
    const auto root = QJsonDocument::fromJson(file.readAll()).object();
    const auto selected = root.value("selected").toString();
    const auto themes = root.value("themes").toObject();
    for (const auto &name : m_availableThemes)
      if (themes.contains(name)) m_palettes[name] = paletteFromJson(themes.value(name).toObject());
    m_currentTheme = m_palettes.contains(selected) ? selected : "Silicone";
    if (root.contains("ircMode")) m_ircMode = root.value("ircMode").toBool();
    if (root.contains("uiFontSize")) m_uiFontSize = root.value("uiFontSize").toInt(13);
    if (root.contains("chatFontSize")) m_chatFontSize = root.value("chatFontSize").toInt(15);
    if (root.contains("chatSpacing")) m_chatSpacing = root.value("chatSpacing").toInt(6);
  } else {
    m_currentTheme = "Silicone";
  }
  m_currentPalette = m_palettes.value(m_currentTheme);
}

void ThemeManager::createDefaultConfig() const { save(); }

void ThemeManager::save() const {
  const auto path = configFilePath();
  QDir().mkpath(QFileInfo(path).absolutePath());
  QJsonObject themes;
  for (const auto &name : m_availableThemes) themes.insert(name, paletteToJson(m_palettes.value(name)));
  QJsonObject root;
  root.insert("selected", m_currentTheme);
  root.insert("themes", themes);
  root.insert("ircMode", m_ircMode);
  root.insert("uiFontSize", m_uiFontSize);
  root.insert("chatFontSize", m_chatFontSize);
  root.insert("chatSpacing", m_chatSpacing);
  QFile file(path);
  if (file.open(QIODevice::WriteOnly | QIODevice::Truncate)) file.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
}

QJsonObject ThemeManager::paletteToJson(const Palette &p) {
  return {{"windowBackground", p.windowBackground.name()}, {"panelBackground", p.panelBackground.name()}, {"elevatedBackground", p.elevatedBackground.name()}, {"controlBackground", p.controlBackground.name()}, {"primaryText", p.primaryText.name()}, {"secondaryText", p.secondaryText.name()}, {"accent", p.accent.name()}, {"accentText", p.accentText.name()}, {"divider", p.divider.name()}};
}

ThemeManager::Palette ThemeManager::paletteFromJson(const QJsonObject &o) {
  return palette(o.value("windowBackground").toString().toUtf8().constData(), o.value("panelBackground").toString().toUtf8().constData(), o.value("elevatedBackground").toString().toUtf8().constData(), o.value("controlBackground").toString().toUtf8().constData(), o.value("primaryText").toString().toUtf8().constData(), o.value("secondaryText").toString().toUtf8().constData(), o.value("accent").toString().toUtf8().constData(), o.value("accentText").toString().toUtf8().constData(), o.value("divider").toString().toUtf8().constData());
}

QString ThemeManager::currentTheme() const { return m_currentTheme; }
QStringList ThemeManager::availableThemes() const { return m_availableThemes; }
#define THEME_COLOR(name) QColor ThemeManager::name() const { return m_currentPalette.name; }
THEME_COLOR(windowBackground) THEME_COLOR(panelBackground) THEME_COLOR(elevatedBackground) THEME_COLOR(controlBackground) THEME_COLOR(primaryText) THEME_COLOR(secondaryText) THEME_COLOR(accent) THEME_COLOR(accentText) THEME_COLOR(divider)
#undef THEME_COLOR

void ThemeManager::selectTheme(const QString &name) {
  if (!m_palettes.contains(name) || name == m_currentTheme) return;
  m_currentTheme = name;
  m_currentPalette = m_palettes.value(name);
  save();
  emit themeChanged();
}

void ThemeManager::setIrcMode(bool enabled) {
  if (m_ircMode == enabled) return;
  m_ircMode = enabled;
  save();
  emit ircModeChanged();
}

void ThemeManager::setUiFontSize(int size) {
  if (m_uiFontSize == size) return;
  m_uiFontSize = size;
  save();
  emit uiFontSizeChanged();
}

void ThemeManager::setChatFontSize(int size) {
  if (m_chatFontSize == size) return;
  m_chatFontSize = size;
  save();
  emit chatFontSizeChanged();
}

void ThemeManager::setChatSpacing(int spacing) {
  if (m_chatSpacing == spacing) return;
  m_chatSpacing = spacing;
  save();
  emit chatSpacingChanged();
}
