// BookingViewController.swift
// Barbershop Booking App
//
// Storyboard ID: "BookingVC"
// חבר ב-Storyboard:
//   - calendarCollectionView  → UICollectionView (ימי החודש)
//   - monthLabel              → UILabel ("יולי 2026")
//   - prevMonthButton         → UIButton (<)
//   - nextMonthButton         → UIButton (>)
//   - timeSlotsCollectionView → UICollectionView (שעות)
//   - servicePickerView       → UIPickerView
//   - confirmButton           → UIButton ("אישור תור")
//   - activityIndicator       → UIActivityIndicatorView

import UIKit

@objc(BookingViewController)
class BookingViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var monthLabel: UILabel!
    @IBOutlet weak var prevMonthButton: UIButton!
    @IBOutlet weak var nextMonthButton: UIButton!
    @IBOutlet weak var calendarCollectionView: UICollectionView!
    @IBOutlet weak var timeSlotsCollectionView: UICollectionView!
    @IBOutlet weak var servicePickerView: UIPickerView!
    @IBOutlet weak var confirmButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var selectedDateLabel: UILabel!
    @IBOutlet weak var selectedTimeLabel: UILabel!

    // MARK: - State
    var selectedBarber: AppUser?   // מוגדר ע"י HomeVC לפני push

    private var currentMonth: Date = {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: Date())
        return calendar.date(from: comps) ?? Date()
    }()

    private var calendarDays: [CalendarDay] = []
    private var timeSlots: [TimeSlot] = []
    private var selectedDate: Date?
    private var selectedTimeSlot: TimeSlot?
    private var selectedService: ServiceType = .haircut
    private var blockedDates: [Date] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        // מציג שם הספר/מספרה בכותרת
        title = selectedBarber.map { $0.shopName ?? $0.name } ?? "קביעת תור"
        setupUI()
        setupCollectionViews()
        setupPickerView()
        loadBlockedDates()
        generateCalendar()
    }

    // MARK: - Setup

    private func setupUI() {
        view.semanticContentAttribute = .forceRightToLeft
        navigationController?.navigationBar.prefersLargeTitles = false

        // תיקון month label — צבע ורקע מפורש כדי לא לתלות בסטוריבורד
        monthLabel.textColor = .label
        monthLabel.backgroundColor = .clear
        monthLabel.textAlignment = .center
        monthLabel.font = .systemFont(ofSize: 18, weight: .semibold)

        confirmButton.layer.cornerRadius = 25
        confirmButton.clipsToBounds = true
        confirmButton.isEnabled = false
        confirmButton.alpha = 0.5

        selectedDateLabel.text = "בחר תאריך"
        selectedDateLabel.textColor = .secondaryLabel
        selectedTimeLabel.text = ""
    }

    private func setupCollectionViews() {
        // Calendar
        calendarCollectionView.delegate = self
        calendarCollectionView.dataSource = self
        calendarCollectionView.register(CalendarDayCell.self, forCellWithReuseIdentifier: CalendarDayCell.identifier)
        calendarCollectionView.backgroundColor = .clear

        // Time Slots
        timeSlotsCollectionView.delegate = self
        timeSlotsCollectionView.dataSource = self
        timeSlotsCollectionView.register(TimeSlotCell.self, forCellWithReuseIdentifier: TimeSlotCell.identifier)
        timeSlotsCollectionView.backgroundColor = .clear

        let calendarLayout = UICollectionViewFlowLayout()
        calendarLayout.scrollDirection = .vertical
        let width = (UIScreen.main.bounds.width - 48) / 7
        calendarLayout.itemSize = CGSize(width: width, height: width)
        calendarLayout.minimumInteritemSpacing = 0
        calendarLayout.minimumLineSpacing = 4
        calendarCollectionView.collectionViewLayout = calendarLayout

        let slotLayout = UICollectionViewFlowLayout()
        slotLayout.scrollDirection = .horizontal
        slotLayout.itemSize = CGSize(width: 80, height: 44)
        slotLayout.minimumInteritemSpacing = 8
        timeSlotsCollectionView.collectionViewLayout = slotLayout
    }

    private func setupPickerView() {
        servicePickerView.delegate = self
        servicePickerView.dataSource = self
    }

    // MARK: - Calendar Logic

    private func generateCalendar() {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "he_IL")
        formatter.dateFormat = "MMMM yyyy"
        monthLabel.text = formatter.string(from: currentMonth)

        var days: [CalendarDay] = []
        let range = calendar.range(of: .day, in: .month, for: currentMonth)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!

        // יום ראשון בחודש נופל על איזה יום בשבוע?
        // בישראל: א=1, ב=2, ..., ש=7
        var weekday = calendar.component(.weekday, from: firstDay)
        weekday = weekday - 1 // adjust for Sunday start
        if weekday < 0 { weekday = 6 }

        // תאים ריקים לפני תחילת החודש
        for _ in 0..<weekday {
            days.append(CalendarDay(date: nil, isAvailable: false, isSelected: false, isPast: false))
        }

        let today = calendar.startOfDay(for: Date())

        for day in 1...range.count {
            var comps = calendar.dateComponents([.year, .month], from: currentMonth)
            comps.day = day
            guard let date = calendar.date(from: comps) else { continue }

            let isPast = date < today
            let isSaturday = BusinessHours.isClosedDay(date)
            let isBlocked = blockedDates.contains { calendar.isDate($0, inSameDayAs: date) }
            let isAvailable = !isPast && !isSaturday && !isBlocked

            days.append(CalendarDay(
                date: date,
                isAvailable: isAvailable,
                isSelected: selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false,
                isPast: isPast || isSaturday || isBlocked
            ))
        }

        calendarDays = days
        calendarCollectionView.reloadData()
    }

    private func loadBlockedDates() {
        FirebaseManager.shared.fetchBlockedDates { [weak self] dates in
            DispatchQueue.main.async {
                self?.blockedDates = dates
                self?.generateCalendar()
            }
        }
    }

    private func selectDate(_ date: Date) {
        selectedDate = date
        selectedTimeSlot = nil
        selectedTimeLabel.text = ""
        updateConfirmButton()

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "he_IL")
        formatter.dateFormat = "EEEE, d MMMM"
        selectedDateLabel.text = formatter.string(from: date)

        generateCalendar()
        loadTimeSlotsForDate(date)
    }

    private func loadTimeSlotsForDate(_ date: Date) {
        setLoading(true)
        let barberId = selectedBarber?.uid ?? ""
        FirebaseManager.shared.fetchAvailableSlots(for: date, barberId: barberId) { [weak self] slots in
            DispatchQueue.main.async {
                self?.setLoading(false)
                self?.timeSlots = slots
                self?.timeSlotsCollectionView.reloadData()
            }
        }
    }

    private func updateConfirmButton() {
        let canBook = selectedDate != nil && selectedTimeSlot != nil
        confirmButton.isEnabled = canBook
        confirmButton.alpha = canBook ? 1.0 : 0.5
    }

    // MARK: - IBActions

    @IBAction func prevMonthTapped(_ sender: UIButton) {
        let calendar = Calendar.current
        if let prev = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            let today = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
            if prev >= today {
                currentMonth = prev
                generateCalendar()
            }
        }
    }

    @IBAction func nextMonthTapped(_ sender: UIButton) {
        let calendar = Calendar.current
        if let next = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = next
            generateCalendar()
        }
    }

    @IBAction func confirmButtonTapped(_ sender: UIButton) {
        guard
            let user = FirebaseManager.shared.currentUser,
            let slot = selectedTimeSlot,
            slot.isAvailable
        else {
            showAlert(title: "שגיאה", message: "אנא בחר תאריך ושעה")
            return
        }

        let appointment = Appointment(
            userId: user.uid,
            userName: user.name,
            userPhone: user.phone,
            service: selectedService,
            date: slot.time,
            barberId: selectedBarber?.uid ?? "",
            barberName: selectedBarber.map { $0.shopName ?? $0.name } ?? ""
        )

        setLoading(true)

        FirebaseManager.shared.bookAppointment(appointment) { [weak self] result in
            DispatchQueue.main.async {
                self?.setLoading(false)
                switch result {
                case .success:
                    self?.showSuccessAndPop(appointment: appointment)
                case .failure(let error):
                    self?.showAlert(title: "שגיאה בקביעת התור", message: error.localizedDescription)
                }
            }
        }
    }

    private func showSuccessAndPop(appointment: Appointment) {
        let alert = UIAlertController(
            title: "✅ התור נקבע!",
            message: "\(appointment.service.rawValue)\n\(appointment.formattedDate)\nשעה \(appointment.formattedTime)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "אישור", style: .default) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    // MARK: - Helpers

    private func setLoading(_ loading: Bool) {
        activityIndicator.isHidden = !loading
        if loading { activityIndicator.startAnimating() }
        else { activityIndicator.stopAnimating() }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "אישור", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UICollectionViewDataSource & Delegate

extension BookingViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == calendarCollectionView {
            return calendarDays.count
        }
        return timeSlots.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == calendarCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CalendarDayCell.identifier, for: indexPath) as! CalendarDayCell
            cell.configure(with: calendarDays[indexPath.item])
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TimeSlotCell.identifier, for: indexPath) as! TimeSlotCell
            let slot = timeSlots[indexPath.item]
            let isSelected = selectedTimeSlot.map { $0.time == slot.time } ?? false
            cell.configure(with: slot, isSelected: isSelected)
            return cell
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == calendarCollectionView {
            let day = calendarDays[indexPath.item]
            guard let date = day.date, day.isAvailable else { return }
            selectDate(date)
        } else {
            let slot = timeSlots[indexPath.item]
            guard slot.isAvailable else { return }
            selectedTimeSlot = slot
            selectedTimeLabel.text = "שעה \(slot.formattedTime)"
            updateConfirmButton()
            timeSlotsCollectionView.reloadData()
        }
    }
}

