#pragma once
#include <QAbstractListModel>
#include <QString>
#include <QVector>
#include <QVariantMap>
#include <QTimer>
#include "chat_organization_manager.h"

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
  Q_PROPERTY(ChatOrganizationManager *organizationManager READ organizationManager WRITE setOrganizationManager NOTIFY organizationManagerChanged)

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
    IsOnlineRole,
    FolderNamesRole
  };

  explicit ChatListModel(QObject *parent = nullptr);

  int rowCount(const QModelIndex &parent = QModelIndex()) const override;

  QVariant data(const QModelIndex &index,
                int role = Qt::DisplayRole) const override;

  QHash<int, QByteArray> roleNames() const override;

  QString filterText() const;
  void setFilterText(const QString &text);

  ChatOrganizationManager *organizationManager() const { return m_orgManager; }
  void setOrganizationManager(ChatOrganizationManager *manager);

  Q_INVOKABLE QVariantMap chatAt(int row) const;
  Q_INVOKABLE QVariantMap chatById(qint64 chatId) const;
  Q_INVOKABLE void refreshFilter();

public slots:
  void upsertChat(const QVariantMap &chat);
  void clearChats();

signals:
  void filterTextChanged();
  void organizationManagerChanged();

private slots:
  void applyBatchUpdate();

private:
  QVector<Chat> m_chats;
  QVector<int> m_filteredIndices;

  QString m_filterText;
  ChatOrganizationManager *m_orgManager = nullptr;
  QTimer *m_batchTimer = nullptr;
  bool m_needsSort = false;

  void updateFilter();
  int indexOfChat(qint64 chatId) const;
};
