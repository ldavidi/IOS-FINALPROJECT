// NotificationManager.swift
// Barbershop Booking App
// מנהל התראות מקומיות + FCM

import Foundation
import UserNotifications
import FirebaseMessaging

class NotificationManager {

    static let shared = NotificationManager()
    private init() {}

    // MARK: - Local Notifications

    /// שלח תזכורת לפני תור (24 שעות + 1 שעה)
    func scheduleReminder(for appointment: Appointment) {
        // תזכורת יום לפני
        scheduleLocalNotification(
            id: "reminder_24h_\(appointment.id)",
            title: "תזכורת לתור מחר 💈",
            body: "\(appointment.service.rawValue) מחר ב-\(appointment.formattedTime)",
            date: appointment.date.addingTimeInterval(-24 * 3600)
        )

        // תזכורת שעה לפני
        scheduleLocalNotification(
            id: "reminder_1h_\(appointment.id)",
            title: "התור שלך עוד שעה! ✂️",
            body: "\(appointment.service.rawValue) ב-\(appointment.formattedTime)",
            date: appointment.date.addingTimeInterval(-3600)
        )
    }

    /// בטל תזכורות עבור תור מבוטל
    func cancelReminders(for appointmentId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [
                "reminder_24h_\(appointmentId)",
                "reminder_1h_\(appointmentId)"
            ]
        )
    }

    private func scheduleLocalNotification(id: String, title: String, body: String, date: Date) {
        guard date > Date() else { return } // אל תשלח אם הזמן עבר

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ Notification error: \(error)")
            }
        }
    }

    // MARK: - Handle Tap

    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        // כאן אפשר לנווט למסך הרלוונטי בהתאם לתוכן ה-notification
        if let appointmentId = userInfo["appointmentId"] as? String {
            print("📲 Tapped notification for appointment: \(appointmentId)")
            NotificationCenter.default.post(
                name: .didTapAppointmentNotification,
                object: nil,
                userInfo: ["appointmentId": appointmentId]
            )
        }
    }

    // MARK: - Send Push via Cloud Function
    // (דורש Firebase Cloud Functions — קוד Node.js לדוגמה מופיע ב-README)

    /// שלח Push ל-Admin כשנקבע תור חדש
    func notifyAdminNewAppointment(_ appointment: Appointment) {
        // הפעל Cloud Function או שלח ישירות דרך FCM REST API
        // ראה הוראות ב-README
        print("🔔 Should notify admin about new appointment: \(appointment.id)")
    }

    /// שלח Push למשתמש כשהתור אושר
    func notifyUserAppointmentConfirmed(_ appointment: Appointment, userFCMToken: String) {
        // ראה הוראות ב-README
        print("🔔 Should notify user \(userFCMToken) that appointment was confirmed")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let didTapAppointmentNotification = Notification.Name("didTapAppointmentNotification")
}
