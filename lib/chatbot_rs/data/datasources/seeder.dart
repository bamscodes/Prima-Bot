import 'dart:convert';
import 'package:flutter/services.dart';
import 'local_datasource.dart';
import '../models/layanan_model.dart';
import '../models/jadwal_model.dart';

class DataSeeder {
  static Future<void> seedData() async {
    final dbHelper = DatabaseHelper.instance;
    
    // Check if data already exists to avoid duplicates (simplified: clear and re-seed for this demo)
    await dbHelper.clearAll();

    final String response = await rootBundle.loadString('assets/data_rs.json');
    final data = await json.decode(response);

    final List<dynamic> layananList = data['layanan'];
    for (var item in layananList) {
      await dbHelper.insertLayanan(LayananModel.fromMap(item));
    }

    final List<dynamic> jadwalList = data['jadwal_dokter'];
    for (var item in jadwalList) {
      await dbHelper.insertJadwal(JadwalModel.fromMap(item));
    }
    
    print('Data seeded successfully');
  }
}
