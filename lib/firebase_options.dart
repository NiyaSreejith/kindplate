// File generated for KindPlate Firebase configuration
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCNt0kEoT06sAXAkLODrlN5AuRsJjbeajU',
    appId: '1:461658367184:web:6d7a268a8af52781f16ad5',
    messagingSenderId: '461658367184',
    projectId: 'kindplate-70cfa',
    authDomain: 'kindplate-70cfa.firebaseapp.com',
    storageBucket: 'kindplate-70cfa.firebasestorage.app',
    measurementId: 'G-JPYCL9SQ8H',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyACHAZqE3KllGViHl91B6MBAhlYQExxOms',
    appId: '1:461658367184:android:c226db7e6fe7fbf8f16ad5',
    messagingSenderId: '461658367184',
    projectId: 'kindplate-70cfa',
    storageBucket: 'kindplate-70cfa.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD1QRAsgW6BEvxK-f9lSJE_Mzve0U10ZGg',
    appId: '1:461658367184:ios:ac60bc8d85623ba9f16ad5',
    messagingSenderId: '461658367184',
    projectId: 'kindplate-70cfa',
    storageBucket: 'kindplate-70cfa.firebasestorage.app',
    iosBundleId: 'com.kindplate.kindplate',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyD1QRAsgW6BEvxK-f9lSJE_Mzve0U10ZGg',
    appId: '1:461658367184:ios:ac60bc8d85623ba9f16ad5',
    messagingSenderId: '461658367184',
    projectId: 'kindplate-70cfa',
    storageBucket: 'kindplate-70cfa.firebasestorage.app',
    iosBundleId: 'com.kindplate.kindplate',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCNt0kEoT06sAXAkLODrlN5AuRsJjbeajU',
    appId: '1:461658367184:web:610b25e7805ff825f16ad5',
    messagingSenderId: '461658367184',
    projectId: 'kindplate-70cfa',
    authDomain: 'kindplate-70cfa.firebaseapp.com',
    storageBucket: 'kindplate-70cfa.firebasestorage.app',
    measurementId: 'G-395158LXJM',
  );
}
