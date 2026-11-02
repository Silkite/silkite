#pragma once
#include <QAbstractListModel>
#include <QString>
#include <QVector>

struct Chat {
  qint64 id;
  QString name;
  QString lastMessage;
  QString time;
  QString initials;
  QString avatarColor;
  int unreadCount;
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
    UnreadCountRole
  };

  explicit ChatListModel(QObject *parent = nullptr);

  int rowCount(const QModelIndex &parent = QModelIndex()) const override;

  QVariant data(const QModelIndex &index,
                int role = Qt::DisplayRole) const override;

  QHash<int, QByteArray> roleNames() const override;

  QString filterText() const;
  void setFilterText(const QString &text);

  Q_INVOKABLE QVariantMap chatAt(int row) const;

signals:
  void filterTextChanged();

private:
  QVector<Chat> m_chats;
  QVector<int> m_filteredIndices;

  QString m_filterText;

  void updateFilter();
};
