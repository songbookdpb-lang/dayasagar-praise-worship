// lib/services/cloudinary_service.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CloudinaryService {
  static const String _cloudName = 'dqejqhxsi';
  static const String _apiKey = '541955271245169';
  
  static Future<String?> uploadImageUnsigned(File imageFile, String fileName) async {
    print('🌥️ CloudinaryService: Starting upload');
    print('🌥️ Cloud name: $_cloudName');
    print('🌥️ API key: $_apiKey');
    print('🌥️ File name: $fileName');
    
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
      print('🌐 Upload URL: $url');
      
      final request = http.MultipartRequest('POST', url);
      print('📤 Created POST request');
      
      // Check if file exists before upload
      if (!await imageFile.exists()) {
        throw Exception('File does not exist: ${imageFile.path}');
      }
      
      final fileSize = await imageFile.length();
      print('📊 File size: $fileSize bytes');
      
      // Add the file
      print('📎 Adding file to request...');
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        filename: fileName,
      ));
      print('✅ File added to request');
      
      // Use unsigned upload preset
      request.fields['upload_preset'] = 'donate_qr_uploads';
      request.fields['folder'] = 'donate_qr_codes';
      
      print('📋 Request fields:');
      request.fields.forEach((key, value) {
        print('   $key: $value');
      });
      
      print('🚀 Sending request to Cloudinary...');
      final response = await request.send();
      
      print('📨 Response received');
      print('📊 Status code: ${response.statusCode}');
      print('📊 Content length: ${response.contentLength}');
      print('📊 Response headers:');
      response.headers.forEach((key, value) {
        print('   $key: $value');
      });
      
      final responseData = await response.stream.toBytes();
      final responseString = String.fromCharCodes(responseData);
      
      print('📄 Response body length: ${responseString.length} characters');
      print('📄 Response body: $responseString');
      
      if (response.statusCode == 200) {
        print('✅ Upload successful (200 OK)');
        
        final Map<String, dynamic> data = json.decode(responseString);
        print('📊 Parsed response data:');
        data.forEach((key, value) {
          print('   $key: $value');
        });
        
        final String secureUrl = data['secure_url'];
        print('🔗 Secure URL extracted: $secureUrl');
        
        return secureUrl;
      } else {
        print('❌ Upload failed with status: ${response.statusCode}');
        print('❌ Response body: $responseString');
        
        // Try to parse error details
        try {
          final errorData = json.decode(responseString);
          print('❌ Error details:');
          errorData.forEach((key, value) {
            print('   $key: $value');
          });
        } catch (e) {
          print('❌ Could not parse error response as JSON: $e');
        }
        
        throw Exception('Upload failed: ${response.statusCode} - $responseString');
      }
      
    } catch (e, stackTrace) {
      print('💥 CloudinaryService ERROR:');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Error message: $e');
      print('📚 Stack trace: $stackTrace');
      
      rethrow; // Re-throw to let the calling method handle it
    }
  }
}
