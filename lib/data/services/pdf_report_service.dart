import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/models/inspection.dart';

class PDFReportService {
  /// Generate a Pre-Crack Survey Report PDF matching NBRO format
  static Future<File> generateInspectionReport(Inspection inspection) async {
    final pdf = pw.Document();
    
    // Load NBRO logo (if available)
    // final logo = await rootBundle.load('assets/icons/icon.png');
    // final logoImage = pw.MemoryImage(logo.buffer.asUint8List());

    // Add pages
    _addCoverPage(pdf, inspection);
    _addSiteDataSheet(pdf, inspection);
    _addBuildingDetailsPage(pdf, inspection);
    if (inspection.defects.isNotEmpty) {
      _addDefectsPages(pdf, inspection);
    }

    // Save PDF
    final output = await _getOutputFile(inspection.id);
    await output.writeAsBytes(await pdf.save());
    
    return output;
  }

  /// Get output file path
  static Future<File> _getOutputFile(String buildingRef) async {
    Directory directory;
    final fileName = 'NBRO_Inspection_${buildingRef}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
    
    if (Platform.isAndroid) {
      // Request storage permission for Android
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      
      // For Android 10+, use app-specific directory or Downloads
      if (await Permission.manageExternalStorage.isGranted || 
          await Directory('/storage/emulated/0/Download').exists()) {
        directory = Directory('/storage/emulated/0/Download');
      } else {
        // Fallback to external storage directory
        directory = (await getExternalStorageDirectory()) ?? await getApplicationDocumentsDirectory();
      }
    } else if (Platform.isIOS) {
      directory = await getApplicationDocumentsDirectory();
    } else {
      directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    }
    
    return File('${directory.path}/$fileName');
  }

