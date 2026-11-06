#pragma once
#include <QAbstractListModel>
#include <QString>
#include <QVector>
#include <QVariantMap>

struct Chat {
  qint64 id;
  QString name;
  QString lastMessage;
  QString time;
  QString initials;
  QString avatarColor;
  QString avatarPath;
  int unreadCount;
  qint64 order = 0;
  QString statusText;
  bool isOnline = false;
};

class ChatListModel : public QAbstractListModel {
  Q_OBJECT

  Q_PROPERTY(QString filterText READ filterText WRITE setFilterText NOTIFY
                 filterTextChanged)
public:
  enum ChatRoles {
    IdRole = Qt::UserRole + 1,
    NameRole,
    LastMessageRole,
    TimeRole,
    InitialsRole,
    AvatarColorRole,
    UnreadCountRole,
    AvatarPathRole,
    StatusTextRole,
    IsOnlineRole
  };

  explicit ChatListModel(QObject *parent = nullptr);

  int rowCount(const QModelIndex &parent = QModelIndex()) const override;

  QVariant data(const QModelIndex &index,
                int role = Qt::DisplayRole) const override;

  QHash<int, QByteArray> roleNames() const override;

  QString filterText() const;
  void setFilterText(const QString &text);

  Q_INVOKABLE QVariantMap chatAt(int row) const;
  Q_INVOKABLE QVariantMap chatById(qint64 chatId) const;

public slots:
  void upsertChat(const QVariantMap &chat);
  void clearChats();

signals:
  void filterTextChanged();

private:
  QVector<Chat> m_chats;
  QVector<int> m_filteredIndices;

  QString m_filterText;

  void updateFilter();
  int indexOfChat(qint64 chatId) const;
};
