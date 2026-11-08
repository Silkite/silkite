#include "chat_organization_manager.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUuid>

ChatOrganizationManager::ChatOrganizationManager(QObject *parent)
    : QAbstractListModel(parent) {
  loadSettings();
}

int ChatOrganizationManager::rowCount(const QModelIndex &parent) const {
  if (parent.isValid()) {
    return 0;
  }
  return m_folders.size();
}

QVariant ChatOrganizationManager::data(const QModelIndex &index, int role) const {
  if (!index.isValid() || index.row() < 0 || index.row() >= m_folders.size()) {
    return {};
  }

  const ChatFolder &folder = m_folders.at(index.row());

  switch (role) {
  case IdRole:
    return folder.id;
  case NameRole:
    return folder.name;
  case IconRole:
    return folder.icon;
  case ChatCountRole:
    return static_cast<int>(folder.chatIds.size());
  case IsActiveRole:
    return folder.id == m_activeFolderId;
  default:
    return {};
  }
}

QHash<int, QByteArray> ChatOrganizationManager::roleNames() const {
  QHash<int, QByteArray> roles;
  roles[IdRole] = "folderId";
  roles[NameRole] = "name";
  roles[IconRole] = "folderIcon";
  roles[ChatCountRole] = "chatCount";
  roles[IsActiveRole] = "isActive";
  return roles;
}

int ChatOrganizationManager::activeFolderIndex() const {
  return findFolderIndex(m_activeFolderId);
}

int ChatOrganizationManager::findFolderIndex(const QString &folderId) const {
  for (int i = 0; i < m_folders.size(); ++i) {
    if (m_folders.at(i).id == folderId) {
      return i;
    }
  }
  return -1;
}

void ChatOrganizationManager::setActiveFolderId(const QString &id) {
  if (m_activeFolderId == id) {
    return;
  }

  m_activeFolderId = id;
  emit activeFolderIdChanged(m_activeFolderId);
  emit activeFolderChanged();

  // Notify views of active state change
  if (!m_folders.isEmpty()) {
    emit dataChanged(index(0, 0), index(m_folders.size() - 1, 0), {IsActiveRole});
  }
}

bool ChatOrganizationManager::isChatInActiveFolder(qint64 chatId) const {
  if (m_activeFolderId == "all" || m_activeFolderId.isEmpty()) {
    return true;
  }

  int idx = findFolderIndex(m_activeFolderId);
  if (idx < 0) {
    return true;
  }

  return m_folders.at(idx).chatIds.contains(chatId);
}

bool ChatOrganizationManager::isChatInFolder(const QString &folderId, qint64 chatId) const {
  if (folderId == "all") {
    return true;
  }
  int idx = findFolderIndex(folderId);
  if (idx < 0) {
    return false;
  }
  return m_folders.at(idx).chatIds.contains(chatId);
}

QStringList ChatOrganizationManager::getChatFolderNames(qint64 chatId) const {
  QStringList names;
  for (const auto &folder : m_folders) {
    if (folder.id != "all" && folder.chatIds.contains(chatId)) {
      names.append(folder.name);
    }
  }
  return names;
}

QVariantList ChatOrganizationManager::getFoldersForChat(qint64 chatId) const {
  QVariantList list;
  for (const auto &folder : m_folders) {
    if (folder.id == "all") continue;
    QVariantMap map;
    map["id"] = folder.id;
    map["name"] = folder.name;
    map["icon"] = folder.icon;
    map["hasChat"] = folder.chatIds.contains(chatId);
    list.append(map);
  }
  return list;
}

QString ChatOrganizationManager::createFolder(const QString &name, const QString &icon) {
  QString trimmed = name.trimmed();
  if (trimmed.isEmpty()) {
    return QString();
  }

  QString newId = QUuid::createUuid().toString(QUuid::WithoutBraces);
  QString folderIcon = icon.trimmed().isEmpty() ? QStringLiteral("📁") : icon.trimmed();

  int insertIndex = m_folders.size();
  beginInsertRows(QModelIndex(), insertIndex, insertIndex);
  m_folders.append(ChatFolder{newId, trimmed, folderIcon, {}});
  endInsertRows();

  saveSettings();
  emit folderContentsChanged();
  emit folderCreated(newId);
  return newId;
}

bool ChatOrganizationManager::renameFolder(const QString &folderId, const QString &newName, const QString &newIcon) {
  if (folderId == "all") {
    return false;
  }

  int idx = findFolderIndex(folderId);
  if (idx < 0) {
    return false;
  }

  QString trimmed = newName.trimmed();
  if (!trimmed.isEmpty()) {
    m_folders[idx].name = trimmed;
  }
  if (!newIcon.trimmed().isEmpty()) {
    m_folders[idx].icon = newIcon.trimmed();
  }

  emit dataChanged(index(idx, 0), index(idx, 0), {NameRole, IconRole});
  saveSettings();
  emit folderContentsChanged();
  return true;
}

