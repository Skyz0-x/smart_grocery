Smart Grocery List App
A Flutter-based mobile application designed to help users manage their grocery lists efficiently, track expenses, and share lists with others. The app features user authentication, persistent storage, and a clean, animated user interface.

Features
User Authentication: Secure user registration and login using Firebase Authentication.

Grocery List Management:

Add, edit, and delete grocery items.

Mark items as purchased.

Categorize items for better organization.

View total estimated cost and spent amount.

Budget Tracking: Set a budget limit and monitor spending against it.

QR Code Sharing: Generate and scan QR codes to easily share grocery lists with other users.

User Profiles: View and update user profile information.

Persistent Storage: Uses both Firebase Firestore for real-time data synchronization and SharedPreferences for local budget storage.

Animated UI: Smooth transitions and animations for a delightful user experience.

Technologies Used
Flutter: UI Toolkit for building natively compiled applications for mobile, web, and desktop from a single codebase.

Firebase:

Firebase Authentication: For user registration, login, and session management.

Cloud Firestore: NoSQL cloud database for storing grocery items and user data in real-time.

shared_preferences: Flutter plugin for reading and writing simple key-value pairs to persistent storage.

qr_flutter: A Flutter package for generating QR codes.

mobile_scanner: A Flutter package for scanning barcodes and QR codes.

Project Structure
The project is organized into the following main directories:

lib/main.dart: The entry point of the Flutter application.

lib/models/grocery_item.dart: Defines the GroceryItem data model.

lib/screens/: Contains the UI screens of the application.

login_screen.dart: User login interface.

register_screen.dart: User registration interface.

grocery_list_screen.dart: Main screen for managing grocery items.

profile_screen.dart: User profile management screen.

lib/utils/: Contains utility classes.

auth_service.dart: Handles Firebase Authentication logic.

storage_helper.dart: Manages local storage using shared_preferences (primarily for budget).

Setup and Installation
To get this project up and running on your local machine, follow these steps:

1. Clone the Repository
git clone <your-repository-url>
cd smart_grocery_list_app

2. Install Flutter
If you don't have Flutter installed, follow the official installation guide: Flutter Installation Guide

3. Configure Firebase
This application uses Firebase for authentication and database. You need to set up a Firebase project and connect it to your Flutter app.

Create a Firebase Project: Go to the Firebase Console and create a new project.

Add Android/iOS App: Follow the instructions in the Firebase Console to add an Android and/or iOS app to your project. This will involve:

Registering your app's package name (Android) or bundle ID (iOS).

Downloading google-services.json (for Android) and placing it in android/app/.

Downloading GoogleService-Info.plist (for iOS) and placing it in ios/Runner/.

Enable Firebase Services:

Authentication: Go to "Authentication" in the Firebase Console and enable "Email/Password" sign-in method.

Firestore Database: Go to "Firestore Database" and create a new database. Choose a starting mode (e.g., "Start in test mode" for quick setup, but remember to secure your rules for production).

Firebase Rules (Firestore):
For the app to function correctly, you'll need to set up Firestore security rules. Here's a basic set of rules that allows authenticated users to read and write to their own grocery lists and public data.

rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Public data (e.g., shared lists, if implemented)
    match /artifacts/{appId}/public/data/{collection}/{document} {
      allow read, write: if request.auth != null;
    }

    // Private user data (e.g., individual grocery lists)
    match /artifacts/{appId}/users/{userId}/{collection}/{document} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Specific rules for 'users' collection (for profile data)
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Rules for the 'groceries' subcollection under each user
    match /users/{userId}/groceries/{documentId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}

Note: The __app_id variable is used in the Canvas environment. If you are running this app outside of Canvas, you might need to adjust the paths or remove artifacts/{appId} from your Firestore rules and code.

4. Install Dependencies
Run the following command in your project root to install all required Flutter packages:

flutter pub get

5. Run the Application
Connect a device or start an emulator, then run the app:

flutter run

Usage
Register/Login: Upon launching the app, you'll be prompted to register a new account or log in with existing credentials.

Manage Grocery List:

Use the floating action button to add new grocery items.

Tap on an item to mark it as purchased or to edit its details.

Swipe left on an item to delete it.

Use the category filter at the top to view items by category.

Set Budget: Access the budget setting from the main grocery list screen to set your spending limit.

Share List: Use the QR code functionality to share your list.

Profile: Access your profile from the navigation to update your name or log out.

Contributing
Contributions are welcome! If you find a bug or have a feature request, please open an issue.

License
This project is open-source and available under the MIT License.
