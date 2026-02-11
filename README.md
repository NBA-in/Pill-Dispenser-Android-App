# Smart Pill Dispenser App

A Flutter-based application for managing a smart pill dispenser, designed to help patients adhere to their medication schedules and allow caregivers to monitor progress.

## 🚀 Features

### 👥 Role-Based Access
- **Caregiver**: Monitor multiple patients, set up devices, and view adherence statistics.
- **Patient**: View daily medication schedules, receive reminders, and track own progress.

### 🔐 Authentication & Onboarding
- **Role Selection**: distinct flows for Patients and Caregivers.
- **Secure Login & Registration**: Integrated with Firebase Authentication.

### 📱 Dashboards
- **Caregiver Dashboard**:
  - Overview of managed dispensers.
  - Quick access to refill wizards and device settings.
  - View dose history and alerts.
- **Patient Dashboard**:
  - clear display of upcoming doses.
  - Next dose countdown.

### 💊 Dispenser Management
- **Device Setup**: Connect and configure new smart pill dispensers.
- **Refill Wizard**: Step-by-step guide to refilling the dispenser.
- **Inventory Tracking**: Monitor remaining pills and receive low-stock alerts.

### 📅 Scheduling & Reminders
- **Flexible Scheduling**: Create complex medication schedules (daily, weekly, custom).
- **Local Notifications**: robust reminder system ensuring alerts even when offline.
- **Cloud Sync**: Schedules synced via Firebase for remote management.

### 📊 Statistics
- **Adherence Tracking**: Visual reports on medication consistency.
- **History Logs**: Detailed records of dispensed and taken doses.

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev/)
- **State Management**: [Riverpod](https://riverpod.dev/)
- **Backend Services**: [Firebase](https://firebase.google.com/) (Auth, Firestore, Cloud Messaging)
- **Local Storage**: [Hive](https://docs.hivedb.dev/)
- **Notifications**: `flutter_local_notifications`

## ⚙️ Setup & Installation

1.  **Clone the repository**:
    ```bash
    git clone <repository-url>
    cd pill_dispenser_app
    ```

2.  **Environment Variables**:
    > [!IMPORTANT]
    > This project uses a `.env` file to secure API keys. You must create this file in the root directory.

    Create a `.env` file in the project root and add your Firebase API keys and configuration:
    ```env
    # Web
    WEB_API_KEY=your_api_key
    WEB_APP_ID=your_app_id
    # ... (other keys for Android, iOS, Windows, macOS)
    ```

3.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```

4.  **Run the App**:
    ```bash
    flutter run
    ```

## 🚧 Development Status

- [x] Core Authentication Flow
- [x] Basic Dashboard UI (Patient & Caregiver)
- [x] Schedule Management
- [x] Local Notifications
- [x] API Key Security
- [ ] Advanced Analytics (In Progress)
- [ ] Hardware Integration Finalization (In Progress)

## 🤝 Contributing

1.  Fork the project
2.  Create your feature branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request
