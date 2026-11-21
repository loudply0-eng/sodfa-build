import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

const _manifestUrl = String.fromEnvironment(
  'SODFA_UPDATE_MANIFEST_URL',
  defaultValue: 'https://mahmoudaljuorany.store/updates/sodfa/manifest.json',
);

class SodfaRelease {
  const SodfaRelease({required this.version,required this.buildNumber,required this.apkUrl,required this.sha256,required this.releaseNotes,required this.forceUpdate,required this.minSupportedBuild});
  final String version; final int buildNumber; final Uri apkUrl; final String sha256; final String releaseNotes; final bool forceUpdate; final int minSupportedBuild;
  factory SodfaRelease.fromJson(Map<String,dynamic> json) {
    final apkUrl=Uri.parse(json['apk_url'] as String);
    final digest=(json['sha256'] as String).toLowerCase();
    if(apkUrl.scheme!='https'||digest.length!=64||!RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) throw const FormatException('Invalid update URL or SHA-256 digest.');
    return SodfaRelease(version:json['version'] as String,buildNumber:(json['build_number'] as num).toInt(),apkUrl:apkUrl,sha256:digest,releaseNotes:(json['release_notes'] as String?)??'',forceUpdate:(json['force_update'] as bool?)??false,minSupportedBuild:(json['min_supported_build'] as num?)?.toInt()??0);
  }
}

class SodfaUpdateService {
  static Future<SodfaRelease?> check() async {
    final uri=Uri.tryParse(_manifestUrl);
    if(uri==null||uri.scheme!='https') throw const FormatException('Update manifest must use HTTPS.');
    final response=await http.get(uri,headers:{'Cache-Control':'no-cache'}).timeout(const Duration(seconds:15));
    if(response.statusCode!=200) throw HttpException('Update server returned ${response.statusCode}.');
    final json=jsonDecode(response.body) as Map<String,dynamic>;
    if(json['platform']!='android'||json['channel']!='stable') return null;
    final release=SodfaRelease.fromJson(json);
    final info=await PackageInfo.fromPlatform();
    final currentBuild=int.tryParse(info.buildNumber)??0;
    final expectedPackage=json['application_id'] as String?;
    if(expectedPackage!=null&&expectedPackage!=info.packageName) throw const FormatException('This update is for a different app package.');
    if(release.buildNumber<=currentBuild) return null;
    final rollout=((json['rollout_percentage'] as num?)?.toInt()??100).clamp(0,100);
    if(rollout<100&&!release.forceUpdate) {
      final bucket=_stableBucket(info.packageName,currentBuild);
      if(bucket>=rollout) return null;
    }
    return release;
  }

  static int _stableBucket(String packageName,int build) {
    final digest=sha256.convert(utf8.encode('$packageName:$build'));
    final value=digest.bytes.fold<int>(0,(sum,byte)=>(sum*31+byte)&0x7fffffff);
    return value%100;
  }

  static Future<String> downloadAndVerify(SodfaRelease release,{required void Function(double progress) onProgress}) async {
    final client=http.Client(); final bytes=<int>[];
    try {
      final request=http.Request('GET',release.apkUrl);
      final response=await client.send(request).timeout(const Duration(seconds:30));
      if(response.statusCode!=200) throw HttpException('APK download failed: ${response.statusCode}.');
      final total=response.contentLength??0; var received=0;
      await for(final chunk in response.stream){received+=chunk.length;bytes.addAll(chunk);if(total>0)onProgress((received/total).clamp(0.0,1.0).toDouble());if(bytes.length>500*1024*1024)throw const FormatException('APK exceeds the 500 MB safety limit.');}
    } finally {client.close();}
    final actualDigest=sha256.convert(bytes).toString();
    if(actualDigest!=release.sha256) throw const FormatException('Downloaded APK failed SHA-256 verification.');
    final directory=await getTemporaryDirectory();
    final file=File('${directory.path}/sodfa-update-${release.buildNumber}.apk');
    if(await file.exists())await file.delete();
    await file.writeAsBytes(bytes,flush:true);
    return file.path;
  }

  static Future<void> openInstaller(String apkPath) async {
    final result=await OpenFilex.open(apkPath,type:'application/vnd.android.package-archive');
    if(result.type!=ResultType.done) throw Exception(result.message.isEmpty?'Android could not open the package installer.':result.message);
  }
}
