import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:nbro_mobile_application/domain/models/inspection.dart';

/// Professional PDF Report Generator matching official NBRO Pre-Crack Survey Format
class PDFReportService {
  /// Generate a Pre-Crack Survey Report PDF matching NBRO official format
  static Future<File> generateInspectionReport(Inspection inspection) async {
    try {
      if (kDebugMode) {
        print('Starting PDF generation for inspection: ${inspection.id}');
      }

      final pdf = pw.Document();

      // Pre-load logo asset & images
      final logoImage = await _loadLogo();
      final buildingImage = await _loadImage(inspection.buildingPhotoUrl);

      final defectImageMap = <String, pw.MemoryImage?>{};
      for (final defect in inspection.defects) {
        final img = await _loadImage(defect.photoUrl ?? defect.photoPath);
        defectImageMap[defect.id] = img;
      }

      // Add PDF pages
      _addAnnexPage(pdf, logoImage);
      _addCoverPage(pdf, inspection, buildingImage, logoImage);
      _addSiteDataSheet(pdf, inspection, logoImage);
      _addBuildingDetailsPage(pdf, inspection, logoImage);
      if (inspection.defects.isNotEmpty) {
        _addDefectsPages(pdf, inspection, defectImageMap, logoImage);
      }

      // Save PDF to device storage
      final output = await _getOutputFile(inspection.id);
      final bytes = await pdf.save();
      await output.writeAsBytes(bytes);

      if (kDebugMode) {
        print('✓ PDF saved successfully to: ${output.path}');
      }

      return output;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error generating PDF: $e');
      }
      rethrow;
    }
  }

  /// Load NBRO emblem logo from assets
  static Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final logoBytes = await rootBundle.load('assets/icons/nbro_logo.png');
      return pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {
      debugPrint('[PDFReportService] Logo load exception: $e');
      return null;
    }
  }

  /// Helper to load image bytes into pw.MemoryImage
  static Future<pw.MemoryImage?> _loadImage(String? pathOrUrl) async {
    if (pathOrUrl == null || pathOrUrl.isEmpty) return null;
    try {
      if (pathOrUrl.startsWith('http')) {
        final response = await http
            .get(Uri.parse(pathOrUrl))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          return pw.MemoryImage(response.bodyBytes);
        }
      } else {
        final file = File(pathOrUrl);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          return pw.MemoryImage(bytes);
        }
      }
    } catch (e) {
      debugPrint('[PDFReportService] Image load exception ($pathOrUrl): $e');
    }
    return null;
  }

  /// Vector-drawn checkmark cell widget (Adjusted for PDF bottom-left origin)
  static pw.Widget _checkCell(bool checked, {double size = 9.0}) {
    if (checked) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(3),
        alignment: pw.Alignment.center,
        child: pw.Container(
          width: size,
          height: size,
          child: pw.CustomPaint(
            painter: (canvas, size) {
              canvas.setStrokeColor(PdfColors.black);
              canvas.setLineWidth(1.4);
              canvas.moveTo(size.x * 0.15, size.y * 0.55);
              canvas.lineTo(size.x * 0.40, size.y * 0.20);
              canvas.lineTo(size.x * 0.85, size.y * 0.80);
              canvas.strokePath();
            },
          ),
        ),
      );
    } else {
      return pw.Container(
        padding: const pw.EdgeInsets.all(3),
        alignment: pw.Alignment.center,
        child: pw.Text('-', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black)),
      );
    }
  }

  /// Vector checkmark inline badge for text options
  static pw.Widget _checkMarkInline(String label, bool isChecked) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
        pw.SizedBox(width: 4),
        if (isChecked)
          pw.Container(
            width: 8,
            height: 8,
            child: pw.CustomPaint(
              painter: (canvas, size) {
                canvas.setStrokeColor(PdfColors.black);
                canvas.setLineWidth(1.3);
                canvas.moveTo(size.x * 0.15, size.y * 0.55);
                canvas.lineTo(size.x * 0.40, size.y * 0.20);
                canvas.lineTo(size.x * 0.85, size.y * 0.80);
                canvas.strokePath();
              },
            ),
          )
        else
          pw.Text('(-)', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
      ],
    );
  }

  /// Page 0: Annex-I - Defects Order Reference Sheet
  static void _addAnnexPage(pw.Document pdf, pw.MemoryImage? logoImage) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Row(
                    children: [
                      if (logoImage != null) ...[
                        pw.Image(logoImage, height: 22, fit: pw.BoxFit.contain),
                        pw.SizedBox(width: 8),
                      ],
                      pw.Text('NBRO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ],
                  ),
                  pw.Text('Annex - I\nSER & PMD', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Divider(thickness: 1.5, color: PdfColors.black),
              pw.SizedBox(height: 8),

              // Title Box
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoImage != null) ...[
                      pw.Container(
                        width: 40,
                        height: 40,
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      ),
                      pw.SizedBox(width: 8),
                    ],
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          pw.Text('NATIONAL BUILDING RESEARCH ORGANISATION', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10.5)),
                          pw.SizedBox(height: 3),
                          pw.Text('STRUCTURAL ENGINEERING RESEARCH & PROJECT MANAGEMENT DIVISION', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                          pw.SizedBox(height: 4),
                          pw.Text('CONTENT : DEFECTS ORDER FOR PRE CRACK SURVEY PHOTO TABLE WORK', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, decoration: pw.TextDecoration.underline)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // Reference Table
              pw.Table(
                border: pw.TableBorder.all(width: 0.8),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2.0),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1.2),
                  3: const pw.FlexColumnWidth(2.5),
                  4: const pw.FlexColumnWidth(3.0),
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _cell('Type of Photo Table', bold: true, align: pw.TextAlign.center),
                      _cell('Defect Type', bold: true, align: pw.TextAlign.center),
                      _cell('Defect Notation', bold: true, align: pw.TextAlign.center),
                      _cell('Description of the Defect', bold: true, align: pw.TextAlign.center),
                      _cell('Remarks', bold: true, align: pw.TextAlign.center),
                    ],
                  ),
                  // Type 01 - Building Floor
                  pw.TableRow(
                    children: [
                      _cell('Type 01-\nConsidering a building floor\n\n(Basement, Ground floor, First floor, Second floor, ...etc. & Roof top floor/roof & ceiling)', bold: true, fontSize: 8),
                      _cell('01. Cracks', fontSize: 8),
                      _cell('1) C\n2) BC\n3) CC\n4) FC\n5) SC\n6) TC', fontSize: 8),
                      _cell('Wall Crack\nBeam Crack\nColumn Crack\nFloor Crack\nSlab Crack\nTile Crack', fontSize: 8),
                      _cell('', fontSize: 8),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _cell(''),
                      _cell('02. Separations', fontSize: 8),
                      _cell('1) SP', fontSize: 8),
                      _cell('Separation\n(Nature should be contained in remark column)', fontSize: 8),
                      _cell('i) Wall-wall Separation\nii) Beam-wall Separation\niii) Column-wall Separation\niv) Floor-wall Separation\nv) Slab-beam Separation', fontSize: 7.5),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _cell(''),
                      _cell('03. Damages', fontSize: 8),
                      _cell('1) D\n2) WD\n3) BD\n4) CD\n5) FD\n6) SD\n7) TD\n8) GD\n9) PD\n10) RD', fontSize: 8),
                      _cell('Damaged Area\nWall Damage\nBeam Damage\nColumn Damage\nFloor Damage\nSlab Damage\nTile Damage\nGlass Damage\nPlaster Damage\nRoof Damage', fontSize: 8),
                      _cell('Example types of Damages (D)\ni) Sun shed Damage\nii) Ceiling Damage\niii) Door/Window Frame Damages\niv) Other Damages\n\n❖ Tile debonding areas can be noted under the tile damages remark', fontSize: 7.5),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _cell(''),
                      _cell('04. Patches', fontSize: 8),
                      _cell('1) DP', fontSize: 8),
                      _cell('Damp Patch\n(Nature should be contained in remark)', fontSize: 8),
                      _cell('i) Damp patch on wall\nii) Damp patch on slab\niii) Damp patch on beam\niv) Damp patch on column', fontSize: 7.5),
                    ],
                  ),
                  // Type 02 - Boundary Wall
                  pw.TableRow(
                    children: [
                      _cell('Type 02-\nConsidering Boundary wall', bold: true, fontSize: 8),
                      _cell('01. Cracks', fontSize: 8),
                      _cell('1) BWC', fontSize: 8),
                      _cell('Boundary Wall Crack', fontSize: 8),
                      _cell('', fontSize: 8),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _cell(''),
                      _cell('02. Separations', fontSize: 8),
                      _cell('1) BWSP', fontSize: 8),
                      _cell('Boundary Wall Separation', fontSize: 8),
                      _cell('', fontSize: 8),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _cell(''),
                      _cell('03. Damages', fontSize: 8),
                      _cell('1) BWD', fontSize: 8),
                      _cell('Boundary Wall Damage', fontSize: 8),
                      _cell('', fontSize: 8),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _cell(''),
                      _cell('04. Patches', fontSize: 8),
                      _cell('1) BWDP', fontSize: 8),
                      _cell('Damp Patch on Boundary Wall', fontSize: 8),
                      _cell('', fontSize: 8),
                    ],
                  ),
                ],
              ),

              pw.Spacer(),
              _buildFooter(logoImage),
            ],
          );
        },
      ),
    );
  }

  /// Page 1: Cover Page - Crack Description Sheet
  static void _addCoverPage(
    pw.Document pdf,
    Inspection inspection,
    pw.MemoryImage? buildingImage,
    pw.MemoryImage? logoImage,
  ) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPageTopHeader('PRE-CRACK SURVEY REPORT', logoImage),
              pw.SizedBox(height: 12),

              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'PRE-CRACK SURVEY REPORT ON BUILDINGS AROUND PREMISES',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11.5),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'AT ${inspection.siteAddress.toUpperCase()}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'FOR NATIONAL BUILDING RESEARCH ORGANISATION',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 12),
                    pw.Divider(thickness: 1),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'CRACK DESCRIPTION SHEET',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11.5),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // Building Info Box
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text('Building Reference No. : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text(inspection.id, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blue800)),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      children: [
                        pw.Text('Name of the Owner    : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text(inspection.ownerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // Front View Image Frame
              pw.Expanded(
                child: pw.Container(
                  width: double.infinity,
                  decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      if (buildingImage != null)
                        pw.Expanded(
                          child: pw.Image(buildingImage, fit: pw.BoxFit.contain),
                        )
                      else
                        pw.Expanded(
                          child: pw.Center(
                            child: pw.Text('[ Front View Building Photo Placeholder ]', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
                          ),
                        ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Front view of the building', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Text('Situation as at ${DateFormat('dd.MM.yyyy').format(inspection.createdAt)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              pw.SizedBox(height: 12),
              _buildFooter(logoImage),
            ],
          );
        },
      ),
    );
  }

  /// Page 2: Site Data Sheet
  static void _addSiteDataSheet(pw.Document pdf, Inspection inspection, pw.MemoryImage? logoImage) {
    final typeStr = inspection.typeOfStructure?.toLowerCase() ?? 'house';
    final condStr = inspection.presentCondition?.toLowerCase() ?? 'permanent';
    final isWaterSupply = inspection.hasPipeBorneWater == true;
    final isElectricity = inspection.hasElectricity == true;
    final isSewage = inspection.hasSewageWaste == true;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPageTopHeader('PRE-CRACK SURVEY REPORT', logoImage),
              pw.SizedBox(height: 10),

              // Header Block
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                child: pw.Column(
                  children: [
                    pw.Text('PRE-CRACK SURVEY REPORT ON BUILDINGS AROUND PREMISES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Text('AT ${inspection.siteAddress.toUpperCase()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    pw.SizedBox(height: 4),
                    pw.Text('SITE DATA SHEET', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, decoration: pw.TextDecoration.underline)),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // Premises Table
              pw.Table(
                border: pw.TableBorder.all(width: 0.8),
                children: [
                  pw.TableRow(children: [
                    _cell('Name of Owner', bold: true, fontSize: 8),
                    _cell(inspection.ownerName, fontSize: 8),
                    _cell('Building Ref. No.', bold: true, fontSize: 8),
                    _cell(inspection.id, bold: true, fontSize: 8),
                  ]),
                  pw.TableRow(children: [
                    _cell('Address of Premises', bold: true, fontSize: 8),
                    _cell(inspection.siteAddress, fontSize: 8),
                    _cell('', fontSize: 8),
                    _cell('', fontSize: 8),
                  ]),
                  pw.TableRow(children: [
                    _cell('Contact No.', bold: true, fontSize: 8),
                    _cell(inspection.contactNo ?? '-', fontSize: 8),
                    _cell('', fontSize: 8),
                    _cell('', fontSize: 8),
                  ]),
                  pw.TableRow(children: [
                    _cell('Location of premises', bold: true, fontSize: 8),
                    _cell('GPS Coordinates:\nN: ${inspection.latitude?.toStringAsFixed(6) ?? '-'}\nE: ${inspection.longitude?.toStringAsFixed(6) ?? '-'}', fontSize: 8),
                    _cell('Distance from Row in meters', bold: true, fontSize: 8),
                    _cell('${inspection.distanceFromRow?.toString() ?? 'Adjacent'} m', fontSize: 8),
                  ]),
                ],
              ),
              pw.SizedBox(height: 10),

              // 1. General Observations
              pw.Text('1. General Observations', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.SizedBox(height: 4),
              pw.Table(
                border: pw.TableBorder.all(width: 0.8),
                columnWidths: {0: const pw.FixedColumnWidth(24)},
                children: [
                  pw.TableRow(children: [
                    _cell('1.1', bold: true, fontSize: 8),
                    _cell('Approx. Age of existing structures', fontSize: 8),
                    _cell('${inspection.ageOfStructure ?? '-'} years', fontSize: 8),
                  ]),
                  pw.TableRow(children: [
                    _cell('1.2', bold: true, fontSize: 8),
                    _cell('Types of existing structures', fontSize: 8),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Wrap(
                        spacing: 8,
                        children: [
                          _checkMarkInline('Office', typeStr.contains('office')),
                          _checkMarkInline('House', typeStr.contains('house')),
                          _checkMarkInline('Shops', typeStr.contains('shop')),
                          _checkMarkInline('Workshops', typeStr.contains('workshop')),
                        ],
                      ),
                    ),
                  ]),
                  pw.TableRow(children: [
                    _cell('1.3', bold: true, fontSize: 8),
                    _cell('Present condition of existing structure/s', fontSize: 8),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Row(
                        children: [
                          _checkMarkInline('Permanent', condStr.contains('permanent') && !condStr.contains('semi')),
                          pw.SizedBox(width: 10),
                          _checkMarkInline('Semi-permanent', condStr.contains('semi')),
                          pw.SizedBox(width: 10),
                          _checkMarkInline('Temporary', condStr.contains('temporary')),
                        ],
                      ),
                    ),
                  ]),
                ],
              ),
              pw.SizedBox(height: 10),

              // 2. External Services
              pw.Text('2. External Services', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.SizedBox(height: 4),
              pw.Table(
                border: pw.TableBorder.all(width: 0.8),
                columnWidths: {0: const pw.FixedColumnWidth(24)},
                children: [
                  pw.TableRow(children: [
                    _cell('2.1', bold: true, fontSize: 8),
                    _cell('Pipe born water supply', fontSize: 8),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Row(
                        children: [
                          _checkMarkInline('From Well', (inspection.waterSource?.toLowerCase() ?? '').contains('well')),
                          pw.SizedBox(width: 16),
                          _checkMarkInline('From main supply', isWaterSupply && !(inspection.waterSource?.toLowerCase() ?? '').contains('well')),
                        ],
                      ),
                    ),
                  ]),
                  pw.TableRow(children: [
                    _cell('2.2', bold: true, fontSize: 8),
                    _cell('Electricity Main Supply', fontSize: 8),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Row(
                        children: [
                          _checkMarkInline('From Private/Solar', (inspection.electricitySource?.toLowerCase() ?? '').contains('solar')),
                          pw.SizedBox(width: 16),
                          _checkMarkInline('From Main supply', isElectricity && !(inspection.electricitySource?.toLowerCase() ?? '').contains('solar')),
                        ],
                      ),
                    ),
                  ]),
                  pw.TableRow(children: [
                    _cell('2.3', bold: true, fontSize: 8),
                    _cell('Sewage & Wasted Water Disposal', fontSize: 8),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Row(
                        children: [
                          _checkMarkInline('Private Septic tank System', isSewage && !(inspection.sewageType?.toLowerCase() ?? '').contains('sewer main')),
                          pw.SizedBox(width: 16),
                          _checkMarkInline('Connected to Sewer Mains', (inspection.sewageType?.toLowerCase() ?? '').contains('sewer main')),
                        ],
                      ),
                    ),
                  ]),
                ],
              ),
              pw.SizedBox(height: 10),

              // 3. Ancillary Buildings
              pw.Text('3. Details of Ancillary Buildings/Structures', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.SizedBox(height: 4),
              pw.Table(
                border: pw.TableBorder.all(width: 0.8),
                columnWidths: {
                  0: const pw.FixedColumnWidth(24),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                  4: const pw.FlexColumnWidth(1),
                  5: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _cell(''),
                      _cell('Details', bold: true, fontSize: 8),
                      _cell('Front', bold: true, align: pw.TextAlign.center, fontSize: 8),
                      _cell('Left', bold: true, align: pw.TextAlign.center, fontSize: 8),
                      _cell('Right', bold: true, align: pw.TextAlign.center, fontSize: 8),
                      _cell('Rear', bold: true, align: pw.TextAlign.center, fontSize: 8),
                    ],
                  ),
                  pw.TableRow(children: [
                    _cell('3.1', bold: true, fontSize: 8),
                    _cell('Boundary walls (Block work / Plastered)', fontSize: 8),
                    _checkCell(true),
                    _checkCell(true),
                    _checkCell(true),
                    _checkCell(true),
                  ]),
                  pw.TableRow(children: [
                    _cell('3.2', bold: true, fontSize: 8),
                    _cell('Others (Gate / External Toilets)', fontSize: 8),
                    _checkCell(false),
                    _checkCell(true),
                    _checkCell(false),
                    _checkCell(false),
                  ]),
                ],
              ),

              pw.Spacer(),
              _buildFooter(logoImage),
            ],
          );
        },
      ),
    );
  }

  /// Page 3: Details of Main Building Elements
  static void _addBuildingDetailsPage(pw.Document pdf, Inspection inspection, pw.MemoryImage? logoImage) {
    bool hasWall = inspection.wallMaterials != null && inspection.wallMaterials!.isNotEmpty;
    bool hasDoor = inspection.doorMaterials != null && inspection.doorMaterials!.isNotEmpty;
    bool hasFloor = inspection.floorMaterials != null && inspection.floorMaterials!.isNotEmpty;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPageTopHeader('PRE-CRACK SURVEY REPORT', logoImage),
              pw.SizedBox(height: 10),

              pw.Text('4. Details of Main Building Elements', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.SizedBox(height: 8),

              pw.Table(
                border: pw.TableBorder.all(width: 0.8),
                columnWidths: {
                  0: const pw.FixedColumnWidth(24),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(3),
                  3: const pw.FlexColumnWidth(1),
                  4: const pw.FlexColumnWidth(1.2),
                  5: const pw.FlexColumnWidth(1),
                  6: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _cell('4.1', bold: true, fontSize: 8),
                      _cell('No of Floors', bold: true, fontSize: 8),
                      _cell(inspection.numberOfFloors ?? 'G+1', bold: true, fontSize: 8),
                      _cell('Basement', bold: true, align: pw.TextAlign.center, fontSize: 7.5),
                      _cell('Ground Floor', bold: true, align: pw.TextAlign.center, fontSize: 7.5),
                      _cell('1st', bold: true, align: pw.TextAlign.center, fontSize: 7.5),
                      _cell('2nd', bold: true, align: pw.TextAlign.center, fontSize: 7.5),
                    ],
                  ),
                  pw.TableRow(children: [
                    _cell('4.2', bold: true, fontSize: 8),
                    _cell('Walls', bold: true, fontSize: 8),
                    _cell(_getMaterialsList(inspection.wallMaterials), fontSize: 8),
                    _checkCell(false),
                    _checkCell(hasWall),
                    _checkCell(hasWall),
                    _checkCell(false),
                  ]),
                  pw.TableRow(children: [
                    _cell('4.3', bold: true, fontSize: 8),
                    _cell('Doors', bold: true, fontSize: 8),
                    _cell(_getMaterialsList(inspection.doorMaterials), fontSize: 8),
                    _checkCell(false),
                    _checkCell(hasDoor),
                    _checkCell(hasDoor),
                    _checkCell(false),
                  ]),
                  pw.TableRow(children: [
                    _cell('4.4', bold: true, fontSize: 8),
                    _cell('Floors', bold: true, fontSize: 8),
                    _cell(_getMaterialsList(inspection.floorMaterials), fontSize: 8),
                    _checkCell(false),
                    _checkCell(hasFloor),
                    _checkCell(hasFloor),
                    _checkCell(false),
                  ]),
                  pw.TableRow(children: [
                    _cell('4.5', bold: true, fontSize: 8),
                    _cell('Finishes', bold: true, fontSize: 8),
                    _cell('Smooth Plastered & Painted', fontSize: 8),
                    _checkCell(false),
                    _checkCell(true),
                    _checkCell(true),
                    _checkCell(false),
                  ]),
                  pw.TableRow(children: [
                    _cell('4.6', bold: true, fontSize: 8),
                    _cell('Roof Shape & Frame', bold: true, fontSize: 8),
                    _cell('${_getMaterialsList(inspection.roofMaterials)} / Timber Frame', fontSize: 8),
                    _checkCell(false),
                    _checkCell(true),
                    _checkCell(true),
                    _checkCell(false),
                  ]),
                  pw.TableRow(children: [
                    _cell(''),
                    _cell('Roof Covering', bold: true, fontSize: 8),
                    _cell(inspection.roofCovering ?? 'Clay Tiles / Asbestos', fontSize: 8),
                    _checkCell(false),
                    _checkCell(true),
                    _checkCell(true),
                    _checkCell(false),
                  ]),
                ],
              ),

              pw.SizedBox(height: 16),
              if (inspection.remarks != null && inspection.remarks!.isNotEmpty) ...[
                pw.Text('Remarks:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.SizedBox(height: 4),
                pw.Text(inspection.remarks!, style: const pw.TextStyle(fontSize: 9)),
              ],

              pw.Spacer(),
              _buildFooter(logoImage),
            ],
          );
        },
      ),
    );
  }

  /// Page 4 & 5: Defect Photo Tables
  static void _addDefectsPages(
    pw.Document pdf,
    Inspection inspection,
    Map<String, pw.MemoryImage?> defectImages,
    pw.MemoryImage? logoImage,
  ) {
    final buildingDefects = inspection.defects
        .where((d) => d.category == DefectCategory.buildingFloor)
        .toList();

    final boundaryDefects = inspection.defects
        .where((d) => d.category == DefectCategory.boundaryWall)
        .toList();

    if (buildingDefects.isNotEmpty) {
      _buildDefectTablePage(
        pdf: pdf,
        sectionTitle: '5. Details/ Photographs of Defects',
        subTitle: 'Ground floor defects',
        defects: buildingDefects,
        images: defectImages,
        logoImage: logoImage,
      );
    }

    if (boundaryDefects.isNotEmpty) {
      _buildDefectTablePage(
        pdf: pdf,
        sectionTitle: '5. Details/ Photographs of Defects',
        subTitle: 'Boundary wall defects',
        defects: boundaryDefects,
        images: defectImages,
        logoImage: logoImage,
      );
    }
  }

  static void _buildDefectTablePage({
    required pw.Document pdf,
    required String sectionTitle,
    required String subTitle,
    required List<Defect> defects,
    required Map<String, pw.MemoryImage?> images,
    required pw.MemoryImage? logoImage,
  }) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPageTopHeader('PRE-CRACK SURVEY REPORT', logoImage),
              pw.SizedBox(height: 8),

              pw.Text(sectionTitle, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.SizedBox(height: 6),

              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                child: pw.Text(subTitle, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              ),
              pw.SizedBox(height: 6),

              // Defects Table
              pw.Table(
                border: pw.TableBorder.all(width: 0.8),
                columnWidths: {
                  0: const pw.FixedColumnWidth(55),
                  1: const pw.FixedColumnWidth(40),
                  2: const pw.FixedColumnWidth(40),
                  3: const pw.FlexColumnWidth(3),
                  4: const pw.FlexColumnWidth(2.5),
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _cell('Defect No.', bold: true, align: pw.TextAlign.center, fontSize: 8),
                      _cell('Length (mm)', bold: true, align: pw.TextAlign.center, fontSize: 8),
                      _cell('Width (mm)', bold: true, align: pw.TextAlign.center, fontSize: 8),
                      _cell('Photograph/s of Defect', bold: true, align: pw.TextAlign.center, fontSize: 8),
                      _cell('Remarks', bold: true, align: pw.TextAlign.center, fontSize: 8),
                    ],
                  ),
                  // Defect Item Rows
                  ...defects.map((defect) {
                    final img = images[defect.id];
                    return pw.TableRow(
                      children: [
                        _cell(defect.notation.code, bold: true, align: pw.TextAlign.center, fontSize: 9),
                        _cell(defect.lengthMm.toStringAsFixed(0), align: pw.TextAlign.center, fontSize: 8),
                        _cell(defect.widthMm?.toStringAsFixed(1) ?? '-', align: pw.TextAlign.center, fontSize: 8),
                        pw.Container(
                          height: 90,
                          padding: const pw.EdgeInsets.all(4),
                          child: img != null
                              ? pw.Image(img, fit: pw.BoxFit.contain)
                              : pw.Center(child: pw.Text('[ Photo ]', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600))),
                        ),
                        _cell(
                          '${defect.notation.description}${defect.floorLevel != null ? ' at ${defect.floorLevel}' : ''}${defect.remarks != null ? '.\n${defect.remarks}' : ''}',
                          fontSize: 8,
                        ),
                      ],
                    );
                  }),
                ],
              ),

              pw.Spacer(),
              _buildFooter(logoImage),
            ],
          );
        }),
    );
  }

  // Common Top Header with NBRO Logo
  static pw.Widget _buildPageTopHeader(String title, pw.MemoryImage? logoImage) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoImage != null) ...[
                  pw.Image(logoImage, height: 22, fit: pw.BoxFit.contain),
                  pw.SizedBox(width: 8),
                ],
                pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5, letterSpacing: 0.5)),
              ],
            ),
            pw.Text('SER & PMD', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Divider(thickness: 1.5, color: PdfColors.black),
      ],
    );
  }

  // Common Running Footer with NBRO Logo
  static pw.Widget _buildFooter(pw.MemoryImage? logoImage) {
    return pw.Column(
      children: [
        pw.Divider(thickness: 1.5, color: PdfColors.black),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logoImage != null) ...[
              pw.Image(logoImage, height: 16, fit: pw.BoxFit.contain),
              pw.SizedBox(width: 6),
            ],
            pw.Text(
              'STRUCTURAL ENGINEERING RESEARCH & PROJECT MANAGEMENT DIVISION - NBRO',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5),
            ),
          ],
        ),
      ],
    );
  }

  // Common Table Cell
  static pw.Widget _cell(
    String text, {
    bool bold = false,
    double fontSize = 8.5,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  /// Get materials list as string
  static String _getMaterialsList(Map<String, bool>? materials) {
    if (materials == null || materials.isEmpty) return '-';
    final selected = materials.entries.where((e) => e.value).map((e) => e.key).toList();
    return selected.isEmpty ? '-' : selected.join(', ');
  }

  /// Get output file path
  static Future<File> _getOutputFile(String buildingRef) async {
    Directory directory;
    final fileName = 'NBRO_Inspection_${buildingRef}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';

    if (Platform.isAndroid) {
      try {
        if (await Permission.storage.isDenied) {
          await Permission.storage.request();
        }
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
          directory = downloadsDir;
        } else {
          directory = await getApplicationDocumentsDirectory();
        }
      } catch (_) {
        directory = await getApplicationDocumentsDirectory();
      }
    } else if (Platform.isIOS) {
      directory = await getApplicationDocumentsDirectory();
    } else {
      directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    }

    final filePath = '${directory.path}/$fileName';
    return File(filePath);
  }

  /// Preview PDF before saving
  static Future<void> previewPDF(Inspection inspection) async {
    try {
      final pdf = pw.Document();

      final logoImage = await _loadLogo();
      final buildingImage = await _loadImage(inspection.buildingPhotoUrl);
      final defectImageMap = <String, pw.MemoryImage?>{};
      for (final defect in inspection.defects) {
        defectImageMap[defect.id] = await _loadImage(defect.photoUrl ?? defect.photoPath);
      }

      _addAnnexPage(pdf, logoImage);
      _addCoverPage(pdf, inspection, buildingImage, logoImage);
      _addSiteDataSheet(pdf, inspection, logoImage);
      _addBuildingDetailsPage(pdf, inspection, logoImage);
      if (inspection.defects.isNotEmpty) {
        _addDefectsPages(pdf, inspection, defectImageMap, logoImage);
      }

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'NBRO_Inspection_${inspection.id}.pdf',
        format: PdfPageFormat.a4,
      );
    } catch (e) {
      debugPrint('Error previewing PDF: $e');
      rethrow;
    }
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
      debugPrint('Error sharing PDF: $e');
      rethrow;
    }
  }

  /// Open PDF file using default viewer
  static Future<void> openPDF(File file) async {
    try {
      final result = await OpenFilex.open(file.path);
      debugPrint('Open file result: ${result.message}');
    } catch (e) {
      debugPrint('Error opening PDF: $e');
      rethrow;
    }
  }
}
