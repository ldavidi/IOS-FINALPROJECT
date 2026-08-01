// FirebaseManager.swift
// Barbershop Booking App

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging

class FirebaseManager {

    // MARK: - Singleton
    static let shared = FirebaseManager()
    private init() {}

    private let db = Firestore.firestore()

    // MARK: - Collections
    private let usersCollection        = "users"
    private let appointmentsCollection = "appointments"
    private let blockedSlotsCollection = "blockedSlots"

    // MARK: - Current User Cache
    var currentUser: AppUser?

    // ─────────────────────────────────────────────
    // MARK: - Authentication
    // ─────────────────────────────────────────────

    func register(name: String, phone: String, email: String, password: String,
                  isBarber: Bool = false, shopName: String? = nil,
                  latitude: Double? = nil, longitude: Double? = nil,
                  completion: @escaping (Result<AppUser, Error>) -> Void) {

        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            if let error = error { completion(.failure(error)); return }
            guard let uid = result?.user.uid else {
                completion(.failure(NSError(domain: "FirebaseManager", code: -1,
                                            userInfo: [NSLocalizedDescriptionKey: "לא התקבל UID"])))
                return
            }

            let user = AppUser(uid: uid, name: name, phone: phone, email: email,
                               isAdmin: isBarber,
                               shopName: shopName,
                               latitude: latitude, longitude: longitude)
            self.saveUser(user) { saveError in
                if let saveError = saveError {
                    completion(.failure(saveError))
                } else {
                    self.currentUser = user
                    completion(.success(user))
                }
            }
        }
    }

    func login(email: String, password: String,
               completion: @escaping (Result<AppUser, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            if let error = error { completion(.failure(error)); return }
            guard let uid = result?.user.uid else {
                completion(.failure(NSError(domain: "FirebaseManager", code: -1,
                                            userInfo: [NSLocalizedDescriptionKey: "לא התקבל UID"])))
                return
            }
            self.fetchUser(uid: uid) { userResult in
                switch userResult {
                case .success(let user):
                    self.currentUser = user
                    completion(.success(user))
                case .failure(let err):
                    completion(.failure(err))
                }
            }
        }
    }

    func logout() {
        try? Auth.auth().signOut()
        currentUser = nil
    }

    func resetPassword(email: String, completion: @escaping (Error?) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email, completion: completion)
    }

    // ─────────────────────────────────────────────
    // MARK: - Users
    // ─────────────────────────────────────────────

    func saveUser(_ user: AppUser, completion: @escaping (Error?) -> Void) {
        db.collection(usersCollection).document(user.uid)
            .setData(user.toDictionary, completion: completion)
    }

    func fetchUser(uid: String, completion: @escaping (Result<AppUser, Error>) -> Void) {
        db.collection(usersCollection).document(uid).getDocument { snapshot, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = snapshot?.data(),
                  let user = AppUser.from(dictionary: data, uid: uid) else {
                completion(.failure(NSError(domain: "User not found", code: 404)))
                return
            }
            completion(.success(user))
        }
    }

    /// שליפת כל הספרים (isAdmin = true) — לבחירת ספר קרוב
    func fetchBarbers(completion: @escaping ([AppUser]) -> Void) {
        db.collection(usersCollection)
            .whereField("isAdmin", isEqualTo: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ fetchBarbers error: \(error.localizedDescription)")
                    completion([])
                    return
                }
                let barbers = snapshot?.documents.compactMap { doc -> AppUser? in
                    AppUser.from(dictionary: doc.data(), uid: doc.documentID)
                } ?? []
                completion(barbers)
            }
    }

    func updateFCMToken(_ token: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection(usersCollection).document(uid).updateData(["fcmToken": token])
    }

    // ─────────────────────────────────────────────
    // MARK: - Appointments
    // ─────────────────────────────────────────────

    func bookAppointment(_ appointment: Appointment,
                         completion: @escaping (Result<Void, Error>) -> Void) {
        let ref = db.collection(appointmentsCollection).document(appointment.id)
        ref.setData(appointment.toDictionary) { error in
            if let error = error { completion(.failure(error)) }
            else { completion(.success(())) }
        }
    }

    func fetchAppointments(for date: Date, barberId: String? = nil,
                           completion: @escaping (Result<[Appointment], Error>) -> Void) {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        let endOfDay   = cal.date(byAdding: .day, value: 1, to: startOfDay)!

        db.collection(appointmentsCollection)
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("date", isLessThan: Timestamp(date: endOfDay))
            .getDocuments { snapshot, error in
                if let error = error { completion(.failure(error)); return }
                var appointments = (snapshot?.documents.compactMap {
                    Appointment.from(dictionary: $0.data(), id: $0.documentID)
                } ?? []).filter { $0.status == .pending || $0.status == .confirmed }

                // סינון לפי ספר אם צוין
                if let barberId = barberId, !barberId.isEmpty {
                    appointments = appointments.filter { $0.barberId == barberId }
                }
                completion(.success(appointments))
            }
    }

    func fetchUserAppointments(userId: String,
                               completion: @escaping (Result<[Appointment], Error>) -> Void) {
        db.collection(appointmentsCollection)
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error { completion(.failure(error)); return }
                let appointments = (snapshot?.documents.compactMap {
                    Appointment.from(dictionary: $0.data(), id: $0.documentID)
                } ?? []).sorted { $0.date > $1.date }
                completion(.success(appointments))
            }
    }

    func fetchAllAppointments(completion: @escaping (Result<[Appointment], Error>) -> Void) {
        db.collection(appointmentsCollection)
            .getDocuments { snapshot, error in
                if let error = error { completion(.failure(error)); return }
                let appointments = (snapshot?.documents.compactMap {
                    Appointment.from(dictionary: $0.data(), id: $0.documentID)
                } ?? []).sorted { $0.date < $1.date }
                completion(.success(appointments))
            }
    }

    /// Listener בזמן אמת — אם barberId מועבר, מציג רק תורים של אותו ספר
    func listenToAllAppointments(barberId: String? = nil,
                                 completion: @escaping ([Appointment]) -> Void) -> ListenerRegistration {
        // אם יש barberId — מסנן בשאילתה ישירות (ללא composite index)
        let query: Query
        if let barberId = barberId, !barberId.isEmpty {
            query = db.collection(appointmentsCollection)
                .whereField("barberId", isEqualTo: barberId)
        } else {
            query = db.collection(appointmentsCollection)
        }

        return query.addSnapshotListener { snapshot, error in
            if let error = error {
                print("❌ listenToAllAppointments error: \(error.localizedDescription)")
                completion([])
                return
            }
            let appointments = (snapshot?.documents.compactMap {
                Appointment.from(dictionary: $0.data(), id: $0.documentID)
            } ?? []).sorted { $0.date < $1.date }
            completion(appointments)
        }
    }

    func updateAppointmentStatus(appointmentId: String, status: AppointmentStatus,
                                 completion: @escaping (Error?) -> Void) {
        db.collection(appointmentsCollection).document(appointmentId)
            .updateData(["status": status.rawValue], completion: completion)
    }

    func cancelAppointment(appointmentId: String, completion: @escaping (Error?) -> Void) {
        updateAppointmentStatus(appointmentId: appointmentId, status: .cancelled, completion: completion)
    }

    // ─────────────────────────────────────────────
    // MARK: - Available Slots
    // ─────────────────────────────────────────────

    func fetchAvailableSlots(for date: Date, barberId: String,
                             completion: @escaping ([TimeSlot]) -> Void) {
        guard !BusinessHours.isClosedDay(date) else { completion([]); return }

        fetchAppointments(for: date, barberId: barberId) { result in
            var slots = BusinessHours.generateSlots(for: date)

            if case .success(let existing) = result {
                let bookedTimes = existing.map { $0.date }
                for i in 0..<slots.count {
                    let isBooked = bookedTimes.contains {
                        abs($0.timeIntervalSince(slots[i].time)) < 60
                    }
                    if isBooked { slots[i].isAvailable = false }
                }
            }

            let now = Date()
            slots = slots.map { var s = $0; if s.time <= now { s.isAvailable = false }; return s }
            completion(slots)
        }
    }

    // ─────────────────────────────────────────────
    // MARK: - Blocked Days
    // ─────────────────────────────────────────────

    func blockDate(_ date: Date, completion: @escaping (Error?) -> Void) {
        let cal   = Calendar.current
        let start = cal.startOfDay(for: date)
        let id    = "\(Int(start.timeIntervalSince1970))"
        db.collection(blockedSlotsCollection).document(id)
            .setData(["date": Timestamp(date: start), "fullDay": true], completion: completion)
    }

    func fetchBlockedDates(completion: @escaping ([Date]) -> Void) {
        db.collection(blockedSlotsCollection).getDocuments { snapshot, _ in
            let dates = snapshot?.documents.compactMap { doc -> Date? in
                (doc.data()["date"] as? Timestamp)?.dateValue()
            } ?? []
            completion(dates)
        }
    }
}