bool ChatOrganizationManager::deleteFolder(const QString &folderId) {
  if (folderId == "all") {
    return false;
  }

  int idx = findFolderIndex(folderId);
  if (idx < 0) {
    return false;
  }

  beginRemoveRows(QModelIndex(), idx, idx);
  m_folders.removeAt(idx);
  endRemoveRows();

  if (m_activeFolderId == folderId) {
    setActiveFolderId("all");
  }

  saveSettings();
  emit folderContentsChanged();
  return true;
}

void ChatOrganizationManager::moveChatToFolder(const QString &folderId, qint64 chatId) {
  if (folderId == "all" || chatId == 0) return;

  int idx = findFolderIndex(folderId);
  if (idx >= 0) {
    if (!m_folders[idx].chatIds.contains(chatId)) {
      m_folders[idx].chatIds.insert(chatId);
      emit dataChanged(index(idx, 0), index(idx, 0), {ChatCountRole});
      saveSettings();
      emit folderContentsChanged();
    }
  }
}

void ChatOrganizationManager::removeChatFromFolder(const QString &folderId, qint64 chatId) {
  if (folderId == "all" || chatId == 0) return;

  int idx = findFolderIndex(folderId);
  if (idx >= 0) {
    if (m_folders[idx].chatIds.remove(chatId)) {
      emit dataChanged(index(idx, 0), index(idx, 0), {ChatCountRole});
      saveSettings();
      emit folderContentsChanged();
    }
  }
}

void ChatOrganizationManager::removeChatFromAllFolders(qint64 chatId) {
  if (chatId == 0) return;
  bool changed = false;
  for (int i = 0; i < m_folders.size(); ++i) {
    if (m_folders[i].chatIds.remove(chatId)) {
      emit dataChanged(index(i, 0), index(i, 0), {ChatCountRole});
      changed = true;
    }
  }
  if (changed) {
    saveSettings();
    emit folderContentsChanged();
  }
}

void ChatOrganizationManager::toggleChatInFolder(const QString &folderId, qint64 chatId) {
  if (folderId == "all" || chatId == 0) return;

  int idx = findFolderIndex(folderId);
  if (idx >= 0) {
    if (m_folders[idx].chatIds.contains(chatId)) {
      m_folders[idx].chatIds.remove(chatId);
    } else {
      m_folders[idx].chatIds.insert(chatId);
    }
    emit dataChanged(index(idx, 0), index(idx, 0), {ChatCountRole});
    saveSettings();
    emit folderContentsChanged();
  }
}

void ChatOrganizationManager::resetFolders() {
  QSettings settings;
  settings.remove("chatFolders");
  m_activeFolderId = "all";
  emit activeFolderIdChanged(m_activeFolderId);
  emit activeFolderChanged();
  loadSettings();
  emit folderContentsChanged();
}

void ChatOrganizationManager::saveSettings() {
  QSettings settings;
  QJsonArray array;

  for (const auto &folder : m_folders) {
    if (folder.id == "all") continue;

    QJsonObject obj;
    obj["id"] = folder.id;
    obj["name"] = folder.name;
    obj["icon"] = folder.icon;

    QJsonArray chatsArray;
    for (qint64 cid : folder.chatIds) {
      chatsArray.append(QString::number(cid));
    }
    obj["chats"] = chatsArray;

    array.append(obj);
  }

  settings.setValue("chatFolders", QJsonDocument(array).toJson(QJsonDocument::Compact));
}

void ChatOrganizationManager::loadSettings() {
  beginResetModel();
  m_folders.clear();

  // Always insert default "All" tab first
  m_folders.append(ChatFolder{"all", QStringLiteral("All"), QStringLiteral("💬"), {}});

  QSettings settings;
  QByteArray raw = settings.value("chatFolders").toByteArray();

  if (raw.isEmpty()) {
    // Provide nice suggested default folders for UX
    m_folders.append(ChatFolder{"work", QStringLiteral("Work"), QStringLiteral("💼"), {}});
    m_folders.append(ChatFolder{"personal", QStringLiteral("Personal"), QStringLiteral("👥"), {}});
    m_folders.append(ChatFolder{"channels", QStringLiteral("Channels"), QStringLiteral("📢"), {}});
  } else {
    QJsonDocument doc = QJsonDocument::fromJson(raw);
    if (doc.isArray()) {
      QJsonArray array = doc.array();
      for (const auto &val : array) {
        if (!val.isObject()) continue;
        QJsonObject obj = val.toObject();
        QString id = obj.value("id").toString();
        QString name = obj.value("name").toString();
        QString icon = obj.value("icon").toString("📁");

        QSet<qint64> chats;
        QJsonArray chatsArray = obj.value("chats").toArray();
        for (const auto &cidVal : chatsArray) {
          chats.insert(cidVal.toString().toLongLong());
        }

        if (!id.isEmpty() && !name.isEmpty()) {
          m_folders.append(ChatFolder{id, name, icon, chats});
        }
      }
    }
  }

  endResetModel();
}
