import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class PDFService {
  Future<void> generateAndShareHistory() async {
    try {
      if (Platform.isAndroid) {
        await Permission.storage.request();
      }

      final pdf = pw.Document();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      final checkupSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('Checkups')
          .orderBy('TimeStamp', descending: true)
          .get();

      final medSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('Medication')
          .get();

      List<pw.Widget> content = [];

      content.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('BAYMAX HEALTH REPORT', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.Text(DateFormat('dd MMM yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 12)),
          ],
        ),
      );
      content.add(pw.SizedBox(height: 20));

      content.add(pw.Text('PATIENT INFORMATION', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)));
      content.add(pw.Divider(thickness: 1, color: PdfColors.grey300));
      content.add(pw.SizedBox(height: 8));
      content.add(pw.Row(
        children: [
          pw.Expanded(child: _buildInfoItem('Name', userData['name'] ?? 'N/A')),
          pw.Expanded(child: _buildInfoItem('Email', userData['email'] ?? 'N/A')),
        ],
      ));
      content.add(pw.Row(
        children: [
          pw.Expanded(child: _buildInfoItem('Age', (userData['age'] ?? '--').toString())),
          pw.Expanded(child: _buildInfoItem('Blood Group', userData['blood'] ?? 'N/A')),
          pw.Expanded(child: _buildInfoItem('Report ID', user.uid.substring(0, 8).toUpperCase())),
        ],
      ));
      content.add(pw.SizedBox(height: 32));

      content.add(pw.Text('HEALTH CHECK-UP HISTORY', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)));
      content.add(pw.SizedBox(height: 12));

      if (checkupSnapshot.docs.isEmpty) {
        content.add(pw.Text('No check-up records found.', style: const pw.TextStyle(color: PdfColors.grey600)));
      } else {
        content.add(
          pw.Table.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey900),
            cellStyle: const pw.TextStyle(fontSize: 9),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(3),
              3: const pw.FlexColumnWidth(3.5),
            },
            headers: ['Date/Time', 'Vitals', 'Symptom Tags', 'Algorithm Guidance'],
            data: checkupSnapshot.docs.map((doc) {
              final d = doc.data();
              final ts = d['TimeStamp'] as Timestamp?;
              final dateStr = ts != null ? DateFormat('dd/MM/yy\nhh:mm a').format(ts.toDate()) : 'N/A';
              
              final vitals = 'T: ${d['Temp']}C\nHR: ${d['HeartRate']}\nO2: ${d['SpO2']}%';
              
              String symptoms = 'N/A';
              if (d['SymptomsJson'] != null) {
                final list = d['SymptomsJson']['symptoms_detected'] as List?;
                if (list != null) symptoms = list.join(', ').replaceAll('_', ' ');
              } else if (d['Observation'] != null) {
                symptoms = d['Observation'];
              }

              return [
                dateStr,
                vitals,
                symptoms,
                d['AIOutput'] ?? 'Normal'
              ];
            }).toList(),
          ),
        );
      }
      content.add(pw.SizedBox(height: 32));

      content.add(pw.Text('MEDICATION ADHERENCE LOGS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)));
      content.add(pw.SizedBox(height: 12));

      if (medSnapshot.docs.isEmpty) {
        content.add(pw.Text('No medications on record.', style: const pw.TextStyle(color: PdfColors.grey600)));
      } else {
        for (var medDoc in medSnapshot.docs) {
          final medData = medDoc.data();
          
          final takenLogs = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('Medication')
              .doc(medDoc.id)
              .collection('Taken')
              .orderBy('Time', descending: true)
              .get();

          content.add(
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 15),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(medData['Name'] ?? 'Unknown Med', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      pw.Text(medData['Food Relation'] ?? '', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Text('Indication: ${medData['Symptoms'] ?? 'General'}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  pw.SizedBox(height: 8),
                  pw.Text('Doses Taken Today/Recently:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  if (takenLogs.docs.isEmpty)
                    pw.Text('No intake logged.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500))
                  else
                    pw.Wrap(
                      spacing: 5,
                      children: takenLogs.docs.take(10).map((t) {
                        final time = (t.get('Time') as Timestamp).toDate();
                        return pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                          child: pw.Text(DateFormat('dd MMM, hh:mm a').format(time), style: const pw.TextStyle(fontSize: 8)),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          );
        }
      }

      content.add(pw.SizedBox(height: 40));
      content.add(pw.Center(child: pw.Text('*** End of Report ***', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500))));

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => content,
      ));

      final directory = Platform.isAndroid 
          ? await getExternalStorageDirectory() 
          : await getApplicationDocumentsDirectory();
      
      final file = File('${directory!.path}/Baymax_Health_Report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], text: 'My Baymax Health Report');
      
    } catch (e) {
      // Error
    }
  }

  pw.Widget _buildInfoItem(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label.toUpperCase(), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