  /// Add cover page
  static void _addCoverPage(pw.Document pdf, Inspection inspection) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 2),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'NBRO',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'NATIONAL BUILDING RESEARCH ORGANISATION',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'STRUCTURAL ENGINEERING RESEARCH & PROJECT',
                      style: const pw.TextStyle(fontSize: 10),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.Text(
                      'MANAGEMENT DIVISION',
                      style: const pw.TextStyle(fontSize: 10),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 40),

              // Report Title
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 1),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PRE-CRACK SURVEY REPORT ON BUILDINGS AROUND PREMISES',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'AT ${inspection.siteAddress.toUpperCase()}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              // Building Info
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 1),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'CRACK DESCRIPTION SHEET',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 15),
                    pw.Row(
                      children: [
                        pw.Text(
                          'Building Reference No. : ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(inspection.id),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        pw.Text(
                          'Name of the Owner : ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(inspection.ownerName),
                      ],
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // Footer
              pw.Center(
                child: pw.Text(
                  'Situation as at ${DateFormat('dd.MM.yyyy').format(inspection.createdAt)}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Add site data sheet
  static void _addSiteDataSheet(pw.Document pdf, Inspection inspection) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildPageHeader('PRE-CRACK SURVEY REPORT'),
              pw.SizedBox(height: 20),

              pw.Text(
                'SITE DATA SHEET',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
              pw.SizedBox(height: 20),

              // Site Information Table
              _buildInfoTable([
                ['Name of Owner', inspection.ownerName, '', ''],
                [
                  'Address of Premises',
                  inspection.siteAddress,
                  'Building Ref. No.',
                  inspection.id
                ],
                [
                  'Contact No.',
                  inspection.contactNo ?? 'N/A',
                  '',
                  ''
                ],
                [
                  'Location of premises',
                  'GPS Coordinates: ${inspection.latitude?.toStringAsFixed(6) ?? 'N/A'}, ${inspection.longitude?.toStringAsFixed(6) ?? 'N/A'}',
                  'Distance from Row in meters',
                  inspection.distanceFromRow?.toString() ?? 'N/A'
                ],
              ]),

              pw.SizedBox(height: 20),

              // General Observations
              pw.Text(
                '1. General Observations',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),

              _buildObservationTable([
                [
                  '1.1',
                  'Approx. Age of existing structures',
                  '${inspection.ageOfStructure ?? 'N/A'} years',
                  ''
                ],
                [
                  '1.2',
                  'Types of existing structures',
                  inspection.typeOfStructure ?? 'N/A',
                  ''
                ],
                [
                  '1.3',
                  'Present condition of existing structure/s',
                  inspection.presentCondition ?? 'N/A',
                  ''
                ],
              ]),

              pw.SizedBox(height: 20),

              // External Services
              pw.Text(
                '2. External Services',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),

              _buildObservationTable([
                [
                  '2.1',
                  'Pipe born water supply',
                  inspection.waterSource ?? 'N/A',
                  inspection.hasPipeBorneWater == true ? '✓' : '-'
                ],
                [
                  '2.2',
                  'Electricity Main Supply',
                  inspection.electricitySource ?? 'N/A',
                  inspection.hasElectricity == true ? '✓' : '-'
                ],
                [
                  '2.3',
                  'Sewage & Wasted Water Disposal',
                  inspection.sewageType ?? 'N/A',
                  inspection.hasSewageWaste == true ? '✓' : '-'
                ],
              ]),
            ],
          );
        },
      ),
    );
  }

  /// Add building details page
  static void _addBuildingDetailsPage(pw.Document pdf, Inspection inspection) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPageHeader('PRE-CRACK SURVEY REPORT'),
              pw.SizedBox(height: 20),

              // Building Elements
              pw.Text(
                '4. Details of Main Building Elements',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),

              _buildTable(
                headers: ['', 'No of Floors', 'G+${inspection.numberOfFloors ?? '0'}'],
                rows: [
                  ['4.2', 'Walls', _getMaterialsList(inspection.wallMaterials)],
                  ['4.3', 'Doors', _getMaterialsList(inspection.doorMaterials)],
                  ['4.4', 'Floors', _getMaterialsList(inspection.floorMaterials)],
                  ['', 'Roof', ''],
                  ['4.6', 'Shape', _getMaterialsList(inspection.roofMaterials)],
                  ['', 'Covering Material', inspection.roofCovering ?? 'N/A'],
                ],
              ),

              pw.SizedBox(height: 20),

              // Summary
              if (inspection.remarks != null && inspection.remarks!.isNotEmpty) ...[
                pw.Text(
                  'Remarks:',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  inspection.remarks!,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Add defects pages
  static void _addDefectsPages(pw.Document pdf, Inspection inspection) {
    // Group defects by category
    final buildingDefects = inspection.defects
        .where((d) => d.category == DefectCategory.buildingFloor)
        .toList();
    final boundaryDefects = inspection.defects
        .where((d) => d.category == DefectCategory.boundaryWall)
        .toList();

    if (buildingDefects.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildPageHeader('PRE-CRACK SURVEY REPORT'),
                pw.SizedBox(height: 20),

                pw.Text(
                  '5. Details/ Photographs of Defects',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 15),

                pw.Text(
                  'Ground floor defects',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),

                _buildDefectsTable(buildingDefects),
              ],
            );
          },
        ),
      );
    }

    if (boundaryDefects.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildPageHeader('PRE-CRACK SURVEY REPORT'),
                pw.SizedBox(height: 20),

                pw.Text(
                  'Boundary wall defects',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),

                _buildDefectsTable(boundaryDefects),
              ],
            );
          },
        ),
      );
    }
  }

  /// Build page header
  static pw.Widget _buildPageHeader(String title) {
    return pw.Column(
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Divider(thickness: 2),
      ],
    );
  }

  /// Build info table
  static pw.Widget _buildInfoTable(List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(),
      children: rows.map((row) {
        return pw.TableRow(
          children: row.map((cell) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                cell,
                style: const pw.TextStyle(fontSize: 10),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  /// Build observation table
  static pw.Widget _buildObservationTable(List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FixedColumnWidth(30),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FixedColumnWidth(30),
      },
      children: rows.map((row) {
        return pw.TableRow(
          children: row.map((cell) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                cell,
                style: const pw.TextStyle(fontSize: 9),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  /// Build generic table
  static pw.Widget _buildTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(),
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: headers.map((header) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                header,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
          }).toList(),
        ),
        // Data rows
        ...rows.map((row) {
          return pw.TableRow(
            children: row.map((cell) {
              return pw.Container(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  cell,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  /// Build defects table
  static pw.Widget _buildDefectsTable(List<Defect> defects) {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FixedColumnWidth(50),
        1: const pw.FixedColumnWidth(60),
        2: const pw.FixedColumnWidth(60),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(2),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _buildTableHeader('Defect No.'),
            _buildTableHeader('Length (mm)'),
            _buildTableHeader('Width (mm)'),
            _buildTableHeader('Photograph of Defect'),
            _buildTableHeader('Remarks'),
          ],
        ),
        // Defect rows
        ...defects.asMap().entries.map((entry) {
          final defect = entry.value;
          return pw.TableRow(
            children: [
              _buildTableCell(defect.notation.code),
              _buildTableCell(defect.lengthMm.toStringAsFixed(0)),
              _buildTableCell(defect.widthMm?.toStringAsFixed(0) ?? '-'),
              _buildTableCell('[Photo placeholder]'),
              _buildTableCell(
                '${defect.notation.description}${defect.floorLevel != null ? ' at ${defect.floorLevel}' : ''}${defect.remarks != null ? '\n${defect.remarks}' : ''}',
              ),
            ],
          );
        }),
      ],
    );
  }

  /// Build table header cell
  static pw.Widget _buildTableHeader(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  /// Build table cell
  static pw.Widget _buildTableCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 8),
      ),
    );
  }

  /// Get materials list as string
  static String _getMaterialsList(Map<String, bool>? materials) {
    if (materials == null || materials.isEmpty) return 'N/A';
    final selected = materials.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    return selected.isEmpty ? 'N/A' : selected.join(', ');
  }

  /// Preview PDF before saving
  static Future<void> previewPDF(Inspection inspection) async {
    final pdf = pw.Document();
    
    _addCoverPage(pdf, inspection);
    _addSiteDataSheet(pdf, inspection);
    _addBuildingDetailsPage(pdf, inspection);
    if (inspection.defects.isNotEmpty) {
      _addDefectsPages(pdf, inspection);
    }

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'NBRO_Inspection_${inspection.id}.pdf',
      format: PdfPageFormat.a4,
    );
  }

  /// Share PDF file
  static Future<void> sharePDF(File file, String fileName) async {
    try {
      final xFile = XFile(file.path);
      await Share.shareXFiles(
        [xFile],
        subject: 'NBRO Inspection Report - $fileName',
        text: 'Pre-Crack Survey Report from NBRO Mobile Application',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error sharing PDF: $e');
      }
      rethrow;
    }
  }

  /// Open PDF file using default viewer
  static Future<void> openPDF(File file) async {
    try {
      final result = await OpenFilex.open(file.path);
      if (kDebugMode) {
        print('Open file result: ${result.message}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error opening PDF: $e');
      }
      rethrow;
    }
  }
}
