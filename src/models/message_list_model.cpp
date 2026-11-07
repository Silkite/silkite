#include "message_list_model.h"

MessageListModel::MessageListModel(QObject *parent)
    : QAbstractListModel(parent) {}

int MessageListModel::rowCount(const QModelIndex &parent) const {
  if (parent.isValid()) return 0;
  return static_cast<int>(m_messages.size());
}

QVariant MessageListModel::data(const QModelIndex &index, int role) const {
  if (!index.isValid() || index.row() < 0 || index.row() >= m_messages.size()) {
    return {};
  }

  const auto &msg = m_messages.at(index.row());

  switch (role) {
  case MessageIdRole:
    return msg.value(QStringLiteral("messageId"));
  case TextRole:
    return msg.value(QStringLiteral("text"));
  case CaptionRole:
    return msg.value(QStringLiteral("caption"));
  case TimeRole:
    return msg.value(QStringLiteral("time"));
  case OutgoingRole:
    return msg.value(QStringLiteral("outgoing"));
  case StatusRole:
    return msg.value(QStringLiteral("status"));
  case FilePathRole:
    return msg.value(QStringLiteral("filePath"));
  case MediaTypeRole:
    return msg.value(QStringLiteral("mediaType"));
  case MediaWidthRole:
    return msg.value(QStringLiteral("mediaWidth"));
  case MediaHeightRole:
    return msg.value(QStringLiteral("mediaHeight"));
  case DurationRole:
    return msg.value(QStringLiteral("duration"));
  case FileNameRole:
    return msg.value(QStringLiteral("fileName"));
  case FileSizeRole:
    return msg.value(QStringLiteral("fileSize"));
  case IsDownloadingRole:
    return msg.value(QStringLiteral("isDownloading"));
  case ReplyToMessageIdRole:
    return msg.value(QStringLiteral("replyToMessageId"));
  case ReplyTextRole:
    return msg.value(QStringLiteral("replyText"));
  case ReplySenderRole:
    return msg.value(QStringLiteral("replySender"));
  case ModelDataRole:
    return msg;
  default:
    return {};
  }
}

QHash<int, QByteArray> MessageListModel::roleNames() const {
  QHash<int, QByteArray> roles;
  roles[MessageIdRole] = "messageId";
  roles[TextRole] = "text";
  roles[CaptionRole] = "caption";
  roles[TimeRole] = "time";
  roles[OutgoingRole] = "outgoing";
  roles[StatusRole] = "status";
  roles[FilePathRole] = "filePath";
  roles[MediaTypeRole] = "mediaType";
  roles[MediaWidthRole] = "mediaWidth";
  roles[MediaHeightRole] = "mediaHeight";
  roles[DurationRole] = "duration";
  roles[FileNameRole] = "fileName";
  roles[FileSizeRole] = "fileSize";
  roles[IsDownloadingRole] = "isDownloading";
  roles[ReplyToMessageIdRole] = "replyToMessageId";
  roles[ReplyTextRole] = "replyText";
  roles[ReplySenderRole] = "replySender";
  roles[ModelDataRole] = "modelData";
  return roles;
}

int MessageListModel::findIndexById(qint64 messageId) const {
  for (int i = 0; i < m_messages.size(); ++i) {
    if (m_messages.at(i).value(QStringLiteral("messageId")).toLongLong() == messageId) {
      return i;
    }
  }
  return -1;
}

void MessageListModel::setMessages(const QVariantList &messages) {
  beginResetModel();
  m_messages.clear();
  m_messages.reserve(messages.size());
  for (const auto &v : messages) {
    m_messages.append(v.toMap());
  }
  endResetModel();
  emit countChanged();
  emit messagesLoaded();
}

void MessageListModel::appendMessage(const QVariantMap &message) {
  const qint64 mid = message.value(QStringLiteral("messageId")).toLongLong();
  if (mid != 0) {
    const int existing = findIndexById(mid);
    if (existing >= 0) {
      m_messages[existing] = message;
      emit dataChanged(index(existing), index(existing));
      return;
    }
  }

  const int newRow = static_cast<int>(m_messages.size());
  beginInsertRows(QModelIndex(), newRow, newRow);
  m_messages.append(message);
  endInsertRows();
  emit countChanged();
  emit messageAdded(message);
}

void MessageListModel::replaceMessageId(qint64 oldId, const QVariantMap &message) {
  const int idx = findIndexById(oldId);
  if (idx >= 0) {
    m_messages[idx] = message;
    emit dataChanged(index(idx), index(idx));
  } else {
    appendMessage(message);
  }
}

void MessageListModel::updateReadOutbox(qint64 lastReadId) {
  for (int i = 0; i < m_messages.size(); ++i) {
    auto &msg = m_messages[i];
    if (msg.value(QStringLiteral("outgoing")).toBool() &&
        msg.value(QStringLiteral("messageId")).toLongLong() <= lastReadId &&
        msg.value(QStringLiteral("status")).toString() != QStringLiteral("✓✓")) {
      msg[QStringLiteral("status")] = QStringLiteral("✓✓");
      emit dataChanged(index(i), index(i), {StatusRole, ModelDataRole});
    }
  }
}

void MessageListModel::updateMessageFile(qint64 messageId, const QString &filePath) {
  const int idx = findIndexById(messageId);
  if (idx >= 0) {
    m_messages[idx][QStringLiteral("filePath")] = filePath;
    m_messages[idx][QStringLiteral("isDownloading")] = false;
    emit dataChanged(index(idx), index(idx), {FilePathRole, IsDownloadingRole, ModelDataRole});
  }
}

void MessageListModel::clear() {
  if (m_messages.isEmpty()) return;
  beginResetModel();
  m_messages.clear();
  endResetModel();
  emit countChanged();
}

QVariantMap MessageListModel::get(int index) const {
  if (index < 0 || index >= m_messages.size()) {
    return {};
  }
  return m_messages.at(index);
}

QVariantMap MessageListModel::getByMessageId(qint64 messageId) const {
  const int idx = findIndexById(messageId);
  if (idx < 0) return {};
  return m_messages.at(idx);
}
