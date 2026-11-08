#pragma once

#include <QAbstractListModel>
#include <QString>
#include <QVariantMap>
#include <QVector>

struct GlobalSearchResultItem {
  qint64 id = 0;              // chatId or userId
  qint64 chatId = 0;          // Resolved chatId (if any)
  qint64 userId = 0;          // If this is a user / contact
  QString name;               // Title or Full Name
  QString username;           // @handle (if any)
  QString subtitle;           // e.g. "50,000 subscribers", "online", last message
  QString type;               // "channel", "group", "bot", "user", "contact"
  QString section;            // "local" or "global"
  QString initials;
  QString avatarColor;
  QString avatarPath;
  bool isOnline = false;
};

class GlobalSearchModel : public QAbstractListModel {
  Q_OBJECT

  Q_PROPERTY(QString query READ query WRITE setQuery NOTIFY queryChanged)
  Q_PROPERTY(bool isSearching READ isSearching NOTIFY isSearchingChanged)
  Q_PROPERTY(int totalCount READ rowCount NOTIFY countChanged)
  Q_PROPERTY(int localCount READ localCount NOTIFY countChanged)
  Q_PROPERTY(int globalCount READ globalCount NOTIFY countChanged)

public:
  enum SearchRoles {
    IdRole = Qt::UserRole + 1,
    ChatIdRole,
    UserIdRole,
    NameRole,
    UsernameRole,
    SubtitleRole,
    TypeRole,
    SectionRole,
    InitialsRole,
    AvatarColorRole,
    AvatarPathRole,
    IsOnlineRole
  };

  explicit GlobalSearchModel(QObject *parent = nullptr);

  int rowCount(const QModelIndex &parent = QModelIndex()) const override;
  QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
  QHash<int, QByteArray> roleNames() const override;

  QString query() const { return m_query; }
  void setQuery(const QString &q);

  bool isSearching() const { return m_isSearching; }
  int localCount() const { return m_localItems.size(); }
  int globalCount() const { return m_globalItems.size(); }

  Q_INVOKABLE QVariantMap itemAt(int index) const;

public slots:
  void setLocalResults(const QString &query, const QVariantList &results);
  void setGlobalResults(const QString &query, const QVariantList &results);
  void clear();

signals:
  void queryChanged();
  void isSearchingChanged();
  void countChanged();

private:
  void rebuildCombined();

  QString m_query;
  bool m_isSearching = false;
  QVector<GlobalSearchResultItem> m_localItems;
  QVector<GlobalSearchResultItem> m_globalItems;
  QVector<GlobalSearchResultItem> m_items;
};
