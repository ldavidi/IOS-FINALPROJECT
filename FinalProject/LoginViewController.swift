// LoginViewController.swift
// Barbershop Booking App
//
// Storyboard ID: "LoginVC"
// חבר ב-Storyboard:
//   - nameTextField        → UITextField
//   - phoneTextField       → UITextField
//   - emailTextField       → UITextField
//   - passwordTextField    → UITextField
//   - nameLabel            → UILabel (מוסתר במצב כניסה)
//   - phoneLabel           → UILabel (מוסתר במצב כניסה)
//   - actionButton         → UIButton ("כניסה" / "הרשמה")
//   - toggleButton         → UIButton (מעבר בין כניסה להרשמה)
//   - forgotPasswordButton → UIButton
//   - activityIndicator    → UIActivityIndicatorView

import UIKit
import CoreLocation

@objc(LoginViewController)
class LoginViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var phoneLabel: UILabel!
    @IBOutlet weak var phoneTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var actionButton: UIButton!
    @IBOutlet weak var toggleButton: UIButton!
    @IBOutlet weak var forgotPasswordButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    // MARK: - State
    private var isLoginMode = true

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTextFields()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        // אם המשתמש כבר מחובר — דלג ישירות לדף הבית
        if FirebaseManager.shared.currentUser != nil {
            navigateToHome()
        }
    }

    // MARK: - UI Setup
    private func setupUI() {
        // RTL
        view.semanticContentAttribute = .forceRightToLeft

        // עיצוב כפתור ראשי
        actionButton.layer.cornerRadius = 25
        actionButton.clipsToBounds = true

        // עיצוב שדות טקסט
        [nameTextField, phoneTextField, emailTextField, passwordTextField].forEach {
            $0?.layer.cornerRadius = 12
            $0?.layer.borderWidth = 1
            $0?.layer.borderColor = UIColor.systemGray4.cgColor
            $0?.textAlignment = .right
            $0?.setLeftPaddingPoints(12)
            $0?.setRightPaddingPoints(12)
        }

        passwordTextField.isSecureTextEntry = true
        phoneTextField.keyboardType = .phonePad
        emailTextField.keyboardType = .emailAddress

        updateModeUI()
    }

    private func setupTextFields() {
        [nameTextField, phoneTextField, emailTextField, passwordTextField].forEach {
            $0?.delegate = self
        }
    }

    private func updateModeUI() {
        let isRegister = !isLoginMode

        // הצגת שדות רק בהרשמה
        nameLabel.isHidden = !isRegister
        nameTextField.isHidden = !isRegister
        phoneLabel.isHidden = !isRegister
        phoneTextField.isHidden = !isRegister
        forgotPasswordButton.isHidden = !isLoginMode

        titleLabel.text = isLoginMode ? "כניסה לחשבון" : "הרשמה"
        actionButton.setTitle(isLoginMode ? "כניסה" : "הרשמה", for: .normal)

        let toggleText = isLoginMode ? "אין לך חשבון? הרשם כאן" : "יש לך חשבון? כנס כאן"
        toggleButton.setTitle(toggleText, for: .normal)
    }

    // MARK: - IBActions

    @IBAction func actionButtonTapped(_ sender: UIButton) {
        view.endEditing(true)
        if isLoginMode {
            performLogin()
        } else {
            performRegister()
        }
    }

    @IBAction func toggleModeButtonTapped(_ sender: UIButton) {
        isLoginMode.toggle()
        UIView.animate(withDuration: 0.3) {
            self.updateModeUI()
            self.view.layoutIfNeeded()
        }
    }

    @IBAction func forgotPasswordTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "שחזור סיסמה",
                                      message: "הזן את כתובת המייל שלך",
                                      preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "מייל"
            tf.keyboardType = .emailAddress
            tf.textAlignment = .right
        }
        alert.addAction(UIAlertAction(title: "שלח", style: .default) { [weak self] _ in
            guard let email = alert.textFields?.first?.text, !email.isEmpty else { return }
            FirebaseManager.shared.resetPassword(email: email) { error in
                if let error = error {
                    self?.showAlert(title: "שגיאה", message: error.localizedDescription)
                } else {
                    self?.showAlert(title: "נשלח!", message: "בדוק את תיבת הדואר שלך")
                }
            }
        })
        alert.addAction(UIAlertAction(title: "ביטול", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Auth Logic

    private func performLogin() {
        guard
            let email = emailTextField.text, !email.isEmpty,
            let password = passwordTextField.text, !password.isEmpty
        else {
            showAlert(title: "שגיאה", message: "אנא מלא את כל השדות")
            return
        }

        setLoading(true)

        FirebaseManager.shared.login(email: email, password: password) { [weak self] result in
            DispatchQueue.main.async {
                self?.setLoading(false)
                switch result {
                case .success:
                    self?.navigateToHome()
                case .failure(let error):
                    self?.showAlert(title: "שגיאת כניסה", message: error.localizedDescription)
                }
            }
        }
    }

    private func performRegister() {
        guard
            let name     = nameTextField.text,     !name.isEmpty,
            let phone    = phoneTextField.text,    !phone.isEmpty,
            let email    = emailTextField.text,    !email.isEmpty,
            let password = passwordTextField.text, password.count >= 6
        else {
            showAlert(title: "שגיאה", message: "אנא מלא את כל השדות (סיסמה לפחות 6 תווים)")
            return
        }

        // שאל אם הוא לקוח או ספר
        let typeAlert = UIAlertController(title: "סוג חשבון", message: "איך תרצה להירשם?", preferredStyle: .actionSheet)

        typeAlert.addAction(UIAlertAction(title: "👤 לקוח", style: .default) { [weak self] _ in
            self?.doRegister(name: name, phone: phone, email: email, password: password,
                             isBarber: false, shopName: nil)
        })

        typeAlert.addAction(UIAlertAction(title: "✂️ ספר / בעל מספרה", style: .default) { [weak self] _ in
            self?.askForShopName { shopName in
                self?.doRegister(name: name, phone: phone, email: email, password: password,
                                 isBarber: true, shopName: shopName)
            }
        })

        typeAlert.addAction(UIAlertAction(title: "ביטול", style: .cancel))
        present(typeAlert, animated: true)
    }

    private func askForShopName(completion: @escaping (String) -> Void) {
        let alert = UIAlertController(title: "שם העסק", message: "הכנס את שם המספרה שלך", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "לדוגמא: מספרת כהן"
            tf.textAlignment = .right
        }
        alert.addAction(UIAlertAction(title: "המשך", style: .default) { _ in
            let shopName = alert.textFields?.first?.text ?? ""
            completion(shopName.isEmpty ? "מספרה" : shopName)
        })
        alert.addAction(UIAlertAction(title: "ביטול", style: .cancel))
        present(alert, animated: true)
    }

    private func doRegister(name: String, phone: String, email: String, password: String,
                            isBarber: Bool, shopName: String?) {
        setLoading(true)

        let finishRegister = { [weak self] (lat: Double?, lon: Double?) in
            FirebaseManager.shared.register(
                name: name, phone: phone, email: email, password: password,
                isBarber: isBarber, shopName: shopName,
                latitude: lat, longitude: lon
            ) { result in
                DispatchQueue.main.async {
                    self?.setLoading(false)
                    switch result {
                    case .success:
                        self?.navigateToHome()
                    case .failure(let error):
                        self?.showAlert(title: "שגיאת הרשמה", message: error.localizedDescription)
                    }
                }
            }
        }

        if isBarber {
            // מבקש מיקום לספר — עם timeout של 6 שניות כדי שהספינר לא יתקע
            var done = false
            let fallback = DispatchWorkItem {
                guard !done else { return }
                done = true
                finishRegister(nil, nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: fallback)

            LocationManager.shared.requestLocation { location in
                guard !done else { return }
                done = true
                fallback.cancel()
                finishRegister(location?.coordinate.latitude, location?.coordinate.longitude)
            }
        } else {
            finishRegister(nil, nil)
        }
    }

    // MARK: - Navigation

    private func navigateToHome() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let homeVC = storyboard.instantiateViewController(withIdentifier: "HomeVC") as? HomeViewController else { return }
        // משתמש ב-NavigationController הקיים של הסטוריבורד
        navigationController?.setViewControllers([homeVC], animated: true)
    }

    // MARK: - Helpers

    private func setLoading(_ loading: Bool) {
        activityIndicator.isHidden = !loading
        if loading { activityIndicator.startAnimating() }
        else { activityIndicator.stopAnimating() }
        actionButton.isEnabled = !loading
        actionButton.alpha = loading ? 0.6 : 1.0
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "אישור", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITextFieldDelegate
extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case nameTextField: phoneTextField.becomeFirstResponder()
        case phoneTextField: emailTextField.becomeFirstResponder()
        case emailTextField: passwordTextField.becomeFirstResponder()
        default: textField.resignFirstResponder()
        }
        return true
    }
}

// MARK: - UITextField Padding Extension
extension UITextField {
    func setLeftPaddingPoints(_ amount: CGFloat) {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: self.frame.height))
        self.leftView = view
        self.leftViewMode = .always
    }
    func setRightPaddingPoints(_ amount: CGFloat) {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: self.frame.height))
        self.rightView = view
        self.rightViewMode = .always
    }
}
