#include "contact_list_model.h"
#include <algorithm>

ContactListModel::ContactListModel(QObject *parent)
    : QAbstractListModel(parent) {}

int ContactListModel::rowCount(const QModelIndex &parent) const {
  if (parent.isValid()) {
    return 0;
  }
  return m_filteredIndices.size();
}

QVariant ContactListModel::data(const QModelIndex &index, int role) const {
  if (!index.isValid() || index.row() < 0 || index.row() >= m_filteredIndices.size()) {
    return {};
  }

  const ContactItem &item = m_contacts.at(m_filteredIndices.at(index.row()));
  switch (role) {
  case UserIdRole:
    return item.userId;
  case ChatIdRole:
    return item.chatId;
  case FirstNameRole:
    return item.firstName;
  case LastNameRole:
    return item.lastName;
  case FullNameRole:
    return item.fullName;
  case PhoneNumberRole:
    return item.phoneNumber;
  case StatusTextRole:
    return item.statusText;
  case IsOnlineRole:
    return item.isOnline;
  case InitialsRole:
    return item.initials;
  case AvatarColorRole:
    return item.avatarColor;
  case AvatarPathRole:
    return item.avatarPath;
  case LastSeenSecsRole:
    return item.lastSeenSecs;
  default:
    return {};
  }
}

QHash<int, QByteArray> ContactListModel::roleNames() const {
  return {
    {UserIdRole, "userId"},
    {ChatIdRole, "chatId"},
    {FirstNameRole, "firstName"},
    {LastNameRole, "lastName"},
    {FullNameRole, "fullName"},
    {PhoneNumberRole, "phoneNumber"},
    {StatusTextRole, "statusText"},
    {IsOnlineRole, "isOnline"},
    {InitialsRole, "initials"},
    {AvatarColorRole, "avatarColor"},
    {AvatarPathRole, "avatarPath"},
    {LastSeenSecsRole, "lastSeenSecs"}
  };
}

void ContactListModel::setFilterText(const QString &text) {
  if (m_filterText == text) {
    return;
  }
  m_filterText = text;
  updateFilter();
  emit filterTextChanged();
}

int ContactListModel::findContactIndex(qint64 userId) const {
  for (int i = 0; i < m_contacts.size(); ++i) {
    if (m_contacts.at(i).userId == userId) {
      return i;
    }
  }
  return -1;
}

QVariantMap ContactListModel::contactAt(int row) const {
  if (row < 0 || row >= m_filteredIndices.size()) {
    return {};
  }
  const ContactItem &item = m_contacts.at(m_filteredIndices.at(row));
  return {
    {"userId", item.userId},
    {"chatId", item.chatId},
    {"name", item.fullName},
    {"fullName", item.fullName},
    {"firstName", item.firstName},
    {"lastName", item.lastName},
    {"phoneNumber", item.phoneNumber},
    {"statusText", item.statusText},
    {"isOnline", item.isOnline},
    {"initials", item.initials},
    {"avatarColor", item.avatarColor},
    {"avatarPath", item.avatarPath},
    {"lastSeenSecs", item.lastSeenSecs}
  };
}

QVariantMap ContactListModel::contactByUserId(qint64 userId) const {
  const int idx = findContactIndex(userId);
  if (idx < 0) {
    return {};
  }
  const ContactItem &item = m_contacts.at(idx);
  return {
    {"userId", item.userId},
    {"chatId", item.chatId},
    {"name", item.fullName},
    {"fullName", item.fullName},
    {"firstName", item.firstName},
    {"lastName", item.lastName},
    {"phoneNumber", item.phoneNumber},
    {"statusText", item.statusText},
    {"isOnline", item.isOnline},
    {"initials", item.initials},
    {"avatarColor", item.avatarColor},
    {"avatarPath", item.avatarPath},
    {"lastSeenSecs", item.lastSeenSecs}
  };
}

void ContactListModel::clearContacts() {
  beginResetModel();
  m_contacts.clear();
  m_filteredIndices.clear();
  endResetModel();
  emit countChanged();
}