// MARK: - UIPickerViewDelegate & DataSource

extension BookingViewController: UIPickerViewDelegate, UIPickerViewDataSource {

    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return ServiceType.allCases.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        let service = ServiceType.allCases[row]
        return "\(service.rawValue) – ₪\(service.price)"
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedService = ServiceType.allCases[row]
    }
}

// MARK: - CalendarDay Model

struct CalendarDay {
    var date: Date?
    var isAvailable: Bool
    var isSelected: Bool
    var isPast: Bool
}

// MARK: - CalendarDayCell

class CalendarDayCell: UICollectionViewCell {

    static let identifier = "CalendarDayCell"

    private let dayLabel = UILabel()
    private let dot = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupCell() {
        layer.cornerRadius = min(bounds.width, bounds.height) / 2
        clipsToBounds = true

        dayLabel.translatesAutoresizingMaskIntoConstraints = false
        dayLabel.textAlignment = .center
        dayLabel.font = .systemFont(ofSize: 15, weight: .medium)
        contentView.addSubview(dayLabel)

        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.layer.cornerRadius = 3
        dot.backgroundColor = .systemRed
        contentView.addSubview(dot)

        NSLayoutConstraint.activate([
            dayLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            dayLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -4),
            dot.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            dot.topAnchor.constraint(equalTo: dayLabel.bottomAnchor, constant: 2),
            dot.widthAnchor.constraint(equalToConstant: 6),
            dot.heightAnchor.constraint(equalToConstant: 6)
        ])
    }

    func configure(with day: CalendarDay) {
        guard let date = day.date else {
            dayLabel.text = ""
            dot.isHidden = true
            backgroundColor = .clear
            return
        }

        let calendar = Calendar.current
        dayLabel.text = "\(calendar.component(.day, from: date))"

        if day.isSelected {
            backgroundColor = .label
            dayLabel.textColor = .systemBackground
            dot.isHidden = true
        } else if day.isAvailable {
            backgroundColor = .systemRed.withAlphaComponent(0.12)
            dayLabel.textColor = .systemRed
            dot.isHidden = false
            dot.backgroundColor = .systemRed
        } else {
            backgroundColor = .clear
            dayLabel.textColor = .tertiaryLabel
            dot.isHidden = true
        }
    }
}

// MARK: - TimeSlotCell

class TimeSlotCell: UICollectionViewCell {

    static let identifier = "TimeSlotCell"

    private let timeLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 12
        clipsToBounds = true

        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.textAlignment = .center
        timeLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        contentView.addSubview(timeLabel)

        NSLayoutConstraint.activate([
            timeLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            timeLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(with slot: TimeSlot, isSelected: Bool) {
        timeLabel.text = slot.formattedTime

        if isSelected {
            backgroundColor = .label
            timeLabel.textColor = .systemBackground
        } else if slot.isAvailable {
            backgroundColor = .secondarySystemBackground
            timeLabel.textColor = .label
        } else {
            backgroundColor = .systemGray6
            timeLabel.textColor = .tertiaryLabel
        }
    }
}
