🛒 Smart Grocery List App

This Flutter application helps users manage their grocery lists efficiently, track their spending against a budget, and leverage QR code functionality for sharing or quick additions. It integrates with Firebase for user authentication and data storage, ensuring a seamless and persistent experience.

✨ Features
🔐 User Authentication
Register new accounts with email and password

Log in existing users
Update user profile (display name, email requires re-authentication)
Logout functionality

📝 Grocery List Management
Add new grocery items with name, quantity, price, and category

Edit existing items
Mark items as purchased
Delete individual items or clear all items

Categorize items:
Fruits & Vegetables
Dairy & Eggs
Meat & Seafood
Pantry
Beverages
Snacks
Frozen
Household
Other

Quick Add functionality for common items

💰 Budget Tracking
Set a budget limit

View total cost, amount spent, and remaining budget
Visual progress indicator for budget usage
Warning for exceeding the budget

📱 QR Code Integration
Generate QR codes for grocery lists
Scan QR codes to import grocery items

💾 Persistent Storage
Local storage using shared_preferences
Cloud storage using Firebase Firestore

🧑‍💻 Smooth User Experience
Animated transitions for various UI elements
Informative snackbar messages for user feedback

🛠️ Technologies Used
Flutter – UI Toolkit for cross-platform development
Firebase
Firebase Authentication: User login & registration
Cloud Firestore: NoSQL database for user data and grocery items
shared_preferences – Local data storage
qr_flutter – QR code generation
mobile_scanner – QR code scanning


🚀 Getting Started
✅ Prerequisites
Flutter SDK
Follow the official Flutter installation guide
Firebase Project Setup
Create a Firebase project at Firebase Console
Enable Email/Password authentication
Set up Cloud Firestore
Add your Android and iOS apps to the Firebase project
Download google-services.json (Android) and GoogleService-Info.plist (iOS)

Place them in:
android/app/google-services.json
ios/Runner/GoogleService-Info.plist

🧪 Installation
bash
Copy
Edit
# Clone the repository
git clone [repository_url]
cd smart_grocery_list_app

# Install dependencies
flutter pub get

# Run the application
flutter run
