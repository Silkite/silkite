#pragma once

#include <QAbstractListModel>
#include <QVariantList>
#include <QVariantMap>

class MessageListModel : public QAbstractListModel {
  Q_OBJECT
  Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
  enum MessageRoles {
    MessageIdRole = Qt::UserRole + 1,
    TextRole,
    CaptionRole,
    TimeRole,
    OutgoingRole,
    StatusRole,
    FilePathRole,
    MediaTypeRole,
    MediaWidthRole,
    MediaHeightRole,
    DurationRole,
    FileNameRole,
    FileSizeRole,
    IsDownloadingRole,
    ReplyToMessageIdRole,
    ReplyTextRole,
    ReplySenderRole,
    ReactionsRole,
    IsSingleEmojiRole,
    ModelDataRole // Returns the full QVariantMap for backwards compatibility
  };
  Q_ENUM(MessageRoles)

  explicit MessageListModel(QObject *parent = nullptr);
  ~MessageListModel() override = default;

  int rowCount(const QModelIndex &parent = QModelIndex()) const override;
  QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
  QHash<int, QByteArray> roleNames() const override;

  int count() const { return static_cast<int>(m_messages.size()); }

  void setMessages(const QVariantList &messages);
  void appendMessage(const QVariantMap &message);
  void replaceMessageId(qint64 oldId, const QVariantMap &message);
  void updateReadOutbox(qint64 lastReadId);
  void updateMessageFile(qint64 messageId, const QString &filePath);
  void updateMessageReactions(qint64 messageId, const QVariantList &reactions);
  Q_INVOKABLE void toggleReactionOptimistic(qint64 messageId, const QString &emoji);
  void clear();

  Q_INVOKABLE QVariantMap get(int index) const;
  Q_INVOKABLE QVariantMap getByMessageId(qint64 messageId) const;

signals:
  void countChanged();
  void messagesLoaded();
  void messageAdded(const QVariantMap &message);

private:
  int findIndexById(qint64 messageId) const;

  QList<QVariantMap> m_messages;
};
