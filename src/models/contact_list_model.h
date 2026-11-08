#pragma once

#include <QAbstractListModel>
#include <QString>
#include <QVector>
#include <QVariantMap>

struct ContactItem {
  qint64 userId = 0;
  qint64 chatId = 0;
  QString firstName;
  QString lastName;
  QString fullName;
  QString phoneNumber;
  QString statusText;
  bool isOnline = false;
  qint64 lastSeenSecs = 0; // used for sorting (online > recently > timestamp > offline)
  QString initials;
  QString avatarColor;
  QString avatarPath;
  bool hasChatHistory = false; // true if chat has lastMessage != null/empty
};

class ContactListModel : public QAbstractListModel {
  Q_OBJECT

  Q_PROPERTY(QString filterText READ filterText WRITE setFilterText NOTIFY filterTextChanged)
  Q_PROPERTY(int contactCount READ rowCount NOTIFY countChanged)

public:
  enum ContactRoles {
    UserIdRole = Qt::UserRole + 1,
    ChatIdRole,
    FirstNameRole,
    LastNameRole,
    FullNameRole,
    PhoneNumberRole,
    StatusTextRole,
    IsOnlineRole,
    InitialsRole,
    AvatarColorRole,
    AvatarPathRole,
    LastSeenSecsRole
  };

  explicit ContactListModel(QObject *parent = nullptr);

  int rowCount(const QModelIndex &parent = QModelIndex()) const override;
  QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
  QHash<int, QByteArray> roleNames() const override;

  QString filterText() const { return m_filterText; }
  void setFilterText(const QString &text);

  Q_INVOKABLE QVariantMap contactAt(int row) const;
  Q_INVOKABLE QVariantMap contactByUserId(qint64 userId) const;

public slots:
  void clearContacts();
  void upsertContact(const QVariantMap &contactData);
  void updateContactStatus(qint64 userId, const QString &statusText, bool isOnline, qint64 lastSeenSecs);
  void updateContactAvatar(qint64 userId, const QString &avatarPath);
  void setContactHasChatHistory(qint64 userId, qint64 chatId, bool hasHistory);
  void removeContact(qint64 userId);

signals:
  void filterTextChanged();
  void countChanged();

private:
  void updateFilter();
  int findContactIndex(qint64 userId) const;

  QVector<ContactItem> m_contacts;
  QVector<int> m_filteredIndices;
  QString m_filterText;
};
