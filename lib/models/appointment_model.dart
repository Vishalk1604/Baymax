import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentModel {
  final String? id;
  final String clinicId;
  final String clinicName;
  final String doctorName;
  final DateTime dateTime;
  final String status;

  AppointmentModel({
    this.id,
    required this.clinicId,
    required this.clinicName,
    required this.doctorName,
    required this.dateTime,
    this.status = 'Upcoming',
  });

  Map<String, dynamic> toMap() {
    return {
      'clinicId': clinicId,
      'clinicName': clinicName,
      'DoctorName': doctorName, // Match existing schema if any
      'Time': Timestamp.fromDate(dateTime),
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
