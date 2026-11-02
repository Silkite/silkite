#include "chat_list_model.h"

#include <QHash>
#include <QVariantMap>

ChatListModel::ChatListModel(QObject *parent) : QAbstractListModel(parent) {
  m_chats = {
      {1, "Tom Hollam", "Hello, sup lol", "10:59", "TH", "#526C8A", 2},
      {2, "Jeffery Dahmer", "Hello, sup lol", "10:59", "JD", "#7B638F", 2},
      {3, "Patrick Bateman", "Hello, sup lol", "10:59", "PB", "#8B6C62", 2}};
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
  if (row < 0 || row >= m_chats.size()) {
    return {};
  }

  const Chat &chat = m_chats.at(row);
  return {{"chatId", chat.id},
          {"name", chat.name},
          {"lastMessage", chat.lastMessage},
          {"time", chat.time},
          {"initials", chat.initials},
          {"avatarColor", chat.avatarColor},
          {"unreadCount", chat.unreadCount}};
}
