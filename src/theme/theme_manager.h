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
  Q_PROPERTY(bool ircMode READ ircMode WRITE setIrcMode NOTIFY ircModeChanged)
  Q_PROPERTY(int uiFontSize READ uiFontSize WRITE setUiFontSize NOTIFY uiFontSizeChanged)
  Q_PROPERTY(int chatFontSize READ chatFontSize WRITE setChatFontSize NOTIFY chatFontSizeChanged)
  Q_PROPERTY(int chatSpacing READ chatSpacing WRITE setChatSpacing NOTIFY chatSpacingChanged)

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

  bool ircMode() const { return m_ircMode; }
  void setIrcMode(bool enabled);

  int uiFontSize() const { return m_uiFontSize; }
  void setUiFontSize(int size);

  int chatFontSize() const { return m_chatFontSize; }
  void setChatFontSize(int size);

  int chatSpacing() const { return m_chatSpacing; }
  void setChatSpacing(int spacing);

  Q_INVOKABLE void selectTheme(const QString &name);
  Q_INVOKABLE QString configFilePath() const;

signals:
  void themeChanged();
  void ircModeChanged();
  void uiFontSizeChanged();
  void chatFontSizeChanged();
  void chatSpacingChanged();

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
  bool m_ircMode = false;
  int m_uiFontSize = 13;
  int m_chatFontSize = 15;
  int m_chatSpacing = 6;
};
