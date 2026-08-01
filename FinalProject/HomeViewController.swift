// HomeViewController.swift
// Barbershop Booking App
//
// Storyboard ID: "HomeVC"
// חבר ב-Storyboard:
//   - welcomeLabel        → UILabel  ("אהלן [שם], שמחים שחזרת")
//   - bookButton          → UIButton ("לחץ לקביעת תור")
//   - myAppointmentsButton→ UIButton
//   - adminButton         → UIButton (מוסתר למשתמש רגיל)
//   - heroImageView       → UIImageView (תמונת הברבר)
//   - appointmentsTableView → UITableView (תורים קרובים)
//   - emptyStateLabel     → UILabel

import UIKit
import FirebaseAuth

@objc(HomeViewController)
class HomeViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var welcomeLabel: UILabel!
    @IBOutlet weak var bookButton: UIButton!
    @IBOutlet weak var myAppointmentsButton: UIButton!
    @IBOutlet weak var adminButton: UIButton!
    @IBOutlet weak var heroImageView: UIImageView!
    @IBOutlet weak var appointmentsTableView: UITableView!
    @IBOutlet weak var emptyStateLabel: UILabel!

    // MARK: - Data
    private var upcomingAppointments: [Appointment] = []
    private var currentUser: AppUser? { FirebaseManager.shared.currentUser }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        checkAuthState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        loadUserAppointments()
    }

    // MARK: - Setup

    private func setupUI() {
        view.semanticContentAttribute = .forceRightToLeft

        // כפתור יציאה בנביגציה (נוסף בקוד כי אין barButtonItem בסטוריבורד)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "יציאה",
            style: .plain,
            target: self,
            action: #selector(logoutTapped)
        )

        // כפתור קביעת תור
        bookButton.layer.cornerRadius = 25
        bookButton.clipsToBounds = true
        bookButton.backgroundColor = .label
        bookButton.setTitleColor(.systemBackground, for: .normal)

        // תמונת הגיבור — עיגול
        heroImageView.layer.cornerRadius = heroImageView.bounds.width / 2
        heroImageView.clipsToBounds = true
        heroImageView.contentMode = .scaleAspectFill

        // כפתור Admin — מוסתר כברירת מחדל
        adminButton.isHidden = true
    }

    private func setupTableView() {
        appointmentsTableView.delegate = self
        appointmentsTableView.dataSource = self
        appointmentsTableView.register(
            AppointmentCell.self,
            forCellReuseIdentifier: AppointmentCell.identifier
        )
        appointmentsTableView.separatorStyle = .none
        appointmentsTableView.backgroundColor = .clear
    }

    private func checkAuthState() {
        guard let user = currentUser else {
            navigateToLogin()
            return
        }

        // ברכה מותאמת אישית
        welcomeLabel.text = "👋 אהלן \(user.name), שמחים שחזרת אלינו"

        // אדמין: מציג כפתור ניהול, מסתיר קביעת תור ותורים אישיים
        let isAdmin = user.isAdmin
        adminButton.isHidden = !isAdmin
        bookButton.isHidden = isAdmin
        myAppointmentsButton.isHidden = isAdmin
    }

    // MARK: - Data Loading

    private func loadUserAppointments() {
        guard let user = currentUser else { return }

        FirebaseManager.shared.fetchUserAppointments(userId: user.uid) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let appointments):
                    // מציג רק תורים עתידיים
                    self?.upcomingAppointments = appointments
                        .filter { $0.date > Date() && $0.status != .cancelled }
                        .sorted { $0.date < $1.date }
                    self?.refreshUI()
                case .failure:
                    break
                }
            }
        }
    }

    private func refreshUI() {
        let hasAppointments = !upcomingAppointments.isEmpty
        emptyStateLabel.isHidden = hasAppointments
        appointmentsTableView.isHidden = !hasAppointments
        appointmentsTableView.reloadData()
    }

    // MARK: - IBActions

    @IBAction func bookButtonTapped(_ sender: UIButton) {
        navigateToBooking()
    }

    @IBAction func myAppointmentsTapped(_ sender: UIButton) {
        navigateToMyAppointments()
    }

    @IBAction func adminButtonTapped(_ sender: UIButton) {
        navigateToAdmin()
    }

    @objc func logoutTapped() {
        let alert = UIAlertController(title: "יציאה", message: "האם אתה בטוח שברצונך לצאת?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "יציאה", style: .destructive) { [weak self] _ in
            FirebaseManager.shared.logout()
            self?.navigateToLogin()
        })
        alert.addAction(UIAlertAction(title: "ביטול", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Navigation

    private func navigateToBooking() {
        let barberVC = BarberSelectionViewController()
        barberVC.onBarberSelected = { [weak self] barber in
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            guard let bookingVC = storyboard.instantiateViewController(withIdentifier: "BookingVC") as? BookingViewController else { return }
            bookingVC.selectedBarber = barber
            self?.navigationController?.pushViewController(bookingVC, animated: true)
        }
        navigationController?.pushViewController(barberVC, animated: true)
    }

    private func navigateToMyAppointments() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let myVC = storyboard.instantiateViewController(withIdentifier: "MyAppointmentsVC") as? MyAppointmentsViewController else { return }
        navigationController?.pushViewController(myVC, animated: true)
    }

    private func navigateToAdmin() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let adminVC = storyboard.instantiateViewController(withIdentifier: "AdminVC") as? AdminViewController else { return }
        navigationController?.pushViewController(adminVC, animated: true)
    }

    private func navigateToLogin() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginVC") as? LoginViewController else { return }
        navigationController?.setViewControllers([loginVC], animated: true)
    }
}

