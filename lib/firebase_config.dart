import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  static Future<void> initializeFirebase() async {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCWwJLz8e_M5YPH2csy8bjs1Xnlx-eqqiE",
        appId: "1:690055898334:android:a5855a3de624b49935ce4f",
        messagingSenderId: "690055898334",
        projectId: "discord-73f6f",
        storageBucket: "discord-73f6f.appspot.com",
        databaseURL: "https://discord-73f6f-default-rtdb.asia-southeast1.firebasedatabase.app/", // 🔥 Thêm dòng này
      ),
    );
  }
}
