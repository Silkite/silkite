#include "global_search_model.h"

GlobalSearchModel::GlobalSearchModel(QObject *parent)
    : QAbstractListModel(parent) {}

int GlobalSearchModel::rowCount(const QModelIndex &parent) const {
  if (parent.isValid()) return 0;
  return m_items.size();
}

QVariant GlobalSearchModel::data(const QModelIndex &index, int role) const {
  if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size()) {
    return {};
  }

  const auto &item = m_items.at(index.row());
  switch (role) {
  case IdRole: return item.id;
  case ChatIdRole: return item.chatId;
  case UserIdRole: return item.userId;
  case NameRole: return item.name;
  case UsernameRole: return item.username;
  case SubtitleRole: return item.subtitle;
  case TypeRole: return item.type;
  case SectionRole: return item.section;
  case InitialsRole: return item.initials;
  case AvatarColorRole: return item.avatarColor;
  case AvatarPathRole: return item.avatarPath;
  case IsOnlineRole: return item.isOnline;
  default: return {};
  }
}

QHash<int, QByteArray> GlobalSearchModel::roleNames() const {
  QHash<int, QByteArray> roles;
  roles[IdRole] = "id";
  roles[ChatIdRole] = "chatId";
  roles[UserIdRole] = "userId";
  roles[NameRole] = "name";
  roles[UsernameRole] = "username";
  roles[SubtitleRole] = "subtitle";
  roles[TypeRole] = "type";
  roles[SectionRole] = "section";
  roles[InitialsRole] = "initials";
  roles[AvatarColorRole] = "avatarColor";
  roles[AvatarPathRole] = "avatarPath";
  roles[IsOnlineRole] = "isOnline";
  return roles;
}

void GlobalSearchModel::setQuery(const QString &q) {
  if (m_query == q) return;
  m_query = q;
  emit queryChanged();
  if (m_query.trimmed().isEmpty()) {
    clear();
  }
}

QVariantMap GlobalSearchModel::itemAt(int index) const {
  if (index < 0 || index >= m_items.size()) return {};
  const auto &item = m_items.at(index);
  return {
    {"id", item.id},
    {"chatId", item.chatId},
    {"userId", item.userId},
    {"name", item.name},
    {"username", item.username},
    {"subtitle", item.subtitle},
    {"type", item.type},
    {"section", item.section},
    {"initials", item.initials},
    {"avatarColor", item.avatarColor},
    {"avatarPath", item.avatarPath},
    {"isOnline", item.isOnline}
  };
}

void GlobalSearchModel::setLocalResults(const QString &query, const QVariantList &results) {
  if (query != m_query.trimmed()) return;

  m_localItems.clear();
  for (const auto &val : results) {
    const auto m = val.toMap();
    GlobalSearchResultItem item;
    item.id = m.value("id").toLongLong();
    item.chatId = m.value("chatId").toLongLong();
    item.userId = m.value("userId").toLongLong();
    item.name = m.value("name").toString();
    item.username = m.value("username").toString();
    item.subtitle = m.value("subtitle").toString();
    item.type = m.value("type").toString();
    item.section = QStringLiteral("local");
    item.initials = m.value("initials").toString();
    item.avatarColor = m.value("avatarColor", QStringLiteral("#526C8A")).toString();
    item.avatarPath = m.value("avatarPath").toString();
    item.isOnline = m.value("isOnline").toBool();
    m_localItems.append(item);
  }

  rebuildCombined();
}

void GlobalSearchModel::setGlobalResults(const QString &query, const QVariantList &results) {
  if (query != m_query.trimmed()) return;

  m_globalItems.clear();
  for (const auto &val : results) {
    const auto m = val.toMap();
    GlobalSearchResultItem item;
    item.id = m.value("id").toLongLong();
    item.chatId = m.value("chatId").toLongLong();
    item.userId = m.value("userId").toLongLong();
    item.name = m.value("name").toString();
    item.username = m.value("username").toString();
    item.subtitle = m.value("subtitle").toString();
    item.type = m.value("type").toString();
    item.section = QStringLiteral("global");
    item.initials = m.value("initials").toString();
    item.avatarColor = m.value("avatarColor", QStringLiteral("#526C8A")).toString();
    item.avatarPath = m.value("avatarPath").toString();
    item.isOnline = m.value("isOnline").toBool();
    m_globalItems.append(item);
  }

  m_isSearching = false;
  emit isSearchingChanged();
  rebuildCombined();
}

void GlobalSearchModel::clear() {
  beginResetModel();
  m_localItems.clear();
  m_globalItems.clear();
  m_items.clear();
  m_isSearching = false;
  endResetModel();
  emit isSearchingChanged();
  emit countChanged();
}

void GlobalSearchModel::rebuildCombined() {
  beginResetModel();
  m_items.clear();
  m_items.reserve(m_localItems.size() + m_globalItems.size());

  QSet<qint64> seenChatIds;
  for (const auto &item : m_localItems) {
    if (item.chatId != 0) {
      seenChatIds.insert(item.chatId);
    }
    m_items.append(item);
  }

  for (const auto &item : m_globalItems) {
    if (item.chatId != 0 && seenChatIds.contains(item.chatId)) {
      continue; // Skip duplicate if already in local results
    }
    m_items.append(item);
  }

  endResetModel();
  emit countChanged();
}
