// import 'package:device_apps/device_apps.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:workmanager/workmanager.dart';
import 'functions/functions.dart';
import 'functions/notifications.dart';
import 'pages/loadingPage/loadingpage.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'package:bubble_head/bubble.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  openApp();
  print('Received a message while in the foreground: ${message.messageId}');

  if (message.data['push_type'].toString() == 'meta-request') {
    // print('iuhthtgtr');
    await playAudioNotification();
    print("Handling a background message: ${message.messageId}");
    openApp();

    // DeviceApps.openApp('com.helloautoapp.driverapp');
  }
  if (message.data['type'] == 'new_ride_request') {
    playAudioNotification();
    await openApp();

  }
}

AudioPlayer audioPlayer = AudioPlayer();

Future<void> playAudioNotification() async {
  await audioPlayer.play(AssetSource('audio/notification_sound.mp3'));

}
Future<void> openApp() async {
  const String packageName = 'com.helloautoapp.driverapp'; // Your app's package name
  final Uri uri = Uri.parse("intent://$packageName#Intent;scheme=android-app;end;");

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
    print('App launched successfully!');
  } else {
    print('Could not launch the app');
    await showFullScreenNotification();

  }
}
Future<void> showFullScreenNotification() async {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'ride_request_channel',
    'Ride Request Notifications',
    importance: Importance.max,
    priority: Priority.high,
    fullScreenIntent: true,  // Ensures the notification behaves like an incoming call
    ticker: 'New Ride Request',
    sound: RawResourceAndroidNotificationSound('notification_sound'),
  );

  const NotificationDetails platformDetails =
  NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    0,
    ' New Ride Request!',
    'Tap to accept the ride.',
    platformDetails,
    payload: 'new_ride_request',
  );
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  // Workmanager().executeTask((task, inputData) async {
  //   try {
  //     await Firebase.initializeApp();
  //     var val = await Geolocator.getCurrentPosition();
  //     // ignore: prefer_typing_uninitialized_variables
  //     var id;
  //     if (inputData != null) {
  //       id = inputData['id'];
  //     }
  //     FirebaseDatabase.instance.ref().child('drivers/driver_$id').update({
  //       'lat-lng': val.latitude.toString(),
  //       'l': {'0': val.latitude, '1': val.longitude},
  //       'updated_at': ServerValue.timestamp
  //     });
  //     // ignore: empty_catches
  //   } catch (e) {}
  //
  //   return Future.value(true);
  // });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

  await Firebase.initializeApp();
  initMessaging();
  checkInternetConnection();

  currentPositionUpdate();

  // Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final platforms = const MethodChannel('flutter.app/awake');
  // This widget is the root of your application.

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    // Workmanager().cancelAll();
    super.initState();
    loadDriverStatus();
  }
  Future<void> loadDriverStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Load the driver's active status
    bool? isActive = prefs.getBool('driver_active');
    if (isActive != null && isActive) {
      userDetails['active'] = true; // Set the user's active status
      // Optionally load other details
      userDetails['id'] = prefs.getString('driver_id');
      userDetails['name'] = prefs.getString('driver_name');
      userDetails['vehicle_types'] = prefs.getString('driver_vehicle')?.split(',') ?? [];
    } else {
      userDetails['active'] = false; // Set to false if not active
    }
  }

  // final Bubble _bubble =
  //     Bubble(showCloseButton: false, allowDragToClose: false);
  Future<void> startBubbleHead() async {
    try {
      // await _bubble.startBubbleHead(sendAppToBackground: false);
    } on PlatformException {
      debugPrint('Failed to call startBubbleHead');
    }
  }

  Future<void> stopBubbleHead() async {
    try {
      // await _bubble.stopBubbleHead();
    } on PlatformException {
      debugPrint('Failed to call stopBubbleHead');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      if (Platform.isAndroid &&
          userDetails.isNotEmpty &&
          userDetails['role'] == 'driver' &&
          userDetails['active'] == true) {
        updateLocation(10);
        startBubbleHead();
        await saveDriverStatus();
      } else {}
    }
    if (Platform.isAndroid && state == AppLifecycleState.resumed) {
      stopBubbleHead();
      loadDriverStatus();
      // Workmanager().cancelAll();
    }
  }

  Future<void> saveDriverStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Save the driver's active status
    await prefs.setBool('driver_active', userDetails['active']);

    // Optionally, save other relevant details
    await prefs.setString('driver_id', userDetails['id']);
    await prefs.setString('driver_name', userDetails['name']);
    await prefs.setString('driver_vehicle', userDetails['vehicle_types'].toString());
  }

  @override
  Widget build(BuildContext context) {
    platform = Theme.of(context).platform;

    return GestureDetector(
        onTap: () {
          //remove keyboard on touching anywhere on the screen.
          FocusScopeNode currentFocus = FocusScope.of(context);

          if (!currentFocus.hasPrimaryFocus) {
            currentFocus.unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          }
        },
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'HelloAuto Driver',
          theme: ThemeData(),
          home: const LoadingPage(),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.0)),
              child: child!,
            );
          },
        ));
  }
}

void updateLocation(duration) {
  for (var i = 0; i < 15; i++) {
    // Workmanager().registerPeriodicTask('locs_$i', 'update_locs_$i',
    //     initialDelay: Duration(minutes: i),
    //     frequency: const Duration(minutes: 15),
    //     constraints: Constraints(
    //         networkType: NetworkType.connected,
    //         requiresBatteryNotLow: false,
    //         requiresCharging: false,
    //         requiresDeviceIdle: false,
    //         requiresStorageNotLow: false),
    //     inputData: {'id': userDetails['id'].toString()});
  }
}