void ContactListModel::upsertContact(const QVariantMap &data) {
  const qint64 userId = data.value("userId").toLongLong();
  if (userId <= 0) return;

  const int idx = findContactIndex(userId);
  if (idx >= 0) {
    ContactItem &item = m_contacts[idx];
    if (data.contains("firstName")) item.firstName = data.value("firstName").toString();
    if (data.contains("lastName")) item.lastName = data.value("lastName").toString();
    if (data.contains("fullName")) item.fullName = data.value("fullName").toString();
    if (data.contains("phoneNumber")) item.phoneNumber = data.value("phoneNumber").toString();
    if (data.contains("statusText")) item.statusText = data.value("statusText").toString();
    if (data.contains("isOnline")) item.isOnline = data.value("isOnline").toBool();
    if (data.contains("lastSeenSecs")) item.lastSeenSecs = data.value("lastSeenSecs").toLongLong();
    if (data.contains("initials")) item.initials = data.value("initials").toString();
    if (data.contains("avatarColor")) item.avatarColor = data.value("avatarColor").toString();
    if (data.contains("avatarPath")) item.avatarPath = data.value("avatarPath").toString();
    if (data.contains("chatId")) item.chatId = data.value("chatId").toLongLong();
    if (data.contains("hasChatHistory")) item.hasChatHistory = data.value("hasChatHistory").toBool();
  } else {
    ContactItem item;
    item.userId = userId;
    item.chatId = data.value("chatId", 0).toLongLong();
    item.firstName = data.value("firstName").toString();
    item.lastName = data.value("lastName").toString();
    item.fullName = data.value("fullName").toString();
    item.phoneNumber = data.value("phoneNumber").toString();
    item.statusText = data.value("statusText").toString();
    item.isOnline = data.value("isOnline", false).toBool();
    item.lastSeenSecs = data.value("lastSeenSecs", 0).toLongLong();
    item.initials = data.value("initials").toString();
    item.avatarColor = data.value("avatarColor", QStringLiteral("#526C8A")).toString();
    item.avatarPath = data.value("avatarPath").toString();
    item.hasChatHistory = data.value("hasChatHistory", false).toBool();
    m_contacts.append(item);
  }

  updateFilter();
  emit countChanged();
}

void ContactListModel::updateContactStatus(qint64 userId, const QString &statusText, bool isOnline, qint64 lastSeenSecs) {
  const int idx = findContactIndex(userId);
  if (idx >= 0) {
    m_contacts[idx].statusText = statusText;
    m_contacts[idx].isOnline = isOnline;
    m_contacts[idx].lastSeenSecs = lastSeenSecs;
    updateFilter();
  }
}

void ContactListModel::updateContactAvatar(qint64 userId, const QString &avatarPath) {
  const int idx = findContactIndex(userId);
  if (idx >= 0) {
    m_contacts[idx].avatarPath = avatarPath;
    for (int r = 0; r < m_filteredIndices.size(); ++r) {
      if (m_filteredIndices[r] == idx) {
        emit dataChanged(index(r), index(r), {AvatarPathRole});
        break;
      }
    }
  }
}

void ContactListModel::setContactHasChatHistory(qint64 userId, qint64 chatId, bool hasHistory) {
  const int idx = findContactIndex(userId);
  if (idx >= 0) {
    m_contacts[idx].chatId = chatId;
    m_contacts[idx].hasChatHistory = hasHistory;
    updateFilter();
    emit countChanged();
  }
}

void ContactListModel::removeContact(qint64 userId) {
  const int idx = findContactIndex(userId);
  if (idx >= 0) {
    m_contacts.removeAt(idx);
    updateFilter();
    emit countChanged();
  }
}

void ContactListModel::updateFilter() {
  beginResetModel();
  m_filteredIndices.clear();

  const QString query = m_filterText.trimmed();

  for (int i = 0; i < m_contacts.size(); ++i) {
    const ContactItem &c = m_contacts.at(i);

    // Rule: Don't show existing chats, only available contacts with NO chat history
    if (c.hasChatHistory) {
      continue;
    }

    if (!query.isEmpty()) {
      const bool matchesName = c.fullName.contains(query, Qt::CaseInsensitive);
      const bool matchesPhone = c.phoneNumber.contains(query, Qt::CaseInsensitive);
      if (!matchesName && !matchesPhone) {
        continue;
      }
    }

    m_filteredIndices.append(i);
  }

  // Sort by last seen descending (online / higher lastSeenSecs first), then alphabetically
  std::sort(m_filteredIndices.begin(), m_filteredIndices.end(), [this](int a, int b) {
    const ContactItem &ca = m_contacts.at(a);
    const ContactItem &cb = m_contacts.at(b);

    if (ca.isOnline != cb.isOnline) {
      return ca.isOnline; // Online first
    }
    if (ca.lastSeenSecs != cb.lastSeenSecs) {
      return ca.lastSeenSecs > cb.lastSeenSecs; // More recent first
    }
    return QString::compare(ca.fullName, cb.fullName, Qt::CaseInsensitive) < 0;
  });

  endResetModel();
}
