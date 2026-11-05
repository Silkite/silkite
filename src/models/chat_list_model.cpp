#include "chat_list_model.h"

#include <QHash>
#include <QVariantMap>
#include <algorithm>

ChatListModel::ChatListModel(QObject *parent) : QAbstractListModel(parent) {
  updateFilter();
}

int ChatListModel::rowCount(const QModelIndex &parent) const {
  if (parent.isValid()) {
    return 0;
  }

  return m_filteredIndices.size();
}

QVariant ChatListModel::data(const QModelIndex &index, int role) const {
  if (!index.isValid() || index.row() < 0 ||
      index.row() >= m_filteredIndices.size()) {
    return {};
  }

  const Chat &chat = m_chats.at(m_filteredIndices.at(index.row()));

  switch (role) {
  case IdRole:
    return chat.id;

  case NameRole:
    return chat.name;

  case LastMessageRole:
    return chat.lastMessage;

  case TimeRole:
    return chat.time;

  case InitialsRole:
    return chat.initials;

  case AvatarColorRole:
    return chat.avatarColor;

  case AvatarPathRole:
    return chat.avatarPath;

  case UnreadCountRole:
    return chat.unreadCount;

  default:
    return {};
  }
}

QHash<int, QByteArray> ChatListModel::roleNames() const {
  QHash<int, QByteArray> roles;

  roles[IdRole] = "chatId";
  roles[NameRole] = "name";
  roles[LastMessageRole] = "lastMessage";
  roles[TimeRole] = "time";
  roles[InitialsRole] = "initials";
  roles[AvatarColorRole] = "avatarColor";
  roles[AvatarPathRole] = "avatarPath";
  roles[UnreadCountRole] = "unreadCount";

  return roles;
}

QString ChatListModel::filterText() const { return m_filterText; }

void ChatListModel::setFilterText(const QString &text) {
  if (m_filterText == text) {
    return;
  }

  m_filterText = text;

  updateFilter();

  emit filterTextChanged();
}

void ChatListModel::updateFilter() {
  beginResetModel();
  m_filteredIndices.clear();

  const QString query = m_filterText.trimmed();
  for (int i = 0; i < m_chats.size(); ++i) {
    const Chat &chat = m_chats.at(i);

    const bool matchesName = chat.name.contains(query, Qt::CaseInsensitive);

    const bool matchesMessage =
        chat.lastMessage.contains(query, Qt::CaseInsensitive);

    if (query.isEmpty() || matchesName || matchesMessage) {
      m_filteredIndices.append(i);
    }
  }

  endResetModel();
}

QVariantMap ChatListModel::chatAt(int row) const {
  if (row < 0 || row >= m_filteredIndices.size()) {
    return {};
  }

  const Chat &chat = m_chats.at(m_filteredIndices.at(row));
  return {{"chatId", chat.id},
          {"name", chat.name},
          {"lastMessage", chat.lastMessage},
          {"time", chat.time},
          {"initials", chat.initials},
          {"avatarColor", chat.avatarColor},
          {"avatarPath", chat.avatarPath},
          {"unreadCount", chat.unreadCount}};
}

int ChatListModel::indexOfChat(qint64 chatId) const {
  for (int i = 0; i < m_chats.size(); ++i)
    if (m_chats.at(i).id == chatId) return i;
  return -1;
}

QVariantMap ChatListModel::chatById(qint64 chatId) const {
  const int i = indexOfChat(chatId);
  if (i < 0) return {};
  const Chat &c = m_chats.at(i);
  return {{"chatId", c.id}, {"name", c.name}, {"lastMessage", c.lastMessage},
          {"time", c.time}, {"initials", c.initials}, {"avatarColor", c.avatarColor},
          {"avatarPath", c.avatarPath},
          {"unreadCount", c.unreadCount}};
}

void ChatListModel::clearChats() {
  beginResetModel(); m_chats.clear(); m_filteredIndices.clear(); endResetModel();
}

void ChatListModel::upsertChat(const QVariantMap &v) {
  const qint64 id = v.value("chatId").toLongLong();
  if (!id) return;
  const int i = indexOfChat(id);
  Chat c = i < 0 ? Chat{id, {}, {}, {}, "?", "#526C8A", {}, 0, 0} : m_chats.at(i);
  c.id = id;
  if (v.contains("name")) c.name = v.value("name").toString();
  if (v.contains("lastMessage")) c.lastMessage = v.value("lastMessage").toString();
  if (v.contains("time")) c.time = v.value("time").toString();
  if (v.contains("initials")) c.initials = v.value("initials").toString();
  if (v.contains("avatarColor")) c.avatarColor = v.value("avatarColor").toString();
  if (v.contains("avatarPath")) c.avatarPath = v.value("avatarPath").toString();
  if (v.contains("unreadCount")) c.unreadCount = v.value("unreadCount").toInt();
  if (v.contains("order")) c.order = v.value("order").toLongLong();
  if (c.initials == "?" && !c.name.trimmed().isEmpty()) c.initials = c.name.trimmed().left(2).toUpper();
  if (i < 0) m_chats.append(c); else m_chats[i] = c;
  std::sort(m_chats.begin(), m_chats.end(), [](const Chat &a, const Chat &b) { return a.order > b.order; });
  updateFilter();
}
