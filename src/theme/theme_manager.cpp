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
  m_availableThemes = {"Gruvbox", "Tokyo Night", "Everforest", "Nord",
                       "Silkite Dark"};
  m_palettes.insert("Gruvbox", palette("#1D2021", "#282828", "#3C3836", "#504945", "#FBF1C7", "#BDAE93", "#FABD2F", "#1D2021", "#665C54"));
  m_palettes.insert("Tokyo Night", palette("#101014", "#16161E", "#24283B", "#2F354F", "#E6EAFB", "#A9B1D6", "#7AA2F7", "#101014", "#414868"));
  m_palettes.insert("Everforest", palette("#232A2E", "#2D353B", "#3D484D", "#4F5B58", "#F3EAD3", "#B7C5B5", "#A7C080", "#232A2E", "#56635F"));
  m_palettes.insert("Nord", palette("#242933", "#2E3440", "#434C5E", "#4C566A", "#F8FAFC", "#D8DEE9", "#88C0D0", "#242933", "#616E88"));
  m_palettes.insert("Silkite Dark", palette("#11161D", "#1A222D", "#253244", "#304158", "#F7FAFF", "#B8C5D6", "#7DB7FF", "#11161D", "#43546A"));
  load();
}

QString ThemeManager::configFilePath() const {
  return QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/themes.json";
}

void ThemeManager::load() {
  const auto path = configFilePath();
  QFile file(path);
  if (!file.exists()) {
    m_currentTheme = "Silkite Dark";
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
    m_currentTheme = m_palettes.contains(selected) ? selected : "Silkite Dark";
  } else {
    m_currentTheme = "Silkite Dark";
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
