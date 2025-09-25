// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/actions/actions.dart' as action_blocks;
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:qr_code_tools/qr_code_tools.dart';
import '/custom_code/actions/index.dart';

class QRScanWidget extends StatefulWidget {
  const QRScanWidget({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  State<QRScanWidget> createState() => _QRScanWidgetState();
}

class _QRScanWidgetState extends State<QRScanWidget> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;

  bool isProcessing = false;
  String? lastScannedCode;
  bool hasPermission = false;
  bool isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
    initBranchListener();
  }

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    } else if (Platform.isIOS) {
      controller?.resumeCamera();
    }
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isDenied) {
      final result = await Permission.camera.request();
      setState(() {
        hasPermission = result.isGranted;
      });
    } else {
      setState(() {
        hasPermission = status.isGranted;
      });
    }
  }

  void initBranchListener() {
    FlutterBranchSdk.listSession().listen((data) async {
      print('Branch listener data: $data');

      if (data.containsKey('+clicked_branch_link') &&
          data['+clicked_branch_link'] == true) {
        try {
          // Use checkEventInvite to process the data
          final deeplinkInfo = await checkEventInvite(data);
          final eventId = deeplinkInfo.eventId;

          if (eventId.isNotEmpty && eventId != 'null') {
            print('Branch listener found eventId: $eventId');

            // Save deeplink info to app state
            FFAppState().DeeplinkInfo = deeplinkInfo;
            FFAppState().update(() {});

            // Reset processing state if we're currently processing
            if (isProcessing && mounted) {
              setState(() {
                isProcessing = false;
              });
            }

            navigateToEventDetail(eventId);
          } else {
            print('Invalid eventId from Branch: "$eventId"');
            // Reset processing state if we're currently processing
            if (isProcessing && mounted) {
              setState(() {
                isProcessing = false;
              });
              showError(
                  'This QR code contains an invalid event. Please contact the event organizer.');
            }
          }
        } catch (e) {
          print('Error processing Branch link in listener: $e');
        }
      }
    });
  }

  Future<void> handleQRCode(String code) async {
    print('handleQRCode called with: $code');

    if (isProcessing) {
      print('Already processing, returning');
      return;
    }

    setState(() {
      isProcessing = true;
      lastScannedCode = code;
    });

    try {
      print('Checking if code contains linkedupclub.app.link');
      // Check if it's a Branch link
      if (code.contains('linkedupclub.app.link')) {
        print('Processing Branch link: $code');

        // Reset processing state
        setState(() {
          isProcessing = false;
        });

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Processing event QR code...',
                style: TextStyle(
                  color: FlutterFlowTheme.of(context).primaryText,
                ),
              ),
              backgroundColor: FlutterFlowTheme.of(context).secondary,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // Handle the Branch link
        FlutterBranchSdk.handleDeepLink(code);

        // Wait for Branch to process the link
        await Future.delayed(const Duration(milliseconds: 500));

        // The Branch listener in initBranchListener will handle navigation
        print('Branch link handled, waiting for listener to navigate');
      } else {
        // Not a valid Branch link
        showError('Invalid QR code. Please scan a valid event QR code.');
        setState(() {
          isProcessing = false;
        });
      }
    } catch (e) {
      print('Error processing QR code: $e');
      showError('Error processing QR code: ${e.toString()}');
      setState(() {
        isProcessing = false;
      });
    } finally {
      // Clear last scanned code after a delay to allow rescanning
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          lastScannedCode = null;
        }
      });
    }
  }

  void navigateToEventDetail(String eventId) {
    print('Navigating to event detail with eventId: $eventId');

    if (!mounted) {
      print('Widget is not mounted, cannot navigate');
      return;
    }

    // Navigate to event detail page
    context.pushNamed(
      'EventDetail',
      pathParameters: {
        'eventId': eventId,
      },
    );
  }

  void showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: FlutterFlowTheme.of(context).primaryText,
          ),
        ),
        backgroundColor: FlutterFlowTheme.of(context).error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void toggleTorch() {
    if (controller != null) {
      controller!.toggleFlash();
      controller!.getFlashStatus().then((status) {
        setState(() {
          isTorchOn = status ?? false;
        });
      });
    }
  }

  Future<void> pickAndScanImage() async {
    final ImagePicker picker = ImagePicker();

    try {
      // Pick image from gallery
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        setState(() {
          isProcessing = true;
        });

        // Add timeout to prevent hanging
        try {
          // Decode QR code from image with timeout
          final String? qrCode =
              await QrCodeToolsPlugin.decodeFrom(image.path).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              print('QR code decoding timed out');
              return null;
            },
          );

          print('QR Code decoded: $qrCode');

          if (qrCode != null && qrCode.isNotEmpty) {
            // Reset processing state before handling QR code
            // to avoid the isProcessing check in handleQRCode
            setState(() {
              isProcessing = false;
            });

            // Process the decoded QR code
            await handleQRCode(qrCode);
          } else {
            showError('No QR code found in the selected image');
            setState(() {
              isProcessing = false;
            });
          }
        } catch (decodeError) {
          print('Error decoding QR: $decodeError');
          showError('Unable to read QR code from image');
          setState(() {
            isProcessing = false;
          });
        }
      }
    } catch (e) {
      print('Image picker error: $e');
      showError('Failed to select image: ${e.toString()}');
      setState(() {
        isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width ?? MediaQuery.of(context).size.width,
      height: widget.height ?? MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Stack(
        children: [
          // Camera preview
          if (hasPermission)
            ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: QRView(
                key: qrKey,
                onQRViewCreated: (QRViewController controller) {
                  this.controller = controller;
                  controller.scannedDataStream.listen((scanData) {
                    final String? code = scanData.code;
                    if (code != null) {
                      handleQRCode(code);
                    }
                  });
                },
                overlay: QrScannerOverlayShape(
                  borderColor: FlutterFlowTheme.of(context).primary,
                  borderRadius: 12.0,
                  borderLength: 30.0,
                  borderWidth: 3.0,
                  cutOutSize: 250.0,
                ),
              ),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_alt_outlined,
                    size: 64.0,
                    color: FlutterFlowTheme.of(context).secondaryText,
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    'Camera permission required',
                    style: FlutterFlowTheme.of(context).bodyLarge,
                  ),
                  const SizedBox(height: 8.0),
                  TextButton(
                    onPressed: _checkCameraPermission,
                    child: Text(
                      'Grant Permission',
                      style: TextStyle(
                        color: FlutterFlowTheme.of(context).primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Instructions
          Positioned(
            top: 40.0,
            left: 0,
            right: 0,
            child: Text(
              'Scan Event QR Code',
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context).headlineSmall.override(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontSize: 20.0,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),

          // Loading indicator when processing
          if (isProcessing)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        FlutterFlowTheme.of(context).primary,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Text(
                      'Processing QR Code...',
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'Inter',
                            color: Colors.white,
                          ),
                    ),
                  ],
                ),
              ),
            ),

          // Action buttons row
          if (hasPermission)
            Positioned(
              bottom: 20.0,
              left: 20.0,
              right: 20.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Upload image button
                  FloatingActionButton(
                    heroTag: 'qr_scanner_upload_button',
                    mini: true,
                    backgroundColor: FlutterFlowTheme.of(context).primary,
                    onPressed: pickAndScanImage,
                    child: Icon(
                      Icons.photo_library,
                      color: Colors.white,
                    ),
                  ),
                  // Torch toggle button
                  FloatingActionButton(
                    heroTag: 'qr_scanner_torch_button',
                    mini: true,
                    backgroundColor: FlutterFlowTheme.of(context).primary,
                    onPressed: toggleTorch,
                    child: Icon(
                      isTorchOn ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
