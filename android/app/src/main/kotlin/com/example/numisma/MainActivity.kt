package com.example.numisma

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (bukan FlutterActivity) karena paket local_auth
// menampilkan dialog biometrik lewat Fragment (NUMISMA_GUIDE Bagian 3).
class MainActivity : FlutterFragmentActivity()
