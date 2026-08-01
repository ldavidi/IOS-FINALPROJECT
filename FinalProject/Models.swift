// Models.swift
// Barbershop Booking App

import Foundation
import FirebaseFirestore

// MARK: - User Model

struct AppUser: Codable {
    var uid: String
    var name: String
    var phone: String
    var email: String
    var isAdmin: Bool           // true = ספר/אדמין
    var fcmToken: String?
    var shopName: String?       // שם העסק (לספרים בלבד)
    var latitude: Double?       // מיקום המספרה
    var longitude: Double?

    // computed — לא נשמר ב-Firestore, מחושב לאחר שליפה
    var distanceKm: Double?

    init(uid: String, name: String, phone: String, email: String,
         isAdmin: Bool = false, fcmToken: String? = nil,
         shopName: String? = nil, latitude: Double? = nil, longitude: Double? = nil) {
        self.uid = uid
        self.name = name
        self.phone = phone
        self.email = email
        self.isAdmin = isAdmin
        self.fcmToken = fcmToken
        self.shopName = shopName
        self.latitude = latitude
        self.longitude = longitude
    }

    var displayName: String { shopName ?? name }

    var toDictionary: [String: Any] {
        var dict: [String: Any] = [
            "uid": uid,
            "name": name,
            "phone": phone,
            "email": email,
            "isAdmin": isAdmin,
            "fcmToken": fcmToken ?? ""
        ]
        if let shopName  { dict["shopName"]  = shopName }
        if let latitude  { dict["latitude"]  = latitude }
        if let longitude { dict["longitude"] = longitude }
        return dict
    }

    static func from(dictionary: [String: Any], uid: String) -> AppUser? {
        guard
            let name  = dictionary["name"]  as? String,
            let phone = dictionary["phone"] as? String,
            let email = dictionary["email"] as? String
        else { return nil }

        return AppUser(
            uid: uid,
            name: name,
            phone: phone,
            email: email,
            isAdmin:   dictionary["isAdmin"]   as? Bool   ?? false,
            fcmToken:  dictionary["fcmToken"]  as? String,
            shopName:  dictionary["shopName"]  as? String,
            latitude:  parseDouble(dictionary["latitude"]),
            longitude: parseDouble(dictionary["longitude"])
        )
    }

    /// Firestore שומר מספרים גם כ-Int64 וגם כ-Double — טיפול בשניהם
    private static func parseDouble(_ value: Any?) -> Double? {
        if let d = value as? Double  { return d }
        if let i = value as? Int     { return Double(i) }
        if let i = value as? Int64   { return Double(i) }
        return nil
    }
}

// MARK: - Appointment Status

enum AppointmentStatus: String, Codable {
    case pending   = "pending"    // ממתין לאישור
    case confirmed = "confirmed"  // מאושר
    case cancelled = "cancelled"  // בוטל
    case completed = "completed"  // הושלם
}

// MARK: - Service Type

enum ServiceType: String, Codable, CaseIterable {
    case haircut        = "תספורת"
    case beard          = "זקן"
    case haircutAndBeard = "תספורת + זקן"
    case fade           = "פייד"
    case kidHaircut     = "תספורת ילדים"

    var durationMinutes: Int {
        switch self {
        case .haircut:         return 30
        case .beard:           return 20
        case .haircutAndBeard: return 45
        case .fade:            return 40
        case .kidHaircut:      return 20
        }
    }

    var price: Int {
        switch self {
        case .haircut:         return 60
        case .beard:           return 40
        case .haircutAndBeard: return 90
        case .fade:            return 70
        case .kidHaircut:      return 50
        }
    }
}

// MARK: - Appointment Model

struct Appointment: Identifiable {
    var id: String
    var userId: String
    var userName: String
    var userPhone: String
    var service: ServiceType
    var date: Date
    var status: AppointmentStatus
    var notes: String?
    var createdAt: Date
    var barberId: String    // uid של הספר
    var barberName: String  // שם הספר / העסק

    init(id: String = UUID().uuidString,
         userId: String,
         userName: String,
         userPhone: String,
         service: ServiceType,
         date: Date,
         status: AppointmentStatus = .pending,
         notes: String? = nil,
         createdAt: Date = Date(),
         barberId: String = "",
         barberName: String = "") {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.userPhone = userPhone
        self.service = service
        self.date = date
        self.status = status
        self.notes = notes
        self.createdAt = createdAt
        self.barberId = barberId
        self.barberName = barberName
    }

    var toDictionary: [String: Any] {
        return [
            "id":          id,
            "userId":      userId,
            "userName":    userName,
            "userPhone":   userPhone,
            "service":     service.rawValue,
            "date":        Timestamp(date: date),
            "status":      status.rawValue,
            "notes":       notes ?? "",
            "createdAt":   Timestamp(date: createdAt),
            "barberId":    barberId,
            "barberName":  barberName
        ]
    }

    static func from(dictionary: [String: Any], id: String) -> Appointment? {
        guard
            let userId      = dictionary["userId"]    as? String,
            let userName    = dictionary["userName"]  as? String,
            let userPhone   = dictionary["userPhone"] as? String,
            let serviceRaw  = dictionary["service"]   as? String,
            let service     = ServiceType(rawValue: serviceRaw),
            let dateTS      = dictionary["date"]      as? Timestamp,
            let statusRaw   = dictionary["status"]    as? String,
            let status      = AppointmentStatus(rawValue: statusRaw),
            let createdTS   = dictionary["createdAt"] as? Timestamp
        else { return nil }

        return Appointment(
            id:          id,
            userId:      userId,
            userName:    userName,
            userPhone:   userPhone,
            service:     service,
            date:        dateTS.dateValue(),
            status:      status,
            notes:       dictionary["notes"]      as? String,
            createdAt:   createdTS.dateValue(),
            barberId:    dictionary["barberId"]   as? String ?? "",
            barberName:  dictionary["barberName"] as? String ?? ""
        )
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "he_IL")
        f.dateFormat = "EEEE, d MMMM"
        return f.string(from: date)
    }

    var formattedTime: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "he_IL")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Available Time Slot

struct TimeSlot {
    var time: Date
    var isAvailable: Bool

    var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: time)
    }
}

// MARK: - Business Hours

struct BusinessHours {
    static let openHour    = 9
    static let closeHour   = 19
    static let slotInterval = 30

    static func isClosedDay(_ date: Date) -> Bool {
        let cal = Calendar(identifier: .hebrew)
        return cal.component(.weekday, from: date) == 7 // שבת
    }

    static func generateSlots(for date: Date) -> [TimeSlot] {
        var slots: [TimeSlot] = []
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: date)
        comps.hour   = openHour
        comps.minute = 0
        comps.second = 0
        guard var slotDate = cal.date(from: comps),
              let closeDate = cal.date(bySettingHour: closeHour, minute: 0, second: 0, of: date)
        else { return [] }

        while slotDate < closeDate {
            slots.append(TimeSlot(time: slotDate, isAvailable: true))
            slotDate = cal.date(byAdding: .minute, value: slotInterval, to: slotDate) ?? slotDate
        }
        return slots
    }
}
