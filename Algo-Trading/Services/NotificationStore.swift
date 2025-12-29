import Foundation
import Combine

class NotificationStore: ObservableObject {
    static let shared = NotificationStore()
    
    @Published var notifications: [ArgusNotification] = []
    
    private let persistenceKey = "ArgusNotificationInbox"
    
    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }
    
    private init() {
        loadNotifications()
    }
    
    func addNotification(_ notification: ArgusNotification) {
        DispatchQueue.main.async {
            // Prepend new (Newest first)
            self.notifications.insert(notification, at: 0)
            self.saveNotifications()
            
            // Also trigger local push for alert
            NotificationManager.shared.sendNotification(
                title: notification.headline,
                body: notification.summary
            )
        }
    }
    
    func markAsRead(_ notification: ArgusNotification) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            DispatchQueue.main.async {
                self.notifications[index].isRead = true
                self.saveNotifications()
            }
        }
    }
    
    func markAllRead() {
        DispatchQueue.main.async {
            for i in 0..<self.notifications.count {
                self.notifications[i].isRead = true
            }
            self.saveNotifications()
        }
    }
    
    func deleteNotification(id: UUID) {
        DispatchQueue.main.async {
            self.notifications.removeAll { $0.id == id }
            self.saveNotifications()
        }
    }
    
    private func saveNotifications() {
        if let data = try? JSONEncoder().encode(notifications) {
            UserDefaults.standard.set(data, forKey: persistenceKey)
        }
    }
    
    private func loadNotifications() {
        if let data = UserDefaults.standard.data(forKey: persistenceKey),
           let items = try? JSONDecoder().decode([ArgusNotification].self, from: data) {
            self.notifications = items
        }
    }
}