// MARK: - UITableViewDataSource & Delegate
extension HomeViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return min(upcomingAppointments.count, 3) // מציג עד 3 תורים קרובים
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AppointmentCell.identifier, for: indexPath) as! AppointmentCell
        cell.configure(with: upcomingAppointments[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        navigateToMyAppointments()
    }
}

// MARK: - AppointmentCell

class AppointmentCell: UITableViewCell {

    static let identifier = "AppointmentCell"

    private let containerView = UIView()
    private let dateLabel = UILabel()
    private let timeLabel = UILabel()
    private let serviceLabel = UILabel()
    private let statusLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupCell() {
        backgroundColor = .clear
        selectionStyle = .none

        containerView.layer.cornerRadius = 16
        containerView.backgroundColor = .secondarySystemBackground
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)

        [dateLabel, timeLabel, serviceLabel, statusLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview($0)
        }

        dateLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        timeLabel.font = .systemFont(ofSize: 22, weight: .bold)
        serviceLabel.font = .systemFont(ofSize: 13)
        serviceLabel.textColor = .secondaryLabel
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.layer.cornerRadius = 8
        statusLabel.clipsToBounds = true
        statusLabel.textAlignment = .center

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            timeLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            timeLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            dateLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            dateLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),

            serviceLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 4),
            serviceLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),

            statusLabel.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 4),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            statusLabel.widthAnchor.constraint(equalToConstant: 70),
            statusLabel.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    func configure(with appointment: Appointment) {
        dateLabel.text = appointment.formattedDate
        timeLabel.text = appointment.formattedTime
        serviceLabel.text = appointment.service.rawValue

        switch appointment.status {
        case .confirmed:
            statusLabel.text = "מאושר"
            statusLabel.backgroundColor = .systemGreen.withAlphaComponent(0.15)
            statusLabel.textColor = .systemGreen
        case .pending:
            statusLabel.text = "ממתין"
            statusLabel.backgroundColor = .systemOrange.withAlphaComponent(0.15)
            statusLabel.textColor = .systemOrange
        case .cancelled:
            statusLabel.text = "בוטל"
            statusLabel.backgroundColor = .systemRed.withAlphaComponent(0.15)
            statusLabel.textColor = .systemRed
        case .completed:
            statusLabel.text = "הושלם"
            statusLabel.backgroundColor = .systemGray.withAlphaComponent(0.15)
            statusLabel.textColor = .systemGray
        }
    }
}

// MARK: - MyAppointmentsViewController

@objc(MyAppointmentsViewController)
class MyAppointmentsViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    private var appointments: [Appointment] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "התורים שלי"
        navigationController?.navigationBar.prefersLargeTitles = true
        view.semanticContentAttribute = .forceRightToLeft
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(AppointmentCell.self, forCellReuseIdentifier: AppointmentCell.identifier)
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        loadAppointments()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadAppointments()
    }

    private func loadAppointments() {
        guard let userId = FirebaseManager.shared.currentUser?.uid else { return }
        FirebaseManager.shared.fetchUserAppointments(userId: userId) { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let items) = result {
                    self?.appointments = items.sorted { $0.date > $1.date }
                    self?.tableView.reloadData()
                }
            }
        }
    }

    // פעולת ביטול דרך לחיצה על התור
    private func showAppointmentOptions(_ appointment: Appointment, at indexPath: IndexPath) {
        let isCancellable = appointment.date > Date() && appointment.status != .cancelled

        let alert = UIAlertController(
            title: appointment.service.rawValue,
            message: "\(appointment.formattedDate) | \(appointment.formattedTime)",
            preferredStyle: .actionSheet
        )

        if isCancellable {
            alert.addAction(UIAlertAction(title: "🗑️ ביטול תור", style: .destructive) { [weak self] _ in
                self?.performCancel(appointment)
            })
        }
        alert.addAction(UIAlertAction(title: "סגור", style: .cancel))
        present(alert, animated: true)
    }

    private func performCancel(_ appointment: Appointment) {
        FirebaseManager.shared.cancelAppointment(appointmentId: appointment.id) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    let alert = UIAlertController(title: "שגיאה", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "אישור", style: .default))
                    self?.present(alert, animated: true)
                } else {
                    self?.loadAppointments()
                }
            }
        }
    }
}

extension MyAppointmentsViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return appointments.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AppointmentCell.identifier, for: indexPath) as! AppointmentCell
        cell.configure(with: appointments[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 90 }

    // לחיצה → תפריט פעולות (כולל ביטול)
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        showAppointmentOptions(appointments[indexPath.row], at: indexPath)
    }

    // Swipe לביטול (גם נשמר)
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let appointment = appointments[indexPath.row]
        guard appointment.date > Date(), appointment.status != .cancelled else { return nil }

        let cancelAction = UIContextualAction(style: .destructive, title: "ביטול") { [weak self] _, _, completion in
            self?.performCancel(appointment)
            completion(true)
        }
        cancelAction.image = UIImage(systemName: "xmark.circle")
        return UISwipeActionsConfiguration(actions: [cancelAction])
    }
}
