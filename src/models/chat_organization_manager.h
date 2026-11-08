#pragma once

#include <QAbstractListModel>
#include <QString>
#include <QVector>
#include <QSet>
#include <QSettings>
#include <QVariantMap>

struct ChatFolder {
  QString id;
  QString name;
  QString icon; // emoji or icon tag
  QSet<qint64> chatIds;
};

class ChatOrganizationManager : public QAbstractListModel {
  Q_OBJECT

  Q_PROPERTY(QString activeFolderId READ activeFolderId WRITE setActiveFolderId NOTIFY activeFolderIdChanged)
  Q_PROPERTY(int activeFolderIndex READ activeFolderIndex NOTIFY activeFolderChanged)

public:
  enum FolderRoles {
    IdRole = Qt::UserRole + 1,
    NameRole,
    IconRole,
    ChatCountRole,
    IsActiveRole
  };

  explicit ChatOrganizationManager(QObject *parent = nullptr);

  int rowCount(const QModelIndex &parent = QModelIndex()) const override;
  QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
  QHash<int, QByteArray> roleNames() const override;

  QString activeFolderId() const { return m_activeFolderId; }
  int activeFolderIndex() const;

  Q_INVOKABLE bool isChatInActiveFolder(qint64 chatId) const;
  Q_INVOKABLE bool isChatInFolder(const QString &folderId, qint64 chatId) const;
  Q_INVOKABLE QStringList getChatFolderNames(qint64 chatId) const;
  Q_INVOKABLE QVariantList getFoldersForChat(qint64 chatId) const;

  // Management operations
  Q_INVOKABLE QString createFolder(const QString &name, const QString &icon = "📁");
  Q_INVOKABLE bool renameFolder(const QString &folderId, const QString &newName, const QString &newIcon = QString());
  Q_INVOKABLE bool deleteFolder(const QString &folderId);
  Q_INVOKABLE void moveChatToFolder(const QString &folderId, qint64 chatId);
  Q_INVOKABLE void removeChatFromFolder(const QString &folderId, qint64 chatId);
  Q_INVOKABLE void toggleChatInFolder(const QString &folderId, qint64 chatId);
  Q_INVOKABLE void resetFolders();

public slots:
  void setActiveFolderId(const QString &id);

signals:
  void activeFolderIdChanged(const QString &folderId);
  void activeFolderChanged();
  void folderContentsChanged();
  void folderCreated(const QString &folderId);

private:
  void loadSettings();
  void saveSettings();
  int findFolderIndex(const QString &folderId) const;

  QVector<ChatFolder> m_folders;
  QString m_activeFolderId = "all";
};
