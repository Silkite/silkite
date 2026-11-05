#pragma once

#include <QObject>
#include <QColor>
#include <QHash>
#include <QJsonObject>
#include <QStringList>

class ThemeManager final : public QObject {
  Q_OBJECT
  Q_PROPERTY(QString currentTheme READ currentTheme NOTIFY themeChanged)
  Q_PROPERTY(QStringList availableThemes READ availableThemes CONSTANT)
  Q_PROPERTY(QColor windowBackground READ windowBackground NOTIFY themeChanged)
  Q_PROPERTY(QColor panelBackground READ panelBackground NOTIFY themeChanged)
  Q_PROPERTY(QColor elevatedBackground READ elevatedBackground NOTIFY themeChanged)
  Q_PROPERTY(QColor controlBackground READ controlBackground NOTIFY themeChanged)
  Q_PROPERTY(QColor primaryText READ primaryText NOTIFY themeChanged)
  Q_PROPERTY(QColor secondaryText READ secondaryText NOTIFY themeChanged)
  Q_PROPERTY(QColor accent READ accent NOTIFY themeChanged)
  Q_PROPERTY(QColor accentText READ accentText NOTIFY themeChanged)
  Q_PROPERTY(QColor divider READ divider NOTIFY themeChanged)

public:
  explicit ThemeManager(QObject *parent = nullptr);

  QString currentTheme() const;
  QStringList availableThemes() const;
  QColor windowBackground() const;
  QColor panelBackground() const;
  QColor elevatedBackground() const;
  QColor controlBackground() const;
  QColor primaryText() const;
  QColor secondaryText() const;
  QColor accent() const;
  QColor accentText() const;
  QColor divider() const;

  Q_INVOKABLE void selectTheme(const QString &name);
  Q_INVOKABLE QString configFilePath() const;

signals:
  void themeChanged();

public:
  struct Palette {
    QColor windowBackground;
    QColor panelBackground;
    QColor elevatedBackground;
    QColor controlBackground;
    QColor primaryText;
    QColor secondaryText;
    QColor accent;
    QColor accentText;
    QColor divider;
  };

  void load();
  void save() const;
  void createDefaultConfig() const;
  static QJsonObject paletteToJson(const Palette &palette);
  static Palette paletteFromJson(const QJsonObject &object);

  QString m_currentTheme;
  QStringList m_availableThemes;
  QHash<QString, Palette> m_palettes;
  Palette m_currentPalette;
};
