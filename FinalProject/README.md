# ✂️ Oran Zandani — אפליקציית קביעת תורים למספרה

אפליקציית iOS לקביעת תורים למספרה, בנויה עם UIKit, Firebase ו-CoreLocation.  
תומכת בשני סוגי משתמשים: **לקוחות** ו**ספרים**, עם ממשק בעברית מלא ותמיכה ב-Dark Mode.

---

## 🔐 פרטי התחברות לבדיקה

| תפקיד | אימייל | סיסמה |
|--------|--------|--------|
| ✂️ ספר (Admin) | `admin@gmail.com` | `imtheadmin` |
| 👤 לקוח | `test@gmail.com` | `testing` |

---

## ✨ תכונות עיקריות

### לקוח
- **הרשמה וכניסה** — Firebase Authentication עם מייל וסיסמה
- **בחירת ספר לפי מיקום** — CoreLocation מאתר ספרים בטווח 20 ק"מ אוטומטית; אם יש יותר מאחד — מוצגת רשימה ממוינת לפי מרחק
- **קביעת תור** — לוח שנה אינטראקטיבי, בחירת שעה ושירות
- **התורים שלי** — צפייה, ביטול (לחיצה על תור)
- **התראות** — תזכורת 24 שעות ו-1 שעה לפני התור

### ספר (Admin)
- **הרשמה כספר** — שם עסק + שמירת מיקום GPS אוטומטית
- **ניהול תורים בזמן אמת** — Firestore Snapshot Listener
- **סינון תורים** — הכל / היום / ממתינים
- **אישור וביטול תורים**
- **חסימת ימים** — חסימת תאריכים שלמים למניעת קביעות

---

## 🏗️ ארכיטקטורה

```
FinalProject/
├── AppDelegate.swift              — אתחול Firebase, ניהול UIWindow
├── Models.swift                   — AppUser, Appointment, ServiceType, TimeSlot, BusinessHours
├── FirebaseManager.swift          — Singleton לכל פעולות Firebase
├── LocationManager.swift          — Singleton לניהול CoreLocation
├── LoginViewController.swift      — כניסה / הרשמה (לקוח + ספר)
├── HomeViewController.swift       — דף הבית + MyAppointmentsViewController
├── BarberSelectionViewController.swift — בחירת ספר לפי מיקום (קוד בלבד, ללא Storyboard)
├── BookingViewController.swift    — קביעת תור (לוח שנה + שעות + שירות)
├── AdminViewController.swift      — ניהול תורים לספר
├── NotificationManager.swift      — התראות מקומיות
└── Main.storyboard                — LoginVC, HomeVC, BookingVC, MyAppointmentsVC, AdminVC
```

---

## 🛠️ טכנולוגיות

| שכבה | טכנולוגיה |
|------|-----------|
| UI | UIKit + Storyboard (iOS 16+) |
| Auth | Firebase Authentication |
| Database | Firebase Firestore |
| Notifications | Firebase Messaging + UNUserNotificationCenter |
| Location | CoreLocation |
| Package Manager | Swift Package Manager (SPM) |
| Language | Swift 5.9, Xcode 16 |

---

## 🗄️ מבנה Firestore

### `users/{uid}`
```
uid:        String
name:       String
email:      String
phone:      String
isAdmin:    Bool        // true = ספר
shopName:   String?     // שם המספרה (ספרים בלבד)
latitude:   Double?     // מיקום GPS
longitude:  Double?
fcmToken:   String
```

### `appointments/{id}`
```
id:         String (UUID)
userId:     String
userName:   String
userPhone:  String
barberId:   String      // uid של הספר
barberName: String
service:    String      // "תספורת" | "זקן" | "תספורת + זקן" | "פייד" | "תספורת ילדים"
date:       Timestamp
status:     String      // "pending" | "confirmed" | "cancelled" | "completed"
notes:      String
createdAt:  Timestamp
```

### `blockedSlots/{id}`
```
date:       Timestamp
fullDay:    Bool
```

---

## ⚙️ התקנה והפעלה

### דרישות מקדימות
- Xcode 16+
- iOS 16+ (Simulator או מכשיר אמיתי)
- חשבון Firebase (פרויקט `finalprojectios-54ba8`)

### הפעלה
1. פתח את `FinalProject.xcodeproj` ב-Xcode
2. ודא ש-`GoogleService-Info.plist` נמצא בתיקיית הפרויקט
3. בחר Simulator או מכשיר → ▶ Run

### Firebase Console
- **Firestore:** `console.firebase.google.com` → FinalProjectIOS → Firestore Database
- **Authentication:** לניהול משתמשים
- **Messaging:** לבדיקת Push Notifications

---

## 🌙 Dark Mode

כל הצבעים בקוד משתמשים ב-Semantic Colors של iOS:
- `.label`, `.systemBackground`, `.secondarySystemBackground`
- `.systemRed`, `.systemGreen`, `.systemOrange` (עם `.withAlphaComponent`)
- `.tertiaryLabel`, `.secondaryLabel`

המעבר בין Light/Dark אוטומטי עם הגדרות המכשיר.

---

## 📱 זרימת המשתמש

```
Launch
  └─ כניסה קיימת? ──Yes──→ Home
          │No
          ↓
      Login / Register
          │ ספר? → בחירת שם עסק + GPS
          ↓
        Home
    ┌─────┴─────────────┐
    ↓                   ↓
 קביעת תור         התורים שלי
    ↓                   ↓
 בחירת ספר        צפייה / ביטול
    ↓
 לוח שנה + שעה
    ↓
 אישור → Firestore
    ↓
 התראה נקבעת (24h + 1h)
```

---

## 👤 זרימת ספר (Admin)

```
Login (admin@gmail.com)
  └─→ Home (ללא כפתורי קביעה)
        └─→ ניהול תורים
              ├─ Listener בזמן אמת
              ├─ סינון: הכל / היום / ממתינים
              ├─ אישור / ביטול תורים
              └─ חסימת ימים
```

---

## 🧪 תרחישי בדיקה מומלצים

1. **הרשמת לקוח חדש** → מלא פרטים → בחר "לקוח" → עובר לדף הבית
2. **קביעת תור** → בחר ספר → בחר תאריך → בחר שעה → אשר → רואה בתורים שלי
3. **ביטול תור** → התורים שלי → לחץ על תור → "ביטול תור"
4. **ניהול אדמין** → כנס עם `admin@gmail.com` → ניהול תורים → אשר/בטל תורים
5. **Dark Mode** → Settings → Developer → Appearance: Dark → חזור לאפליקציה

---

*פרויקט גמר | פיתוח אפליקציות מובייל | 2026*
