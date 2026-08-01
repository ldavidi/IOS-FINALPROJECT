// BarberSelectionViewController.swift
// Barbershop Booking App
// מסך בחירת ספר לפי מיקום — נוצר לגמרי בקוד (ללא סטוריבורד)

import UIKit
import CoreLocation

@objc(BarberSelectionViewController)
class BarberSelectionViewController: UIViewController {

    // קריאה חוזרת כשהמשתמש בוחר ספר
    var onBarberSelected: ((AppUser) -> Void)?

    private var barbers: [AppUser] = []
    private var didSelectBarber = false  // מונע לחיצה כפולה

    // MARK: - UI
    private let tableView        = UITableView(frame: .zero, style: .insetGrouped)
    private let spinner          = UIActivityIndicatorView(style: .large)
    private let emptyLabel       = UILabel()
    private let locationDeniedLabel = UILabel()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "בחר ספר"
        view.backgroundColor = .systemGroupedBackground
        view.semanticContentAttribute = .forceRightToLeft
        setupUI()
        loadNearbyBarbers()
    }

    // MARK: - Setup

    private func setupUI() {
        // TableView
        tableView.delegate   = self
        tableView.dataSource = self
        tableView.register(BarberCell.self, forCellReuseIdentifier: BarberCell.identifier)
        tableView.backgroundColor = .clear
        tableView.isHidden = true
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        // Spinner
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)

        // Empty label
        emptyLabel.text = "אין ספרים בטווח 20 ק\"מ ממיקומך"
        emptyLabel.textAlignment = .center
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.font = .systemFont(ofSize: 16)
        emptyLabel.numberOfLines = 0
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)

        // Location denied label
        locationDeniedLabel.text = "לא ניתן לגשת למיקום.\nמציג את כל הספרים הרשומים."
        locationDeniedLabel.textAlignment = .center
        locationDeniedLabel.textColor = .secondaryLabel
        locationDeniedLabel.font = .systemFont(ofSize: 13)
        locationDeniedLabel.numberOfLines = 0
        locationDeniedLabel.isHidden = true
        locationDeniedLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(locationDeniedLabel)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            locationDeniedLabel.bottomAnchor.constraint(equalTo: tableView.topAnchor, constant: -8),
            locationDeniedLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            locationDeniedLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }

    // MARK: - Load

    private func loadNearbyBarbers() {
        spinner.startAnimating()

        LocationManager.shared.requestLocation { [weak self] userLocation in
            guard let self = self else { return }

            FirebaseManager.shared.fetchBarbers { barbers in
                self.spinner.stopAnimating()

                if let userLocation = userLocation {
                    // מחשב מרחק לכל ספר שיש לו מיקום
                    let withDistance = barbers.map { barber -> AppUser in
                        var b = barber
                        if let lat = barber.latitude, let lon = barber.longitude {
                            b.distanceKm = LocationManager.distanceKm(from: userLocation, toLat: lat, lon: lon)
                        }
                        return b
                    }.sorted { ($0.distanceKm ?? 9999) < ($1.distanceKm ?? 9999) }

                    // מנסה לסנן ל-20 ק"מ; אם אין כאלה — מציג את כולם
                    let nearby = withDistance.filter { ($0.distanceKm ?? 9999) <= 20 }
                    self.handleResult(nearby.isEmpty ? withDistance : nearby, locationAvailable: true)
                } else {
                    // אין מיקום — מציג את כל הספרים
                    self.locationDeniedLabel.isHidden = false
                    self.handleResult(barbers, locationAvailable: false)
                }
            }
        }
    }

    private func handleResult(_ barbers: [AppUser], locationAvailable: Bool) {
        self.barbers = barbers

        if barbers.isEmpty {
            emptyLabel.isHidden = false
        } else if barbers.count == 1 {
            // ספר יחיד — בוחרים אוטומטית
            selectBarber(barbers[0])
        } else {
            tableView.isHidden = false
            tableView.reloadData()
        }
    }

    private func selectBarber(_ barber: AppUser) {
        guard !didSelectBarber else { return }
        didSelectBarber = true
        onBarberSelected?(barber)
    }
}

// MARK: - UITableViewDataSource & Delegate

extension BarberSelectionViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        barbers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: BarberCell.identifier, for: indexPath) as! BarberCell
        cell.configure(with: barbers[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 72 }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        selectBarber(barbers[indexPath.row])
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "ספרים בסביבתך"
    }
}

// MARK: - BarberCell

class BarberCell: UITableViewCell {

    static let identifier = "BarberCell"

    private let shopLabel     = UILabel()
    private let nameLabel     = UILabel()
    private let distanceLabel = UILabel()
    private let chevron       = UIImageView(image: UIImage(systemName: "chevron.left"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupCell() {
        semanticContentAttribute = .forceRightToLeft
        selectionStyle = .default

        let icon = UIImageView(image: UIImage(systemName: "scissors"))
        icon.tintColor = .systemRed
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 32).isActive = true

        shopLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        shopLabel.textColor = .label

        nameLabel.font = .systemFont(ofSize: 13)
        nameLabel.textColor = .secondaryLabel

        distanceLabel.font = .systemFont(ofSize: 13, weight: .medium)
        distanceLabel.textColor = .systemRed
        distanceLabel.textAlignment = .left

        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.widthAnchor.constraint(equalToConstant: 14).isActive = true

        let textStack = UIStackView(arrangedSubviews: [shopLabel, nameLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [icon, textStack, distanceLabel, chevron])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }

    func configure(with barber: AppUser) {
        shopLabel.text = barber.shopName ?? barber.name
        nameLabel.text = barber.shopName != nil ? barber.name : ""

        if let dist = barber.distanceKm {
            distanceLabel.text = dist < 1 ? "פחות מ-1 ק\"מ" : String(format: "%.1f ק\"מ", dist)
        } else {
            distanceLabel.text = ""
        }
    }
}
