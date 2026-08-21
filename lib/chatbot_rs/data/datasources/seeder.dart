import 'dart:convert';
import 'dart:developer';
import 'package:flutter/services.dart';
import 'local_datasource.dart';
import '../models/layanan_model.dart';
import '../models/jadwal_model.dart';

class DataSeeder {
  static Future<void> seedData() async {
    final dbHelper = DatabaseHelper.instance;
    if (await dbHelper.hasSeededHospitalData()) return;

    final String response = await rootBundle.loadString('assets/data_rs.json');
    final data = json.decode(response) as Map<String, dynamic>;

    final layananList = (data['layanan'] as List<dynamic>)
        .map((item) => LayananModel.fromMap(item as Map<String, dynamic>))
        .toList();
    final jadwalList = (data['jadwal_dokter'] as List<dynamic>)
        .map((item) => JadwalModel.fromMap(item as Map<String, dynamic>))
        .toList();

    await dbHelper.seedHospitalData(layananList, jadwalList);

    log('Data seeded successfully');
  }
}
