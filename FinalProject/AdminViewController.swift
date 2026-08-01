// AdminViewController.swift
// Barbershop Booking App
//
// Storyboard ID: "AdminVC"
// חבר ב-Storyboard:
//   - tableView      → UITableView
//   - segmentedControl → UISegmentedControl ("הכל" / "היום" / "ממתינים")
//   - datePicker     → UIDatePicker (לחסימת ימים)

import UIKit
import FirebaseFirestore

@objc(AdminViewController)
class AdminViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!

    // MARK: - Data
    private var allAppointments: [Appointment] = []
    private var filteredAppointments: [Appointment] = []
    private var listener: ListenerRegistration?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "ניהול תורים"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "calendar.badge.exclamationmark"),
            style: .plain,
            target: self,
            action: #selector(blockDayTapped)
        )
        setupTableView()
        startListening()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        listener?.remove()
    }

    // MARK: - Setup

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(AdminAppointmentCell.self,
                           forCellReuseIdentifier: AdminAppointmentCell.identifier)
        tableView.separatorStyle = .none
        tableView.backgroundColor = .systemGroupedBackground
    }

    // MARK: - Firebase Listener (זמן אמת)

    private func startListening() {
        // כל ספר רואה רק את התורים שלו
        let myId = FirebaseManager.shared.currentUser?.uid
        listener = FirebaseManager.shared.listenToAllAppointments(barberId: myId) { [weak self] appointments in
            DispatchQueue.main.async {
                self?.allAppointments = appointments
                self?.applyFilter()
            }
        }
    }

    // MARK: - Filtering

    private func applyFilter() {
        let index = segmentedControl?.selectedSegmentIndex ?? 0
        switch index {
        case 0: // הכל
            filteredAppointments = allAppointments
        case 1: // היום
            let calendar = Calendar.current
            filteredAppointments = allAppointments.filter {
                calendar.isDateInToday($0.date)
            }
        case 2: // ממתינים
            filteredAppointments = allAppointments.filter {
                $0.status == .pending
            }
        default:
            filteredAppointments = allAppointments
        }
        tableView.reloadData()
        updateEmptyState()
    }

    private func updateEmptyState() {
        if filteredAppointments.isEmpty {
            let label = UILabel()
            label.text = "אין תורים להצגה"
            label.textAlignment = .center
            label.textColor = .secondaryLabel
            label.font = .systemFont(ofSize: 16)
            tableView.backgroundView = label
        } else {
            tableView.backgroundView = nil
        }
    }

    // MARK: - IBActions

    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        applyFilter()
    }

    @objc private func blockDayTapped() {
        let alert = UIAlertController(title: "חסימת יום", message: "בחר תאריך לחסימה", preferredStyle: .alert)

        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .date
        datePicker.minimumDate = Date()
        datePicker.preferredDatePickerStyle = .wheels
        datePicker.locale = Locale(identifier: "he_IL")
        alert.view.addSubview(datePicker)

        // מרווח לתצוגת DatePicker
        let height: NSLayoutConstraint = NSLayoutConstraint(item: alert.view!, attribute: .height, relatedBy: .equal,
                                                             toItem: nil, attribute: .notAnAttribute,
                                                             multiplier: 1, constant: 320)
        alert.view.addConstraint(height)
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            datePicker.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 60),
            datePicker.leadingAnchor.constraint(equalTo: alert.view.leadingAnchor, constant: 8),
            datePicker.trailingAnchor.constraint(equalTo: alert.view.trailingAnchor, constant: -8)
        ])

        alert.addAction(UIAlertAction(title: "חסום", style: .destructive) { _ in
            FirebaseManager.shared.blockDate(datePicker.date) { error in
                DispatchQueue.main.async {
                    if error == nil {
                        self.showAlert(title: "✅ היום נחסם", message: "")
                    }
                }
            }
        })
        alert.addAction(UIAlertAction(title: "ביטול", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Appointment Actions

    private func confirmAppointment(_ appointment: Appointment) {
        FirebaseManager.shared.updateAppointmentStatus(appointmentId: appointment.id, status: .confirmed) { [weak self] error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.showAlert(title: "שגיאה", message: error.localizedDescription)
                }
            }
            // ה-Listener יעדכן את הטבלה אוטומטית
        }
    }

    private func cancelAppointment(_ appointment: Appointment) {
        let alert = UIAlertController(title: "ביטול תור",
                                      message: "האם לבטל את התור של \(appointment.userName)?",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "בטל תור", style: .destructive) { [weak self] _ in
            FirebaseManager.shared.cancelAppointment(appointmentId: appointment.id) { _ in }
        })
        alert.addAction(UIAlertAction(title: "חזור", style: .cancel))
        present(alert, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "אישור", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource & Delegate

extension AdminViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredAppointments.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AdminAppointmentCell.identifier, for: indexPath) as! AdminAppointmentCell
        cell.configure(with: filteredAppointments[indexPath.row])
        cell.onConfirm = { [weak self] in
            self?.confirmAppointment(self!.filteredAppointments[indexPath.row])
        }
        cell.onCancel = { [weak self] in
            self?.cancelAppointment(self!.filteredAppointments[indexPath.row])
        }
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 110 }
}

