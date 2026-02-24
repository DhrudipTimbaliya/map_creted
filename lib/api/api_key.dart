import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';

class ApiKey {
  static const String _placesApiKey = "AIzaSyB4OsZKR2hF7xBBCJR8sM2b6xf17v5DWZs";


  static String _serchedplace = "";

  /// GET
  static String get serchedplace {
  return _serchedplace;
  }

  /// SET
  static set serchedplace(String value) {
  _serchedplace = value;
  }

  final url =
      "https://maps.googleapis.com/maps/api/geocode/json?address=$_serchedplace&key=$_placesApiKey";

}