// MARK: - AdminAppointmentCell

class AdminAppointmentCell: UITableViewCell {

    static let identifier = "AdminAppointmentCell"

    var onConfirm: (() -> Void)?
    var onCancel: (() -> Void)?

    private let containerView = UIView()
    private let nameLabel = UILabel()
    private let phoneLabel = UILabel()
    private let serviceLabel = UILabel()
    private let dateTimeLabel = UILabel()
    private let statusLabel = UILabel()
    private let confirmButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupCell() {
        backgroundColor = .systemGroupedBackground
        selectionStyle = .none

        containerView.backgroundColor = .secondarySystemGroupedBackground
        containerView.layer.cornerRadius = 16
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)

        [nameLabel, phoneLabel, serviceLabel, dateTimeLabel, statusLabel, confirmButton, cancelButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview($0)
        }

        nameLabel.font = .systemFont(ofSize: 16, weight: .bold)
        phoneLabel.font = .systemFont(ofSize: 13)
        phoneLabel.textColor = .secondaryLabel
        serviceLabel.font = .systemFont(ofSize: 13, weight: .medium)
        dateTimeLabel.font = .systemFont(ofSize: 13)
        dateTimeLabel.textColor = .secondaryLabel

        statusLabel.font = .systemFont(ofSize: 11, weight: .bold)
        statusLabel.layer.cornerRadius = 8
        statusLabel.clipsToBounds = true
        statusLabel.textAlignment = .center

        confirmButton.setTitle("אישור ✓", for: .normal)
        confirmButton.backgroundColor = .systemGreen.withAlphaComponent(0.15)
        confirmButton.setTitleColor(.systemGreen, for: .normal)
        confirmButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        confirmButton.layer.cornerRadius = 10
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)

        cancelButton.setTitle("ביטול ✕", for: .normal)
        cancelButton.backgroundColor = .systemRed.withAlphaComponent(0.10)
        cancelButton.setTitleColor(.systemRed, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        cancelButton.layer.cornerRadius = 10
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            statusLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            statusLabel.widthAnchor.constraint(equalToConstant: 65),
            statusLabel.heightAnchor.constraint(equalToConstant: 22),

            phoneLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            phoneLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            serviceLabel.topAnchor.constraint(equalTo: phoneLabel.bottomAnchor, constant: 2),
            serviceLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            dateTimeLabel.centerYAnchor.constraint(equalTo: serviceLabel.centerYAnchor),
            dateTimeLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),

            confirmButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10),
            confirmButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            confirmButton.widthAnchor.constraint(equalToConstant: 80),
            confirmButton.heightAnchor.constraint(equalToConstant: 30),

            cancelButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10),
            cancelButton.trailingAnchor.constraint(equalTo: confirmButton.leadingAnchor, constant: -8),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),
            cancelButton.heightAnchor.constraint(equalToConstant: 30),
        ])
    }

    @objc private func confirmTapped() { onConfirm?() }
    @objc private func cancelTapped() { onCancel?() }

    func configure(with appointment: Appointment) {
        nameLabel.text = appointment.userName
        phoneLabel.text = appointment.userPhone
        serviceLabel.text = appointment.service.rawValue
        dateTimeLabel.text = "\(appointment.formattedDate) | \(appointment.formattedTime)"

        switch appointment.status {
        case .pending:
            statusLabel.text = "ממתין"
            statusLabel.backgroundColor = .systemOrange.withAlphaComponent(0.15)
            statusLabel.textColor = .systemOrange
            confirmButton.isHidden = false
            cancelButton.isHidden = false
        case .confirmed:
            statusLabel.text = "מאושר"
            statusLabel.backgroundColor = .systemGreen.withAlphaComponent(0.15)
            statusLabel.textColor = .systemGreen
            confirmButton.isHidden = true
            cancelButton.isHidden = false
        case .cancelled:
            statusLabel.text = "בוטל"
            statusLabel.backgroundColor = .systemRed.withAlphaComponent(0.15)
            statusLabel.textColor = .systemRed
            confirmButton.isHidden = true
            cancelButton.isHidden = true
        case .completed:
            statusLabel.text = "הושלם"
            statusLabel.backgroundColor = .systemGray.withAlphaComponent(0.15)
            statusLabel.textColor = .systemGray
            confirmButton.isHidden = true
            cancelButton.isHidden = true
        }
    }
}
